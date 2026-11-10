-- Pure item ordering (T1). A category's item list is naturally in scan
-- order (bag/slot); TrackArrivals/ByArrival (below) reorder it by when
-- each item arrived, and ApplyManualOrder reapplies a user's drag-to-reorder choices
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

-- Arrival order: newly acquired items list at the BOTTOM of their
-- category instead of wherever their bag slot happens to fall, while
-- anything already in the bag keeps its place. `state` is one storage's
-- persisted record, { next = <counter>, seq = { [itemID] = n } }; items
-- is that storage's full current scan.
--
-- Assigns the next sequence number to every itemID not seen before (in
-- scan order, so a first-ever run reproduces today's slot order exactly),
-- and -- only when allowRemoval is set -- forgets itemIDs no longer
-- present, so an item that fully leaves and later comes back counts as
-- new again. Callers hold allowRemoval off while a scan might be
-- incomplete (just after login, or just after the bank opens) so a
-- partial scan can't wipe the history. Returns the forgotten itemIDs.
function Sort.TrackArrivals(state, items, allowRemoval)
	state.next = state.next or 1
	state.seq = state.seq or {}

	local removed = {}
	if allowRemoval then
		local present = {}
		for _, item in ipairs(items) do
			present[item.itemID] = true
		end
		for id in pairs(state.seq) do
			if not present[id] then
				state.seq[id] = nil
				table.insert(removed, id)
			end
		end
	end

	for _, item in ipairs(items) do
		if not state.seq[item.itemID] then
			state.seq[item.itemID] = state.next
			state.next = state.next + 1
		end
	end

	return removed
end

-- Stable sort by arrival sequence (seq: itemID -> n). Items with no
-- sequence yet sort after every sequenced one, in their original order.
function Sort.ByArrival(items, seq)
	if not seq then
		return items
	end
	local indexed = {}
	for i, item in ipairs(items) do
		indexed[i] = { item = item, originalIndex = i, seq = seq[item.itemID] }
	end
	table.sort(indexed, function(a, b)
		if a.seq and b.seq then
			if a.seq ~= b.seq then return a.seq < b.seq end
		elseif a.seq or b.seq then
			return a.seq ~= nil
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
