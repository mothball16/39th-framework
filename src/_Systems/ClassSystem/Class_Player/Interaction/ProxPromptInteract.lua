local PPS = game:GetService("ProximityPromptService")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local TagObserver = require("@game/ReplicatedStorage/Packages/tag-observer")
local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local Consts = require("@game/ReplicatedStorage/Class_Framework/Core/Consts")

local PPI: Types.InteractionController = {
    isOpen = nil,
    activePrompt = Charm.atom(nil),
    maid = Maid.new(),
}


function PPI.Initialize(isOpen: Charm.Atom<boolean>)
    PPI.isOpen = isOpen

    -- initialize all prompts with text when entering
    PPI.maid:GiveTask(TagObserver.new(Consts.PROMPT_INTERACT_TAG, {
        onCreated = function(promptParent)
            local prompt = promptParent:FindFirstChild("Class_ProxPrompt")
            if not prompt then
                prompt = Instance.new("ProximityPrompt")
                prompt.Parent = promptParent
                prompt.Name = "Class_ProxPrompt"
                PPI.maid:GiveTask(prompt)
            end

            -- just confirm prompt text is correct if custom prompt values are used
            prompt.ObjectText = Consts.PROMPT_TEXT.OBJECT
            prompt.ActionText = Consts.PROMPT_TEXT.PASSIVE
        end
    }):Init())

    -- player triggered prompt? cause open
    PPI.maid:GiveTask(PPS.PromptTriggered:Connect(function(prompt)
        local isValidPrompt = prompt.Parent:HasTag(Consts.PROMPT_INTERACT_TAG)
        local promptAlreadyOpen = PPI.isOpen()
        local promptOpenedExternally = promptAlreadyOpen and PPI.activePrompt() ~= prompt
        if not isValidPrompt or promptOpenedExternally then
            return
        end

        local isCurrentPrompt = PPI.activePrompt() == prompt
        if isCurrentPrompt then
            PPI.isOpen(false)
            return
        end

        PPI.activePrompt(prompt)
        PPI.isOpen(true)
    end))

    -- player strayed too far from ACTIVE prompt? close selector
    PPI.maid:GiveTask(PPS.PromptHidden:Connect(function(prompt)
        if prompt == PPI.activePrompt() then
            PPI.isOpen(false)
        end
    end))

    -- selector was closed? clear active prompt
    PPI.maid:GiveTask(Charm.effect(function()
        if not PPI.isOpen() then
            PPI.activePrompt(nil)
        end
    end))

    -- update prompt text when active prompt changes
    PPI.maid:GiveTask(Charm.subscribe(PPI.activePrompt, function(prompt, oldPrompt)
        if prompt then
            prompt.ActionText = Consts.PROMPT_TEXT.ACTIVE
        else
            oldPrompt.ActionText = Consts.PROMPT_TEXT.PASSIVE
        end
    end))


end


function PPI.Destroy()
    PPI.maid:DoCleaning()
end

return PPI