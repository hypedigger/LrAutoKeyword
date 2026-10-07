-- json.lua - minimal JSON encode/decode for Lightroom Classic
-- Based on json.lua by Jeffrey Friedl (simplified)

local json = {}

local function isArray(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

-- Encode a string to JSON — no complex patterns, char-by-char for safety in LR Lua
local function encodeString(s)
    local result = {}
    for i = 1, #s do
        local c = s:sub(i, i)
        local b = s:byte(i)
        if     c == '"'  then result[#result + 1] = '\\"'
        elseif c == '\\' then result[#result + 1] = '\\\\'
        elseif c == '\n' then result[#result + 1] = '\\n'
        elseif c == '\r' then result[#result + 1] = '\\r'
        elseif c == '\t' then result[#result + 1] = '\\t'
        elseif b < 32    then result[#result + 1] = string.format('\\u%04x', b)
        else                   result[#result + 1] = c
        end
    end
    return '"' .. table.concat(result) .. '"'
end

local function encodeValue(val)
    local t = type(val)
    if t == 'nil' then
        return 'null'
    elseif t == 'boolean' then
        return tostring(val)
    elseif t == 'number' then
        if val ~= val then return 'null' end
        return tostring(val)
    elseif t == 'string' then
        return encodeString(val)
    elseif t == 'table' then
        if isArray(val) then
            local parts = {}
            for _, v in ipairs(val) do
                parts[#parts + 1] = encodeValue(v)
            end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local parts = {}
            for k, v in pairs(val) do
                parts[#parts + 1] = encodeString(tostring(k)) .. ':' .. encodeValue(v)
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    end
    return 'null'
end

function json.encode(val)
    return encodeValue(val)
end

local function skipWhitespace(s, pos)
    while pos <= #s and s:sub(pos, pos):match('%s') do
        pos = pos + 1
    end
    return pos
end

local decodeValue

local function decodeString(s, pos)
    pos = pos + 1
    local result = {}
    while pos <= #s do
        local c = s:sub(pos, pos)
        if c == '"' then
            return table.concat(result), pos + 1
        elseif c == '\\' then
            local e = s:sub(pos + 1, pos + 1)
            local unesc = {['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t'}
            if unesc[e] then
                result[#result + 1] = unesc[e]
                pos = pos + 2
            elseif e == 'u' then
                local hex = s:sub(pos + 2, pos + 5)
                result[#result + 1] = '?'
                pos = pos + 6
            else
                result[#result + 1] = e
                pos = pos + 2
            end
        else
            result[#result + 1] = c
            pos = pos + 1
        end
    end
    error('Unterminated string')
end

local function decodeArray(s, pos)
    pos = pos + 1
    local result = {}
    pos = skipWhitespace(s, pos)
    if s:sub(pos, pos) == ']' then return result, pos + 1 end
    while true do
        local val
        val, pos = decodeValue(s, pos)
        result[#result + 1] = val
        pos = skipWhitespace(s, pos)
        local c = s:sub(pos, pos)
        if c == ']' then return result, pos + 1 end
        if c ~= ',' then error('Expected , or ] in array') end
        pos = skipWhitespace(s, pos + 1)
    end
end

local function decodeObject(s, pos)
    pos = pos + 1
    local result = {}
    pos = skipWhitespace(s, pos)
    if s:sub(pos, pos) == '}' then return result, pos + 1 end
    while true do
        pos = skipWhitespace(s, pos)
        local key
        key, pos = decodeString(s, pos)
        pos = skipWhitespace(s, pos)
        if s:sub(pos, pos) ~= ':' then error('Expected : in object') end
        pos = skipWhitespace(s, pos + 1)
        local val
        val, pos = decodeValue(s, pos)
        result[key] = val
        pos = skipWhitespace(s, pos)
        local c = s:sub(pos, pos)
        if c == '}' then return result, pos + 1 end
        if c ~= ',' then error('Expected , or } in object') end
        pos = skipWhitespace(s, pos + 1)
    end
end

decodeValue = function(s, pos)
    pos = skipWhitespace(s, pos)
    local c = s:sub(pos, pos)
    if c == '"' then
        return decodeString(s, pos)
    elseif c == '[' then
        return decodeArray(s, pos)
    elseif c == '{' then
        return decodeObject(s, pos)
    elseif c == 't' then
        return true, pos + 4
    elseif c == 'f' then
        return false, pos + 5
    elseif c == 'n' then
        return nil, pos + 4
    else
        local num = s:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
        if num then return tonumber(num), pos + #num end
        error('Unexpected character: ' .. c .. ' at position ' .. pos)
    end
end

function json.decode(s)
    local ok, result = pcall(function()
        local val, _ = decodeValue(s, 1)
        return val
    end)
    if ok then return result end
    return nil, result
end

return json
