local ADDON_NAME, Folio = ...

-- Full rescan on every bag change — no diffing yet (architecture principle
-- 3 wants incremental diffs eventually; this spike proves the virtualized
-- list works with real data first).
local function RefreshItems()
	local items = Folio.Data.Scanner.ScanBags(Folio.API, Folio.API.GetBagIDs())
	Folio.Data.Cache.SetItems(items)
	Folio.UI.ListView.SetItems(items)
end

-- CUR8: one-time seed from the user's existing Blizzard backpack-tracked
-- currencies, so most users never need the (not-yet-built) Options picker.
local function SeedCurrenciesIfNeeded()
	if Folio.Config.db.seededCurrencies then return end
	local ids = Folio.Data.Currency.SeedFromBackpack(Folio.API)
	for _, id in ipairs(ids) do
		table.insert(Folio.Config.db.pinnedCurrencies, id)
	end
	Folio.Config.db.seededCurrencies = true
end

local function RefreshCurrencies()
	local entries = { Folio.Data.Currency.GetGoldEntry(Folio.API) }
	local pinned = Folio.Data.Currency.ScanPinned(Folio.API, Folio.Config.db.pinnedCurrencies)
	for _, entry in ipairs(pinned) do
		table.insert(entries, entry)
	end
	Folio.UI.CurrencyBar.SetEntries(entries)
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:RegisterEvent("BAG_UPDATE_DELAYED")
bootstrap:RegisterEvent("PLAYER_MONEY")
bootstrap:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
bootstrap:SetScript("OnEvent", function(self, event, loadedAddon)
	if event == "ADDON_LOADED" then
		if loadedAddon ~= ADDON_NAME then return end
		self:UnregisterEvent("ADDON_LOADED")
		Folio.Config.Init()
	elseif event == "PLAYER_LOGIN" then
		-- Pre-create the frame at login, not reactively later, to sidestep
		-- 12.0's in-combat/in-instance frame-creation restrictions (§3).
		Folio.UI.Frame.Create()
		SeedCurrenciesIfNeeded()
		RefreshItems()
		RefreshCurrencies()
		print("|cff33ff99Folio|r loaded — type /folio to toggle the window")
	elseif event == "BAG_UPDATE_DELAYED" then
		RefreshItems()
	elseif event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
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

-- Temporary diagnostic for the currency-bar visibility bug -- remove once
-- it's found.
local function DebugCurrencyBar()
	local f = _G.FolioFrame
	local bar = Folio.UI.CurrencyBar.DebugGetBar()
	print("|cff33ff99[folio debug]|r FolioFrame:", f, "shown:", f and f:IsShown(), "visible:", f and f:IsVisible())
	print("|cff33ff99[folio debug]|r bar:", bar, "shown:", bar and bar:IsShown(), "visible:", bar and bar:IsVisible())
	if bar then
		print("|cff33ff99[folio debug]|r bar:GetParent() == FolioFrame:", bar:GetParent() == f)
		print("|cff33ff99[folio debug]|r bar:GetParent():GetName():", bar:GetParent() and bar:GetParent():GetName())
	end
end

SLASH_FOLIO1 = "/folio"
SlashCmdList.FOLIO = function(msg)
	if msg == "dump" then
		DumpFixture()
	elseif msg == "debug" then
		DebugCurrencyBar()
	else
		Folio.UI.Frame.Toggle()
	end
end
