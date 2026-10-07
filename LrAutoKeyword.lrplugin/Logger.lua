-- Logger.lua - Simple file logger for LrAutoKeyword
-- Log file: LithRoomTagger.lrplugin/debug.log

local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local Logger = {}

-- Get log file path next to the plugin
local _logPath = nil

local function getLogPath()
    if _logPath then return _logPath end
    -- _PLUGIN.path is the plugin directory
    if _PLUGIN and _PLUGIN.path then
        _logPath = LrPathUtils.child(_PLUGIN.path, 'debug.log')
    else
        _logPath = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'lrautokeyword_debug.log')
    end
    return _logPath
end

local function timestamp()
    return os.date('%Y-%m-%d %H:%M:%S')
end

function Logger.log(level, msg)
    local path = getLogPath()
    local f = io.open(path, 'a')
    if f then
        f:write(string.format('[%s] [%s] %s\n', timestamp(), level, tostring(msg)))
        f:close()
    end
end

function Logger.info(msg)  Logger.log('INFO',  msg) end
function Logger.warn(msg)  Logger.log('WARN',  msg) end
function Logger.error(msg) Logger.log('ERROR', msg) end
function Logger.debug(msg) Logger.log('DEBUG', msg) end

function Logger.clear()
    local path = getLogPath()
    local f = io.open(path, 'w')
    if f then
        f:write(string.format('=== LrAutoKeyword log started %s ===\n', timestamp()))
        f:close()
    end
end

return Logger
