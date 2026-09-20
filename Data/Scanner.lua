-- Normalizes raw container data into the unified entry record (§5).
-- Takes `api` as a parameter rather than reaching for Folio.API directly,
-- so tests can inject a fake (T2) without touching a real WoW client.

local _, Folio = ...

local Scanner = {}

-- `storage` (default "bags") tags each item for §4.3's sub-group
-- rendering -- same container API works identically for bags and bank
-- tabs, only the bagIDs passed in differ.
function Scanner.ScanBags(api, bagIDs, storage)
	storage = storage or "bags"
	local items = {}
	for _, bag in ipairs(bagIDs) do
		local numSlots = api.GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local info = api.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local classInfo = api.GetItemClassInfo(info.hyperlink)
				-- The client can return an empty string (not nil) for an
				-- item it hasn't fetched a name for yet -- most often right
				-- after login/reload, before the server has answered.
				-- Normalized to nil here so every consumer's
				-- `entry.name or fallback` actually catches it (Lua's `or`
				-- doesn't treat "" as falsy).
				local name = info.itemName ~= "" and info.itemName or nil
				table.insert(items, {
					kind = "item",
					itemID = info.itemID,
					itemLink = info.hyperlink,
					name = name,
					icon = info.iconFileID,
					count = info.stackCount,
					quality = info.quality,
					craftingQuality = api.GetCraftingQuality(info.hyperlink),
					craftingQualityIcon = api.GetCraftingQualityIcon(info.hyperlink),
					expansionID = api.GetItemExpansion(info.hyperlink),
					ilvl = api.GetItemLevel(info.hyperlink),
					itemClass = classInfo and classInfo.classID,
					subClass = classInfo and classInfo.subClassID,
					equipSlot = classInfo and classInfo.equipLoc,
					bag = bag,
					slot = slot,
					bound = info.isBound,
					storage = storage,
					categoryID = nil,
				})
			end
		end
	end
	return items
end

-- Used/total slot counts across the given bagIDs -- a separate, lighter
-- pass than ScanBags itself (which normalizes every OCCUPIED slot into a
-- full entry record); this only needs a count, occupied or not, so it
-- doesn't build up classInfo/craftingQuality/etc. for anything.
function Scanner.GetBagSpace(api, bagIDs)
	local used, total = 0, 0
	for _, bag in ipairs(bagIDs) do
		local numSlots = api.GetContainerNumSlots(bag)
		total = total + numSlots
		for slot = 1, numSlots do
			if api.GetContainerItemInfo(bag, slot) then
				used = used + 1
			end
		end
	end
	return used, total
end

if type(Folio) == "table" then
	Folio.Data = Folio.Data or {}
	Folio.Data.Scanner = Scanner
end

return Scanner
