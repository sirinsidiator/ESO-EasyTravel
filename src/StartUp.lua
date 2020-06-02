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

EasyTravel.RegisterForEvent = RegisterForEvent
EasyTravel.UnregisterForEvent = UnregisterForEvent
EasyTravel.WrapFunction = WrapFunction
EasyTravel.Print = Print

local function OnAddonLoaded(callback)
    local eventHandle = ""
    eventHandle = RegisterForEvent(EVENT_ADD_ON_LOADED, function(event, name)
        if(name ~= ADDON_NAME) then return end
        callback()
        UnregisterForEvent(event, name)
    end)
end

OnAddonLoaded(function()
    local L = EasyTravel.Localization
    local JumpHelper = EasyTravel.JumpHelper
    local ZoneList = EasyTravel.ZoneList

    local CANNOT_JUMP_TO = {
        [1] = true, -- Tamriel
        [24] = true, -- The Aurbis
        --TODO: [35] = true, -- Norg-Tzel
        [GetCyrodiilMapIndex()] = true,
        [GetImperialCityMapIndex()] = true,
    }

    local function ShowSubTargetMenu(subTargets, control)
        ClearMenu()

        for i = 1, #subTargets do
            local target = subTargets[i]
            AddCustomMenuItem(target.data.name, function() JumpHelper:JumpTo(target.data) end)
        end

        ShowMenu(control)
    end

    local function AttemptJumpTo(mapIndex, control)
        if(CANNOT_JUMP_TO[mapIndex]) then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, L["INVALID_TARGET_ZONE"])
            return false
        end

        local targetZone = ZoneList:SetMapByIndex(mapIndex)
        if(targetZone) then
            local subTargets = ZoneList:GetSubTargets(mapIndex)
            if(subTargets) then
                ShowSubTargetMenu(subTargets, control)
                return false
            else
                JumpHelper:JumpTo(targetZone)
                return true
            end
        end
    end

    local function CancelJump()
        CancelCast()
        zo_callLater(function()
            JumpHelper:CleanUp(false)
        end, 1)
    end

    EasyTravel.JumpTo = AttemptJumpTo
    EasyTravel.CancelJump = CancelJump

    ZO_PreHook("ZO_WorldMapLocationRowLocation_OnMouseUp", function(label, button, upInside)
        if(upInside and button == MOUSE_BUTTON_INDEX_RIGHT) then
            local data = ZO_ScrollList_GetData(label:GetParent())
            AttemptJumpTo(data.index, label)
            PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
            return true
        end
    end)
end)
