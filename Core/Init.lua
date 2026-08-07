local ADDON_NAME, Folio = ...

local UNCATEGORIZED = "uncategorized"

-- §4.3 S1: sub-groups (and bank/warband data at all) only exist while a
-- banker is actually open.
local isBankOpen = false

local function ScanAllStorages()
	local items = Folio.Data.Scanner.ScanBags(Folio.API, Folio.API.GetBagIDs(), "bags")
	if isBankOpen then
		local bankItems = Folio.Data.Scanner.ScanBags(Folio.API, Folio.API.GetCharacterBankTabIDs(), "bank")
		local warbandItems = Folio.Data.Scanner.ScanBags(Folio.API, Folio.API.GetWarbandBankTabIDs(), "warband")
		for _, item in ipairs(bankItems) do
			table.insert(items, item)
		end
		for _, item in ipairs(warbandItems) do
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
	local resolved = Folio.Data.Assign.ResolveAll(tree, items)
	for i, item in ipairs(items) do
		local categoryID = resolved[i] or UNCATEGORIZED
		item.categoryID = categoryID
		groups[categoryID] = groups[categoryID] or {}
		local storage = item.storage or "bags"
		groups[categoryID][storage] = groups[categoryID][storage] or {}
		table.insert(groups[categoryID][storage], item)
	end
	return groups
end

-- Full rescan on every bag/bank change — no diffing yet (architecture
-- principle 3 wants incremental diffs eventually; this spike proves the
-- virtualized list works with real data first).
local function RefreshItems()
	local items = ScanAllStorages()
	Folio.Data.Cache.SetItems(items)

	local tree = Folio.Config.db.categories
	local groups = GroupByCategory(tree, items)
	local rows = Folio.Render.BuildRows(tree, groups, isBankOpen)
	Folio.UI.ListView.SetItems(rows)
end

Folio.UI.Row.OnHeaderClick = function(categoryID, subgroup)
	local node = Folio.Tree.GetNode(Folio.Config.db.categories, categoryID)
	if not node then return end
	if subgroup then
		node.subCollapsed[subgroup] = not node.subCollapsed[subgroup]
	else
		node.collapsed = not node.collapsed
	end
	RefreshItems()
end

-- §4.3 S5, narrowed first pass: drag an item onto a Bags/Bank/Warband
-- sub-group header WITHIN ITS OWN CATEGORY to transfer it. Cross-category
-- transfer+recategorize, stack modifiers, and bulk queue/throttle are
-- deliberate follow-ups -- see Logic/Transfer.lua's header.

local function StorageBagIDs(storage)
	if storage == "bank" then return Folio.API.GetCharacterBankTabIDs() end
	if storage == "warband" then return Folio.API.GetWarbandBankTabIDs() end
	return Folio.API.GetBagIDs()
end

local function BankTypeForStorage(storage)
	if storage == "bank" then return Enum.BankType.Character end
	if storage == "warband" then return Enum.BankType.Account end
	return nil
end

Folio.UI.Row.OnItemDragStart = function(itemRow)
	Folio.API.PickupContainerItem(itemRow.itemBag, itemRow.itemSlot)
end

Folio.UI.Row.OnItemDragStop = function(itemRow, target)
	-- Not dropped on one of our own sub-group headers -- leave the item
	-- on the cursor exactly as native WoW does on an invalid drop; the
	-- player can still click any real bag/bank slot to place it, or
	-- click the same slot again to cancel.
	if not target or target.entryKind ~= "header" or not target.subgroup then
		return
	end

	if target.categoryID ~= itemRow.itemCategoryID then
		print("|cff33ff99Folio|r cross-category drag isn't supported yet -- item's still on your cursor, click a bag/bank slot to place it.")
		return
	end

	local toStorage = target.subgroup
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
		print("|cff33ff99Folio|r can't move that there (" .. reason .. ") -- item's still on your cursor.")
		return
	end

	Folio.API.PickupContainerItem(destBag, destSlot)
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
bootstrap:RegisterEvent("PLAYER_MONEY")
bootstrap:RegisterEvent("BANKFRAME_OPENED")
bootstrap:RegisterEvent("BANKFRAME_CLOSED")
bootstrap:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
bootstrap:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
bootstrap:SetScript("OnEvent", function(self, event, loadedAddon)
	if event == "ADDON_LOADED" then
		if loadedAddon ~= ADDON_NAME then return end
		self:UnregisterEvent("ADDON_LOADED")
		Folio.Config.Init()
	elseif event == "PLAYER_LOGIN" then
		-- Pre-create the frame at login, not reactively later, to sidestep
		-- 12.0's in-combat/in-instance frame-creation restrictions (§3).
		Folio.UI.Frame.Create()
		RefreshItems()
		RefreshCurrencies()
		if Folio.Config.db.bagReplacementEnabled then
			Folio.BagReplacement.Enable()
		end
		print("|cff33ff99Folio|r loaded — type /folio to toggle the window")
	elseif event == "BAG_UPDATE_DELAYED" then
		RefreshItems()
	elseif event == "PLAYER_MONEY" then
		RefreshCurrencies()
	elseif event == "BANKFRAME_OPENED" then
		isBankOpen = true
		RefreshItems()
	elseif event == "BANKFRAME_CLOSED" then
		isBankOpen = false
		RefreshItems()
	elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
		if isBankOpen then
			RefreshItems()
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

-- UI8: collapse-all/expand-all. Promoted to a primary control per the
-- PRD, but there's no search-bar-adjacent button built yet, so a slash
-- command stands in for now. Also touches every sub-group's collapse
-- state, not just each category's own.
local function SetAllCollapsed(collapsed)
	local tree = Folio.Config.db.categories
	for _, node in pairs(tree.nodes) do
		node.collapsed = collapsed
		for storage in pairs(node.subCollapsed) do
			node.subCollapsed[storage] = collapsed
		end
	end
	RefreshItems()
end

-- F8: no Options panel yet to flip this from, so a slash command in the
-- meantime.
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
	else
		Folio.UI.Frame.Toggle()
	end
end
