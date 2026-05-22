return function()
	local Access = require("../Access")
	local Maid = require("@game/ReplicatedStorage/Packages/maid")
	local UniformProvider = require("../ItemProviders/Uniform")

	local uniformAssets = Access.Config.ItemTypePaths[UniformProvider.ID]
	assert(uniformAssets, "Uniform asset path missing from Access.Config.ItemTypePaths")

	local function createUniformAsset(itemName: string, shirtTemplate: string?, pantsTemplate: string?, tshirtGraphic: string?)
		local folder = Instance.new("Folder")
		folder.Name = itemName
		folder.Parent = uniformAssets
	
		if shirtTemplate then
			local shirt = Instance.new("Shirt")
			shirt.ShirtTemplate = shirtTemplate
			shirt.Parent = folder
		end

		if pantsTemplate then
			local pants = Instance.new("Pants")
			pants.PantsTemplate = pantsTemplate
			pants.Parent = folder
		end

		if tshirtGraphic then
			local tshirt = Instance.new("ShirtGraphic")
			tshirt.Graphic = tshirtGraphic
			tshirt.Parent = folder
		end
		return folder
	end

	local function createPlayerCharacter()
		local character = Instance.new("Model")
		character.Name = "TestCharacter"
		character.Parent = workspace
		return {
			Character = character,
			Destroy = function()
				character:Destroy()
			end,
		}
	end

	describe("UniformProvider", function()
		local maid
		beforeEach(function()
			maid = Maid.new()
		end)

		afterEach(function()
			maid:DoCleaning()
		end)

		it("GetItem returns clothing template payload for configured uniform", function()
			maid:GiveTask(createUniformAsset("SpecUniform_GetItem", "rbxassetid://shirt_1", "rbxassetid://pants_1", "rbxassetid://graphic_1"))

			local item = UniformProvider.GetItem("SpecUniform_GetItem")
			expect(item).to.be.ok()
			expect(item.Shirt).to.equal("rbxassetid://shirt_1")
			expect(item.Pants).to.equal("rbxassetid://pants_1")
			expect(item.TShirt).to.equal("rbxassetid://graphic_1")
		end)

		it("Assign creates missing clothing instances from uniform item", function()
			maid:GiveTask(createUniformAsset("SpecUniform_AssignCreate", "rbxassetid://shirt_new", "rbxassetid://pants_new", "rbxassetid://graphic_new"))
			local player = maid:GiveTask(createPlayerCharacter())

			UniformProvider.Assign(player, { itemName = "SpecUniform_AssignCreate" })

			local character = player.Character
			local shirt = character:FindFirstChildOfClass("Shirt")
			local pants = character:FindFirstChildOfClass("Pants")
			local tshirt = character:FindFirstChildOfClass("ShirtGraphic")

			expect(shirt).to.be.ok()
			expect(pants).to.be.ok()
			expect(tshirt).to.be.ok()
			expect(shirt.ShirtTemplate).to.equal("rbxassetid://shirt_new")
			expect(pants.PantsTemplate).to.equal("rbxassetid://pants_new")
			expect(tshirt.Graphic).to.equal("rbxassetid://graphic_new")
		end)

		it("Assign stores original templates and Unassign restores them", function()
			createUniformAsset("SpecUniform_Restore", "rbxassetid://shirt_uniform", "rbxassetid://pants_uniform", "rbxassetid://graphic_uniform")
			local player = maid:GiveTask(createPlayerCharacter())
			local character = player.Character

			local shirt = maid:GiveTask(Instance.new("Shirt"))
			shirt.ShirtTemplate = "rbxassetid://shirt_orig"
			shirt.Parent = character

			local pants = maid:GiveTask(Instance.new("Pants"))
			pants.PantsTemplate = "rbxassetid://pants_orig"
			pants.Parent = character

			local tshirt = maid:GiveTask(Instance.new("ShirtGraphic"))
			tshirt.Graphic = "rbxassetid://graphic_orig"
			tshirt.Parent = character

			UniformProvider.Assign(player, { itemName = "SpecUniform_Restore" })

			expect(shirt:GetAttribute("OriginalClothing")).to.equal("rbxassetid://shirt_orig")
			expect(pants:GetAttribute("OriginalClothing")).to.equal("rbxassetid://pants_orig")
			expect(tshirt:GetAttribute("OriginalClothing")).to.equal("rbxassetid://graphic_orig")

			expect(shirt.ShirtTemplate).to.equal("rbxassetid://shirt_uniform")
			expect(pants.PantsTemplate).to.equal("rbxassetid://pants_uniform")
			expect(tshirt.Graphic).to.equal("rbxassetid://graphic_uniform")

			UniformProvider.Unassign(player, { itemName = "SpecUniform_Restore" })

			expect(shirt.ShirtTemplate).to.equal("rbxassetid://shirt_orig")
			expect(pants.PantsTemplate).to.equal("rbxassetid://pants_orig")
			expect(tshirt.Graphic).to.equal("rbxassetid://graphic_orig")
		end)

		it("Unassign removes clothing when no original template attribute exists", function()
			maid:GiveTask(createUniformAsset("SpecUniform_UnassignDestroy", "rbxassetid://shirt_tmp", "rbxassetid://pants_tmp", "rbxassetid://graphic_tmp"))
			local player = maid:GiveTask(createPlayerCharacter())

			UniformProvider.Assign(player, { itemName = "SpecUniform_UnassignDestroy" })
			UniformProvider.Unassign(player, { itemName = "SpecUniform_UnassignDestroy" })

			local character = player.Character
			expect(character:FindFirstChildOfClass("Shirt")).to.equal(nil)
			expect(character:FindFirstChildOfClass("Pants")).to.equal(nil)
			expect(character:FindFirstChildOfClass("ShirtGraphic")).to.equal(nil)
		end)
	end)
end
