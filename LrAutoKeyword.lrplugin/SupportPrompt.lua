-- SupportPrompt.lua
-- Ko-fi link + usage counter + discreet "support the creator" popup.
-- One use = one Auto-Tag run that went through to the end (no error, not cancelled).
-- The counter lives in the plugin preferences only; nothing is sent anywhere.

local LrView            = import 'LrView'
local LrDialogs         = import 'LrDialogs'
local LrBinding         = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp            = import 'LrHttp'
local LrPrefs           = import 'LrPrefs'
local LrTasks           = import 'LrTasks'

local SupportRule = require 'SupportRule'
local Logger      = require 'Logger'

local SupportPrompt = {}

SupportPrompt.KOFI_URL = 'https://ko-fi.com/hypedigger'

function SupportPrompt.openKofi()
    LrHttp.openUrlInBrowser(SupportPrompt.KOFI_URL)
end

local function showDialog(prefs)
    LrFunctionContext.callWithContext('SupportPrompt', function(context)
        local f     = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)

        props.optOut = false

        local contents = f:column {
            bind_to_object = props,
            spacing        = f:control_spacing(),

            f:static_text {
                title           = 'Ce plug-in est gratuit et open source, développé sur le temps libre de son créateur.\n\nS\'il vous fait gagner du temps, un petit café sur Ko-fi l\'aide à continuer — merci !',
                width_in_chars  = 60,
                height_in_lines = 5,
            },

            f:checkbox {
                title = 'Ne plus me le demander',
                value = LrView.bind('optOut'),
            },
        }

        local dialogResult = LrDialogs.presentModalDialog({
            title      = '☕ Vous aimez LrAutoKeyword ?',
            contents   = contents,
            actionVerb = '☕ Soutenir sur Ko-fi',
            cancelVerb = 'Plus tard',
        })

        -- La case vaut quel que soit le bouton choisi
        if props.optOut then
            prefs.supportOptOut = true
        end

        if dialogResult == 'ok' then
            SupportPrompt.openKofi()
        end
    end)
end

-- Counts one use and shows the popup when due (10th use, then every 100).
-- Must be called from an async task, once the run has finished its work.
function SupportPrompt.recordUse()
    local prefs = LrPrefs.prefsForPlugin()
    local count = (tonumber(prefs.usageCount) or 0) + 1
    prefs.usageCount = count

    if SupportRule.shouldShow(count, prefs.supportOptOut == true) then
        -- The popup is a nicety: it must never turn a successful run into an error
        local ok, err = LrTasks.pcall(showDialog, prefs)
        if not ok then
            Logger.error('SupportPrompt: ' .. tostring(err))
        end
    end
end

return SupportPrompt
