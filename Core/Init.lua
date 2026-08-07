local ADDON_NAME, Folio = ...

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function(self, event, loadedAddon)
	if event == "ADDON_LOADED" then
		if loadedAddon ~= ADDON_NAME then return end
		self:UnregisterEvent("ADDON_LOADED")
		Folio.Config.Init()
	elseif event == "PLAYER_LOGIN" then
		-- Pre-create the frame at login, not reactively later, to sidestep
		-- 12.0's in-combat/in-instance frame-creation restrictions (§3).
		Folio.UI.Frame.Create()
		print("|cff33ff99Folio|r loaded — type /folio to toggle the window")
	end
end)

SLASH_FOLIO1 = "/folio"
SlashCmdList.FOLIO = function()
	Folio.UI.Frame.Toggle()
end
