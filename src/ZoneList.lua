local RegisterForEvent = EasyTravel.RegisterForEvent
local UnregisterForEvent = EasyTravel.UnregisterForEvent

local ZoneList = ZO_Object:Subclass()

function ZoneList:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function ZoneList:Initialize()
    self.zoneById = {}
    self.zoneByIndex = {}
    self.zoneByName = {}
    self.autocompleteList = {}

    -- CanJumpToPlayerInZone currently doesn't return the correct results, but should hopefully work in a future update
--    local zoneIndex = 1
--    while true do
--        local zoneName = GetZoneNameByIndex(zoneIndex)
--        if(zoneName == "") then break end
--
--        local zoneId = GetZoneId(zoneIndex)
--        local canJump, result = CanJumpToPlayerInZone(zoneId)
--        if(canJump) then
--            zoneName = zo_strformat("<<1>>", GetZoneNameByIndex(zoneIndex))
--            self:AddEntry(zoneId, zoneIndex, zoneName)
--        end
--        zoneIndex = zoneIndex + 1
--    end

    -- for now we have to put the zoneIds in a list
    local zoneIds = {3, 19, 20, 41, 57, 58, 92, 101, 103, 104, 108, 117, 280, 281, 347, 381, 382, 383, 534, 535, 537, 684, 816, 823, 888}
    for i = 1, #zoneIds do
        local zoneId = zoneIds[i]
        local zoneIndex = GetZoneIndex(zoneId)
        local zoneName = zo_strformat("<<1>>", GetZoneNameByIndex(zoneIndex))
        self:AddEntry(zoneId, zoneIndex, zoneName)
    end
end

function ZoneList:AddEntry(zoneId, zoneIndex, zoneName)
    local zoneData = {
        id = zoneId,
        index = zoneIndex,
        name = zoneName
    }
    self.zoneById[zoneId] = zoneData
    self.zoneByIndex[zoneIndex] = zoneData
    self.zoneByName[zoneName] = zoneData
    self.autocompleteList[zo_strlower(zoneData.name)] = zoneData.name
end

function ZoneList:SetMapByIndex(mapIndex)
    ZO_WorldMap_SetMapByIndex(mapIndex)
    return self.zoneByIndex[GetCurrentMapZoneIndex()]
end

function ZoneList:GetCurrentZone()
    SetMapToPlayerLocation()
    while not(GetMapType() == MAPTYPE_ZONE and GetMapContentType() ~= MAP_CONTENT_DUNGEON) do
        if (MapZoomOut() ~= SET_MAP_RESULT_MAP_CHANGED) then break end
    end
    local currentIndex = GetCurrentMapZoneIndex()
    return self.zoneByIndex[currentIndex]
end

function ZoneList:GetZoneByZoneIndex(zoneIndex)
    return self.zoneByIndex[zoneIndex]
end

function ZoneList:GetZoneByZoneId(zoneId)
    return self.zoneById[zoneId]
end

function ZoneList:GetZoneByZoneName(zoneName)
    return self.zoneByName[zo_strformat("<<1>>", zoneName)]
end

function ZoneList:HasZone(zoneName)
    return self.zoneByName[zo_strformat("<<1>>", zoneName)] ~= nil
end

function ZoneList:GetZoneList()
    return self.zoneByName
end

function ZoneList:GetZoneFromPartialName(partialZone)
    local results = GetTopMatchesByLevenshteinSubStringScore(self.autocompleteList, partialZone, 1, 1)
    if(#results == 0) then return end
    return self.zoneByName[results[1]]
end

EasyTravel.ZoneList = ZoneList:New()
