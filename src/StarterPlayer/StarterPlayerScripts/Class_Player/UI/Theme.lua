local function CreateFont(family, weight, style)
    local f = Font.fromEnum(family)
    f.Weight = weight or Enum.FontWeight.Regular
    f.Style = style or Enum.FontStyle.Normal
    return f
end

return {
    Background = Color3.fromRGB(30, 30, 30),
    BackgroundAlt = Color3.fromRGB(60, 60, 60),
    AccentColor = Color3.fromRGB(0, 120, 215),
    AccentColorAlt = Color3.fromRGB(32, 62, 87),
    TextColor = Color3.fromRGB(255, 255, 255),

    fontH1 = CreateFont(Enum.Font.RobotoCondensed, Enum.FontWeight.Bold),
    fontH2 = CreateFont(Enum.Font.RobotoCondensed, Enum.FontWeight.SemiBold),
    fontH3 = CreateFont(Enum.Font.RobotoCondensed, Enum.FontWeight.Medium),
    fontNormal = CreateFont(Enum.Font.Code, Enum.FontWeight.Regular),
}