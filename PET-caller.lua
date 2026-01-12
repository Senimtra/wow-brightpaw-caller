local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local fired = false

frame:SetScript("OnEvent", function()
    if fired then return end
    fired = true

    DEFAULT_CHAT_FRAME:AddMessage("|cff8f3fffPET-caller|r loaded v1.0")
end)
