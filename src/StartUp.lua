local ADDON_NAME = "EasyTravel"
EasyTravel = {}

local nextEventHandleIndex = 1

local function RegisterForEvent(event, callback)
    local eventHandleName = ADDON_NAME .. nextEventHandleIndex
    EVENT_MANAGER:RegisterForEvent(eventHandleName, event, callback)
    nextEventHandleIndex = nextEventHandleIndex + 1
    return eventHandleName
end

local function UnregisterForEvent(event, name)
    EVENT_MANAGER:UnregisterForEvent(name, event)
end

local function WrapFunction(object, functionName, wrapper)
    if(type(object) == "string") then
        wrapper = functionName
        functionName = object
        object = _G
    end
    local originalFunction = object[functionName]
    object[functionName] = function(...) return wrapper(originalFunction, ...) end
end

local function Print(message, ...)
    df("[%s] %s", ADDON_NAME, message:format(...))
end

local function OnAddonLoaded(callback)
    local eventHandle = ""
    eventHandle = RegisterForEvent(EVENT_ADD_ON_LOADED, function(event, name)
        if(name ~= ADDON_NAME) then return end
        callback()
        UnregisterForEvent(event, name)
    end)
end

OnAddonLoaded(function()
    local TYPE_GROUP = 1
    local TYPE_FRIEND = 2
    local TYPE_GUILD = 3
    local JUMP_TO = {
        [TYPE_GROUP] = JumpToGroupMember,
        [TYPE_FRIEND] = JumpToFriend,
        [TYPE_GUILD] = JumpToGuildMember,
    }

    local function ByTypeCpAndLevel(a, b)
        if(a.type == b.type) then
            if(a.cp > 0 or b.cp > 0) then
                return b.cp < a.cp
            else
                return b.level < a.level
            end
        end
        return a.type < b.type
    end

    local STATE_READY = 1
    local STATE_REQUESTING_JUMP = 2
    local STATE_STARTED_JUMP = 3
    local STATE_JUMP_REQUEST_FAILED = 4
    local STATE_JUMP_FAILED_NEED_TO_WAIT = 5
    local currentState = STATE_READY

    local jumpAttempted = {}
    local function JumpTo(targetZoneName)
        local myAlliance = GetUnitAlliance("player")
        local jumpTargets = {}
        local collected = {}
        collected[GetDisplayName()] = true -- prevent adding ourself as target

        local function AddJumpTarget(name, level, cp, type)
            jumpTargets[#jumpTargets + 1] = {name = name, level = level, cp = cp, type = type}
            collected[name] = true
        end

        -- collect jump targets from group
        for i = 1, GetGroupSize() do
            local unitTag = GetGroupUnitTagByIndex(i)
            local displayName = GetUnitDisplayName(unitTag)
            if(not collected[displayName] and IsUnitOnline(unitTag) and GetUnitAlliance(unitTag) == myAlliance and GetUnitZone(unitTag) == targetZoneName) then
                AddJumpTarget(displayName, GetUnitLevel(unitTag), GetUnitChampionPoints(unitTag), TYPE_GROUP)
            end
        end

        -- collect jump targets from friend list
        for i = 1, GetNumFriends() do
            local displayName, _, status = GetFriendInfo(i)
            local hasChar, _, zoneName, _, alliance, level, cp = GetFriendCharacterInfo(i)
            if(hasChar and not collected[displayName] and status ~= PLAYER_STATUS_OFFLINE and alliance == myAlliance and zoneName == targetZoneName) then
                AddJumpTarget(displayName, level, cp, TYPE_FRIEND)
            end
        end

        -- collect jump targets from guild rosters
        for g = 1, GetNumGuilds() do
            local guildId = GetGuildId(g)
            for i = 1, GetNumGuildMembers(guildId) do
                local displayName, _, _, status = GetGuildMemberInfo(guildId, i)
                local hasChar, _, zoneName, _, alliance, level, cp = GetGuildMemberCharacterInfo(guildId, i)
                if(hasChar and not collected[displayName] and status ~= PLAYER_STATUS_OFFLINE and alliance == myAlliance and zoneName == targetZoneName) then
                    AddJumpTarget(displayName, level, cp, TYPE_GUILD)
                end
            end
        end

        if(#jumpTargets > 0) then
            table.sort(jumpTargets, ByTypeCpAndLevel)

            if(currentState == STATE_READY) then
                Print("Traveling to %s", targetZoneName)
            end

            currentState = STATE_REQUESTING_JUMP
            for i = 1, #jumpTargets do
                local target = jumpTargets[i]
                if(not jumpAttempted[target.name]) then
                    jumpAttempted[target.name] = true
                    JUMP_TO[target.type](target.name)
                    return
                end
            end
        end
        Print("No suitable jump target found for %s", targetZoneName)
    end

    local EVENT_NAMESPACE1 = ADDON_NAME
    local EVENT_NAMESPACE2 = ADDON_NAME .. "2"

    local function Cleanup()
        Print("Cleaning Up")
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE1, EVENT_COMBAT_EVENT)
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE2, EVENT_COMBAT_EVENT)
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE1, EVENT_SOCIAL_ERROR)
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE1, EVENT_WEAPON_PAIR_LOCK_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE1, EVENT_PLAYER_DEACTIVATED)
        currentState = STATE_READY
    end

    local currentTargetZone
    local RECALL_ABILITY_ID = 6811
    local characterName = GetRawUnitName("player")
    local function HandleCombatEvents(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
        if(targetName == characterName) then
            currentState = STATE_STARTED_JUMP
            Print("Starting jump")
        end
    end

    local function HandleCombatEventErrors(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
        if(targetName == characterName) then
            if(result == ACTION_RESULT_BUSY) then
                currentState = STATE_JUMP_FAILED_NEED_TO_WAIT
                Print("Jump has been interrupted, need to wait for current jump to end")
            elseif(result == ACTION_RESULT_FAILED) then
                Print("Jump has ended, trying again")
                JumpTo(currentTargetZone)
            else
                Print("Jump has been interrupted, unhandled result: %d, %s", result, GetString("SI_ACTIONRESULT", result))
                Cleanup()
            end
        end
    end

    local function HandleWeaponPairLockState(eventCode, locked)
        if(currentState == STATE_STARTED_JUMP and not locked) then
            Print("Jump has been cancelled")
            Cleanup()
        end
    end

    local IS_SOCIAL_ERROR_JUMP_RELATED = {
        [SOCIAL_RESULT_CHARACTER_NOT_FOUND] = true,
        [SOCIAL_RESULT_NOT_GROUPED] = true,
        [SOCIAL_RESULT_CANT_JUMP_SELF] = true,
        [SOCIAL_RESULT_NO_LOCATION] = true,
        [SOCIAL_RESULT_DESTINATION_FULL] = true,
        [SOCIAL_RESULT_NO_JUMP_IN_COMBAT] = true,
        [SOCIAL_RESULT_NOT_SAME_GROUP] = true,
        [SOCIAL_RESULT_WRONG_ALLIANCE] = true,
        [SOCIAL_RESULT_JUMPS_EXIT_DISABLED] = true,
        [SOCIAL_RESULT_NO_JUMP_CHAMPION_RANK] = true,
        [SOCIAL_RESULT_JUMP_ENTRY_DISABLED] = true,
        [SOCIAL_RESULT_NOT_IN_SAME_GROUP] = true,
        [SOCIAL_RESULT_NO_INTRA_CAMPAIGN_JUMPS_ALLOWED] = true,
        [SOCIAL_RESULT_BEING_ARRESTED] = true,
        [SOCIAL_RESULT_CANT_JUMP_INVALID_TARGET] = true,
    }

    local CAN_RECOVER_FROM_SOCIAL_ERROR = {
        [SOCIAL_RESULT_CHARACTER_NOT_FOUND] = true,
        [SOCIAL_RESULT_NOT_GROUPED] = true,
        [SOCIAL_RESULT_CANT_JUMP_SELF] = true,
        [SOCIAL_RESULT_NO_LOCATION] = true,
        [SOCIAL_RESULT_NOT_SAME_GROUP] = true,
        [SOCIAL_RESULT_WRONG_ALLIANCE] = true,
        [SOCIAL_RESULT_NOT_IN_SAME_GROUP] = true,
        [SOCIAL_RESULT_CANT_JUMP_INVALID_TARGET] = true,
    }

    local function HandleSocialErrors(eventCode, error)
        if(IS_SOCIAL_ERROR_JUMP_RELATED[error]) then
            if(CAN_RECOVER_FROM_SOCIAL_ERROR[error]) then
                currentState = STATE_JUMP_REQUEST_FAILED
                JumpTo(currentTargetZone)
            else
                Cleanup()
            end
        end
    end

    local CANNOT_JUMP_TO = {
        [1] = true, -- Tamriel
        [24] = true, -- The Aurbis
        [GetCyrodiilMapIndex()] = true,
        [GetImperialCityMapIndex()] = true,
    }

    local function AttemptJumpTo(mapIndex)
        if(currentState ~= STATE_READY) then
            Print("Cannot jump, already trying to jump to %s", currentTargetZone)
            return false
        end
        if(CANNOT_JUMP_TO[mapIndex]) then
            Print("Cannot jump, invalid target zone")
            return false
        end

        Print("Attempting Jump")

        ZO_WorldMap_SetMapByIndex(mapIndex)
        jumpAttempted = {}
        currentTargetZone = GetZoneNameByIndex(GetCurrentMapZoneIndex())

        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE1, EVENT_COMBAT_EVENT, HandleCombatEvents)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE1, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_BEGIN)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE1, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, RECALL_ABILITY_ID)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE1, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE1, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_IN_GAMEPAD_PREFERRED_MODE, false)

        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE2, EVENT_COMBAT_EVENT, HandleCombatEventErrors)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE2, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, RECALL_ABILITY_ID)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE2, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, true)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE2, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_IN_GAMEPAD_PREFERRED_MODE, false)

        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE1, EVENT_SOCIAL_ERROR, HandleSocialErrors)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE1, EVENT_WEAPON_PAIR_LOCK_CHANGED, HandleWeaponPairLockState)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE1, EVENT_PLAYER_DEACTIVATED, Cleanup)

        JumpTo(currentTargetZone)
        return true
    end

    EasyTravel.JumpTo = AttemptJumpTo

    ZO_PreHook("ZO_WorldMapLocationRowLocation_OnMouseUp", function(label, button, upInside)
        if(upInside and button == MOUSE_BUTTON_INDEX_RIGHT) then
            local data = ZO_ScrollList_GetData(label:GetParent())
            if(AttemptJumpTo(data.index)) then
                SCENE_MANAGER:Hide(WORLD_MAP_SCENE:GetName())
            end
            PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
            return true
        end
    end)
end)
