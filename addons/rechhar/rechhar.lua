--[[
================================================================================
  reChhar v0.2.0 - Ashita port of React
  (Sammeh/Byrth's Windower addon, original 2016; ported & simplified)

  Universal mode: no per-job files. When ANY mob begins a gaze ability
  targeting you, you face away. When it resolves, you face back.

  Design decisions:
    * Uses Ashita's packet 0x028 (action packet) for detection -- same event
      source as Windower's 'action' event, just one level lower.
    * Uses direct heading manipulation via the entity's memory. If your
      Ashita build exposes SetHeading differently, see the TODO near
      faceAt() for the override point.
    * Runaway/runto from original React are OMITTED for v0.2 -- getting
      character movement right from an addon on era servers is risky
      flag-wise, and 90% of gaze defense is just facing away.
    * No per-job behavior.

  Credits: Sammeh (original React, 2016), Byrth, Langly (turnaround math)
================================================================================
]]--

addon.name    = 'reChhar';
addon.author  = 'ChharithOeun (port) / Sammeh (original React)';
addon.version = '0.2.2';
addon.desc    = 'Universal auto-face-away during gaze attacks (Ashita port of React)';

require('common');
local gazes    = require('data.gazes');
local settings = require('data.settings');

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
local M = {
    enabled      = false,
    era          = 'toau',
    savedHeading = nil,       -- restore to this after action resolves
    savedTarget  = nil,       -- the mob whose gaze we're reacting to
    debug        = false,
};

-- Hydrate from saved settings
local cfg = settings.load();
M.enabled = cfg.enabled or false;
M.era     = cfg.era     or 'toau';

-- ---------------------------------------------------------------------------
-- Load / Unload
-- ---------------------------------------------------------------------------
ashita.events.register('load', 'rechhar_load', function()
    print(('[reChhar] v%s loaded. State: %s | Era: %s | /rechhar help for commands.')
          :format(addon.version, M.enabled and 'ON' or 'OFF', M.era));
end);

ashita.events.register('unload', 'rechhar_unload', function()
    cfg.enabled = M.enabled;
    cfg.era     = M.era;
    settings.save(cfg);
end);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function selfIndex()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
end

local function selfServerId()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
end

local function entity() return AshitaCore:GetMemoryManager():GetEntity(); end

-- Find a mob's entity index by server id. Walk the entity table since Ashita
-- doesn't give us a direct id -> index lookup.
local function indexFromServerId(serverId)
    local ent = entity();
    for i = 0, 0x8FF do
        if (ent:GetServerId(i) == serverId) then return i; end
    end
    return nil;
end

local function echo(msg)
    print('[reChhar] '..msg);
end

-- ---------------------------------------------------------------------------
-- Heading control
-- ---------------------------------------------------------------------------
-- Compute the heading radian that points you AWAY from (or TOWARD) a mob
-- entity, given the current self position.
--
-- Math is identical to Byrth's React:  atan2(dy, dx) * 180/pi * -1  (deg)
-- then add 180 if we want the opposite direction, convert to radians.
local function computeHeading(mobIdx, selfIdx, facingAway)
    local ent = entity();
    local mx, my = ent:GetLocalPositionX(mobIdx), ent:GetLocalPositionY(mobIdx);
    local sx, sy = ent:GetLocalPositionX(selfIdx), ent:GetLocalPositionY(selfIdx);
    if (not mx or not sx) then return nil; end
    local degrees = (math.atan2((my - sy), (mx - sx)) * 180 / math.pi) * -1;
    if (facingAway) then degrees = degrees + 180; end
    return degrees * math.pi / 180;
end

-- Ashita v4 exposes GetHeading / SetHeading (no "Local" prefix) on the
-- entity table. Positions ARE prefixed (GetLocalPositionX etc.) but heading
-- is not. Confirmed on Phoenix build 2026-10-04.
local function setHeading(idx, radians)
    entity():SetHeading(idx, radians);
end

local function getHeading(idx)
    return entity():GetHeading(idx);
end

local function faceAway(mobIdx)
    local si = selfIndex();
    local h  = computeHeading(mobIdx, si, true);
    if (not h) then return; end
    -- Save the heading we were at so we can restore
    M.savedHeading = getHeading(si);
    M.savedTarget  = mobIdx;
    setHeading(si, h);
    if (M.debug) then echo('faceAway -> rad '..string.format('%.3f', h)); end
end

local function faceBack()
    if (M.savedHeading == nil) then return; end
    setHeading(selfIndex(), M.savedHeading);
    if (M.debug) then echo('faceBack -> rad '..string.format('%.3f', M.savedHeading)); end
    M.savedHeading = nil;
    M.savedTarget  = nil;
end

-- ---------------------------------------------------------------------------
-- Action-packet handler  (0x028 = incoming action, equivalent to Windower's
-- 'action' event). We parse enough to know: who's acting, what ability,
-- what category, and who the primary target is.
-- ---------------------------------------------------------------------------
--
-- Packet 0x028 layout (reference: Project Topaz / Ashita docs):
--   offset  size   field
--   0x05    4      actor_id (server id of the mob/player casting)
--   0x09    4b/4b  target_count (low nibble) / unused
--   0x0A    4b/6b  category (low 4 bits) / param_hi (upper 6 bits)
--   0x0B    1b/16b reserved / param (spell/ability id)
--     ^ category 4 = finished spell, 7 = begin ability, 8 = begin spell,
--       11 = finished ability
--   0x19    4      first target server id
--
-- We only care about: is actor an NPC, is first target me, what's the ability
-- id, and what's the category.
local function parseAction028(data)
    -- Pull values via string.byte with masking
    local b = function(off) return struct.unpack('B', data, 1 + off); end
    local w = function(off) return struct.unpack('I4', data, 1 + off); end

    local actor_id      = w(0x05);
    local category_byte = b(0x0A);
    local category      = category_byte % 16;
    local param         = struct.unpack('I2', data, 1 + 0x0B);
    local first_target  = w(0x19);
    return actor_id, category, param, first_target;
end

ashita.events.register('packet_in', 'rechhar_028', function(e)
    if (not M.enabled) then return; end
    if (e.id ~= 0x028) then return; end

    local ok, actorId, category, param, firstTargetId = pcall(parseAction028, e.data);
    if (not ok) then return; end

    -- We only react when the action's primary target is US
    if (firstTargetId ~= selfServerId()) then return; end
    -- And we only react to NPC actors (not players)
    local actorIdx = indexFromServerId(actorId);
    if (not actorIdx) then return; end
    local isNpc = (entity():GetSpawnFlags(actorIdx) ~= 0);  -- non-zero = non-player
    if (not isNpc) then return; end

    -- Resolve ability name from category + param
    local abilityName = nil;
    local rm = AshitaCore:GetResourceManager();
    if (category == 7 or category == 11) then
        -- Monster ability (ready move)
        local ab = rm:GetAbilityById(param + 0x200);  -- monster abilities offset
        if (ab) then abilityName = ab.Name[1]; end
    elseif (category == 8 or category == 4) then
        -- Spell
        local sp = rm:GetSpellById(param);
        if (sp) then abilityName = sp.Name[1]; end
    else
        return;  -- categories we don't care about
    end
    if (not abilityName) then return; end

    local gaze = gazes.lookup(abilityName, M.era);
    if (not gaze) then
        if (M.debug) then echo('(not a tracked gaze) '..abilityName); end
        return;
    end

    if (M.debug) then
        echo(('%s uses %s (cat %d) -> %s')
             :format('mob', abilityName, category, gaze.type));
    end

    -- Category 7 or 8 = beginning the action  (face away)
    -- Category 4 or 11 = finished the action  (face back)
    if (category == 7 or category == 8) then
        faceAway(actorIdx);
        echo(('turning away from %s'):format(abilityName));
    elseif (category == 4 or category == 11) then
        faceBack();
    end
end);

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------
ashita.events.register('command', 'rechhar_command', function(e)
    local args = e.command:args();
    if (#args == 0 or args[1]:lower() ~= '/rechhar') then return; end
    e.blocked = true;

    local cmd = (args[2] or ''):lower();
    local val = (args[3] or ''):lower();

    if (cmd == 'on') then
        M.enabled = true;  cfg.enabled = true;  settings.save(cfg);
        echo('ENABLED');
    elseif (cmd == 'off') then
        M.enabled = false; cfg.enabled = false; settings.save(cfg);
        echo('DISABLED');
    elseif (cmd == 'era') then
        if (val == 'toau' or val == 'wotg' or val == 'retail' or val == 'base') then
            M.era = val; cfg.era = val; settings.save(cfg);
            echo(('era = %s (%d gazes tracked)'):format(val, gazes.countFor(val)));
        else
            echo(('era = %s. options: base, toau, wotg, retail'):format(M.era));
        end
    elseif (cmd == 'list') then
        echo(('tracked gazes for era "%s":'):format(M.era));
        for name, info in pairs(gazes.listFor(M.era)) do
            print(('  %-25s  %-7s  (%s)'):format(name, info.type, info.effect or '-'));
        end
    elseif (cmd == 'debug') then
        M.debug = not M.debug;
        echo('debug = '..tostring(M.debug));
    elseif (cmd == 'test') then
        -- Test the heading math on your current target.
        -- Timer-free: /rechhar test faces you away, /rechhar faceback restores.
        local t = AshitaCore:GetMemoryManager():GetTarget();
        local tidx = t:GetTargetIndex(0);
        if (tidx and tidx ~= 0) then
            echo('facing away from current target. Run /rechhar faceback to restore.');
            faceAway(tidx);
        else
            echo('no target to test on');
        end
    elseif (cmd == 'faceback') then
        faceBack();
        echo('faced back');
    else
        echo('commands:');
        print('  /rechhar on | off');
        print('  /rechhar era <base|toau|wotg|retail>');
        print('  /rechhar list     -- show tracked gazes');
        print('  /rechhar test     -- face away from current target (manual)');
        print('  /rechhar faceback -- restore heading after test');
        print('  /rechhar debug    -- toggle verbose logging');
    end
end);

return M;
