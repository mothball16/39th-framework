local module = {}

local BACKWARD_RECOIL_FACTOR_INFLUENCE = 0.5

local function backwardPunch(recoilPunch, recoilPower)
	return recoilPunch / 2 * (1 + (recoilPower - 1) * BACKWARD_RECOIL_FACTOR_INFLUENCE)
end

module.Recoil = function(Recoil, RecoilPunch, RecoilPower, vP, hP, dP)
	local RecoilAngles =
		CFrame.Angles(math.rad(vP * RecoilPower), math.rad(hP * RecoilPower), math.rad(dP * RecoilPower))
	return Recoil:lerp(Recoil * CFrame.new(0, 0, backwardPunch(RecoilPunch, RecoilPower)) * RecoilAngles, 1)
end

module.BipodRecoil = function(Recoil, RecoilPunch, RecoilPower, vP, hP, dP)
	local modPower = RecoilPower * 0.25
	local RecoilAngles = CFrame.Angles(math.rad(vP * modPower), math.rad(hP * modPower), math.rad(dP * modPower))
	return Recoil:lerp(Recoil * CFrame.new(0, 0, backwardPunch(RecoilPunch, modPower)) * RecoilAngles, 1)
end

return module
