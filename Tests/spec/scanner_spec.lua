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
			GetCraftingQuality = function(link)
				return link == "item:111" and 2 or nil
			end,
			GetCraftingQualityIcon = function(link)
				return link == "item:111" and "Professions-Icon-Quality-Tier2-Small" or nil
			end,
			GetItemExpansion = function(link)
				return link == "item:111" and 11 or nil
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
		assert.are.equal(2, items[1].craftingQuality)
		assert.are.equal("Professions-Icon-Quality-Tier2-Small", items[1].craftingQualityIcon)
		assert.are.equal(11, items[1].expansionID)
		assert.is_nil(items[2].craftingQuality)
		assert.is_nil(items[2].craftingQualityIcon)
		assert.is_nil(items[2].expansionID)
		assert.is_nil(items[1].ilvl)
		assert.is_false(items[1].bound)
		assert.are.equal(0, items[1].itemClass)
		assert.are.equal(1, items[1].subClass)

		assert.is_nil(items[2].itemClass) -- fake API returned nothing for this link

		assert.are.equal(222, items[2].itemID)
		assert.are.equal(1002, items[2].icon)
		assert.are.equal(610, items[2].ilvl)
		assert.is_true(items[2].bound)

		assert.are.equal("bags", items[1].storage) -- default when unspecified
	end)

	it("tags every item with the given storage instead of the default", function()
		local fakeApi = {
			GetContainerNumSlots = function() return 1 end,
			GetContainerItemInfo = function()
				return { itemID = 1, hyperlink = "item:1", itemName = "Thing", stackCount = 1, quality = 1 }
			end,
			GetItemLevel = function() return nil end,
			GetItemClassInfo = function() return nil end,
			GetCraftingQuality = function() return nil end,
			GetCraftingQualityIcon = function() return nil end,
			GetItemExpansion = function() return nil end,
		}
		local items = Scanner.ScanBags(fakeApi, { 6 }, "bank")
		assert.are.equal("bank", items[1].storage)
	end)

	it("normalizes an uncached item's empty-string name to nil", function()
		-- The client can return "" (not nil) for itemName on an item it
		-- hasn't fetched data for yet, most often right after login --
		-- `entry.name or fallback` downstream doesn't catch "" (it's
		-- truthy in Lua), so this has to be normalized at the source.
		local fakeApi = {
			GetContainerNumSlots = function() return 1 end,
			GetContainerItemInfo = function()
				return { itemID = 1, hyperlink = "item:1", itemName = "", stackCount = 1, quality = 1 }
			end,
			GetItemLevel = function() return nil end,
			GetItemClassInfo = function() return nil end,
			GetCraftingQuality = function() return nil end,
			GetCraftingQualityIcon = function() return nil end,
			GetItemExpansion = function() return nil end,
		}
		local items = Scanner.ScanBags(fakeApi, { 0 })
		assert.is_nil(items[1].name)
	end)

	it("appends the owned keystone's dungeon+level to the Mythic Keystone's name (Q42)", function()
		local fakeApi = {
			GetContainerNumSlots = function() return 1 end,
			GetContainerItemInfo = function()
				return { itemID = 180653, hyperlink = "item:180653", itemName = "Mythic Keystone", stackCount = 1, quality = 1 }
			end,
			GetItemLevel = function() return nil end,
			GetItemClassInfo = function() return nil end,
			GetCraftingQuality = function() return nil end,
			GetCraftingQualityIcon = function() return nil end,
			GetItemExpansion = function() return nil end,
			GetOwnedKeystoneInfo = function() return "Pit of Saron", 10 end,
		}
		local items = Scanner.ScanBags(fakeApi, { 0 })
		assert.are.equal("Mythic Keystone (PoS +10)", items[1].name)
	end)

	it("does not call GetOwnedKeystoneInfo for any other item", function()
		local fakeApi = {
			GetContainerNumSlots = function() return 1 end,
			GetContainerItemInfo = function()
				return { itemID = 111, hyperlink = "item:111", itemName = "Healing Potion", stackCount = 1, quality = 1 }
			end,
			GetItemLevel = function() return nil end,
			GetItemClassInfo = function() return nil end,
			GetCraftingQuality = function() return nil end,
			GetCraftingQualityIcon = function() return nil end,
			GetItemExpansion = function() return nil end,
			GetOwnedKeystoneInfo = function() error("should not be called") end,
		}
		local items = Scanner.ScanBags(fakeApi, { 0 })
		assert.are.equal("Healing Potion", items[1].name)
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
