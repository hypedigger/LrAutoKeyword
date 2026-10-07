-- ReviewDialog.lua
-- 3 boutons dialog SDK (limite Adobe) + 1 bouton "Appliquer à toutes" dans le contenu.
-- Workflow : cocher les tags → cliquer "Appliquer à toutes" (optionnel) → "Appliquer"

local LrView            = import 'LrView'
local LrDialogs         = import 'LrDialogs'
local LrBinding         = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'

local VERSION = require 'Version'

local ReviewDialog = {}

local function getExistingNames(photo)
    local set = {}
    local ok, keywords = pcall(function() return photo:getRawMetadata('keywords') end)
    if ok and keywords then
        for _, kw in ipairs(keywords) do
            local ok2, name = pcall(function() return kw:getName() end)
            if ok2 and name then set[name] = true end
        end
    end
    return set
end

function ReviewDialog.show(photo, tagResult, photoIndex, photoCount, tempImagePath)
    local result = {}

    LrFunctionContext.callWithContext('ReviewDialog', function(context)
        local f     = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)

        local existingNames = getExistingNames(photo)
        local allTags       = {}
        local seenNames     = {}

        for _, name in ipairs(tagResult.certain or {}) do
            local key = 'tag_' .. name:gsub('[^%w]', '_')
            props[key] = true
            allTags[#allTags + 1] = { name = name, key = key, certain = true, existing = existingNames[name] or false }
            seenNames[name] = true
        end

        for _, name in ipairs(tagResult.probable or {}) do
            local key = 'tag_' .. name:gsub('[^%w]', '_')
            props[key] = false
            allTags[#allTags + 1] = { name = name, key = key, certain = false, existing = existingNames[name] or false }
            seenNames[name] = true
        end

        local existingOnly = {}
        for name in pairs(existingNames) do
            if not seenNames[name] then existingOnly[#existingOnly + 1] = name end
        end
        table.sort(existingOnly)

        -- Flag "appliquer à toutes" activé via push_button dans le contenu
        props.applyToAll      = false
        props.applyToAllLabel = 'Appliquer a toutes les photos suivantes'

        local function makeTagRows()
            local rows = {}

            if #(tagResult.certain or {}) > 0 then
                rows[#rows + 1] = f:static_text { title = 'Tags certains Claude (>85%) :', font = '<system/bold>' }
                for _, tag in ipairs(allTags) do
                    if tag.certain then
                        local label = tag.existing and (tag.name .. '  [deja present]') or tag.name
                        rows[#rows + 1] = f:checkbox { title = label, value = LrView.bind(tag.key) }
                    end
                end
            end

            if #(tagResult.probable or {}) > 0 then
                rows[#rows + 1] = f:spacer { height = 6 }
                rows[#rows + 1] = f:static_text { title = 'Tags probables Claude (50-85%) :', font = '<system/bold>' }
                for _, tag in ipairs(allTags) do
                    if not tag.certain then
                        local label = tag.existing and (tag.name .. '  [deja present]') or tag.name
                        rows[#rows + 1] = f:checkbox { title = label, value = LrView.bind(tag.key) }
                    end
                end
            end

            if #existingOnly > 0 then
                rows[#rows + 1] = f:spacer { height = 6 }
                rows[#rows + 1] = f:static_text { title = 'Tags deja sur cette photo :', font = '<system/bold>' }
                for _, name in ipairs(existingOnly) do
                    rows[#rows + 1] = f:static_text { title = '   ' .. name }
                end
            end

            if #allTags == 0 and #existingOnly == 0 then
                rows[#rows + 1] = f:static_text { title = 'Aucun tag reconnu pour cette photo.' }
            end

            return rows
        end

        local tagRows  = makeTagRows()
        local filename = photo:getFormattedMetadata('fileName') or '?'
        local header   = string.format('Photo %d / %d  —  %s', photoIndex, photoCount, filename)

        local thumbView
        if tempImagePath then
            thumbView = f:picture { value = tempImagePath, width = 360, height = 270 }
        else
            thumbView = f:static_text { title = '(apercu indisponible)', width = 360 }
        end

        local contents = f:column {
            bind_to_object  = props,
            fill_horizontal = 1,
            spacing         = f:label_spacing(),

            f:static_text { title = header, font = '<system/bold>', width = 900 },

            f:separator { fill_horizontal = 1 },

            f:row {
                spacing         = 16,
                fill_horizontal = 1,
                thumbView,
                f:column {
                    fill_horizontal = 1,
                    spacing         = f:control_spacing(),
                    unpack(tagRows),
                },
            },

            f:separator { fill_horizontal = 1 },

            f:checkbox {
                title = 'Appliquer a toutes les photos suivantes sans demander',
                value = LrView.bind('applyToAll'),
            },
        }

        -- 3 boutons SDK : Appliquer | Ignorer | Annuler tout
        local dialogResult = LrDialogs.presentModalDialog({
            title      = 'LrAutoKeyword ' .. VERSION .. ' — Revue des tags',
            contents   = contents,
            actionVerb = 'Appliquer',
            otherVerb  = 'Ignorer cette photo',
            cancelVerb = 'Annuler tout',
        })

        if dialogResult == 'cancel' then
            result = { cancel = true }
            return
        end

        if dialogResult == 'other' then
            result = { skip = true }
            return
        end

        local selected = {}
        for _, tag in ipairs(allTags) do
            if props[tag.key] then selected[#selected + 1] = tag.name end
        end

        result = {
            selectedTags = selected,
            applyToAll   = props.applyToAll,
        }
    end)

    return result
end

return ReviewDialog
