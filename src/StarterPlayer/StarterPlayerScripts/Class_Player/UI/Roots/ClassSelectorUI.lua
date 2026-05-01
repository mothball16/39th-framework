local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create = Vide.create


local VideCharm = require(Packages["vide-charm"])
local Maid = require(Packages.maid)

local UIComponents = script.Parent.Parent.Components
local ClassCard = require(UIComponents.ClassCard)

return function(props: {
	FactionConfigs: {[string]: any},
	PlayerAssignments: {[string]: any},
})
	return ClassCard({
		bgImage = "rbxassetid://1234567890",
		overlayFrameTransparency = 0.5,
		overlayFrameColor = Color3.fromRGB(0, 0, 0),
		title = "Class 1",
		Activated = function()
			print("Class 1 activated")
		end,
	})
end