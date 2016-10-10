local PlayerList = EasyTravel.PlayerList

local JUMP_TO = {
    [PlayerList.TYPE_GROUP] = JumpToGroupMember,
    [PlayerList.TYPE_FRIEND] = JumpToFriend,
    [PlayerList.TYPE_GUILD] = JumpToGuildMember,
}

local TargetHelper = ZO_Object:Subclass()

function TargetHelper:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function TargetHelper:Initialize()
    self.hasAttemptedJumpTo = {}
end

function TargetHelper:ClearJumpAttempts()
    ZO_ClearTable(self.hasAttemptedJumpTo)
end

function TargetHelper:JumpToNextTargetInZone(zone)
    local targets = PlayerList:GetSortedPlayersInZone(zone)
    for i = 1, #targets do
        local target = targets[i]
        if(not self.hasAttemptedJumpTo[target.displayName]) then
            self.hasAttemptedJumpTo[target.displayName] = true
            JUMP_TO[target.type](target.displayName)
            return true
        end
    end
    return false
end

function TargetHelper:JumpToPlayer(player)
    JUMP_TO[player.type](player.displayName)
end

function TargetHelper:JumpToGroupLeader()
    JumpToGroupLeader()
end

EasyTravel.TargetHelper = TargetHelper:New()
