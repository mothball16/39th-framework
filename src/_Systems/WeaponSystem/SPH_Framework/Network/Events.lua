local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local ByteNetMax = require(Packages["bytenet-max"])

local B = ByteNetMax

local function buildPacket(schema, reliabilityType: "unreliable" | "reliable")
	return B.definePacket({ value = schema, reliabilityType = reliabilityType })
end

local packets = {}

local switchWeaponSchema = B.struct({
	tool = B.optional(B.inst),
})
export type SwitchWeaponPayload = typeof(switchWeaponSchema)
packets.SwitchWeapon = buildPacket(switchWeaponSchema, "reliable")


local playerFireSchema = B.struct({
	firePoint = B.cframe,
})
export type PlayerFirePayload = typeof(playerFireSchema)
packets.PlayerFire = buildPacket(playerFireSchema, "reliable")


local playSoundSchema = B.struct({
	soundName = B.string,
	firstPerson = B.bool,
})
export type PlaySoundPayload = typeof(playSoundSchema)
packets.PlaySound = buildPacket(playSoundSchema, "unreliable")


local reloadSchema = B.struct({
	_ = B.uint8,
})
export type ReloadPayload = typeof(reloadSchema)
packets.Reload = buildPacket(reloadSchema, "reliable")


local playerChamberSchema = B.struct({
	_ = B.uint8,
})
export type PlayerChamberPayload = typeof(playerChamberSchema)
packets.PlayerChamber = buildPacket(playerChamberSchema, "unreliable")


local moveBoltSchema = B.struct({
	-- CFrame offset or numeric bolt travel (see BulletHandler.MoveBolt).
	direction = B.unknown,
	magAmmo = B.float32,
})
export type MoveBoltPayload = typeof(moveBoltSchema)
packets.MoveBolt = buildPacket(moveBoltSchema, "unreliable")


local switchFireModeSchema = B.struct({
	mode = B.uint8,
})
export type SwitchFireModePayload = typeof(switchFireModeSchema)
packets.SwitchFireMode = buildPacket(switchFireModeSchema, "unreliable")


local playerDropGunSchema = B.struct({
	_ = B.uint8,
})
export type PlayerDropGunPayload = typeof(playerDropGunSchema)
packets.PlayerDropGun = buildPacket(playerDropGunSchema, "reliable")


local playerToggleAttachmentSchema = B.struct({
	attachmentType = B.uint8,
	enabled = B.bool,
})
export type PlayerToggleAttachmentPayload = typeof(playerToggleAttachmentSchema)
packets.PlayerToggleAttachment = buildPacket(playerToggleAttachmentSchema, "reliable")


local repBoltOpenSchema = B.struct({
	_ = B.uint8,
})
export type RepBoltOpenPayload = typeof(repBoltOpenSchema)
packets.RepBoltOpen = buildPacket(repBoltOpenSchema, "unreliable")


local magGrabSchema = B.struct({
	_ = B.uint8,
})
export type MagGrabPayload = typeof(magGrabSchema)
packets.MagGrab = buildPacket(magGrabSchema, "reliable")


local playerLeanSchema = B.struct({
	lean = B.float32,
})
export type PlayerLeanPayload = typeof(playerLeanSchema)
packets.PlayerLean = buildPacket(playerLeanSchema, "reliable")


local bodyAnimRequestSchema = B.struct({
	neckC1 = B.cframe,
})
export type BodyAnimRequestPayload = typeof(bodyAnimRequestSchema)
packets.BodyAnimRequest = buildPacket(bodyAnimRequestSchema, "unreliable")


local fallDamageSchema = B.struct({
	damage = B.float64,
})
export type FallDamagePayload = typeof(fallDamageSchema)
packets.FallDamage = buildPacket(fallDamageSchema, "reliable")


local replicateFootstepSchema = B.struct({
	material = B.unknown,
	foot = B.inst,
	volume = B.float32,
})
export type ReplicateFootstepPayload = typeof(replicateFootstepSchema)
packets.ReplicateFootstep = buildPacket(replicateFootstepSchema, "unreliable")


local bulletHitSchema = B.struct({
	toolData = B.unknown,
	rayHit = B.unknown,
	bulletCFrame = B.cframe,
})
export type BulletHitPayload = typeof(bulletHitSchema)
packets.BulletHit = buildPacket(bulletHitSchema, "unreliable")


local requestSuppressionSchema = B.struct({
	target = B.inst,
	level = B.float32,
	factor = B.float32,
})
export type RequestSuppressionPayload = typeof(requestSuppressionSchema)
packets.RequestSuppression = buildPacket(requestSuppressionSchema, "reliable")


local reportSuppressionSchema = B.struct({
	level = B.float32,
	factor = B.float32,
})
export type ReportSuppressionPayload = typeof(reportSuppressionSchema)
packets.ReportSuppression = buildPacket(reportSuppressionSchema, "reliable")


local replicateFireSchema = B.struct({
	shooter = B.inst,
	firePoint = B.cframe,
})
export type ReplicateFirePayload = typeof(replicateFireSchema)
packets.ReplicateFire = buildPacket(replicateFireSchema, "unreliable")


local replicateSoundSchema = B.struct({
	shooter = B.inst,
	sound = B.inst,
})
export type ReplicateSoundPayload = typeof(replicateSoundSchema)
packets.ReplicateSound = buildPacket(replicateSoundSchema, "unreliable")


local replicateHitSchema = B.struct({
	toolData = B.unknown,
	rayHit = B.unknown,
})
export type ReplicateHitPayload = typeof(replicateHitSchema)
packets.ReplicateHit = buildPacket(replicateHitSchema, "unreliable")


local replicateBoltSchema = B.struct({
	shooter = B.inst,
	direction = B.unknown,
	magAmmo = B.float32,
})
export type ReplicateBoltPayload = typeof(replicateBoltSchema)
packets.ReplicateBolt = buildPacket(replicateBoltSchema, "unreliable")


local replicateCharacterSoundSchema = B.struct({
	shooter = B.inst,
	soundType = B.string,
})
export type ReplicateCharacterSoundPayload = typeof(replicateCharacterSoundSchema)
packets.ReplicateCharacterSound = buildPacket(replicateCharacterSoundSchema, "unreliable")


local playCharacterSoundSchema = B.struct({
	soundType = B.string,
})
export type PlayCharacterSoundPayload = typeof(playCharacterSoundSchema)
packets.PlayCharacterSound = buildPacket(playCharacterSoundSchema, "unreliable")


local replicateToggleAttachmentSchema = B.struct({
	attachment = B.inst,
	enabled = B.bool,
	character = B.optional(B.inst),
})
export type ReplicateToggleAttachmentPayload = typeof(replicateToggleAttachmentSchema)
packets.ReplicateToggleAttachment = buildPacket(replicateToggleAttachmentSchema, "reliable")


local replicateMagGrabSchema = B.struct({
	magPart = B.inst,
})
export type ReplicateMagGrabPayload = typeof(replicateMagGrabSchema)
packets.ReplicateMagGrab = buildPacket(replicateMagGrabSchema, "reliable")


return B.defineNamespace("SPH_Framework", function()
	return {
		packets = packets,
		queries = {},
	}
end)
