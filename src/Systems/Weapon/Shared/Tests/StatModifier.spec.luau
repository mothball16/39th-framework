return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StatModifier = require(ReplicatedStorage.Utility.StatModifier)

	describe("StatModifier", function()
		it("returns base stats when no modifiers", function()
			local base = { Damage = 10, Speed = 2 }
			local sm = StatModifier.new(base)

			local stats = sm:GetStats()
			expect(stats.Damage).to.equal(10)
			expect(stats.Speed).to.equal(2)
		end)

		it("stacks Add modifiers (numbers)", function()
			local sm = StatModifier.new({ Damage = 10 })
			sm:Add({ Damage = 5 }):Add({ Damage = 2 })

			expect(sm:GetStats().Damage).to.equal(17)
		end)

		it("stacks Multiply modifiers (numbers)", function()
			local sm = StatModifier.new({ Damage = 10 })
			sm:Multiply({ Damage = 0.5 }):Multiply({ Damage = 0.5 })

			-- (10 + 0) * (1 + 1.0) = 20
			expect(sm:GetStats().Damage).to.equal(20)
		end)

		it("applies Add then Multiply in that order", function()
			local sm = StatModifier.new({ Damage = 10 })
			sm:Add({ Damage = 5 })
			sm:Multiply({ Damage = 1.0 })

			-- (10 + 5) * (1 + 1) = 30
			expect(sm:GetStats().Damage).to.equal(30)
		end)

		it("override replaces base before Add/Multiply", function()
			local sm = StatModifier.new({ Damage = 10 })
			sm:Override({ Damage = 7 })
			sm:Add({ Damage = 5 })
			sm:Multiply({ Damage = 1.0 })

			-- (7 + 5) * 2 = 24
			expect(sm:GetStats().Damage).to.equal(24)
		end)

		it("GetKeyModifiers returns per-key modifier values", function()
			local sm = StatModifier.new({ Damage = 10, Speed = 2 })
			sm:Add({ Damage = 1 })
			sm:Multiply({ Speed = 0.25 })
			sm:Override({ Damage = 9 })

			local dmg = sm:GetKeyModifiers("Damage")
			expect(dmg.add).to.equal(1)
			expect(dmg.multiply).to.equal(nil)
			expect(dmg.override).to.equal(9)

			local speed = sm:GetKeyModifiers("Speed")
			expect(speed.add).to.equal(nil)
			expect(speed.multiply).to.equal(0.25)
			expect(speed.override).to.equal(nil)
		end)

		it("supports nested table stats with table-shaped modifiers", function()
			local sm = StatModifier.new({
				Damage = { Head = 100, Torso = 50 },
				Recoil = { Hip = { Up = 1, Side = 2 } },
			})

			sm:Add({
				Damage = { Head = 10, Torso = 5 },
				Recoil = { Hip = { Up = 0.5, Side = 1 } },
			})

			sm:Multiply({
				Damage = { Head = 0.5, Torso = 0 },
				Recoil = { Hip = { Up = 1.0, Side = 0 } },
			})

			local stats = sm:GetStats()
			expect(stats.Damage.Head).to.equal((100 + 10) * 1.5)
			expect(stats.Damage.Torso).to.equal((50 + 5) * 1.0)
			expect(stats.Recoil.Hip.Up).to.equal((1 + 0.5) * 2.0)
			expect(stats.Recoil.Hip.Side).to.equal((2 + 1) * 1.0)
		end)

		it("supports scalar Add/Multiply applied across nested tables", function()
			local sm = StatModifier.new({ Damage = { Head = 100, Torso = 50 } })
			sm:Add({ Damage = 5 })
			sm:Multiply({ Damage = 0.1 })

			local stats = sm:GetStats()
			expect(stats.Damage.Head).to.equal((100 + 5) * 1.1)
			expect(stats.Damage.Torso).to.equal((50 + 5) * 1.1)
		end)

		it("does not mutate nested base stats when modifiers are applied", function()
			local base = { Damage = { Head = 100, Torso = 50 } }
			local sm = StatModifier.new(base)
			sm:Add({ Damage = { Head = 10 } })

			local stats = sm:GetStats()

			expect(stats.Damage.Head).to.equal(110)
			expect(stats.Damage.Torso).to.equal(50)
			expect(base.Damage.Head).to.equal(100)
			expect(base.Damage.Torso).to.equal(50)
		end)

		it("treats missing nested Add/Multiply entries as zero", function()
			local sm = StatModifier.new({ Damage = { Head = 100, Torso = 50 } })
			sm:Add({ Damage = { Head = 10 } })
			sm:Multiply({ Damage = { Torso = 0.5 } })

			local stats = sm:GetStats()
			expect(stats.Damage.Head).to.equal(110)
			expect(stats.Damage.Torso).to.equal(75)
		end)

		it("GetRaw returns the original base reference", function()
			local base = { Damage = 10 }
			local sm = StatModifier.new(base)
			expect(sm:GetRaw()).to.equal(base)
		end)

		it("Apply clears dirty flag so repeated GetStats is stable", function()
			local sm = StatModifier.new({ Damage = 10 })
			sm:Add({ Damage = 1 })

			local a = sm:GetStats().Damage
			local b = sm:GetStats().Damage
			expect(a).to.equal(11)
			expect(b).to.equal(11)
		end)
	end)
end
