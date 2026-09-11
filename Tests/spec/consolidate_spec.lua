local Consolidate = require("Logic.Consolidate")

describe("Logic.Consolidate", function()
	describe("MergeStacks", function()
		it("sums counts for multiple stacks of the same itemID", function()
			local items = {
				{ itemID = 1, count = 3, bag = 0, slot = 1 },
				{ itemID = 1, count = 5, bag = 0, slot = 4 },
			}
			local result = Consolidate.MergeStacks(items)

			assert.are.equal(1, #result)
			assert.are.equal(8, result[1].count)
		end)

		it("keeps different-quality stacks of the same itemID separate", function()
			local items = {
				{ itemID = 1, count = 3, craftingQuality = 1 },
				{ itemID = 1, count = 5, craftingQuality = 2 },
			}
			local result = Consolidate.MergeStacks(items)

			assert.are.equal(2, #result)
		end)

		it("keeps different itemIDs separate", function()
			local items = {
				{ itemID = 1, count = 1 },
				{ itemID = 2, count = 1 },
			}
			local result = Consolidate.MergeStacks(items)

			assert.are.equal(2, #result)
		end)

		it("defaults a missing count to 1 before summing", function()
			local items = {
				{ itemID = 1 },
				{ itemID = 1, count = 2 },
			}
			local result = Consolidate.MergeStacks(items)

			assert.are.equal(1, #result)
			assert.are.equal(3, result[1].count)
		end)

		it("keeps the first-encountered stack's other fields as representative", function()
			local items = {
				{ itemID = 1, count = 3, bag = 0, slot = 1, itemLink = "item:1:first" },
				{ itemID = 1, count = 5, bag = 1, slot = 2, itemLink = "item:1:second" },
			}
			local result = Consolidate.MergeStacks(items)

			assert.are.equal(0, result[1].bag)
			assert.are.equal(1, result[1].slot)
			assert.are.equal("item:1:first", result[1].itemLink)
		end)

		it("preserves first-encountered order across merged and unmerged entries", function()
			local items = {
				{ itemID = 2, count = 1 },
				{ itemID = 1, count = 3 },
				{ itemID = 1, count = 5 },
			}
			local result = Consolidate.MergeStacks(items)

			assert.are.equal(2, result[1].itemID)
			assert.are.equal(1, result[2].itemID)
			assert.are.equal(8, result[2].count)
		end)

		it("does not mutate the source item tables", function()
			local source = { itemID = 1, count = 3 }
			Consolidate.MergeStacks({ source, { itemID = 1, count = 5 } })
			assert.are.equal(3, source.count)
		end)

		it("returns an empty list for an empty input", function()
			assert.are.same({}, Consolidate.MergeStacks({}))
		end)
	end)
end)
