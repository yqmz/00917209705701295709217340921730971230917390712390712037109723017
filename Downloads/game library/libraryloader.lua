-- ModuleScript: GameRepoLoader
-- Maps a Roblox PlaceId to a GitHub repo and loads that repo info into a slot.

local GameRepoLoader = {}
GameRepoLoader.__index = GameRepoLoader

local function isValidPlaceId(value)
    return type(value) == "number"
        and value > 0
        and math.floor(value) == value
end

local function normalizeGameName(gameName)
    if type(gameName) ~= "string" then
        return ""
    end
    return string.lower(gameName)
end

GameRepoLoader.GameRepos = {
    -- Replace these with your real Roblox PlaceIds + GitHub repo URLs.
    fortnite = { PlaceId = 123456789, Repo = "https://github.com/fortnite/fortnite" },
    roblox = { PlaceId = 1962086868, Repo = "https://github.com/Roblox/roblox" },
    minecraft = { PlaceId = 100000000, Repo = "https://github.com/MinecraftForge/MinecraftForge" },
    valorant = { PlaceId = 200000000, Repo = "https://github.com/riotgames/valorant-game" },
    csgo = { PlaceId = 300000000, Repo = "https://github.com/ValveSoftware/csgo" },
    rust = { PlaceId = 400000000, Repo = "https://github.com/facepunch/Rust" },
}

function GameRepoLoader.new(slotCount)
    local self = setmetatable({}, GameRepoLoader)
    self.SlotCount = slotCount or 100
    self.Slots = {}

    for i = 1, self.SlotCount do
        self.Slots[i] = {
            SlotId = i,
            Game = "EMPTY",
            PlaceId = 0,
            Repo = "",
            Loaded = false,
        }
    end

    return self
end

function GameRepoLoader:RegisterGame(gameName, placeId, repoURL)
    self.GameRepos[normalizeGameName(gameName)] = {
        PlaceId = tonumber(placeId) or 0,
        Repo = repoURL or "",
    }
end

function GameRepoLoader:GetRepoByPlaceId(placeId)
    local id = tonumber(placeId)
    if not isValidPlaceId(id) then
        return nil
    end

    for gameName, config in pairs(self.GameRepos) do
        if tonumber(config.PlaceId) == id then
            return gameName, config.Repo
        end
    end

    return nil
end

function GameRepoLoader:GetRepoByGameName(gameName)
    local key = normalizeGameName(gameName)
    local config = self.GameRepos[key]
    if not config then
        return nil
    end
    return config.Repo
end

function GameRepoLoader:FindAvailableSlot()
    for i = 1, self.SlotCount do
        if not self.Slots[i].Loaded then
            return i
        end
    end

    error("All " .. self.SlotCount .. " slots are full.", 2)
end

function GameRepoLoader:CreateRepoScript(gameName, repoURL, parent)
    local script = Instance.new("Script")
    script.Name = "GitRepoLoader_" .. tostring(gameName)
    script.Source = [[
        local gameName = "]] .. tostring(gameName) .. [["
        local repoURL = "]] .. tostring(repoURL) .. [["
        print("Game:", gameName)
        print("GitHub Repo:", repoURL)
    ]]
    script.Parent = parent
    return script
end

function GameRepoLoader:LoadByPlaceId(placeId, slotId)
    local id = tonumber(placeId)
    if not isValidPlaceId(id) then
        error("'" .. tostring(placeId) .. "' is not a valid Roblox PlaceId.", 2)
    end

    local targetSlot = slotId or self:FindAvailableSlot()
    if targetSlot < 1 or targetSlot > self.SlotCount then
        error("Slot " .. tostring(targetSlot) .. " is out of range. Use 1-" .. self.SlotCount .. ".", 2)
    end

    local slot = self.Slots[targetSlot]
    if slot.Loaded then
        error("Slot " .. targetSlot .. " is already occupied by " .. slot.Game, 2)
    end

    local gameName, repoURL = self:GetRepoByPlaceId(id)
    if not gameName or not repoURL then
        error("No GitHub repo configured for PlaceId " .. tostring(id), 2)
    end

    local root = Instance.new("Folder")
    root.Name = "GameRepo_" .. tostring(gameName)
    root.Parent = workspace

    self:CreateRepoScript(gameName, repoURL, root)

    slot.Game = gameName
    slot.PlaceId = id
    slot.Repo = repoURL
    slot.Loaded = true

    return slot
end

function GameRepoLoader:LoadGameByPlaceId(placeId, slotId)
    return self:LoadByPlaceId(placeId, slotId)
end

function GameRepoLoader:LoadGameByName(gameName, slotId)
    local key = normalizeGameName(gameName)
    local config = self.GameRepos[key]
    if not config then
        error("No repo configured for game '" .. tostring(gameName) .. "'", 2)
    end
    return self:LoadByPlaceId(config.PlaceId, slotId)
end

function GameRepoLoader:UnloadSlot(slotId)
    if slotId < 1 or slotId > self.SlotCount then
        error("Slot " .. tostring(slotId) .. " is out of range. Use 1-" .. self.SlotCount .. ".", 2)
    end

    self.Slots[slotId] = {
        SlotId = slotId,
        Game = "EMPTY",
        PlaceId = 0,
        Repo = "",
        Loaded = false,
    }
end

function GameRepoLoader:ListSlots()
    local list = {}
    for i = 1, self.SlotCount do
        table.insert(list, {
            SlotId = self.Slots[i].SlotId,
            Game = self.Slots[i].Game,
            PlaceId = self.Slots[i].PlaceId,
            Repo = self.Slots[i].Repo,
            Loaded = self.Slots[i].Loaded,
        })
    end
    return list
end

return GameRepoLoader
