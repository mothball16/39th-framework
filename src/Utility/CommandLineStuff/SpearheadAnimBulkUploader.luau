local AssetService = game:GetService("AssetService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

--[[
An ai made script modified by ai to bulk-upload spearhead animations.

(Warning: This works for 90% of the default animations because the script just uses hardcoded pattern matching to guess at which animation you want to upload to. Animations that don't match the pattern will drop themselves off in ServerStorage.OrphanedAnimations - just manually assign those, they've already been uploaded.)

If you don't want to do that, you can also just match the pattern:
- underscores are inserted between words, BoltClose is reworded to Close

Ex a) RifleReload --> Rifle_Reload
Ex b) RifleBoltClose --> Rifle_Close

Your word after the pattern is applied should correspond to one of the animation instances in the directory folder. Matching this pattern will also let you bulk upload non-default animations. 

Instructions
1. Turn on CreateAssetAsync Lua API in roblox studio beta features and restart studio if not already on

2. Check the top lines of the script to either upload to a group or upload to yourself

3. Below that, change the target directory to either R6 or R15 based off whether you're uploading to R6 or R15

4. Select the MODEL of each animation rig (Not the animsaves folder). For example, if I want to upload rifle animations, I will select ["Animation Rigs"].RifleAnims. You can select multiple at a time

5. Copy and run this script in the command line. Watch the output so you know when the script is done running - it will take a couple seconds per animation and will print out a report at the end when done

7. Boom! Most of the animation IDs will have already been assigned. for the ones that didn't, go check ServerStorage.OrphanedAnimations and manually assign the rest!!
]]


-- // 1. USER CONFIGURATION //
-- Set to a Group ID (number) to upload to a group. 
-- Set to nil (or comment out) to upload to your personal account.

local UPLOAD_TO_GROUP_ID = nil
local DIRECTORY = game.ReplicatedStorage:WaitForChild("SPH_Assets").Animations.R6
local KEYWORD_REPLACE = {
    ["BoltClose"] = "Close"
}

local DEBUG = false

-- // 2. SYSTEM SETUP //
local sessionResults = { success = {}, errors = {} }

local function findAnimSource(rig)
    -- Check inside the Rig (Legacy)
    local internal = rig:FindFirstChild("AnimSaves")
    if internal then return internal:GetChildren() end
    
    -- Check ServerStorage (Modern Studio)
    local rbxSaves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
    if rbxSaves and rbxSaves:FindFirstChild(rig.Name) then
        local ext = rbxSaves[rig.Name]:FindFirstChild("AnimSaves")
        if ext then return ext:GetChildren() end
    end
    return nil
end

-- // 3. UPLOAD PROCESS //
print("\n[Auto-Uploader] Starting Batch Process...")
local selected = Selection:Get()

if #selected == 0 then 
    warn("[Auto-Uploader] No Rigs selected! Please select models in the workspace.") 
    return 
end

for _, rig in pairs(selected) do
    local rigName = rig.Name
    local sequences = findAnimSource(rig)
    
    if sequences then
        -- Initialize table for this animal
        sessionResults.success[rigName] = {}
        
        for _, obj in pairs(sequences) do
            if obj:IsA("KeyframeSequence") then
                local params = {
                    Name = rigName .. " " .. obj.Name,
                    Description = "Auto-uploaded Animation",
                    CreatorType = UPLOAD_TO_GROUP_ID and Enum.AssetCreatorType.Group or Enum.AssetCreatorType.User,
                    CreatorId = UPLOAD_TO_GROUP_ID
                }

                -- Tuple Capture: success, statusEnum, assetId
                local pcallSuccess, statusEnum, assetId = pcall(function()
                    if DEBUG then
                        return Enum.CreateAssetResult.Success, 1
                    end
                    return AssetService:CreateAssetAsync(obj, Enum.AssetType.Animation, params)
                end)

                if pcallSuccess and statusEnum == Enum.CreateAssetResult.Success then
                    local finalId = "rbxassetid://" .. tostring(assetId)
                    sessionResults.success[rigName][obj.Name] = finalId
                    print(string.format(" [+] Uploaded: %s -> %s (%s)", rigName, obj.Name, tostring(assetId)))
                else
                    local errMessage = pcallSuccess and tostring(statusEnum) or tostring(statusEnum)
                    table.insert(sessionResults.errors, { animal = rigName, anim = obj.Name, err = errMessage })
                    warn(string.format(" [!] FAILED: %s -> %s | %s", rigName, obj.Name, errMessage))
                end
            end
        end
    else
        warn("[Skip] No animations found for: " .. rigName)
    end
end

-- // 4. FOLDER CREATION (The Consumer) //
print("\n[Auto-Uploader] Organizing Assets...")
sessionResults.orphaned = {}

for animal, anims in pairs(sessionResults.success) do    
    for name, id in pairs(anims) do
        local newName = name

        for search, replace in pairs(KEYWORD_REPLACE) do
            newName = string.gsub(newName, search, replace)
        end
        newName = string.match(newName, "^%s*(.-)%s*$") -- Trim whitespace

        -- For every uppercase letter but the first, add a _ before it (RifleReload -> Rifle_Reload)
        newName = string.gsub(newName, "(%l)(%u)", "%1_%2")

        -- Search for a valid Animation instance within DIRECTORY that matches the name
        local validAnimation = DIRECTORY:FindFirstChild(newName)

        -- If there is a valid Animation instance, replace the AnimationId with the id of this animation
        if validAnimation and validAnimation:IsA("Animation") then
            validAnimation.AnimationId = id
        else
            -- Else, store the animation name and animation id in an orphaned animation folder and print them out in the final report
            local orphanedFolder = ServerStorage:FindFirstChild("OrphanedAnimations")
            if not orphanedFolder then
                orphanedFolder = Instance.new("Folder")
                orphanedFolder.Name = "OrphanedAnimations"
                orphanedFolder.Parent = ServerStorage
            end
            
            local orphanedAnim = Instance.new("Animation")
            orphanedAnim.Name = newName
            orphanedAnim.AnimationId = id
            orphanedAnim.Parent = orphanedFolder
            
            table.insert(sessionResults.orphaned, { animal = animal, anim = newName, id = id })
        end
    end
end

-- // 5. FINAL REPORT //
print("\n------------------------------------------------")
print("REPORT")


if #sessionResults.errors > 0 then
    warn("ERRORS DETECTED: " .. #sessionResults.errors)
    for _, e in ipairs(sessionResults.errors) do
        warn(string.format(" > %s (%s): %s", e.animal, e.anim, e.err))
    end
else
    print("Success: All animations uploaded cleanly.")
end

if #sessionResults.orphaned > 0 then
    warn("\nORPHANED ANIMATIONS: " .. #sessionResults.orphaned)
    for _, o in ipairs(sessionResults.orphaned) do
        warn(string.format(" > %s (%s): %s", o.animal, o.anim, o.id))
    end
end

-- Optional: Print Backup Table
print("\n[Backup Table Data]")
local backupStr = "local animalAnims = {\n"
for animal, anims in pairs(sessionResults.success) do
    backupStr = backupStr .. string.format('    ["%s"] = {\n', animal)
    for name, id in pairs(anims) do
        backupStr = backupStr .. string.format('        ["%s"] = "%s",\n', name, id)
    end
    backupStr = backupStr .. "    },\n"
end
backupStr = backupStr .. "}"
print(backupStr)
print("------------------------------------------------")