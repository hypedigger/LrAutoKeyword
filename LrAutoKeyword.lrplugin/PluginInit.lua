-- PluginInit.lua - Called when the plugin is loaded by Lightroom Classic

local LrPrefs = import 'LrPrefs'

local prefs = LrPrefs.prefsForPlugin()

-- Set defaults if not already configured
if prefs.apiKey == nil then
    prefs.apiKey = ''
end
if prefs.model == nil then
    prefs.model = 'claude-sonnet-4-6'
end
if prefs.excludedKeywords == nil then
    prefs.excludedKeywords = {}
end
if prefs.jpegMaxSize == nil then
    prefs.jpegMaxSize = 1500
end
if prefs.jpegQuality == nil then
    prefs.jpegQuality = 80
end
