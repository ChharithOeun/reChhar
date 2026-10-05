--[[
================================================================================
  settings.lua - persistent config for reChhar
  Stored as <addon>/data/rechhar_settings.lua on disk.
================================================================================
]]--

local M = {};

local defaults = {
    enabled      = false,       -- master toggle; default off
    era          = 'toau',
    customGazes  = {},          -- user-added ability names
    autoFaceBack = true,        -- restore heading after resolve
    minDistance  = 0.0,         -- only react within this range (0 = always)
    maxDistance  = 30.0,        -- gaze range cap on most mobs
};

local function settingsFile()
    return AshitaCore:GetInstallPath() .. 'config/addons/rechhar/settings.lua';
end

function M.load()
    local path = settingsFile();
    local ok, cfg = pcall(dofile, path);
    if (ok and type(cfg) == 'table') then
        -- Merge defaults for any new keys
        for k, v in pairs(defaults) do
            if (cfg[k] == nil) then cfg[k] = v; end
        end
        return cfg;
    end
    -- First run or corrupt file: fall back to defaults
    return setmetatable({}, { __index = defaults });
end

function M.save(cfg)
    local path = settingsFile();
    -- Ensure directory exists
    local dir = path:match('(.*/)');
    if (dir and not ashita.fs.exists(dir)) then
        ashita.fs.create_directory(dir);
    end
    local f = io.open(path, 'w');
    if (not f) then
        print('[reChhar] WARN: could not save settings to '..path);
        return;
    end
    f:write('return {\n');
    for k, v in pairs(cfg) do
        if (type(v) == 'boolean' or type(v) == 'number') then
            f:write(('  %s = %s,\n'):format(k, tostring(v)));
        elseif (type(v) == 'string') then
            f:write(('  %s = %q,\n'):format(k, v));
        elseif (type(v) == 'table') then
            f:write(('  %s = {\n'):format(k));
            for _, item in ipairs(v) do f:write(('    %q,\n'):format(item)); end
            f:write('  },\n');
        end
    end
    f:write('};\n');
    f:close();
end

return M;
