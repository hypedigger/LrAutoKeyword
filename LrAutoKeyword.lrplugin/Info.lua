return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,

    -- identifiant conserve pour garder les preferences existantes (cle API...)
    LrToolkitIdentifier = 'com.lithroom.claudetagger',
    LrPluginName = 'LrAutoKeyword (Claude AI)',
    LrPluginInfoUrl = 'https://github.com/hypedigger/LrAutoKeyword',

    LrInitPlugin = 'PluginInit.lua',

    LrLibraryMenuItems = {
        {
            title    = 'Auto-Tag avec Claude',
            file     = 'TagSelectedPhotos.lua',
            -- Shortcut: assignable via Edition > Raccourcis clavier dans LR Classic
            -- Le SDK ne supporte pas les raccourcis directs dans Info.lua,
            -- mais LR Classic permet de les assigner manuellement dans ses options.
        },
        {
            title = 'Parametres du plugin',
            file  = 'ShowSettings.lua',
        },
        {
            title = 'Exporter liste des tags',
            file  = 'ExportTagList.lua',
        },
    },

    VERSION = { major = 3, minor = 7, revision = 0 },
}
