local Scanner = require("Data.Scanner")

describe("Data.Scanner", function()
	it("normalizes every occupied slot across the given bags", function()
		local slots = {
			[0] = {
				[1] = { itemID = 111, hyperlink = "item:111", itemName = "Healing Potion", iconFileID = 1001, stackCount = 5, quality = 1, isBound = false },
			},
			[1] = {
				[1] = { itemID = 222, hyperlink = "item:222", itemName = "Flask", iconFileID = 1002, stackCount = 1, quality = 3, isBound = true },
			},
		}
		local fakeApi = {
			GetContainerNumSlots = function(bag) return bag == 0 and 1 or 1 end,
			GetContainerItemInfo = function(bag, slot)
				return slots[bag] and slots[bag][slot]
			end,
			GetItemLevel = function(link)
				return link == "item:222" and 610 or nil
			end,
			GetItemClassInfo = function(link)
				if link == "item:111" then
					return { classID = 0, subClassID = 1, equipLoc = "" }
				end
			end,
		}

		local items = Scanner.ScanBags(fakeApi, { 0, 1 })

		assert.are.equal(2, #items)

		assert.are.equal(111, items[1].itemID)
		assert.are.equal("Healing Potion", items[1].name)
		assert.are.equal(5, items[1].count)
		assert.are.equal(0, items[1].bag)
		assert.are.equal(1, items[1].slot)
		assert.are.equal(1001, items[1].icon)
		assert.is_nil(items[1].ilvl)
		assert.is_false(items[1].bound)
		assert.are.equal(0, items[1].itemClass)
		assert.are.equal(1, items[1].subClass)

		assert.is_nil(items[2].itemClass) -- fake API returned nothing for this link

		assert.are.equal(222, items[2].itemID)
		assert.are.equal(1002, items[2].icon)
		assert.are.equal(610, items[2].ilvl)
		assert.is_true(items[2].bound)
	end)

	it("skips empty slots", function()
		local fakeApi = {
			GetContainerNumSlots = function() return 2 end,
			GetContainerItemInfo = function() return nil end,
			GetItemLevel = function() return nil end,
		}
		local items = Scanner.ScanBags(fakeApi, { 0 })
		assert.are.equal(0, #items)
	end)

	it("scans zero bags into an empty list", function()
		local fakeApi = {
			GetContainerNumSlots = function() error("should not be called") end,
			GetContainerItemInfo = function() error("should not be called") end,
			GetItemLevel = function() error("should not be called") end,
		}
		assert.are.same({}, Scanner.ScanBags(fakeApi, {}))
	end)
end)
