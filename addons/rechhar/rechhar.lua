--[[
================================================================================
  reChhar - gaze detection and reaction for Ashita v4
  by Chharizard

  When a mob targets you with a gaze/eye attack, reChhar fires:
    * ALERT: big chat warning telling you which ability from which mob
    * AUTOTURN (opt-in): sends outgoing position packet to rotate you away

  Universal mode: one addon handles all 22 jobs. Era-aware ability database
  (base / ToAU / WoTG / retail). Works on Horizon XI, Phoenix XI, and retail.
================================================================================
]]--

addon.name    = 'reChhar';
addon.author  = 'Chharizard';
addon.version = '0.4.0';
addon.desc    = 'Gaze detection and reaction (alert + optional auto-turn)';

require('common');
local gazes    = require('data.gazes');
local settings = require('data.settings');

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
local M = {
    enabled      = false,
    era          = 'toau',
    alert        = true,       -- chat warning on gaze detect (safe, default ON)
    autoturn     = false,      -- packet-based auto-rotate (opt-in, experimental)
    hud          = false,      -- floating-card HUD for ALL mob abilities (opt-in)
    hudPosX      = 400,
    hudPosY      = 80,
    hudCards     = {},         -- active telegraph cards: [actor_id] = {ability, mob, startedAt, duration}
    telegraphDefault = 3.0,    -- fallback telegraph duration if unknown
    cardMaxAge   = 10.0,       -- hard-remove cards after this many seconds
    savedHeading = nil,
    savedTarget  = nil,
    debug        = false,
};

local cfg = settings.load();
M.enabled  = cfg.enabled  == true;
M.era      = cfg.era      or 'toau';
M.alert    = (cfg.alert    ~= false);
M.autoturn = cfg.autoturn == true;
M.hud      = cfg.hud      == true;
M.hudPosX  = cfg.hudPosX  or 400;
M.hudPosY  = cfg.hudPosY  or 80;

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

