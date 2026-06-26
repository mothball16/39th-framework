local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local ByteNetMax = require(Packages["bytenet-max"])
local B = ByteNetMax

local namespace = ByteNetMax.defineNamespace("SPH_Framework", function()
	return {
		packets = {
			SwitchWeapon = B.definePacket({
				value = B.struct({ tool = B.optional(B.inst) }),
				reliabilityType = "reliable",
			}),
			PlayerFire = B.definePacket({
				value = B.struct({ firePoint = B.cframe }),
				reliabilityType = "reliable",
			}),
			PlaySound = B.definePacket({
				value = B.struct({
					soundName = B.string,
					firstPerson = B.bool,
				}),
				reliabilityType = "unreliable",
			}),
			Reload = B.definePacket({
				value = B.struct({ _ = B.uint8 }),
				reliabilityType = "reliable",
			}),
			PlayerChamber = B.definePacket({
				value = B.struct({ _ = B.uint8 }),
				reliabilityType = "unreliable",
			}),
			MoveBolt = B.definePacket({
				value = B.struct({
					direction = B.unknown,
					magAmmo = B.float32,
				}),
				reliabilityType = "unreliable",
			}),
			SwitchFireMode = B.definePacket({
				value = B.struct({ mode = B.uint8 }),
				reliabilityType = "unreliable",
			}),
			PlayerDropGun = B.definePacket({
				value = B.struct({ _ = B.uint8 }),
				reliabilityType = "reliable",
			}),
			PlayerToggleAttachment = B.definePacket({
				value = B.struct({
					attachmentType = B.uint8,
					enabled = B.bool,
				}),
				reliabilityType = "reliable",
			}),
			RepBoltOpen = B.definePacket({
				value = B.struct({ _ = B.uint8 }),
				reliabilityType = "unreliable",
			}),
			MagGrab = B.definePacket({
				value = B.struct({ _ = B.uint8 }),
				reliabilityType = "reliable",
			}),
			PlayerLean = B.definePacket({
				value = B.struct({ lean = B.float32 }),
				reliabilityType = "reliable",
			}),
			BodyAnimRequest = B.definePacket({
				value = B.struct({ neckC1 = B.cframe }),
				reliabilityType = "unreliable",
			}),
			FallDamage = B.definePacket({
				value = B.struct({ damage = B.float64 }),
				reliabilityType = "reliable",
			}),
			ReplicateFootstep = B.definePacket({
				value = B.struct({
					material = B.unknown,
					foot = B.inst,
					volume = B.float32,
				}),
				reliabilityType = "unreliable",
			}),
			BulletHit = B.definePacket({
				value = B.struct({
					toolData = B.unknown,
					rayHit = B.unknown,
					bulletCFrame = B.cframe,
				}),
				reliabilityType = "unreliable",
			}),
			RequestSuppression = B.definePacket({
				value = B.struct({
					target = B.inst,
					level = B.float32,
					factor = B.float32,
					limit = B.float32,
				}),
				reliabilityType = "reliable",
			}),
			ReportSuppression = B.definePacket({
				value = B.struct({
					level = B.float32,
					factor = B.float32,
					limit = B.float32,
				}),
				reliabilityType = "reliable",
			}),
			ReplicateFire = B.definePacket({
				value = B.struct({
					shooter = B.inst,
					firePoint = B.cframe,
				}),
				reliabilityType = "unreliable",
			}),
			ReplicateSound = B.definePacket({
				value = B.struct({
					shooter = B.inst,
					sound = B.inst,
				}),
				reliabilityType = "unreliable",
			}),
			ReplicateHit = B.definePacket({
				value = B.struct({
					toolData = B.unknown,
					rayHit = B.unknown,
				}),
				reliabilityType = "unreliable",
			}),
			ReplicateBolt = B.definePacket({
				value = B.struct({
					shooter = B.inst,
					direction = B.unknown,
					magAmmo = B.float32,
				}),
				reliabilityType = "unreliable",
			}),
			ReplicateCharacterSound = B.definePacket({
				value = B.struct({
					shooter = B.inst,
					soundType = B.string,
				}),
				reliabilityType = "unreliable",
			}),
			PlayCharacterSound = B.definePacket({
				value = B.struct({ soundType = B.string }),
				reliabilityType = "unreliable",
			}),
			ReplicateToggleAttachment = B.definePacket({
				value = B.struct({
					attachment = B.inst,
					enabled = B.bool,
					character = B.optional(B.inst),
				}),
				reliabilityType = "reliable",
			}),
			ReplicateMagGrab = B.definePacket({
				value = B.struct({ magPart = B.inst }),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
	}
end)

return namespace
