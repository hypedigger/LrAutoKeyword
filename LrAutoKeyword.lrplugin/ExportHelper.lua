-- ExportHelper.lua
-- Exports a photo as a temporary JPEG for sending to Claude API.
-- Size limit: 3500 KB raw → ~4.7 MB base64 (under Claude's 5 MB limit)

local LrExportSession = import 'LrExportSession'
local LrPathUtils     = import 'LrPathUtils'
local LrFileUtils     = import 'LrFileUtils'
local LrPrefs         = import 'LrPrefs'

local ExportHelper = {}

function ExportHelper.exportPhotoToTemp(photo)
    local prefs   = LrPrefs.prefsForPlugin()
    local maxSize = prefs.jpegMaxSize or 1500
    local quality = (prefs.jpegQuality or 70) / 100  -- LR expects 0.0–1.0

    local tempDir = LrPathUtils.getStandardFilePath('temp')
    local photoId = tostring(photo.localIdentifier or os.time())
    local tempPath = LrPathUtils.child(tempDir, 'lrt_' .. photoId .. '.jpg')

    if LrFileUtils.exists(tempPath) then
        LrFileUtils.delete(tempPath)
    end

    local exportSettings = {
        LR_export_destinationType       = 'specificFolder',
        LR_export_destinationPathPrefix = tempDir,
        LR_export_useSubfolder          = false,
        LR_format                       = 'JPEG',
        LR_jpeg_quality                 = quality,
        -- Hard size limit: 400 KB raw → base64 ~540 KB (rapide + peu coûteux)
        LR_jpeg_useLimitSize            = true,
        LR_jpeg_limitSize               = 400,
        LR_minimizeEmbeddedMetadata     = true,
        LR_removeLocationMetadata       = true,
        LR_outputSharpeningOn           = false,
        -- Resize: 'wh' constrains both dimensions — more reliable than 'longEdge'
        LR_size_doNotEnlarge            = true,
        LR_size_resizeType              = 'wh',
        LR_size_maxWidth                = maxSize,
        LR_size_maxHeight               = maxSize,
        LR_size_units                   = 'pixels',
        LR_reimportExportedPhoto        = false,
        LR_collisionHandling            = 'overwrite',
        LR_export_colorSpace            = 'sRGB',
        LR_useWatermark                 = false,
        LR_embeddedMetadataOption       = 'titleOnly',
    }

    local session = LrExportSession({
        photosToExport = { photo },
        exportSettings = exportSettings,
    })

    local exportedPath = nil
    local exportError  = nil

    for _, rendition in session:renditions() do
        local success, pathOrMessage = rendition:waitForRender()
        if success then
            exportedPath = pathOrMessage
        else
            exportError = pathOrMessage
        end
    end

    if not exportedPath then
        return nil, exportError or 'Export échoué sans message d\'erreur.'
    end

    return exportedPath, nil
end

function ExportHelper.cleanup(filePath)
    if filePath and LrFileUtils.exists(filePath) then
        LrFileUtils.delete(filePath)
    end
end

return ExportHelper
