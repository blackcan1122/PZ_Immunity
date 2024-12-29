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

    
    for i=1, BodyParts:size()-1 do
        ScratchTable[BodyDamage:getBodyPartName(i)] = createStruct(0,false)
    end

    local playertable = player:getModData()
    if playertable.ImmunityTable == nil then
        playertable.ImmunityTable = ScratchTable
    end 
end

local function updateInfectionLevel(...)
    InfectionLevel = getPlayer():getBodyDamage():getInfectionLevel()
    print (tostring(InfectionLevel))
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



local function CalculateImmunity(Character, DamageType, Damage)
    updateInfectionLevel()
    if Character ~= getPlayer() then
        print ("No Valid Character")
        return
    end
    -- if Character:getAttackedBy() ~= nil then
    --     if Character:getAttackedBy():isZombie() == false then
    --         print ("no Zombie")
    --        return
    --     end
    -- end

    local Character = getPlayer() 
    local BodyDamage = Character:getBodyDamage()
    local BodyParts = BodyDamage:getBodyParts()
    local PlayerScratchTable = Character:getModData().ImmunityTable

    if PlayerScratchTable == nil then
        Character:Say("Table was Nil")
        return
    end

    
    for i=1, BodyParts:size()-1 do
        if BodyDamage:IsScratched(i) == true then
            Character:Say("Im Scratched")
            if PlayerScratchTable[BodyDamage:getBodyPartName(i)].flag ~= true then
                PlayerScratchTable[BodyDamage:getBodyPartName(i)].flag = true
                PlayerScratchTable[BodyDamage:getBodyPartName(i)].counter = PlayerScratchTable[BodyDamage:getBodyPartName(i)].counter+1
                ScratchCounter = ScratchCounter +1
                Character:Say("Increasing Counter")
            else
                if PlayerScratchTable[BodyDamage:getBodyPartName(i)].flag ~= true then
                    PlayerScratchTable[BodyDamage:getBodyPartName(i)].flag = false
                    Character:Say("Scratch Gone")
                end
            end            
        end    
    end

end



Events.OnGameStart.Add(SetSandboxSettings)
Events.OnPlayerGetDamage.Add(CalculateImmunity)
Events.OnCreatePlayer.Add(InitPlayer)