require('NPCs/MainCreationMethods')
require('ISUI/ISCharacterInfoWindow')
require('IsoGameCharacter')
require('BodyDamage')
require "ISUI/ISCharacterScreen"
require "ISUI/ISPanelJoypad"
require ('ISUI/ISPanelJoypad')
require('ISUI/ISCharacterScreen')
require('PZMath')

----------------------- SETUP -------------------------------------

local MULTIPLIER, STARTCHANCE


local ScratchTable = {}
local ScratchCounter = 0

-- Struct to use in a Table
local function createStruct(counter, flag)
    return {
        counter = counter,
        flag = flag
    }
end

--- Function to update the ScratchCount
---@param Character IsoGameCharacter
---@param DamageType? string
---@param Damage? number
local function UpdateScratchCount(Character, DamageType, Damage)
    if Character ~= getPlayer() then
        return
    end
    ---@type table<string, {counter: number, flag: boolean}>
        local ImmunityTable = Character:getModData().ImmunityTable
        if ImmunityTable == nil then
            Character:SayDebug("ImmunityTable is Nil")
            return
        end
        ScratchCounter = 0
    
        for v,k in pairs(ImmunityTable) do
            ScratchCounter = ScratchCounter + k.counter
        end
    end

--- we need to attach the ScratchTable to the player to keep track how many times it has been scratched and to check if we increase the counter
---@type Callback_OnCreatePlayer
local function InitPlayer(playernum, player)

    local BodyDamage = player:getBodyDamage()
    local BodyParts = BodyDamage:getBodyParts()
    local playertable = player:getModData()

    if playertable.ImmunityTable == nil then
        for i=1, BodyParts:size()-1 do
            ScratchTable[BodyDamage:getBodyPartName(i)] = createStruct(0,false)
        end
        playertable.ImmunityTable = ScratchTable
    end 

    if playertable.ImmunityLevel == nil then
        playertable.ImmunityLevel = SandboxVars.Immunity.InitialChance
    end

    UpdateScratchCount(player)
end
----------------------- SETUP END -------------------------------------
----------------------- UI -------------------------------------
local original_createChildren = ISCharacterScreen.createChildren

local MyInfoPanel = ISPanel:derive("InfoPanel")

function MyInfoPanel:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end


function MyInfoPanel:render()
    ISPanel.render(self)
    self:drawText("ImmunityLevel: " .. string.format("%.4f", getPlayer():getModData().ImmunityLevel), 0, 0, 1, 1, 1, 1, UIFont.Small)
    self:drawText("ScratchCounter: " .. tostring(ScratchCounter), 0, 10, 1, 1, 1, 1, UIFont.Small)
end

function ISCharacterScreen:createChildren()
    original_createChildren(self)
    local infoPanel = MyInfoPanel:new(170, 200, 150, 50)
    self:addChild(infoPanel)
end

----------------------- UI END -------------------------------------

-------------------------------------------------------------------------------------------------------------------
--- right now not needed, if we ever need to update something in synch with the UI we could call the functions here
-- local original_prerender = ISCharacterScreen.prerender
-- function ISCharacterScreen:prerender()
--     original_prerender(self)
-- end
-------------------------------------------------------------------------------------------------------------------


local function SetSandboxSettings()
    MULTIPLIER = SandboxVars.Immunity.Multiplier
    if MULTIPLIER == nil then
        MULTIPLIER = 1.01
    end
    STARTCHANCE = SandboxVars.Immunity.InitialChance
    if STARTCHANCE == nil then
        STARTCHANCE = 0.01
    end

    print("SandboxVars were initialised with STARTCHANCE: ", STARTCHANCE, "And Multiplier: ", MULTIPLIER)
end

---@param Character IsoPlayer 
---@param BodyDamage BodyDamage 
---@param BodyParts ArrayList 
local function HealBodyPartFromInfection(Character, BodyDamage, BodyParts, PlayerScratchTable, PlayerImmunityLevel)
    for i=1, BodyParts:size()-1 do
        if BodyDamage:IsBitten(i) == true then
            BodyDamage:getBodyPart(BodyPartType.FromIndex(i)):SetInfected(false)
            Character:SayDebug("BodyPart: " .. BodyDamage:getBodyPartName(i) .. " setting Infected to: " .. tostring(BodyDamage:getBodyPart(BodyPartType.FromIndex(i)):IsInfected()))
        end
    end
