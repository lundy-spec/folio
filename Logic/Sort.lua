-- Pure manual item ordering (T1). A category's item list is naturally in
-- scan order (bag/slot); this reapplies a user's drag-to-reorder choices
-- on top of that, the same way Logic/Tree.lua's `order` field does for
-- categories -- but items aren't tree nodes, so there's no node to stash
-- an order field on, hence this standalone module instead.

local Sort = {}

-- items: array of item entries (each with an itemID -- duplicate stacks of
-- the same itemID are expected and handled, see below).
-- orderedIds: array of itemIDs recording the user's desired relative
-- order, or nil/empty for "no manual order yet" (natural order unchanged).
--
-- Items whose itemID appears in orderedIds are sorted by their position
-- there; anything else keeps its original relative order, appended after.
-- Duplicate stacks of the same itemID rank together (first occurrence
-- wins) and fall back to their original relative order to break the tie --
-- orderedIds tracks one position per item, not per physical stack, so
-- there's no way to rank two stacks of the same item differently.
function Sort.ApplyManualOrder(items, orderedIds)
	if not orderedIds or #orderedIds == 0 then
		return items
	end

	local rank = {}
	for i, id in ipairs(orderedIds) do
		if not rank[id] then
			rank[id] = i
		end
	end

	local indexed = {}
	for i, item in ipairs(items) do
		indexed[i] = { item = item, originalIndex = i, rank = rank[item.itemID] }
	end

	table.sort(indexed, function(a, b)
		if a.rank and b.rank then
			if a.rank ~= b.rank then return a.rank < b.rank end
		elseif a.rank or b.rank then
			return a.rank ~= nil
		end
		return a.originalIndex < b.originalIndex
	end)

	local result = {}
	for i, entry in ipairs(indexed) do
		result[i] = entry.item
	end
	return result
end

-- Moves itemID to sit immediately before/after targetItemID within
-- orderedIds (mutates and returns it). If orderedIds is nil, seedItems
-- (the category's current natural-order item list) is used to build a
-- fresh one first -- so a first-ever drop only changes the one item's
-- position instead of silently reordering everything else in the process.
function Sort.Reposition(orderedIds, seedItems, itemID, targetItemID, dropPosition)
	orderedIds = orderedIds or {}
	if #orderedIds == 0 and seedItems then
		for _, item in ipairs(seedItems) do
			table.insert(orderedIds, item.itemID)
		end
	end

	for i, id in ipairs(orderedIds) do
		if id == itemID then
			table.remove(orderedIds, i)
			break
		end
	end

	local insertIndex = #orderedIds + 1
	for i, id in ipairs(orderedIds) do
		if id == targetItemID then
			insertIndex = (dropPosition == "after") and (i + 1) or i
			break
		end
	end
	table.insert(orderedIds, insertIndex, itemID)

	return orderedIds
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Sort = Sort
end

return Sort
