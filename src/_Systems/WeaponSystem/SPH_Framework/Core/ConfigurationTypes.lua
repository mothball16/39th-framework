export type WeaponStats = {
    -- vertical camera recoil: between 10-50 for most guns
	VRecoil: {number},
    -- horizontal camera recoil: between 10-50 for most guns
	HRecoil: {number},
	-- tilt recoil: WIP
	TRecoil: {number},

    -- camera recovery percentage: between 0 & 1
	AimRecover: number,

    -- backward model punch
	RecoilPunch: number,
    -- vertical angular model punch
	VPunchBase: number,
    -- horizontal angular model punch
	HPunchBase: number,
    -- tilt angular model punch
	DPunchBase: number,

    -- recoil speed: 18 is default
	PunchSpeed: number,
    -- recoil springiness. less is more springy: between 0.5-0.75 for most guns
	PunchDamper: number,
    -- model recovery speed
    PunchRecover: number,

    -- divide RecoilPunch by this when aiming
	AimBackwardPunchReduction: number,
    -- divide VPunch/HPunch/DPunch by this while aiming
	AimRotationalPunchReduction: number,
    -- divide VRecoil/HRecoil by this while aiming
	AimRecoilReduction: number,

    -- minimum recoil multiplier: should really be one in most cases
	MinRecoilFactor: number,
    -- maximum recoil multiplier: between 2-3 for most guns
	MaxRecoilFactor: number,
    -- how much recoil factor goes up by per shot: between 0.25-0.75 for most guns
	RecoilStepAmount: number,
    -- how much recoil factor goes down by per second: between 1-2 for most guns
	RecoilRecoverPerSecond: number,
	
    -- minimum spread in degrees: TODO
	MinSpread: number,
    -- maximum spread in degrees: TODO
	MaxSpread: number,
    -- how much spread increases by per shot: TODO
	SpreadStepAmount: number,
    -- how much spread goes down by per second: TODO
	SpreadRecoverPerSecond: number,
	
    -- weapon sway when moving camera around: between 3-5 for most stocked weapons
	DeltaInstability: Vector2,
    -- weapon sway when moving while walking: between 0.5-0.75 for most stocked weapons
	MoveInstability: number,

	-- how much the instability is multiplied by when aiming
	AimedInstabilityMultiplier: {delta: number, move: number},

    -- DTS config shit
	weaponType: string,
    -- what projectile configuration to use
	projectile: string,
    -- what bullet physics configuration to use for penetration/ricochet
	bulletPhysics: string?,

    -- what sort of mag 
	magType: number,
	
    operationType: number,
	
    clipSize: number?,
	
    clipReloadAnim: string?,

    fireRate: number,
	-- Number from 0-10 that determines how often the muzzle will flash when firing
    muzzleChance: number,

    muzzleVelocity: number,
		
    gunLength: number,
	
    maxPushback: number,

	fireSwitch: {boolean},
	
    fireMode: number,
	
    burstNumber: number,
	
    burstFireRate: number?,

	shotgun: boolean,
	shotgunPellets: number?,

	aimTime: number,
	aimMoveMultiplier: number,
    aimFovs: {number},

	suppressionLevel: number,
	suppressionDistance: number,
	suppressionLimit: number,

	holster: boolean,
	holsterPart: string,
	holsterPart_R15: string?,
	holsterPosition: CFrame,

	calcEjectionForce: () -> Vector3,

	ADSEnabled: {boolean},

	range: {
		Min: number,
		Max: number
	},
	damage: {
		Head: {Min: number, Max: number},
		Torso: {Min: number, Max: number},
		Other: {Min: number, Max: number}
	},

	tracers: boolean,
	tracerTiming: number,
	tracerColor: Color3 | string,

	ammoType: string,
	shellEject: boolean,
	magazineCapacity: number,
	arcadeAmmo: boolean,
	startAmmoPool: number,
	maxAmmoPool: number,
	infiniteAmmo: boolean,
	startChambered: boolean,

	bulletDrop: boolean,
	bulletForce: number,

	viewmodelOffset: CFrame,
	serverOffset: CFrame,

    -- animation strings
	Animations: {
		idle: string,
		sprint: string,
		reload: string,
		boltChamber: string,
		boltClose: string,
		equip: string,
		patrol: string?,
		holdUp: string?,
		holdDown: string?,
		switch: string?,
		fire: string?,
	},
	
	reloadSpeedModifier: number,

	rigParts: {string},
	fireMoveParts: {string},
	boltDist: number,
	emptyLockBolt: boolean,
	emptyCloseBolt: boolean,
	autoChamber: boolean,

	-- Optional System Fields
	Attachments: any?,
	hasUBGL: boolean?,
	ubgl: any?,
	explosiveAmmo: boolean?,
	explosionRadius: number?,
	explosionEffect: string?,
}

type KeybindSlot = Enum.KeyCode | Enum.UserInputType
type KeybindBinding = {KeybindSlot | nil}

