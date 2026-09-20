local ADDON_NAME, Folio = ...

-- Cross-file-callable actions -- UI/Options.lua's panel and UI/Frame.lua's
-- corner menu both call into these instead of duplicating logic.
Folio.Actions = {}

local UNCATEGORIZED = "uncategorized"

-- The built-in "Junk" starter category's stable id (Logic/Seed.lua) --
-- used to find sellable items regardless of what the player has renamed
-- that category to. A custom category the player creates and calls
-- "Junk"/"Trash" themselves gets its own id and isn't included.
local JUNK_CATEGORY_ID = "junk"

-- §4.3 S1: bank data (and the drawer that shows it, Q43) only exists
-- while a banker is actually open.
local isBankOpen = false

-- Debounce flag for GET_ITEM_INFO_RECEIVED (see the event handler below).
local itemInfoRefreshPending = false

-- True while the "Show Bags" button (UI/Frame.lua) has temporarily
-- cleared the bag-replacement keybind override so its secure-forwarded
-- click reaches Blizzard's own bags -- see ArmBlizzardBagsPeek below.
local peekingBlizzardBags = false

-- Q39: live search (UI/Frame.lua's search box). Trimmed, never nil --
-- "" means no search is active. Persists across RefreshItems() calls
-- (bag updates, etc.) so results stay live-filtered while typing.
local searchText = ""

-- Q52: true once the player has explicitly closed the main Folio window
-- (UI/Frame.lua's OnClosed hook) while still at a banker -- suppresses
-- RefreshBankDrawer's normal auto-show-while-isBankOpen behavior until
-- the player leaves and re-opens a banker (BANKFRAME_OPENED resets it),
-- otherwise the very next bag/bank update would just pop the drawer back
-- open on its own, right after the player closed everything.
local bankDrawerDismissed = false

local function ScanAllStorages()
	local items = Folio.Data.Scanner.ScanBags(Folio.API, Folio.API.GetBagIDs(), "bags")
	if isBankOpen then
		local bankItems = Folio.Data.Scanner.ScanBags(Folio.API, Folio.API.GetCharacterBankTabIDs(), "bank")
		for _, item in ipairs(bankItems) do
			table.insert(items, item)
		end
	end
	return items
end

-- groups[categoryID][storage] -> array of items, matching what
-- Logic/Render.lua expects. Also stamps categoryID onto each item itself
-- (Scanner never sets it) so a dragged item row knows which category it
-- currently belongs to -- see Row.OnItemDragStop below.
local function GroupByCategory(tree, items)
	local groups = {}
	local resolved = Folio.Data.Assign.ResolveAll(tree, items, Folio.Config.db.itemOverrides)
	for i, item in ipairs(items) do
		local categoryID = resolved[i] or UNCATEGORIZED
		item.categoryID = categoryID
		groups[categoryID] = groups[categoryID] or {}
		local storage = item.storage or "bags"
		groups[categoryID][storage] = groups[categoryID][storage] or {}
		table.insert(groups[categoryID][storage], item)
	end

	-- Merge same-item (same itemID + craftingQuality) stacks scattered
	-- across different bag slots into one display row with a summed
	-- count (confirmed live: e.g. 4 physical stacks of the same reagent,
	-- split across non-contiguous slots, showed as 4 identical-looking
	-- rows instead of one).
	for _, byStorage in pairs(groups) do
		for storage, list in pairs(byStorage) do
			byStorage[storage] = Folio.Consolidate.MergeStacks(list)
		end
	end

	-- Layer the user's drag-to-reorder choices (if any) on top of the
	-- natural scan order, per category+storage bucket.
	local itemOrder = Folio.Config.db.itemOrder
	for categoryID, byStorage in pairs(groups) do
		local order = itemOrder[categoryID]
		if order then
			for storage, list in pairs(byStorage) do
				byStorage[storage] = Folio.Sort.ApplyManualOrder(list, order[storage])
			end
		end
	end

	return groups
end

-- Last groups computed by RefreshItems -- Row.OnItemDragStop reads this to
-- seed a fresh manual order (Logic/Sort.lua's Reposition) from whatever's
-- currently displayed, rather than re-deriving it from scratch.
local lastGroups = {}

-- Q43: which storage a drop on a header row transfers an item to
-- (Row.lua's ResolveHeaderDropTarget/UI/Row.lua reads this back as
-- row.dropStorage) -- stamped per-window here rather than by
-- Logic/Render.lua, since BuildRows itself doesn't know which window
-- (main bags, or the bank drawer) it's being called for.
local function TagDropStorage(rows, storage)
	for _, row in ipairs(rows) do
		if row.kind == "header" then
			row.dropStorage = storage
		end
	end
	return rows
end

-- Q43: the bank drawer -- uses the SAME category tree as the main window,
-- showing only bank storage's items (Logic/Render.lua's storage-scoped
-- BuildRows).
local function RefreshBankDrawer(tree, groups)
	if not isBankOpen or bankDrawerDismissed then
		Folio.UI.BankFrame.Hide()
		return
	end

	local db = Folio.Config.db
	local bankRows = TagDropStorage(
		Folio.Render.BuildRows(tree, groups, "bank", db.pinnedItemIDs, db.collapsedByStorage.bank), "bank")

	Folio.UI.BankFrame.SetItems(bankRows)
	Folio.UI.BankFrame.Show()
end

-- Full rescan on every bag/bank change — no diffing yet (architecture
-- principle 3 wants incremental diffs eventually; this spike proves the
-- virtualized list works with real data first).
-- Split out from RefreshItems so toggling the percent-display option
-- (UI/Options.lua) can update the readout immediately without a full
-- bag rescan -- the underlying used/total counts haven't changed, only
-- how they're formatted.
local function RefreshBagSpace()
	local usedSlots, totalSlots = Folio.Data.Scanner.GetBagSpace(Folio.API, Folio.API.GetBagIDs())
	Folio.UI.Frame.SetBagSpace(usedSlots, totalSlots)
end

local function RefreshItems()
	local items = ScanAllStorages()
	Folio.Data.Cache.SetItems(items)

	local tree = Folio.Config.db.categories
	local groups = GroupByCategory(tree, items)
	lastGroups = groups

	local rows
	if searchText ~= "" then
		rows = Folio.Render.BuildSearchRows(tree, groups, "bags", searchText)
	else
		local db = Folio.Config.db
		rows = TagDropStorage(
			Folio.Render.BuildRows(tree, groups, "bags", db.pinnedItemIDs, db.collapsedByStorage.bags), "bags")
	end
	Folio.UI.Frame.SetItems(rows)

	RefreshBagSpace()

	RefreshBankDrawer(tree, groups)
end

-- Auto-sell-junk-at-vendor: fires on MERCHANT_SHOW. Reads
-- Folio.Data.Cache's raw, one-entry-PER-BAG-SLOT item list (RefreshItems()
-- above, just called, keeps it current) rather than the category-grouped
-- `lastGroups` -- that grouping runs same-item stacks through
-- Logic/Consolidate.lua's MergeStacks, which collapses several physical
-- slots into one display row carrying only ONE of their bag/slot pairs
-- (see that file's own comment). Selling off that merged view would sell
-- only one physical stack while reporting profit for all of them. Only
-- "bags" storage -- a bank item isn't in a reachable slot to sell from
-- here even if some were still cached from an earlier bank visit.
local function SellJunkItems()
	RefreshItems()
	local items = Folio.Data.Cache.GetItems()

	local sellable = {}
	for _, item in ipairs(items) do
		if item.categoryID == JUNK_CATEGORY_ID and item.storage == "bags" then
			local sellPrice = Folio.API.GetItemSellPrice(item.itemLink)
			if sellPrice and sellPrice > 0 then
				table.insert(sellable, { bag = item.bag, slot = item.slot, sellPrice = sellPrice, count = item.count })
			end
		end
	end
	if #sellable == 0 then return end

	local profit = Folio.Vendor.CalculateProfit(sellable)
	for _, item in ipairs(sellable) do
		Folio.API.SellContainerItem(item.bag, item.slot)
	end

	print(("|cff33ff99Folio|r sold %d junk item%s for %s."):format(
		#sellable, #sellable == 1 and "" or "s", Folio.API.GetMoneyString(profit)))
end

local function Trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Q39: fired on every keystroke from the search box's OnTextChanged
-- (UI/Frame.lua) -- RefreshItems() re-derives rows from the current
-- searchText every time it runs, so this just updates the text and
-- re-runs it, same as any other bag-state change.
local function SetSearchText(text)
	searchText = Trim(text or "")
	RefreshItems()
end
Folio.Actions.SetSearchText = SetSearchText

-- Q40/Q41: pin toggle (UI/Row.lua's shift-left-click on an item row).
-- Ordered array, not a set -- Logic/Render.lua displays pinned items in
-- pin order, and the list is expected to stay small (a handful), so a
-- linear scan per toggle is simpler than maintaining a parallel set just
-- to speed it up.
local function ToggleItemPin(itemID)
	local pinned = Folio.Config.db.pinnedItemIDs
	for i, id in ipairs(pinned) do
		if id == itemID then
			table.remove(pinned, i)
			RefreshItems()
			return
		end
	end
	table.insert(pinned, itemID)
	RefreshItems()
end
Folio.Actions.ToggleItemPin = ToggleItemPin

Folio.UI.Row.OnItemPinToggle = ToggleItemPin

-- New categories always land at the root -- dragging a category onto
-- another to *nest* it isn't supported yet either (see the reorder
-- comment below), so there's nowhere else a fresh one could go.
StaticPopupDialogs["FOLIO_NEW_CATEGORY"] = {
	text = "New category name:",
	button1 = "Create",
	button2 = "Cancel",
	hasEditBox = true,
	maxLetters = 50,
	OnAccept = function(self)
		-- TEMP DEBUG (Q23): second-attempt "Create did nothing" report.
		local raw = self.EditBox:GetText()
		print("|cff33ff99Folio debug|r new-category OnAccept raw=", "'" .. tostring(raw) .. "'")
		local name = Trim(raw)
		if name == "" then
			print("|cff33ff99Folio debug|r new-category name empty after trim, aborting")
			return
		end
		local db = Folio.Config.db
		local id = "custom" .. db.nextCategoryID
		db.nextCategoryID = db.nextCategoryID + 1
		local node, err = Folio.Tree.AddNode(db.categories, id, { name = name })
		print("|cff33ff99Folio debug|r AddNode id=", id, "node=", node, "err=", err)
		RefreshItems()
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		if parent.OnAccept then parent.OnAccept(parent) end
		parent:Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
	OnShow = function(self)
		self.EditBox:SetFocus()
	end,
	OnHide = function(self)
		self.EditBox:SetText("")
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Exposed so the corner menu's "New Category" entry (UI/Frame.lua) can
-- trigger this dialog.
Folio.Actions.ShowNewCategoryDialog = function()
	StaticPopup_Show("FOLIO_NEW_CATEGORY")
end

-- Q53: fires from either window, but only toggles collapse state for the
-- SPECIFIC window/section (dropStorage) the click came from -- see
-- Logic/Render.lua's IsCollapsed for how an untouched category still
-- falls back to its own default in every window.
Folio.UI.Row.OnHeaderClick = function(categoryID, dropStorage)
	local node = Folio.Tree.GetNode(Folio.Config.db.categories, categoryID)
	if not node then return end
	local storage = dropStorage or "bags"
	local db = Folio.Config.db
	db.collapsedByStorage[storage] = db.collapsedByStorage[storage] or {}
	local collapsed = db.collapsedByStorage[storage]
	-- First toggle for this category in this window starts from the
	-- node's own default (not blindly `true`), same fallback Render.lua
	-- itself uses, so the very first click reliably flips the visible
	-- state instead of sometimes doing nothing (if the default was
	-- already collapsed) or double-collapsing.
	if collapsed[categoryID] == nil then
		collapsed[categoryID] = not node.collapsed
	else
		collapsed[categoryID] = not collapsed[categoryID]
	end
	RefreshItems()
end

-- Q52: main window's own close button (or /folio, or Escape) closes the
-- bank drawer right along with it -- the drawer no longer has its own
-- close button (UI/BankFrame.lua), it's a companion to this window.
Folio.UI.Frame.OnClosed = function()
	bankDrawerDismissed = true
	Folio.UI.BankFrame.Hide()
end

-- Deleting a category by dragging it out past the window's edges (Q19).
-- Cascading (children go with it, Logic/Tree.lua's RemoveNode), and any
-- itemOverrides pointing at the removed ids are pruned too -- an override
-- left pointing at a dead id would still "work" (Render.lua lists it as
-- a leftover) but there's no reason to keep the dead reference around.
StaticPopupDialogs["FOLIO_DELETE_CATEGORY"] = {
	text = "Delete category \"%s\"?\nAny sub-categories inside it are deleted too. Items inside won't be deleted -- they'll show up unsorted. This cannot be undone.",
	button1 = "Delete",
	button2 = "Cancel",
	OnAccept = function(_, categoryID)
		local db = Folio.Config.db
		local removedIDs = Folio.Tree.RemoveNode(db.categories, categoryID)
		if not removedIDs then return end
		local removedSet = {}
		for _, id in ipairs(removedIDs) do
			removedSet[id] = true
		end
		for itemID, overrideCategoryID in pairs(db.itemOverrides) do
			if removedSet[overrideCategoryID] then
				db.itemOverrides[itemID] = nil
			end
		end
		for _, id in ipairs(removedIDs) do
			db.itemOrder[id] = nil
		end
		for _, byCategory in pairs(db.collapsedByStorage) do
			for _, id in ipairs(removedIDs) do
				byCategory[id] = nil
			end
		end
		RefreshItems()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Drag one category header onto another: top/bottom third of the target
-- reorders as a sibling (same-parent only for now, cross-parent
-- reordering isn't supported), middle third nests it as the target's
-- child (Q24, any parent -- that's how a category's parent changes).
-- dropPosition ("before"/"after"/"into") comes from Row.lua's
-- cursor-third tracking that drives the insertion-line/highlight
-- indicator. A drop with no target at all, past the window's own edges
-- (droppedOutside, from Row.lua's cursor-vs-frame-bounds check), asks to
-- delete it instead.
local reorderInProgress = false

Folio.UI.Row.OnHeaderDragStop = function(headerRow, target, dropPosition, droppedOutside)
	if reorderInProgress then return end
	if not target then
		if droppedOutside then
			local node = Folio.Tree.GetNode(Folio.Config.db.categories, headerRow.categoryID)
			if node then
				StaticPopup_Show("FOLIO_DELETE_CATEGORY", node.name, nil, headerRow.categoryID)
			end
		end
		return
	end
	if target.entryKind ~= "header" then return end
	if target.categoryID == headerRow.categoryID then return end

	local tree = Folio.Config.db.categories
	local draggedNode = Folio.Tree.GetNode(tree, headerRow.categoryID)
	local targetNode = Folio.Tree.GetNode(tree, target.categoryID)
	if not draggedNode or not targetNode then return end

	-- Middle third of the target row (Row.lua's DropPositionRelativeTo)
	-- nests the dragged category as the target's child instead of
	-- reordering it as a sibling -- unlike before/after, this is exactly
	-- how a category changes parent, so it's allowed across different
	-- parents (that's the point) and doesn't need the same-parent guard
	-- below. MoveNode itself rejects dropping a category into its own
	-- descendant (would create a cycle).
	if dropPosition == "into" then
		reorderInProgress = true
		local ok, err = Folio.Tree.MoveNode(tree, headerRow.categoryID, target.categoryID)
		if not ok then
			print(("|cff33ff99Folio|r can't move %s into %s (%s)."):format(draggedNode.name, targetNode.name, err))
		else
			RefreshItems()
		end
		reorderInProgress = false
		return
	end

	if draggedNode.parent ~= targetNode.parent then
		print("|cff33ff99Folio|r can't reorder across different parent categories yet.")
		return
	end

	local siblings = Folio.Tree.GetChildren(tree, draggedNode.parent)
	local orderedIds = {}
	for _, node in ipairs(siblings) do
		if node.id ~= headerRow.categoryID then
			table.insert(orderedIds, node.id)
		end
	end

	local insertIndex = #orderedIds + 1
	for i, id in ipairs(orderedIds) do
		if id == target.categoryID then
			insertIndex = (dropPosition == "after") and (i + 1) or i
			break
		end
	end
	table.insert(orderedIds, insertIndex, headerRow.categoryID)

	reorderInProgress = true
	Folio.Tree.ReorderChildren(tree, draggedNode.parent, orderedIds)
	RefreshItems()
	reorderInProgress = false
end

-- §4.3 (Q17's drop-target-decides model, Q43's two-window update): drop
-- on a category header in the SAME window recategorizes only (R2: sticky
-- manual override, no item movement); drop on a category header in the
-- OTHER window (main <-> bank drawer) both recategorizes AND deposits/
-- withdraws (S5), via that header's dropStorage. Stack modifiers and
-- bulk queue/throttle are deliberate follow-ups.

local function StorageBagIDs(storage)
	if storage == "bank" then return Folio.API.GetCharacterBankTabIDs() end
	return Folio.API.GetBagIDs()
end

local function BankTypeForStorage(storage)
	if storage == "bank" then return Enum.BankType.Character end
	return nil
end

Folio.UI.Row.OnItemDragStart = function(itemRow)
	Folio.API.PickupContainerItem(itemRow.itemBag, itemRow.itemSlot)
end

-- A header's own row is only ~18px tall in a dense list, so landing a
-- drop precisely on it is unrealistic -- confirmed live: GetMouseFoci()
-- was working fine, drops were just landing on an adjacent item row one
-- pixel off. Treat a drop on ANY row belonging to a category (its header
-- or one of its items) as targeting that category, same fix as the
-- deleted UI/DragPrototype.lua's full-block hit boxes during Q17
-- testing. `dropStorage` (Q43) is whichever window the target header was
-- rendered in -- main window headers all resolve to "bags", the bank
-- drawer's to "bank" -- so dropping a bag item on ANY category header in
-- the bank drawer both recategorizes AND deposits it, and vice versa for
-- withdrawing.
local function ResolveDropTarget(target)
	if not target then return nil end
	if target.entryKind == "header" and target.categoryID then
		return target.categoryID, target.dropStorage
	end
	if target.entryKind == "item" and target.itemCategoryID then
		return target.itemCategoryID, target.itemStorage
	end
	return nil
end

-- Physically moves the item, returning it to its original slot if the
-- move isn't possible. Returns true only if the move actually happened.
local function TryTransfer(itemRow, toStorage)
	local bankType = BankTypeForStorage(toStorage)
	local eligible = true
	if bankType then
		eligible = Folio.API.IsItemAllowedInBankType(itemRow.itemBag, itemRow.itemSlot, bankType)
	end

	local destBag, destSlot = Folio.API.FindEmptySlot(StorageBagIDs(toStorage))

	local ok, reason = Folio.Transfer.Validate({
		fromStorage = itemRow.itemStorage,
		toStorage = toStorage,
		eligible = eligible,
		destinationBag = destBag,
	})

	if not ok then
		print("|cff33ff99Folio|r couldn't move it to " .. toStorage .. " (" .. reason .. ").")
		Folio.API.PickupContainerItem(itemRow.itemBag, itemRow.itemSlot) -- place back
		return false
	end

	Folio.API.PickupContainerItem(destBag, destSlot)
	return true
end

Folio.UI.Row.OnItemDragStop = function(itemRow, target, dropPosition)
	-- RefreshItems() below rebuilds the ScrollBox and recycles pooled row
	-- frames, which can trigger a spurious second OnDragStop on this same
	-- physical frame (confirmed live). On that phantom call the cursor is
	-- already empty, and PickupContainerItem on an empty cursor PICKS UP
	-- rather than places -- re-grabbing the item we just placed back. Only
	-- proceed if the cursor is actually still holding the item this drag
	-- started with.
	local cursorType, cursorItemID = GetCursorInfo()
	if cursorType ~= "item" or cursorItemID ~= itemRow.itemID then
		return
	end

	local categoryID, toStorage = ResolveDropTarget(target)

	-- Not dropped on any part of one of our own categories -- leave the
	-- item on the cursor exactly as native WoW does on an invalid drop;
	-- the player can still click any real bag/bank slot to place it, or
	-- click the same slot again to cancel.
	if not categoryID then
		return
	end

	if categoryID ~= itemRow.itemCategoryID then
		Folio.Config.db.itemOverrides[itemRow.itemID] = categoryID
		local node = Folio.Tree.GetNode(Folio.Config.db.categories, categoryID)
		print(("|cff33ff99Folio|r moved %s to %s."):format(itemRow.itemLink or "item", node and node.name or categoryID))
	end

	-- Dropped directly on another item row, not just its category/header --
	-- record where in that bucket's list this one lands too (Row.lua's
	-- ItemDropPositionRelativeTo), seeded from whatever's currently
	-- displayed there (lastGroups) on the first-ever reorder so this only
	-- changes the one item's position.
	if target and target.entryKind == "item" and dropPosition then
		local db = Folio.Config.db
		db.itemOrder[categoryID] = db.itemOrder[categoryID] or {}
		local seedItems = lastGroups[categoryID] and lastGroups[categoryID][toStorage]
		db.itemOrder[categoryID][toStorage] = Folio.Sort.Reposition(
			db.itemOrder[categoryID][toStorage], seedItems, itemRow.itemID, target.itemID, dropPosition
		)
	end

	if toStorage and toStorage ~= itemRow.itemStorage then
		TryTransfer(itemRow, toStorage)
	else
		-- No physical storage change requested (or dropped back into its
		-- own storage) -- place the item back where it was, whether or
		-- not its category changed.
		Folio.API.PickupContainerItem(itemRow.itemBag, itemRow.itemSlot)
	end

	RefreshItems()
end

-- Currencies are paused (Data/Currency.lua's pin/seed machinery stays,
-- tested, for whenever that resumes) -- gold only for now.
local function RefreshCurrencies()
	Folio.UI.CurrencyBar.SetGold(Folio.Data.Currency.GetGoldEntry(Folio.API))
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:RegisterEvent("BAG_UPDATE_DELAYED")
-- Fires once the server answers a name/data request for an item the
-- client hadn't cached yet (most common right after login/reload) --
-- without this, an item scanned before its name arrived stays a bare
-- icon (or "Item 12345" placeholder) until something else happens to
-- trigger a rescan.
bootstrap:RegisterEvent("GET_ITEM_INFO_RECEIVED")
bootstrap:RegisterEvent("PLAYER_MONEY")
bootstrap:RegisterEvent("BANKFRAME_OPENED")
bootstrap:RegisterEvent("BANKFRAME_CLOSED")
bootstrap:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
bootstrap:RegisterEvent("MERCHANT_SHOW")
-- Only meaningful while peekingBlizzardBags (see ArmBlizzardBagsPeek below) --
-- the signal that the player's done looking at Blizzard's real bags and
-- it's safe to restore Folio's keybind override.
bootstrap:RegisterEvent("BAG_CLOSED")
bootstrap:SetScript("OnEvent", function(self, event, loadedAddon)
	if event == "ADDON_LOADED" then
		if loadedAddon ~= ADDON_NAME then return end
		self:UnregisterEvent("ADDON_LOADED")
		Folio.Config.Init()
	elseif event == "PLAYER_LOGIN" then
		-- Pre-create the frame at login, not reactively later, to sidestep
		-- 12.0's in-combat/in-instance frame-creation restrictions (§3).
		Folio.UI.Frame.Create()
		Folio.UI.BankFrame.Create()
		Folio.UI.Options.Create()
		RefreshItems()
		RefreshCurrencies()
		if Folio.Config.db.bagReplacementEnabled then
			Folio.BagReplacement.Enable()
		end
		print("|cff33ff99Folio|r loaded — type /folio to toggle the window")
	elseif event == "BAG_UPDATE_DELAYED" then
		RefreshItems()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		-- Fires once per item, client-wide -- can arrive in a rapid burst
		-- right after login as many items resolve at once. Debounced
		-- rather than refreshing on every single one, which would mean
		-- a full rescan+regroup+render dozens of times in a row.
		if not itemInfoRefreshPending then
			itemInfoRefreshPending = true
			C_Timer.After(0.5, function()
				itemInfoRefreshPending = false
				RefreshItems()
			end)
		end
	elseif event == "PLAYER_MONEY" then
		RefreshCurrencies()
	elseif event == "BANKFRAME_OPENED" then
		isBankOpen = true
		-- A fresh banker interaction -- clears any earlier explicit close
		-- (Q52) so the drawer isn't stuck suppressed forever.
		bankDrawerDismissed = false
		RefreshItems()
	elseif event == "BANKFRAME_CLOSED" then
		isBankOpen = false
		RefreshItems()
	elseif event == "PLAYERBANKSLOTS_CHANGED" then
		-- Confirmed live: purchasing a bank bag slot (not merely opening
		-- the bank -- confirmed live separately) prints "Folio has been
		-- blocked from an action only available to the Blizzard UI".
		-- This event plausibly fires synchronously as a direct result of
		-- that still-in-progress protected BuyBankSlot() call, so running
		-- RefreshItems() (a full rescan + UI rebuild) directly in this
		-- handler risks doing it nested inside that call's own stack,
		-- tainting it. Deferred a tick so Folio's code always runs after
		-- any protected call already in progress has fully unwound.
		if isBankOpen then
			C_Timer.After(0, RefreshItems)
		end
	elseif event == "MERCHANT_SHOW" then
		SellJunkItems()
	elseif event == "BAG_CLOSED" then
		if peekingBlizzardBags then
			peekingBlizzardBags = false
			Folio.BagReplacement.Enable()
			print("|cff33ff99Folio|r bag replacement restored — B opens Folio again.")
		end
	end
end)

-- T4: serializes the current scan to SavedVariables so it can be captured
-- as a real test fixture (Tests/fixtures/) rather than a synthetic one.
local function DumpFixture()
	local items = Folio.Data.Cache.GetItems()
	FOLIO_DB.dump = { items = items, timestamp = time() }
	print(("|cff33ff99Folio|r dumped %d items to SavedVariables (FOLIO_DB.dump)."):format(#items))
end

-- UI8: collapse-all/expand-all.
local function SetAllCollapsed(collapsed)
	local tree = Folio.Config.db.categories
	for _, node in pairs(tree.nodes) do
		node.collapsed = collapsed
	end
	-- Clears every window's per-category overrides (Q53) too -- a blunt
	-- "collapse/expand everything" should apply everywhere uniformly, not
	-- leave some categories stuck at whatever a specific window had
	-- customized -- Logic/Render.lua falls back to the node defaults just
	-- set above once there's nothing left in here.
	Folio.Config.db.collapsedByStorage = {}
	RefreshItems()
end
Folio.Actions.SetAllCollapsed = SetAllCollapsed

-- Dev/testing escape hatch: the category tree's *structure* changed
-- (not just a default value), so an existing save won't pick up the new
-- starter set on its own -- Config.Init() only seeds when categories
-- doesn't exist yet. Wipes manual sorting too, for a clean slate.
local function ResetCategories()
	Folio.Config.db.categories = Folio.Seed.BuildDefaultTree()
	Folio.Config.db.itemOverrides = {}
	Folio.Config.db.collapsedByStorage = {}
	RefreshItems()
	print("|cff33ff99Folio|r categories reset to defaults.")
end
Folio.Actions.ResetCategories = ResetCategories

-- F8: also reachable from the Options panel checkbox (UI/Options.lua).
local function ToggleBagReplacement()
	Folio.Config.db.bagReplacementEnabled = not Folio.Config.db.bagReplacementEnabled
	if Folio.Config.db.bagReplacementEnabled then
		Folio.BagReplacement.Enable()
		print("|cff33ff99Folio|r bag replacement enabled — the default bag keybind/buttons open Folio.")
	else
		Folio.BagReplacement.Disable()
		print("|cff33ff99Folio|r bag replacement disabled — Blizzard's bags are back.")
	end
end
Folio.Actions.ToggleBagReplacement = ToggleBagReplacement

local function ToggleBagSpaceAsPercent()
	Folio.Config.db.showBagSpaceAsPercent = not Folio.Config.db.showBagSpaceAsPercent
	RefreshBagSpace()
end
Folio.Actions.ToggleBagSpaceAsPercent = ToggleBagSpaceAsPercent

-- Q35/Q38: the "Show Bags" button (UI/Frame.lua) needs Blizzard's real bag
-- frames reachable ALONGSIDE Folio, not instead of it, in one click -- a
-- straight ToggleBagReplacement() flips the user's persisted preference
-- off with no way back except the Options checkbox, which stranded a
-- player who'd just lost their B keybind entirely (confirmed live). This
-- only clears the live keybind override -- db.bagReplacementEnabled (the
-- user's actual saved preference) is untouched -- so Blizzard's own
-- MainMenuBarBackpackButton (secure-click-forwarded to from the button,
-- see UI/Frame.lua) resolves _G.ToggleBackpack to the real Blizzard
-- function instead of Folio's. Restored automatically on the next
-- BAG_CLOSED, once the player's actually done looking, rather than
-- requiring them to remember to flip it back themselves.
--
-- A dropdown-menu version of this that called OpenAllBags directly was
-- tried and reverted (Q37/Q38): it only rendered the reagent bag instead
-- of the full combined bag window, almost certainly the same documented
-- taint bug corrupting ContainerFrame's layout, not just the "items
-- become unusable" symptom from Blizzard's own forums. The secure
-- click-forward this drives is the only version confirmed to work
-- correctly.
local function ArmBlizzardBagsPeek()
	if not Folio.Config.db.bagReplacementEnabled then return end
	Folio.BagReplacement.Disable()
	peekingBlizzardBags = true
end
Folio.Actions.ArmBlizzardBagsPeek = ArmBlizzardBagsPeek

SLASH_FOLIO1 = "/folio"
SlashCmdList.FOLIO = function(msg)
	if msg == "dump" then
		DumpFixture()
	elseif msg == "bagreplace" then
		ToggleBagReplacement()
	elseif msg == "collapseall" then
		SetAllCollapsed(true)
	elseif msg == "expandall" then
		SetAllCollapsed(false)
	elseif msg == "resetcategories" then
		ResetCategories()
	elseif msg == "options" then
		Folio.UI.Options.Open()
	elseif msg == "debug" then
		Folio.UI.Frame.Debug()
	elseif msg == "bankdebug" then
		Folio.UI.BankFrame.Debug()
	else
		Folio.UI.Frame.Toggle()
	end
end