-- Scan entity table for the one whose ServerId == us (declared AFTER entity()
-- so Lua can resolve the call -- local function forward-references don't work).
local function selfIndexByScan()
    local sid = selfServerId();
    local ent = entity();
    for i = 0, 0x8FF do
        if (ent:GetServerId(i) == sid) then return i; end
    end
    return nil;
end

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

-- Ashita v4 exposes GetHeading / SetHeading on the entity table. HOWEVER
-- writing the player's heading via entity memory often doesn't visibly
-- rotate the character -- the engine controls player facing via a separate
-- target-heading field and server-side position syncing. We may need a
-- packet or raw-address approach next. For now, v0.2.3 just adds diagnostic
-- output so we can see what's actually happening in memory.
local function setHeading(idx, radians)
    entity():SetHeading(idx, radians);
end

local function getHeading(idx)
    return entity():GetHeading(idx);
end

-- Convert radians (-π to π) to the single-byte heading format FFXI uses
-- in packet 0x015. 0 = east, 64 = north, 128 = west, 192 = south.
local function radiansToHeadingByte(radians)
    local b = math.floor(((radians + math.pi) / (2 * math.pi)) * 256) % 256;
    return b;
end

-- Build and send an outgoing 0x015 standard-position packet with the chosen
-- heading. This is how Byrth's React rotates the character on Windower --
-- same idea, Ashita API. Returns ok, err_message.
local function sendTurnPacket(radians)
    local pm = AshitaCore:GetPacketManager();
    if (not pm) then return false, 'no packet manager'; end
    local si = selfIndex();
    local ent = entity();
    local x = ent:GetLocalPositionX(si) or 0;
    local y = ent:GetLocalPositionY(si) or 0;
    local z = ent:GetLocalPositionZ(si) or 0;
    local h = radiansToHeadingByte(radians);

    -- Pack to binary string, then convert to table-of-bytes which is what
    -- Ashita v4's AddOutgoingPacket actually wants.
    local payload_str;
    local pack_ok, pack_err = pcall(function()
        payload_str = struct.pack('< I4 f f f H H B B H',
            0,           -- sequence
            x, z, y,     -- position (hold current)
            0,           -- run count
            0,           -- head position
            h,           -- heading byte
            0,           -- move count
            0            -- target index
        );
    end);
    if (not pack_ok) then return false, 'struct.pack failed: '..tostring(pack_err); end
    if (not payload_str) then return false, 'payload nil after pack'; end

    -- Convert string to table of byte values
    local payload = {};
    for i = 1, #payload_str do
        payload[i] = string.byte(payload_str, i);
    end

    local ok, err = pcall(function() pm:AddOutgoingPacket(0x15, payload); end);
    if (ok) then return true, 'sent'; end
    return false, tostring(err);
end

-- Chat alert: big obvious warning so you can turn manually.
-- Uses in-game echo (/echo) via chat manager so it shows in chat line.
local function doAlert(abilityName, mobName, gazeType)
    local msg = string.format('*** %s INCOMING: %s%s - TURN AWAY ***',
        gazeType:upper(),
        abilityName,
        mobName and (' from ' .. mobName) or '');
    AshitaCore:GetChatManager():QueueCommand(1, '/echo ' .. msg);
end

local function faceAway(mobIdx, abilityName, mobName, gazeType)
    local si = selfIndex();
    local h  = computeHeading(mobIdx, si, true);
    if (not h) then return; end
    M.savedHeading = getHeading(si);
    M.savedTarget  = mobIdx;

    -- Feature 1: chat alert (always safe)
    if (M.alert and abilityName) then
        doAlert(abilityName, mobName, gazeType or 'GAZE');
    end

    -- Feature 2: packet-based auto-turn (opt-in)
    if (M.autoturn) then
        local sent, info = sendTurnPacket(h);
        if (M.debug) then
            echo(('autoturn: sent=%s  info=%s  rad=%.3f  byte=%d')
                 :format(tostring(sent), tostring(info), h, radiansToHeadingByte(h)));
        end
    end
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
    local ent = entity();
    local mobName = ent:GetName(actorIdx) or 'mob';

    -- HUD: track ALL mob abilities, not just gazes. Keyed by actor_id so a
    -- single mob chaining abilities just updates its card.
    if (M.hud) then
        if (category == 7 or category == 8) then
            M.hudCards[actorId] = {
                ability   = abilityName,
                mob       = mobName,
                startedAt = os.clock(),
                duration  = (gaze and gaze.delay) or M.telegraphDefault,
                isGaze    = gaze ~= nil,
            };
        elseif (category == 4 or category == 11) then
            M.hudCards[actorId] = nil;
        end
    end

    if (not gaze) then
        if (M.debug) then echo('(not tracked) '..abilityName); end
        return;
    end
    if (M.debug) then
        echo(('%s / %s (cat %d, %s)'):format(mobName, abilityName, category, gaze.type));
    end

    if (category == 7 or category == 8) then
        faceAway(actorIdx, abilityName, mobName, gaze.type);
    elseif (category == 4 or category == 11) then
        faceBack();
    end
end);

