local Sort = require("Logic.Sort")

describe("Logic.Sort", function()
	describe("ApplyManualOrder", function()
		it("returns items unchanged when there is no manual order yet", function()
			local items = { { itemID = 3 }, { itemID = 1 }, { itemID = 2 } }
			local result = Sort.ApplyManualOrder(items, nil)
			assert.are.same(items, result)
		end)

		it("returns items unchanged for an empty order list", function()
			local items = { { itemID = 3 }, { itemID = 1 } }
			local result = Sort.ApplyManualOrder(items, {})
			assert.are.same(items, result)
		end)

		it("sorts items to match the given order", function()
			local items = { { itemID = 3 }, { itemID = 1 }, { itemID = 2 } }
			local result = Sort.ApplyManualOrder(items, { 1, 2, 3 })
			assert.are.same({ 1, 2, 3 }, { result[1].itemID, result[2].itemID, result[3].itemID })
		end)

		it("appends items missing from the order after the ranked ones, in original relative order", function()
			local items = { { itemID = 5 }, { itemID = 1 }, { itemID = 9 }, { itemID = 2 } }
			local result = Sort.ApplyManualOrder(items, { 2, 1 })
			assert.are.same({ 2, 1, 5, 9 }, { result[1].itemID, result[2].itemID, result[3].itemID, result[4].itemID })
		end)

		it("keeps duplicate stacks of the same itemID together, tie-broken by original order", function()
			local items = { { itemID = 1, slot = "a" }, { itemID = 2 }, { itemID = 1, slot = "b" } }
			local result = Sort.ApplyManualOrder(items, { 1, 2 })
			assert.are.same({ 1, 1, 2 }, { result[1].itemID, result[2].itemID, result[3].itemID })
			assert.are.equal("a", result[1].slot)
			assert.are.equal("b", result[2].slot)
		end)

		it("ignores orderedIds entries that don't match any current item", function()
			local items = { { itemID = 1 }, { itemID = 2 } }
			local result = Sort.ApplyManualOrder(items, { 99, 2, 1 })
			assert.are.same({ 2, 1 }, { result[1].itemID, result[2].itemID })
		end)
	end)

	describe("Reposition", function()
		it("seeds a fresh order from the current items on the first-ever reorder", function()
			local seedItems = { { itemID = 1 }, { itemID = 2 }, { itemID = 3 } }
			local order = Sort.Reposition(nil, seedItems, 1, 3, "before")
			assert.are.same({ 2, 1, 3 }, order)
		end)

		it("moves an item to sit before the target", function()
			local order = Sort.Reposition({ 1, 2, 3 }, nil, 3, 1, "before")
			assert.are.same({ 3, 1, 2 }, order)
		end)

		it("moves an item to sit after the target", function()
			local order = Sort.Reposition({ 1, 2, 3 }, nil, 1, 3, "after")
			assert.are.same({ 2, 3, 1 }, order)
		end)

		it("appends the item at the end if the target isn't found in the order", function()
			local order = Sort.Reposition({ 1, 2 }, nil, 3, 99, "after")
			assert.are.same({ 1, 2, 3 }, order)
		end)

		it("mutates and returns the same table instance", function()
			local order = { 1, 2, 3 }
			local result = Sort.Reposition(order, nil, 1, 3, "after")
			assert.are.equal(order, result)
		end)
	end)
	describe("TrackArrivals", function()
		local function ids(list)
			local out = {}
			for i, id in ipairs(list) do out[i] = { itemID = id } end
			return out
		end

		it("numbers a first-ever scan in scan order", function()
			local state = {}
			Sort.TrackArrivals(state, ids({ 7, 3, 9 }), true)
			assert.are.same({ [7] = 1, [3] = 2, [9] = 3 }, state.seq)
			assert.are.equal(4, state.next)
		end)

		it("gives a new item the next number, leaving existing items alone", function()
			local state = {}
			Sort.TrackArrivals(state, ids({ 7, 3 }), true)
			-- 5 picked up into an earlier bag slot than 3
			Sort.TrackArrivals(state, ids({ 7, 5, 3 }), true)
			assert.are.same({ [7] = 1, [3] = 2, [5] = 3 }, state.seq)
		end)

		it("forgets items that left, and returns them, when removal is allowed", function()
			local state = {}
			Sort.TrackArrivals(state, ids({ 7, 3 }), true)
			local removed = Sort.TrackArrivals(state, ids({ 7 }), true)
			assert.are.same({ 3 }, removed)
			assert.is_nil(state.seq[3])
		end)

		it("an item that left and came back counts as new", function()
			local state = {}
			Sort.TrackArrivals(state, ids({ 7, 3 }), true)
			Sort.TrackArrivals(state, ids({ 7 }), true)
			Sort.TrackArrivals(state, ids({ 3, 7 }), true)
			assert.are.equal(3, state.seq[3])
		end)

		it("keeps everything when removal isn't allowed (possibly partial scan)", function()
			local state = {}
			Sort.TrackArrivals(state, ids({ 7, 3 }), true)
			local removed = Sort.TrackArrivals(state, ids({}), false)
			assert.are.same({}, removed)
			assert.are.same({ [7] = 1, [3] = 2 }, state.seq)
		end)
	end)

	describe("ByArrival", function()
		it("orders by arrival number, not scan order", function()
			local items = { { itemID = 5 }, { itemID = 7 }, { itemID = 3 } }
			local result = Sort.ByArrival(items, { [7] = 1, [3] = 2, [5] = 3 })
			assert.are.same({ 7, 3, 5 }, { result[1].itemID, result[2].itemID, result[3].itemID })
		end)

		it("puts unnumbered items last, in original order", function()
			local items = { { itemID = 8 }, { itemID = 7 }, { itemID = 9 } }
			local result = Sort.ByArrival(items, { [7] = 1 })
			assert.are.same({ 7, 8, 9 }, { result[1].itemID, result[2].itemID, result[3].itemID })
		end)

		it("returns items unchanged with no arrival data", function()
			local items = { { itemID = 2 }, { itemID = 1 } }
			assert.are.same(items, Sort.ByArrival(items, nil))
		end)
	end)
end)
