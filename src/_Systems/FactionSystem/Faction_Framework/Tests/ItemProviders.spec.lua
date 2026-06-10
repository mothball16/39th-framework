local Item = require("../Core/Item")
local ItemEquipper = require("@game/ServerScriptService/Faction_Server/ItemEquipper")
local CallbackProvider = require("../ItemProviders/Callback")
local MaxHealthProvider = require("../ItemProviders/MaxHealth")
local SpeedProvider = require("../ItemProviders/Speed")
local Maid = require("@game/ReplicatedStorage/Packages/maid")

local ORIG_MAX_HEALTH_ATTR = "OriginalMaxHealth"
local ORIG_WALK_SPEED_ATTR = "OriginalWalkSpeed"

local function createMockPlayer(userId: number, cleanupMaid: Maid.Maid)
	local character = Instance.new("Model")
	character.Name = "Character"
	cleanupMaid:GiveTask(character)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 16
	humanoid.Parent = character

	local backpack = Instance.new("Backpack")
	backpack.Parent = character

	local player = {
		UserId = userId,
		Character = character,
	}

	function player:FindFirstChildOfClass(className: string)
		if className == "Backpack" then
			return backpack
		end
		return nil
	end

	return player, humanoid
end

local function expectNoThrow(callback: () -> ())
	local ok, err = pcall(callback)
	expect(ok).to.equal(true)
	if not ok then
		error(err)
	end
end

