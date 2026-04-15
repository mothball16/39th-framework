return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local DamageLogic = require(ReplicatedStorage.SPH_Framework.Combat.DamageLogic)

	describe("DamageLogic.getDamage", function()
		it("new stats: more damage close, less damage far (linear)", function()
			local dmg = { Head = { Min = 40, Max = 100 }, Torso = { Min = 1, Max = 1 }, Other = { Min = 1, Max = 1 } }
			local range = { Min = 50, Max = 150 }
			expect(DamageLogic.getDamage(dmg, "Head", 0, range)).to.equal(100)
			expect(DamageLogic.getDamage(dmg, "Head", 150, range)).to.equal(40)
			local mid = DamageLogic.getDamage(dmg, "Head", 100, range)
			expect(math.abs(mid - 70) < 0.01).to.equal(true)
		end)

		it("new stats: no distance or range -> use low damage", function()
			local dmg = { Head = { Min = 40, Max = 100 }, Torso = { Min = 1, Max = 1 }, Other = { Min = 1, Max = 1 } }
			expect(DamageLogic.getDamage(dmg, "Head", nil, { Min = 0, Max = 100 })).to.equal(40)
			expect(DamageLogic.getDamage(dmg, "Head", 10, nil)).to.equal(40)
		end)

		it("old stats: per-part numbers still work", function()
			local dmg = { Head = 90, Torso = 35, Other = 15, LeftFoot = 7 }
			expect(DamageLogic.getDamage(dmg, "LeftFoot")).to.equal(7)
			local dmg2 = { UpperTorso = 44, Torso = 33, Other = 11 }
			expect(DamageLogic.getDamage(dmg2, "HumanoidRootPart")).to.equal(44)
		end)
	end)
end
