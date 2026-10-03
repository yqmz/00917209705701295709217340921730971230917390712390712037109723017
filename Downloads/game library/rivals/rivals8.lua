if getgenv().kitty_loaded then return end
getgenv().kitty_loaded = true

local function dl(url) return game:HttpGet(url) end
-- [[ ANTICHEAT BYPASS (from meowlua_private.lua) ]]
do
 local _executor_name = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or ""
 _executor_name = tostring(_executor_name):lower()
 local _blacklist = {
  { id = "xeno",      label = "Xeno" },
  { id = "wave",      label = "Wave" },
  { id = "solara",    label = "Solara" },
  { id = "arceus x",  label = "Arceus X" },
  { id = "codex",     label = "Codex" },
  { id = "jjsploit",  label = "JJSploit" },
 }
 for _, entry in ipairs(_blacklist) do
  if _executor_name:find(entry.id, 1, true) then
   local _players = game:GetService("Players")
   local _lp = _players.LocalPlayer
   if _lp then
    _lp:Kick(entry.label .. " isn't supported.")
   end
   return
  end
 end
end

task.spawn(function()
    local bypassed = false

    local kKickNames = {
        "Kick",
        "kick"
    }

    local kProtectedProperties = {
        Enabled = true,
        Disabled = false
    }

    local kSlotMap = {
        [69]  = 2,
        [138] = 3,
        [207] = 4,
        [276] = 5,
        [345] = 6,
        [414] = 7,
    }

    local kFilledSub = {
        1,
        2,
        3,
        4,
        5
    }

    local Players = cloneref(game:GetService("Players"))
    local ReplicatedFirst = cloneref(game:GetService("ReplicatedFirst"))
    local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
    local ScriptContext = cloneref(game:GetService("ScriptContext"))

    local LocalPlayer = Players.LocalPlayer

    local ac_script = ReplicatedFirst:WaitForChild("LocalScript3")
    local ac_event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteEvent")

    local last = nil
    local first_seen = false
    local hijack_ready = false
    local client_id
    local expected_interval = 0.6
    local min_interval = 0.25
    local ema_alpha = 0.5
    local samples = 0
    local hidden_fn = {}
    local max_stack_depth = 128
    if not setstackhidden then
        local function ValidTraceback(s)
            local dotPos = string.find(s, "%.")
            local colonPos = string.find(s, ":")

            if not dotPos then
                return false
            end

            if not colonPos then
                return true
            end

            return dotPos < colonPos
        end

        local function TracebackLines(str, lvl)
            local pos = lvl
            return function()
                if not pos then
                    return nil
                end
                local p1, p2 = string.find(str, "\r?\n", pos)
                local line
                if p1 then
                    line = str:sub(pos, p1 - 1)
                    pos = p2 + 1
                else
                    line = str:sub(pos)
                    pos = nil
                end
                return line
            end
        end

        local old_dbg_traceback;
        old_dbg_traceback = hookfunction(getrenv().debug.traceback, function(...)
            if checkcaller() or not (pcall(old_dbg_traceback, ...)) then
                return old_dbg_traceback(...)
            end

            local StartingString, StackLevel = ...
            local Traceback = old_dbg_traceback(...)
            local NewTraceback = {}

            if typeof(StartingString) == "string" or typeof(StartingString) == "number" then
                table.insert(NewTraceback, tostring(StartingString))
            end

            if typeof(StackLevel) ~= "number" or not tonumber(StackLevel) then
                StackLevel = 1
            else
                StackLevel = math.floor(tonumber(StackLevel))
            end

            for Line in TracebackLines(Traceback, StackLevel) do
                if not ValidTraceback(Line) then
                    continue
                end

                table.insert(NewTraceback, Line)
            end

            return table.concat(NewTraceback, "\n") .. "\n"
        end)

        local old_dbg_info;
        old_dbg_info = hookfunction(getrenv().debug.info, function(...)
            local ToInspect, LevelOrInfo, _ThreadInfo = ...

            if
                checkcaller()
                or typeof(ToInspect) == "function"
                or typeof(ToInspect) == "thread"
                or not pcall(function(LevelOrInfo)
                    old_dbg_info(function() end, LevelOrInfo)
                end, LevelOrInfo)
            then
                return old_dbg_info(...)
            end

            ToInspect = math.floor(ToInspect)

            local ReconstructedConstructedStack = {}
            for Level = 2, max_stack_depth do
                local Function, Source, Line, Name, NumberOfArgs, Varargs = old_dbg_info(Level, "fslna")

                if not Function or not Source or not Line or not Name then
                    break
                end

                if isexecutorclosure(Function) and not hidden_fn[Function] then
                    continue
                end

                table.insert(ReconstructedConstructedStack, {
                    f = Function,
                    s = Source,
                    l = Line,
                    n = Name,
                    a = { NumberOfArgs, Varargs },
                })
            end

            local InfoLevel = ReconstructedConstructedStack[ToInspect + 1]

            if not InfoLevel then
                return old_dbg_info(3e4, LevelOrInfo)
            end

            local ReturnResult = {}
            for idx, info in string.split(LevelOrInfo, "") do
                local Value = InfoLevel[info]

                if typeof(Value) == "table" then
                    for _, v in Value do
                        table.insert(ReturnResult, v)
                    end

                    continue
                end

                table.insert(ReturnResult, Value)
            end

            return table.unpack(ReturnResult, 1, #ReturnResult)
        end)

        local old_getfenv;
        old_getfenv = hookfunction(getrenv().getfenv, function(...)
            if checkcaller() then
                return old_getfenv(...)
            end

            local ToInspect: (...any) -> (...any) | number = ...

            local Success, ResultingEnv = pcall(function()
                if typeof(ToInspect) == "number" and ToInspect >= 0 then
                    return old_getfenv(ToInspect + 3)
                end

                return old_getfenv(ToInspect)
            end)

            if not Success then
                if typeof(ToInspect) == "number" and ToInspect >= 0 then
                    return old_getfenv(ToInspect + 3)
                end

                return old_getfenv(ToInspect)
            end

            if ToInspect == nil or typeof(ToInspect) == "function" then
                return ResultingEnv
            end

            ToInspect = math.floor(ToInspect)

            local ReconstructedConstructedStack = {}
            for Level = 1, max_stack_depth do
                local StackInfoSuccess, Data = pcall(function()
                    return {
                        Environement = old_getfenv(Level + 3),
                        Function = old_dbg_info(Level + 3, "f"),
                    }
                end)

                if not StackInfoSuccess or not Data then
                    break
                end

                local Environement = Data.Environement
                local Function = Data.Function

                if typeof(Environement["getgenv"]) == "function" and isexecutorclosure(Environement["getgenv"]) then
                    if shared.Hooking.IncludeInStackFunctions[Function] then
                        Environement = setmetatable(ResultingEnv, {
                            __index = getrenv()
                        })
                    else
                        continue
                    end
                end

                table.insert(ReconstructedConstructedStack, Environement)
            end

            local InfoLevel = ReconstructedConstructedStack[ToInspect + 1]

            if not InfoLevel then
                return old_getfenv(3e4)
            end

            return InfoLevel
        end)
    end

    setstackhidden = setstackhidden or function(fn_or_level, hidden)
        assert(typeof(hidden) == "boolean", "hidden must be boolean")

        local ok, fn = pcall(function()
            if typeof(fn_or_level) == "number" then
                return debug.info(fn_or_level + 2, "f")
            end
            return fn_or_level
        end)

        assert(ok and fn, "invalid argument #1 to 'setstackhidden'")
        hidden_fn[fn] = not hidden
    end

    local TrustedFunctions = setmetatable({}, {
        __mode = "k"
    })

    local function TrustFunction(fn)
        if type(fn) == "function" then
            TrustedFunctions[fn] = true
        end

        return fn
    end

    local function IsTrustedFunction(fn)
        return TrustedFunctions[fn] == true
    end

    local SafeHook = function(hookfn, ...)
        local args = {...}
        local func, inst, metamethod, detour

        if hookfn == hookmetamethod then
            inst = args[1]
            metamethod = args[2]
            detour = args[3]
        else
            func = args[1]
            detour = args[2]
        end

        local original_func

        if hookfn == hookfunction and iscclosure(func) then
            detour = newcclosure(detour)
        end

        if not iscclosure(detour) then
            detour = newcclosure(detour)
        end

        setstackhidden(detour, true)

        local ok, _ = pcall(function()
            TrustFunction(detour)
                    
            if hookfn == hookmetamethod then
                original_func = hookfn(inst, metamethod, detour)
            else
                original_func = hookfn(func, detour)
            end
        end)

        if not ok then
            LocalPlayer:Kick("[AethSec]: Bypass failed! n1")
        end

        return original_func
    end

    local SafeCall = function(func, ...)
        if checkcaller() then
            return func(...)
        end

        local old = getthreadidentity()
        if old ~= 2 then
            setthreadidentity(2)
        end

        local result = {func(...)}

        if old ~= 2 then
            setthreadidentity(old)
        end

        return table.unpack(result)
    end

    local monitor_conn = ScriptContext.Error:Connect(TrustFunction(function(message, stack, _)
        message = tostring(message)
        stack = tostring(stack)
        if stack:find("PlayerScripts.Controllers.MiscellaneousController") and message:find("attempt to index number with number") then
            LocalPlayer:Kick("[AethSec]: Bypass failed! n2")
        end
    end))

    local oldindex; oldindex = SafeHook(hookmetamethod, ac_script, "__index", function(t, k)
        local is_caller = not bypassed and checkcaller()
        if t == ac_script and not is_caller and kProtectedProperties[k] ~= nil then
            return kProtectedProperties[k]
        end
        if checkcaller() then
            return oldindex(t, k)
        end
        return SafeCall(oldindex, t, k)
    end)

    local oldnewindex; oldnewindex = SafeHook(hookmetamethod, ac_script, "__newindex", function(t, k, v)
        local is_caller = not bypassed and checkcaller()
        if t == ac_script and not is_caller and kProtectedProperties[k] ~= nil then
            kProtectedProperties[k] = v
            if k == "Enabled" then
                kProtectedProperties["Disabled"] = not v
            end

            if k == "Disabled" then
                kProtectedProperties["Enabled"] = not v
            end
            return
        end
        if checkcaller() then
            return oldnewindex(t, k, v)
        end
        return SafeCall(oldnewindex, t, k, v)
    end)

    client_id = ""
    last = tick()

    local oldfireserver; oldfireserver = SafeHook(hookfunction, ac_event.FireServer, function(self, ...)
        local now = tick()
        local args = {...}

        if not first_seen then
            first_seen = true
            local first_arg = args[1]

            if type(first_arg) == "table" and #first_arg >= 1 and (type(first_arg[1]) == "string" or type(first_arg[1]) == "number") then
                client_id = tostring(first_arg[1])
            else
                client_id = client_id or ""
            end

            last = tick()
            samples = 1
            hijack_ready = true

            local res = SafeCall(oldfireserver, self, ...)
            return res
        end

        local interval = now - (last or now)

        if interval > 0 then
            if samples == 0 then
                expected_interval = interval
            else
                expected_interval = ema_alpha * interval + (1 - ema_alpha) * expected_interval
            end

            samples = samples + 1

            if expected_interval < min_interval then
                expected_interval = min_interval
            end
        end

        local res = SafeCall(oldfireserver, self, ...)
        last = tick()

        return res
    end)

    local BuildSubTable = function()
        local num_empty = math.random(1, 5)
        local empty_map = {}
        local empty_slots = {7}
        empty_map[7] = true

        while #empty_slots < num_empty do
            local slot = math.random(1, 6)
            if not empty_map[slot] then
                empty_map[slot] = true
                table.insert(empty_slots, slot)
            end
        end

        table.sort(empty_slots)

        local result = {}
        for i = 1, 7 do
            if empty_map[i] then
                result[i] = {}
            else
                result[i] = kFilledSub
            end
        end

        return result, empty_slots
    end

    local ApplyTransforms = function(t, mask, empty_slots)
        local payload = t[1]
        local outer_index = #payload
        local inner_index = empty_slots[math.random(1, #empty_slots)]
        local derived
        local outer_val = payload[outer_index]

        if type(outer_val) == "table" and type(inner_index) == "number" then
            derived = outer_val[inner_index]
        else
            for i = outer_index, 1, -1 do
                if type(payload[i]) ~= "table" then
                    continue
                end

                local candidate = payload[i]

                if type(inner_index) == "number" and candidate[inner_index] ~= nil then
                    derived = candidate[inner_index]
                    break
                else
                    derived = candidate
                    break
                end
            end

            if derived == nil then
                derived = {}
            end
        end

        local written = {}
        local kSlotMapRef = kSlotMap

        for _, value in ipairs(mask) do
            local slot = kSlotMapRef[value]
            if slot and not written[slot] then
                t[slot] = derived
                written[slot] = true
            end
        end

        return t
    end

    local BuildPayload = function(challenge, mask)
        local sub_table, empty_slots = BuildSubTable()
        local total_idx = math.random(1, 8)
        local payload = {client_id, buffer.tostring(challenge)}
        local extra_strings = math.random(0, 2)

        for _ = 1, extra_strings do
            payload[#payload + 1] = ""
        end

        while #payload < (total_idx - 1) do
            payload[#payload + 1] = math.random(5, 100000)
        end

        payload[#payload + 1] = sub_table

        local t = {
            payload,
            {},
            nil,
            nil,
            nil,
            nil,
            nil
        }
        return ApplyTransforms(t, mask, empty_slots)
    end

    task.spawn(function()
        getfenv().script = ac_script
        while not hijack_ready do
            task.wait()
        end

        ac_script.Enabled = false

        ac_event.OnClientEvent:Connect(function(...)
            last = tick()

            local remote = Instance.new("RemoteEvent", nil)
            remote:FireServer()

            local t = {...}
            local challenge = t[1]
            local index = t[2]
            local mask = t[3]

            if typeof(challenge) ~= "buffer" or type(index) ~= "number" or type(mask) ~= "table" then
                LocalPlayer:Kick("[AethSec]: Bypass failed! n3")
            end

            local payload = BuildPayload(challenge, mask)
            task.defer(function()
                local since_last = tick() - (last or 0)
                local desired_wait = expected_interval - since_last
                
                if desired_wait > 0 then
                    task.wait(desired_wait)
                end
                ac_event:FireServer(table.unpack(payload, 1, 5))
                last = tick()
                remote:Destroy()
            end)
        end)
            
        bypassed = true
        monitor_conn:Disconnect()
    end)

    for _, name in ipairs(kKickNames) do
        local func = LocalPlayer[name]
        if type(func) ~= "function" then return end
            
        local oldfunc; oldfunc = SafeHook(hookfunction, func, function(self, ...)
            if self == LocalPlayer and not checkcaller() then
                return nil
            end
            return oldfunc(self, ...)
        end)
    end

    for _, conn in ipairs(getconnections(ScriptContext.Error)) do
        if not conn.Function then continue end
        if IsTrustedFunction(conn.Function) then continue end
        SafeHook(hookfunction, conn.Function, function(...)
            return nil
        end)
    end

    SafeHook(hookfunction, ScriptContext.Error.Connect, function(...)
        return nil
    end)

    while not bypassed do
        task.wait(0.5)
    end
    task.wait(1)
end)

pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)

local P   = game:GetService("Players")
local RS  = game:GetService("ReplicatedStorage")
local RSvc= game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VU  = game:GetService("VirtualUser")
local HS  = game:GetService("HttpService")
local TS  = game:GetService("TeleportService")
local L   = game:GetService("Lighting")
local T   = game:GetService("TweenService")
local W   = game:GetService("Workspace")
local CG  = game:GetService("CoreGui")
local SG  = game:GetService("StarterGui")
local C   = W.CurrentCamera
local me  = P.LocalPlayer

getgenv().s = {
    -- ragebot
    rage = false, rageType = "Normal", rageWep = "primary", ragePrio = "",
    shootAt = 10, multiPart = false, partPriority = "Head",
    rageSmooth = false, rageSmoothVal = 1,
    rageAutoWall = false, rageVisible = false,
    -- spread / recoil
    noSpread = false, noRecoil = false, noMuzzle = false,
    rapid = false,
    -- void spam
    voidSpam = false, vsHide = 0.01,
    -- teleportation
    ttEnabled = false, ttMode = "Closest", ttPrio = "", ttPosition = "Front",
    ttMethod = "Adaptive", ttOffsetDist = 3, ttAimLead = false, ttStagger = 1,
    -- anti aim
    aa = false, aaMeth = "Desync",
    aaSpin = 999999, aaYaw = 180, aaPitch = 90, aaRoll = 180,
    strafe = false, strafeSpd = 500, strafeRad = 50, strafeH = 20, strafeRand = true,
    -- esp
    espBox = false, espName = false, espHp = false, espTrace = false,
    espSkelly = false, espDist = false, espTeam = false,
    espBoxCol   = Color3.fromRGB(0,255,0),
    espNameCol  = Color3.fromRGB(255,255,255),
    espHpCol    = Color3.fromRGB(0,255,0),
    espTraceCol = Color3.fromRGB(255,0,0),
    espSkellyCol= Color3.fromRGB(255,255,255),
    espDistCol  = Color3.fromRGB(255,255,0),
    espBoxT=2, espNameS=18, espHpS=14, espTraceT=2, espSkellyT=2,
    espChams = false, espChamsCol = Color3.fromRGB(0,255,0),
    -- misc
    antiAfk = false, ffaHop = false, autoBan = false,
    autoBanW1 = "Katana", autoBanW2 = "Flamethrower",
    autoQ = false, qMode = "Ranked 1v1",
    autoChoose = false, autoChooseW1 = "Katana", autoChooseW2 = "Knife",
    autoLoad = false, lastCfg = "default", autoExec = false,
    -- aimbot / silent / trig
    aimbot = false, silent = false, trig = false,
    trigReact = 0, trigMaxDist = 9999, trigPart = "Head", trigVisible = true,
    -- movement
    noFall = false, bulletTp = false, antiStuck = false, bulletTpRad = 99999,
    -- riot
    riotAbuse = false, riotDist = 500, riotX = 50, riotY = 15, riotZ = 50,
    riotSpin = 1000000000000, riotBypass = false, riotBypassDist = 3,
    riotBypassH = 5, riotBypassRate = 0.1,
    -- sbd (unused legacy)
    sbd=false, sbdInf=false, sbdNoGrav=false, sbdIgnoreWalls=false,
    sbdInsta=false, sbdThrough=false, sbdRapid=false, sbdHitbox=false,
    sbdDmg=999, sbdNoFalloff=false, sbdHeat=false,
    -- config
    config_selection = "default",
}

getgenv().allConns = {}
local s = getgenv().s
local cfgFolder = "kittyware_configs"
if not isfolder(cfgFolder) then makefolder(cfgFolder) end

local Toggles = {}
local Options  = {}

local function n(t, c)
    pcall(function()
        SG:SetCore("SendNotification", {Title=t, Text=c, Duration=3})
    end)
end

local function sr(obj)
    if not obj then return nil end
    local ok, res = pcall(require, obj)
    if ok then return res end
    return nil
end

local function inMatch()
    local char = me.Character
    if not char then return false end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return hum and hum.Health > 0 and root ~= nil
end
getgenv().KittyIsInLiveMatch = inMatch

local function vis(part, target)
    if not part or not target then return false end
    local origin    = part.Position
    local targetPos = target.Position
    local dir       = (targetPos - origin)
    local dist      = dir.Magnitude
    if dist < 0.01 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {me.Character, W:FindFirstChild("ViewModels")}
    local result = W:Raycast(origin, dir.Unit * dist, params)
    if not result then return true end
    return result.Instance and result.Instance:IsDescendantOf(target.Parent)
end

getgenv().getHrp = function(p)
    local pl = p or me
    if not pl or not pl.Character then return nil end
    return pl.Character:FindFirstChild("HumanoidRootPart")
end

getgenv().getClosest = function(checkFF, checkVis)
    local closest, minD = nil, math.huge
    local hrp = getgenv().getHrp(me)
    if not hrp then return nil end
    for _, p in ipairs(P:GetPlayers()) do
        if p ~= me and p.Character then
            local ff   = p.Character:FindFirstChildOfClass("ForceField")
            local tHrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum  = p.Character:FindFirstChildOfClass("Humanoid")
            if tHrp and hum and hum.Health > 0
                and not (checkFF and ff)
                and (me.Team == nil or p.Team == nil or me.Team ~= p.Team) then
                local doCheck = true
                if checkVis then
                    local head = p.Character:FindFirstChild("Head")
                    if not head or not vis(hrp, head) then doCheck = false end
                end
                if doCheck then
                    local d = (hrp.Position - tHrp.Position).Magnitude
                    if d < minD then minD = d; closest = p end
                end
            end
        end
    end
    return closest
end

local rbLast      = 0
local rbFireCount = 0
local rbMissStreak= 0

-- Priority part list for multi-part ragebot
local rageParts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}

local function getPartForRage(char)
    -- If multi-part is off, just use the configured priority
    if not s.multiPart then
        return char:FindFirstChild(s.partPriority) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    -- Multi-part: try each part in priority order, prefer visible ones
    local hrp = getgenv().getHrp(me)
    for _, pname in ipairs(rageParts) do
        local part = char:FindFirstChild(pname)
        if part then
            if not s.rageVisible or (hrp and vis(hrp, part)) then
                return part
            end
        end
    end
    -- fallback
    return char:FindFirstChild("HumanoidRootPart")
end

getgenv().getRageTarget = function()
    local targetName = s.ragePrio
    if targetName and targetName ~= "" then
        local sp = P:FindFirstChild(targetName)
        if sp and sp.Character then
            local tHrp = sp.Character:FindFirstChild("HumanoidRootPart")
            local hum  = sp.Character:FindFirstChildOfClass("Humanoid")
            if tHrp and hum and hum.Health > 0
                and not sp.Character:FindFirstChildOfClass("ForceField")
                and (me.Team == nil or sp.Team == nil or me.Team ~= sp.Team) then
                return sp
            end
        end
    end
    -- visible-only filter when enabled
    return getgenv().getClosest(true, s.rageVisible)
end

local function buildFireData(util, targetPart)
    local camPos = C.CFrame.Position
    local atp    = targetPart.Position
    local lookCF = CFrame.lookAt(camPos, atp)
    local cData  = {}
    cData[utf8.char(1)] = {
        [utf8.char(0)] = util:EncodeCFrame(lookCF),
        [utf8.char(1)] = util:EncodeCFrame(lookCF),
        [utf8.char(2)] = targetPart,
        [utf8.char(3)] = util:EncodeCFrame(targetPart.CFrame:ToObjectSpace(CFrame.new(atp)))
    }
    cData.Hitbox = targetPart.Name
    return cData
end

local function fireShoot(targetPart, tChar)
    pcall(function()
        local util   = sr(RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Utility"))
        local enums  = sr(RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("EnumLibrary"))
        local fCtrl  = sr(me.PlayerScripts:FindFirstChild("Controllers") and me.PlayerScripts.Controllers:FindFirstChild("FighterController"))
        if not util or not enums or not fCtrl then return end
        if not fCtrl.LocalFighter or not fCtrl.LocalFighter.EquippedItem then return end

        local item   = fCtrl.LocalFighter.EquippedItem
        local objID  = item:Get("ObjectID")
        if not objID then return end

        local cData  = buildFireData(util, targetPart)
        local shots  = math.clamp(s.shootAt or 10, 1, 30)

        -- Smooth mode: spread shots across frames via task.spawn
        if s.rageSmooth then
            local smooth = math.max(s.rageSmoothVal or 1, 0.1)
            task.spawn(function()
                for i = 1, shots do
                    RS.Remotes.Replication.Fighter.UseItem:FireServer(
                        objID, enums:ToEnum("StartShooting"), cData, nil
                    )
                    if i < shots then task.wait(smooth / shots) end
                end
            end)
        else
            for _ = 1, shots do
                RS.Remotes.Replication.Fighter.UseItem:FireServer(
                    objID, enums:ToEnum("StartShooting"), cData, nil
                )
            end
        end
        rbFireCount = rbFireCount + 1
    end)
end
getgenv().fireShoot = fireShoot

-- Wall-check for auto-wall feature
local function canShootThrough(myHrp, targetPart)
    if not s.rageAutoWall then return false end
    -- simple check: if not visible but autowall is on, fire anyway
    return true
end

local function rageShootStep()
    if not s.rage then return end
    local now    = tick()
    -- Adaptive cooldown: back off slightly if we've been spamming successfully
    local cd     = 0.008
    if now - rbLast < cd then return end

    local target = getgenv().getRageTarget()
    if not target or not target.Character then return end
    if target.Character:FindFirstChildOfClass("ForceField") then return end

    local myHrp = getgenv().getHrp(me)
    if not myHrp then return end

    local targetPart = getPartForRage(target.Character)
    if not targetPart then return end

    -- Visible check (unless autowall bypasses it)
    if s.rageVisible and not canShootThrough(myHrp, targetPart) then
        if not vis(myHrp, targetPart) then
            rbMissStreak = rbMissStreak + 1
            return
        end
    end
    rbMissStreak = 0

    rbLast = now
    fireShoot(targetPart, target.Character)
end

getgenv().startRage = function()
    -- Bind teleportation to keep us on target
    s.ttEnabled = true
    s.ttPrio    = s.ragePrio or ""
    getgenv().startTT()

    -- High-priority render step for shot firing
    pcall(function() RSvc:UnbindFromRenderStep("RageShoot") end)
    RSvc:BindToRenderStep("RageShoot", Enum.RenderPriority.Camera.Value + 1, rageShootStep)

    -- Secondary heartbeat loop for maximum fire rate
    if getgenv()._rageHBConn then getgenv()._rageHBConn:Disconnect() end
    getgenv()._rageHBConn = RSvc.Heartbeat:Connect(function()
        if not s.rage then return end
        rageShootStep()
    end)

    rbFireCount  = 0
    rbMissStreak = 0
end

getgenv().stopRage = function()
    s.rage      = false
    s.ttEnabled = false
    if s.ttPrio == s.ragePrio then s.ttPrio = "" end
    getgenv().stopTT()
    pcall(function() RSvc:UnbindFromRenderStep("RageShoot") end)
    if getgenv()._rageHBConn then
        getgenv()._rageHBConn:Disconnect()
        getgenv()._rageHBConn = nil
    end
    rbFireCount  = 0
    rbMissStreak = 0
end

local vsConn    = nil
local vsAcc     = 0
local vsPhaseAcc= 0

getgenv().startVoid = function()
    if vsConn then vsConn:Disconnect() end
    vsAcc = 0; vsPhaseAcc = 0
    local safeHeight = 15
    vsConn = RSvc.Heartbeat:Connect(function(dt)
        if not s.voidSpam then getgenv().stopVoid() return end
        local hrp = getgenv().getHrp(me)
        local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        if hrp.Position.Y < -10 then
            hrp.CFrame = CFrame.new(hrp.Position.X, safeHeight, hrp.Position.Z)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            return
        end
        if hum:GetState() ~= Enum.HumanoidStateType.Physics then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        end
        vsPhaseAcc = vsPhaseAcc + dt
        if vsPhaseAcc < s.vsHide then return end
        vsPhaseAcc = 0
        vsAcc = vsAcc + dt
        if vsAcc >= 0.001 then
            vsAcc = 0
            for _ = 1, 100 do
                local finalPos = Vector3.new(
                    math.clamp(hrp.Position.X + math.random(-200,200), -5000, 5000),
                    math.max(safeHeight + math.random(0,10), safeHeight),
                    math.clamp(hrp.Position.Z + math.random(-200,200), -5000, 5000)
                )
                hrp.CFrame = CFrame.new(finalPos)
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end)
end

getgenv().stopVoid = function()
    if vsConn then vsConn:Disconnect(); vsConn = nil end
    s.voidSpam = false
end

local tt_conn        = nil
local tt_render_conn = nil
local tt_track       = {}
local tt_live        = {}
local tt_locked_target = nil
local TT_HISTORY_LEN   = 64
local TT_MICRO_SAMPLES = 16
local TT_VOID_THRESH   = -500

local function tt_record(part, x, y, z, cf, now)
    local live = tt_live[part]
    if not live then
        tt_live[part] = {x=x,y=y,z=z,cf=cf,t=now,lkg_x=x,lkg_y=y,lkg_z=z,lkg_cf=cf,lkg_t=now,is_void=false}
        live = tt_live[part]
    else
        live.x,live.y,live.z,live.cf,live.t = x,y,z,cf,now
        local in_void = y < TT_VOID_THRESH
        live.is_void = in_void
        if not in_void then
            live.lkg_x,live.lkg_y,live.lkg_z,live.lkg_cf,live.lkg_t = x,y,z,cf,now
        end
    end
    local entry = tt_track[part]
    if not entry then tt_track[part]={hist={},void_hist={}}; entry=tt_track[part] end
    local hist = entry.hist
    local n2   = #hist
    if n2 >= TT_HISTORY_LEN then
        local half = math.floor(TT_HISTORY_LEN/2)
        for i=1,half do hist[i]=hist[i+half] end
        for i=half+1,n2 do hist[i]=nil end
    end
    hist[#hist+1]={x=x,y=y,z=z,t=now,void=(y<TT_VOID_THRESH)}
    if y < TT_VOID_THRESH then
        local vh=entry.void_hist; vh[#vh+1]={x=x,y=y,z=z,t=now}
        if #vh>32 then table.remove(vh,1) end
    end
end

local function tt_predict_velocity(part)
    local entry=tt_track[part]
    if not entry or not entry.hist or #entry.hist<3 then return Vector3.zero end
    local hist=entry.hist; local n2=#hist
    local live=tt_live[part]; local in_void=live and live.is_void
    if in_void then
        local vh=entry.void_hist
        if vh and #vh>=2 then
            local a,b=vh[#vh-1],vh[#vh]; local dt2=b.t-a.t
            if dt2>0 then return Vector3.new((b.x-a.x)/dt2,(b.y-a.y)/dt2,(b.z-a.z)/dt2) end
        end
        return Vector3.zero
    end
    local vx,vy,vz,tw=0,0,0,0
    local var_acc,total=0,0; local prev_spd=nil
    for i=2,n2 do
        local a,b=hist[i-1],hist[i]
        if not b.void and not a.void then
            local dt2=b.t-a.t
            if dt2>0 then
                local w=i*i
                local dvx=(b.x-a.x)/dt2; local dvy=(b.y-a.y)/dt2; local dvz=(b.z-a.z)/dt2
                local spd=dvx*dvx+dvy*dvy+dvz*dvz
                if prev_spd then
                    local ratio=spd>prev_spd and spd/(prev_spd+1e-6) or prev_spd/(spd+1e-6)
                    var_acc=var_acc+(ratio>1000 and 1 or 0)
                end
                total=total+1; prev_spd=spd
                vx=vx+dvx*w; vy=vy+dvy*w; vz=vz+dvz*w; tw=tw+w
            end
        end
    end
    if total>0 and var_acc/total>0.30 then return Vector3.zero end
    if tw==0 then return Vector3.zero end
    return Vector3.new(vx/tw,vy/tw,vz/tw)
end

local function tt_target_valid(p)
    if not p or not p.Character then return false end
    local t_hrp=p.Character:FindFirstChild("HumanoidRootPart")
    if not t_hrp then return false end
    if p.Character:FindFirstChildOfClass("ForceField") then return false end
    if me.Team and p.Team and me.Team==p.Team then return false end
    local live=tt_live[t_hrp]; if live then return true end
    local hum=p.Character:FindFirstChildOfClass("Humanoid")
    local alive=false
    if hum then pcall(function() alive=hum.Health>0 end) end
    return alive
end

local function tt_get_target()
    local prio=s.ttPrio
    if prio and prio~="" then
        local sp=P:FindFirstChild(prio)
        if sp and tt_target_valid(sp) then return sp end
    end
    local hrp=getgenv().getHrp(me); if not hrp then return nil end
    local my_x,my_y,my_z=hrp.Position.X,hrp.Position.Y,hrp.Position.Z
    local mode=s.ttMode or "Closest"
    local best,best_val=nil,mode=="Closest" and math.huge or -math.huge
    for _,p in ipairs(P:GetPlayers()) do
        if p~=me and tt_target_valid(p) then
            local t_hrp=p.Character:FindFirstChild("HumanoidRootPart")
            if t_hrp then
                local tx,ty,tz
                local live=tt_live[t_hrp]
                if live then tx,ty,tz=live.x,live.y,live.z
                else pcall(function() local cf=t_hrp.CFrame; tx,ty,tz=cf.X,cf.Y,cf.Z end) end
                if tx then
                    local dx,dy,dz=tx-my_x,ty-my_y,tz-my_z
                    local dsq=dx*dx+dy*dy+dz*dz
                    if mode=="Closest" and dsq<best_val then best_val=dsq; best=p
                    elseif mode=="Farthest" and dsq>best_val then best_val=dsq; best=p end
                end
            end
        end
    end
    return best
end

local function tt_sample_part(part)
    local cf; pcall(function()
        local mt=getrawmetatable(part)
        if mt then local ri=rawget(mt,"__index"); if ri then cf=ri(part,"CFrame") end end
    end)
    if not cf then pcall(function() cf=part.CFrame end) end
    if not cf then return end
    local px,py,pz=cf.X,cf.Y,cf.Z
    if px~=px or py~=py or pz~=pz then return end
    tt_record(part,px,py,pz,cf,tick())
end

local function tt_sample_all(char,t_hrp)
    pcall(tt_sample_part,t_hrp)
    local head=char:FindFirstChild("Head"); if head then pcall(tt_sample_part,head) end
    local tor=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if tor then pcall(tt_sample_part,tor) end
end

local function tt_nuke_fallen()
    pcall(function() W.FallenPartsDestroyHeight=-math.huge end)
    pcall(function() W.FallenPartsDestroyHeight=0/0 end)
    pcall(function()
        local mt=getrawmetatable(W)
        if mt then local ni=rawget(mt,"__newindex"); if ni then ni(W,"FallenPartsDestroyHeight",-math.huge) end end
    end)
end

local function tt_validate_vec3(v)
    if not v then return false end
    local x,y,z=v.X,v.Y,v.Z
    if x~=x or y~=y or z~=z then return false end
    if math.abs(x)==math.huge or math.abs(y)==math.huge or math.abs(z)==math.huge then return false end
    return true
end

local function tt_make_spin()
    local t2=tick(); local twopi=math.pi*2
    return CFrame.Angles((1e20*t2*1.00)%twopi,(1e20*t2*0.73)%twopi,(1e20*t2*0.41)%twopi)
end

local function tt_force_cframe(hrp,target_cf)
    tt_nuke_fallen()
    local function write_direct()
        hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero
        hrp.CFrame=target_cf
        hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero
    end
    local function write_rawmt()
        local mt=getrawmetatable(hrp); if not mt then return end
        local ni=rawget(mt,"__newindex"); if not ni then return end
        ni(hrp,"AssemblyLinearVelocity",Vector3.zero); ni(hrp,"AssemblyAngularVelocity",Vector3.zero)
        ni(hrp,"CFrame",target_cf)
        ni(hrp,"AssemblyLinearVelocity",Vector3.zero); ni(hrp,"AssemblyAngularVelocity",Vector3.zero)
    end
    local function write_anchor()
        local was=hrp.Anchored; hrp.Anchored=true; hrp.CFrame=target_cf
        hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero
        hrp.Anchored=was
    end
    local written=false
    local function try(fn) if written then return end; local ok=pcall(fn); if ok then written=true end end
    try(write_direct); try(write_rawmt); try(write_anchor)
    if not written then for _=1,4 do pcall(write_direct); pcall(write_rawmt) end end
    tt_nuke_fallen()
end

local function tt_get_latest(part)
    local live=tt_live[part]
    if live then return Vector3.new(live.x,live.y,live.z) end
    local ok,cf=pcall(function() return part.CFrame end)
    if ok then return Vector3.new(cf.X,cf.Y,cf.Z) end
    return nil
end

local function tt_get_lkg(part)
    local live=tt_live[part]
    if live and live.lkg_x then return Vector3.new(live.lkg_x,live.lkg_y,live.lkg_z) end
    return tt_get_latest(part)
end

local function tt_is_void(part)
    local live=tt_live[part]; return live and live.is_void or false
end

local function tt_get_predicted(part,lookahead)
    local live=tt_live[part]
    if not live then
        local ok,cf=pcall(function() return part.CFrame end)
        if ok then return Vector3.new(cf.X,cf.Y,cf.Z) end
        return nil
    end
    local base=Vector3.new(live.x,live.y,live.z)
    if not lookahead or lookahead<=0 then return base end
    local vel=tt_predict_velocity(part)
    local pred=base+vel*lookahead
    local dx,dy,dz=pred.X-base.X,pred.Y-base.Y,pred.Z-base.Z
    if dx*dx+dy*dy+dz*dz>50000*50000 then return base end
    return pred
end

local function tt_get_ping()
    local ok,stat=pcall(function() return game:GetService("Stats") end)
    if ok and stat then
        local ok2,ping=pcall(function() return stat.Network.ServerStatsItem["Data Ping"].Value end)
        if ok2 and type(ping)=="number" and ping==ping then return math.clamp(ping/1000,0,0.5) end
    end
    return 1/30
end

local function tt_resolve_void(t_hrp,head)
    local pos=tt_get_latest(t_hrp)
    if pos and tt_validate_vec3(pos) then return pos end
    if head then local hp=tt_get_latest(head); if hp and tt_validate_vec3(hp) then return hp end end
    local lkg=tt_get_lkg(t_hrp)
    if lkg and tt_validate_vec3(lkg) then return lkg end
    return nil
end

local function tt_get_offset_dest(part,base)
    local pos_mode=s.ttPosition or "Front"
    local live=tt_live[part]; local cf=live and live.cf
    if not cf then pcall(function() cf=part.CFrame end) end
    if not cf then return base end
    local d=math.clamp(s.ttOffsetDist or 3,0,500)
    local dest
    if     pos_mode=="Front"  then dest=(cf*CFrame.new(0,0,-d)).Position
    elseif pos_mode=="Behind" then dest=(cf*CFrame.new(0,0, d)).Position
    elseif pos_mode=="Above"  then dest=(cf*CFrame.new(0, d,0)).Position
    elseif pos_mode=="Below"  then dest=(cf*CFrame.new(0,-d,0)).Position
    elseif pos_mode=="Left"   then dest=(cf*CFrame.new(-d,0,0)).Position
    elseif pos_mode=="Right"  then dest=(cf*CFrame.new( d,0,0)).Position
    elseif pos_mode=="Exact"  then dest=cf.Position end
    if dest and tt_validate_vec3(dest) then return dest end
    return base
end

local function tt_resolve_dest(head,t_hrp,method)
    local in_void=tt_is_void(t_hrp)
    if method=="Predictive" then
        local vel=tt_predict_velocity(t_hrp); local spd=vel.Magnitude
        local ping=tt_get_ping(); local stagger=math.clamp(s.ttStagger or 1,0,10)
        local la=math.clamp(spd/500*ping*stagger,0,1)
        if in_void then
            local base=tt_get_latest(t_hrp) or tt_get_lkg(t_hrp)
            if base and tt_validate_vec3(base) then
                if la>0 and spd>0 then local pred=base+vel*la; if tt_validate_vec3(pred) then return pred end end
                return base
            end
            return tt_resolve_void(t_hrp,head)
        end
        local pos=(head and tt_get_predicted(head,la)) or tt_get_predicted(t_hrp,la)
        if pos and tt_validate_vec3(pos) then return pos end
        return (head and tt_get_latest(head)) or tt_get_latest(t_hrp)
    else
        if in_void then return tt_resolve_void(t_hrp,head) end
        local pos=(head and tt_get_latest(head)) or tt_get_latest(t_hrp)
        if pos and tt_validate_vec3(pos) then return pos end
        return nil
    end
end

local function tt_apply(hrp,dest,hum,t_hrp)
    pcall(function() W.FallenPartsDestroyHeight=-math.huge end)
    pcall(function() W.FallenPartsDestroyHeight=0/0 end)
    if not tt_validate_vec3(dest) then return end
    if hum then
        pcall(function() hum.AutoRotate=false end)
        pcall(function() hum.PlatformStand=true end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
    end
    local final=tt_get_offset_dest(t_hrp,dest)
    if s.ttAimLead then
        local vel=tt_predict_velocity(t_hrp)
        if vel and vel.Magnitude>=1 then
            local lead_t=math.clamp(vel.Magnitude/500*(1/30),0,0.5)
            local led=final+vel*lead_t
            if tt_validate_vec3(led) then final=led end
        end
    end
    if not tt_validate_vec3(final) then final=dest end
    local x,y,z=final.X,final.Y,final.Z
    tt_force_cframe(hrp,CFrame.new(x,y,z)*tt_make_spin())
end

local function tt_do_snap()
    if not s.ttEnabled then return end
    tt_nuke_fallen()
    local target=tt_get_target(); if not target or not target.Character then return end
    local t_hrp=target.Character:FindFirstChild("HumanoidRootPart"); if not t_hrp then return end
    local head=target.Character:FindFirstChild("Head")
    for _=1,math.floor(TT_MICRO_SAMPLES/2) do pcall(tt_sample_all,target.Character,t_hrp) end
    local dest=tt_resolve_dest(head,t_hrp,s.ttMethod or "Adaptive"); if not dest then return end
    local hrp=getgenv().getHrp(me); if not hrp then return end
    local hum=me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    pcall(tt_apply,hrp,dest,hum,t_hrp)
end

getgenv().startTT = function()
    if tt_conn then tt_conn:Disconnect() end
    if tt_render_conn then tt_render_conn:Disconnect() end
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTVoidGuard") end)
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTSample") end)
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTMicro") end)
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTSnap") end)
    tt_track={}; tt_live={}; tt_locked_target=nil
    tt_nuke_fallen()
    RSvc:BindToRenderStep("KittyTTVoidGuard",Enum.RenderPriority.First.Value-20,function()
        tt_nuke_fallen(); if not s.ttEnabled then return end
        local char=me.Character; if not char then return end
        for _,part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    if part.Position.Y<TT_VOID_THRESH then
                        pcall(function() part.AssemblyLinearVelocity=Vector3.zero end)
                        pcall(function() part.AssemblyAngularVelocity=Vector3.zero end)
                    end
                end)
            end
        end
    end)
    RSvc:BindToRenderStep("KittyTTSample",Enum.RenderPriority.First.Value-10,function()
        if not s.ttEnabled then return end; tt_nuke_fallen()
        local target=tt_get_target(); if not target or not target.Character then return end
        local t_hrp=target.Character:FindFirstChild("HumanoidRootPart"); if not t_hrp then return end
        for _=1,TT_MICRO_SAMPLES do pcall(tt_sample_all,target.Character,t_hrp) end
        task.spawn(function() for _=1,TT_MICRO_SAMPLES do pcall(tt_sample_all,target.Character,t_hrp) end end)
        local head=target.Character:FindFirstChild("Head")
        local dest=tt_resolve_dest(head,t_hrp,s.ttMethod or "Adaptive")
        if dest then
            local hrp=getgenv().getHrp(me)
            if hrp then local hum=me.Character and me.Character:FindFirstChildOfClass("Humanoid"); pcall(tt_apply,hrp,dest,hum,t_hrp) end
        end
    end)
    RSvc:BindToRenderStep("KittyTTMicro",Enum.RenderPriority.Camera.Value,function()
        if not s.ttEnabled then return end; tt_nuke_fallen()
        local target=tt_get_target(); if not target or not target.Character then return end
        local t_hrp=target.Character:FindFirstChild("HumanoidRootPart"); if not t_hrp then return end
        local head=target.Character:FindFirstChild("Head")
        for _=1,TT_MICRO_SAMPLES do pcall(tt_sample_all,target.Character,t_hrp) end
        local dest=tt_resolve_dest(head,t_hrp,s.ttMethod or "Adaptive")
        if dest then
            local hrp=getgenv().getHrp(me)
            if hrp then local hum=me.Character and me.Character:FindFirstChildOfClass("Humanoid"); pcall(tt_apply,hrp,dest,hum,t_hrp) end
        end
    end)
    RSvc:BindToRenderStep("KittyTTSnap",Enum.RenderPriority.Last.Value+10,function() tt_do_snap() end)
    tt_conn=RSvc.Heartbeat:Connect(function() tt_do_snap() end)
    local function launch_loop(stagger)
        task.spawn(function()
            if stagger then task.wait() end
            while s.ttEnabled do
                tt_nuke_fallen()
                local target=tt_get_target()
                if target and target.Character then
                    local t_hrp=target.Character:FindFirstChild("HumanoidRootPart")
                    local hrp=getgenv().getHrp(me)
                    if t_hrp and hrp then
                        for _=1,math.floor(TT_MICRO_SAMPLES/2) do pcall(tt_sample_all,target.Character,t_hrp) end
                        local head=target.Character:FindFirstChild("Head")
                        local dest=tt_resolve_dest(head,t_hrp,s.ttMethod or "Adaptive")
                        if dest then local hum=me.Character and me.Character:FindFirstChildOfClass("Humanoid"); pcall(tt_apply,hrp,dest,hum,t_hrp) end
                    end
                end
                task.wait()
            end
        end)
    end
    launch_loop(false); launch_loop(true)
    task.spawn(function()
        while s.ttEnabled do
            tt_nuke_fallen()
            local target=tt_get_target()
            if target and target.Character then
                local t_hrp=target.Character:FindFirstChild("HumanoidRootPart")
                if t_hrp then for _=1,TT_MICRO_SAMPLES do pcall(tt_sample_all,target.Character,t_hrp) end end
            end
            task.wait()
        end
    end)
end

getgenv().stopTT = function()
    s.ttEnabled=false
    if tt_conn then tt_conn:Disconnect(); tt_conn=nil end
    if tt_render_conn then tt_render_conn:Disconnect(); tt_render_conn=nil end
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTVoidGuard") end)
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTSample") end)
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTMicro") end)
    pcall(function() RSvc:UnbindFromRenderStep("KittyTTSnap") end)
    tt_track={}; tt_live={}; tt_locked_target=nil
    local hum=me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.AutoRotate=true end); pcall(function() hum.PlatformStand=false end) end
end

local aaConn  = nil
local aaOrbit = 0

getgenv().startAa = function()
    if aaConn then aaConn:Disconnect() end
    local aaT=0
    aaConn=RSvc.Heartbeat:Connect(function(dt)
        if not s.aa then return end
        local hrp=getgenv().getHrp(me); if not hrp then return end
        local hum=me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        local cam=C; if not cam then return end
        aaT=aaT+dt; local t2=aaT
        local method=s.aaMeth or "Desync"
        if method=="Static" then
            if hum then hum.AutoRotate=false end
            local look=cam.CFrame.LookVector; local rootPos=hrp.Position
            if look.Magnitude>0.001 then hrp.CFrame=CFrame.lookAt(rootPos,rootPos+look)*CFrame.Angles(0,math.rad(180),0) end
        elseif method=="Spin" then
            if hum then hum.AutoRotate=false end
            hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(0,math.rad((s.aaSpin or 999999)*dt%360),0)
        elseif method=="Jitter" then
            if hum then hum.AutoRotate=false end
            hrp.CFrame=hrp.CFrame*CFrame.Angles(math.rad(math.random(-180,180)),math.rad(math.random(-180,180)),math.rad(math.random(-180,180)))
        elseif method=="Desync" then
            if hum then hum.AutoRotate=false end
            local rootPos=hrp.Position; local look=cam.CFrame.LookVector
            local base=CFrame.lookAt(rootPos,rootPos+Vector3.new(look.X,0,look.Z))
            hrp.CFrame=base*CFrame.Angles(math.rad(s.aaYaw or 180),math.rad(s.aaPitch or 90),math.rad(s.aaRoll or 180))
            for _,v in pairs(me.Character:GetDescendants()) do
                if v:IsA("Motor6D") and v.Name~="RootJoint" then
                    pcall(function() v.Transform=CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360))) end)
                end
            end
        elseif method=="Sway" then
            if hum then hum.AutoRotate=false end
            hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(math.cos(t2*2)*math.rad(45),math.sin(t2*3)*math.rad(90),math.sin(t2*1.5)*math.rad(30))
        elseif method=="Orbit" then
            if hum then hum.AutoRotate=false end
            aaOrbit=aaOrbit+dt*(s.aaSpin or 999999)*0.05
            local dirs={Vector3.new(math.cos(aaOrbit),0,math.sin(aaOrbit)),Vector3.new(0,math.sin(aaOrbit),math.cos(aaOrbit))}
            local chosen=dirs[(math.floor(t2*8)%#dirs)+1]
            local rootPos=hrp.Position; local randR=math.random(500,50000)
            hrp.CFrame=CFrame.new(rootPos+chosen*randR)*CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
            hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero
        elseif method=="Custom" then
            if hum then hum.AutoRotate=false end
            hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(math.rad(s.aaPitch or 0),math.rad(s.aaYaw or 0),math.rad(s.aaRoll or 0))
        end
    end)
end

getgenv().stopAa = function()
    if aaConn then aaConn:Disconnect(); aaConn=nil end
    local hum=me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate=true end
    s.aa=false
end

local strafeC1=nil; local strafeC2=nil; local strafeAng=0; local strafeDir=1

getgenv().startStrafe = function()
    if strafeC1 then strafeC1:Disconnect() end
    if strafeC2 then strafeC2:Disconnect() end
    strafeAng=0; local lastSwitch=tick()
    strafeC1=RSvc.Stepped:Connect(function(_,dt)
        if not s.strafe then return end
        local target=getgenv().getClosest(true,false); local hrp=getgenv().getHrp(me)
        if target and target.Character and hrp then
            local tHrp=target.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                if s.strafeRand and tick()-lastSwitch>math.random(1,3) then strafeDir=strafeDir*-1; lastSwitch=tick() end
                strafeAng=strafeAng+(((s.strafeSpd or 500)/100)*strafeDir*dt*60)
                local tv=tHrp.AssemblyLinearVelocity
                local pred=tHrp.Position+(tv*dt+(tv*(me:GetNetworkPing()*2)))
                local off=Vector3.new(math.cos(strafeAng)*(s.strafeRad or 50),s.strafeH or 20,math.sin(strafeAng)*(s.strafeRad or 50))
                hrp.CFrame=CFrame.lookAt(pred+off,tHrp.Position); hrp.AssemblyLinearVelocity=tv; hrp.AssemblyAngularVelocity=Vector3.zero
            end
        end
    end)
    strafeC2=RSvc.RenderStepped:Connect(function(dt)
        if not s.strafe then return end
        local target=getgenv().getClosest(true,false); local hrp=getgenv().getHrp(me)
        if target and target.Character and hrp then
            local tHrp=target.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                local tv=tHrp.AssemblyLinearVelocity
                local pred=tHrp.Position+(tv*dt+(tv*(me:GetNetworkPing()*2)))
                local off=Vector3.new(math.cos(strafeAng)*(s.strafeRad or 50),s.strafeH or 20,math.sin(strafeAng)*(s.strafeRad or 50))
                hrp.CFrame=CFrame.lookAt(pred+off,tHrp.Position)
            end
        end
    end)
end

getgenv().stopStrafe = function()
    if strafeC1 then strafeC1:Disconnect(); strafeC1=nil end
    if strafeC2 then strafeC2:Disconnect(); strafeC2=nil end
    s.strafe=false
end

local muzzleC=nil

getgenv().startMuzzle = function()
    if muzzleC then muzzleC:Disconnect() end
    muzzleC=RSvc.RenderStepped:Connect(function()
        local vm=W:FindFirstChild("ViewModels"); if not vm then return end
        for _,child in ipairs(vm:GetDescendants()) do
            if child:IsA("ParticleEmitter") and child.Name=="ParticleEmiter" then child:Destroy() end
            if child:IsA("SpotLight") then child:Destroy() end
        end
    end)
end

getgenv().stopMuzzle = function()
    if muzzleC then muzzleC:Disconnect(); muzzleC=nil end
end

local wpnS={ShootRecoil=0,ShootSpread=0,ProjectileSpeed=math.huge,ShootCooldown=0,QuickShotCooldown=0,ShootBurstCooldown=0,AttackCooldown=0,Cooldown=0}
local rfEn=false

getgenv().startRapid = function()
    if rfEn then return end; rfEn=true
    task.spawn(function()
        pcall(function()
            local ci=sr(me.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem); if not ci then return end
            getgenv().oldInp=hookfunction(ci.Input,function(...)
                local args={...}
                if s.rapid and type(args[1])=="table" and args[1].Info then
                    for k,v2 in pairs(wpnS) do args[1].Info[k]=v2 end
                end
                return getgenv().oldInp(...)
            end)
        end)
    end)
end

getgenv().stopRapid = function()
    rfEn=false; s.rapid=false
    if getgenv().oldInp then
        pcall(function() sr(me.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem).Input=getgenv().oldInp end)
        getgenv().oldInp=nil
    end
end

local afkC=nil

getgenv().startAfk = function()
    if afkC then afkC:Disconnect() end
    afkC=me.Idled:Connect(function()
        if s.antiAfk then VU:Button2Down(Vector2.new(0,0),C.CFrame); task.wait(1); VU:Button2Up(Vector2.new(0,0),C.CFrame) end
    end)
end

getgenv().stopAfk = function()
    if afkC then afkC:Disconnect(); afkC=nil end
end

local lastHop=0
local function hop()
    if not s.ffaHop then return end
    if tick()-lastHop<8 then return end
    task.wait(0.7+math.random()*1.6)
    task.spawn(function()
        local ok,response=pcall(function()
            return HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100",true))
        end)
        if not ok or not response or not response.data then return end
        local valid={}
        for _,sv in ipairs(response.data) do
            if sv and sv.id and sv.id~=game.JobId and sv.playing<(sv.maxPlayers or 1)*0.88 then
                table.insert(valid,sv)
            end
        end
        if #valid==0 then return end
        local target=valid[math.random(1,math.min(6,#valid))]
        lastHop=tick(); task.wait(0.5+math.random()*1.3)
        pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,target.id,me) end)
    end)
end

task.spawn(function()
    while task.wait(14+math.random()*13) do if s.ffaHop then hop() end end
end)
local rWeaps={"none","Katana","Knife","Fists","Battle Axe","Chainsaw","Riot Shield","Scythe","Maul","Trowel","Grenade","Flashbang","Jump Pad","Molotav","Satchel","Smoke Grenade","War Horn","Medkit","Subspace Tripmine","Warpstone","Flamethrower","Bow","Crossbow","Dagger","Sling","Sword"}
local rQs   ={"1v1","Ranked 1v1","2v2","Ranked 2v2","3v3","Ranked 3v3","4v4","5v5"}

local abC=nil
getgenv().startAb = function()
    if abC then pcall(task.cancel,abC) end
    abC=task.spawn(function()
        while task.wait(0.5) do
            if not s.autoBan then break end
            pcall(function()
                local bR=RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Ban"); if not bR then return end
                if s.autoBanW1 and s.autoBanW1~="none" then bR:FireServer(s.autoBanW1) end
                if s.autoBanW2 and s.autoBanW2~="none" then bR:FireServer(s.autoBanW2) end
            end)
        end
    end)
end
getgenv().stopAb = function()
    s.autoBan=false
    if abC then pcall(task.cancel,abC); abC=nil end
end

local aqC=nil
getgenv().startAq = function()
    if aqC then pcall(task.cancel,aqC) end
    aqC=task.spawn(function()
        while task.wait(1) do
            if not s.autoQ then break end
            pcall(function()
                local qR=RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Queue")
                if qR then qR:FireServer(s.qMode or "Ranked 1v1") end
                local mm=RS:FindFirstChild("MatchMaking") or RS:FindFirstChild("Matchmaking")
                if mm then local q=mm:FindFirstChild("Queue") or mm:FindFirstChild("JoinQueue"); if q then q:FireServer(s.qMode or "Ranked 1v1") end end
            end)
        end
    end)
end
getgenv().stopAq = function()
    s.autoQ=false
    if aqC then pcall(task.cancel,aqC); aqC=nil end
end

local acC=nil
getgenv().startAc = function()
    if acC then pcall(task.cancel,acC) end
    acC=task.spawn(function()
        while task.wait(0.5) do
            if not s.autoChoose then break end
            pcall(function()
                local cR=RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Choose"); if not cR then return end
                if s.autoChooseW1 and s.autoChooseW1~="none" then cR:FireServer(s.autoChooseW1) end
                if s.autoChooseW2 and s.autoChooseW2~="none" then cR:FireServer(s.autoChooseW2) end
            end)
        end
    end)
end
getgenv().stopAc = function()
    s.autoChoose=false
    if acC then pcall(task.cancel,acC); acC=nil end
end

local espD={}
local function clearEsp()
    for _,d in ipairs(espD) do pcall(function() d:Remove() end) end
    espD={}
end

local espC=nil
local function startEsp()
    if espC then espC:Disconnect() end
    espC=RSvc.RenderStepped:Connect(function()
        clearEsp()
        if not(s.espBox or s.espName or s.espHp or s.espTrace or s.espSkelly or s.espDist) then return end
        local cam=C; if not cam then return end
        for _,plr in ipairs(P:GetPlayers()) do
            if plr~=me and plr.Character then
                local hrp2=plr.Character:FindFirstChild("HumanoidRootPart")
                local hum2=plr.Character:FindFirstChildOfClass("Humanoid")
                if hrp2 and hum2 and hum2.Health>0 then
                    local pos,isvis=cam:WorldToViewportPoint(hrp2.Position)
                    if isvis then
                        local teamCol=s.espTeam and plr.Team and plr.Team.TeamColor and plr.Team.TeamColor.Color or Color3.fromRGB(255,255,255)
                        if s.espDist then
                            local myhrp=me.Character and me.Character:FindFirstChild("HumanoidRootPart")
                            local dist2=myhrp and (myhrp.Position-hrp2.Position).Magnitude or 0
                            local lbl=Drawing.new("Text")
                            lbl.Text=string.format("%d",math.floor(dist2))
                            lbl.Position=Vector2.new(pos.X,pos.Y+10)
                            lbl.Color=s.espDistCol; lbl.Size=10; lbl.Center=true; lbl.Visible=true
                            table.insert(espD,lbl)
                        end
                        if s.espName then
                            local lbl=Drawing.new("Text")
                            lbl.Text=plr.Name
                            lbl.Position=Vector2.new(pos.X,pos.Y-30)
                            lbl.Color=s.espTeam and teamCol or s.espNameCol
                            lbl.Size=s.espNameS; lbl.Center=true; lbl.Visible=true
                            table.insert(espD,lbl)
                        end
                        if s.espHp then
                            local lbl=Drawing.new("Text")
                            lbl.Text=string.format("hp: %d",math.floor(hum2.Health))
                            lbl.Position=Vector2.new(pos.X,pos.Y-14)
                            lbl.Color=s.espHpCol; lbl.Size=s.espHpS; lbl.Center=true; lbl.Visible=true
                            table.insert(espD,lbl)
                        end
                        if s.espBox then
                            local box=Drawing.new("Square"); local size=40
                            box.Position=Vector2.new(pos.X-size/2,pos.Y-size/2)
                            box.Size=Vector2.new(size,size)
                            box.Color=s.espTeam and teamCol or s.espBoxCol
                            box.Thickness=s.espBoxT; box.Visible=true
                            table.insert(espD,box)
                        end
                        if s.espTrace then
                            local tracer=Drawing.new("Line")
                            local center2=cam.ViewportSize/2
                            tracer.From=Vector2.new(center2.X,center2.Y+50)
                            tracer.To=Vector2.new(pos.X,pos.Y)
                            tracer.Color=s.espTeam and teamCol or s.espTraceCol
                            tracer.Thickness=s.espTraceT; tracer.Visible=true
                            table.insert(espD,tracer)
                        end
                        if s.espSkelly then
                            local joints={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm","LeftUpperLeg","LeftLowerLeg","RightUpperLeg","RightLowerLeg"}
                            local points={}
                            for _,jname in ipairs(joints) do
                                local part=plr.Character:FindFirstChild(jname)
                                if part then
                                    local sp2,on=cam:WorldToViewportPoint(part.Position)
                                    if on then table.insert(points,{part=part,pos=Vector2.new(sp2.X,sp2.Y)}) end
                                end
                            end
                            for i=1,#points do
                                for j=i+1,#points do
                                    if(points[i].part.Position-points[j].part.Position).Magnitude<10 then
                                        local line=Drawing.new("Line")
                                        line.From=points[i].pos; line.To=points[j].pos
                                        line.Color=s.espSkellyCol; line.Thickness=s.espSkellyT; line.Visible=true
                                        table.insert(espD,line)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end
startEsp()

-- ─── Triggerbot (Triggerbot.lua) ───────────────────────────────────────────
local Triggerbot = {}
Triggerbot.__index = Triggerbot

local HITBOX_NAMES = { "HitboxBody", "HitboxHead", "HitboxHands" }

function Triggerbot.new(clientFighter, clientItem, input)
    local self = setmetatable({}, Triggerbot)
    self.clientFighter = clientFighter
    self.clientItem = clientItem
    self.input = input

    self.rayParams = RaycastParams.new()
    self.rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local function buildFilter()
        local filter = {}
        local characters = W:FindFirstChild("characters")
        if characters then table.insert(filter, characters) end
        local localChar = me.Character
        if localChar then table.insert(filter, localChar) end
        self.rayParams.FilterDescendantsInstances = filter
    end

    local function isScopedWeapon(item)
        if not item then return false end
        local weaponName = item.Name
        local scoped = Options.triggerbot_scoped and Options.triggerbot_scoped.Value or {}
        for weapon, enabled in pairs(scoped) do
            if enabled and weaponName == weapon then return true end
        end
        return false
    end

    local function rayToTarget()
        local cam = C; if not cam then return nil end
        buildFilter()
        local origin    = cam.CFrame.Position
        local direction = cam.CFrame.LookVector
        local maxDistance = Options.triggerbot_max_distance and Options.triggerbot_max_distance.Value or s.trigMaxDist or 9999
        local result = W:Raycast(origin, direction * maxDistance, self.rayParams)
        if not result then return nil end
        local instance = result.Instance; if not instance then return nil end
        local blacklist = Options.triggerbot_part_blacklist and Options.triggerbot_part_blacklist.Value or {}
        if blacklist[instance.Name] then return nil end
        local character = instance:FindFirstAncestorOfClass("Model"); if not character then return nil end
        local hum = character:FindFirstChild("Humanoid"); if not hum or hum.Health <= 0 then return nil end
        local ally = character:FindFirstChild("_is_ally"); if ally and ally.Value then return nil end
        if me.Team then
            for _, p in ipairs(P:GetPlayers()) do
                if p ~= me and p.Character == character and me.Team == p.Team then return nil end
            end
        end
        for _, name in ipairs(HITBOX_NAMES) do
            if instance.Name == name then return instance end
        end
        return nil
    end

    local function tryShoot()
        if not (Toggles.triggerbot_enabled and Toggles.triggerbot_enabled.Value or s.trig) then return end
        if not self:keyHeld() then return end
        local target = rayToTarget(); if not target then return end
        local reaction = Options.triggerbot_reaction_time and Options.triggerbot_reaction_time.Value or (s.trigReact or 0)
        local offset   = Options.triggerbot_reaction_time_offset and Options.triggerbot_reaction_time_offset.Value or 0
        local delay    = Options.triggerbot_shoot_delay and Options.triggerbot_shoot_delay.Value or 0
        task.delay((reaction + offset) / 1000, function()
            task.wait(delay / 1000)
            if not (Toggles.triggerbot_enabled and Toggles.triggerbot_enabled.Value or s.trig) then return end
            if self.clientItem then
                pcall(function() self.clientItem:Input(nil) end)
            elseif self.input then
                pcall(function() self.input(nil) end)
            else
                -- fallback: fire via remote
                local fCtrl = sr(me.PlayerScripts:FindFirstChild("Controllers") and me.PlayerScripts.Controllers:FindFirstChild("FighterController"))
                if not fCtrl or not fCtrl.LocalFighter or not fCtrl.LocalFighter.EquippedItem then return end
                local item   = fCtrl.LocalFighter.EquippedItem
                local objId  = item:Get("ObjectID"); if not objId then return end
                local util   = sr(RS.Modules and RS.Modules:FindFirstChild("Utility")); if not util then return end
                local enums  = sr(RS.Modules and RS.Modules:FindFirstChild("EnumLibrary")); if not enums then return end
                local atp    = target.Position
                local cData  = {}
                cData[utf8.char(1)] = {
                    [utf8.char(0)] = util:EncodeCFrame(CFrame.lookAt(C.CFrame.Position, atp)),
                    [utf8.char(1)] = util:EncodeCFrame(CFrame.lookAt(C.CFrame.Position, atp)),
                    [utf8.char(2)] = target,
                    [utf8.char(3)] = util:EncodeCFrame(target.CFrame:ToObjectSpace(CFrame.new(atp)))
                }
                cData.Hitbox = target.Name
                pcall(function() RS.Remotes.Replication.Fighter.UseItem:FireServer(objId, enums:ToEnum("StartShooting"), cData, nil) end)
            end
        end)
    end

    function self:keyHeld()
        if Toggles.triggerbot_keybind then
            local mode = Toggles.triggerbot_keybind.Mode
            local key  = Toggles.triggerbot_keybind.Value
            if mode == "Always" then return true end
            if mode == "Hold"   then return UIS:IsKeyDown(key) end
            if mode == "Toggle" then return Toggles.triggerbot_keybind.KeyDown end
        end
        return true
    end

    RSvc.Heartbeat:Connect(function() tryShoot() end)
    RSvc.RenderStepped:Connect(function() if me.Character then buildFilter() end end)

    return self
end

local _triggerbotInst = nil
local function startTrig()
    if not _triggerbotInst then
        _triggerbotInst = Triggerbot.new(nil, nil, nil)
    end
    s.trig = true
end
getgenv().startTrig = startTrig
getgenv().stopTrig = function() s.trig = false end

local hpL={"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso","Left Arm","LeftHand","LeftLowerArm","LeftUpperArm","Right Arm","RightHand","RightLowerArm","RightUpperArm","Left Leg","LeftFoot","LeftLowerLeg","LeftUpperLeg","Right Leg","RightFoot","RightLowerLeg","RightUpperLeg","Neck","Back","Front","Closest","Random"}

local isMobile=(UIS.TouchEnabled and not UIS.KeyboardEnabled)

-- ─── SilentAim (SilentAim.lua) ────────────────────────────────────────────
local SilentAim = {}
SilentAim.__index = SilentAim

local function _saCircle()
    local c=Drawing.new("Circle"); c.Thickness=1; c.Transparency=1
    c.Color=Color3.fromRGB(255,255,255); c.Filled=false; c.Visible=false; return c
end
local function _saLine()
    local l=Drawing.new("Line"); l.Thickness=1; l.Transparency=1
    l.Color=Color3.fromRGB(255,255,255); l.Visible=false; return l
end

function SilentAim.new(events)
    local self=setmetatable({},SilentAim)
    self.events=events or {}
    self.drawings={}
    self.fovCircle=_saCircle(); self.fovFill=_saCircle(); self.targetLine=_saLine()
    table.insert(self.drawings,self.fovCircle); table.insert(self.drawings,self.fovFill)
    table.insert(self.drawings,self.targetLine)
    self.target=nil; self.manipulated=false

    local function updateFovCircle()
        local cam=C; local radius=Options.silent_radius and Options.silent_radius.Value or s.silentFovRadius or 500
        local lerp=Options.silent_fov_lerp and Options.silent_fov_lerp.Value or 0.2
        local vp=cam.ViewportSize
        local focal=(vp.X/2)/math.tan(math.rad(cam.FieldOfView)/2)
        local pixelRadius=focal*math.tan(math.rad(radius))
        local circle=self.fovCircle
        circle.Radius=circle.Radius+(pixelRadius-circle.Radius)*lerp
        circle.Position=cam:WorldToViewportPoint(cam.CFrame.Position)
        self.fovFill.Radius=circle.Radius; self.fovFill.Position=circle.Position
        circle.Color=Options.silent_color1 and Options.silent_color1.Value or Color3.fromRGB(0,255,0)
        self.fovFill.Color=Options.silent_fill_color1 and Options.silent_fill_color1.Value or Color3.fromRGB(0,255,0)
    end

    local function onRender()
        local toggle=Toggles.silent_toggle and Toggles.silent_toggle.Value or s.silent
        local showFov=Toggles.silent_showfov and Toggles.silent_showfov.Value or false
        local visualize=Toggles.silent_visualize and Toggles.silent_visualize.Value or false
        if not toggle then
            self.fovCircle.Visible=false; self.fovFill.Visible=false; self.targetLine.Visible=false; return
        end
        updateFovCircle()
        self.fovCircle.Visible=showFov and (Toggles.silent_fov_outline and Toggles.silent_fov_outline.Value or true)
        self.fovFill.Visible=showFov and (Toggles.silent_fov_fill and Toggles.silent_fov_fill.Value or false)
        if self.fovFill.Visible then self.fovFill.Filled=true end
        local target=self:acquire()
        if target then
            local screen,onScreen=C:WorldToViewportPoint(target.Position)
            if onScreen then
                local center=C:WorldToViewportPoint(C.CFrame.Position)
                self.targetLine.From=Vector2.new(center.X,center.Y)
                self.targetLine.To=Vector2.new(screen.X,screen.Y)
                self.targetLine.Visible=visualize
                self.targetLine.Color=Options.silent_color2 and Options.silent_color2.Value or Color3.fromRGB(0,255,0)
            end
        else self.targetLine.Visible=false end
    end

    local function getTargetPart(character)
        if Options.silent_closest_part and Options.silent_closest_part.Value then
            local best,bestDist=nil,math.huge
            for _,part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then
                    local d=(part.Position-C.CFrame.Position).Magnitude
                    if d<bestDist then bestDist=d; best=part end
                end
            end
            return best
        end
        return character:FindFirstChild("HitboxHead") or character:FindFirstChild("Head")
               or character:FindFirstChild("HumanoidRootPart")
    end

    function self:acquire()
        local cam=C; if not cam then return nil end
        local radius=Options.silent_radius and Options.silent_radius.Value or s.silentFovRadius or 500
        local origin=cam.CFrame.Position
        local best,bestScore=nil,math.huge
        local vp=cam.ViewportSize; local center=Vector2.new(vp.X/2,vp.Y/2)
        for _,player in ipairs(P:GetPlayers()) do
            if player==me then continue end
            local char=player.Character; if not char then continue end
            local hum=char:FindFirstChild("Humanoid"); if not hum or hum.Health<=0 then continue end
            local ally=char:FindFirstChild("_is_ally"); if ally and ally.Value then continue end
            if me.Team and player.Team and me.Team==player.Team then continue end
            local part=getTargetPart(char); if not part then continue end
            local screen,onScreen=cam:WorldToViewportPoint(part.Position); if not onScreen then continue end
            local dist=(part.Position-origin).Magnitude; if dist>radius then continue end
            local score=(Vector2.new(screen.X,screen.Y)-center).Magnitude
            if score<bestScore then bestScore=score; best=part end
        end
        self.target=best; return best
    end

    function self:getTarget()
        if not (Toggles.silent_toggle and Toggles.silent_toggle.Value or s.silent) then return nil end
        local target=self:acquire(); if not target then return nil end
        local hitchance=Options.silent_hitchance and Options.silent_hitchance.Value or s.silentHitChance or 100
        if math.random(100)>hitchance then self.manipulated=false; return nil end
        self.manipulated=true; return target
    end

    function self:manipulate(position)
        if not (Toggles.silent_manipulation and Toggles.silent_manipulation.Value) then return position end
        local target=self:getTarget(); if not target then return nil end
        return target.Position
    end

    function self:destroy()
        for _,d in ipairs(self.drawings) do pcall(function() d:Remove() end) end
        self.drawings={}
    end

    RSvc.RenderStepped:Connect(onRender)

    -- auto-shoot heartbeat (mirrors original autoShoot / LMB behaviour)
    local _saLastFire=0; local _saFireCD=0.01
    local _saEnumLib=nil; local _saUtil=nil
    task.spawn(function()
        pcall(function()
            _saEnumLib=sr(RS.Modules and RS.Modules:FindFirstChild("EnumLibrary"))
            _saUtil=sr(RS.Modules and RS.Modules:FindFirstChild("Utility"))
        end)
    end)
    RSvc.Heartbeat:Connect(function()
        local tog=Toggles.silent_toggle and Toggles.silent_toggle.Value or s.silent
        if not tog then return end
        local autoShoot=Toggles.silent_autoshoot and Toggles.silent_autoshoot.Value or s.silentAutoShoot or false
        if not (autoShoot or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then return end
        local now=tick(); if now-_saLastFire<_saFireCD then return end
        local part=self:getTarget(); if not part then return end
        local myChar=me.Character; local root=myChar and myChar:FindFirstChild("HumanoidRootPart"); if not root then return end
        local fCtrl=sr(me.PlayerScripts.Controllers and me.PlayerScripts.Controllers:FindFirstChild("FighterController"))
        if not fCtrl or not fCtrl.LocalFighter or not fCtrl.LocalFighter.EquippedItem then return end
        local item=fCtrl.LocalFighter.EquippedItem; local objId=item:Get("ObjectID"); if not objId then return end
        if not _saEnumLib or not _saUtil then return end
        _saLastFire=now
        local atp=part.Position
        local data={[utf8.char(1)]={
            [utf8.char(0)]=_saUtil:EncodeCFrame(CFrame.new(root.Position,atp)),
            [utf8.char(1)]=_saUtil:EncodeCFrame(CFrame.new(root.Position,atp)),
            [utf8.char(2)]=part,
            [utf8.char(3)]=_saUtil:EncodeCFrame(CFrame.new(0.43,0.25,0.42))
        }}
        pcall(function() RS.Remotes.Replication.Fighter.UseItem:FireServer(objId,_saEnumLib:ToEnum("StartShooting"),data,nil) end)
    end)

    return self
end

local _silentAimInst = SilentAim.new()

-- ─── Aimbot (Aimbot.lua) ──────────────────────────────────────────────────
local Aimbot = {}
Aimbot.__index = Aimbot

local function _abCircle()
    local c=Drawing.new("Circle"); c.Thickness=1; c.Transparency=1
    c.Color=Color3.fromRGB(255,255,255); c.Filled=false; c.Visible=false; return c
end

function Aimbot.new(targeting)
    local self=setmetatable({},Aimbot)
    self.targeting=targeting or {}
    self.target=nil; self.manipulated=false
    self.fovCircle=_abCircle(); self.fovFill=_abCircle()

    local function isAlly(character)
        local flag=character and character:FindFirstChild("_is_ally")
        return flag~=nil and flag.Value==true
    end

    local function getTargetPart(character)
        if Toggles.aimbot_closest_part and Toggles.aimbot_closest_part.Value then
            local best,bestDist=nil,math.huge
            for _,part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then
                    local d=(part.Position-C.CFrame.Position).Magnitude
                    if d<bestDist then bestDist=d; best=part end
                end
            end
            return best
        end
        local partName=Options.targeting_part and Options.targeting_part.Value or s.aimTargetPart or "Head"
        return character:FindFirstChild(partName)
            or character:FindFirstChild("HitboxHead")
            or character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
    end

    local function acquire()
        local cam=C; if not cam then return nil end
        local radius=Options.aimbot_radius and Options.aimbot_radius.Value or s.aimFovRadius or 1000
        local origin=cam.CFrame.Position
        local best,bestScore=nil,math.huge
        local vp=cam.ViewportSize; local center=Vector2.new(vp.X/2,vp.Y/2)
        for _,player in ipairs(P:GetPlayers()) do
            if player==me then continue end
            local char=player.Character; if not char then continue end
            local hum=char:FindFirstChild("Humanoid"); if not hum or hum.Health<=0 then continue end
            if isAlly(char) then continue end
            if me.Team and player.Team and me.Team==player.Team then continue end
            local part=getTargetPart(char); if not part then continue end
            local screen,onScreen=cam:WorldToViewportPoint(part.Position); if not onScreen then continue end
            local dist=(part.Position-origin).Magnitude; if dist>radius then continue end
            local score=(Vector2.new(screen.X,screen.Y)-center).Magnitude
            if score<bestScore then bestScore=score; best=part end
        end
        self.target=best; return best
    end

    local function updateFov()
        local cam=C; local vp=cam.ViewportSize
        local radius=Options.aimbot_radius and Options.aimbot_radius.Value or s.aimFovRadius or 1000
        local lerp=Options.aimbot_fov_lerp and Options.aimbot_fov_lerp.Value or 0.2
        local focal=(vp.X/2)/math.tan(math.rad(cam.FieldOfView)/2)
        local pixelRadius=focal*math.tan(math.rad(radius))
        local circle=self.fovCircle
        circle.Radius=circle.Radius+(pixelRadius-circle.Radius)*lerp
        circle.Position=cam:WorldToViewportPoint(cam.CFrame.Position)
        self.fovFill.Radius=circle.Radius; self.fovFill.Position=circle.Position
        circle.Color=Options.aimbot_color1 and Options.aimbot_color1.Value or Color3.fromRGB(255,0,0)
        self.fovFill.Color=Options.aimbot_fill_color1 and Options.aimbot_fill_color1.Value or Color3.fromRGB(255,0,0)
    end

    local function onRender()
        local toggle=Toggles.aimbot_toggle and Toggles.aimbot_toggle.Value or s.aimbot
        local showFov=Toggles.aimbot_showfov and Toggles.aimbot_showfov.Value or false
        if not toggle then self.fovCircle.Visible=false; self.fovFill.Visible=false; return end
        updateFov()
        self.fovCircle.Visible=showFov
        self.fovFill.Visible=showFov and (Toggles.aimbot_fov_fill and Toggles.aimbot_fov_fill.Value or false)
        if self.fovFill.Visible then self.fovFill.Filled=true end
        if not self:keyHeld() then return end
        local target=acquire(); if not target then return end
        local cam=C
        local look=cam.CFrame.LookVector
        local toTarget=(target.Position-cam.CFrame.Position).Unit
        local dot=look:Dot(toTarget)
        if dot<math.cos(math.rad(Options.aimbot_radius and Options.aimbot_radius.Value or s.aimFovRadius or 1000)) then return end
        local smoothing=Options.aimbot_smoothing and Options.aimbot_smoothing.Value or s.aimSmooth or 0.2
        local matchAxis=Options.aimbot_match_axis and Options.aimbot_match_axis.Value or "lerp"
        local desired=CFrame.lookAt(cam.CFrame.Position,target.Position)
        if matchAxis=="y" then
            local yaw=math.atan2(target.Position.X-cam.CFrame.Position.X,target.Position.Z-cam.CFrame.Position.Z)
            local pitch=math.asin(math.clamp((target.Position.Y-cam.CFrame.Position.Y)/(target.Position-cam.CFrame.Position).Magnitude,-1,1))
            local currentYaw=math.atan2(cam.CFrame.LookVector.X,cam.CFrame.LookVector.Z)
            local delta=(yaw-currentYaw+math.pi)%(2*math.pi)-math.pi
            cam.CFrame=CFrame.new(cam.CFrame.Position)*CFrame.Angles(0,delta*smoothing,0)*CFrame.Angles(-pitch*smoothing,0,0)
        else
            if isMobile then
                local sp3,on=cam:WorldToViewportPoint(target.Position)
                if on then
                    local mp=UIS:GetMouseLocation(); local tp=Vector2.new(sp3.X,sp3.Y)
                    local dx=tp.X-mp.X; local dy=tp.Y-mp.Y
                    local smooth=math.max(1/smoothing,0.1)
                    if math.abs(dx)>1 or math.abs(dy)>1 then pcall(function() UIS:SetMouseLocation(mp.X+dx/smooth,mp.Y+dy/smooth) end) end
                end
            else
                local sp3,on=cam:WorldToViewportPoint(target.Position)
                if on then
                    local mp=UIS:GetMouseLocation(); local tp=Vector2.new(sp3.X,sp3.Y)
                    local dx=tp.X-mp.X; local dy=tp.Y-mp.Y
                    local smooth=math.max(1/smoothing,0.1)
                    if math.abs(dx)>1 or math.abs(dy)>1 then pcall(function() mousemoverel(dx/smooth,dy/smooth) end) end
                end
            end
        end
    end

    function self:getTarget()
        if not (Toggles.aimbot_toggle and Toggles.aimbot_toggle.Value or s.aimbot) then return nil end
        if not self:keyHeld() then return nil end
        return acquire()
    end

    function self:keyHeld()
        if Toggles.aimbot_keybind then
            local mode=Toggles.aimbot_keybind.Mode
            local key=Toggles.aimbot_keybind.Value
            if mode=="Always" then return true end
            if mode=="Hold" then return UIS:IsKeyDown(key) end
        end
        return true
    end

    function self:destroy()
        pcall(function() self.fovCircle:Remove() end)
        pcall(function() self.fovFill:Remove() end)
    end

    RSvc.RenderStepped:Connect(onRender)
    return self
end

local _aimbotInst = nil
local function startAim()
    s.aimbot=true
    if not _aimbotInst then _aimbotInst=Aimbot.new() end
end
local function stopAim()
    s.aimbot=false
    if _aimbotInst then pcall(function() _aimbotInst:destroy() end); _aimbotInst=nil end
end

local function syncTogglesFromS()
    pcall(function()
        for key,toggle in pairs(Toggles) do
            if s[key]~=nil then pcall(function() toggle:SetValue(s[key]) end) end
        end
    end)
end

getgenv().saveCfg = function(name)
    if not name or name=="" then name="default" end
    local path=cfgFolder.."/"..name..".json"
    local data={AutoLoadConfig=s.autoLoad,LastLoadedConfig=name,full_config={}}
    for k,v2 in pairs(s) do
        local t2=type(v2)
        if t2=="boolean" or t2=="number" or t2=="string" then data.full_config[k]=v2
        elseif t2=="userdata" then pcall(function() data.full_config[k]={r=v2.R,g=v2.G,b=v2.B} end) end
    end
    local ok,enc=pcall(HS.JSONEncode,HS,data)
    if ok and enc then local wok=pcall(writefile,path,enc); if wok then n("config","saved: "..name); return true end end
    n("config","failed to save."); return false
end

getgenv().loadCfg = function(name)
    if not name or name=="" then name="default" end
    local path=cfgFolder.."/"..name..".json"
    if not isfile(path) then n("config","not found: "..name); return false end
    local ok,raw=pcall(readfile,path); if not ok then n("config","failed to read."); return false end
    local s2,d=pcall(HS.JSONDecode,HS,raw)
    if not s2 or not d or not d.full_config then n("config","corrupted."); return false end
    s.autoLoad=d.AutoLoadConfig or false; s.lastCfg=name; s.config_selection=name
    for k,v2 in pairs(d.full_config) do
        if s[k]~=nil then
            local st=type(s[k]); local vt=type(v2)
            if st=="userdata" then if vt=="table" and v2.r and v2.g and v2.b then pcall(function() s[k]=Color3.new(v2.r,v2.g,v2.b) end) end
            elseif st==vt then s[k]=v2 end
        end
    end
    pcall(function()
        if s.rage then getgenv().startRage() else getgenv().stopRage() end
        if s.voidSpam then getgenv().startVoid() else getgenv().stopVoid() end
        if s.ttEnabled then getgenv().startTT() else getgenv().stopTT() end
        if s.aa then getgenv().startAa() else getgenv().stopAa() end
        if s.rapid then getgenv().startRapid() else getgenv().stopRapid() end
        if s.noMuzzle then getgenv().startMuzzle() else getgenv().stopMuzzle() end
        if s.antiAfk then getgenv().startAfk() else getgenv().stopAfk() end
        if s.autoBan then getgenv().startAb() else getgenv().stopAb() end
        if s.autoQ then getgenv().startAq() else getgenv().stopAq() end
        if s.autoChoose then getgenv().startAc() else getgenv().stopAc() end
        if s.trig then startTrig() else getgenv().stopTrig() end
        if s.aimbot then startAim() else stopAim() end
        -- silent aim is driven by s.silent / Toggles.silent_toggle; no separate table to sync
    end)
    syncTogglesFromS()
    n("config","loaded: "..name)
    return true
end

getgenv().overwriteCfg = function(name)
    if not name or name=="" then name="default" end
    local path=cfgFolder.."/"..name..".json"
    local data={AutoLoadConfig=s.autoLoad,LastLoadedConfig=name,full_config={}}
    for k,v2 in pairs(s) do
        local t2=type(v2)
        if t2=="boolean" or t2=="number" or t2=="string" then data.full_config[k]=v2
        elseif t2=="userdata" then pcall(function() data.full_config[k]={r=v2.R,g=v2.G,b=v2.B} end) end
    end
    local ok,enc=pcall(HS.JSONEncode,HS,data)
    if ok and enc then local wok=pcall(writefile,path,enc); if wok then n("config","overwritten: "..name); return true end end
    n("config","failed to overwrite."); return false
end

getgenv().delCfg = function(name)
    if not name or name=="" or name=="default" then n("config","cannot delete default."); return false end
    local path=cfgFolder.."/"..name..".json"
    if not isfile(path) then n("config","not found."); return false end
    local ok=pcall(delfile,path)
    if ok then n("config","deleted: "..name); return true end
    n("config","failed to delete."); return false
end

getgenv().listCfgs = function()
    if not isfolder(cfgFolder) then return{"default"} end
    local list={}; local ok,files=pcall(listfiles,cfgFolder)
    if ok and files then
        for _,f in ipairs(files) do local m=f:match("([^/\\]+)%.json$"); if m then table.insert(list,m) end end
    end
    table.sort(list)
    if #list==0 then list={"default"} end
    return list
end

getgenv().unloadAll = function()
    getgenv().kitty_loaded=false
    pcall(getgenv().stopRage); pcall(getgenv().stopVoid); pcall(getgenv().stopTT); pcall(getgenv().stopAa)
    pcall(getgenv().stopStrafe); pcall(getgenv().stopRapid); pcall(getgenv().stopMuzzle); pcall(getgenv().stopAfk)
    pcall(getgenv().stopAb); pcall(getgenv().stopAq); pcall(getgenv().stopAc); pcall(getgenv().stopTrig)
    stopAim(); s.ffaHop=false
    for _,c in ipairs(getgenv().allConns) do pcall(function() c:Disconnect() end) end
    getgenv().allConns={}; clearEsp()
    n("kittyware","unloaded")
end

local libReady=false; local Library,SaveManager,ThemeManager; local libStart=tick()

task.spawn(function()
    local repo="https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"
    local ok1,lib=pcall(function() return loadstring(game:HttpGet(repo.."Library.lua"))() end)
    if not ok1 or not lib then n("kittyware","linoria ui library failed to load."); libReady=true; return end
    Library=lib
    local ok2,sm=pcall(function() return loadstring(game:HttpGet(repo.."addons/SaveManager.lua"))() end)
    if ok2 and sm then SaveManager=sm end
    local ok3,tm=pcall(function() return loadstring(game:HttpGet(repo.."addons/ThemeManager.lua"))() end)
    if ok3 and tm then ThemeManager=tm end
    libReady=true
end)

repeat task.wait(0.1) until libReady or (tick()-libStart)>30

if not Library then
    n("kittyware","ui timed out, logic active without ui.")
    return
end

local Window=Library:CreateWindow({Title="kittyware",Center=true,AutoShow=true,TabPadding=8,MenuFadeTime=0.2})
_G.linoria_window=Window
pcall(function() Library:SetMobileEnabled(true) end)

local TabObjs={
    Combat   = Window:AddTab("combat"),
    Visuals  = Window:AddTab("visuals"),
    Character= Window:AddTab("character"),
    Guns     = Window:AddTab("guns"),
    Misc     = Window:AddTab("misc"),
    World    = Window:AddTab("world"),
    Settings = Window:AddTab("settings"),
}

local function updatePlayerList()
    local list={"none"}
    for _,p in ipairs(P:GetPlayers()) do if p~=me then table.insert(list,p.Name) end end
    table.sort(list,function(a,b) if a=="none" then return true end; if b=="none" then return false end; return a<b end)
    return list
end

local function updateConfigList()
    return getgenv().listCfgs()
end

local RageGroup=TabObjs.Combat:AddLeftGroupbox("ragebot")
do
    local t=RageGroup:AddToggle("rage",{Text="ragebot",Default=false,Tooltip="enhanced ragebot: dual-loop fire, multi-part targeting, visible-only filter",
        Callback=function(val) s.rage=val; if val then getgenv().startRage() else getgenv().stopRage() end end})
    Toggles["rage"]=t
end
RageGroup:AddDropdown("RageType",{Text="ragebot type",Default="regular",Values={"regular"},Callback=function(val) s.rageType=val end})
RageGroup:AddDropdown("RageWeapon",{Text="weapon",Default="primary",Values={"primary","secondary","melee"},Callback=function(val) s.rageWep=val end})
RageGroup:AddDropdown("RagePartPriority",{Text="part priority",Default="Head",Values={"Head","HumanoidRootPart","UpperTorso","LowerTorso"},Callback=function(val) s.partPriority=val end})
RageGroup:AddSlider("ShootAttempts",{Text="shoot attempts",Default=10,Min=1,Max=30,Rounding=0,Callback=function(val) s.shootAt=val end})
do local t=RageGroup:AddToggle("multiPart",{Text="multi-part targeting",Default=false,Tooltip="cycles through all body parts to find a hittable one",Callback=function(val) s.multiPart=val end}); Toggles["multiPart"]=t end
do local t=RageGroup:AddToggle("rageVisible",{Text="visible only",Default=false,Tooltip="only shoot when target part is not behind a wall",Callback=function(val) s.rageVisible=val end}); Toggles["rageVisible"]=t end
do local t=RageGroup:AddToggle("rageAutoWall",{Text="auto wall",Default=false,Tooltip="fire even through walls (ignores visible filter)",Callback=function(val) s.rageAutoWall=val end}); Toggles["rageAutoWall"]=t end
do local t=RageGroup:AddToggle("rageSmooth",{Text="smooth fire",Default=false,Tooltip="spreads shots across a small window to appear more human",Callback=function(val) s.rageSmooth=val end}); Toggles["rageSmooth"]=t end
RageGroup:AddSlider("RageSmoothVal",{Text="smooth window (s)",Default=1,Min=0.05,Max=2,Rounding=2,Suffix="s",Callback=function(val) s.rageSmoothVal=val end})
local ragePrioDrop=RageGroup:AddDropdown("RagePriority",{Text="target selector",Default="none",Values=updatePlayerList(),Callback=function(val) s.ragePrio=val=="none" and "" or val end})
P.PlayerAdded:Connect(function() ragePrioDrop:SetValues(updatePlayerList()) end)
P.PlayerRemoving:Connect(function() ragePrioDrop:SetValues(updatePlayerList()) end)
do local t=RageGroup:AddToggle("voidSpam",{Text="voidspam",Default=false,Tooltip="alternates between void and teleportation",Callback=function(val) s.voidSpam=val; if val then getgenv().startVoid() else getgenv().stopVoid() end end}); Toggles["voidSpam"]=t end
RageGroup:AddSlider("VsHideTime",{Text="hide time",Default=0.01,Min=0.01,Max=1,Rounding=2,Suffix="s",Callback=function(val) s.vsHide=val end})

local TpGroup=TabObjs.Combat:AddRightGroupbox("teleportation")
do local t=TpGroup:AddToggle("ttEnabled",{Text="teleportation",Default=false,Tooltip="tracks and teleports to target using ring-buffer position history",Callback=function(val) s.ttEnabled=val; if val then getgenv().startTT() else getgenv().stopTT() end end}); Toggles["ttEnabled"]=t end
TpGroup:AddDropdown("TTMethod",{Text="tracking method",Default="Adaptive",Values={"Adaptive","Predictive"},Callback=function(val) s.ttMethod=val end})
TpGroup:AddDropdown("TTMode",{Text="target mode",Default="Closest",Values={"Closest","Farthest"},Callback=function(val) s.ttMode=val end})
TpGroup:AddDropdown("TTPosition",{Text="position",Default="Front",Values={"Front","Behind","Above","Below","Left","Right","Exact"},Callback=function(val) s.ttPosition=val end})
TpGroup:AddSlider("TTOffsetDist",{Text="offset distance",Default=3,Min=0,Max=50,Rounding=1,Callback=function(val) s.ttOffsetDist=val end})
TpGroup:AddSlider("TTStagger",{Text="predictive stagger",Default=1,Min=0,Max=10,Rounding=1,Callback=function(val) s.ttStagger=val end})
do local t=TpGroup:AddToggle("ttAimLead",{Text="target lead",Default=false,Callback=function(val) s.ttAimLead=val end}); Toggles["ttAimLead"]=t end
local ttPrioDrop=TpGroup:AddDropdown("TTPriority",{Text="target selector",Default="none",Values=updatePlayerList(),Callback=function(val) s.ttPrio=val=="none" and "" or val end})
P.PlayerAdded:Connect(function() ttPrioDrop:SetValues(updatePlayerList()) end)
P.PlayerRemoving:Connect(function() ttPrioDrop:SetValues(updatePlayerList()) end)

-- ── Silent Aim UI ──────────────────────────────────────────────────────────
local AimGroup=TabObjs.Combat:AddLeftGroupbox("silent aim")
local SilentCustom=TabObjs.Combat:AddRightGroupbox("silent aim customization")
do
    local t=AimGroup:AddToggle("silent_toggle",{Text="enable silent aim",Default=false,
        Callback=function(val) s.silent=val end})
    Toggles["silent_toggle"]=t; Toggles["silent"]=t
end
do local t=AimGroup:AddToggle("silent_autoshoot",{Text="auto shoot",Default=false,Callback=function(val) s.silentAutoShoot=val end}); Toggles["silent_autoshoot"]=t end
AimGroup:AddSlider("silent_hitchance",{Text="hit chance",Default=100,Min=0,Max=100,Rounding=0,Compact=true,Callback=function(val) s.silentHitChance=val end})
AimGroup:AddDropdown("silent_hitpart",{Text="hit part",Default="Head",Values=hpL,Callback=function(val) s.silentHitPart=val end})
do local t=AimGroup:AddToggle("silent_fov_outline",{Text="show fov outline",Default=false,Callback=function() end}); Toggles["silent_fov_outline"]=t end
do local t=AimGroup:AddToggle("silent_showfov",{Text="show fov",Default=false,Callback=function() end}); Toggles["silent_showfov"]=t end
do local t=AimGroup:AddToggle("silent_fov_fill",{Text="filled fov",Default=false,Callback=function() end}); Toggles["silent_fov_fill"]=t end
do local t=AimGroup:AddToggle("silent_visualize",{Text="visualize target line",Default=false,Callback=function() end}); Toggles["silent_visualize"]=t end
do local t=SilentCustom:AddToggle("silent_fov_moving",{Text="animate fov",Default=false,Callback=function() end}); Toggles["silent_fov_moving"]=t end
SilentCustom:AddSlider("silent_radius",{Text="fov radius",Default=500,Min=10,Max=1000,Rounding=1,Compact=true,Callback=function(val) s.silentFovRadius=val end})
SilentCustom:AddSlider("silent_fov_lerp",{Text="fov lerp",Default=20,Min=1,Max=100,Rounding=0,Compact=true,Callback=function(val) if Options.silent_fov_lerp then Options.silent_fov_lerp.Value=val/100 end end})
SilentCustom:AddLabel("fov color"):AddColorPicker("silent_color1",{Default=Color3.fromRGB(0,255,0),Callback=function() end})
SilentCustom:AddLabel("fill color"):AddColorPicker("silent_fill_color1",{Default=Color3.fromRGB(0,255,0),Callback=function() end})
SilentCustom:AddLabel("line color"):AddColorPicker("silent_color2",{Default=Color3.fromRGB(0,200,0),Callback=function() end})

-- ── Aimbot UI ──────────────────────────────────────────────────────────────
local AimbotTab=TabObjs.Combat:AddLeftGroupbox("aimbot")
local AimbotCustom=TabObjs.Combat:AddRightGroupbox("aimbot customization")
do
    local t=AimbotTab:AddToggle("aimbot_toggle",{Text="enable aimbot",Default=false,
        Callback=function(val) s.aimbot=val; if val then startAim() else stopAim() end end})
    Toggles["aimbot_toggle"]=t; Toggles["aimbot"]=t
end
do local t=AimbotTab:AddToggle("aimbot_closest_part",{Text="closest part mode",Default=false,Callback=function() end}); Toggles["aimbot_closest_part"]=t end
AimbotTab:AddSlider("aimbot_smoothing",{Text="smoothing",Default=20,Min=1,Max=100,Rounding=0,Compact=true,Callback=function(val) s.aimSmooth=val/100 end})
AimbotTab:AddDropdown("targeting_part",{Text="target part",Default="Head",Values={"Head","HumanoidRootPart","UpperTorso","LowerTorso"},Callback=function(val) s.aimTargetPart=val end})
AimbotTab:AddSlider("aimbot_radius",{Text="fov radius",Default=1000,Min=50,Max=2000,Rounding=0,Compact=true,Callback=function(val) s.aimFovRadius=val end})
AimbotTab:AddDropdown("aimbot_match_axis",{Text="rotation mode",Default="lerp",Values={"lerp","y"},Callback=function(val) end})
do local t=AimbotTab:AddToggle("aimbot_showfov",{Text="show fov",Default=false,Callback=function() end}); Toggles["aimbot_showfov"]=t end
do local t=AimbotTab:AddToggle("aimbot_fov_fill",{Text="filled fov",Default=false,Callback=function() end}); Toggles["aimbot_fov_fill"]=t end
do local t=AimbotTab:AddToggle("aimbot_fov_moving",{Text="animate fov",Default=false,Callback=function() end}); Toggles["aimbot_fov_moving"]=t end
AimbotCustom:AddSlider("aimbot_fov_lerp",{Text="fov lerp",Default=20,Min=1,Max=100,Rounding=0,Compact=true,Callback=function(val) if Options.aimbot_fov_lerp then Options.aimbot_fov_lerp.Value=val/100 end end})
AimbotCustom:AddLabel("fov color"):AddColorPicker("aimbot_color1",{Default=Color3.fromRGB(255,0,0),Callback=function() end})
AimbotCustom:AddLabel("fill color"):AddColorPicker("aimbot_fill_color1",{Default=Color3.fromRGB(255,0,0),Callback=function() end})
do
    local t = AimbotCustom:AddLabel("Aimbot Keybind"):AddKeyPicker("aimbot_keybind", {
        Text = "hold key",
        Default = "None",
        Mode = "Hold",
        Callback = function() end
    })

    Options["aimbot_keybind"] = t
end

-- ── Triggerbot UI ──────────────────────────────────────────────────────────
local TrigGroup=TabObjs.Combat:AddLeftGroupbox("triggerbot")
do
    local t=TrigGroup:AddToggle("triggerbot_enabled",{Text="triggerbot",Default=false,
        Callback=function(val) s.trig=val; if val then startTrig() else getgenv().stopTrig() end end})
    Toggles["triggerbot_enabled"]=t; Toggles["trig"]=t
end
TrigGroup:AddSlider("triggerbot_reaction_time",{Text="reaction time",Default=0,Min=0,Max=500,Rounding=0,Suffix="ms",Callback=function(val) s.trigReact=val end})
TrigGroup:AddSlider("triggerbot_reaction_time_offset",{Text="reaction offset",Default=0,Min=0,Max=200,Rounding=0,Suffix="ms",Callback=function() end})
TrigGroup:AddSlider("triggerbot_shoot_delay",{Text="shoot delay",Default=0,Min=0,Max=200,Rounding=0,Suffix="ms",Callback=function() end})
TrigGroup:AddSlider("triggerbot_max_distance",{Text="max distance",Default=9999,Min=50,Max=9999,Rounding=0,Suffix=" studs",Callback=function(val) s.trigMaxDist=val end})
do
    local t = TrigGroup:AddLabel("Triggerbot Keybind"):AddKeyPicker("triggerbot_keybind", {
        Text = "hold key",
        Default = "None",
        Mode = "Always",
        Callback = function() end
    })

    Options["triggerbot_keybind"] = t
end

local VisLeft=TabObjs.Visuals:AddLeftGroupbox("esp")
do local t=VisLeft:AddToggle("espName",{Text="names",Default=false,Callback=function(v) s.espName=v end}); Toggles["espName"]=t end
VisLeft:AddSlider("EspNamesSize",{Text="names size",Default=18,Min=8,Max=30,Rounding=0,Callback=function(v) s.espNameS=v end})
do local t=VisLeft:AddToggle("espHp",{Text="health",Default=false,Callback=function(v) s.espHp=v end}); Toggles["espHp"]=t end
VisLeft:AddSlider("EspHealthSize",{Text="health size",Default=14,Min=8,Max=30,Rounding=0,Callback=function(v) s.espHpS=v end})
do local t=VisLeft:AddToggle("espBox",{Text="boxes",Default=false,Callback=function(v) s.espBox=v end}); Toggles["espBox"]=t end
VisLeft:AddSlider("EspBoxesThickness",{Text="boxes thickness",Default=2,Min=1,Max=5,Rounding=0,Callback=function(v) s.espBoxT=v end})
do local t=VisLeft:AddToggle("espTrace",{Text="tracers",Default=false,Callback=function(v) s.espTrace=v end}); Toggles["espTrace"]=t end
VisLeft:AddSlider("EspTracersThickness",{Text="tracers thickness",Default=2,Min=1,Max=5,Rounding=0,Callback=function(v) s.espTraceT=v end})
do local t=VisLeft:AddToggle("espSkelly",{Text="skeleton",Default=false,Callback=function(v) s.espSkelly=v end}); Toggles["espSkelly"]=t end
VisLeft:AddSlider("EspSkeletonThickness",{Text="skeleton thickness",Default=2,Min=1,Max=5,Rounding=0,Callback=function(v) s.espSkellyT=v end})
do local t=VisLeft:AddToggle("espDist",{Text="distance",Default=false,Callback=function(v) s.espDist=v end}); Toggles["espDist"]=t end
do local t=VisLeft:AddToggle("espTeam",{Text="team colors",Default=false,Callback=function(v) s.espTeam=v end}); Toggles["espTeam"]=t end

local VisRight=TabObjs.Visuals:AddRightGroupbox("chams")
do local t=VisRight:AddToggle("espChams",{Text="enable chams",Default=false,Callback=function(v) s.espChams=v end}); Toggles["espChams"]=t end

local VisColorLeft=TabObjs.Visuals:AddLeftGroupbox("colors")
VisColorLeft:AddLabel("names color"):AddColorPicker("EspNamesColor",{Default=Color3.fromRGB(255,255,255),Title="names color",Callback=function(v) s.espNameCol=v end})
VisColorLeft:AddLabel("health color"):AddColorPicker("EspHealthColor",{Default=Color3.fromRGB(0,255,0),Title="health color",Callback=function(v) s.espHpCol=v end})
VisColorLeft:AddLabel("boxes color"):AddColorPicker("EspBoxesColor",{Default=Color3.fromRGB(0,255,0),Title="boxes color",Callback=function(v) s.espBoxCol=v end})
VisColorLeft:AddLabel("tracers color"):AddColorPicker("EspTracersColor",{Default=Color3.fromRGB(255,0,0),Title="tracers color",Callback=function(v) s.espTraceCol=v end})
VisColorLeft:AddLabel("skeleton color"):AddColorPicker("EspSkeletonColor",{Default=Color3.fromRGB(255,255,255),Title="skeleton color",Callback=function(v) s.espSkellyCol=v end})
VisColorLeft:AddLabel("distance color"):AddColorPicker("EspDistanceColor",{Default=Color3.fromRGB(255,255,0),Title="distance color",Callback=function(v) s.espDistCol=v end})
VisColorLeft:AddLabel("chams color"):AddColorPicker("EspChamsColor",{Default=Color3.fromRGB(0,255,0),Title="chams color",Callback=function(v) s.espChamsCol=v end})

local CharLeft=TabObjs.Character:AddLeftGroupbox("anti aim")
do local t=CharLeft:AddToggle("aa",{Text="enable anti aim",Default=false,Tooltip="scrambles character orientation",Callback=function(val) s.aa=val; if val then getgenv().startAa() else getgenv().stopAa() end end}); Toggles["aa"]=t end
CharLeft:AddDropdown("AntiAimMethod",{Text="method",Default="Desync",Values={"Static","Spin","Jitter","Desync","Sway","Orbit","Custom"},Callback=function(v) s.aaMeth=v end})
CharLeft:AddSlider("AntiAimSpinSpeed",{Text="spin speed",Default=999999,Min=100,Max=999999,Rounding=0,Callback=function(v) s.aaSpin=v end})
CharLeft:AddSlider("AntiAimYaw",{Text="yaw",Default=180,Min=0,Max=360,Rounding=0,Callback=function(v) s.aaYaw=v end})
CharLeft:AddSlider("AntiAimPitch",{Text="pitch",Default=90,Min=0,Max=360,Rounding=0,Callback=function(v) s.aaPitch=v end})
CharLeft:AddSlider("AntiAimRoll",{Text="roll",Default=180,Min=0,Max=360,Rounding=0,Callback=function(v) s.aaRoll=v end})

local GunsLeft=TabObjs.Guns:AddLeftGroupbox("guns")
do local t=GunsLeft:AddToggle("noSpread",{Text="no spread",Default=false,Callback=function(v) s.noSpread=v end}); Toggles["noSpread"]=t end
do local t=GunsLeft:AddToggle("noRecoil",{Text="no recoil",Default=false,Callback=function(v) s.noRecoil=v end}); Toggles["noRecoil"]=t end
do local t=GunsLeft:AddToggle("noMuzzle",{Text="no muzzle flash",Default=false,Callback=function(val) s.noMuzzle=val; if val then getgenv().startMuzzle() else getgenv().stopMuzzle() end end}); Toggles["noMuzzle"]=t end
do local t=GunsLeft:AddToggle("rapid",{Text="rapid fire",Default=false,Callback=function(val) s.rapid=val; if val then getgenv().startRapid() else getgenv().stopRapid() end end}); Toggles["rapid"]=t end
local MiscLeft=TabObjs.Misc:AddLeftGroupbox("auto ban")
do local t=MiscLeft:AddToggle("autoBan",{Text="enable auto ban",Default=false,Callback=function(val) s.autoBan=val; if val then getgenv().startAb() else getgenv().stopAb() end end}); Toggles["autoBan"]=t end
MiscLeft:AddDropdown("AutoBanWeapon1",{Text="ban weapon slot 1",Default="Katana",Values=rWeaps,Callback=function(v) s.autoBanW1=v end})
MiscLeft:AddDropdown("AutoBanWeapon2",{Text="ban weapon slot 2",Default="Flamethrower",Values=rWeaps,Callback=function(v) s.autoBanW2=v end})

local MiscMiddle=TabObjs.Misc:AddRightGroupbox("auto queue")
do local t=MiscMiddle:AddToggle("autoQ",{Text="auto queue",Default=false,Callback=function(val) s.autoQ=val; if val then getgenv().startAq() else getgenv().stopAq() end end}); Toggles["autoQ"]=t end
MiscMiddle:AddDropdown("QueueMode",{Text="queue mode",Default="Ranked 1v1",Values=rQs,Callback=function(v) s.qMode=v end})

local MiscRight=TabObjs.Misc:AddRightGroupbox("automation")
do local t=MiscRight:AddToggle("autoChoose",{Text="auto choose",Default=false,Callback=function(val) s.autoChoose=val; if val then getgenv().startAc() else getgenv().stopAc() end end}); Toggles["autoChoose"]=t end
MiscRight:AddDropdown("AutoChooseWeapon1",{Text="choose weapon slot 1",Default="Katana",Values=rWeaps,Callback=function(v) s.autoChooseW1=v end})
MiscRight:AddDropdown("AutoChooseWeapon2",{Text="choose weapon slot 2",Default="Knife",Values=rWeaps,Callback=function(v) s.autoChooseW2=v end})
do local t=MiscRight:AddToggle("antiAfk",{Text="anti afk",Default=false,Callback=function(val) s.antiAfk=val; if val then getgenv().startAfk() else getgenv().stopAfk() end end}); Toggles["antiAfk"]=t end
do local t=MiscRight:AddToggle("ffaHop",{Text="ffa server hopping",Default=false,Callback=function(val) s.ffaHop=val end}); Toggles["ffaHop"]=t end

local RiotGroup=TabObjs.Misc:AddLeftGroupbox("riot abuser")
do
    local t=RiotGroup:AddToggle("riotAbuse",{Text="riot abuser",Default=false,Tooltip="spins and jitters position to block shots",
        Callback=function(val)
            s.riotAbuse=val
            if val then
                if getgenv()._riotAbuseConn then getgenv()._riotAbuseConn:Disconnect() end
                local t0=tick(); local seed=math.random(1000,9999)
                getgenv()._riotAbuseConn=RSvc.Heartbeat:Connect(function(dt)
                    if not s.riotAbuse then return end
                    local hrp=getgenv().getHrp(me); if not hrp then return end
                    local t2=tick()-t0; local sm=s.riotSpin or 1000000000000
                    local yaw=math.rad(sm*dt); local pitch=math.rad(sm*0.37*dt*math.sin(t2*3.1)); local roll=math.rad(sm*0.19*dt*math.cos(t2*5.7+seed))
                    local spinCF=hrp.CFrame*CFrame.Angles(pitch,yaw,roll)
                    local spread=(s.riotDist or 500)/300
                    local jX=(math.random()-0.5)*(s.riotX or 50)*spread*2+math.noise(t2*9,seed,0)*(s.riotX or 50)*spread
                    local jY=(math.random()-0.5)*(s.riotY or 15)*spread+math.noise(0,t2*9,seed)*(s.riotY or 15)*spread*0.3
                    local jZ=(math.random()-0.5)*(s.riotZ or 50)*spread*2+math.noise(0,0,t2*9+seed)*(s.riotZ or 50)*spread
                    hrp.CFrame=spinCF+Vector3.new(jX,math.max(spinCF.Position.Y+jY,2)-spinCF.Position.Y,jZ)
                end)
            else
                if getgenv()._riotAbuseConn then getgenv()._riotAbuseConn:Disconnect(); getgenv()._riotAbuseConn=nil end
            end
        end
    })
    Toggles["riotAbuse"]=t
end
RiotGroup:AddSlider("RiotAbuserDistance",{Text="distance",Default=500,Min=100,Max=2000,Rounding=0,Callback=function(v) s.riotDist=v end})
RiotGroup:AddSlider("RiotAbuserX",{Text="x jitter",Default=50,Min=1,Max=500,Rounding=0,Callback=function(v) s.riotX=v end})
RiotGroup:AddSlider("RiotAbuserY",{Text="y jitter",Default=15,Min=1,Max=200,Rounding=0,Callback=function(v) s.riotY=v end})
RiotGroup:AddSlider("RiotAbuserZ",{Text="z jitter",Default=50,Min=1,Max=500,Rounding=0,Callback=function(v) s.riotZ=v end})
RiotGroup:AddSlider("RiotAbuserSpin",{Text="spin speed",Default=1000000000000,Min=0,Max=1000000000000,Rounding=0,Callback=function(v) s.riotSpin=v end})

-- RIOT BYPASS
local RiotBypassGroup=TabObjs.Misc:AddRightGroupbox("riot bypass")
local rbTargetLabel=nil
do
    local t=RiotBypassGroup:AddToggle("riotBypass",{Text="riot bypass",Default=false,Tooltip="smoothly positions you behind the nearest enemy",
        Callback=function(val)
            s.riotBypass=val
            if val then
                local rbLastUpdate=0; local rbCurrentTarget=nil
                local function findRiotTarget()
                    local hrp=getgenv().getHrp(me); if not hrp then return nil end
                    local closest,closestDist=nil,math.huge
                    for _,plr in ipairs(P:GetPlayers()) do
                        if plr~=me and plr.Character then
                            local tHrp=plr.Character:FindFirstChild("HumanoidRootPart")
                            local hum=plr.Character:FindFirstChildOfClass("Humanoid")
                            if tHrp and hum and hum.Health>0 and(me.Team==nil or plr.Team==nil or me.Team~=plr.Team) then
                                local dist2=(hrp.Position-tHrp.Position).Magnitude
                                if dist2<closestDist then closestDist=dist2; closest=plr end
                            end
                        end
                    end
                    return closest
                end
                if getgenv()._riotBypassConn then getgenv()._riotBypassConn:Disconnect() end
                getgenv()._riotBypassConn=RSvc.Heartbeat:Connect(function()
                    if not s.riotBypass then return end
                    if tick()-rbLastUpdate>(s.riotBypassRate or 0.1) then
                        rbCurrentTarget=findRiotTarget(); rbLastUpdate=tick()
                        if rbTargetLabel then rbTargetLabel:SetText(rbCurrentTarget and "target: "..rbCurrentTarget.Name or "target: none") end
                    end
                    if not rbCurrentTarget or not rbCurrentTarget.Character then return end
                    local hrp=getgenv().getHrp(me); if not hrp then return end
                    local targetRoot=rbCurrentTarget.Character:FindFirstChild("HumanoidRootPart"); if not targetRoot then return end
                    local targetPos=targetRoot.Position; local targetLook=targetRoot.CFrame.LookVector
                    local behindPos=targetPos-targetLook*(s.riotBypassDist or 3)+Vector3.new(0,s.riotBypassH or 5,0)
                    local tweenInfo=TweenInfo.new(s.riotBypassRate or 0.1,Enum.EasingStyle.Linear)
                    local tween=T:Create(hrp,tweenInfo,{CFrame=CFrame.new(behindPos)}); tween:Play()
                end)
            else
                if getgenv()._riotBypassConn then getgenv()._riotBypassConn:Disconnect(); getgenv()._riotBypassConn=nil end
                if rbTargetLabel then rbTargetLabel:SetText("target: none") end
            end
        end
    })
    Toggles["riotBypass"]=t
end
RiotBypassGroup:AddSlider("RiotBypassDistance",{Text="distance behind",Default=3,Min=0,Max=50,Rounding=1,Callback=function(v) s.riotBypassDist=v end})
RiotBypassGroup:AddSlider("RiotBypassHeight",{Text="height offset",Default=5,Min=-20,Max=20,Rounding=1,Callback=function(v) s.riotBypassH=v end})
RiotBypassGroup:AddSlider("RiotBypassUpdateRate",{Text="update rate",Default=1,Min=1,Max=50,Rounding=0,Callback=function(v) s.riotBypassRate=v/10 end})
rbTargetLabel=RiotBypassGroup:AddLabel("target: none")

-- AUTO LOAD
local AutoLoadGroup=TabObjs.Misc:AddLeftGroupbox("auto load")
do local t=AutoLoadGroup:AddToggle("autoLoad",{Text="autoload configuration",Default=false,Callback=function(val) s.autoLoad=val end}); Toggles["autoLoad"]=t end
do
    local t=AutoLoadGroup:AddToggle("autoExec",{Text="autoload script on rejoin",Default=false,
        Callback=function(val)
            s.autoExec=val
            getgenv()._kittyAutoExec=val
            if not val and getgenv()._kittyAutoExecConn then getgenv()._kittyAutoExecConn:Disconnect(); getgenv()._kittyAutoExecConn=nil end
        end
    })
    Toggles["autoExec"]=t
end

local WorldLeft=TabObjs.World:AddLeftGroupbox("color correction")
local cc=L:FindFirstChildOfClass("ColorCorrectionEffect")
local function getCC()
    if not cc or not cc.Parent then cc=L:FindFirstChildOfClass("ColorCorrectionEffect"); if not cc then cc=Instance.new("ColorCorrectionEffect"); cc.Parent=L end end
    return cc
end
WorldLeft:AddToggle("CCEnabled",{Text="enabled",Default=false,Callback=function(v) getCC().Enabled=v end})
WorldLeft:AddSlider("CCSaturation",{Text="saturation",Default=50,Min=-100,Max=100,Rounding=0,Callback=function(v) getCC().Saturation=v/10 end})
WorldLeft:AddSlider("CCContrast",{Text="contrast",Default=50,Min=-100,Max=100,Rounding=0,Callback=function(v) getCC().Contrast=v/10 end})
WorldLeft:AddSlider("CCBrightness",{Text="brightness",Default=50,Min=-100,Max=100,Rounding=0,Callback=function(v) getCC().Brightness=v/100 end})

local WorldRight=TabObjs.World:AddRightGroupbox("atmosphere")
local atmo=L:FindFirstChildOfClass("Atmosphere")
local function getAtmo()
    if not atmo or not atmo.Parent then atmo=L:FindFirstChildOfClass("Atmosphere"); if not atmo then atmo=Instance.new("Atmosphere"); atmo.Parent=L end end
    return atmo
end
WorldRight:AddToggle("AtmoEnabled",{Text="enabled",Default=false,Callback=function(v) if not v then local a=getAtmo(); a.Density=0; a.Haze=0; a.Glare=0; a.Offset=0 end end})
WorldRight:AddLabel("color"):AddColorPicker("AtmoColor",{Default=Color3.fromRGB(255,255,255),Callback=function(v) getAtmo().Color=v end})
WorldRight:AddLabel("decay"):AddColorPicker("AtmoDecay",{Default=Color3.fromRGB(255,255,255),Callback=function(v) getAtmo().Decay=v end})
WorldRight:AddSlider("AtmoGlare",{Text="glare",Default=50,Min=0,Max=100,Rounding=0,Callback=function(v) getAtmo().Glare=v/10 end})
WorldRight:AddSlider("AtmoHaze",{Text="haze",Default=50,Min=0,Max=100,Rounding=0,Callback=function(v) getAtmo().Haze=v end})
WorldRight:AddSlider("AtmoOffset",{Text="offset",Default=50,Min=0,Max=100,Rounding=0,Callback=function(v) getAtmo().Offset=v/100 end})
WorldRight:AddSlider("AtmoDensity",{Text="density",Default=50,Min=0,Max=100,Rounding=0,Callback=function(v) getAtmo().Density=v/100 end})

local WorldRight2=TabObjs.World:AddRightGroupbox("lighting")
WorldRight2:AddToggle("LAmbient",{Text="ambient",Default=false,Callback=function(v) if not v then L.Ambient=Color3.fromRGB(70,70,70) end end})
WorldRight2:AddLabel("ambient color"):AddColorPicker("LAmbientColor",{Default=Color3.fromRGB(255,255,255),Callback=function(v) L.Ambient=v end})
WorldRight2:AddToggle("LColorShiftBottom",{Text="color shift bottom",Default=false,Callback=function(v) if not v then L.ColorShift_Bottom=Color3.fromRGB(0,0,0) end end})
WorldRight2:AddLabel("color shift bottom"):AddColorPicker("LCSBColor",{Default=Color3.fromRGB(255,255,255),Callback=function(v) L.ColorShift_Bottom=v end})
WorldRight2:AddToggle("LColorShiftTop",{Text="color shift top",Default=false,Callback=function(v) if not v then L.ColorShift_Top=Color3.fromRGB(0,0,0) end end})
WorldRight2:AddLabel("color shift top"):AddColorPicker("LCSTColor",{Default=Color3.fromRGB(255,255,255),Callback=function(v) L.ColorShift_Top=v end})
WorldRight2:AddToggle("LFogColor",{Text="fog color",Default=false,Callback=function(v) if not v then L.FogColor=Color3.fromRGB(192,192,192) end end})
WorldRight2:AddLabel("fog color"):AddColorPicker("LFogColorPicker",{Default=Color3.fromRGB(200,200,200),Callback=function(v) L.FogColor=v end})
WorldRight2:AddToggle("LFogEnd",{Text="fog end",Default=false,Callback=function(v) if not v then L.FogEnd=100000 end end})
WorldRight2:AddSlider("LFogEndVal",{Text="fog end",Default=2510,Min=0,Max=10000,Rounding=0,Suffix="studs",Callback=function(v) L.FogEnd=v end})
WorldRight2:AddToggle("LFogStart",{Text="fog start",Default=false,Callback=function(v) if not v then L.FogStart=0 end end})
WorldRight2:AddSlider("LFogStartVal",{Text="fog start",Default=0,Min=0,Max=5000,Rounding=0,Suffix="studs",Callback=function(v) L.FogStart=v end})
WorldRight2:AddToggle("LExposure",{Text="exposure compensation",Default=false,Callback=function(v) if not v then L.ExposureCompensation=0 end end})
WorldRight2:AddSlider("LExposureVal",{Text="exposure compensation",Default=-11,Min=-100,Max=100,Rounding=0,Callback=function(v) L.ExposureCompensation=v/10 end})
WorldRight2:AddToggle("LBrightness",{Text="brightness",Default=false,Callback=function(v) if not v then L.Brightness=2 end end})
WorldRight2:AddSlider("LBrightnessVal",{Text="brightness",Default=17,Min=0,Max=50,Rounding=0,Callback=function(v) L.Brightness=v/10 end})
WorldRight2:AddToggle("LClockTime",{Text="clock time",Default=false,Callback=function(v) if not v then L.ClockTime=14 end end})
WorldRight2:AddSlider("LClockTimeVal",{Text="clock time",Default=114,Min=0,Max=240,Rounding=0,Suffix="h",Callback=function(v) L.ClockTime=v/10 end})
WorldRight2:AddToggle("LGlobalShadows",{Text="global shadows",Default=false,Callback=function(v) L.GlobalShadows=v end})
WorldRight2:AddDropdown("LTechnology",{Text="technology",Values={"Compatibility","Voxel","ShadowMap","Future"},Default="ShadowMap",Callback=function(v) L.Technology=Enum.Technology[v] end})

local SettingsLeft=TabObjs.Settings:AddLeftGroupbox("settings")
SettingsLeft:AddButton({Text="unload kittyware",Func=function() getgenv().unloadAll() end})
SettingsLeft:AddButton({Text="display keybinds",Func=function() Library:SetKeybindMenuOpen(true) end})

local configDropdown=SettingsLeft:AddDropdown("ConfigSelection",{
    Text="select config",Default="default",Values=updateConfigList(),
    Callback=function(val) s.config_selection=val end
})

local function refreshConfigList()
    local list=updateConfigList(); configDropdown:SetValues(list)
    local sel=s.config_selection
    if sel and table.find(list,sel) then configDropdown:SetValue(sel)
    elseif #list>0 then configDropdown:SetValue(list[1]) end
end

SettingsLeft:AddButton({Text="save config",Func=function()
    local name=s.config_selection or "default"
    if name~="" then getgenv().saveCfg(name); refreshConfigList() else n("config","select a config first") end
end})
SettingsLeft:AddButton({Text="overwrite config",Func=function()
    local name=s.config_selection or "default"
    if name~="" then getgenv().overwriteCfg(name); refreshConfigList() else n("config","select a config first") end
end})
SettingsLeft:AddButton({Text="load selected config",Func=function()
    local name=s.config_selection or "default"
    if name~="" then getgenv().loadCfg(name); refreshConfigList() else n("config","select a config first") end
end})
SettingsLeft:AddButton({Text="delete config",Func=function()
    local name=s.config_selection or ""
    if name~="" and name~="default" then getgenv().delCfg(name); refreshConfigList()
    else n("config","cannot delete default or empty selection") end
end})

local listLabel=SettingsLeft:AddLabel("configs: none")
local function updateListLabel()
    local cfgs=getgenv().listCfgs()
    listLabel:SetText("configs: "..(#cfgs>0 and table.concat(cfgs,", ") or "none"))
end

SettingsLeft:AddButton({Text="refresh list",Func=function()
    updateListLabel(); refreshConfigList(); n("config","list refreshed")
end})

if not isMobile then
    SettingsLeft:AddLabel("Menu Toggle Key"):AddKeyPicker("MenuToggleKeybind", {
        Text = "toggle menu",
        Default = "RightShift",
        Mode = "Toggle",
        Callback = function(state)
            if state then
                pcall(function()
                    Library:ToggleWindowVisibility()
                end)
            end
        end
    })

    SettingsLeft:AddLabel("Menu Lock Key"):AddKeyPicker("MenuLockKeybind", {
        Text = "lock menu",
        Default = "Delete",
        Mode = "Toggle",
        Callback = function(state)
            if state then
                pcall(function()
                    Library:ToggleLock()
                end)
            end
        end
    })
else
    SettingsLeft:AddLabel("Menu Toggle Key"):AddKeyPicker("MenuToggleKeybind", {
        Text = "toggle menu",
        Default = "None",
        Mode = "Toggle",
        Callback = function(state)
            if state then
                pcall(function()
                    Library:ToggleWindowVisibility()
                end)
            end
        end
    })
end

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("kittyware-themes")
    ThemeManager:ApplyToTab(TabObjs.Settings)
end

task.spawn(function()
    while task.wait(1) do
        -- Anti-stuck
        if s.antiStuck and me.Character then
            local hrp=me.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position.Y<-100 then hrp.CFrame=CFrame.new(0,10,0) end
        end
        -- Chams
        if s.espChams then
            for _,plr in ipairs(P:GetPlayers()) do
                if plr~=me and plr.Character then
                    for _,part in ipairs(plr.Character:GetChildren()) do
                        if part:IsA("BasePart") and not part:FindFirstChild("ChamsColor") then
                            local color=Instance.new("ColorCorrectionEffect"); color.Name="ChamsColor"; color.Parent=part
                        end
                    end
                end
            end
        else
            for _,plr in ipairs(P:GetPlayers()) do
                if plr and plr.Character then
                    for _,part in ipairs(plr.Character:GetChildren()) do
                        if part:IsA("BasePart") then local ch=part:FindFirstChild("ChamsColor"); if ch then ch:Destroy() end end
                    end
                end
            end
        end
    end
end)

local function handleAutoload()
    if not s.autoLoad then return end
    local cfgs=getgenv().listCfgs()
    for _,cfgName in ipairs(cfgs) do
        local path=cfgFolder.."/"..cfgName..".json"
        local ok,raw=pcall(readfile,path)
        if ok and raw then
            local s2,d=pcall(HS.JSONDecode,HS,raw)
            if s2 and d and d.AutoLoadConfig and d.LastLoadedConfig then
                if getgenv().loadCfg(d.LastLoadedConfig) then pcall(refreshConfigList); return end
            end
        end
    end
end

pcall(handleAutoload)
pcall(refreshConfigList)
pcall(updateListLabel)