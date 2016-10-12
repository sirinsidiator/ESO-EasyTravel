local LIB_IDENTIFIER = "LibSlashCommander"
local lib = LibStub:NewLibrary(LIB_IDENTIFIER, 3)

if not lib then
    return -- already loaded and no upgrade necessary
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

function lib:Register(aliases, callback)
    local command = lib.Command:New()
    if(callback) then
        command:SetCallback(callback)
    end

    if(aliases) then
        if(type(aliases) == "table") then
            for i=1, #aliases do
                command:AddAlias(aliases[i])
            end
        else
            command:AddAlias(aliases)
        end
    end

    lib.globalCommand:RegisterSubCommand(command)
    return command
end

function lib:Unregister(command)
    lib.globalCommand:UnregisterSubCommand(command)
end

local function RunAutoCompletion(self, command, text)
    self.ignoreTextEntryChangedEvent = true
    lib.currentCommand = command
    self.textEntry:AutoCompleteTarget(text)
    self.ignoreTextEntryChangedEvent = false
end

local function GetCurrentCommandAndToken(command, input)
    local alias, newInput = input:match("(.-)%s+(.-)$")
    if(not alias or not lib.IsCommand(command)) then return command, input end
    local subCommand = command:GetSubCommandByAlias(alias)
    if(not subCommand) then return command, input end
    if(not newInput) then return subCommand, "" end
    return GetCurrentCommandAndToken(subCommand, newInput)
end

lib.GetCurrentCommandAndToken = GetCurrentCommandAndToken

local function Sanitize(value)
    return value:gsub("[-*+?^$().[%]%%]", "%%%0") -- escape meta characters
end

local function OnTextEntryChanged(self, text)
    if(self.ignoreTextEntryChangedEvent or not lib.globalCommand:ShouldAutoComplete(text)) then return end
    lib.currentCommand = nil

    local command, token = GetCurrentCommandAndToken(lib.globalCommand, text)
    if(not command or not lib.IsCommand(command)) then return end

    lib.lastInput = text:match(string.format("(.+)%%s+%s$", Sanitize(token)))
    if(command:ShouldAutoComplete(token)) then
        RunAutoCompletion(self, command, token)
        return true
    end
end

local function OnSetChannel()
    CHAT_SYSTEM.textEntry:CloseAutoComplete()
end

local function OnAutoCompleteEntrySelected(self, text)
    local command = lib.hasCustomResults
    if(command) then
        text = command:GetAutoCompleteResultFromDisplayText(text)
        if(lib.lastInput) then
            text = string.format("%s %s", lib.lastInput, text)
            lib.lastInput = nil
        else
            text = string.format("%s ", text)
        end
        StartChatInput(text)
        return true
    end
end

local function GetTopMatches(command, text)
    local results = command:GetAutoCompleteResults(text)
    local topResults = GetTopMatchesByLevenshteinSubStringScore(results, text, 1, lib.maxResults)
    if topResults then
        return unpack(topResults)
    end
end

local function GetAutoCompletionResults(original, self, text)
    local command = lib.currentCommand
    if(command) then
        lib.hasCustomResults = command
        return GetTopMatches(command, text)
    else
        lib.hasCustomResults = nil
        return original(self, text)
    end
end

local function Unload()
    CHAT_SYSTEM.OnTextEntryChanged = lib.oldOnTextEntryChanged
    CHAT_SYSTEM.SetChannel = lib.oldSetChannel
    CHAT_SYSTEM.OnAutoCompleteEntrySelected = lib.oldOnAutoCompleteEntrySelected
    CHAT_SYSTEM.textEntry.autoComplete.GetAutoCompletionResults = lib.oldGetAutoCompletionResults
    lib.globalCommand = nil
end

local function AutoCompleteSlashCommands()
    local results = {}
    for alias in pairs(SLASH_COMMANDS) do
        results[zo_strlower(alias)] = alias
    end
    for alias in pairs(CHAT_SYSTEM.switchLookup) do
        results[zo_strlower(alias)] = alias
    end
    return results
end

local function Load()
    lib.oldOnTextEntryChanged = CHAT_SYSTEM.OnTextEntryChanged
    lib.oldSetChannel = CHAT_SYSTEM.SetChannel
    lib.oldOnAutoCompleteEntrySelected = CHAT_SYSTEM.OnAutoCompleteEntrySelected
    lib.oldGetAutoCompletionResults = CHAT_SYSTEM.textEntry.autoComplete.GetAutoCompletionResults

    ZO_PreHook(CHAT_SYSTEM, "OnTextEntryChanged", OnTextEntryChanged)
    ZO_PreHook(CHAT_SYSTEM, "SetChannel", OnSetChannel)
    ZO_PreHook(CHAT_SYSTEM, "OnAutoCompleteEntrySelected", OnAutoCompleteEntrySelected)
    WrapFunction(CHAT_SYSTEM.textEntry.autoComplete, "GetAutoCompletionResults", GetAutoCompletionResults)

    local globalLookup = setmetatable({}, {
        __index = function(_, key)
            key = zo_strlower(key)
            return SLASH_COMMANDS[key] or CHAT_SYSTEM.switchLookup[key]
        end,
        __newindex = function(_, key, value)
            SLASH_COMMANDS[key] = value
        end
    })
    lib.globalCommand = lib.Command:New()
    lib.globalCommand.subCommandAliases = globalLookup
    lib.globalCommand:SetAutoComplete(AutoCompleteSlashCommands, "/")

    lib.Unload = Unload
end

lib.Init = function()
    lib.Init = function() end
    if(lib.Unload) then lib.Unload() end
    Load()
end
