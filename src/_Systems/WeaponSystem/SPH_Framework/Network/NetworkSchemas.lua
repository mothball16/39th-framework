--!strict

export type UnitPayload = { _: number }
export type SwitchWeaponPayload = { tool: Instance? }
export type PlayerFirePayload = { firePoint: CFrame }
export type PlaySoundPayload = { soundName: string, firstPerson: boolean }
export type ReloadPayload = UnitPayload
export type PlayerChamberPayload = UnitPayload
export type MoveBoltPayload = { direction: unknown, magAmmo: number }
export type SwitchFireModePayload = { mode: number }
export type PlayerDropGunPayload = UnitPayload
export type PlayerToggleAttachmentPayload = { attachmentType: number, enabled: boolean }
export type RepBoltOpenPayload = UnitPayload
export type MagGrabPayload = UnitPayload
export type PlayerLeanPayload = { lean: number }
export type BodyAnimRequestPayload = { neckC1: CFrame }
export type FallDamagePayload = { damage: number }
export type ReplicateFootstepPayload = { material: unknown, foot: Instance, volume: number }
export type BulletHitPayload = { toolData: unknown, rayHit: unknown, bulletCFrame: CFrame }
export type RequestSuppressionPayload = { target: Instance, level: number, factor: number }
export type ReportSuppressionPayload = { level: number, factor: number }
export type ReplicateFirePayload = { shooter: Instance, firePoint: CFrame }
export type ReplicateSoundPayload = { shooter: Instance, sound: Instance }
export type ReplicateHitPayload = { toolData: unknown, rayHit: unknown }
export type ReplicateBoltPayload = { shooter: Instance, direction: unknown, magAmmo: number }
export type ReplicateCharacterSoundPayload = { shooter: Instance, soundType: string }
export type PlayCharacterSoundPayload = { soundType: string }
export type ReplicateToggleAttachmentPayload = {
	attachment: Instance,
	enabled: boolean,
	character: Instance?,
}
export type ReplicateMagGrabPayload = { magPart: Instance }

return {}
