-- ClaudeAPI.lua
-- Handles communication with the Anthropic Claude API for image tagging.

local LrHttp   = import 'LrHttp'
local LrPrefs  = import 'LrPrefs'

local json   = require 'json'
local base64 = require 'base64'
local Logger = require 'Logger'

local ClaudeAPI = {}

local API_URL = 'https://api.anthropic.com/v1/messages'

-- Read image file and return base64 string
local function encodeImageFile(filePath)
    local f, err = io.open(filePath, 'rb')
    if not f then
        return nil, 'Impossible d\'ouvrir le fichier image: ' .. (err or filePath)
    end
    local data = f:read('*all')
    f:close()
    return base64.encode(data)
end

-- Descriptions des tags dont le sens n'est pas évident visuellement.
-- Personnelles : tag_descriptions.lua (non versionné) ;
-- modèle fourni : tag_descriptions_example.lua.
local okDesc, TAG_DESCRIPTIONS = pcall(require, 'tag_descriptions')
if not okDesc or type(TAG_DESCRIPTIONS) ~= 'table' then
    okDesc, TAG_DESCRIPTIONS = pcall(require, 'tag_descriptions_example')
end
if type(TAG_DESCRIPTIONS) ~= 'table' then
    TAG_DESCRIPTIONS = {}
end

