require('NPCs/MainCreationMethods')
require('ISUI/ISCharacterInfoWindow')
require('IsoGameCharacter')
require('BodyDamage')
require "ISUI/ISCharacterScreen"
require "ISUI/ISPanelJoypad"
require ('ISUI/ISPanelJoypad')
require('ISUI/ISCharacterScreen')

local MULTIPLIER, STARTCHANCE



local InfectionLevel
local overallImmunity

local ScratchTable = {}
local ScratchCounter = 0

-- Define a struct creation function
local function createStruct(counter, flag)
    return {
        counter = counter,
        flag = flag
    }
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
end

local function updateInfectionLevel(...)
    InfectionLevel = getPlayer():getBodyDamage():getInfectionLevel()
end

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
    self:drawText("Infection Level: " .. string.format("%.2f", InfectionLevel), 0, 0, 1, 1, 1, 1, UIFont.Small)
    self:drawText("Infection Level: " .. string.format("%.2f", ScratchCounter), 0, 10, 1, 1, 1, 1, UIFont.Small)
end

function ISCharacterScreen:createChildren()
    original_createChildren(self)
    local infoPanel = MyInfoPanel:new(170, 200, 150, 50)
    self:addChild(infoPanel)
end

local original_prerender = ISCharacterScreen.prerender
function ISCharacterScreen:prerender()
    original_prerender(self)
    updateInfectionLevel()
end


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

---@type Callback_OnPlayerUpdate
local function CheckIfHealed(Character)
    updateInfectionLevel()

    local Character = getPlayer() 
    local BodyDamage = Character:getBodyDamage()
    local BodyParts = BodyDamage:getBodyParts()
    local PlayerScratchTable = Character:getModData().ImmunityTable
    local PlayerImmunityLevel = Character:getModData().ImmunityLevel

    if BodyDamage:isInfected() == true then
        math.randomseed(GameTime:getHoursSurvived())
        local randomFloat = math.random()
        if (randomFloat < PlayerImmunityLevel) then
            BodyDamage:setInfected(false)
            BodyDamage:setIsFakeInfected(true)
            Character:SayDebug("Fake Infected")
        end
    end

    if PlayerScratchTable == nil then
        Character:Say("Table was Nil")
        return
    end

    if PlayerImmunityLevel == nil then
        Character:Say("Player ImmunityLevel is Nil")
        return
    end

    for i=1, BodyParts:size()-1 do
        if PlayerScratchTable[BodyDamage:getBodyPartName(i)] == nil then
            Character:Say("ScratchTable at Index ".. i .. " Was nil")
        end
        local BodyPartName = BodyDamage:getBodyPartName(i)

        if BodyDamage:IsScratched(i) == true then
            if PlayerScratchTable[BodyPartName].flag ~= true then
                PlayerScratchTable[BodyPartName].flag = true
                PlayerScratchTable[BodyPartName].counter = PlayerScratchTable[BodyPartName].counter+1
                ScratchCounter = ScratchCounter +1
                Character:Say("Increasing Counter")
                Character:Say("Setting Flag to " .. tostring(PlayerScratchTable[BodyPartName].flag) .. " for bodypart " .. tostring(BodyPartName))
                Character:Say("The new ImmunityLevel should be " .. tostring(PlayerImmunityLevel * MULTIPLIER))
                PlayerImmunityLevel = PlayerImmunityLevel * MULTIPLIER
                Character:Say("New Immunity Level is: " .. PlayerImmunityLevel .. "and Multiplier is: " .. MULTIPLIER)

            end            
        else
            if PlayerScratchTable[BodyPartName].flag == true then
                PlayerScratchTable[BodyPartName].flag = false
                Character:Say("Setting Flag to " .. tostring(PlayerScratchTable[BodyPartName].flag) .. " for bodypart " .. tostring(BodyPartName))
            end
        end 
    
    end
end


---@type Callback_OnKeyPressed
local function DebugPrint(key)
    print(key)
    if (key == 67) then
        local table = getPlayer():getModData().ImmunityTable
        print(table["Pups"].flag)
    end
end

Events.OnGameStart.Add(SetSandboxSettings)
Events.OnCreatePlayer.Add(InitPlayer)
Events.OnPlayerUpdate.Add(CheckIfHealed)
Events.OnKeyPressed.Add(DebugPrint)