-- gameloader.lua
-- Arsenal script selector
-- buttons use the file name before .lua as the label

local repoBase = "https://raw.githubusercontent.com/yqmz/00917209705701295709217340921730971230917390712390712037109723017/main/Downloads/game%20library/arsenal/"

local scripts = {
    { file = "azure.lua" },
    { file = "lighthub.lua", tag = "(paid)" },
    { file = "lithium.lua" },
    { file = "main33.lua" },
    { file = "titanic.lua" },
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

    if result and type(result) == "table" then
        if type(result.Start) == "function" then
            result:Start()
        elseif type(result.Run) == "function" then
            result:Run()
        end
    elseif type(result) == "function" then
        result()
    end
end

local function createGui()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("ArsenalLoader")
    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ArsenalLoader"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 280)
    frame.Position = UDim2.new(0.5, -130, 0.5, -140)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundTransparency = 1
    title.Text = "Arsenal Scripts"
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
        local text = scriptInfo.file:match("^(.-)%.lua$") or scriptInfo.file
        if scriptInfo.tag then
            text = text .. " " .. scriptInfo.tag
        end

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -4, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
        btn.BorderSizePixel = 0
        btn.Text = text
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
