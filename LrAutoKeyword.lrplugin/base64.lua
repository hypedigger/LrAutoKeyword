-- base64.lua - Base64 encoder for binary data (images)

local base64 = {}

local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function base64.encode(data)
    local result = {}
    local len = #data
    local i = 1

    while i <= len do
        local b1 = data:byte(i) or 0
        local b2 = data:byte(i + 1) or 0
        local b3 = data:byte(i + 2) or 0

        local n = b1 * 65536 + b2 * 256 + b3

        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        result[#result + 1] = chars:sub(c1 + 1, c1 + 1)
        result[#result + 1] = chars:sub(c2 + 1, c2 + 1)
        result[#result + 1] = (i + 1 <= len) and chars:sub(c3 + 1, c3 + 1) or '='
        result[#result + 1] = (i + 2 <= len) and chars:sub(c4 + 1, c4 + 1) or '='

        i = i + 3
    end

    return table.concat(result)
end

return base64
