local Main = script.Parent
local MainFrame = Main.Main

local TimeText = MainFrame.Time

local TIME_ZONE = -7

function formatTime()
	local date = os.date("!*t")
	local hour = (date.hour + TIME_ZONE) % 24
	local ampm = hour < 12 and "AM" or "PM"
	local timestamp = string.format("%02i:%02i %s", ((hour - 1) % 12) + 1, date.min, ampm)
	return timestamp
end

function formatLocalTime()
	local t = tick()

	local hours = math.floor(t / 3600) % 24
	local ampm = hours < 12 and "AM" or "PM"
	local mins = math.floor(t / 60) % 60
	local timestamp = string.format("%02i:%02i %s", ((hours - 1) % 12) + 1, mins, ampm)

	return timestamp
end

while true do
	local timestamp = formatTime()
	local localTimestamp = formatLocalTime()
	
	TimeText.Text = localTimestamp.." LOCAL | "..timestamp.." PST"
	
	wait(1)
end