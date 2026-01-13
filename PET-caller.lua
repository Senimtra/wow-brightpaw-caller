-- PET-caller: summon Brightpaw whenever I mount Mystic Runesaber.

local frame = CreateFrame("Frame") -- Create a hidden frame to receive events.
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Register the login/reload event.
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") -- Register the spell-cast success event.
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Register mount state changes.
frame:RegisterEvent("PLAYER_STOPPED_MOVING") -- Register movement stops to check for landing.

local fired = false -- Guard the one-time load message.
local MOUNT_SPELL_NAME = "Mystic Runesaber" -- Exact mount spell name.
local PET_NAME = "Brightpaw" -- Exact pet name.
local targetPetGUID = nil -- Cache Brightpaw's GUID once found.
local lastMountIsMystic = false -- Remember if the last mount cast was Mystic Runesaber.
local groundCheckTicker = nil -- Store a repeating timer for ground checks.

local function getSpellName(spellID) -- Helper to resolve spell names.
    if C_Spell and C_Spell.GetSpellName then -- Prefer the newest API.
        return C_Spell.GetSpellName(spellID) -- Return the spell name.
    end -- End the newest API branch.
    if C_Spell and C_Spell.GetSpellInfo then -- Try the older C_Spell API.
        local info = C_Spell.GetSpellInfo(spellID) -- Fetch the spell info table.
        return info and info.name or nil -- Return the name if available.
    end -- End the older API branch.
    if GetSpellInfo then -- Fall back to the legacy global API.
        return GetSpellInfo(spellID) -- Return the spell name.
    end -- End the legacy API branch.
    return nil -- Return nil if no API exists.
end -- Finish the getSpellName helper.

local function isAirborne() -- Helper that tells if the player is in the air.
    if IsFlying and IsFlying() then -- Treat flying as airborne.
        return true -- Report airborne.
    end -- End the flying check.
    if IsFalling and IsFalling() then -- Treat falling as airborne.
        return true -- Report airborne.
    end -- End the falling check.
    return false -- Assume grounded otherwise.
end -- Finish the isAirborne helper.

local function findBrightpawGUID() -- Helper to find Brightpaw in the pet journal.
    local numPets = C_PetJournal.GetNumPets() -- Read how many pets exist.
    for i = 1, numPets do -- Loop over each pet entry.
        local petID, _, owned, customName, _, _, _, name = C_PetJournal.GetPetInfoByIndex(i) -- Read pet data.
        local displayName = customName or name -- Use the custom name if it exists.
        if owned and displayName == PET_NAME then -- Match only owned pets by name.
            return petID -- Return the GUID for Brightpaw.
        end -- End the match check.
    end -- End the loop.
    return nil -- Return nil if Brightpaw is not found.
end -- Finish the findBrightpawGUID helper.

local function summonBrightpawIfNeeded() -- Helper to summon Brightpaw safely.
    if not targetPetGUID then -- Check if the GUID is cached.
        targetPetGUID = findBrightpawGUID() -- Look it up if missing.
    end -- End the cache check.
    if not targetPetGUID then -- Stop if still missing.
        return -- Exit early.
    end -- End the missing-GUID branch.

    if C_PetJournal.GetSummonedPetGUID() == targetPetGUID then -- Skip if Brightpaw is already out.
        return -- Exit early to avoid toggling the pet off.
    end -- End the already-summoned branch.

    C_PetJournal.SummonPetByGUID(targetPetGUID) -- Summon Brightpaw.
end -- Finish the summon helper.

local function shouldSummonOnGround() -- Helper to decide if re-summon on ground is needed.
    if not lastMountIsMystic then -- Only act if last mount was Mystic Runesaber.
        return false -- Say no.
    end -- End the mount-name check.
    if not (IsMounted and IsMounted()) then -- Require that the player is still mounted.
        return false -- Say no.
    end -- End the mounted check.
    if isAirborne() then -- Do nothing while in the air.
        return false -- Say no.
    end -- End the airborne check.
    return true -- Say yes if all checks pass.
end -- Finish the ground-check helper.

local function handleGroundCheck() -- Helper for ground re-summons.
    if shouldSummonOnGround() then -- Only act when conditions are right.
        summonBrightpawIfNeeded() -- Summon Brightpaw if needed.
    end -- End the conditional.
end -- Finish the ground handler.

local function startGroundCheckTicker() -- Helper to start a repeating ground check.
    if groundCheckTicker then -- Avoid creating duplicate timers.
        return -- Exit early.
    end -- End the duplicate guard.
    if not (C_Timer and C_Timer.NewTicker) then -- Bail if timers are unavailable.
        return -- Exit early.
    end -- End the timer availability check.
    groundCheckTicker = C_Timer.NewTicker(1, function() handleGroundCheck() end) -- Check once per second.
end -- Finish the ticker starter.

local function stopGroundCheckTicker() -- Helper to stop the repeating ground check.
    if not groundCheckTicker then -- Do nothing if no timer exists.
        return -- Exit early.
    end -- End the guard.
    groundCheckTicker:Cancel() -- Stop the timer.
    groundCheckTicker = nil -- Clear the reference.
end -- Finish the ticker stopper.

frame:SetScript("OnEvent", function(_, event, ...) -- Define the event handler.
    if event == "PLAYER_ENTERING_WORLD" then -- Handle the login/reload event.
        if fired then return end -- Avoid running twice.
        fired = true -- Mark the event as handled.
        targetPetGUID = findBrightpawGUID() -- Cache Brightpaw's GUID early.
        DEFAULT_CHAT_FRAME:AddMessage("|cff8f3fffPET-caller|r loaded v1.0") -- Print the load message.
        return -- Finish this event.
    end -- End the login branch.

    if event == "UNIT_SPELLCAST_SUCCEEDED" then -- Handle successful spell casts.
        local unit, _, spellID = ... -- Read the event payload.
        if unit ~= "player" then return end -- Ignore other units.

        local spellName = getSpellName(spellID) -- Convert the spell ID to a name.
        if spellName == MOUNT_SPELL_NAME then -- React only to the mount cast.
            lastMountIsMystic = true -- Remember that Mystic Runesaber was mounted.
            summonBrightpawIfNeeded() -- Summon Brightpaw right away if needed.
            startGroundCheckTicker() -- Keep checking for ground re-summons.
        end -- End the mount-name check.
        return -- Finish this event.
    end -- End the spellcast branch.

    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then -- Handle mount state changes.
        if IsMounted and not IsMounted() then -- Detect dismounts.
            lastMountIsMystic = false -- Clear the mount flag on dismount.
            stopGroundCheckTicker() -- Stop the ground check timer.
        end -- End the dismount check.
        return -- Finish this event.
    end -- End the mount-display branch.

    if event == "PLAYER_STOPPED_MOVING" then -- Handle movement stops (like landing).
        handleGroundCheck() -- Try a ground re-summon when movement stops.
        return -- Finish this event.
    end -- End the movement branch.
end) -- Finish the event handler.
