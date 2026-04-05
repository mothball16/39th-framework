local module = {}

module.AimRecoil = function(Recoil,RecoilPunch,RecoilPower,vP,hP,dP,AimRecoilReduction)
	local modPower = RecoilPower/AimRecoilReduction
	local RecoilAngles = CFrame.Angles(math.rad(vP*modPower),math.rad(hP*modPower),math.rad(dP*modPower))
	return Recoil:lerp(Recoil*CFrame.new(0,-RecoilPunch/8,RecoilPunch) * RecoilAngles,.25)
end

module.HipRecoil = function(Recoil,RecoilPunch,RecoilPower,vP,hP,dP)
	local RecoilAngles = CFrame.Angles(math.rad(vP*RecoilPower),math.rad(hP*RecoilPower),math.rad(dP*RecoilPower))
	return Recoil:lerp(Recoil*CFrame.new(0,0,RecoilPunch/2) * RecoilAngles,1)
end

module.BipodAimRecoil = function(Recoil,RecoilPunch,RecoilPower,vP,hP,dP,AimRecoilReduction)
	local modPower = RecoilPower*math.min(1/AimRecoilReduction,0.25)
	local RecoilAngles = CFrame.Angles(math.rad(vP*modPower),math.rad(hP*modPower),math.rad(dP*modPower))
	return Recoil:lerp(Recoil*CFrame.new(0,-RecoilPunch/8,RecoilPunch) * RecoilAngles,1)
end

module.BipodHipRecoil = function(Recoil,RecoilPunch,RecoilPower,vP,hP,dP)
	local modPower = RecoilPower*0.25
	local RecoilAngles = CFrame.Angles(math.rad(vP*modPower),math.rad(hP*modPower),math.rad(dP*modPower))
	return Recoil:lerp(Recoil*CFrame.new(0,-RecoilPunch/8,RecoilPunch) * RecoilAngles,1)
end

return module
