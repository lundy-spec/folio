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
}

function Config.Init()
	FOLIO_DB = FOLIO_DB or {}
	FOLIO_DB.frame = FOLIO_DB.frame or CopyTable(defaults.frame)
	FOLIO_DB.pinnedCurrencies = FOLIO_DB.pinnedCurrencies or CopyTable(defaults.pinnedCurrencies)
	if FOLIO_DB.seededCurrencies == nil then
		FOLIO_DB.seededCurrencies = defaults.seededCurrencies
	end
	Config.db = FOLIO_DB
end

return Config
