local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create = Vide.create

local function ClassCard(props: {
	bgImage: string,
    overlayFrameTransparency: number,
    overlayFrameColor: Color3,
    title: string,
    Activated: () -> (),
})
    return create "Frame" {
        Size = UDim2.fromScale(1, 1),

        create "UIAspectRatioConstraint" {
            AspectRatio = 3/2,
        },

        create "ImageLabel" {
            Size = UDim2.fromScale(1, 1),
            Image = props.bgImage,
            ScaleType = Enum.ScaleType.Fit,
        },

        create "Frame" {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = props.overlayFrameTransparency,
            BackgroundColor3 = props.overlayFrameColor,
        },
    
        create "TextLabel" {
            Size = UDim2.fromScale(1, 1),
            Text = props.title,
        },

        create "TextButton" {
            Size = UDim2.fromScale(1, 1),
            Text = "",
            BackgroundTransparency = 1,
            Activated = props.Activated,
        }
    }
end

return ClassCard