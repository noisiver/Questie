--Contains functions to fetch the Quest Experiance for quests.
---@class QuestXP
local QuestXP = QuestieLoader:CreateModule("QuestXP")

---@type table<QuestId,table<Level,XP>> -- { questId={level, xp}, ..... }
QuestXP.db = {}

--- COMPATIBILITY ---
local UnitBuff = QuestieCompat.UnitBuff
local GetMaxPlayerLevel = QuestieCompat.GetMaxPlayerLevel
local GetQuestLogRewardMoney = QuestieCompat.GetQuestLogRewardMoney

local floor = floor
local UnitLevel = UnitLevel

local globalXPMultiplier = 1
local isDiscovererDelightActive = false

function QuestXP.Init()
    if (Questie.IsWotlk or Questie.IsSoD) and globalXPMultiplier == 1 then
        for i = 1, 40 do
            local _, _, _, _, _, _, _, _, _, buffSpellId = UnitBuff("player", i)

            if buffSpellId == 377749 then
                -- Joyous Journeys is active - 50% bonus XP
                globalXPMultiplier = 1.5
                break
            end

            if buffSpellId == 436412 then
                -- Discoverer's Delight is active - 100% bonus XP
                globalXPMultiplier = 2
                isDiscovererDelightActive = true
                break
            end
        end
    end
end

---@param xp XP
---@param qLevel Level
---@param ignorePlayerLevel boolean
---@return XP experience
local function getAdjustedXP(xp, qLevel, ignorePlayerLevel)
    local charLevel = UnitLevel("player")
    if charLevel == GetMaxPlayerLevel() and (not ignorePlayerLevel) then
        return 0
    end

    --? These calculations are fetched from cmangos
    local xpMultiplier = 2 * (qLevel - charLevel) + 20
    if (xpMultiplier < 1) then
        xpMultiplier = 1
    elseif (xpMultiplier > 10) then
        xpMultiplier = 10
    end

    xp = xp * xpMultiplier / 10
    --? I am unsure if the first xp <= 100 is actually correct... because some 85 xp quests should actually give 90
    if (xp <= 100) then
        xp = 5 * floor((xp + 2) / 5)
    elseif (xp <= 500) then
        xp = 10 * floor((xp + 5) / 10)
    elseif (xp <= 1000) then
        xp = 25 * floor((xp + 12) / 25)
    else
        xp = 50 * floor((xp + 25) / 50)
    end

    return floor(xp * globalXPMultiplier)
end


---Get the adjusted XP for a quest.
---@param questId QuestId
---@param ignorePlayerLevel boolean
---@return XP experience
function QuestXP:GetQuestLogRewardXP(questId, ignorePlayerLevel)
    if QuestXP.db[questId] then
        local level = QuestXP.db[questId][1]
        local xp = QuestXP.db[questId][2]

        --? We have -1 as a level for quests that are event quests and so on for TBC and WOTLK.
        if level > 0 and xp > 0 then
            return getAdjustedXP(xp, level, ignorePlayerLevel)
        end
    end

    -- Return 0 if questId or xp data is not found for some reason
    return 0
end

local exclusions = {
    [78612] = true,
    [78872] = true,
    [79101] = true,
    [79102] = true,
    [79103] = true,
    [80307] = true,
    [80308] = true,
    [80309] = true,
}

function QuestXP.GetQuestRewardMoney(questId)
    local modifier = 1
    if isDiscovererDelightActive and (not exclusions[questId]) then
        modifier = 3
    end
    return floor(GetQuestLogRewardMoney(questId) * modifier)
end
