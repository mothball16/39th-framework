return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CameraZoomManager = require(ReplicatedStorage.Utility.CameraZoomManager)

	local testIndex = 0
	local function getId(name: string): string
		testIndex += 1
		return `CameraZoomManagerTest.{testIndex}.{name}`
	end

	describe("CameraZoomManager", function()
		it("resolves FOV and zoom distance independently", function()
			local base = CameraZoomManager.Register(getId("base"), 0, {
				fieldOfView = function()
					return 70
				end,
				maxZoomDistance = function()
					return 12
				end,
			})
			local fov = CameraZoomManager.Register(getId("fov"), 10, {
				fieldOfView = function()
					return 45
				end,
			})
			local zoomDistance = CameraZoomManager.Register(getId("zoom"), 10, {
				maxZoomDistance = function()
					return 0.5
				end,
			})

			local values = CameraZoomManager.Resolve()
			expect(values.fieldOfView).to.equal(45)
			expect(values.maxZoomDistance).to.equal(0.5)

			base()
			fov()
			zoomDistance()
		end)

		it("uses registration order for ties and falls back from nil targets", function()
			local first = CameraZoomManager.Register(getId("first"), 5, {
				fieldOfView = function()
					return 60
				end,
			})
			local second = CameraZoomManager.Register(getId("second"), 5, {
				fieldOfView = function()
					return 75
				end,
			})
			local nilTarget = CameraZoomManager.Register(getId("nil"), 10, {
				fieldOfView = function()
					return nil
				end,
			})

			expect(CameraZoomManager.Resolve().fieldOfView).to.equal(60)

			first()
			expect(CameraZoomManager.Resolve().fieldOfView).to.equal(75)

			nilTarget()
			second()
		end)

		it("keeps FOV interpolation metadata with the winning FOV", function()
			local low = CameraZoomManager.Register(getId("low"), 1, {
				fieldOfView = function()
					return 80
				end,
				fieldOfViewLerpSpeed = function()
					return 10
				end,
			})
			local high = CameraZoomManager.Register(getId("high"), 2, {
				fieldOfView = function()
					return 50
				end,
				fieldOfViewLerpSpeed = function()
					return 3
				end,
			})

			local values = CameraZoomManager.Resolve()
			expect(values.fieldOfView).to.equal(50)
			expect(values.fieldOfViewLerpSpeed).to.equal(3)

			high()
			values = CameraZoomManager.Resolve()
			expect(values.fieldOfView).to.equal(80)
			expect(values.fieldOfViewLerpSpeed).to.equal(10)

			low()
		end)

		it("replaces an existing id and ignores stale cleanup", function()
			local id = getId("replace")
			local first = CameraZoomManager.Register(id, 0, {
				maxZoomDistance = function()
					return 12
				end,
			})
			local second = CameraZoomManager.Register(id, 0, {
				maxZoomDistance = function()
					return 0.5
				end,
			})

			expect(CameraZoomManager.Resolve().maxZoomDistance).to.equal(0.5)

			first()
			expect(CameraZoomManager.Resolve().maxZoomDistance).to.equal(0.5)

			second()
			expect(CameraZoomManager.Resolve().maxZoomDistance).to.equal(nil)
		end)
	end)
end
