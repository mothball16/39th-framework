--[[       
DRAGOON TANK SYSTEM
Global Settings
1.2.0
--]]

local config = {}

--// Version & Info
config.prefix = "«-DRAGOON-»"
config.version = "1.2.0"
config.credits = {"Jarr", "VanguardCobalt"}

--// Damage & HP
config.FriendlyFire = true
config.FFMultiplier = 1 --if friendly fire is enabled, how much damage should be received from a friendly?
config.leaderboard = true --Use roblox leaderboard kill counting (NOTE: this wont create a leaderboard, just enable DTS using it)
config.leaderboardKillStat = "" -- adds to whichever stat your leaderboard uses to track Kills. If you use SPH Leaderboard leave this blank or set to "K"
config.leaderboardTKStat = "" -- adds teamkills to whichever stat your leaderboard uses to track Teamkills. If you want TKs to count as kills, set this to match the kill stat
config.leaderboardDisplayNames = true --For kill/hit notifications, use display names instead of user names?
config.WreckRemovalDelay = 5 --How much to wait before removing destroyed vehicles. Set to nil to disable. 

--// Explosions
config.explosionRaycast = true -- Use raycasts to check if there is line of sight between the explosion source and the target
config.explosionEffects = true -- Use explosion effects? spamming these could lag a bit or annoy other players
config.explosionEffectMult = 1 --Multiply the amount of particles emitted and their duration.
config.terrainExplosions = false -- Should explosive shells affect terrain? Adjust material resistance in "CraterMod" module.
config.terrainExplosionMult = 1 -- Multiplies the radius/depth values for terrain craters. Use this if your explosions are too powerful, or not enough.

--// Roadkill
config.RoadkillPlayers = true --Can vehicles kill players by running them over?
config.RoadkillProps = true --Can vehicles destroy props by running them over/bumping into them?
config.RoadkillVehicles = true --Can vehicles damage other vehicles by bumping into them?

--// FastCast Ballistics
config.fireEffectDistance = 4000 -- Maximum distance for firing effects to be replicated
config.maxBulletDistance = 12000 -- Bullets that fly further than this distance will be deleted
config.maxHitDistance = 2000 -- Maximum distance to see bullet hit effects
config.maxBullets = 500 -- Maximum number of bullets that are cached (Cache size will temporarily increase if this is exceeded)
config.bulletAcceleration = Vector3.new(0, -workspace.Gravity, 0) -- This is used for the bullet drop force
config.useBulletForce = true -- Should bullet impacts be able to push things around?
config.arcadeBullets = false -- Gives bullets a faint streak similar to FE Gun Kit, looks pretty bad with tracers enabled
config.BulletRepFocus = 100--workspace.StreamingTargetRadius*0.9 -- At what distance should we add a replication focus to load in the terrain of the bullet?

--// Effects
config.cameraShake = true -- shake the camera when firing
config.suppressionEffects = true -- Tunnel vision and crack sounds
config.tracerStartDistance = 15 -- Tracers and arcade bullets don't appear until they're this distance away from you
config.fireSoundVariation = 500 -- Lowering this number increases the variation in pitch (playback speed) of fire and echo sounds
config.firstPersonEcho = true -- If this is set to false other players will hear echo sounds, but not yourself
config.laserTrail = true -- Should lasers have a trail
config.reloadSoundLast = true -- Should the reload sound play just before finishing the reload? if not, it will play as it begins.

--// Zoom & Gunsights
config.ForceGunsights = nil --Should weapon aiming be forced to a single gunsights state? Set to true to enforce gunsights-only, to false to disable them, or nil to remove this limitation.
config.ZoomLimits = {0, 40} --Should camera zoom out be limited for all weapons? Weapon specific zoom settings override this.

--// Game mechanics & performance
config.JumpPreventionSpeed = 15 --at what speed should we prevent players from exiting vehicles? Set to "nil" to disable.
config.AimWithMouse = false --Aim at the player's mouse instead of the center of their screen
config.CalculatedAim = false
--[[
	When true, the weapon will aim to the screen center/mouse position ACCOUNTING for bullet drop and other factors.
	When false, the weapon will aim DIRECTLY to the screen center/mouse position NOT ACCOUNT for bullet drop.
	Some vehicles can have this enabled individually, but if this option is enabled it will apply for everything.
--]]

config.DirectTurretReplication = true 
--[[ EXPERIMENTAL SETTING!!
	When false, a gunner without network ownership calls the server to replicate their turret movements, which results 
	in everyone (including the gunner) noticing lag in the turret movement.
	When true, a gunner without network ownership calls the server to replicate their turret movements, and the server
	passes along the message to every client except the gunner. This results in smoother movement for the gunner, but
	additional lag for everyone else (and they still notice some lag in the turret movements)
	
	Do not touch this unless you know what it does.
--]]
config.UseWeldReplication = true
--[[ EXPERIMENTAL SETTING!!
	When true, hingeConstraints will be replaced for welds. If used along with direct turret replication, this should
	help in achieving smoother turret movement for multicrew vehicles. Note that this is an old technique and might have
	unforeseen implications.
	
	Do not touch this unless you know what it does.
	Setting this and "DirectTurretReplication" to true will greatly improve multicrew experience in MOST cases.
--]]

return config
