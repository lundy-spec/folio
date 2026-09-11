-- Normalizes raw container data into the unified entry record (§5).
-- Takes `api` as a parameter rather than reaching for Folio.API directly,
-- so tests can inject a fake (T2) without touching a real WoW client.

local Keystone
local _, Folio = ...
if type(Folio) == "table" then
	Keystone = Folio.Keystone
else
	Keystone = require("Logic.Keystone")
end

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
				-- Q42: the Mythic Keystone (item 180653, Folio's only
				-- itemID-specific special case) gets its current
				-- dungeon+level appended -- "Mythic Keystone (PoS +10)"
				-- instead of the bare name every key shares.
				if info.itemID == Keystone.ITEM_ID then
					local dungeonName, level = api.GetOwnedKeystoneInfo()
					name = Keystone.AppendSuffix(name, dungeonName, level)
				end
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

if type(Folio) == "table" then
	Folio.Data = Folio.Data or {}
	Folio.Data.Scanner = Scanner
end

return Scanner
