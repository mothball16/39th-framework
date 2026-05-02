local function CreateFont(family, weight, style)
    local f = Font.fromEnum(family)
    f.Weight = weight or Enum.FontWeight.Regular
    f.Style = style or Enum.FontStyle.Normal
    return f
end

-- https://coolors.co/0b1732-3556ac-fdfffc-c1292e-f1d302
return {
    Background = Color3.fromHex("0B1732"),
    BackgroundAlt = Color3.fromHex("122654"),
    AccentColor = Color3.fromHex("3556AC"),
    AccentColorAlt = Color3.fromHex("7388A6"),
    ColorWarning = Color3.fromHex("f1d302"),
    ColorError = Color3.fromHex("c1292e"),
    TextColor = Color3.fromHex("fdfffc"),
    TextColorDark = Color3.fromHex("122654"),

    fontH1 = CreateFont(Enum.Font.RobotoCondensed, Enum.FontWeight.Bold),
    fontH2 = CreateFont(Enum.Font.RobotoCondensed, Enum.FontWeight.SemiBold),
    fontH3 = CreateFont(Enum.Font.RobotoCondensed, Enum.FontWeight.Medium),
    fontNormal = CreateFont(Enum.Font.RobotoMono, Enum.FontWeight.Regular),
}