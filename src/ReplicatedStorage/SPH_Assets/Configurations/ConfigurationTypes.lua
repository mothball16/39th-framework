export type WeaponStats = {
    -- vertical camera recoil: between 10-50 for most guns
	VRecoil: {number},
    -- horizontal camera recoil: between 10-50 for most guns
	HRecoil: {number},
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

    -- DTS config shit
	weaponType: string,
    -- what projectile configuration to use
	projectile: string,

    -- what sort of mag 
	magType: number,
	
    operationType: number,
	
    clipSize: number?,
	
    clipReloadAnim: string?,

    fireRate: number,
	-- Number from 0-10 that determines how often the muzzle will flash when firing
    muzzleChance: number,

    muzzleVelocity: number,
	
    aimSpeed: number,
	
    gunLength: number,
	
    maxPushback: number,

	fireSwitch: {boolean},
	
    fireMode: number,
	
    burstNumber: number,
	
    burstFireRate: number?,

	spread: number,
	shotgun: boolean,
	shotgunPellets: number?,

	aimTime: number,
	
    aimFovs: {number},

	suppressionLevel: number,

	holster: boolean,
	holsterPart: string,
	holsterPart_R15: string?,
	holsterPosition: CFrame,

	calcEjectionForce: () -> Vector3,

	ADSEnabled: {boolean},
	damage: {[string]: number},

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
	idleAnim: string,
	sprintAnim: string,
	reloadAnim: string,
	boltChamber: string,
	boltClose: string,
	equipAnim: string,
	patrolAnim: string?,
	holdUpAnim: string?,
	holdDownAnim: string?,
	switchAnim: string?,
	fireAnim: string?,

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


return wepStats