end

--- bool to check whether we want to roll for being immun
local FreshlyInfected = true

--- calling this OnPlayerUpdate to detect when the player is healed as OnPlayerGetDamage doesn't get called when player is not hurt
--- but we need to check when he is healed to reset  FreshlyInfected
--- could maybe be refactored to use OnPlayerGetDamage with a while Loop but not sure about game thread blocking
---@type Callback_OnPlayerUpdate
local function CheckIfImmune(Character)
    local BodyDamage = Character:getBodyDamage()
    local BodyParts = BodyDamage:getBodyParts()
    local PlayerScratchTable = Character:getModData().ImmunityTable
    local PlayerImmunityLevel = Character:getModData().ImmunityLevel

    --- Closure Guards to check if anytable is NIL
    if PlayerScratchTable == nil then
        Character:SayDebug("Table was Nil")
        return
    end

    if PlayerImmunityLevel == nil then
        Character:SayDebug("Player ImmunityLevel is Nil")
        return
    end

    --- since OnPlayerUpdate is calling per Tick but we only want one Random Seed per "infection" we use a bool
    --- to force it be only called once per "real" infection
    --- that means we could get a fake Infection, and afterwards still get a real Infection but after we are really infected
    --- we can't get a fake infection anymore as FreshlyInfected won't reset anymore
    if BodyDamage:isInfected() == true and FreshlyInfected then
        FreshlyInfected = false
        local randomFloat = ZombRandFloat(1,100)
        Character:SayDebug("random Float Value is:".. randomFloat)
        if (randomFloat < PlayerImmunityLevel) then
        BodyDamage:setInfected(false)
        BodyDamage:setInfectionLevel(0)
        BodyDamage:setIsFakeInfected(true)
        Character:SayDebug("Fake Infected")
        HealBodyPartFromInfection(Character, BodyDamage, BodyParts, PlayerScratchTable, PlayerImmunityLevel)
        end
    end

    if BodyDamage:isInfected() == false then
        FreshlyInfected = true
    end

    for i=1, BodyParts:size()-1 do
        if PlayerScratchTable[BodyDamage:getBodyPartName(i)] == nil then
            Character:SayDebug("ScratchTable at Index ".. i .. " Was nil")
        end
        local BodyPartName = BodyDamage:getBodyPartName(i)

        if BodyDamage:IsScratched(i) == true and BodyDamage:isInfected() == false then
            if PlayerScratchTable[BodyPartName].flag ~= true then
                PlayerScratchTable[BodyPartName].flag = true
                PlayerScratchTable[BodyPartName].counter = PlayerScratchTable[BodyPartName].counter+1
                Character:getModData().ImmunityLevel =  PZMath.clampFloat(PlayerImmunityLevel * MULTIPLIER,0,SandboxVars.Immunity.Max_Immunity)
                Character:SayDebug("New Immunity Level is: " .. string.format("%.4f", getPlayer():getModData().ImmunityLevel))

            end            
        else
            if PlayerScratchTable[BodyPartName].flag == true then
                PlayerScratchTable[BodyPartName].flag = false
            end
        end 
    end
end

local function ReduceImmunity()

    if SandboxVars.Immunity.DegradeOverTime == false then
        return
    end

    getPlayer():SayDebug("Reducing ImmunityLevel")
    getPlayer():getModData().ImmunityLevel = getPlayer():getModData().ImmunityLevel * ZombRandFloat(0.5, 0.75)
    getPlayer():SayDebug("New Immunity is now: " .. getPlayer():getModData().ImmunityLevel)
end



--- triggering a wrong Table Access Key to see the table in Debug View
---@type Callback_OnKeyPressed
local function DebugPrint(key)
    if (key == 67) and isDebugEnabled() then
        local table = getPlayer():getModData().ImmunityTable
        print(table["XXX"].flag)
    end
end

Events.OnGameStart.Add(SetSandboxSettings)
Events.OnCreatePlayer.Add(InitPlayer)
Events.OnPlayerUpdate.Add(CheckIfImmune)
Events.OnKeyPressed.Add(DebugPrint)
Events.OnPlayerGetDamage.Add(UpdateScratchCount)
Events.EveryDays.Add(ReduceImmunity)