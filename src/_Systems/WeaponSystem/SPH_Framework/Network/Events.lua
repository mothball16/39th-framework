-- ByteNetMax namespace for SPH (same pattern as Class_Framework/Core/Events.lua; no legacy remotes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local ByteNetMax = require(Packages["bytenet-max"])

local B = ByteNetMax

local namespace = B.defineNamespace("SPH_Framework", function()
	return {
		packets = {
			SwitchWeapon = B.definePacket({
				value = B.struct({
					tool = B.optional(B.inst),
				}),
			}),
			PlayerFire = B.definePacket({
				value = B.struct({
					firePoint = B.cframe,
				}),
			}),
			PlaySound = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					soundName = B.string,
					firstPerson = B.bool,
				}),
			}),
			Reload = B.definePacket({
				value = B.struct({
					_ = B.uint8,
				}),
			}),
			PlayerChamber = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					_ = B.uint8,
				}),
			}),
			MoveBolt = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					-- CFrame offset or numeric bolt travel (see BulletHandler.MoveBolt).
					direction = B.unknown,
					magAmmo = B.float32,
				}),
			}),
			SwitchFireMode = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					mode = B.uint8,
				}),
			}),
			PlayerDropGun = B.definePacket({
				value = B.struct({
					_ = B.uint8,
				}),
			}),
			PlayerToggleAttachment = B.definePacket({
				value = B.struct({
					attachmentType = B.uint8,
					enabled = B.bool,
				}),
			}),
			RepBoltOpen = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					_ = B.uint8,
				}),
			}),
			MagGrab = B.definePacket({
				value = B.struct({
					_ = B.uint8,
				}),
			}),
			PlayerLean = B.definePacket({
				value = B.struct({
					lean = B.float32,
				}),
			}),
			BodyAnimRequest = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					neckC1 = B.cframe,
				}),
			}),
			FallDamage = B.definePacket({
				value = B.struct({
					damage = B.float64,
				}),
			}),
			ReplicateFootstep = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					material = B.unknown,
					foot = B.inst,
					volume = B.float32,
				}),
			}),
			BulletHit = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					toolData = B.unknown,
					rayHit = B.unknown,
					bulletCFrame = B.cframe,
				}),
			}),
			ReplicateFire = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					shooter = B.inst,
					firePoint = B.cframe,
				}),
			}),
			ReplicateSound = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					shooter = B.inst,
					sound = B.inst,
				}),
			}),
			ReplicateHit = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					toolData = B.unknown,
					rayHit = B.unknown,
				}),
			}),
			ReplicateBolt = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					shooter = B.inst,
					direction = B.unknown,
					magAmmo = B.float32,
				}),
			}),
			ReplicateCharacterSound = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					shooter = B.inst,
					soundType = B.string,
				}),
			}),
			PlayCharacterSound = B.definePacket({
				reliabilityType = "unreliable",
				value = B.struct({
					soundType = B.string,
				}),
			}),
			ReplicateToggleAttachment = B.definePacket({
				value = B.struct({
					attachment = B.inst,
					enabled = B.bool,
					character = B.optional(B.inst),
				}),
			}),
			ReplicateMagGrab = B.definePacket({
				value = B.struct({
					magPart = B.inst,
				}),
			}),
		},
		queries = {},
	}
end)

local Events = {}

function Events.GetNamespace()
	return namespace
end

return Events
