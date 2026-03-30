--[[       
INTERACTIVE SYSTEM
Vehicle Spawner local script
1.4.2

based on an old Order of Cobalt script.

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local players = game:GetService("Players")
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local player = players.LocalPlayer

--// Folders
local assets = replicatedStorage.INTERACT_Assets
local modules = assets.Modules

local vicConfig = require(modules.VehicleSpawner.SpawnLimits)
local event = assets.Events.VehicleSpawn

local vehicleSamples = assets.VehicleStorage
local vehicles = game.Workspace.Vehicles
local gui = script.Parent

local cameraOffset = Vector3.new(0, 6, 25)

local selectedCamConnection
local selectedCam
local selectedVic
local selectedVicInfo
local selectedPreviewVic
local used = false

--// functions
local function CameraSetup()
	local camera = selectedCam

	camera.CameraType = Enum.CameraType.Scriptable
	local rotationAngle = Instance.new("NumberValue")
	local tweenComplete = false

	local function updateCamera()
		if not selectedPreviewVic or not selectedCam then return end
		local targetPOS = selectedPreviewVic:GetPivot()
		local rotatedCFrame = CFrame.Angles(0, math.rad(rotationAngle.Value), 0)
		rotatedCFrame = CFrame.new(targetPOS.Position) * rotatedCFrame
		camera.Focus = targetPOS
		camera.CFrame = rotatedCFrame:ToWorldSpace(CFrame.new(cameraOffset))
		camera.CFrame = CFrame.new(camera.CFrame.Position, targetPOS.Position)
	end

	--Set up and start rotation tween
	local tweenInfo = TweenInfo.new(20, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	local tween = tweenService:Create(rotationAngle, tweenInfo, {Value=360})
	tween.Completed:Connect(function()
		tweenComplete = true
	end)
	tween:Play()

	--Update camera position while tween runs
	selectedCamConnection = runService.RenderStepped:Connect(function()
		if tweenComplete == false then
			updateCamera()
		end
	end)
end

function ViewportSetup(ViewportFrame, Vic)
	local currentCam  

	local oldVic = ViewportFrame:FindFirstChild("PreviewVic")
	if oldVic then oldVic:Destroy() end
	if not Vic then return end

	local newVic = Vic:Clone()
	newVic.Name = "PreviewVic"
	newVic.Parent = ViewportFrame

	local oldCamera = ViewportFrame:FindFirstChild("PreviewCam")
	if oldCamera then
		ViewportFrame.CurrentCamera = oldCamera
		currentCam = oldCamera 
	else 
		local newCamera = Instance.new("Camera")
		ViewportFrame.CurrentCamera = newCamera
		newCamera.Name = "PreviewCam"
		newCamera.Parent = ViewportFrame
		currentCam = newCamera
	end

	if not selectedPreviewVic and not selectedCam then
		selectedPreviewVic = newVic
		selectedCam = currentCam 
		if selectedCamConnection then selectedCamConnection:Disconnect() end
		CameraSetup(currentCam)
	else
		selectedPreviewVic = newVic
		selectedCam = currentCam
	end 
end

local function LoadVic(vehicle, vehicleEntry)
	local vicCount = event:InvokeServer("Count", vehicle)
	gui.Frame.VicInfo.Info_Slots.Text = (vehicleEntry.SpawnLimit ~= nil and vicCount[2]-vicCount[1].."/"..vicCount[2].." vehicles left.") or ""
	gui.Frame.VicInfo.Info_Slots.Visible = vicCount[2] ~= nil

	gui.Frame.VicInfo.Info_Name.Text = vehicleEntry.DisplayName or vehicle
	gui.Frame.VicInfo.Info_Description.Text = vehicleEntry.Description or ""
end

local function SelectEntry(vehicle)
	local vehicleEntry = vicConfig.Info[vehicle]
	local vehicleModel = vehicleSamples:FindFirstChild(vehicle)
	if not vehicleEntry then warn("VehicleSpawner_Local: "..vehicle.." has no entry in the module settings!"); return end
	if not vehicleModel then warn("VehicleSpawner_Local: "..vehicle.." has no sample vehicle!"); return end

	selectedVic = vehicleModel
	selectedVicInfo = vehicleEntry
	LoadVic(vehicle, vehicleEntry)
	ViewportSetup(gui.Frame.VicInfo.Preview.ViewportFrame, vehicleModel) 
end

local function SetupUI(spawnerConfig, spawnerPos, spawnerSize, spawnerModel)
	--Set up exit button, in case the system errors
	gui.Frame.Button_Exit.Activated:Connect(function()
		used = true
		event:InvokeServer("Exit", gui)
	end)

	--Set up the buttons
	for each, vehicle:string in spawnerConfig.VehicleList do
		local vehicleEntry = vicConfig.Info[vehicle]
		local vehicleModel = vehicleSamples:FindFirstChild(vehicle)
		if not vehicleEntry then warn("VehicleSpawner_Local: "..vehicle.." has no entry in the module settings!"); continue end
		if not vehicleModel then warn("VehicleSpawner_Local: "..vehicle.." has no sample vehicle!"); continue end

		local newUI = gui.Frame.VicList.ScrollingFrame.UIListLayout.Example:Clone()
		newUI.Parent = gui.Frame.VicList.ScrollingFrame
		newUI.Name = vehicle
		newUI.VehicleName.Text = vehicleEntry.ShortName or vehicle
		newUI.VehicleImg.Image = "rbxassetid://"..(vehicleEntry.ImageID or 12338080417)
		newUI.Button_Load.Activated:Connect(function()
			if used then return end

			selectedVic = vehicleModel
			selectedVicInfo = vehicleEntry
			LoadVic(vehicle, vehicleEntry)
			ViewportSetup(gui.Frame.VicInfo.Preview.ViewportFrame, vehicleModel) 
		end)
	end
	SelectEntry(spawnerConfig.VehicleList[1])

	--Set up the important buttons
	gui.Frame.VicInfo.Button_Spawn.UIStroke.Color = Color3.new(0.698039, 0.768627, 1)
	gui.Frame.VicInfo.Button_Spawn.Activated:Connect(function()
		if used or not selectedVic or not selectedVicInfo then return end

		local vicCount = event:InvokeServer("Count", selectedVic.Name)
		gui.Frame.VicInfo.Info_Slots.Text = (selectedVicInfo.SpawnLimit ~= nil and vicCount[2]-vicCount[1].."/"..vicCount[2].." vehicles left.") or ""
		gui.Frame.VicInfo.Info_Slots.Visible = vicCount[2] ~= nil

		--spawnerData: {Position:Vector3, Size:Vector3, Object:Model}
		local spawnerData = {Position = spawnerPos, Size =  spawnerSize, Object = spawnerModel}
		local result = event:InvokeServer("Spawn", selectedVic, spawnerData)
		if result then
			used = true
			gui.Success:Play()
			event:InvokeServer("Exit", gui)
		else
			used = true
			gui.Error:Play()
			
			local checkCooldown = selectedVic:FindFirstChild("RespawnTimer")
			if checkCooldown then
				local deltaTime = checkCooldown:GetAttribute("Duration") - math.ceil(os.clock() - checkCooldown.Value)
				gui.Frame.VicInfo.Button_Spawn.Text = "WAIT "..deltaTime.."s"
				gui.Frame.VicInfo.Button_Spawn.UIStroke.Color = Color3.new(1, 0.407843, 0.290196)
			else
				gui.Frame.VicInfo.Button_Spawn.Text = "CAN'T SPAWN"
				gui.Frame.VicInfo.Button_Spawn.UIStroke.Color = Color3.new(1, 0.407843, 0.290196)
			end
			task.wait(1)
			gui.Frame.VicInfo.Button_Spawn.Text = "SPAWN"
			gui.Frame.VicInfo.Button_Spawn.UIStroke.Color = Color3.new(0.698039, 0.768627, 1)
			used = false
		end
	end)
end

local spawnerConfig = require(script.SpawnerSettings.Value) 
local spawnerPos = script.SpawnPos.Value
local spawnerSize = script.SpawnSize.Value
local spawnerModel = script.Spawner.Value
SetupUI(spawnerConfig, spawnerPos, spawnerSize, spawnerModel)
