local Transfer = require("Logic.Transfer")

describe("Logic.Transfer", function()
	describe("Validate", function()
		it("allows a move between two different storages with a free slot", function()
			local ok = Transfer.Validate({
				fromStorage = "bags",
				toStorage = "bank",
				eligible = true,
				destinationBag = 6,
			})
			assert.is_true(ok)
		end)

		it("rejects moving to the storage the item is already in", function()
			local ok, reason = Transfer.Validate({
				fromStorage = "bags",
				toStorage = "bags",
				eligible = true,
				destinationBag = 0,
			})
			assert.is_false(ok)
			assert.are.equal("already there", reason)
		end)

		it("rejects an ineligible destination (e.g. soulbound -> bank)", function()
			local ok, reason = Transfer.Validate({
				fromStorage = "bags",
				toStorage = "bank",
				eligible = false,
				destinationBag = 12,
			})
			assert.is_false(ok)
			assert.are.equal("not allowed in that storage", reason)
		end)

		it("rejects a destination with no free slot", function()
			local ok, reason = Transfer.Validate({
				fromStorage = "bags",
				toStorage = "bank",
				eligible = true,
				destinationBag = nil,
			})
			assert.is_false(ok)
			assert.are.equal("no free slot", reason)
		end)

		it("does not require eligible to be explicitly true (nil means no restriction applies)", function()
			local ok = Transfer.Validate({
				fromStorage = "bank",
				toStorage = "bags",
				eligible = nil,
				destinationBag = 0,
			})
			assert.is_true(ok)
		end)
	end)
end)