-- Build the Claude prompt for tagging
local function buildPrompt(tagList)
    local tagListStr = table.concat(tagList, '\n- ')

    -- Build glossary only for tags present in the active list that have a description
    local glossaryLines = {}
    for _, name in ipairs(tagList) do
        if TAG_DESCRIPTIONS[name] then
            glossaryLines[#glossaryLines + 1] = string.format('  "%s" = %s', name, TAG_DESCRIPTIONS[name])
        end
    end
    local glossary = ''
    if #glossaryLines > 0 then
        glossary = '\n\nGlossaire (sens de certains tags) :\n' .. table.concat(glossaryLines, '\n')
    end

    return string.format([[Tu es un assistant de catalogage photographique.

Analyse cette image et retourne UNIQUEMENT les tags qui décrivent les sujets PRINCIPAUX et DOMINANTS de la photo, parmi cette liste :
- %s%s

Règles STRICTES :
1. Ne retourne JAMAIS un tag absent de cette liste (respecte la casse et l'orthographe exactes)
2. Tague uniquement ce qui occupe une place IMPORTANTE dans l'image ou qui en est le sujet principal
3. IGNORE les éléments en arrière-plan, partiels ou secondaires
4. Retourne tous les tags clairement pertinents — ni trop (pas d'éléments anecdotiques), ni trop peu (ne rate pas les sujets importants)
5. Certitude >85%% → "certain" | Certitude 50-85%% → "probable"
6. Réponds UNIQUEMENT en JSON valide, sans aucun texte avant ou après :
{"certain": ["tag1", "tag2"], "probable": ["tag3"]}
7. Préfère toujours le tag le plus précis : si tu choisis une sous-catégorie (ex : "église"), ne propose PAS le tag parent générique (ex : "bâtiment")

Si rien ne correspond clairement : {"certain": [], "probable": []}]], tagListStr, glossary)
end

-- Send image to Claude API and return parsed tag lists.
-- activeTags: array of { name, fullPath, ... } from TagManager.getActiveTags()
-- Returns: tagResult { certain = {}, probable = {} }, error
function ClaudeAPI.analyzeImage(imagePath, activeTags)
    local prefs  = LrPrefs.prefsForPlugin()
    local apiKey = prefs.apiKey or ''
    local model  = prefs.model or 'claude-sonnet-4-6'

    -- Build flat name list for the prompt + fullPath lookup for post-processing
    local tagList    = {}
    local pathByName = {}
    for _, t in ipairs(activeTags) do
        tagList[#tagList + 1] = t.name
        if not pathByName[t.name] then
            pathByName[t.name] = t.fullPath
        end
    end

    Logger.info('analyzeImage: ' .. tostring(imagePath) .. ' model=' .. model)
    Logger.info('tagList count: ' .. #tagList)

    if apiKey == '' then
        Logger.error('Clé API manquante')
        return nil, 'Clé API manquante. Configurez-la dans les paramètres du plugin.'
    end

    -- Encode image
    local imageData, encErr = encodeImageFile(imagePath)
    if not imageData then
        Logger.error('Encode image failed: ' .. tostring(encErr))
        return nil, encErr
    end
    Logger.info('Image encoded, base64 length: ' .. #imageData)

    -- Build request body
    local prompt = buildPrompt(tagList)
    local body = json.encode({
        model      = model,
        max_tokens = 1024,
        messages   = {
            {
                role    = 'user',
                content = {
                    {
                        type   = 'image',
                        source = {
                            type       = 'base64',
                            media_type = 'image/jpeg',
                            data       = imageData,
                        },
                    },
                    {
                        type = 'text',
                        text = prompt,
                    },
                },
            },
        },
    })

    -- HTTP headers
    local headers = {
        { field = 'Content-Type',      value = 'application/json' },
        { field = 'x-api-key',         value = apiKey },
        { field = 'anthropic-version', value = '2023-06-01' },
    }

    -- POST request
    Logger.info('Sending POST to Claude API...')
    local result, resHeaders = LrHttp.post(API_URL, body, headers)

    if not result then
        Logger.error('No response from API')
        return nil, 'Erreur réseau : pas de réponse de l\'API Claude.'
    end

    local status = resHeaders and resHeaders.status
    Logger.info('HTTP status: ' .. tostring(status))

    if status ~= 200 then
        Logger.error('API error body: ' .. tostring(result):sub(1, 300))
        local errData = json.decode(result)
        local errMsg = (errData and errData.error and errData.error.message) or result
        return nil, string.format('Erreur API Claude (HTTP %s): %s', tostring(status), errMsg)
    end

    local data, parseErr = json.decode(result)
    if not data then
        Logger.error('JSON parse error: ' .. tostring(parseErr))
        return nil, 'Réponse API illisible: ' .. (parseErr or result)
    end

    local text = data.content and data.content[1] and data.content[1].text
    if not text then
        Logger.error('No text in response: ' .. tostring(result):sub(1, 300))
        return nil, 'Réponse API vide ou format inattendu.'
    end

    Logger.info('Claude raw response: ' .. tostring(text):sub(1, 500))

    text = text:match('```json%s*(.-)%s*```') or text:match('```%s*(.-)%s*```') or text
    text = text:match('^%s*(.-)%s*$')

    local tagResult, tagErr = json.decode(text)
    if not tagResult then
        Logger.error('Tag JSON parse error: ' .. tostring(tagErr) .. ' | text: ' .. tostring(text))
        return nil, 'Claude n\'a pas retourné un JSON valide: ' .. (tagErr or text)
    end

    Logger.info('Tags certain: ' .. #(tagResult.certain or {}) .. ' probable: ' .. #(tagResult.probable or {}))

    -- Post-process: remove parent tags when a more specific child tag is also returned.
    -- Build a set of all returned paths (certain + probable).
    local returnedPaths = {}
    for _, name in ipairs(tagResult.certain  or {}) do
        local p = pathByName[name]
        if p then returnedPaths[p] = true end
    end
    for _, name in ipairs(tagResult.probable or {}) do
        local p = pathByName[name]
        if p then returnedPaths[p] = true end
    end

    local function filterParents(list)
        local out = {}
        for _, name in ipairs(list) do
            local path    = pathByName[name]
            local isParent = false
            if path then
                local prefix = path .. ' > '
                for rp in pairs(returnedPaths) do
                    if rp ~= path and rp:sub(1, #prefix) == prefix then
                        isParent = true
                        break
                    end
                end
            end
            if not isParent then
                out[#out + 1] = name
            end
        end
        return out
    end

    local certain  = filterParents(tagResult.certain  or {})
    local probable = filterParents(tagResult.probable or {})
    Logger.info('After parent-filter — certain: ' .. #certain .. ' probable: ' .. #probable)

    return { certain = certain, probable = probable }
end

return ClaudeAPI
