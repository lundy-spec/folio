local ADDON_NAME, Folio = ...

local UNCATEGORIZED = "uncategorized"

local function GroupByCategory(tree, items)
	local groups = {}
	local resolved = Folio.Data.Assign.ResolveAll(tree, items)
	for i, item in ipairs(items) do
		local categoryID = resolved[i] or UNCATEGORIZED
		groups[categoryID] = groups[categoryID] or {}
		table.insert(groups[categoryID], item)
	end
	return groups
end

-- Full rescan on every bag change — no diffing yet (architecture principle
-- 3 wants incremental diffs eventually; this spike proves the virtualized
-- list works with real data first).
local function RefreshItems()
	local items = Folio.Data.Scanner.ScanBags(Folio.API, Folio.API.GetBagIDs())
	Folio.Data.Cache.SetItems(items)

	local tree = Folio.Config.db.categories
	local groups = GroupByCategory(tree, items)
	local rows = Folio.Render.BuildRows(tree, groups)
	Folio.UI.ListView.SetItems(rows)
end

Folio.UI.Row.OnHeaderClick = function(categoryID)
	local node = Folio.Tree.GetNode(Folio.Config.db.categories, categoryID)
	if not node then return end
	node.collapsed = not node.collapsed
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
	end
end)

-- T4: serializes the current scan to SavedVariables so it can be captured
-- as a real test fixture (Tests/fixtures/) rather than a synthetic one.
local function DumpFixture()
	local items = Folio.Data.Cache.GetItems()
	FOLIO_DB.dump = { items = items, timestamp = time() }
	print(("|cff33ff99Folio|r dumped %d items to SavedVariables (FOLIO_DB.dump)."):format(#items))
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
	else
		Folio.UI.Frame.Toggle()
	end
end
