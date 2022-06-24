local ET = EasyTravel
local internal = ET.internal
local L = internal.Localization
local PlayerList = ET.class.PlayerList
local chat = internal.chat
local HOME_LABEL = L["AUTOCOMPLETE_HOME_LABEL"]

local SlashCommandHelper = ZO_InitializingObject:Subclass()
ET.class.SlashCommandHelper = SlashCommandHelper

function SlashCommandHelper:Initialize(zoneList, playerList, jumpHelper)
    self.zoneList = zoneList
    self.playerList = playerList
    self.jumpHelper = jumpHelper
    self.resultList = {}
    self.playerLookup = {}
    self.zoneLookup = {}
    self.houseLookup = {}
    self.dirty = true

    playerList:RegisterCallback(PlayerList.SET_DIRTY, function()
        self.dirty = true
    end)

    local LSC = LibSlashCommander
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
    self.autocompleteResultProvider = EasyTravelAutoCompleteProvider

    self.command = LSC:Register({"/tp", "/travel", "/goto"}, SlashCommandCallback, L["SLASH_COMMAND_DESCRIPTION"])
    self.command:SetAutoComplete(EasyTravelAutoCompleteProvider:New())
end

function SlashCommandHelper:SlashCommandCallback(input, isTopResult)
    local zoneList = self.zoneList
    local playerList = self.playerList
    local jumpHelper = self.jumpHelper
    if(not isTopResult) then
        playerList:Rebuild()
    end
    if(input == HOME_LABEL and GetHousingPrimaryHouse() > 0) then
        jumpHelper:JumpToHouse(GetHousingPrimaryHouse())
        return
    elseif(zoneList:HasZone(input)) then
        local zone = zoneList:GetZoneByZoneName(input)
        jumpHelper:JumpTo(zone)
        return
    elseif(zoneList:HasHouse(input)) then
        local house = zoneList:GetHouseByName(input)
        jumpHelper:JumpToHouse(house.houseId)
        return
    elseif(playerList:HasDisplayName(input) or playerList:HasCharacterName(input)) then
        local player = playerList:GetPlayerByDisplayName(input) or playerList:GetPlayerByCharacterName(input)
        jumpHelper:JumpToPlayer(player)
        return
    elseif(input == "") then
        if(IsUnitGrouped("player") and not IsUnitGroupLeader("player")) then
            jumpHelper:JumpToGroupLeader()
        else
            local zone = zoneList:GetCurrentZone()
            if(not zone) then -- TODO: remember last zone we have been in and jump there instead
                Print(L["INVALID_TARGET_ZONE"])
                PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
            else
                jumpHelper:JumpTo(zone)
            end
        end
        return
    elseif(not isTopResult) then
        local results = self.autocompleteResultProvider:GetResultList()
        local matches = GetTopMatchesByLevenshteinSubStringScore(results, input, 1, 1, true)

        if(#matches > 0) then
            local target = self.autocompleteResultProvider:GetResultFromLabel(matches[1])
            return self:SlashCommandCallback(target, true)
        end
    end

    chat:Print(L["INVALID_TARGET_ZONE"])
    PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
end

function SlashCommandHelper:GetPlayerResults()
    local playerList = {}
    local players = self.playerList:GetPlayerList()
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
    local zones = self.zoneList:GetZoneList()
    ZO_ClearTable(self.zoneLookup)

    for zoneName, zone in pairs(zones) do
        local count = self.playerList:GetPlayerCountForZone(zone)
        local label = zo_strformat(L["AUTOCOMPLETE_ZONE_LABEL_TEMPLATE"], zoneName, count)
        zoneList[zo_strlower(zoneName)] = label
        self.zoneLookup[label] = zoneName
    end

    return zoneList
end

function SlashCommandHelper:GetHouseResults()
    local houseList = {}
    local houses = self.zoneList:GetHouseList()
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
