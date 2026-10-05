--[[
================================================================================
  gazes.lua - ability database for reChhar
  Covers all jobs because any job can be a gaze target.

  Schema per entry:
    name    = canonical ability name as it appears in chat log
    id      = action ID (needed for 0x028 packet matching)
    type    = 'eye' | 'gaze' | 'frontal' | 'conal' | 'aoe'
              determines whether facing away helps
    delay   = telegraph seconds before resolution (how long we have to react)
    effect  = short tag of what happens if you don't turn away
    era     = which era this ability exists in
================================================================================
]]--

local M = {};

-- ============================================================================
-- Base (always available in all eras)
-- ============================================================================
M.base = {
    -- Classic eye/gaze lineup — base game through RoZ
    ["Stone Gaze"]        = { id = 0x078, type = 'gaze', delay = 2.0, effect = 'petrify',       era = 'base' },
    ["Mortal Ray"]        = { id = 0x079, type = 'eye',  delay = 2.5, effect = 'doom',          era = 'base' },
    ["Hex Eye"]           = { id = 0x07A, type = 'eye',  delay = 2.0, effect = 'paralyze',      era = 'base' },
    ["Blaster"]           = { id = 0x07B, type = 'eye',  delay = 2.0, effect = 'paralyze',      era = 'base' },
    ["Chaotic Eye"]       = { id = 0x07C, type = 'eye',  delay = 2.0, effect = 'silence',       era = 'base' },
    ["Charming Gaze"]     = { id = 0x07D, type = 'gaze', delay = 2.0, effect = 'charm',         era = 'base' },
    ["Gloom Breath"]      = { id = 0x07E, type = 'conal',delay = 2.5, effect = 'doom',          era = 'base' },
    ["Reaving Wind"]      = { id = 0x07F, type = 'eye',  delay = 2.0, effect = 'silence',       era = 'base' },
    ["Petro Eyes"]        = { id = 0x080, type = 'gaze', delay = 2.0, effect = 'petrify',       era = 'base' },
};

-- ============================================================================
-- CoP / ToAU additions
-- ============================================================================
M.toau = {
    -- ToAU monsters: Puks, Marids, Lamiae, Troll Mercenaries, etc.
    ["Breath Gaze"]       = { id = 0x100, type = 'gaze', delay = 2.0, effect = 'poison',        era = 'toau' },
    ["Weakening Gaze"]    = { id = 0x101, type = 'gaze', delay = 2.0, effect = 'weakness',      era = 'toau' },
    ["Soporific"]         = { id = 0x102, type = 'eye',  delay = 2.5, effect = 'sleep',         era = 'toau' },
};

-- ============================================================================
-- WoTG + later (Phoenix will unlock when they ship WoTG)
-- ============================================================================
M.wotg = {
    ["Despotic Gaze"]     = { id = 0x120, type = 'gaze', delay = 2.0, effect = 'paralyze',      era = 'wotg' },
    ["Shadow Spread"]     = { id = 0x121, type = 'conal',delay = 3.0, effect = 'curse',         era = 'wotg' },
};

-- ============================================================================
-- Retail-era (SoA / RoV / modern)
-- ============================================================================
M.retail = {
    -- Add as needed; sparse because reChhar's primary audience is era servers.
    ["Daydream"]          = { id = 0x200, type = 'eye',  delay = 2.0, effect = 'sleep',         era = 'retail' },
    ["Dreamflower"]       = { id = 0x201, type = 'aoe',  delay = 3.0, effect = 'sleep',         era = 'retail' },
};

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

-- Returns the merged ability table for a given era (base + era-specific).
function M.listFor(era)
    local out = {};
    for k, v in pairs(M.base) do out[k] = v; end
    if (era == 'toau' or era == 'wotg' or era == 'retail') then
        for k, v in pairs(M.toau) do out[k] = v; end
    end
    if (era == 'wotg' or era == 'retail') then
        for k, v in pairs(M.wotg) do out[k] = v; end
    end
    if (era == 'retail') then
        for k, v in pairs(M.retail) do out[k] = v; end
    end
    return out;
end

-- Count abilities tracked for a given era (used by /rechhar era <X>).
function M.countFor(era)
    local n = 0;
    for _ in pairs(M.listFor(era)) do n = n + 1; end
    return n;
end

-- Look up a specific ability by name OR by action ID.
function M.lookup(nameOrId, era)
    local tbl = M.listFor(era);
    if (type(nameOrId) == 'string') then
        return tbl[nameOrId];
    elseif (type(nameOrId) == 'number') then
        for name, info in pairs(tbl) do
            if (info.id == nameOrId) then return info; end
        end
    end
    return nil;
end

return M;
