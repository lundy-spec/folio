local ADDON_NAME, Folio = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
	if loadedAddon ~= ADDON_NAME then return end
	self:UnregisterEvent("ADDON_LOADED")
	print("|cff33ff99Folio|r loaded — v0.0.1 alpha")
end)
