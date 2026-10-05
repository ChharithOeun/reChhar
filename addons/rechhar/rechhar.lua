--[[
================================================================================
  reChhar - Ashita port of React (Byrth's Windower addon)
  v0.1.0-scaffold

  WHAT THIS IS: an addon that auto-faces your character AWAY when a mob begins
  a gaze/eye attack, then faces back when the action resolves.

  WHAT THIS IS NOT (yet): working code. This file is the scaffold -- commands
  are wired, events are hooked, config loads correctly, but the actual
  "turn away" packet injection is marked TODO until the base React source
  is studied for reference.

  COPYING:
    * Base concept, structure, ability database: React by Byrth (Windower)
    * Ashita port: ChharithOeun
    * MIT license
================================================================================
]]--

addon.name    = 'reChhar';
addon.author  = 'ChharithOeun';
addon.version = '0.1.0-scaffold';
addon.desc    = 'Ashita port of React: auto-face-away during gaze attacks';

require('common');
local gazes    = require('data.gazes');
local settings = require('data.settings');

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
local M = {
    enabled      = false,     -- master toggle; defaults off
    era          = 'toau',    -- toau | wotg | retail
    activeGazes  = {},        -- table of mob IDs currently casting a gaze on us
    savedHeading = nil,       -- heading before we turned away, so we can restore
    config       = settings.load(),
};

-- ---------------------------------------------------------------------------
-- Load / Unload
-- ---------------------------------------------------------------------------
ashita.events.register('load', 'rechhar_load', function()
    print(('[reChhar] v%s loaded. /rechhar on to enable.'):format(addon.version));
end);

ashita.events.register('unload', 'rechhar_unload', function()
    settings.save(M.config);
end);

-- ---------------------------------------------------------------------------
-- Command handler
-- ---------------------------------------------------------------------------
ashita.events.register('command', 'rechhar_command', function(e)
    local args = e.command:args();
    if (#args == 0 or args[1]:lower() ~= '/rechhar') then return; end
    e.blocked = true;

    local cmd = (args[2] or ''):lower();
    local val = (args[3] or ''):lower();

    if (cmd == 'on') then
        M.enabled = true;
        print('[reChhar] ENABLED');

    elseif (cmd == 'off') then
        M.enabled = false;
        print('[reChhar] DISABLED');

    elseif (cmd == 'era') then
        if (val == 'toau' or val == 'wotg' or val == 'retail') then
            M.era = val;
            print(('[reChhar] Era set to %s (%d gaze abilities loaded)')
                  :format(val, gazes.countFor(val)));
        else
            print(('[reChhar] Current era: %s. Options: toau, wotg, retail'):format(M.era));
        end

    elseif (cmd == 'list') then
        print(('[reChhar] Era: %s'):format(M.era));
        for name, info in pairs(gazes.listFor(M.era)) do
            print(('  - %-25s  (%s, telegraph %.1fs)'):format(name, info.type, info.delay));
        end

    elseif (cmd == 'add') then
        local name = args[3] and e.command:match('/rechhar add%s+"?(.-)"?%s*$') or nil;
        if (name) then
            M.config.customGazes = M.config.customGazes or {};
            table.insert(M.config.customGazes, name);
            settings.save(M.config);
            print(('[reChhar] Added "%s" to custom gaze list'):format(name));
        end

    elseif (cmd == 'remove') then
        local name = args[3] and e.command:match('/rechhar remove%s+"?(.-)"?%s*$') or nil;
        if (name and M.config.customGazes) then
            for i, v in ipairs(M.config.customGazes) do
                if (v == name) then
                    table.remove(M.config.customGazes, i);
                    settings.save(M.config);
                    print(('[reChhar] Removed "%s" from custom gaze list'):format(name));
                    return;
                end
            end
        end

    elseif (cmd == 'debug') then
        print(('[reChhar DEBUG] enabled=%s  era=%s  active=%d  saved heading=%s')
              :format(tostring(M.enabled), M.era, #M.activeGazes,
                      tostring(M.savedHeading)));

    else
        print('[reChhar] Commands:');
        print('  /rechhar on | off');
        print('  /rechhar era <toau|wotg|retail>');
        print('  /rechhar list');
        print('  /rechhar add "Ability Name"');
        print('  /rechhar remove "Ability Name"');
        print('  /rechhar debug');
    end
end);

-- ---------------------------------------------------------------------------
-- Incoming-action hook  (0x028 packet - the mob started a move)
-- ---------------------------------------------------------------------------
-- TODO: parse packet 0x028, identify category 11 (ability) or 4 (spell),
--       look up action ID in gazes database, if matched then schedule
--       face-away at telegraph delay, and face-back after resolution.
ashita.events.register('packet_in', 'rechhar_packet_in', function(e)
    if (not M.enabled) then return; end
    if (e.id ~= 0x028) then return; end

    -- Placeholder: real parsing goes here once we study the React source.
    -- Pseudocode:
    --   local actor_id, target_id, category, action_id = parse028(e.data);
    --   if (target_id == my_server_id) then
    --       local gaze = gazes.lookupById(action_id, M.era);
    --       if (gaze) then handleIncomingGaze(actor_id, gaze); end
    --   end
end);

-- ---------------------------------------------------------------------------
-- Facing control (TODO: real implementation)
-- ---------------------------------------------------------------------------
local function faceAway(from_entity_id)
    -- TODO: write to 0x05B keyboard/mouse facing packet, OR directly set
    -- the player's heading in memory. React does this via a specific client
    -- packet; need to look at the source for the exact bytes.
    print(('[reChhar] (stub) would face away from entity %d'):format(from_entity_id));
end

local function faceBack()
    if (M.savedHeading) then
        -- TODO: restore heading
        print('[reChhar] (stub) would face back to saved heading');
        M.savedHeading = nil;
    end
end

-- Expose for other scripts (and testing)
return M;
