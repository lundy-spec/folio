local Cache = require("Data.Cache")

describe("Data.Cache", function()
	after_each(function()
		Cache.Clear()
	end)

	it("starts empty", function()
		assert.are.same({}, Cache.GetItems())
	end)

	it("returns whatever was last set", function()
		local items = { { itemID = 1 }, { itemID = 2 } }
		Cache.SetItems(items)
		assert.are.same(items, Cache.GetItems())
	end)

	it("overwrites the previous set on a second call", function()
		Cache.SetItems({ { itemID = 1 } })
		Cache.SetItems({ { itemID = 2 } })
		assert.are.equal(1, #Cache.GetItems())
		assert.are.equal(2, Cache.GetItems()[1].itemID)
	end)

	it("Clear resets back to empty", function()
		Cache.SetItems({ { itemID = 1 } })
		Cache.Clear()
		assert.are.same({}, Cache.GetItems())
	end)
end)
