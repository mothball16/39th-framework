-- TODO: this is an ai slop mess - needs to be significantly refactored before we do any work on the server
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local Utility = replicatedStorage:WaitForChild("Utility")
local debris = game:GetService("Debris")
local proxPromptService = game:GetService("ProximityPromptService")
local collectionService = game:GetService("CollectionService")
local physicsService = game:GetService("PhysicsService")

physicsService:RegisterCollisionGroup("Casings")
physicsService:RegisterCollisionGroup("Players")
physicsService:RegisterCollisionGroup("RootParts")
physicsService:RegisterCollisionGroup("Guns")
physicsService:CollisionGroupSetCollidable("Casings", "Casings", false)
physicsService:CollisionGroupSetCollidable("Casings", "Players", false)
physicsService:CollisionGroupSetCollidable("Guns", "Guns", false)
physicsService:CollisionGroupSetCollidable("Guns", "Players", false)
physicsService:CollisionGroupSetCollidable("Casings", "Guns", false)

local Framework = replicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local assets = Access.assets
local config = Access.config
local mainui = assets.HUD.SPH_UI

require(Utility.TestRunner)(Framework.Tests)


local WeaponStatLocator = require(Framework.Weapons.WeaponStatLocator)
local weldMod = require(Framework.Weapons.WeldMod)
local Events = require(Framework.Network.Events)
local NetUtil = require(Framework.Network.NetUtil)
local viewMod = require(Framework.Weapons.ViewMod)
local explosionMod = require(Framework.Effects.ExplosionFX)
local ragdoll = require(Framework.Effects.RagdollMod)
local warnPrefix = "【 SPEARHEAD 】 "
print(warnPrefix .. "Loading Server " .. config.version)

local dd_settings = replicatedStorage:FindFirstChild("DD_Settings") and require(replicatedStorage.DD_Settings) or nil

local dtsInstall = replicatedStorage:FindFirstChild("DTS_Assets")
local atmod
if dtsInstall then
	atmod = require(dtsInstall.Modules.Antitank)
end

local explosionRayParams = RaycastParams.new()
explosionRayParams.IgnoreWater = true

local explosionOverlapParams = OverlapParams.new()
explosionOverlapParams.MaxParts = 500

local Controllers = script.Parent.Controllers
local net = Events.GetNamespace()

local naughtyList = {}
game:GetService("SoundService").RespectFilteringEnabled = true

local mainFolder = Instance.new("Folder", workspace)
mainFolder.Name = "SPH_Workspace"
local projectiles = Instance.new("Folder", mainFolder)
projectiles.Name = "Projectiles"
local cache = Instance.new("Folder", mainFolder)
cache.Name = "Cache"
local bodies = Instance.new("Folder", mainFolder)
bodies.Name = "Bodies"
local shells = Instance.new("Folder", mainFolder)
shells.Name = "Shells"
local drops = Instance.new("Folder", mainFolder)
drops.Name = "Drops"

local dropTable = {}

local ctx = {
	players = players,
	replicatedStorage = replicatedStorage,
	debris = debris,
	collectionService = collectionService,
	proxPromptService = proxPromptService,
	assets = assets,
	modules = Framework,
	config = config,
	warnPrefix = warnPrefix,
	weldMod = weldMod,
	viewMod = viewMod,
	explosionMod = explosionMod,
	ragdoll = ragdoll,
	WeaponStatLocator = WeaponStatLocator,
	dd_settings = dd_settings,
	atmod = atmod,
	explosionRayParams = explosionRayParams,
	explosionOverlapParams = explosionOverlapParams,
	mainui = mainui,
	bodies = bodies,
	drops = drops,
	naughtyList = naughtyList,
	dropTable = dropTable,
	net = net,
	netUtil = NetUtil,
}

local WeaponRigController = require(Controllers.WeaponRigController)
local WeaponEquipController = require(Controllers.WeaponEquipController)
local DropController = require(Controllers.DropController)
local PlayerLifecycleController = require(Controllers.PlayerLifecycleController)
local CombatController = require(Controllers.CombatController)
local AmmoController = require(Controllers.AmmoController)
local ServerReplicationController = require(Controllers.ServerReplicationController)
local InteractionController = require(Controllers.InteractionController)

WeaponRigController.Initialize(ctx)
WeaponEquipController.Initialize(ctx)
DropController.Initialize(ctx)
PlayerLifecycleController.Initialize(ctx)
CombatController.Initialize(ctx)
AmmoController.Initialize(ctx)
ServerReplicationController.Initialize(ctx)
InteractionController.Initialize(ctx)

print(warnPrefix .. "Main Server loaded successfully!")
