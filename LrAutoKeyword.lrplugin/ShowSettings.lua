-- ShowSettings.lua
-- Entry point for "Paramètres du plugin" menu item.

local LrTasks = import 'LrTasks'

local SettingsDialog = require 'SettingsDialog'

LrTasks.startAsyncTask(function()
    SettingsDialog.show()
end)
