local NametagModule = {}

function NametagModule.HookPlayer(player: Player)
    local characterAdded = player.CharacterAdded:Connect(function(character)
        
    end)

    local characterRemoved = player.CharacterRemoving:Connect(function(character)
        
    end)
    
    return function()
        
    end
end

return NametagModule