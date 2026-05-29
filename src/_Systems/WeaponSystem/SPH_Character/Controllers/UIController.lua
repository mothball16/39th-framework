--[[
TODO: the UIController is currently ugly as shit because it's mixing imperative and declarative UI and is generally holding onto legacy code.
if we could pivot strictly to declarative UI, we can make this a lot cleaner and more maintainable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local assets = Access.assets
local config = Access.config

local CharacterStateModule = require(Framework.State.CharacterState)
local WeaponStateModule = require(Framework.State.WeaponState)

local WeaponPrefs = require(Framework.Weapons.WeaponPrefsClient)

local FIRE_MODE_NAMES = { "[SAFE]", "[SEMI]", "[AUTO]", "[BURST]", "[UBGL]", "[MANUAL]" }

local UIController = {}
UIController.__index = UIController

type self = {
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
	ammoUI: Frame,
	ammoCounter: TextLabel,
	ammoPoolUI: TextLabel,
	bulletType: TextLabel,
	fireMode: TextLabel,
	chambered: TextLabel,
	attachmentFrame: Frame,
	aimSens: TextLabel,
	ubglAmmo: IntValue?,
}

export type UIController = typeof(setmetatable({} :: self, UIController))

local function splitNumber(number: number): { string }
	local numberStr = tostring(number)
	local leadingZeros = ""
	local restOfNumber = numberStr

	local totalLength = 3
	local leadingZerosCount = totalLength - #numberStr

	if leadingZerosCount > 0 then
		for i = 1, leadingZerosCount do
			leadingZeros = leadingZeros .. "0"
		end
	end

	if #numberStr > totalLength then
		restOfNumber = numberStr:sub(-totalLength)
		leadingZeros = ""
	end

	return { leadingZeros, restOfNumber }
end

function UIController.new(params: {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
}): UIController
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local mainUI = playerGui:WaitForChild("SPH_UI")
	local ammoUI = mainUI:WaitForChild("Ammo")
	mainUI:WaitForChild("Version").Text = "Spearhead " .. config.version

	local ammoCounter = ammoUI.AmmoFrame.Frame.MagAmmo
	local ammoPoolUI = ammoUI.AmmoFrame.Frame.AmmoPool
	local bulletType = ammoUI.Other.AmmoType
	local fireMode = ammoUI.FiremodeFrame.Firemode
	local chambered = ammoUI.AmmoFrame.Frame.Chambered
	local attachmentFrame = ammoUI:WaitForChild("AttachmentFrame")
	local aimSens = ammoUI.FiremodeFrame.Sens

	attachmentFrame.Flashlight.KeybindText.Text =
		"[" .. UserInputService:GetStringForKeyCode(config.toggleFlashlight[1]) .. "]"
	attachmentFrame.Laser.KeybindText.Text =
		"[" .. UserInputService:GetStringForKeyCode(config.toggleLaser[1]) .. "]"

	if UserInputService.TouchEnabled then
		ammoUI.Position = UDim2.new(1, -30, 1, -100)
	end

	local self = setmetatable({
		weaponState = params.weaponState,
		state = params.state,
		ammoUI = ammoUI,
		ammoCounter = ammoCounter,
		ammoPoolUI = ammoPoolUI,
		bulletType = bulletType,
		fireMode = fireMode,
		chambered = chambered,
		attachmentFrame = attachmentFrame,
		aimSens = aimSens,
		ubglAmmo = nil,
	} :: self, UIController)

	Charm.subscribe(self.state.equippedTool, function(tool)
		self:SyncEquippedTool(tool)
	end)
	Charm.subscribe(self.state.aiming, function(aiming)
		self:SyncAiming(aiming)
	end)

	return self
end

function UIController.SyncAiming(self: UIController, aiming: boolean)
	self.aimSens.TextTransparency = aiming and 0 or 1
end

function UIController.SyncEquippedTool(self: UIController, tool: Tool?)
	if tool then
		local ws = self.weaponState.wepStats()
		if ws and ws.hasUBGL then
			self.ubglAmmo = tool:FindFirstChild("UBGLAmmo")
		else
			self.ubglAmmo = nil
		end

		local wepModel = assets.WeaponModels:FindFirstChild(tool.Name)
		if wepModel and wepModel.Grip:FindFirstChild("Flashlight") then
			self.attachmentFrame.Flashlight.Visible = true
		end
		if wepModel and wepModel.Grip:FindFirstChild("Laser") then
			self.attachmentFrame.Laser.Visible = true
		end

		if ws and ws.ammoType then
			self.bulletType.Text = ws.ammoType
		end
	else
		self.ubglAmmo = nil
		self.attachmentFrame.Laser.Visible = false
		self.attachmentFrame.Flashlight.Visible = false
	end
end

function UIController.UpdateHeartbeat(self: UIController, _dt: number)
	local tool = self.state.equippedTool()
	local wepStats = self.weaponState.wepStats()
	local magAmmo = self.weaponState.gunAmmo and self.weaponState.gunAmmo:FindFirstChild("MagAmmo")

	if tool and wepStats and (tool:FindFirstChild("Chambered") or wepStats.openBolt) and magAmmo and not self.state.dead() then
		if self.state.Parts.Humanoid.SeatPart ~= nil and self.state.Parts.Humanoid.SeatPart.ClassName == "VehicleSeat" then
			return
		end
		self.ammoUI.Visible = true

		local fireModeVal = self.weaponState.fireMode()

		if fireModeVal == 4 and wepStats.hasUBGL and self.ubglAmmo then
			local ubglAmmoPool = tool:FindFirstChild("UBGLAmmoPool")
			self.ammoCounter.Text = self.ubglAmmo.Value
			self.ammoPoolUI.Text = "/" .. ubglAmmoPool.Value
			self.bulletType.Text = wepStats.ubgl.ammoType
			self.chambered.TextTransparency = 1
			if self.ubglAmmo.Value > 0 then
				self.ammoCounter.TextColor3 = Color3.new(1, 1, 1)
			else
				self.ammoCounter.TextColor3 = Color3.new(1, 0.1, 0.1)
			end
		else
			local chamberedVal = tool:FindFirstChild("Chambered") and tool.Chambered.Value

			if wepStats.operationType == 4 and chamberedVal then
				local digits = splitNumber(magAmmo.Value + 1)
				self.ammoCounter.Text = [[<font transparency="0.5">]] .. digits[1] .. [[</font>]] .. digits[2]
			else
				local digits = splitNumber(magAmmo.Value)
				self.ammoCounter.Text = [[<font transparency="0.5">]] .. digits[1] .. [[</font>]] .. digits[2]
			end

			self.ammoPoolUI.Text = "/"
			if wepStats.infiniteAmmo then
				self.ammoPoolUI.Text = self.ammoPoolUI.Text .. "INF"
			else
				local ammoPoolVal = self.weaponState.gunAmmo.ArcadeAmmoPool.Value
				local digits = splitNumber(ammoPoolVal)
				self.ammoPoolUI.Text = self.ammoPoolUI.Text
					.. [[<font transparency="0.5">]]
					.. digits[1]
					.. [[</font>]]
					.. digits[2]
				if ammoPoolVal > 0 then
					self.ammoPoolUI.TextColor3 = Color3.fromRGB(255, 255, 255)
				else
					self.ammoPoolUI.TextColor3 = Color3.new(1, 0, 0)
				end
			end

			if fireModeVal == 0 then
				self.ammoCounter.TextColor3 = Color3.new(0.5, 0.5, 0.5)
			elseif chamberedVal or (wepStats.openBolt and magAmmo.Value > 1) then
				if wepStats.operationType < 4 then
					self.chambered.TextTransparency = 0
				end
				self.ammoCounter.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				self.chambered.TextTransparency = 1
				self.ammoCounter.TextColor3 = Color3.new(1, 0, 0)
			end
		end

		self.fireMode.Text = FIRE_MODE_NAMES[fireModeVal + 1]
		self.aimSens.Text = string.format("%.2f", WeaponPrefs.getGlobal("aimSens"))
	else
		self.ammoUI.Visible = false
	end
end

return UIController
