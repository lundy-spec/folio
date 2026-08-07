-- §4.1: gold and pinned currencies as unified entry records (§5). Takes
-- `api` as a parameter rather than reaching for Folio.API directly, so
-- tests can inject a fake (T2).

local Currency = {}

-- CUR8: seed the pinned set from the user's existing Blizzard
-- backpack-tracked currencies on first run. GetBackpackCurrencyInfo's
-- struct field is `currencyTypesID`, not `currencyID` -- verified
-- against Blizzard's generated API docs rather than guessed.
function Currency.SeedFromBackpack(api)
	local ids = {}
	local index = 1
	while true do
		local info = api.GetBackpackCurrencyInfo(index)
		if not info then break end
		table.insert(ids, info.currencyTypesID)
		index = index + 1
	end
	return ids
end

-- CUR1/CUR4: normalizes each pinned currency into the unified entry
-- record. Silently skips an id that no longer resolves (e.g. removed
-- in a patch) rather than inserting a broken entry.
function Currency.ScanPinned(api, pinnedIDs)
	local entries = {}
	for _, currencyID in ipairs(pinnedIDs) do
		local info = api.GetCurrencyInfo(currencyID)
		if info then
			table.insert(entries, {
				kind = "currency",
				currencyID = currencyID,
				name = info.name,
				icon = info.iconFileID,
				quantity = info.quantity,
				maxQuantity = info.maxQuantity,
				earnedThisWeek = info.quantityEarnedThisWeek,
				weeklyMax = info.maxWeeklyQuantity,
				quality = info.quality,
				isAccountTransferable = info.isAccountTransferable,
				pinned = true,
				categoryID = nil,
			})
		end
	end
	return entries
end

-- CUR2: gold as a currency-shaped entry, using Blizzard's own coin
-- formatting rather than a bespoke string.
function Currency.GetGoldEntry(api)
	local money = api.GetMoney()
	return {
		kind = "money",
		name = "Gold",
		quantity = money,
		display = api.GetMoneyString(money),
		categoryID = nil,
	}
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Data = Folio.Data or {}
	Folio.Data.Currency = Currency
end

return Currency
