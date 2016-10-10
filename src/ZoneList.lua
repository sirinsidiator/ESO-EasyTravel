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

    -- there is currently no good way to find the correct zones across languages, so we have to put them in a list
    local zoneIds = {3, 19, 20, 41, 57, 58, 92, 101, 103, 104, 108, 117, 280, 281, 347, 381, 382, 383, 534, 535, 537, 684, 816, 823, 888}
    for i = 1, #zoneIds do
        local zoneId = zoneIds[i]
        local zoneIndex = GetZoneIndex(zoneId)
        local zoneName = zo_strformat("<<1>>", GetZoneNameByIndex(zoneIndex))
        local zoneData = {
            id = zoneId,
            index = zoneIndex,
            name = zoneName
        }
        self.zoneById[zoneId] = zoneData
        self.zoneByIndex[zoneIndex] = zoneData
        self.zoneByName[zoneName] = zoneData
        self.autocompleteList[zo_strlower(zoneName)] = zoneName
    end
end

function ZoneList:SetMapByIndex(mapIndex)
    ZO_WorldMap_SetMapByIndex(mapIndex)
    return self.zoneByIndex[GetCurrentMapZoneIndex()]
end

function ZoneList:GetCurrentZone()
    local currentIndex = GetUnitZoneIndex("player")
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
