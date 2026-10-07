-- TagManager.lua
-- Reads keyword hierarchy from Lightroom, filters out "Personnes" category,
-- and handles excluded keywords from prefs.
-- ID strategy: use full path string as unique identifier (LrKeyword has no localIdentifier).

local LrApplication = import 'LrApplication'
local LrPrefs       = import 'LrPrefs'

local TagManager = {}

local PEOPLE_ROOT_NAMES = { 'Personnes', 'People', 'Personen', 'Persone', 'Personas' }

local function isPeopleRoot(keyword)
    local name = keyword:getName()
    for _, n in ipairs(PEOPLE_ROOT_NAMES) do
        if name == n then return true end
    end
    local attrs = keyword:getAttributes()
    if attrs and attrs.keywordType == 'person' then return true end
    return false
end

-- Recursively collect all keywords under a keyword node.
-- excludedSet keys are fullPath strings.
local function collectKeywords(keyword, parentPath, result, excludedSet)
    local name = keyword:getName()
    local path = parentPath and (parentPath .. ' > ' .. name) or name

    if not excludedSet[path] then
        result[#result + 1] = {
            id       = path,   -- full path used as stable ID
            name     = name,
            fullPath = path,
            keyword  = keyword,
        }
    end

    local children = keyword:getChildren()
    if children then
        for _, child in ipairs(children) do
            collectKeywords(child, path, result, excludedSet)
        end
    end
end

-- Build a set of excluded keyword paths from prefs.
local function buildExcludedSet()
    local prefs    = LrPrefs.prefsForPlugin()
    local excluded = prefs.excludedKeywords or {}
    local set = {}
    for _, path in ipairs(excluded) do
        set[path] = true
    end
    return set
end

-- Returns a flat list of all "Autre" (non-people) keywords, excluding those in prefs.
function TagManager.getActiveTags()
    if _tagsCache then return _tagsCache end

    local catalog      = LrApplication.activeCatalog()
    local rootKeywords = catalog:getKeywords()
    local excludedSet  = buildExcludedSet()
    local result       = {}

    for _, kw in ipairs(rootKeywords) do
        if not isPeopleRoot(kw) then
            collectKeywords(kw, nil, result, excludedSet)
        end
    end

    _tagsCache = result
    return result
end

-- Returns the full keyword hierarchy as a tree for the settings UI.
-- Each node: { id, name, fullPath, keyword, excluded, children }
local function buildTree(keyword, parentPath, excludedSet)
    local name = keyword:getName()
    local path = parentPath and (parentPath .. ' > ' .. name) or name

    local node = {
        id       = path,
        name     = name,
        fullPath = path,
        keyword  = keyword,
        excluded = excludedSet[path] or false,
        children = {},
    }

    local children = keyword:getChildren()
    if children then
        for _, child in ipairs(children) do
            node.children[#node.children + 1] = buildTree(child, path, excludedSet)
        end
    end

    return node
end

function TagManager.getKeywordTree()
    if _treeCache then return _treeCache end

    local catalog      = LrApplication.activeCatalog()
    local rootKeywords = catalog:getKeywords()
    local excludedSet  = buildExcludedSet()
    local result       = {}

    for _, kw in ipairs(rootKeywords) do
        if not isPeopleRoot(kw) then
            result[#result + 1] = buildTree(kw, nil, excludedSet)
        end
    end

    _treeCache = result
    return result
end

-- Caches built once per session
local _kwCache   = nil
local _treeCache = nil
local _tagsCache = nil

local function buildCache()
    local cache = {}
    local catalog = LrApplication.activeCatalog()
    local roots   = catalog:getKeywords()

    local function index(keywords)
        for _, kw in ipairs(keywords) do
            local name = kw:getName()
            if not cache[name] then
                cache[name] = kw
            end
            local children = kw:getChildren()
            if children and #children > 0 then
                index(children)
            end
        end
    end

    index(roots)
    return cache
end

-- Invalidate all caches (call after keyword tree changes)
function TagManager.invalidateCache()
    _kwCache   = nil
    _treeCache = nil
    _tagsCache = nil
end

function TagManager.findKeyword(tagName)
    if not _kwCache then
        _kwCache = buildCache()
    end
    return _kwCache[tagName]
end

-- Apply a list of tag names to a photo within a single write transaction.
function TagManager.applyTagsToPhoto(photo, tagNames)
    if not _kwCache then
        _kwCache = buildCache()
    end
    local catalog = LrApplication.activeCatalog()
    catalog:withWriteAccessDo('Apply Claude Tags', function()
        for _, name in ipairs(tagNames) do
            local kw = _kwCache[name]
            if kw then
                photo:addKeyword(kw)
            end
        end
    end)
end

-- Returns a flat list of tag names for the Claude prompt.
function TagManager.getTagNamesForPrompt()
    local tags  = TagManager.getActiveTags()
    local names = {}
    for _, tag in ipairs(tags) do
        names[#names + 1] = tag.name
    end
    return names
end

return TagManager
