local _, Folio = ...

local Config = {}
Folio.Config = Config

local defaults = {
	frame = {
		width = 320,
		height = 500,
		point = "RIGHT",
		relativePoint = "RIGHT",
		x = -40,
		y = 0,
	},
	pinnedCurrencies = {},
	seededCurrencies = false,
	-- F8: "Default on; must degrade gracefully when off."
	bagReplacementEnabled = true,
	-- R2: manual category assignment, keyed by itemID. A sticky override
	-- no rule can move -- checked before rule resolution in
	-- Data/Assign.lua.
	itemOverrides = {},
}

function Config.Init()
	FOLIO_DB = FOLIO_DB or {}
	FOLIO_DB.frame = FOLIO_DB.frame or CopyTable(defaults.frame)
	FOLIO_DB.pinnedCurrencies = FOLIO_DB.pinnedCurrencies or CopyTable(defaults.pinnedCurrencies)
	if FOLIO_DB.seededCurrencies == nil then
		FOLIO_DB.seededCurrencies = defaults.seededCurrencies
	end
	if FOLIO_DB.bagReplacementEnabled == nil then
		FOLIO_DB.bagReplacementEnabled = defaults.bagReplacementEnabled
	end
	FOLIO_DB.itemOverrides = FOLIO_DB.itemOverrides or CopyTable(defaults.itemOverrides)
	-- F11: seed once. Folio.Seed is pure (no WoW API calls), safe to run
	-- here at ADDON_LOADED time rather than waiting for PLAYER_LOGIN. Once
	-- FOLIO_DB.categories exists (even as an emptied-out tree, if the user
	-- deletes everything later) this never re-seeds.
	if not FOLIO_DB.categories then
		FOLIO_DB.categories = Folio.Seed.BuildDefaultTree()
	end
	Config.db = FOLIO_DB
end

return Config
