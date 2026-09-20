std = "lua51"
max_line_length = false

-- T1/T2: Logic/ and Data/ must never touch a WoW global directly.
-- Logic/ because it has to run under plain Lua (T1); Data/ because WoW
-- access is supposed to flow through the `api` parameter injected into
-- every function (T2), never reached for directly. "min" is the
-- portable intersection of Lua 5.1/5.2/5.3/LuaJIT stdlib globals --
-- nothing WoW-specific sneaks in. luacheck enforces this far more
-- thoroughly than the CI grep-based check (kept alongside this as a
-- fast, dependency-free first line of defense).
files["Logic/**/*.lua"] = { std = "min" }
files["Data/**/*.lua"] = { std = "min" }

-- Core/ and UI/ are the only files allowed to touch WoW's global
-- namespace directly. Harvested from an actual luacheck run against
-- the codebase rather than guessed, so it's exactly what's used, no
-- more -- if a new WoW API call gets added, luacheck will flag it as
-- undefined until it's deliberately added here.
local wowGlobals = {
	-- Widgets & frame construction
	"CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip",
	"CreateScrollBoxListLinearView", "ScrollUtil", "CreateDataProvider",
	-- Show Bags button (UI/Frame.lua): secure click-forward target
	"MainMenuBarBackpackButton",
	-- Item/container/bank/currency APIs
	"C_Container", "C_Item", "C_CurrencyInfo", "C_Bank", "C_TradeSkillUI", "Enum", "ItemLocation",
	-- Misc game state
	"GetMoney", "GetMoneyString", "GetCursorInfo", "GetCursorPosition",
	"GetMouseFoci", "GetScreenHeight", "GetScreenWidth", "ITEM_QUALITY_COLORS", "CopyTable", "time",
	"UnitName",
	"IsShiftKeyDown", "CreateColor",
	"C_Timer",
	-- Settings panel (§ Options)
	"Settings", "StaticPopup_Show",
	-- Corner menu (Blizzard_Menu)
	"MenuUtil",
	-- Combat-safe bag keybind override (Core/BagReplacement.lua)
	"InCombatLockdown", "GetBindingKey", "SetOverrideBindingClick", "ClearOverrideBindings",
	-- Sell cursor at a vendor (UI/Row.lua)
	"MerchantFrame", "ShowContainerSellCursor", "ResetCursor", "SetCursor",
}

-- StaticPopupDialogs is a Blizzard table addons register new keys into,
-- not a value addons assign wholesale, so it needs write access rather
-- than read_globals' read-only treatment. Both Core/ (category
-- create/delete/reset confirmations) and UI/ (Options panel) register
-- popups into it.
files["Core/**/*.lua"] = {
	read_globals = wowGlobals,
	-- Folio's own globals: FOLIO_DB is the declared SavedVariable;
	-- SLASH_FOLIO1/SlashCmdList are how WoW's slash command system works.
	globals = { "FOLIO_DB", "SLASH_FOLIO1", "SlashCmdList", "StaticPopupDialogs" },
}
files["UI/**/*.lua"] = {
	read_globals = wowGlobals,
	globals = { "StaticPopupDialogs" },
}

-- Tests/ use busted's DSL (describe/it/assert/before_each/...).
files["Tests/spec/**/*.lua"] = { std = "lua51+busted" }
