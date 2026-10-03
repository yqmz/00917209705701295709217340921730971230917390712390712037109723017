-- gameloader.lua
-- executor-friendly bootstrap loader for a single rivals script
-- only loads rivals1.lua right now since that is the script we verified exists

local repoBase = "https://raw.githubusercontent.com/yqmz/00917209705701295709217340921730971230917390712390712037109723017/main/Downloads/game%20library/rivals/"

local scripts = {
    { name = "Script 1", file = "rivals1.lua" },
    { name = "Script 2", file = "rivals2.lua" },
    { name = "Script 3", file = "rivals3.lua" },
    { name = "Script 4", file = "rivals4.lua" },
    { name = "Script 5", file = "rivals5.lua" },
    { name = "Script 6", file = "rivals6.lua" },
    { name = "Script 7", file = "rivals7.lua" },
    { name = "Script 8", file = "rivals8.lua" },
    { name = "Script 9", file = "rivals9.lua" },
    { name = "Script 10", file = "rivals10.lua" },
    { name = "Script 11", file = "rivals11.lua" },
    { name = "Script 12 (paid)", file = "rivals12.lua" },
}

local function fetch(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        return nil, result
    end

    return result, nil
end

local function loadRemoteScript(fileName)
    local url = repoBase .. fileName
    local source, err = fetch(url)
    if not source then
        error("Failed to fetch " .. fileName .. ": " .. tostring(err))
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("Failed to compile " .. fileName .. ": " .. tostring(compileErr))
    end

    return chunk
end

local function runScript(fileName)
    local chunk, loadErr = pcall(loadRemoteScript, fileName)
    if not chunk then
        warn("Failed to load " .. fileName .. ": " .. tostring(loadErr))
        return
    end

    local success, result = pcall(chunk)
    if not success then
        warn("Failed to run " .. fileName .. ": " .. tostring(result))
        return
    end

    local resultType = type(result)

    if resultType == "function" then
        result()
        return
    end

    if resultType == "table" then
        if type(result.Start) == "function" then
            result:Start()
            return
        elseif type(result.Run) == "function" then
            result:Run()
            return
        elseif type(result.Init) == "function" then
            result:Init()
            return
        end
    end

    -- Some Rivals scripts are self-running and return nil/boolean/string/number
    -- after executing. In that case, no extra call should be made.
end

local function createGui()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("RivalsLoader")
    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RivalsLoader"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 320)
    frame.Position = UDim2.new(0.5, -130, 0.5, -160)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundTransparency = 1
    title.Text = "Rivals Loader"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame

    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Size = UDim2.new(1, -20, 1, -42)
    scrolling.Position = UDim2.new(0, 10, 0, 32)
    scrolling.BackgroundTransparency = 1
    scrolling.BorderSizePixel = 0
    scrolling.ScrollBarThickness = 6
    scrolling.CanvasSize = UDim2.new(0, 0, 0, (#scripts * 38))
    scrolling.Parent = frame

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.Parent = scrolling

    for _, scriptInfo in ipairs(scripts) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -4, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
        btn.BorderSizePixel = 0
        btn.Text = scriptInfo.name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 15
        btn.Parent = scrolling

        btn.MouseButton1Click:Connect(function()
            runScript(scriptInfo.file)
            screenGui:Destroy()
        end)
    end
end

createGui()