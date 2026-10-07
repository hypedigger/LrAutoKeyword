-- ExportTagList.lua
-- Exports all active (non-excluded) tags to a text file for manual annotation.
-- Format: one tag per line followed by ': ' so the user can fill in meanings.

local LrDialogs = import 'LrDialogs'
local LrTasks   = import 'LrTasks'

local TagManager = require 'TagManager'

LrTasks.startAsyncTask(function()
    local activeTags = TagManager.getActiveTags()

    if #activeTags == 0 then
        LrDialogs.message('Aucun tag', 'Aucun tag actif trouvé dans le catalogue.', 'warning')
        return
    end

    -- Collect unique names, sorted alphabetically
    local names = {}
    local seen  = {}
    for _, tag in ipairs(activeTags) do
        if not seen[tag.name] then
            seen[tag.name] = true
            names[#names + 1] = tag.name
        end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)

    local lines = {}
    for _, name in ipairs(names) do
        lines[#lines + 1] = name .. ': '
    end

    local content = table.concat(lines, '\n')
    local outPath = _PLUGIN.path .. '/tags_annotation.txt'

    local f, err = io.open(outPath, 'w')
    if not f then
        LrDialogs.message('Erreur écriture', 'Impossible de créer le fichier :\n' .. tostring(err), 'critical')
        return
    end
    f:write(content)
    f:close()

    LrDialogs.message(
        'Fichier créé (' .. #names .. ' tags)',
        'Enregistré dans :\n' .. outPath,
        'info'
    )
end)
