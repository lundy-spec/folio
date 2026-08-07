-- Normalizes raw container data into the unified entry record (§5).
-- Takes `api` as a parameter rather than reaching for Folio.API directly,
-- so tests can inject a fake (T2) without touching a real WoW client.

local Scanner = {}

function Scanner.ScanBags(api, bagIDs)
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
