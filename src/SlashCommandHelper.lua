local L = EasyTravel.Localization
local JumpHelper = EasyTravel.JumpHelper
local ZoneList = EasyTravel.ZoneList
local PlayerList = EasyTravel.PlayerList

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
    self.dirty = true

    PlayerList:RegisterCallback(PlayerList.SET_DIRTY, function()
        self.dirty = true
    end)

    local function SlashCommandCallback(input)
        return self:SlashCommandCallback(input)
    end

    local function AutoCompleteResultProvider()
        return self:AutoCompleteResultProvider()
    end

    local function AutoCompleteResultLookup(label)
        return self:AutoCompleteResultLookup(label)
    end

    local LSC = LibStub("LibSlashCommander")
    self.command = LSC:Register({"/tp", "/travel", "/goto"}, SlashCommandCallback)
    self.command:SetAutoComplete(AutoCompleteResultProvider, nil, AutoCompleteResultLookup)
end

function SlashCommandHelper:SlashCommandCallback(input)
    PlayerList:Rebuild()
    if(ZoneList:HasZone(input)) then
        local zone = ZoneList:GetZoneByZoneName(input)
        JumpHelper:JumpTo(zone)
    elseif(PlayerList:HasDisplayName(input) or PlayerList:HasCharacterName(input)) then
        local player = PlayerList:GetPlayerByDisplayName(input) or PlayerList:GetPlayerByCharacterName(input)
        JumpHelper:JumpToPlayer(player)
    else
        local targetZone = ZoneList:GetZoneFromPartialName(input)
        if(targetZone) then
            JumpHelper:JumpTo(targetZone)
            return
        end

        local player = PlayerList:GetPlayerFromPartialName(input)
        if(player) then
            JumpHelper:JumpToPlayer(player)
            return
        end

        if(IsUnitGrouped("player") and not IsUnitGroupLeader("player")) then
            JumpHelper:JumpToGroupLeader()
        else
            local zone = ZoneList:GetCurrentZone()
            JumpHelper:JumpTo(zone)
        end
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

function SlashCommandHelper:AutoCompleteResultProvider()
    if(self.dirty) then
        ZO_ClearTable(self.resultList)
        ZO_ShallowTableCopy(self:GetPlayerResults(), self.resultList)
        ZO_ShallowTableCopy(self:GetZoneResults(), self.resultList)
        self.dirty = false
    end
    return self.resultList
end

function SlashCommandHelper:AutoCompleteResultLookup(label)
    return self.playerLookup[label] or self.zoneLookup[label] or label
end

EasyTravel.SlashCommandHelper = SlashCommandHelper:New()
