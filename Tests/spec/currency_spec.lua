local Currency = require("Data.Currency")

describe("Data.Currency", function()
	describe("SeedFromBackpack", function()
		it("collects currencyTypesID from every backpack slot until one returns nil", function()
			local backpack = {
				[1] = { name = "Valorstones", currencyTypesID = 3008 },
				[2] = { name = "Flightstones", currencyTypesID = 2245 },
			}
			local fakeApi = {
				GetBackpackCurrencyInfo = function(index) return backpack[index] end,
			}

			assert.are.same({ 3008, 2245 }, Currency.SeedFromBackpack(fakeApi))
		end)

		it("returns an empty list when nothing is tracked", function()
			local fakeApi = {
				GetBackpackCurrencyInfo = function() return nil end,
			}
			assert.are.same({}, Currency.SeedFromBackpack(fakeApi))
		end)
	end)

	describe("ScanPinned", function()
		it("normalizes each pinned currency into the unified entry record", function()
			local fakeApi = {
				GetCurrencyInfo = function(currencyID)
					if currencyID == 3008 then
						return {
							name = "Valorstones",
							iconFileID = 5000,
							quantity = 1200,
							maxQuantity = 2000,
							quantityEarnedThisWeek = 300,
							maxWeeklyQuantity = 1000,
							quality = 3,
							isAccountTransferable = true,
						}
					end
				end,
			}

			local entries = Currency.ScanPinned(fakeApi, { 3008 })

			assert.are.equal(1, #entries)
			assert.are.equal("currency", entries[1].kind)
			assert.are.equal(3008, entries[1].currencyID)
			assert.are.equal("Valorstones", entries[1].name)
			assert.are.equal(1200, entries[1].quantity)
			assert.are.equal(2000, entries[1].maxQuantity)
			assert.are.equal(300, entries[1].earnedThisWeek)
			assert.are.equal(1000, entries[1].weeklyMax)
			assert.is_true(entries[1].isAccountTransferable)
			assert.is_true(entries[1].pinned)
		end)

		it("skips a pinned id that no longer resolves", function()
			local fakeApi = {
				GetCurrencyInfo = function() return nil end,
			}
			assert.are.same({}, Currency.ScanPinned(fakeApi, { 9999 }))
		end)
	end)

	describe("GetGoldEntry", function()
		it("wraps GetMoney/GetMoneyString as a money-kind entry", function()
			local fakeApi = {
				GetMoney = function() return 123456 end,
				GetMoneyString = function(money) return "12g 34s 56c (" .. money .. ")" end,
			}

			local entry = Currency.GetGoldEntry(fakeApi)

			assert.are.equal("money", entry.kind)
			assert.are.equal(123456, entry.quantity)
			assert.are.equal("12g 34s 56c (123456)", entry.display)
		end)
	end)
end)
