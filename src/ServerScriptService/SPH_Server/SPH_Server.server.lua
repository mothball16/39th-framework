-- Main server script: collision + workspace setup, shared context, controller wiring.

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
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

local assets = replicatedStorage.SPH_Assets
local modules = assets.Modules
local mainui = assets.HUD.SPH_UI

local WeaponStatLocator = require(modules.WeaponStatLocator)
local weldMod = require(modules.WeldMod)
local bridgeNet = require(replicatedStorage.SPH_Assets.Modules.BridgeNet)
local viewMod = require(modules.ViewMod)
local explosionMod = require(modules.ExplosionFX)
local config = require(assets.GameConfig)
local ragdoll = require(modules.RagdollMod)
local systemMessages = require(modules.SystemMessages)
local fractureGlass = require(modules.FractureGlass)
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
local ServerBridges = require(Controllers.ServerBridges)
local bridges = ServerBridges.CreateAll(bridgeNet)

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
	modules = modules,
	config = config,
	warnPrefix = warnPrefix,
	weldMod = weldMod,
	viewMod = viewMod,
	explosionMod = explosionMod,
	ragdoll = ragdoll,
	systemMessages = systemMessages,
	fractureGlass = fractureGlass,
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
	bridges = bridges,
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
