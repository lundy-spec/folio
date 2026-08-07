-- Normalizes raw container data into the unified entry record (§5).
-- Takes `api` as a parameter rather than reaching for Folio.API directly,
-- so tests can inject a fake (T2) without touching a real WoW client.

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
				table.insert(items, {
					kind = "item",
					itemID = info.itemID,
					itemLink = info.hyperlink,
					name = info.itemName,
					icon = info.iconFileID,
					count = info.stackCount,
					quality = info.quality,
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

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Data = Folio.Data or {}
	Folio.Data.Scanner = Scanner
end

return Scanner