--[[
	Shape of the main game ModuleScript config (defaults / runtime settings table).
	Keybind fields may be set to nil to disable that binding, or use a table (including `{ nil }`).
]]
export type MainGameSettings = {
	fixHeadHitboxes: boolean,
	
	thirdPersonFiring: boolean,
	arcadeBullets: boolean,

	leaderboard: boolean,
	rblxDamageTags: boolean,
	leaderboardKillStat: string,
	leaderboardTKStat: string,
	leaderboardDeathStat: string,

	deathScreen: boolean,

	fallDamage: boolean,
	fallDamageDist: number,
	fallDamageMultiplier: number,

	teamKill: boolean,
	teamTracers: boolean,

	firstPersonBody: boolean,
	headRotation: boolean,
	headRotationSpeed: number,
	disableHeadRotation: boolean,
	headRotationEventRate: number,
	replicatedHeadRotationSpeed: number,
	headRotationDistance: number,

	useDeathCameraSubject: boolean,
	explosionRaycast: boolean,

	gunDropping: boolean,
	dropOnDeath: boolean,
	dropOnLeave: boolean,
	dropDespawnTime: number,
	maxDroppedGuns: number,
	pickupDistance: number,
	dropGunAnchorTime: number,

	walkSpeed: number,
	sprintSpeed: number,
	crouchSpeed: number,
	proneSpeed: number,
	movementLeaning: boolean,
	replicateMovementLeaning: boolean,
	replicateAttachments: boolean,
	maxLeanAngle: number,
	stanceChangeTime: number,
	canLean: boolean,
	canCrouch: boolean,
	canProne: boolean,
	proneAngle: boolean,
	stanceThrottle: number,
	jumpCooldown: number,

	keySprint: KeybindBinding?,
	keyReload: KeybindBinding?,
	keyChamber: KeybindBinding?,
	sightSwitch: KeybindBinding?,
	freeLook: KeybindBinding?,
	lowerStance: KeybindBinding?,
	raiseStance: KeybindBinding?,
	holdUp: KeybindBinding?,
	holdPatrol: KeybindBinding?,
	holdDown: KeybindBinding?,
	switchFireMode: KeybindBinding?,
	leanLeft: KeybindBinding?,
	leanRight: KeybindBinding?,
	dropKey: KeybindBinding?,
	pickupKey: KeybindBinding?,
	toggleLaser: KeybindBinding?,
	toggleFlashlight: KeybindBinding?,
	holdForScrollZoom: Enum.KeyCode?,
	fireGun: KeybindBinding?,
	aimGun: KeybindBinding?,

	defaultFOV: number,
	defaultAimSensitivity: number,
	gunInputPriority: number,
	movementInputPriority: number,
	mobileButtons: boolean,
	toggleAiming: boolean,

	animDistance: number,
	fireEffectDistance: number,
	maxBulletDistance: number,
	maxHitDistance: number,
	ragdolls: boolean,
	bodyDespawn: number,
	bodyLimit: number,
	bodyAnchorTime: number,

	shellEjection: boolean,
	shellDistance: number,
	shellMaxCount: number,
	shellDespawn: number,
	shellAnchorTime: number,

	firstPersonHolsters: boolean,
	blurEffects: boolean,
	despawnEmptyAmmoBoxes: boolean,
	ammoBoxDespawnTime: number,
	maxBullets: number,
	bulletHoles: boolean,
	bulletHoleDespawnTime: number,
	glassShatter: boolean,
	glassShardDespawnTime: number,
	glassRespawnTime: number,

	bulletAcceleration: Vector3,
	useBulletForce: boolean,
	bulletPen: boolean,

	breathingSpeed: number,
	breathingDist: number,
	breathingAimMultiplier: number,
	bobSpeed: number,
	bobDampening: number,
	aimBobDampening: number,

	cameraTilting: boolean,
	cameraLimitInSeats: boolean,
	hipfireMove: boolean,
	hipfireMoveX: number,
	hipfireMoveY: number,
	hipfireMoveSpeed: number,
	offCenterAiming: boolean,
	pushBackViewmodel: boolean,
	raiseGunAtWall: boolean,
	fireWithFreelook: boolean,
	maxStrafeRoll: number,
	maxStrafeShift: number,
	strafeShiftAimMult: number,
	showAccessoriesFP: boolean,

	lowHealthEffects: boolean,
	suppressionEffects: boolean,
	footstepSounds: boolean,
	tracerStartDistance: number,
	fireSoundVariation: number,
	firstPersonEcho: boolean,
	laserTrail: boolean,

	destructibleObjects: boolean,
	pierceDamageMultiplier: number,

	listenForKillAll: boolean,
	multiKillThreshold: number,
	printKillLogs: boolean,
	requireEquippedGun: boolean,
	listenForExplosionSpam: boolean,
	ammoCountCheck: boolean,
	listenForReloadSpam: boolean,
	killAngleCheck: boolean,
	multiKillDistanceCheck: boolean,
	strikes: boolean,
	maxStrike: number,
	serverBanList: boolean,

	version: string,

	hitmarkers: boolean,
	damageIndicators: boolean,

	suppressionMinDistance: number,
	suppressionVignetteLimit: number,
	suppressionRecovery: number,
	suppressionThrottle: number,
	suppressionAimPunchFactor: number,
	suppressionAimPunchThrottle: number,

	fullySuppressedZoomFactor: number,
	fullySuppressedThreshold: number,
	

	playerZoomDistance: number,

}

return nil
