-- Central BridgeNet surface for the server (single place for bridge names).

local M = {}

function M.CreateAll(bridgeNet: any)
	return {
		switchWeapon = bridgeNet.CreateBridge("SwitchWeapon"),
		repFire = bridgeNet.CreateBridge("ReplicateFire"),
		repReload = bridgeNet.CreateBridge("Reload"),
		repSound = bridgeNet.CreateBridge("ReplicateSound"),
		bulletHit = bridgeNet.CreateBridge("BulletHit"),
		repHit = bridgeNet.CreateBridge("ReplicateHit"),
		repChamber = bridgeNet.CreateBridge("PlayerChamber"),
		moveBolt = bridgeNet.CreateBridge("MoveBolt"),
		playerFire = bridgeNet.CreateBridge("PlayerFire"),
		playSound = bridgeNet.CreateBridge("PlaySound"),
		sysMessage = bridgeNet.CreateBridge("SystemMessage"),
		fallDamage = bridgeNet.CreateBridge("FallDamage"),
		repBolt = bridgeNet.CreateBridge("ReplicateBolt"),
		switchFireMode = bridgeNet.CreateBridge("SwitchFireMode"),
		playCharSound = bridgeNet.CreateBridge("PlayCharacterSound"),
		repCharSound = bridgeNet.CreateBridge("ReplicateCharacterSound"),
		repFootstep = bridgeNet.CreateBridge("ReplicateFootstep"),
		playerDropGun = bridgeNet.CreateBridge("PlayerDropGun"),
		playerToggleAttachment = bridgeNet.CreateBridge("PlayerToggleAttachment"),
		repToggleAttachment = bridgeNet.CreateBridge("ReplicateToggleAttachment"),
		repBoltOpen = bridgeNet.CreateBridge("RepBoltOpen"),
		magGrab = bridgeNet.CreateBridge("MagGrab"),
		repMagGrab = bridgeNet.CreateBridge("ReplicateMagGrab"),
		playerLean = bridgeNet.CreateBridge("PlayerLean"),
		bodyAnimRequest = bridgeNet.CreateBridge("BodyAnimRequest"),
	}
end

return M
