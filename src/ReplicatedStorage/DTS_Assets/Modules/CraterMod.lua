--Original by: kash_from_roblox
--Modified by: Jarr

local CraterModule = {}
local config = require(game.ReplicatedStorage.DTS_Assets.GlobalSettings)

local materialResistance = --Multiplies the radius and depth.
	{
		--Hard materials
		CrackedLava = 0.25,
		Rock = 0.25,
		Asphalt = 0.25,
		Basalt = 0.5,
		Slate = 0.5,
		Cobblestone = 0.5,
		Pavement = 0.5,
		Concrete = 0.5,
		Brick = 0.5,
		Limestone = 0.5,
		Salt = 0.5,
		Glacier = 0.75,
		Sandstone = 0.75,
		--Soft materials
		Ice = 1,
		Mud = 1,
		Ground = 1,
		Grass = 1,
		LeafyGrass = 1.25,
		WoodPlanks = 1.5,
		Sand = 1.5,
		Snow = 1.5,
		--
		Water = 0,
		--Everything else gets 1
	}

local materials =
	{
		Dirt = {Enum.Material.Grass, Enum.Material.Ground, Enum.Material.LeafyGrass, Enum.Material.Mud},
		Sand = {Enum.Material.Sand, Enum.Material.Limestone, Enum.Material.Sandstone},
	}

-- Function to create a crater at the specified position
function CraterModule.CreateCrater(position:Vector3, radius:number, depth:number, hitMaterial:Enum.Material?)
	local terrain = workspace.Terrain
	if hitMaterial == Enum.Material.Water then return end
	
	-- Simulate material hardness and resistance to cratering by reducing radius and depth.
	local findResistance = hitMaterial and materialResistance[hitMaterial.Name]
	if findResistance then
		radius = radius*findResistance
		depth = depth*(findResistance*0.5)
	end
	
	if radius==0 or depth==0 then return end
	
	radius = math.max(radius * (config.terrainExplosionMult or 1), 1)  --Minimum radius of 1
	depth = math.abs(depth * (config.terrainExplosionMult or 1)) --Depth cannot be negative

	-- Set a base scaling factor for depth
	local depthScale = 0.5  -- Adjust this value for the desired appearance
	local scaledDepth = depth * depthScale

	-- Adjust the crater center with a fixed offset of 5 studs above the position
	local craterCenter = position + Vector3.new(0, 5, 0) - Vector3.new(0, scaledDepth, 0)

	-- Check if the terrain at the crater center is not water
	local region = Region3.new(
		craterCenter - Vector3.new(radius, radius, radius), 
		craterCenter + Vector3.new(radius, radius, radius)
	):ExpandToGrid(4)

	local materials = terrain:ReadVoxels(region, 4)
	for x = 1, #materials do
		for y = 1, #materials[x] do
			for z = 1, #materials[x][y] do
				if materials[x][y][z] == Enum.Material.Water then
					return
				end
			end
		end
	end
	terrain:FillBall(craterCenter, radius, Enum.Material.Air)
	
	--if materials[1][1][1] ~= Enum.Material.Water then
	--	terrain:FillBall(craterCenter, radius, Enum.Material.Air)
	--end

	CraterModule.CreateRimWithRaycasts(position, radius, scaledDepth)
end

function CraterModule.CreateRimWithRaycasts(position, radius)
	local terrain = workspace.Terrain
	local rimRadius = radius * 1.15  --Slightly larger than the crater radius for alignment
	local numRaycasts = math.max(12, math.floor(rimRadius * 3))  --Ensure smooth coverage
	local angleStep = 360 / numRaycasts  --Calculate angle between rays

	--Loop around the crater to place thin rim segments
	for angle = 0, 360 - angleStep, angleStep do
		local direction = Vector3.new(
			math.cos(math.rad(angle)) * rimRadius,
			0,
			math.sin(math.rad(angle)) * rimRadius
		)

		--Perform raycast to find the terrain's surface at this direction
		local rayStart = position + direction + Vector3.new(0, 10, 0)
		local rayEnd = rayStart - Vector3.new(0, 20, 0)
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {terrain}
		rayParams.FilterType = Enum.RaycastFilterType.Include
		local rayResult = workspace:Raycast(rayStart, rayEnd - rayStart, rayParams)

		if rayResult and rayResult.Material ~= Enum.Material.Water then
			--Determine the rim material based on the surface material
			local rimMaterial
			if table.find(materials.Sand, rimMaterial) then
				rimMaterial = Enum.Material.Sandstone --Sandstone for sand-related materials
			elseif table.find(materials.Dirt, rimMaterial) then
				rimMaterial = Enum.Material.Mud
			else
				rimMaterial = rayResult.Material --Default to the material at the rim
			end

			--Position the rim segment at the raycast hit point
			local hitPosition = rayResult.Position
			terrain:FillBall(hitPosition, radius * 0.05, rimMaterial)
		end
	end
end

return CraterModule