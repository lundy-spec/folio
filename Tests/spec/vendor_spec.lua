local Vendor = require("Logic.Vendor")

describe("Logic.Vendor", function()
	describe("CalculateProfit", function()
		it("sums sellPrice times count across items", function()
			local total = Vendor.CalculateProfit({
				{ sellPrice = 10, count = 3 },
				{ sellPrice = 5, count = 1 },
			})
			assert.are.equal(35, total)
		end)

		it("defaults a missing count to 1", function()
			local total = Vendor.CalculateProfit({ { sellPrice = 7 } })
			assert.are.equal(7, total)
		end)

		it("treats a missing sellPrice as 0", function()
			local total = Vendor.CalculateProfit({ { count = 5 } })
			assert.are.equal(0, total)
		end)

		it("returns 0 for an empty list", function()
			assert.are.equal(0, Vendor.CalculateProfit({}))
		end)
	end)
end)
