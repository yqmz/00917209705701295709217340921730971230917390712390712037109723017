-- libraryloader.lua
-- Loads the correct game loader for the current game/place ID.
-- This is the repo-side bootstrap loader.

local LibraryLoader = {}
LibraryLoader.__index = LibraryLoader

local RIVALS_PLACE_IDS = {
    [17625359962] = true,
    [18126510175] = true,
    [71874690745115] = true,
    [117398147513099] = true,
    [129604661913557] = true,
    [133215910299950] = true,
}

-- Update this to your actual repo base.
local REPO_BASE = "https://raw.githubusercontent.com/yqmz/00917209705701295709217340921730971230917390712390712037109723017/main/"

function LibraryLoader.new()
    return setmetatable({}, LibraryLoader)
end

local function fetch(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        return nil, result
    end

    return result, nil
end

local function isTableKey(tbl, key)
    for k in pairs(tbl) do
        if k == key then
            return true
        end
    end
    return false
end

function LibraryLoader:GetGameForPlace(placeId)
    placeId = tonumber(placeId)
    if not placeId then
        return nil
    end

    if isTableKey(RIVALS_PLACE_IDS, placeId) then
        return {
            name = "rivals",
            script = "Downloads/game library/rivals/gameloader.lua",
        }
    end

    return nil
end

function LibraryLoader:LoadGameByPlace(placeId)
    local info = self:GetGameForPlace(placeId)
    if not info then
        warn("No library loader registered for PlaceId " .. tostring(placeId))
        return nil
    end

    local url = REPO_BASE .. info.script
    local source, err = fetch(url)
    if not source then
        warn("Failed to fetch game loader for " .. info.name .. ": " .. tostring(err))
        return nil
    end

    local chunk, compErr = loadstring(source)
    if not chunk then
        warn("Failed to compile game loader for " .. info.name .. ": " .. tostring(compErr))
        return nil
    end

    local ok, result = pcall(chunk)
    if not ok then
        warn("Failed to run game loader for " .. info.name .. ": " .. tostring(result))
        return nil
    end

    if result and type(result) == "table" and type(result.Start) == "function" then
        result:Start()
        return result
    elseif type(result) == "function" then
        result()
        return result
    end

    return result
end

function LibraryLoader:LoadCurrentGame()
    return self:LoadGameByPlace(game.PlaceId)
end

-- Auto-run when the script is executed directly via loadstring(game:HttpGet(...))()
local loader = LibraryLoader.new()
local detected = loader:GetGameForPlace(game.PlaceId)
if detected then
    print("[LibraryLoader] Detected game:", detected.name, "PlaceId:", game.PlaceId)
    loader:LoadCurrentGame()
else
    print("[LibraryLoader] No registered game loader for PlaceId:", tostring(game.PlaceId))
end

return LibraryLoader