return function()
	local maid = Maid.new()

	beforeEach(function()
		maid:DoCleaning()
	end)

	afterAll(function()
		maid:DoCleaning()
	end)

	describe("Item builders", function()
		it("should stamp type for callback items", function()
			local args = Item.callback({
				name = "CustomCallback",
			})

			expect(args.type).to.equal("Callback")
			expect(args.name).to.equal("CustomCallback")
		end)

		it("should stamp type and value for maxHealth items", function()
			local args = Item.maxHealth({
				value = 150,
				name = "Tank",
			})

			expect(args.type).to.equal("MaxHealth")
			expect(args.value).to.equal(150)
			expect(args.name).to.equal("Tank")
		end)

		it("should stamp type and value for speed items", function()
			local args = Item.speed({
				value = 24,
			})

			expect(args.type).to.equal("Speed")
			expect(args.value).to.equal(24)
		end)
	end)

	describe("Callback provider", function()
		it("should invoke onAssign with player and args", function()
			local assignCount = 0
			local receivedPlayer
			local receivedArgs

			local args = CallbackProvider.Build({
				name = "TestCallback",
				onAssign = function(player, itemArgs)
					assignCount += 1
					receivedPlayer = player
					receivedArgs = itemArgs
				end,
			})

			local player = createMockPlayer(1, maid)
			CallbackProvider.Assign(player, args)

			expect(assignCount).to.equal(1)
			expect(receivedPlayer).to.equal(player)
			expect(receivedArgs).to.equal(args)
		end)

		it("should invoke onUnassign with player and args", function()
			local unassignCount = 0

			local args = CallbackProvider.Build({
				onUnassign = function()
					unassignCount += 1
				end,
			})

			local player = createMockPlayer(1, maid)
			CallbackProvider.Unassign(player, args)

			expect(unassignCount).to.equal(1)
		end)

		it("should not error when callbacks are missing", function()
			local args = CallbackProvider.Build({})
			local player = createMockPlayer(1, maid)

			expectNoThrow(function()
				CallbackProvider.Assign(player, args)
				CallbackProvider.Unassign(player, args)
			end)
		end)
	end)

	describe("MaxHealth provider", function()
		it("should set max health and preserve the original value", function()
			local player, humanoid = createMockPlayer(1, maid)
			local args = MaxHealthProvider.Build({ value = 150 })

			MaxHealthProvider.Assign(player, args)

			expect(humanoid.MaxHealth).to.equal(150)
			expect(humanoid:GetAttribute(ORIG_MAX_HEALTH_ATTR)).to.equal(100)
		end)

		it("should clamp health when max health is lowered", function()
			local player, humanoid = createMockPlayer(1, maid)
			humanoid.Health = 100
			local args = MaxHealthProvider.Build({ value = 50 })

			MaxHealthProvider.Assign(player, args)

			expect(humanoid.MaxHealth).to.equal(50)
			expect(humanoid.Health).to.equal(50)
		end)

		it("should restore the original max health on unassign", function()
			local player, humanoid = createMockPlayer(1, maid)
			local args = MaxHealthProvider.Build({ value = 150 })

			MaxHealthProvider.Assign(player, args)
			MaxHealthProvider.Unassign(player, args)

			expect(humanoid.MaxHealth).to.equal(100)
			expect(humanoid:GetAttribute(ORIG_MAX_HEALTH_ATTR)).to.equal(nil)
		end)

		it("should keep the first original max health when assigned multiple times", function()
			local player, humanoid = createMockPlayer(1, maid)
			local firstArgs = MaxHealthProvider.Build({ value = 150 })
			local secondArgs = MaxHealthProvider.Build({ value = 200 })

			MaxHealthProvider.Assign(player, firstArgs)
			MaxHealthProvider.Assign(player, secondArgs)
			MaxHealthProvider.Unassign(player, secondArgs)

			expect(humanoid.MaxHealth).to.equal(100)
		end)

		it("should no-op when the player has no character", function()
			local player = { UserId = 1, Character = nil }
			local args = MaxHealthProvider.Build({ value = 150 })

			expectNoThrow(function()
				MaxHealthProvider.Assign(player, args)
				MaxHealthProvider.Unassign(player, args)
			end)
		end)
	end)

	describe("Speed provider", function()
		it("should set walk speed and preserve the original value", function()
			local player, humanoid = createMockPlayer(1, maid)
			local args = SpeedProvider.Build({ value = 24 })

			SpeedProvider.Assign(player, args)

			expect(humanoid.WalkSpeed).to.equal(24)
			expect(humanoid:GetAttribute(ORIG_WALK_SPEED_ATTR)).to.equal(16)
		end)

		it("should restore the original walk speed on unassign", function()
			local player, humanoid = createMockPlayer(1, maid)
			local args = SpeedProvider.Build({ value = 24 })

			SpeedProvider.Assign(player, args)
			SpeedProvider.Unassign(player, args)

			expect(humanoid.WalkSpeed).to.equal(16)
			expect(humanoid:GetAttribute(ORIG_WALK_SPEED_ATTR)).to.equal(nil)
		end)

		it("should keep the first original walk speed when assigned multiple times", function()
			local player, humanoid = createMockPlayer(1, maid)
			local firstArgs = SpeedProvider.Build({ value = 24 })
			local secondArgs = SpeedProvider.Build({ value = 32 })

			SpeedProvider.Assign(player, firstArgs)
			SpeedProvider.Assign(player, secondArgs)
			SpeedProvider.Unassign(player, secondArgs)

			expect(humanoid.WalkSpeed).to.equal(16)
		end)

		it("should no-op when the player has no character", function()
			local player = { UserId = 1, Character = nil }
			local args = SpeedProvider.Build({ value = 24 })

			expectNoThrow(function()
				SpeedProvider.Assign(player, args)
				SpeedProvider.Unassign(player, args)
			end)
		end)
	end)

	describe("ItemEquipper integration", function()
		it("should assign and unassign callback, maxHealth, and speed class items", function()
			local assignCount = 0
			local unassignCount = 0
			local player, humanoid = createMockPlayer(1, maid)

			local classConfig = {
				ID = "StatClass",
				Items = {
					Item.callback({
						onAssign = function()
							assignCount += 1
						end,
						onUnassign = function()
							unassignCount += 1
						end,
					}),
					Item.maxHealth({ value = 150 }),
					Item.speed({ value = 24 }),
				},
			}

			local itemEquipper = ItemEquipper.new({
				Callback = CallbackProvider,
				MaxHealth = MaxHealthProvider,
				Speed = SpeedProvider,
			}, {
				StatClass = classConfig,
			})

			itemEquipper:AssignClassItems(player, "StatClass")

			expect(assignCount).to.equal(1)
			expect(humanoid.MaxHealth).to.equal(150)
			expect(humanoid.WalkSpeed).to.equal(24)

			-- AssignClassItems unassigns existing items first, so reset before testing explicit unassign.
			unassignCount = 0

			itemEquipper:UnassignClassItems(player, "StatClass")

			expect(unassignCount).to.equal(1)
			expect(humanoid.MaxHealth).to.equal(100)
			expect(humanoid.WalkSpeed).to.equal(16)
		end)
	end)
end
