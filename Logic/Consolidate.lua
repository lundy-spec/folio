-- Pure stack-merging (T1). Data/Scanner.lua lists one entry PER OCCUPIED
-- BAG SLOT -- if the same item happens to be split across several slots
-- (stack-size limits, picked up at different times, bag reorganization,
-- ...) that's several near-identical rows instead of one. This merges
-- same-item stacks within a single category+storage bucket down to one
-- display row with a summed count.

local Consolidate = {}

-- Same itemID AND craftingQuality only -- different crafting-quality
-- tiers of the same itemID are genuinely different variants (UI/Row.lua's
-- quality icon exists specifically to tell them apart) and must stay
-- separate rows, never merged together.
--
-- The first-encountered stack's other fields (bag/slot/itemLink/...) are
-- kept as the merged row's representative physical location -- an
-- inherent simplification, since WoW's bag API (pickup/use) only ever
-- operates on one specific bag+slot, and a merged row can represent more
-- than one. Order preserved: a merged entry lands at the position of its
-- first-encountered stack.
function Consolidate.MergeStacks(items)
	local order = {}
	local byKey = {}
	for _, item in ipairs(items) do
		local key = item.itemID .. ":" .. tostring(item.craftingQuality)
		local existing = byKey[key]
		if existing then
			existing.count = (existing.count or 1) + (item.count or 1)
		else
			local merged = {}
			for k, v in pairs(item) do
				merged[k] = v
			end
			merged.count = merged.count or 1
			byKey[key] = merged
			table.insert(order, merged)
		end
	end
	return order
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Consolidate = Consolidate
end

return Consolidate
