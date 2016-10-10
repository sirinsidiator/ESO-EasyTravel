local lib = LibStub("LibSlashCommander")

local ERROR_INVALID_TYPE = "Invalid argument type"
local ERROR_HAS_NO_PARENT = "Command does not have a parent"
local ERROR_ALREADY_HAS_PARENT = "Command already has a parent"
local ERROR_CIRCULAR_HIERARCHY = "Circular hierarchy detected"
local ERROR_AUTOCOMPLETE_NOT_ACTIVE = "Tried to get autocomplete results while it's disabled"
local ERROR_AUTOCOMPLETE_RESULT_NOT_VALID = "Autocomplete provider returned invalid result type"
local ERROR_ALREADY_HAS_ALIAS = "Tried to overwrite existing command alias"
local ERROR_CALLED_WITHOUT_CALLBACK = "Tried to call command while no callback is set"

local Command = ZO_Object:Subclass()

local function AssertIsType(value, typeName)
    assert(type(value) == typeName, ERROR_INVALID_TYPE)
end

local function IsCommand(command)
    return getmetatable(command) == Command
end
lib.IsCommand = IsCommand

local function AssertIsCommand(command)
    assert(IsCommand(command), ERROR_INVALID_TYPE)
end

local function IsCallable(func)
    return type(func) == "function" or type((getmetatable(func) or {}).__call) == "function"
end

function Command:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function Command:Initialize()
    self.callback = nil

    -- make the table callable
    local meta = getmetatable(self)
    meta.__call = function(self, input)
        if(type(input) == "string" and next(self.subCommandAliases)) then
            local alias, newInput = input:match("(.-)%s+(.-)$")
            if(not alias) then alias = input end
            local subCommand = self.subCommandAliases[alias]
            if(subCommand) then
                subCommand(newInput)
                return
            end
        end
        if(self.callback) then
            self.callback(input)
        else
            error(ERROR_CALLED_WITHOUT_CALLBACK)
        end
    end

    self.aliases = {}
    self.subCommands = {}
    self.subCommandAliases = {}
    self.autocomplete = nil
end

function Command:SetCallback(callback)
    if(callback ~= nil) then
        assert(IsCallable(callback), ERROR_INVALID_TYPE)
    end
    self.callback = callback
end

function Command:GetCallback(callback)
    return self.callback
end

function Command:AddAlias(alias)
    AssertIsType(alias, "string")
    self.aliases[alias] = self
    if(self.parent ~= nil) then
        self.parent:RegisterSubCommandAlias(alias, self)
    end
end

function Command:HasAlias(alias)
    if(self.aliases[alias]) then
        return true
    end
    return false
end

function Command:RemoveAlias(alias)
    self.aliases[alias] = nil
    if(self.parent ~= nil) then
        self.parent:UnregisterSubCommandAlias(alias)
    end
end

function Command:HasAncestor(parent)
    while parent ~= nil do
        if(parent == self) then return true end
        parent = parent.parent
    end
    return false
end

function Command:SetParentCommand(command)
    if(command == nil) then
        assert(self.parent, ERROR_HAS_NO_PARENT)
        for alias in pairs(self.aliases) do
            self.parent:UnregisterSubCommandAlias(alias)
        end
        self.parent = nil
    else
        assert(not self.parent, ERROR_ALREADY_HAS_PARENT)
        AssertIsCommand(command)
        assert(not self:HasAncestor(command), ERROR_CIRCULAR_HIERARCHY)
        self.parent = command
        for alias in pairs(self.aliases) do
            self.parent:RegisterSubCommandAlias(alias, self)
        end
    end
end

function Command:RegisterSubCommand(command)
    if(command == nil) then
        command = Command:New()
    end
    AssertIsCommand(command)
    command:SetParentCommand(self)
    self.subCommands[command] = command
    if(not self.autocomplete) then
        self:SetAutoComplete(true)
    end
    return command
end

function Command:HasSubCommand(command)
    if(self.subCommands[command]) then
        return true
    end
    return false
end

function Command:UnregisterSubCommand(command)
    command:SetParentCommand(nil)
    self.subCommands[command] = nil
    if(self.autocomplete == self.AutoCompleteSubCommands and not next(self.subCommands)) then
        self:SetAutoComplete(false)
    end
end

function Command:RegisterSubCommandAlias(alias, command)
    AssertIsType(alias, "string")
    AssertIsCommand(command)
    assert(not self.subCommandAliases[alias], ERROR_ALREADY_HAS_ALIAS)
    self.subCommandAliases[alias] = command
end

function Command:HasSubCommandAlias(alias)
    if(self.subCommandAliases[alias]) then
        return true
    end
    return false
end

function Command:GetSubCommandByAlias(alias)
    return self.subCommandAliases[alias]
end

function Command:UnregisterSubCommandAlias(alias)
    self.subCommandAliases[alias] = nil
end

function Command:AutoCompleteSubCommands()
    local results = {}
    for alias in pairs(self.subCommandAliases) do
        results[zo_strlower(alias)] = alias
    end
    return results
end

function Command:AutoCompleteTable()
    local data = self.autocompleteData
    local results = {}
    for i = 1, #data do
        results[zo_strlower(data[i])] = data[i]
    end
    return results
end

function Command:SetAutoComplete(provider, prefix, lookup)
    self.autocomplete = nil
    self.autocompleteData = nil
    self.autocompletePrefix = nil
    self.autocompleteLookup = nil

    if(prefix ~= nil) then
        AssertIsType(prefix, "string")
        self.autocompletePrefix = prefix
    end

    if(lookup ~= nil) then
        assert(IsCallable(lookup), ERROR_INVALID_TYPE)
        self.autocompleteLookup = lookup
    end

    if(provider == nil or provider == false) then
    -- do nothing
    elseif(provider == true) then
        self.autocomplete = self.AutoCompleteSubCommands
    elseif(IsCallable(provider)) then
        self.autocomplete = provider
    elseif(type(provider) == "table") then
        self.autocomplete = self.AutoCompleteTable
        self.autocompleteData = provider
    else
        error(ERROR_INVALID_TYPE)
    end
end

function Command:ShouldAutoComplete(token)
    if(not self.autocomplete) then
        return false
    elseif(self.autocompletePrefix) then
        return token:sub(1, #self.autocompletePrefix) == self.autocompletePrefix
    end
    return true
end

function Command:GetAutoCompleteResults()
    assert(self.autocomplete ~= nil, ERROR_AUTOCOMPLETE_NOT_ACTIVE)
    local results = self:autocomplete()
    assert(type(results) == "table", ERROR_AUTOCOMPLETE_RESULT_NOT_VALID)
    return results
end

function Command:GetAutoCompleteResultFromDisplayText(text)
    assert(self.autocomplete ~= nil, ERROR_AUTOCOMPLETE_NOT_ACTIVE)
    AssertIsType(text, "string")
    if(self.autocompleteLookup ~= nil) then
        local result = self.autocompleteLookup(text)
        assert(type(result) == "string", ERROR_AUTOCOMPLETE_RESULT_NOT_VALID)
        return result
    end
    return text
end

lib.Command = Command
lib.Init()
