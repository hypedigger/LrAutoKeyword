-- SupportRule.lua
-- Pure rule (no Lightroom SDK dependency, testable with any Lua interpreter):
-- decides whether the "support the creator" popup is due after a given use.

local SupportRule = {}

-- count  : number of uses so far, including the one that just finished
-- optOut : true once the user ticked "Ne plus me le demander"
-- Shown at the 10th use, then every 100 uses (100, 200, 300...).
function SupportRule.shouldShow(count, optOut)
    if optOut then return false end
    if type(count) ~= 'number' then return false end
    if count == 10 then return true end
    return count >= 100 and count % 100 == 0
end

return SupportRule
