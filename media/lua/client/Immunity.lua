require('NPCs/MainCreationMethods')
require('ISUI/ISCharacterInfoWindow')
require('IsoGameCharacter')
require('BodyDamage')
require "ISUI/ISCharacterScreen"
require "ISUI/ISPanelJoypad"
require ('ISUI/ISPanelJoypad')
require('ISUI/ISCharacterScreen')

local MULTIPLIER, STARTCHANCE

local original_createChildren = ISCharacterScreen.createChildren

local InfectionLevel

local function updateInfectionLevel(...)
    InfectionLevel = getPlayer():getBodyDamage():getInfectionLevel()
    print (tostring(InfectionLevel))
end


function ISCharacterScreen:createChildren()
    original_createChildren(self)
    
    -- Add your custom information here
    local y = self.height
    local customLabel = ISLabel:new(250, y, 20, "Custom Info:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(customLabel)
    
    
    y = y + 20
    local infoLabel = ISLabel:new(250, y, 20, tostring(InfectionLevel) , 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(infoLabel)
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

    print("SandboxVars were initialised with STARTCHANCE:", STARTCHANCE, "And Multiplier:", MULTIPLIER)
    getPlayer():getBodyDamage():setInfected(true);
    --addCustomStatToUI(getPlayer())
    InfectionLevel = getPlayer():getBodyDamage().InfectionLevelToZombify
end



local function CalculateImmunity(Character, DamageType, Damage)
    updateInfectionLevel()
    if Character ~= getPlayer() then
        print ("No Valid Character")
        return
    end
    if Character:getAttackedBy():isZombie() == false then
        print ("no Zombie")
       return
    end

    local Character = getPlayer() 
    local BodyDamage = Character:getBodyDamage()
    local BodyParts = BodyDamage:getBodyParts()

    for i=1, BodyParts:size()-1 do
        print (BodyDamage:getBodyPartName(i))
        BodyDamage:IsBitten(i)
        BodyDamage:IsScratched(i)
    end
    

end



Events.OnGameStart.Add(SetSandboxSettings)
Events.OnPlayerGetDamage.Add(CalculateImmunity)