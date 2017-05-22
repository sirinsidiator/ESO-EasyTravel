local L = EasyTravel.Localization
local JumpHelper = EasyTravel.JumpHelper
local ZoneList = EasyTravel.ZoneList
local PlayerList = EasyTravel.PlayerList
local Print = EasyTravel.Print
local HOME_LABEL = L["AUTOCOMPLETE_HOME_LABEL"]

local SlashCommandHelper = ZO_Object:Subclass()

function SlashCommandHelper:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function SlashCommandHelper:Initialize()
    self.resultList = {}
    self.playerLookup = {}
    self.zoneLookup = {}
    self.houseLookup = {}
    self.dirty = true

    PlayerList:RegisterCallback(PlayerList.SET_DIRTY, function()
        self.dirty = true
    end)

    local LSC = LibStub("LibSlashCommander")
    local this = self

    local EasyTravelAutoCompleteProvider = LSC.AutoCompleteProvider:Subclass()
    function EasyTravelAutoCompleteProvider:New()
        return LSC.AutoCompleteProvider.New(self)
    end

    function EasyTravelAutoCompleteProvider:GetResultList()
        return this:AutoCompleteResultProvider()
    end
    
    function EasyTravelAutoCompleteProvider:GetResultFromLabel(label)
        return this:AutoCompleteResultLookup(label)
    end
    
    local function SlashCommandCallback(input)
        return self:SlashCommandCallback(input)
    end

    self.command = LSC:Register({"/tp", "/travel", "/goto"}, SlashCommandCallback, L["SLASH_COMMAND_DESCRIPTION"])
    self.command:SetAutoComplete(EasyTravelAutoCompleteProvider:New())
end

function SlashCommandHelper:SlashCommandCallback(input)
    PlayerList:Rebuild()
    if(input == HOME_LABEL and GetHousingPrimaryHouse() > 0) then
        JumpHelper:JumpToHouse(GetHousingPrimaryHouse())
    elseif(ZoneList:HasZone(input)) then
        local zone = ZoneList:GetZoneByZoneName(input)
        JumpHelper:JumpTo(zone)
    elseif(ZoneList:HasHouse(input)) then
        local house = ZoneList:GetHouseByName(input)
        JumpHelper:JumpToHouse(house.houseId)
    elseif(PlayerList:HasDisplayName(input) or PlayerList:HasCharacterName(input)) then
        local player = PlayerList:GetPlayerByDisplayName(input) or PlayerList:GetPlayerByCharacterName(input)
        JumpHelper:JumpToPlayer(player)
    elseif(input == "") then
        if(IsUnitGrouped("player") and not IsUnitGroupLeader("player")) then
            JumpHelper:JumpToGroupLeader()
        else
            local zone = ZoneList:GetCurrentZone()
            if(not zone) then -- TODO: remember last zone we have been in and jump there instead
                Print(L["INVALID_TARGET_ZONE"])
                PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
            else
                JumpHelper:JumpTo(zone)
            end
        end
    else
        local targetZone = ZoneList:GetZoneFromPartialName(input)
        if(targetZone) then
            JumpHelper:JumpTo(targetZone)
            return
        end

        local targetHouse = ZoneList:GetHouseFromPartialName(input)
        if(targetHouse) then
            JumpHelper:JumpToHouse(targetHouse.houseId)
            return
        end

        local player = PlayerList:GetPlayerFromPartialName(input)
        if(player) then
            JumpHelper:JumpToPlayer(player)
            return
        end

        Print(L["INVALID_TARGET_ZONE"])
        PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
    end
end

function SlashCommandHelper:GetPlayerResults()
    local playerList = {}
    local players = PlayerList:GetPlayerList()
    ZO_ClearTable(self.playerLookup)

    for lower, player in pairs(players) do
        local label = zo_strformat(L["AUTOCOMPLETE_PLAYER_LABEL_TEMPLATE"], player.characterName, player.displayName, player.zone.name)
        playerList[zo_strlower(player.characterName .. player.displayName)] = label
        self.playerLookup[label] = player.displayName
    end

    return playerList
end

function SlashCommandHelper:GetZoneResults()
    local zoneList = {}
    local zones = ZoneList:GetZoneList()
    ZO_ClearTable(self.zoneLookup)

    for zoneName, zone in pairs(zones) do
        local count = PlayerList:GetPlayerCountForZone(zone)
        local label = zo_strformat(L["AUTOCOMPLETE_ZONE_LABEL_TEMPLATE"], zoneName, count)
        zoneList[zo_strlower(zoneName)] = label
        self.zoneLookup[label] = zoneName
    end

    return zoneList
end

function SlashCommandHelper:GetHouseResults()
    local houseList = {}
    local houses = ZoneList:GetHouseList()
    ZO_ClearTable(self.houseLookup)

    for houseName, house in pairs(houses) do
        local zoneName = house.foundInZoneName
        local template = house.unlocked and L["AUTOCOMPLETE_UNLOCKED_HOME_LABEL_TEMPLATE"] or L["AUTOCOMPLETE_LOCKED_HOME_LABEL_TEMPLATE"]
        local label = zo_strformat(template, houseName, zoneName)
        houseList[zo_strlower(houseName)] = label
        self.houseLookup[label] = houseName
        if(IsPrimaryHouse(house.houseId)) then
            local label = zo_strformat(L["AUTOCOMPLETE_PRIMARY_HOME_LABEL_TEMPLATE"], HOME_LABEL, houseName, zoneName)
            houseList[zo_strlower(HOME_LABEL)] = label
            self.houseLookup[label] = HOME_LABEL
        end
    end

    return houseList
end

function SlashCommandHelper:AutoCompleteResultProvider()
    if(self.dirty) then
        ZO_ClearTable(self.resultList)
        ZO_ShallowTableCopy(self:GetPlayerResults(), self.resultList)
        ZO_ShallowTableCopy(self:GetZoneResults(), self.resultList)
        ZO_ShallowTableCopy(self:GetHouseResults(), self.resultList)
        self.dirty = false
    end
    return self.resultList
end

function SlashCommandHelper:AutoCompleteResultLookup(label)
    return self.playerLookup[label] or self.zoneLookup[label] or self.houseLookup[label] or label
end

EasyTravel.SlashCommandHelper = SlashCommandHelper:New()
