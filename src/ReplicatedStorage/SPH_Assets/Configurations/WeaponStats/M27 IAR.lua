--!strict
local Types = require(script.Parent.Parent.ConfigurationTypes)

local wepStats: Types.WeaponStats = {
	VRecoil = {12,18},
	HRecoil = {22,26},
	AimRecover = 0.75,

	RecoilPunch = 1.5,
	VPunchBase = 2,					--- Vertical Punch
	HPunchBase = 3,					--- Horizontal Punch
	DPunchBase = 1,				--- Tilt Punch | useless

	PunchSpeed = 18,
	PunchDamper = 0.75,

	AimBackwardPunchReduction = 1.5,
	AimRotationalPunchReduction = 1.5,
	AimRecoilReduction = 2, 		--- Recoil Reduction Factor While Aiming (Do not set to 0)
	PunchRecover = .3,			--- Recoil punch recovery rate
	
	MinRecoilFactor = 1,
	MaxRecoilFactor = 2.25,
	RecoilStepAmount = 0.34,
	RecoilRecoverPerSecond = 2.25 - 1,
	
	MinSpread = 0.1,					--- Min bullet spread value | Studs
	MaxSpread = 0.4,
	SpreadStepAmount = 0.1,		--- Increase in bullet spread when firing
	SpreadRecoverPerSecond = 0.5,		--- Decrease in bullet spread when not firing
	
	DeltaInstability = Vector2.new(5, 3),	--- Weapon sway when moving camera around. Stocked weapons should default at 3-5. 
	MoveInstability = 0.75,					--- Weapon sway when moving while walking. Stocked weapons should default at 0.5-0.75.

	--< Weapon type >--
	weaponType = "Gun",
	projectile = "Bullet",
	magType = 1,
	--[[ Ammo 
	1 = This gun is magazine fed.
	2 = This gun must have bullets inserted manually. (Shotguns, revolvers, etc)
	3 = This gun can have bullets inserted manually, but also has clips.
	If you want the gun's capacity to be higher than its clip size, add a setting called clipSize.
	2 and 3 will use their reload anim for shell insertion.
	3 requires a clipReloadAnim animation setting.
	]]

	operationType = 1,
	--[[ V Operation Type Guide V
	1 = Gun can be reloaded with the bolt closed, chambering is only necessary when there's no round in the chamber.
	2 = The bolt should be opened before reloading if the gun is empty.
	3 = The bolt should always be opened before reloading.
	4 = This gun doesn't have a bolt, it's a rocket launcher or a laser gun or smth.
	]]

	--< Gun settings >--
	fireRate = 750,
	muzzleChance = 5, -- Number from 0-10 that determines how often the muzzle will flash when firing
	muzzleVelocity = 884, -- this stat uses meters per second
	aimSpeed = 0.3, -- 0-1 how much should the aim speed be multiplied by
	gunLength = 3.5, -- How close you can get to a surface before the viewmodel moves back
	maxPushback = 0.8, -- How far can the viewmodel move backwards until the gun is blocked

	fireSwitch = {
		true, -- Semi
		true, -- Auto
		false, -- Burst
		false -- Manual (bolt/pump action)
	},
	fireMode = 2, -- Default mode from the above table
	burstNumber = 3, -- If this gun can fire in bursts, what should the shot limit be?
	burstFireRate = nil, -- Use this if you want a separate burst fire rate, leave it as nil if you want to use the regular fire rate

	shotgun = false,
	shotgunPellets = 10, -- If shotgun is true, how many pellets should be fired at once?

	aimTime = 1,
	aimFovs = {30, 60},

	suppressionLevel = 2, -- How much should this gun suppress people?

	holster = true, -- Add gun models to the your character when they aren't equipped
	holsterPart = "Torso", -- The body part to attach the gun model to
	holsterPart_R15 = "UpperTorso", -- The body part to attach the gun model to on an R15 rig
	holsterPosition = CFrame.new(1.244, -0.912, 0.574) * CFrame.Angles(math.rad(-21),math.rad(4),math.rad(6)),

	calcEjectionForce = function()
		return Vector3.new(
			math.random(1800,2000) / 10, -- Side to side
			math.random(180,220) / 10, -- Up
			math.random(330,380) / 10 -- Front
		)
	end,

	ADSEnabled = { -- Ignore this setting if not using an ADS Mesh
		true, -- Enabled for primary sight
		false -- Enabled for secondary sight (T)
	},

	-- Damage
	damage = {
		Head = 150,
		Torso = 50,
		Other = 30, -- Default damage if body part is not included
	},

	-- Tracers
	tracers = true,
	tracerTiming = 3, -- Every x number of shots will be a tracer
	tracerColor = Color3.fromRGB(255, 55, 55),

	-- Ammo
	ammoType = "5.56×45mm", -- Gun shell models can be found in ReplicatedStorage > SPH_Assets > Shells
	shellEject = true, -- Should this gun eject shells?
	magazineCapacity = 30, -- Max ammo that can go in a mag
	arcadeAmmo = true, -- Don't disable this until the new ammo system is added
	startAmmoPool = 120, -- How much ammo should the gun start with?
	maxAmmoPool = 120, -- How much ammo can this gun hold?

	infiniteAmmo = false,
	startChambered = true, -- Start with a round in the chamber?

	-- Physics
	bulletDrop = true, -- Bullet drop based on workspace.Gravity
	bulletForce = 300, -- If a bullet hits something unanchored, this force is applied

	-- Viewmodel
	viewmodelOffset = CFrame.new(0.2,0.1,-0.3), -- Where should the viewmodel be placed in reference to the camera
	serverOffset = CFrame.new(0,0,0), -- Where should the viewmodel be placed in reference to the player's head

	-- Animation
	idleAnim = "Rifle_Idle", -- Animations are located in ReplicatedStorage > SPH_Assets > Animations
	sprintAnim = "Rifle_Sprint",
	reloadAnim = "Rifle_Reload",
	boltChamber = "Rifle_Chamber", -- Plays if the bolt is closed
	boltClose = "Rifle_Close", -- Plays if the bolt is open
	equipAnim = "Rifle_Equip",
	patrolAnim = "Rifle_Sprint",
	holdUpAnim = "Rifle_Neutral",
	holdDownAnim = nil,
	switchAnim = "Rifle_Switch",
	fireAnim = nil, -- Plays when the gun fires

	reloadSpeedModifier = 0.8, -- 1 = Normal speed, higher = faster, lower = slower

	rigParts = {"Mag","Bolt","ChargingHandle"}, -- These parts will have their welds replaced with Motor6Ds in case they need to be animated
	fireMoveParts = {"Bolt"}, -- These parts will move when firing

	boltDist = 0.45, -- Distance the bolt will move when firing (Make this number negative for open bolt guns!)
	emptyLockBolt = true, -- Lock the bolt back after firing last round
	emptyCloseBolt = false, -- Close the bolt if the player tries to fire with no bullet in the chamber
	autoChamber = true, -- Chamber the gun after reloading if needed
}


return wepStats