-- ---------------------------------------------------------------------------
-- HUD: floating-card telegraph display  (imgui, drawn on d3d_present)
-- ---------------------------------------------------------------------------
ashita.events.register('d3d_present', 'rechhar_hud', function()
    if (not M.hud) then return; end
    if (not M.enabled) then return; end

    -- Garbage-collect stale cards first
    local now = os.clock();
    for id, c in pairs(M.hudCards) do
        if (now - c.startedAt > M.cardMaxAge) then
            M.hudCards[id] = nil;
        end
    end

    -- Count how many we're drawing so we can size the window
    local count = 0;
    for _ in pairs(M.hudCards) do count = count + 1; end
    if (count == 0) then return; end

    imgui.SetNextWindowPos({ M.hudPosX, M.hudPosY }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ 320, 32 * count + 16 }, ImGuiCond_Always);
    imgui.SetNextWindowBgAlpha(0.65);
    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoFocusOnAppearing
    );
    if (imgui.Begin('reChhar HUD', nil, flags)) then
        for id, c in pairs(M.hudCards) do
            local elapsed = now - c.startedAt;
            local progress = math.max(0, math.min(1, 1 - (elapsed / c.duration)));
            local label = string.format('%s: %s  (%.1fs)', c.mob, c.ability, c.duration - elapsed);
            -- Color: red for known gazes, yellow/white for other abilities
            if (c.isGaze) then
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.3, 0.3, 1.0 });
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.2, 0.2, 1.0 });
            else
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 0.6, 1.0 });
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { 1.0, 0.9, 0.3, 1.0 });
            end
            imgui.Text(label);
            imgui.ProgressBar(progress, { 300, 6 }, '');
            imgui.PopStyleColor(2);
        end
    end
    imgui.End();
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
        echo(('ENABLED  (alert=%s  autoturn=%s)')
             :format(M.alert and 'on' or 'off', M.autoturn and 'on' or 'off'));
    elseif (cmd == 'off') then
        M.enabled = false; cfg.enabled = false; settings.save(cfg);
        echo('DISABLED');
    elseif (cmd == 'alert') then
        if (val == 'on' or val == 'off') then
            M.alert = (val == 'on'); cfg.alert = M.alert; settings.save(cfg);
        end
        echo('alert = '..(M.alert and 'ON' or 'OFF'));
    elseif (cmd == 'autoturn') then
        if (val == 'on' or val == 'off') then
            M.autoturn = (val == 'on'); cfg.autoturn = M.autoturn; settings.save(cfg);
        end
        echo('autoturn = '..(M.autoturn and 'ON' or 'OFF'));
    elseif (cmd == 'hud') then
        if (val == 'on' or val == 'off') then
            M.hud = (val == 'on'); cfg.hud = M.hud; settings.save(cfg);
        end
        echo('hud = '..(M.hud and 'ON' or 'OFF'));
    elseif (cmd == 'hudpos') then
        -- /rechhar hudpos <x> <y>
        local x = tonumber(args[3]);
        local y = tonumber(args[4]);
        if (x and y) then
            M.hudPosX = x; M.hudPosY = y;
            cfg.hudPosX = x; cfg.hudPosY = y; settings.save(cfg);
            echo(('hud position set to %d,%d'):format(x, y));
        else
            echo(('hud position: %d,%d  (usage: /rechhar hudpos <x> <y>)')
                 :format(M.hudPosX, M.hudPosY));
        end
    elseif (cmd == 'hudtest') then
        -- Inject a fake card to see the HUD without needing a real mob
        if (not M.hud) then M.hud = true; echo('HUD force-enabled for test'); end
        local t = AshitaCore:GetMemoryManager():GetTarget();
        local tidx = t:GetTargetIndex(0);
        local actorId = (tidx and tidx ~= 0) and entity():GetServerId(tidx) or 999999;
        local mobName = (tidx and tidx ~= 0) and entity():GetName(tidx) or 'TestMob';
        M.hudCards[actorId] = {
            ability = 'Petrifying Eye', mob = mobName,
            startedAt = os.clock(), duration = 3.0, isGaze = true,
        };
        echo('injected test card for 3 sec');
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
        -- Fires both alert + autoturn (if enabled) as if a gaze happened.
        local t = AshitaCore:GetMemoryManager():GetTarget();
        local tidx = t:GetTargetIndex(0);
        if (tidx and tidx ~= 0) then
            local ent = entity();
            local mobName = ent:GetName(tidx) or 'target';
            echo('testing react on current target...');
            faceAway(tidx, 'Test Gaze', mobName, 'gaze');
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
        print('  /rechhar alert on|off     -- chat warning on gaze detect');
        print('  /rechhar autoturn on|off  -- packet 0x015 auto-rotate (experimental)');
        print('  /rechhar hud on|off       -- floating-card telegraph HUD');
        print('  /rechhar hudpos <x> <y>   -- move the HUD');
        print('  /rechhar hudtest          -- inject a mock card');
        print('  /rechhar test             -- fire a mock gaze on current target');
        print('  /rechhar debug            -- toggle verbose logging');
    end
end);

return M;
