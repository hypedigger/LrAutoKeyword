-- TagSelectedPhotos.lua
-- Entry point for "Auto-Tag avec Claude" menu item.
-- Processes selected photos: export → Claude → review → apply tags.

local LrApplication = import 'LrApplication'
local LrDialogs     = import 'LrDialogs'
local LrTasks       = import 'LrTasks'
local LrProgressScope = import 'LrProgressScope'
local LrPrefs       = import 'LrPrefs'

local TagManager   = require 'TagManager'
local ClaudeAPI    = require 'ClaudeAPI'
local ExportHelper = require 'ExportHelper'
local ReviewDialog = require 'ReviewDialog'
local Logger       = require 'Logger'

Logger.clear()
Logger.info('=== Auto-Tag démarré ===')

-- Check API key before doing anything
local prefs = LrPrefs.prefsForPlugin()
if not prefs.apiKey or prefs.apiKey == '' then
    LrDialogs.message(
        'Clé API manquante',
        'Configurez votre clé API Anthropic dans\nBibliothèque > Plugin > Paramètres du plugin.',
        'warning'
    )
    return
end

LrTasks.startAsyncTask(function()
    local catalog        = LrApplication.activeCatalog()
    local selectedPhotos = catalog:getTargetPhotos()

    if not selectedPhotos or #selectedPhotos == 0 then
        LrDialogs.message('Aucune photo sélectionnée', 'Sélectionnez au moins une photo dans la bibliothèque.', 'warning')
        return
    end

    Logger.info('Photos sélectionnées: ' .. #selectedPhotos)

    -- Get active tag list once (same for all photos)
    local activeTags = TagManager.getActiveTags()
    Logger.info('Tags actifs: ' .. #activeTags)
    if #activeTags == 0 then
        LrDialogs.message('Aucun tag disponible', 'Aucun tag "Autre" trouvé dans votre catalogue (hors exclusions).', 'warning')
        return
    end

    local total    = #selectedPhotos
    local progress = LrProgressScope({
        title        = string.format('LrAutoKeyword — Analyse de %d photo(s)', total),
        functionContext = nil,
    })

    -- When set, these tags are applied to all remaining photos without calling Claude
    local applyToAllTags = nil

    local function processPhoto(photo, index)
        if progress:isCanceled() then return false end

        progress:setPortionComplete(index - 1, total)

        -- "Apply to all" mode: skip export AND Claude, just apply the validated tags
        if applyToAllTags then
            progress:setCaption(string.format('Application tags photo %d/%d…', index, total))
            Logger.info('ApplyToAll: applying saved tags to photo ' .. index)
            TagManager.applyTagsToPhoto(photo, applyToAllTags)
            return true
        end

        -- Normal mode: export → Claude → review
        progress:setCaption(string.format('Export photo %d/%d…', index, total))
        Logger.info('Exporting photo ' .. index .. '/' .. total)
        local tempPath, exportErr = ExportHelper.exportPhotoToTemp(photo)
        Logger.info('Export result: ' .. tostring(tempPath) .. ' err=' .. tostring(exportErr))
        if not tempPath then
            LrDialogs.message(
                'Erreur export',
                string.format('Photo %d/%d : %s', index, total, exportErr or 'inconnue'),
                'critical'
            )
            return true
        end

        progress:setCaption(string.format('Analyse Claude photo %d/%d…', index, total))
        local tagResult, apiErr = ClaudeAPI.analyzeImage(tempPath, activeTags)

        if not tagResult then
            ExportHelper.cleanup(tempPath)
            LrDialogs.message(
                'Erreur API Claude',
                string.format('Photo %d/%d : %s', index, total, apiErr or 'inconnue'),
                'critical'
            )
            return true
        end

        local reviewResult = ReviewDialog.show(photo, tagResult, index, total, tempPath)
        ExportHelper.cleanup(tempPath)

        if reviewResult.cancel then
            return false
        end

        if reviewResult.skip then
            return true
        end

        if reviewResult.selectedTags and #reviewResult.selectedTags > 0 then
            TagManager.applyTagsToPhoto(photo, reviewResult.selectedTags)
        end

        -- Save tags for all remaining photos if requested
        if reviewResult.applyToAll then
            applyToAllTags = reviewResult.selectedTags or {}
        end

        return true
    end

    for i, photo in ipairs(selectedPhotos) do
        local shouldContinue = processPhoto(photo, i)
        if not shouldContinue then
            break
        end
    end

    progress:done()

    if not progress:isCanceled() then
        LrDialogs.message(
            'LrAutoKeyword terminé',
            string.format('%d photo(s) traitée(s).', total),
            'info'
        )
    end
end)
