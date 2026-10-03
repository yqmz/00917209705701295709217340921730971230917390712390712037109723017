local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local hookmetamethod = hookmetamethod
local getrawmetatable = getrawmetatable
local setreadonly = setreadonly
local checkcaller = checkcaller
local getnamecallmethod = getnamecallmethod
local getconnections = getconnections

local mt = getrawmetatable(game)
setreadonly(mt, false)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "Kick" and self == LocalPlayer then
        return
    end
    if method == "FireServer" or method == "InvokeServer" then
        local name = self.Name:lower()
        if name:find("exploit") or name:find("cheat") or
           name:find("detect") or name:find("ban") or
           name:find("flag") or name:find("validate") or
           name:find("integrity") or name:find("security") or
           name:find("anticheat") or name:find("ac_") then
            return
        end
    end
    return oldNamecall(self, ...)
end)

setreadonly(mt, true)

local function nukeConnections()
    if not getconnections then return end
    pcall(function()
        for _, conn in ipairs(getconnections(LocalPlayer.CharacterAdded)) do
            if not checkcaller() then
                conn:Disable()
            end
        end
    end)
    pcall(function()
        for _, conn in ipairs(getconnections(LocalPlayer.PlayerGui.ChildAdded)) do
            if not checkcaller() then
                conn:Disable()
            end
        end
    end)
end
nukeConnections()

ReplicatedStorage.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        local name = obj.Name:lower()
        if name:find("exploit") or name:find("cheat") or
           name:find("detect") or name:find("ban") or
           name:find("flag") or name:find("validate") or
           name:find("integrity") or name:find("security") or
           name:find("anticheat") or name:find("ac_") then
            pcall(function() obj:Destroy() end)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    nukeConnections()
end)

local oldIndex
oldIndex = hookmetamethod(game, "__index", function(self, key)
    if checkcaller() and key == "Kick" and self == LocalPlayer then
        return function() end
    end
    return oldIndex(self, key)
end)

task.spawn(function()
    pcall(function()

        local _stbl
        _stbl = hookfunction(getrenv().setmetatable, newcclosure(function(tbl, mt)
            if mt and typeof(mt) == "table" and rawget(mt, "__mode") == "kv" then
                local tr = debug.traceback()
                if tr:find("MiscellaneousController") then
                    return _stbl({1,2,3}, {})
                end
            end
            return _stbl(tbl, mt)
        end))
    end)

    pcall(function()
        local function _procAC(o)
            pcall(function()
                if o:IsA("LocalScript") or o:IsA("ModuleScript") then
                    local _s, nm = pcall(function() return o.Name:lower() end)
                    if not _s or not nm then return end
                    local _tags = {"anticheat","ac","detection","ban","kick","security","moderation"}
                    for _i = 1, #_tags do
                        if nm:find(_tags[_i]) then
                            pcall(function() o.Disabled = true end)
                            break
                        end
                    end
                end
            end)
        end

        pcall(function()
            for _, o in ipairs(game:GetDescendants()) do
                _procAC(o)
            end
        end)

        pcall(function() game.DescendantAdded:Connect(_procAC) end)
    end)

    pcall(function()
        local _nc = game:GetService("NetworkClient")
        if not _nc then return end
        _nc.ChildAdded:Connect(function(ch)
            pcall(function()
                local _ok, _n = pcall(function() return ch.Name:lower() end)
                if _ok and _n then
                    if _n:find("anticheat") or _n:find("detection") then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end)
        end)
    end)

    pcall(function()
        local _rf = game:GetService("ReplicatedFirst")
        local _tgt = _rf:WaitForChild("LocalScript3", 10)
        local _gc = getgc(false)
        for _i = 1, #_gc do
            local _fn = _gc[_i]
            if type(_fn) ~= "function" then continue end
            local _ok1, _env = pcall(getfenv, _fn)
            if not _ok1 or type(_env) ~= "table" then continue end
            local _ok2, _scr = pcall(function() return rawget(_env, "script") end)
            if not _ok2 or not _scr or typeof(_scr) ~= "Instance" then continue end
            if _scr ~= _tgt then continue end
            local _ok4, _consts = pcall(debug.getconstants, _fn)
            if not _ok4 or type(_consts) ~= "table" then continue end
            for _j = 1, #_consts do
                local _c = _consts[_j]
                if type(_c) == "string" and (_c:find("TakeTheL") or _c:find("ban") or _c:find("kick")) then
                    pcall(function() hookfunction(_fn, function() end) end)
                    break
                end
            end
        end
    end)
end)

-- Fake "ClientAlert" event to intercept server kick/ban attempts
local _fakeEv
pcall(function()
    _fakeEv = Instance.new("RemoteEvent")
    _fakeEv.Name = "ClientAlert"
    _fakeEv.Parent = game:GetService("Players").LocalPlayer
end)

local CosmeticUnlocker = {
    Enabled = false,
    _active = false,
}

getgenv()._ZX_SetupCosmeticUnlocker = function()
    local _plrs    = game:GetService("Players")
    local _rs      = game:GetService("ReplicatedStorage")
    local _http    = game:GetService("HttpService")
    local _lp      = _plrs.LocalPlayer
    local _pscripts = _lp.PlayerScripts
    local _ctrl    = _pscripts:WaitForChild("Controllers", 30)
    local _mods    = _rs:WaitForChild("Modules", 30)

    local _enumLib = require(_mods:WaitForChild("EnumLibrary", 10))
    if _enumLib then pcall(function() _enumLib:WaitForEnumBuilder() end) end

    local _cosLib  = require(_mods:WaitForChild("CosmeticLibrary", 10))
    local _itmLib  = require(_mods:WaitForChild("ItemLibrary", 10))
    local _datCtrl = require(_ctrl:WaitForChild("PlayerDataController", 10))

    local _eq, _favs = {}, {}
    local _buildingWep, _viewProf = nil, nil
    local _lastWep = nil

    local function _mkCosmetic(nm, ctype, opts)
        local _base = _cosLib.Cosmetics[nm]
        if not _base then return nil end
        local _d = {}
        for k, v in pairs(_base) do _d[k] = v end
        _d.Name = nm
        _d.Type = _d.Type or ctype
        _d.Seed = _d.Seed or math.random(1, 1000000)
        if _enumLib then
            local _s, _eid = pcall(_enumLib.ToEnum, _enumLib, nm)
            if _s and _eid then
                _d.Enum = _eid
                _d.ObjectID = _d.ObjectID or _eid
            end
        end
        if opts then
            if opts.inverted ~= nil then _d.Inverted = opts.inverted end
            if opts.favoritesOnly ~= nil then _d.OnlyUseFavorites = opts.favoritesOnly end
        end
        return _d
    end

    local _cfgFile = "rivals_unlocker_config.json"
    local _saveLock = false

    local function _stripForSave()
        local _out = {}
        for wn, cos in pairs(_eq) do
            _out[wn] = {}
            for ct, cd in pairs(cos) do
                if cd and cd.Name then
                    _out[wn][ct] = {
                        Name = cd.Name,
                        Inverted = cd.Inverted,
                        OnlyUseFavorites = cd.OnlyUseFavorites
                    }
                end
            end
        end
        return { equipped = _out, favorites = _favs }
    end

    local function _loadCfg()
        if not isfile or not readfile then return end
        local _ok1, _ex = pcall(isfile, _cfgFile)
        if not _ok1 or not _ex then return end
        local _ok2, _raw = pcall(readfile, _cfgFile)
        if not _ok2 or not _raw or _raw == "" then return end
        local _ok3, _dec = pcall(_http.JSONDecode, _http, _raw)
        if not _ok3 or not _dec then return end
        if _dec.favorites then _favs = _dec.favorites end
        if _dec.equipped then
            _eq = {}
            for wn, cos in pairs(_dec.equipped) do
                _eq[wn] = {}
                for ct, sd in pairs(cos) do
                    if sd and sd.Name and _cosLib.Cosmetics[sd.Name] then
                        local _cloned = _mkCosmetic(sd.Name, ct, {
                            inverted = sd.Inverted,
                            favoritesOnly = sd.OnlyUseFavorites
                        })
                        if _cloned then _eq[wn][ct] = _cloned end
                    end
                end
                if not next(_eq[wn]) then _eq[wn] = nil end
            end
        end
    end

    local function _saveCfg()
        if not writefile or _saveLock then return end
        _saveLock = true
        task.spawn(function()
            task.wait(1)
            local _payload = _stripForSave()
            local _ok, _enc = pcall(_http.JSONEncode, _http, _payload)
            if _ok then pcall(writefile, _cfgFile, _enc) end
            _saveLock = false
        end)
    end

    _loadCfg()

    local _cosTypes = {"Skin","Wrap","Charm","Dance","Emote"}
    local function _isCosType(cosObj)
        if not cosObj then return false end
        for _, t in ipairs(_cosTypes) do
            if cosObj.Type == t then return true end
        end
        return false
    end

    _cosLib.OwnsCosmeticNormally = function(self, inv, nm, wep)
        local c = _cosLib.Cosmetics[nm]
        if c and c.Type == "Skin" then return true end
        return false
    end
    _cosLib.OwnsCosmeticUniversally = function(self, inv, nm, wep)
        local c = _cosLib.Cosmetics[nm]
        if c and c.Type == "Skin" then return true end
        return false
    end
    _cosLib.OwnsCosmeticForWeapon = function(self, inv, nm, wep)
        local c = _cosLib.Cosmetics[nm]
        if c and c.Type == "Skin" then return true end
        return false
    end

    local _origOwns = _cosLib.OwnsCosmetic
    _cosLib.OwnsCosmetic = function(self, inv, nm, wep)
        if nm:find("MISSING_") or nm == "Bubble Gun" then
            return _origOwns(self, inv, nm, wep)
        end
        local c = _cosLib.Cosmetics[nm]
        if c and _isCosType(c) then return true end
        return _origOwns(self, inv, nm, wep)
    end

    local _origGet = _datCtrl.Get
    _datCtrl.Get = function(self, key)
        local _val = _origGet(self, key)
        if key == "CosmeticInventory" then
            local _prx = {}
            if _val then
                for k, v in pairs(_val) do
                    local c = _cosLib.Cosmetics[k]
                    if c and _isCosType(c) then _prx[k] = v end
                end
            end
            return setmetatable(_prx, {
                __index = function(t, k)
                    local c = _cosLib.Cosmetics[k]
                    if c and _isCosType(c) then return true end
                    return nil
                end
            })
        end
        if key == "FavoritedCosmetics" then
            local _res = _val and table.clone(_val) or {}
            for wep, fv in pairs(_favs) do
                _res[wep] = _res[wep] or {}
                for nm, isFav in pairs(fv) do
                    local c = _cosLib.Cosmetics[nm]
                    if c and _isCosType(c) then
                        _res[wep][nm] = isFav
                    end
                end
            end
            return _res
        end
        return _val
    end

    local _origGetWep = _datCtrl.GetWeaponData
    _datCtrl.GetWeaponData = function(self, wn)
        local _d = _origGetWep(self, wn)
        if not _d then return nil end
        local _m = {}
        for k, v in pairs(_d) do _m[k] = v end
        _m.Name = wn
        if _eq[wn] then
            for ct, cd in pairs(_eq[wn]) do
                _m[ct] = cd
            end
        end
        return _m
    end

    local _fightCtrl
    pcall(function()
        _fightCtrl = require(_ctrl:WaitForChild("FighterController", 10))
    end)

    if hookmetamethod then
        local _remotes   = _rs:FindFirstChild("Remotes")
        local _dataRem   = _remotes and _remotes:FindFirstChild("Data")
        local _equipRem  = _dataRem and _dataRem:FindFirstChild("EquipCosmetic")
        local _favRem    = _dataRem and _dataRem:FindFirstChild("FavoriteCosmetic")
        local _repRem    = _remotes and _remotes:FindFirstChild("Replication")
        local _fightRem  = _repRem and _repRem:FindFirstChild("Fighter")
        local _useItmRem = _fightRem and _fightRem:FindFirstChild("UseItem")

        if _equipRem then
            local _onc
            _onc = hookmetamethod(game, "__namecall", function(self, ...)
                if getnamecallmethod() ~= "FireServer" then
                    return _onc(self, ...)
                end
                local _a = {...}

                if _useItmRem and self == _useItmRem then
                    local _oid = _a[1]
                    if _fightCtrl then
                        pcall(function()
                            local _f = _fightCtrl:GetFighter(_lp)
                            if _f and _f.Items then
                                for _, itm in pairs(_f.Items) do
                                    if itm:Get("ObjectID") == _oid then
                                        _lastWep = itm.Name
                                        break
                                    end
                                end
                            end
                        end)
                    end
                end

                if self == _equipRem then
                    local _wn   = _a[1]
                    local _ct   = _a[2]
                    local _cn   = _a[3]
                    local _opts = _a[4] or {}
                    if _cn and _cn ~= "None" and _cn ~= "" then
                        local _inv = _datCtrl:Get("CosmeticInventory")
                        if _inv and rawget(_inv, _cn) then
                            return _onc(self, ...)
                        end
                    end
                    _eq[_wn] = _eq[_wn] or {}
                    if not _cn or _cn == "None" or _cn == "" then
                        _eq[_wn][_ct] = nil
                        if not next(_eq[_wn]) then _eq[_wn] = nil end
                    else
                        local _cloned = _mkCosmetic(_cn, _ct, {
                            inverted = _opts.IsInverted,
                            favoritesOnly = _opts.OnlyUseFavorites
                        })
                        if _cloned then _eq[_wn][_ct] = _cloned end
                    end
                    task.defer(function()
                        pcall(function() _datCtrl.CurrentData:Replicate("WeaponInventory") end)
                    end)
                    _saveCfg()
                    return
                end

                if self == _favRem then
                    local _cos = _cosLib.Cosmetics[_a[2]]
                    if _cos then
                        _favs[_a[1]] = _favs[_a[1]] or {}
                        _favs[_a[1]][_a[2]] = _a[3] or nil
                        task.spawn(function()
                            pcall(function() _datCtrl.CurrentData:Replicate("FavoritedCosmetics") end)
                        end)
                        _saveCfg()
                    end
                    return
                end

                return _onc(self, ...)
            end)
        end
    end

    local _cliItem
    pcall(function()
        _cliItem = require(_lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
    end)

    if _cliItem and _cliItem._CreateViewModel then
        local _origCVM = _cliItem._CreateViewModel
        _cliItem._CreateViewModel = function(self, vmRef)
            local _wn  = self.Name
            local _wp  = self.ClientFighter and self.ClientFighter.Player
            _buildingWep = (_wp == _lp) and _wn or nil
            if _wp == _lp and _eq[_wn] then
                local _dk = self:ToEnum("Data")
                if vmRef[_dk] then
                    if _eq[_wn].Skin then
                        vmRef[_dk][self:ToEnum("Skin")] = _eq[_wn].Skin
                        vmRef[_dk][self:ToEnum("Name")] = _eq[_wn].Skin.Name
                    end
                    if _eq[_wn].Charm then vmRef[_dk][self:ToEnum("Charm")] = _eq[_wn].Charm end
                    if _eq[_wn].Wrap  then vmRef[_dk][self:ToEnum("Wrap")]  = _eq[_wn].Wrap  end
                elseif vmRef.Data then
                    if _eq[_wn].Skin  then vmRef.Data.Skin  = _eq[_wn].Skin; vmRef.Data.Name = _eq[_wn].Skin.Name end
                    if _eq[_wn].Charm then vmRef.Data.Charm = _eq[_wn].Charm end
                    if _eq[_wn].Wrap  then vmRef.Data.Wrap  = _eq[_wn].Wrap  end
                end
            end
            local _r = _origCVM(self, vmRef)
            _buildingWep = nil
            return _r
        end
    end

    local _vmMod = _lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
    if _vmMod then
        local _CVM = require(_vmMod)
        local _origNew = _CVM.new
        _CVM.new = function(repData, cliItm)
            local _wp  = cliItm.ClientFighter and cliItm.ClientFighter.Player
            local _wn  = _buildingWep or cliItm.Name
            if _wp == _lp and _eq[_wn] then
                local _RC  = require(_rs.Modules.ReplicatedClass)
                local _dk  = _RC:ToEnum("Data")
                repData[_dk] = repData[_dk] or {}
                local _cos = _eq[_wn]
                if _cos.Skin  then repData[_dk][_RC:ToEnum("Skin")]  = _cos.Skin  end
                if _cos.Charm then repData[_dk][_RC:ToEnum("Charm")] = _cos.Charm end
                if _cos.Wrap  then repData[_dk][_RC:ToEnum("Wrap")]  = _cos.Wrap  end
            end
            return _origNew(repData, cliItm)
        end
    end

    CosmeticUnlocker._active = true
end

getgenv()._startCosmeticUnlocker = function()
    if not CosmeticUnlocker._active then
        getgenv()._ZX_SetupCosmeticUnlocker()
    end
end
getgenv().CosmeticUnlocker = CosmeticUnlocker

getgenv().whscript = "Zythera-X"

getgenv().webhookexecUrl = ""

if rawget(_G, "ID") then
    while true do end
end

setmetatable(_G, {
    __newindex = function(t, i, v)
        if tostring(i) == "ID" then
            while true do end
        end
        rawset(t, i, v)
    end
})

task.spawn(function()
    pcall(function()
        if not getgc or not hookfunction or not newcclosure or not debug.info then
            return
        end
        local scanned = 0
        local hooked = 0
        for _, fn in pairs(getgc(true)) do
            scanned = scanned + 1
            if typeof(fn) == "function" then
                local ok, src = pcall(function() return debug.info(fn, "s") end)
                if ok and type(src) == "string" and src:find("AnalyticsPipelineController") then
                    pcall(function()
                        hookfunction(fn, newcclosure(function(...)
                            return wait(8924896910)
                        end))
                        hooked = hooked + 1
                    end)
                end
            end
        end

    end)
end)

local _raw_cloneref = cloneref or clonereference
local function safe_cloneref(instance)
    if not instance then return instance end
    if not _raw_cloneref then return instance end
    local ok, result = pcall(_raw_cloneref, instance)
    if ok and result and typeof(result) == "Instance" then
        return result
    end
    return instance
end
local cloneref = safe_cloneref

local _raw_clonefn = clonefunction or copyfunction
local function safe_clonefunction(func)
    if not func then return func end
    if not _raw_clonefn then return func end
    local ok, result = pcall(_raw_clonefn, func)
    if ok and result and type(result) == "function" then
        return result
    end
    return func
end
local clonefunction = safe_clonefunction

local isfolder, isfile, listfiles = isfolder, isfile, listfiles

if typeof(clonefunction) == "function" then
    local isfolder_copy = clonefunction(isfolder)
    local isfile_copy = clonefunction(isfile)
    local listfiles_copy = clonefunction(listfiles)

    local isfolder_success, isfolder_result = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_result) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            if success then return data else return false end
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            if success then return data else return false end
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            if success then return data else return {} end
        end
    end
end

local ServiceProxy = setmetatable({}, {
    __index = function(_, serviceName)
        local success, service = pcall(function()
            return game:GetService(serviceName)
        end)
        if success and service then
            return cloneref(service)
        end
        return nil
    end
})

local HttpService = cloneref(game:GetService("HttpService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Workspace = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local StarterGui = cloneref(game:GetService("StarterGui"))
local TweenService = cloneref(game:GetService("TweenService"))

local TeleportService = cloneref(game:GetService("TeleportService"))
local Lighting = cloneref(game:GetService("Lighting"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
local Stats = cloneref(game:GetService("Stats"))

local ACBypassState = {
    runs = 0,
    remoteHooks = 0,
    hookedRemotes = {},
    hookedFunctions = {},
}

local function hookRemoteOnClientEvent(remotePath, remote)
    if not remote or not remote:IsA("RemoteEvent") then return 0 end
    if ACBypassState.hookedRemotes[remotePath] then return 0 end
    if not getconnections or not hookfunction then return 0 end

    local hooked = 0
    local ok, conns = pcall(getconnections, remote.OnClientEvent)
    if not ok or not conns then return 0 end

    for _, conn in ipairs(conns) do
        if conn and conn.Function then
            local fn = conn.Function
            local key = tostring(fn)
            if not ACBypassState.hookedFunctions[key] then
                ACBypassState.hookedFunctions[key] = true
                pcall(function()
                    hookfunction(fn, function(...)
                        return
                    end)
                end)
                hooked = hooked + 1
            end
        end
    end
    ACBypassState.hookedRemotes[remotePath] = true
    return hooked
end

local function hookRemoteFunctionInvoke(remotePath, remote)
    if not remote or not remote:IsA("RemoteFunction") then return 0 end
    if ACBypassState.hookedRemotes[remotePath] then return 0 end

    pcall(function()
        remote.OnClientInvoke = function(...)
            return nil
        end
    end)
    ACBypassState.hookedRemotes[remotePath] = true
    return 1
end

local function setupAnticheatBypass()
    pcall(function()
        ACBypassState.runs = ACBypassState.runs + 1
        local RS = game:GetService("ReplicatedStorage")
        local remotes = RS:FindFirstChild("Remotes")
        if not remotes then
            print("[Zythera-X] AC bypass run #" .. ACBypassState.runs .. ": Remotes folder not found yet")
            return
        end

        local totalRemoteHooks = 0

        local punishmentRemotes = {

            {"Moderator", "Ban"},
            {"Moderator", "Kick"},
            {"Moderator", "Unban"},
            {"Moderator", "UpdateBanData"},
            {"Moderator", "LockBans"},
            {"Moderator", "PardonRedFlags"},

            {"PrivateServer", "BanPlayer"},
            {"PrivateServer", "KickPlayer"},
            {"PrivateServer", "UnbanPlayer"},
            {"PrivateServer", "ReplicateBannedPlayers"},
            {"PrivateServer", "FetchBannedPlayers"},

            {"Matchmaking", "KickPlayerFromParty"},
        }
        for _, path in ipairs(punishmentRemotes) do
            local parent = remotes:FindFirstChild(path[1])
            if parent then
                local remote = parent:FindFirstChild(path[2])
                if remote then
                    local fullPath = "Remotes." .. path[1] .. "." .. path[2]
                    if remote:IsA("RemoteEvent") then
                        totalRemoteHooks = totalRemoteHooks + hookRemoteOnClientEvent(fullPath, remote)
                    elseif remote:IsA("RemoteFunction") then
                        totalRemoteHooks = totalRemoteHooks + hookRemoteFunctionInvoke(fullPath, remote)
                    end
                end
            end
        end

        ACBypassState.remoteHooks = ACBypassState.remoteHooks + totalRemoteHooks

        print(("[Zythera-X] AC bypass run #%d — punishment remotes hooked this round: %d (total %d) | gameplay channels left intact (damage works)"):format(
            ACBypassState.runs, totalRemoteHooks, ACBypassState.remoteHooks))
    end)
end

setupAnticheatBypass()
task.delay(8, setupAnticheatBypass)
task.delay(25, setupAnticheatBypass)
task.delay(60, setupAnticheatBypass)

pcall(function()
    print("[Zythera-X] Extra AC bypass: initializing...")

    local RS = cloneref(game:GetService("ReplicatedStorage"))
    local LogService = cloneref(game:GetService("LogService"))
    local ScriptContext = cloneref(game:GetService("ScriptContext"))
    local Players = cloneref(game:GetService("Players"))
    local StarterGui = cloneref(game:GetService("StarterGui"))
    local localPlayer = Players.LocalPlayer

    task.spawn(function()
        pcall(function()
            local Remotes = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 10)
            if not Remotes then return end
            local AnalyticsPipeline = Remotes:FindFirstChild("AnalyticsPipeline")
            if not AnalyticsPipeline then return end
            local RemoteEvent = AnalyticsPipeline:FindFirstChild("RemoteEvent")
            if not RemoteEvent or not RemoteEvent:IsA("RemoteEvent") then return end
            if not getconnections or not hookfunction then return end

            local ok, conns = pcall(getconnections, RemoteEvent.OnClientEvent)
            if not ok or not conns then return end
            local hooked = 0
            for _, conn in ipairs(conns) do
                if conn and conn.Function then
                    pcall(function()
                        hookfunction(conn.Function, function(...)
                            return
                        end)
                    end)
                    hooked = hooked + 1
                end
            end
            print(("[Zythera-X] Hooked AnalyticsPipeline.OnClientEvent (%d connections)"):format(hooked))
        end)
    end)

    task.spawn(function()
        pcall(function()
            if not getconnections or not hookfunction then return end
            local ok, conns = pcall(getconnections, LogService.MessageOut)
            if not ok or not conns then return end
            local hooked = 0
            for _, conn in ipairs(conns) do
                if conn and conn.Function then
                    pcall(function()
                        local orig = conn.Function
                        hookfunction(orig, function(message, messageType)
                            local lower = string.lower(tostring(message))

                            if string.find(lower, "cheat")
                            or string.find(lower, "exploit")
                            or string.find(lower, "hack")
                            or string.find(lower, "suspicious")
                            or string.find(lower, "anticheat")
                            or string.find(lower, "ac:")
                            or string.find(lower, "flag")
                            or string.find(lower, "detect")
                            or string.find(lower, "unauthorized")
                            or string.find(lower, "tamper")
                            then
                                return
                            end
                            return orig(message, messageType)
                        end)
                    end)
                    hooked = hooked + 1
                end
            end
            print(("[Zythera-X] Hooked LogService.MessageOut (%d connections)"):format(hooked))
        end)
    end)

    task.spawn(function()
        pcall(function()
            if not getconnections then return end
            local ok, conns = pcall(getconnections, ScriptContext.Error)
            if not ok or not conns then return end
            print(("[Zythera-X] ScriptContext.Error listeners found: %d (left intact — suppressing would break game error reporting)"):format(#conns))
        end)
    end)

    task.spawn(function()
        pcall(function()
            if not hookmetamethod or not getnamecallmethod then return end
            local playerNamecall = localPlayer
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if (method == "Kick" or method == "kick") and self == playerNamecall then
                    print("[Zythera-X] Blocked LocalPlayer:" .. method .. "() call")
                    return
                end
                return oldNamecall(self, ...)
            end))
            print("[Zythera-X] Hooked LocalPlayer:Kick() via __namecall (newcclosure pattern)")
        end)
    end)

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Text = "success!",
            Title = "rivals ac disable",
            Duration = 5
        })
    end)

    print("[Zythera-X] Extra AC bypass: started successfully")
end)

WallbangStealthState = nil

local player = Players.LocalPlayer
local players = Players

lucide_embedded_source = [=[
Lucide = {}

IS_GETCUSTOMASSET_BROKEN = false

if writefile and isfolder and makefolder and getcustomasset then
        if not isfolder("lucide-icons") then
                makefolder("lucide-icons")
        end

        if not isfile("lucide-icons/version.txt") then
                writefile("lucide-icons/version.txt", "2026-06-01T02:15:52.057378077+00:00")
        end

        local ShouldUpdate = readfile("lucide-icons/version.txt") ~= "2026-06-01T02:15:52.057378077+00:00"

        if ShouldUpdate then
                writefile("lucide-icons/version.txt", "2026-06-01T02:15:52.057378077+00:00")
        end

        for spritesheet = 1, 2 do
                if isfile(`lucide-icons/{spritesheet}.png`) and not ShouldUpdate then
                        continue
                end

                writefile(
                        `lucide-icons/{spritesheet}.png`,
                        nil
                )
        end

        local Success, _Error = pcall(function()
                return getcustomasset("lucide-icons/1.png")
        end)

        IS_GETCUSTOMASSET_BROKEN = not Success
end

icons = {{"align-vertical-distribute-center","chevron-down","list-restart","table-cells-split","gavel","dna-off","refresh-ccw-dot","venus","bean","circle-question-mark","folder-code","bolt","heater","feather","align-horizontal-distribute-center","grip-vertical","pill-bottle","person-standing","badge-swiss-franc","between-horizontal-end","file-braces-corner","rotate-cw","house-plus","bus-front","shield-ellipsis","between-vertical-end","globe-lock","tags","concierge-bell","bookmark-minus","file-down","picture-in-picture","messages-square","scissors","file-check-corner","phone-call","anchor","hand-helping","text-wrap","birdhouse","wifi-off","cloud-alert","message-square","cloud-download","folder-plus","cctv-off","mirror-round","user-round","pointer","between-horizontal-start","chevrons-up-down","brush","message-circle-more","parentheses","book-up-2","flame","chevrons-up","square-dashed","square-mouse-pointer","superscript","signal","wifi-cog","hexagon","navigation-2-off","eye-off","arrows-up-from-line","file-code-corner","square-centerline-dashed-horizontal","panels-right-bottom","scaling","hash","arrow-left-from-line","ship","ticket-percent","calendar-clock","x","non-binary","voicemail","presentation","tree-palm","badge","captions-off","align-vertical-justify-center","download","mouse-right","lens-convex","focus","diamond-percent","arrow-big-up","volume-x","mouse-pointer-click","origami","hard-drive","grid-2x2-x","package-minus","cloud","pipette","corner-left-down","badge-cent","cloud-lightning","user-round-pen","arrow-left-to-line","book-open-text","monitor-cloud","parking-meter","cat","heart-handshake","dam","trees","ham","circle-pause","chess-king","bean-off","rat","separator-horizontal","ambulance","signal-zero","citrus","phone-missed","calendar-off","chart-column","battery-medium","square-minus","decimals-arrow-left","folder-output","menu","image-down","terminal","angry","circle-dot-dashed","medal","cake-slice","git-graph","armchair","tickets","qr-code","copy","goal","trending-down","creative-commons","ev-charger","user-star","road","nfc","align-center-horizontal","car","notebook-tabs","ear","videotape","sun-moon","chart-scatter","toolbox","calendar","calendar-cog","gallery-horizontal","clipboard-x","book-open","circle-pile","rectangle-ellipsis","badge-plus","badge-info","file-headphone","bow-arrow","clipboard-pen-line","user-round-key","folder-search","utensils-crossed","arrow-up","arrow-up-from-dot","align-vertical-justify-start","layers-minus","pause","shrub","flag","biceps-flexed","align-horizontal-distribute-end","donut","calendar-plus-2","move-vertical","file-pen-line","badge-russian-ruble","radius","pilcrow","corner-left-up","georgian-lari","cable","book-user","square-arrow-down","circle-plus","view","cctv","circle-arrow-left","volume","octagon-alert","panel-bottom-dashed","book-a","align-end-vertical","thumbs-up","globe","rabbit","layers-plus","banknote-arrow-down","message-square-off","dice-4","message-circle-x","folder-x","message-circle-warning","map","move","arrow-up-left","award","arrow-down-wide-narrow","unfold-horizontal","lens-concave","motorbike","music-4","shield-x","file-volume","disc-3","file-signal","columns-4","archive-x","square-dashed-kanban","mouse-pointer-2","clock-arrow-up","clock-fading","vegan","message-circle-plus","fast-forward","user-pen","chess-knight","wifi-pen","files","send-to-back","alarm-clock","shopping-basket","send","brush-cleaning","skip-back","book-audio","file-scan","message-square-dashed","chevrons-left","umbrella","skip-forward","clipboard-copy","map-pin-off","arrow-up-from-line","circle-chevron-up","circle-small","align-vertical-space-between","lamp-desk","circle-arrow-up","zap","beaker","paintbrush","broccoli","chevron-up","pen-tool","form","pencil-ruler","dna","arrow-big-down-dash","chart-area","bug-off","card-sim","map-pin-search","ellipse","spell-check","popcorn","blocks","washing-machine","microchip","badge-minus","cloud-sun","circle","shield-alert","map-minus","separator-vertical","ampersands","user-search","fence","square-user-round","sunrise","strikethrough","calendar-days","folder-bookmark","banknote-arrow-up","dollar-sign","message-square-quote","list-minus","cloud-hail","eye-closed","app-window-mac","ellipsis","copy-check","history","satellite","bookmark-plus","folder-key","coffee","circle-power","hourglass","tickets-plane","folder-git","bomb","layers-2","battery-full","user-minus","chart-gantt","folder-tree","command","badge-dollar-sign","align-start-vertical","briefcase-conveyor-belt","message-circle-question-mark","bluetooth-off","square-square","cannabis","book","grip-horizontal","circle-minus","audio-waveform","moon-star","arrow-down-narrow-wide","database-backup","wand","receipt-turkish-lira","calendar-minus-2","copy-minus","folder-input","book-image","mouse-left","shirt","server-off","move-up","plug-2","chess-rook","brackets","calendar-heart","list-ordered","mic-off","arrow-big-left","square-split-horizontal","clover","sun-snow","sofa","funnel-x","clock-2","calendar-fold","fish-off","baby","leaf","fold-vertical","hop","paperclip","cigarette","minus","smile-plus","diamond-plus","file-chart-column","triangle-dashed","git-pull-request-closed","badge-check","plug-zap","heading-4","chess-queen","graduation-cap","grid-3x2","zodiac-sagittarius","square-dashed-bottom-code","clock-7","ethernet-port","scan-text","shower-head","equal-not","move-down","clock-arrow-down","ticket-slash","ruler","circle-user-round","list-filter","map-pin-check","egg-off","cog","dog","swords","spotlight","panel-right-dashed","truck-electric","check-line","bubbles","bot","chart-bar-increasing","trash-2","air-vent","dot","file-symlink","clipboard-paste","chevron-last","book-heart","circle-parking","globe-check","cloud-check","panel-left","circle-chevron-right","squares-unite","arrow-down-up","git-fork","forward","brain-circuit","between-vertical-start","database","panel-right","log-out","git-branch-plus","clipboard-minus","file-text","table-rows-split","milk-off","tv-minimal","cloud-upload","banknote","drumstick","calendar-search","zoom-out","bell-ring","circle-chevron-left","zoom-in","arrow-down","arrow-up-down","folder-dot","zodiac-virgo","loader-pinwheel","whole-word","monitor","disc-2","trending-up-down","film","zodiac-pisces","underline","tv-minimal-play","circle-stop","align-vertical-space-around","zodiac-libra","zodiac-leo","zodiac-gemini","arrow-big-down","circle-parking-off","calendar-x-2","user-plus","move-diagonal-2","bandage","gallery-horizontal-end","panel-top-dashed","squircle","land-plot","tram-front","zodiac-aries","podcast","zodiac-aquarius","audio-lines","expand","x-line-top","square-chevron-up","flip-vertical-2","rocket","worm","ear-off","workflow","wine-off","wine","wind-arrow-down","printer","megaphone-off","weight","arrow-big-right","section","file-clock","plane-landing","toy-brick","square-chevron-down","dice-1","drill","app-window","shield-check","hand-metal","wifi-sync","spell-check-2","square-arrow-out-up-left","wifi-high","list-plus","wifi","rotate-ccw-key","wheat-off","chart-pie","wheat","weight-tilde","copy-slash","wind","reply","layout-panel-left","gamepad","circle-percent","webcam","circle-arrow-out-down-right","square-x","italic","chart-column-increasing","waypoints","step-forward","waves-vertical","a-arrow-down","container","sticker","waves-ladder","waves-horizontal","soap-dispenser-droplet","waves-arrow-down","watch","inspection-panel","import","badge-turkish-lira","square-terminal","file-music","wand-sparkles","beef","route-off","file-user","wallpaper","square-radical","wallet-minimal","image-upscale","book-type","smile","signpost-big","wallet-cards","cloudy","wallet","square-percent","vote","navigation-off","arrow-left","car-taxi-front","volume-off","skull","chevrons-right-left","volume-1","volleyball","utensils","video","telescope","vibrate","venus-and-mars","square-pause","align-end-horizontal","repeat-1","equal","megaphone","calendar-x","message-square-warning","vault","egg","badge-x","van","utility-pole","circle-pound-sterling","video-off","japanese-yen","users-round","users","user-x","library","file-terminal","circle-chevron-down","accessibility","user-round-x","square-library","amphora","user-round-search","tally-2","monitor-play","monitor-dot","user-round-cog","user-round-check","sheet","circle-check-big","user-lock","user-key","map-pinned","corner-down-left","circuit-board","stethoscope","square-arrow-up-right","user","maximize","folder-open-dot","book-dashed","upload","unplug","bluetooth","tree-pine","receipt-indian-rupee","square-slash","unlink","university","ungroup","unfold-vertical","book-plus","flask-conical","undo-2","funnel","square-star","folder-sync","undo","zodiac-ophiuchus","umbrella-off","type-outline","arrow-up-narrow-wide","fishing-hook","gamepad-directional","file-up","folder-root","frame","calendar-arrow-down","clock-12","turntable","turkish-lira","truck","images","lollipop","book-text","trophy","lamp-floor","file-plus-corner","image","ghost","badge-euro","bike","triangle-alert","triangle","trending-up","tree-deciduous","shell","transgender","chevron-left","option","train-front-tunnel","scroll-text","table-of-contents","move-3d","traffic-cone","tractor","toggle-right","tower-control","ferris-wheel","camera-off","salad","touchpad-off","touchpad","torus","tornado","group","tool-case","battery","toilet","tent-tree","toggle-left","rectangle-horizontal","timer-reset","rectangle-vertical","timer","bitcoin","timeline","battery-plus","database-search","ticket-x","file-diff","stretch-vertical","locate-fixed","shield-user","spline-pointer","move-left","axis-3d","heart-off","thermometer-sun","binoculars","thermometer-snowflake","thermometer","theater","rose","message-square-share","mail-minus","text-quote","phone-incoming","text-cursor-input","text-cursor","clipboard-pen","bottle-wine","alarm-clock-off","iteration-cw","list","text-align-justify","square-arrow-right","text-align-end","badge-pound-sterling","bookmark-check","text-align-center","test-tubes","test-tube-diagonal","a-arrow-up","clock-check","bug","tent","vibrate-off","mail-check","zodiac-cancer","tangent","file-code","snowflake","chart-column-big","locate","tally-3","cassette-tape","battery-low","list-video","tag","signpost","tablets","calendar-arrow-up","landmark","fish-symbol","tablet-smartphone","loader","bold","dice-2","file-type","clipboard-clock","beer","lectern","shield","table-properties","table-columns-split","binary","move-diagonal","table-cells-merge","door-closed","table-2","layout-template","table","syringe","save-off","bookmark-off","hand-heart","switch-camera","scan-qr-code","message-square-check","swiss-franc","bell-off","sunset","brain","sun-medium","sun-dim","folder-cog","key","clock-11","subscript","ticket-plus","arrow-up-0-1","bell-electric","stretch-horizontal","heading","book-open-check","panel-top-close","lasso-select","map-pin-x","stone","info","sticky-note-x","bus","chart-bar-stacked","bed-single","chart-no-axes-gantt","file-spreadsheet","file-minus-corner","clipboard-list","grid-2x2","contact-round","sticky-note-check","keyboard-off","sticky-note","file-badge","battery-warning","mail-question-mark","arrow-down-from-line","briefcase","biohazard","rectangle-circle","braces","scale-3d","panel-top-bottom-dashed","mail-x","square-dashed-mouse-pointer","user-cog","lock-open","step-back","pizza","list-indent-decrease","arrow-up-wide-narrow","star-off","clock-5","shield-cog","rotate-ccw","align-horizontal-justify-center","star","antenna","memory-stick","scan-eye","stamp","square-check","heart-plus","squirrel","map-pin-minus-inside","git-merge","gallery-vertical-end","component","hand-coins","zodiac-capricorn","wifi-low","heading-2","clock","file-pen","git-compare-arrows","cloud-sun-rain","align-horizontal-justify-start","squares-exclude","square-user","calculator","calendar-plus","square-stack","arrow-down-z-a","bath","square-split-vertical","unlink-2","square-sigma","square-scissors","folder-check","square-round-corner","book-key","ribbon","microwave","line-dot-right-horizontal","gallery-vertical","square-plus","square-play","square-dashed-text","map-pin-pen","move-up-left","square-pilcrow","folder-heart","square-pi","music-2","lock","arrow-up-a-z","square-parking","square-dashed-top-solid","panel-right-open","square-m","square-kanban","swatch-book","receipt-cent","spool","folder-archive","folder-symlink","columns-3","ban","message-square-x","paint-roller","square-equal","archive","square-dot","square-divide","building-2","circle-slash-2","square-dashed-bottom","cake","cloud-rain","chart-bar","square-code","wrench","list-indent-increase","square-chevron-left","search-alert","flag-triangle-right","square-chart-gantt","square-centerline-dashed-vertical","bell","square-bottom-dashed-scissors","square-asterisk","music-3","chart-bar-big","user-check","proportions","siren","plane","webhook-off","carrot","square-arrow-left","file-cog","circle-dashed","square-arrow-right-exit","square-arrow-right-enter","square-arrow-out-up-right","mailbox","squares-subtract","package-search","square-arrow-out-down-left","split","square-arrow-down-right","globe-x","forklift","monitor-pause","alarm-clock-minus","heart-x","eraser","book-marked","square","bluetooth-connected","rotate-ccw-square","chart-no-axes-column","cannabis-off","folder-kanban","sprout","mars-stroke","spray-can","sport-shoe","remove-formatting","file-box","speech","paint-bucket","glass-water","speaker","glasses","piggy-bank","sparkles","cuboid","cloud-off","check-check","activity","axe","plane-takeoff","sparkle","cloud-rain-wind","spade","flag-off","copy-x","file-axis-3d","radical","chart-column-decreasing","soup","bug-play","align-vertical-distribute-start","solar-panel","waves-arrow-up","tally-5","snail","smartphone-nfc","chevrons-left-right-ellipsis","circle-divide","smartphone","sliders-vertical","sliders-horizontal","life-buoy","saudi-riyal","mic-vocal","volume-2","battery-charging","russian-ruble","square-arrow-up-left","brick-wall-shield","footprints","signature","building","signal-medium","signal-low","git-branch","sigma","book-alert","link-2","astroid","bell-minus","image-up","closed-caption","drum","arrow-up-z-a","sun","fan","shrimp","file-key","house-heart","paintbrush-vertical","scissors-line-dashed","plug","shopping-bag","ship-wheel","ticket-check","combine","shield-question-mark","shield-plus","mountain","mars","picture-in-picture-2","radio-off","flower-2","shield-off","squares-intersect","shield-half","shield-cog-corner","keyboard-music","star-half","shield-ban","code-xml","pencil-line","mails","brain-cog","tablet","shelving-unit","pi","trash","book-down","hdmi-port","git-pull-request-draft","case-upper","circle-fading-arrow-up","share","croissant","shapes","settings-2","barcode","settings","server-crash","bed","server-cog","divide","grape","server","party-popper","file-chart-pie","send-horizontal","search-x","dice-6","search-slash","blender","search-code","zap-off","square-check-big","search","scroll","screen-share-off","laptop-minimal","screen-share","lock-keyhole","map-pin-minus","school","chart-spline","message-square-more","scan-search","chart-candlestick","list-music","arrow-down-a-z","circle-ellipsis","scan-face","move-horizontal","file-sliders","frown","scan-barcode","cup-soda","scan","rows-2","sword","infinity","package-open","earth","slice","dice-3","milk","mouse-pointer-ban","crown","circle-slash","circle-star","rotate-cw-square","atom","package-x","bed-double","satellite-dish","circle-dot","file-exclamation-point","hand-fist","message-circle-code","folder-git-2","message-square-code","sandwich","towel-rack","sailboat","arrow-big-left-dash","monitor-speaker","dumbbell","file-search-corner","rows-4","rows-3","scale","router","flashlight","panel-top-open","route","rotate-3d","notebook","redo-2","roller-coaster","square-menu","rewind","monitor-smartphone","laptop","scan-line","clock-4","square-arrow-up","book-minus","file-question-mark","replace-all","replace","repeat-off","arrow-down-to-line","repeat-2","refresh-ccw","venetian-mask","calendar-check-2","repeat","spline","banknote-x","git-pull-request-create-arrow","regex","circle-check","refrigerator","refresh-cw-off","refresh-cw","copyleft","redo","circle-play","timer-off","arrow-big-right-dash","rectangle-goggles","hard-hat","receipt-swiss-franc","backpack","receipt-russian-ruble","keyboard","receipt-japanese-yen","receipt-euro","rainbow","arrow-down-right","ratio","receipt","wifi-zero","radio-receiver","radio","radiation","radar","image-off","quote","pyramid","puzzle","projector","square-chevron-right","mail-search","printer-check","power-off","power","pound-sterling","popsicle","folder-search-2","tally-1","ampersand","plus","shopping-cart","align-vertical-justify-end","play-off","alarm-smoke","play","file-input","clock-8","hand-grab","cloud-cog","blend","hd","radio-tower","list-tree","droplet","pin-off","eye","crosshair","pill","banana","gpu","message-square-plus","pilcrow-left","circle-equal","pickaxe","piano","circle-alert","phone-off","text-initial","arrow-up-right","phone-forwarded","leafy-green","message-square-dot","file-chart-line","columns-3-cog","phone","grip","minimize-2","percent","pentagon","cone","pencil-off","file-image","diamond-minus","palette","barrel","gallery-thumbnails","pen-off","cpu","pen-line","thumbs-down","merge","hamburger","pc-case","hat-glasses","code","notepad-text","parasol","calendar-minus","panels-left-bottom","file-video-camera","panel-top","kanban","bone","apple","rocking-chair","bot-off","panel-right-close","panel-left-right-dashed","panel-left-open","circle-arrow-out-up-left","panel-left-dashed","cable-car","arrow-down-left","square-activity","hotel","cigarette-off","panel-bottom-close","message-circle","circle-arrow-out-up-right","panel-bottom","panda","fold-horizontal","shovel","calendar-1","cloud-moon","square-arrow-out-down-right","package-plus","clock-plus","save","cloud-snow","anvil","arrow-big-up-dash","dices","package-2","package","orbit","omega","logs","chevrons-down-up","clipboard-plus","circle-x","list-end","octagon-pause","octagon-minus","chevrons-right","move-right","message-square-reply","corner-down-right","nut-off","nut","lamp-wall-down","notepad-text-dashed","paw-print","ellipsis-vertical","globe-off","square-stop","arrow-up-1-0","align-horizontal-justify-end","scan-heart","align-vertical-distribute-end","heart-crack","airplay","newspaper","network","navigation-2","monitor-x","bell-check","navigation","square-pen","file-minus","move-up-right","dice-5","octagon","ticket","move-down-right","move-down-left","train-front","bookmark","microscope","album","mouse-pointer","chart-bar-decreasing","mouse-off","calendar-sync","funnel-plus","store","circle-arrow-down","notebook-pen","egg-fried","moon","monitor-up","corner-right-up","monitor-stop","ruler-dimension-line","user-round-plus","panel-left-close","monitor-off","pilcrow-right","user-round-minus","monitor-cog","monitor-check","mail-plus","layout-dashboard","heart-pulse","milestone","mouse-pointer-2-off","drone","slash","mic","aperture","arrow-right-left","case-sensitive","vector-square","circle-gauge","message-square-text","check","text-search","arrow-down-to-dot","monitor-down","message-square-lock","chef-hat","message-square-heart","message-square-diff","file-archive","signal-high","inbox","flip-horizontal-2","message-circle-off","image-play","align-horizontal-space-between","message-circle-heart","calendar-check","database-zap","droplets","message-circle-dashed","message-circle-check","meh","layout-list","file-search","maximize-2","alarm-clock-plus","circle-dollar-sign","usb","house","receipt-pound-sterling","list-check","map-pin-x-inside","id-card","mouse","minimize","map-pin-plus","diff","file-play","map-pin","book-x","mirror-rectangular","bird","mail","magnet","headphone-off","asterisk","circle-arrow-right","octagon-x","languages","log-in","alarm-clock-check","guitar","lock-keyhole-open","beer-off","scooter","square-parking-off","notebook-text","arrow-right-to-line","ticket-minus","tally-4","zodiac-taurus","loader-circle","door-open","flag-triangle-left","grid-3x3","file","diameter","pocket-knife","book-copy","castle","car-front","clock-alert","reply-all","cloud-moon-rain","clipboard-type","list-collapse","list-todo","printer-x","lamp-wall-up","list-start","list-chevrons-up-down","a-large-small","list-chevrons-down-up","list-checks","map-plus","link-2-off","link","line-style","line-squiggle","arrow-right-from-line","flame-kindling","square-power","calendar-range","bring-to-front","lightbulb","ligature","bell-plus","library-big","layout-panel-top","layout-grid","folders","mail-warning","layers","laugh","lasso","chevrons-left-right","chart-line","file-lock","cast","circle-fading-plus","clock-10","undo-dot","target","list-filter-plus","lamp-ceiling","drama","lamp","baseline","martini","contrast","key-square","candy-off","file-x-corner","book-check","kayak","book-lock","joystick","briefcase-medical","calendars","text-align-start","iteration-ccw","hop-off","warehouse","sticky-notes","drafting-compass","save-all","indian-rupee","image-plus","image-minus","id-card-lanyard","ice-cream-cone","fishing-rod","book-headphones","credit-card","ice-cream-bowl","house-wifi","house-plug","shredder","panel-bottom-open","hospital","highlighter","helicopter","balloon","map-pin-plus-inside","bookmark-x","badge-question-mark","pen","heart-minus","candy-cane","heart","headset","gamepad-2","file-x","heading-6","heading-5","heading-3","shield-minus","circle-off","dessert","eclipse","church","heading-1","cylinder","badge-japanese-yen","haze","receipt-text","hard-drive-upload","hard-drive-download","file-digit","handbag","file-output","disc-album","hand-platter","arrow-down-0-1","captions","hand","hammer","philippine-peso","badge-alert","flower","folder-pen","cross","grid-2x2-check","chevron-right","sticky-note-minus","square-arrow-down-left","share-2","git-pull-request-create","contact","folder-lock","git-merge-conflict","git-compare","git-commit-vertical","chess-pawn","git-commit-horizontal","briefcase-business","clipboard","message-circle-reply","gift","triangle-right","folder-clock","gem","gauge","type","webhook","fullscreen","align-horizontal-distribute-start","fuel","folder-up","pointer-off","turtle","camera","folder-open","folder-minus","git-pull-request","bluetooth-searching","arrow-up-to-line","squircle-dashed","clock-3","badge-percent","shuffle","folder-closed","folder","grid-2x2-plus","flask-round","box","flask-conical-off","clock-1","file-heart","flashlight-off","space","fish","fire-extinguisher","fingerprint-pattern","corner-up-left","clock-6","zodiac-scorpio","key-round","headphones","tv","file-type-corner","file-stack","rss","cookie","at-sign","map-pin-check-inside","sticky-note-off","music","handshake","file-check","circle-user","copy-plus","file-chart-column-increasing","file-braces","shrink","factory","external-link","search-check","clipboard-check","columns-2","euro","equal-approximately","align-center-vertical","earth-lock","droplet-off","club","cloud-fog","dock","disc","map-pin-house","package-check","chevron-first","pencil","cloud-drizzle","list-x","delete","computer","corner-up-right","currency","pin","crop","corner-right-down","badge-indian-rupee","copyright","redo-dot","brick-wall","align-start-horizontal","chart-column-stacked","file-plus","git-pull-request-arrow","construction","decimals-arrow-right","bell-dot","folder-down","compass","coins","align-horizontal-space-around","door-closed-locked","cloud-sync","diamond","blinds","cloud-backup","clock-9","book-search","git-branch-minus","clapperboard","recycle","mountain-snow","luggage","circle-arrow-out-down-left","bot-message-square","phone-outgoing","smartphone-charging","chevrons-down","train-track","chess-bishop","cherry","sticky-note-plus","chart-no-axes-column-increasing","chart-no-axes-column-decreasing","chart-network","chart-no-axes-combined","metronome","case-lower","arrow-down-1-0","caravan","candy","arrow-left-right","lightbulb-off","panels-top-left","beef-off","locate-off","annoyed","test-tube","brick-wall-fire","cooking-pot","boxes","boom-box","book-up","laptop-minimal-check","mail-open","square-function","baggage-claim","variable","arrow-right","archive-restore"},{if getcustomasset and not IS_GETCUSTOMASSET_BROKEN then getcustomasset("lucide-icons/1.png") else "rbxassetid://89707116417717",if getcustomasset and not IS_GETCUSTOMASSET_BROKEN then getcustomasset("lucide-icons/2.png") else "rbxassetid://101599128715386"},{[48]={{1,{24,24},{175,0}},{1,{24,24},{350,275}},{1,{24,24},{725,325}},{1,{24,24},{900,725}},{1,{24,24},{500,425}},{1,{24,24},{600,200}},{1,{24,24},{975,325}},{2,{24,24},{50,150}},{1,{24,24},{125,275}},{1,{24,24},{375,300}},{1,{24,24},{725,175}},{1,{24,24},{125,325}},{1,{24,24},{375,600}},{1,{24,24},{275,550}},{1,{24,24},{50,75}},{1,{24,24},{475,475}},{1,{24,24},{425,800}},{1,{24,24},{875,350}},{1,{24,24},{350,25}},{1,{24,24},{175,250}},{1,{24,24},{100,725}},{1,{24,24},{975,350}},{1,{24,24},{75,900}},{1,{24,24},{75,450}},{1,{24,24},{525,850}},{1,{24,24},{125,300}},{1,{24,24},{850,100}},{1,{24,24},{650,975}},{1,{24,24},{575,175}},{1,{24,24},{400,100}},{1,{24,24},{625,225}},{1,{24,24},{550,675}},{1,{24,24},{250,850}},{1,{24,24},{775,575}},{1,{24,24},{825,25}},{1,{24,24},{825,400}},{1,{24,24},{100,100}},{1,{24,24},{200,750}},{1,{24,24},{725,950}},{1,{24,24},{400,50}},{2,{24,24},{175,125}},{1,{24,24},{725,0}},{1,{24,24},{275,825}},{1,{24,24},{625,100}},{1,{24,24},{325,575}},{1,{24,24},{600,0}},{1,{24,24},{750,375}},{2,{24,24},{50,100}},{1,{24,24},{725,525}},{1,{24,24},{150,275}},{1,{24,24},{25,600}},{1,{24,24},{250,275}},{1,{24,24},{875,225}},{1,{24,24},{500,700}},{1,{24,24},{25,450}},{1,{24,24},{250,625}},{1,{24,24},{0,625}},{1,{24,24},{800,700}},{1,{24,24},{550,950}},{1,{24,24},{750,850}},{1,{24,24},{450,950}},{2,{24,24},{250,50}},{1,{24,24},{325,650}},{1,{24,24},{425,725}},{1,{24,24},{400,425}},{1,{24,24},{225,100}},{1,{24,24},{750,100}},{1,{24,24},{700,775}},{1,{24,24},{600,600}},{1,{24,24},{425,900}},{1,{24,24},{950,25}},{1,{24,24},{75,200}},{1,{24,24},{875,525}},{1,{24,24},{800,900}},{1,{24,24},{350,200}},{2,{24,24},{200,125}},{1,{24,24},{250,900}},{2,{24,24},{125,100}},{1,{24,24},{575,675}},{1,{24,24},{925,875}},{1,{24,24},{275,100}},{1,{24,24},{350,225}},{1,{24,24},{100,75}},{1,{24,24},{350,450}},{1,{24,24},{925,225}},{1,{24,24},{450,575}},{1,{24,24},{0,875}},{1,{24,24},{175,600}},{1,{24,24},{125,125}},{2,{24,24},{0,225}},{1,{24,24},{975,175}},{1,{24,24},{650,525}},{1,{24,24},{0,950}},{1,{24,24},{600,350}},{1,{24,24},{575,600}},{1,{24,24},{250,475}},{1,{24,24},{325,900}},{1,{24,24},{100,650}},{1,{24,24},{275,75}},{1,{24,24},{525,200}},{2,{24,24},{150,0}},{1,{24,24},{25,250}},{1,{24,24},{175,300}},{1,{24,24},{700,425}},{1,{24,24},{475,725}},{1,{24,24},{0,575}},{1,{24,24},{550,425}},{1,{24,24},{450,325}},{1,{24,24},{875,925}},{1,{24,24},{375,575}},{1,{24,24},{550,125}},{1,{24,24},{475,150}},{1,{24,24},{150,250}},{1,{24,24},{800,475}},{1,{24,24},{375,975}},{1,{24,24},{200,0}},{1,{24,24},{475,925}},{1,{24,24},{100,575}},{1,{24,24},{750,475}},{1,{24,24},{175,375}},{1,{24,24},{275,325}},{1,{24,24},{275,125}},{1,{24,24},{575,925}},{1,{24,24},{325,450}},{1,{24,24},{375,525}},{1,{24,24},{125,950}},{1,{24,24},{900,100}},{1,{24,24},{725,925}},{1,{24,24},{75,125}},{1,{24,24},{125,525}},{1,{24,24},{250,825}},{1,{24,24},{550,0}},{1,{24,24},{175,750}},{1,{24,24},{50,175}},{1,{24,24},{925,800}},{1,{24,24},{375,875}},{1,{24,24},{225,525}},{1,{24,24},{750,200}},{1,{24,24},{850,950}},{1,{24,24},{725,50}},{1,{24,24},{500,325}},{2,{24,24},{0,150}},{1,{24,24},{550,750}},{1,{24,24},{275,875}},{1,{24,24},{0,100}},{1,{24,24},{250,325}},{1,{24,24},{200,950}},{1,{24,24},{50,750}},{2,{24,24},{175,50}},{1,{24,24},{875,725}},{1,{24,24},{25,575}},{1,{24,24},{950,800}},{1,{24,24},{575,0}},{1,{24,24},{325,225}},{1,{24,24},{700,225}},{1,{24,24},{525,175}},{1,{24,24},{150,325}},{1,{24,24},{500,175}},{1,{24,24},{475,800}},{1,{24,24},{50,300}},{1,{24,24},{150,200}},{1,{24,24},{575,275}},{1,{24,24},{150,350}},{1,{24,24},{625,75}},{2,{24,24},{25,100}},{1,{24,24},{250,650}},{2,{24,24},{75,100}},{1,{24,24},{250,75}},{1,{24,24},{100,200}},{1,{24,24},{50,125}},{1,{24,24},{775,250}},{1,{24,24},{425,775}},{1,{24,24},{625,775}},{1,{24,24},{300,575}},{1,{24,24},{75,350}},{1,{24,24},{25,100}},{1,{24,24},{475,325}},{1,{24,24},{150,400}},{1,{24,24},{575,575}},{1,{24,24},{325,525}},{1,{24,24},{375,0}},{1,{24,24},{850,425}},{1,{24,24},{450,775}},{1,{24,24},{75,675}},{1,{24,24},{450,475}},{1,{24,24},{0,525}},{1,{24,24},{500,0}},{1,{24,24},{525,925}},{1,{24,24},{450,225}},{2,{24,24},{150,75}},{1,{24,24},{575,25}},{1,{24,24},{525,125}},{2,{24,24},{250,0}},{1,{24,24},{850,325}},{1,{24,24},{250,925}},{1,{24,24},{50,400}},{1,{24,24},{75,50}},{1,{24,24},{875,825}},{1,{24,24},{775,175}},{1,{24,24},{325,925}},{1,{24,24},{750,275}},{1,{24,24},{125,250}},{1,{24,24},{475,625}},{1,{24,24},{25,750}},{1,{24,24},{725,375}},{1,{24,24},{125,775}},{1,{24,24},{750,350}},{1,{24,24},{400,675}},{1,{24,24},{550,600}},{1,{24,24},{50,250}},{1,{24,24},{50,275}},{1,{24,24},{150,125}},{2,{24,24},{25,0}},{1,{24,24},{475,550}},{1,{24,24},{325,800}},{1,{24,24},{475,675}},{1,{24,24},{950,450}},{1,{24,24},{700,175}},{1,{24,24},{700,100}},{1,{24,24},{100,750}},{1,{24,24},{725,25}},{1,{24,24},{100,125}},{1,{24,24},{900,600}},{1,{24,24},{175,950}},{1,{24,24},{125,575}},{1,{24,24},{75,625}},{2,{24,24},{125,75}},{1,{24,24},{825,275}},{1,{24,24},{300,525}},{2,{24,24},{125,0}},{1,{24,24},{450,175}},{2,{24,24},{150,150}},{1,{24,24},{600,275}},{1,{24,24},{425,925}},{1,{24,24},{75,25}},{1,{24,24},{800,600}},{1,{24,24},{400,950}},{1,{24,24},{275,250}},{1,{24,24},{900,525}},{1,{24,24},{0,450}},{1,{24,24},{175,675}},{1,{24,24},{625,475}},{1,{24,24},{100,525}},{1,{24,24},{925,975}},{1,{24,24},{875,550}},{1,{24,24},{0,675}},{1,{24,24},{650,425}},{1,{24,24},{75,225}},{1,{24,24},{225,425}},{1,{24,24},{300,375}},{1,{24,24},{0,175}},{1,{24,24},{175,825}},{1,{24,24},{375,275}},{2,{24,24},{150,175}},{1,{24,24},{175,225}},{1,{24,24},{350,825}},{1,{24,24},{300,225}},{1,{24,24},{225,400}},{1,{24,24},{300,900}},{1,{24,24},{0,900}},{1,{24,24},{975,250}},{1,{24,24},{575,225}},{1,{24,24},{25,200}},{1,{24,24},{550,50}},{1,{24,24},{200,325}},{1,{24,24},{200,375}},{1,{24,24},{550,525}},{1,{24,24},{725,100}},{1,{24,24},{825,625}},{1,{24,24},{700,550}},{1,{24,24},{275,175}},{2,{24,24},{25,225}},{1,{24,24},{125,975}},{1,{24,24},{100,250}},{1,{24,24},{325,400}},{1,{24,24},{150,525}},{1,{24,24},{650,725}},{1,{24,24},{800,275}},{1,{24,24},{975,400}},{1,{24,24},{150,50}},{2,{24,24},{25,125}},{1,{24,24},{250,575}},{1,{24,24},{900,650}},{1,{24,24},{800,800}},{1,{24,24},{975,625}},{1,{24,24},{300,250}},{1,{24,24},{825,75}},{1,{24,24},{100,275}},{1,{24,24},{500,300}},{1,{24,24},{425,675}},{1,{24,24},{825,225}},{1,{24,24},{550,175}},{1,{24,24},{425,400}},{1,{24,24},{200,25}},{1,{24,24},{675,150}},{1,{24,24},{350,400}},{1,{24,24},{275,700}},{1,{24,24},{600,725}},{1,{24,24},{350,150}},{1,{24,24},{500,400}},{1,{24,24},{100,625}},{1,{24,24},{400,275}},{1,{24,24},{150,825}},{1,{24,24},{950,775}},{1,{24,24},{600,300}},{1,{24,24},{100,350}},{1,{24,24},{800,225}},{1,{24,24},{325,75}},{2,{24,24},{0,100}},{1,{24,24},{250,350}},{1,{24,24},{175,725}},{1,{24,24},{675,75}},{1,{24,24},{225,125}},{1,{24,24},{0,150}},{1,{24,24},{400,125}},{1,{24,24},{800,300}},{1,{24,24},{225,225}},{1,{24,24},{575,950}},{1,{24,24},{375,200}},{1,{24,24},{450,50}},{1,{24,24},{500,450}},{1,{24,24},{650,25}},{1,{24,24},{75,250}},{1,{24,24},{375,750}},{1,{24,24},{275,0}},{1,{24,24},{425,350}},{2,{24,24},{75,175}},{1,{24,24},{550,725}},{1,{24,24},{225,325}},{1,{24,24},{325,425}},{1,{24,24},{550,350}},{1,{24,24},{325,150}},{1,{24,24},{250,875}},{1,{24,24},{850,550}},{1,{24,24},{900,475}},{1,{24,24},{600,550}},{1,{24,24},{900,350}},{1,{24,24},{375,250}},{1,{24,24},{50,450}},{1,{24,24},{250,300}},{1,{24,24},{775,275}},{1,{24,24},{200,900}},{1,{24,24},{225,25}},{1,{24,24},{625,900}},{1,{24,24},{200,525}},{1,{24,24},{850,750}},{1,{24,24},{525,900}},{1,{24,24},{775,150}},{1,{24,24},{375,325}},{1,{24,24},{275,275}},{1,{24,24},{500,375}},{1,{24,24},{350,0}},{1,{24,24},{550,475}},{1,{24,24},{875,25}},{1,{24,24},{225,750}},{1,{24,24},{550,650}},{1,{24,24},{600,50}},{1,{24,24},{800,325}},{1,{24,24},{650,775}},{1,{24,24},{150,625}},{1,{24,24},{25,800}},{1,{24,24},{925,900}},{1,{24,24},{75,850}},{1,{24,24},{250,100}},{1,{24,24},{875,375}},{1,{24,24},{750,225}},{1,{24,24},{400,225}},{1,{24,24},{700,250}},{1,{24,24},{550,400}},{2,{24,24},{275,75}},{1,{24,24},{950,550}},{1,{24,24},{250,450}},{1,{24,24},{550,275}},{1,{24,24},{875,475}},{1,{24,24},{725,675}},{1,{24,24},{625,200}},{1,{24,24},{750,400}},{1,{24,24},{150,550}},{1,{24,24},{750,950}},{1,{24,24},{750,575}},{1,{24,24},{225,450}},{1,{24,24},{900,150}},{1,{24,24},{750,325}},{1,{24,24},{775,50}},{1,{24,24},{75,650}},{1,{24,24},{525,275}},{1,{24,24},{625,975}},{1,{24,24},{675,775}},{1,{24,24},{825,375}},{1,{24,24},{975,875}},{1,{24,24},{600,25}},{1,{24,24},{225,300}},{1,{24,24},{200,300}},{1,{24,24},{475,125}},{1,{24,24},{800,975}},{1,{24,24},{0,50}},{1,{24,24},{375,425}},{1,{24,24},{0,850}},{1,{24,24},{650,50}},{1,{24,24},{300,325}},{1,{24,24},{350,125}},{1,{24,24},{575,100}},{1,{24,24},{875,75}},{1,{24,24},{675,50}},{1,{24,24},{875,325}},{1,{24,24},{250,400}},{1,{24,24},{725,825}},{1,{24,24},{175,100}},{1,{24,24},{200,725}},{1,{24,24},{925,0}},{1,{24,24},{25,475}},{1,{24,24},{100,325}},{1,{24,24},{350,425}},{1,{24,24},{775,425}},{1,{24,24},{275,775}},{1,{24,24},{350,575}},{1,{24,24},{675,25}},{1,{24,24},{850,25}},{1,{24,24},{800,825}},{1,{24,24},{900,225}},{1,{24,24},{950,925}},{1,{24,24},{275,450}},{1,{24,24},{50,325}},{1,{24,24},{125,675}},{1,{24,24},{75,475}},{2,{24,24},{150,200}},{1,{24,24},{225,200}},{1,{24,24},{275,375}},{2,{24,24},{175,175}},{1,{24,24},{100,175}},{1,{24,24},{125,175}},{1,{24,24},{675,225}},{2,{24,24},{200,150}},{1,{24,24},{525,525}},{2,{24,24},{275,25}},{1,{24,24},{400,725}},{1,{24,24},{725,75}},{1,{24,24},{825,975}},{1,{24,24},{575,300}},{2,{24,24},{300,50}},{1,{24,24},{975,950}},{1,{24,24},{975,900}},{1,{24,24},{250,425}},{1,{24,24},{25,150}},{2,{24,24},{350,0}},{2,{24,24},{0,325}},{2,{24,24},{25,300}},{1,{24,24},{0,225}},{1,{24,24},{600,75}},{1,{24,24},{25,525}},{2,{24,24},{100,25}},{1,{24,24},{850,300}},{1,{24,24},{150,225}},{1,{24,24},{725,200}},{1,{24,24},{700,500}},{1,{24,24},{675,875}},{1,{24,24},{50,950}},{1,{24,24},{850,925}},{2,{24,24},{100,225}},{1,{24,24},{775,475}},{2,{24,24},{125,200}},{1,{24,24},{100,225}},{1,{24,24},{475,350}},{2,{24,24},{225,100}},{1,{24,24},{500,975}},{1,{24,24},{75,800}},{1,{24,24},{525,775}},{2,{24,24},{275,50}},{1,{24,24},{75,725}},{2,{24,24},{300,25}},{2,{24,24},{0,300}},{2,{24,24},{325,0}},{2,{24,24},{50,250}},{1,{24,24},{500,750}},{1,{24,24},{225,850}},{2,{24,24},{25,250}},{1,{24,24},{175,75}},{1,{24,24},{475,875}},{1,{24,24},{775,75}},{1,{24,24},{275,950}},{1,{24,24},{775,975}},{1,{24,24},{575,900}},{1,{24,24},{100,675}},{1,{24,24},{275,525}},{1,{24,24},{175,50}},{1,{24,24},{600,775}},{1,{24,24},{175,775}},{2,{24,24},{125,175}},{1,{24,24},{850,600}},{1,{24,24},{950,525}},{2,{24,24},{225,75}},{1,{24,24},{750,300}},{2,{24,24},{75,225}},{1,{24,24},{400,900}},{2,{24,24},{0,275}},{1,{24,24},{50,550}},{2,{24,24},{300,0}},{2,{24,24},{50,225}},{1,{24,24},{275,475}},{2,{24,24},{25,275}},{1,{24,24},{625,675}},{1,{24,24},{625,400}},{1,{24,24},{550,375}},{1,{24,24},{525,150}},{2,{24,24},{125,150}},{1,{24,24},{475,175}},{1,{24,24},{850,700}},{1,{24,24},{525,475}},{1,{24,24},{325,275}},{2,{24,24},{150,125}},{1,{24,24},{925,650}},{2,{24,24},{175,100}},{1,{24,24},{0,0}},{1,{24,24},{450,300}},{1,{24,24},{875,700}},{2,{24,24},{200,75}},{2,{24,24},{225,50}},{1,{24,24},{550,875}},{2,{24,24},{275,0}},{2,{24,24},{0,250}},{1,{24,24},{550,450}},{1,{24,24},{675,325}},{1,{24,24},{325,50}},{1,{24,24},{925,625}},{1,{24,24},{375,475}},{2,{24,24},{100,150}},{1,{24,24},{0,400}},{1,{24,24},{950,375}},{1,{24,24},{750,125}},{2,{24,24},{125,125}},{1,{24,24},{750,775}},{2,{24,24},{175,75}},{1,{24,24},{750,250}},{1,{24,24},{50,425}},{1,{24,24},{625,800}},{1,{24,24},{975,450}},{2,{24,24},{200,50}},{1,{24,24},{225,500}},{2,{24,24},{150,100}},{1,{24,24},{900,625}},{2,{24,24},{225,25}},{1,{24,24},{375,775}},{1,{24,24},{0,275}},{1,{24,24},{275,300}},{2,{24,24},{25,200}},{1,{24,24},{850,575}},{1,{24,24},{75,550}},{2,{24,24},{75,150}},{2,{24,24},{100,125}},{2,{24,24},{50,125}},{2,{24,24},{200,25}},{1,{24,24},{800,850}},{2,{24,24},{0,200}},{2,{24,24},{75,125}},{1,{24,24},{950,575}},{1,{24,24},{100,25}},{1,{24,24},{800,500}},{1,{24,24},{600,225}},{1,{24,24},{200,875}},{1,{24,24},{0,550}},{1,{24,24},{325,775}},{2,{24,24},{175,25}},{1,{24,24},{750,75}},{1,{24,24},{300,75}},{2,{24,24},{0,175}},{2,{24,24},{25,150}},{1,{24,24},{425,250}},{2,{24,24},{225,0}},{1,{24,24},{450,550}},{2,{24,24},{125,50}},{2,{24,24},{100,75}},{2,{24,24},{175,0}},{1,{24,24},{400,625}},{1,{24,24},{875,0}},{1,{24,24},{300,350}},{1,{24,24},{50,0}},{2,{24,24},{75,75}},{1,{24,24},{650,850}},{1,{24,24},{125,75}},{2,{24,24},{100,50}},{1,{24,24},{950,700}},{1,{24,24},{550,575}},{1,{24,24},{650,475}},{2,{24,24},{50,75}},{2,{24,24},{75,50}},{1,{24,24},{725,650}},{1,{24,24},{350,300}},{2,{24,24},{25,75}},{2,{24,24},{50,50}},{1,{24,24},{450,625}},{1,{24,24},{150,600}},{1,{24,24},{125,550}},{1,{24,24},{900,675}},{1,{24,24},{800,675}},{2,{24,24},{150,25}},{1,{24,24},{275,800}},{1,{24,24},{425,475}},{1,{24,24},{425,50}},{2,{24,24},{25,50}},{2,{24,24},{50,25}},{1,{24,24},{175,275}},{1,{24,24},{900,900}},{1,{24,24},{700,575}},{1,{24,24},{650,875}},{2,{24,24},{75,0}},{2,{24,24},{25,25}},{2,{24,24},{50,0}},{2,{24,24},{0,25}},{1,{24,24},{125,350}},{1,{24,24},{150,725}},{1,{24,24},{950,975}},{1,{24,24},{750,175}},{1,{24,24},{975,575}},{1,{24,24},{200,700}},{2,{24,24},{0,0}},{2,{24,24},{325,25}},{1,{24,24},{950,950}},{1,{24,24},{900,975}},{1,{24,24},{25,275}},{1,{24,24},{425,450}},{1,{24,24},{575,350}},{1,{24,24},{775,100}},{1,{24,24},{300,600}},{1,{24,24},{900,25}},{1,{24,24},{450,100}},{1,{24,24},{400,300}},{1,{24,24},{900,950}},{1,{24,24},{925,925}},{1,{24,24},{950,900}},{1,{24,24},{700,300}},{1,{24,24},{225,825}},{1,{24,24},{75,400}},{1,{24,24},{850,975}},{1,{24,24},{150,850}},{1,{24,24},{250,600}},{1,{24,24},{725,275}},{1,{24,24},{425,500}},{1,{24,24},{200,150}},{1,{24,24},{50,375}},{1,{24,24},{950,875}},{1,{24,24},{875,950}},{1,{24,24},{975,850}},{1,{24,24},{950,850}},{1,{24,24},{700,675}},{1,{24,24},{825,950}},{1,{24,24},{275,350}},{1,{24,24},{700,475}},{1,{24,24},{925,850}},{1,{24,24},{675,675}},{1,{24,24},{850,775}},{1,{24,24},{875,275}},{1,{24,24},{950,825}},{1,{24,24},{975,800}},{1,{24,24},{775,950}},{1,{24,24},{800,950}},{1,{24,24},{225,600}},{1,{24,24},{525,50}},{1,{24,24},{675,650}},{1,{24,24},{875,875}},{1,{24,24},{850,900}},{1,{24,24},{900,850}},{1,{24,24},{925,825}},{1,{24,24},{425,525}},{1,{24,24},{975,775}},{1,{24,24},{200,200}},{1,{24,24},{750,975}},{1,{24,24},{775,875}},{1,{24,24},{800,925}},{1,{24,24},{425,850}},{1,{24,24},{850,875}},{1,{24,24},{400,875}},{1,{24,24},{825,900}},{1,{24,24},{375,75}},{1,{24,24},{900,825}},{1,{24,24},{250,150}},{1,{24,24},{400,375}},{1,{24,24},{725,975}},{1,{24,24},{675,175}},{1,{24,24},{600,975}},{1,{24,24},{475,575}},{1,{24,24},{975,425}},{1,{24,24},{800,650}},{1,{24,24},{700,450}},{1,{24,24},{0,325}},{1,{24,24},{500,475}},{1,{24,24},{950,750}},{1,{24,24},{0,425}},{1,{24,24},{975,725}},{1,{24,24},{925,775}},{1,{24,24},{700,975}},{1,{24,24},{450,850}},{1,{24,24},{375,725}},{1,{24,24},{125,925}},{1,{24,24},{775,900}},{1,{24,24},{775,450}},{1,{24,24},{850,825}},{1,{24,24},{825,850}},{1,{24,24},{600,100}},{1,{24,24},{175,325}},{1,{24,24},{0,75}},{1,{24,24},{475,525}},{1,{24,24},{575,475}},{1,{24,24},{900,775}},{1,{24,24},{850,625}},{1,{24,24},{925,750}},{1,{24,24},{25,325}},{1,{24,24},{425,75}},{1,{24,24},{950,725}},{1,{24,24},{975,700}},{1,{24,24},{700,950}},{1,{24,24},{25,0}},{1,{24,24},{100,600}},{1,{24,24},{150,375}},{1,{24,24},{750,900}},{2,{24,24},{25,175}},{1,{24,24},{150,900}},{2,{24,24},{75,250}},{1,{24,24},{850,800}},{1,{24,24},{725,125}},{1,{24,24},{575,850}},{1,{24,24},{375,225}},{1,{24,24},{425,625}},{1,{24,24},{925,725}},{1,{24,24},{75,500}},{1,{24,24},{300,100}},{1,{24,24},{625,425}},{1,{24,24},{675,950}},{1,{24,24},{950,475}},{1,{24,24},{700,925}},{1,{24,24},{425,125}},{1,{24,24},{25,975}},{1,{24,24},{475,400}},{1,{24,24},{750,875}},{1,{24,24},{500,550}},{1,{24,24},{150,300}},{1,{24,24},{75,700}},{1,{24,24},{800,75}},{1,{24,24},{25,650}},{1,{24,24},{400,25}},{1,{24,24},{500,525}},{1,{24,24},{925,475}},{1,{24,24},{825,800}},{1,{24,24},{875,750}},{1,{24,24},{25,400}},{1,{24,24},{825,325}},{1,{24,24},{925,700}},{1,{24,24},{425,375}},{1,{24,24},{950,675}},{1,{24,24},{575,450}},{1,{24,24},{775,850}},{1,{24,24},{975,650}},{1,{24,24},{525,800}},{1,{24,24},{375,125}},{1,{24,24},{225,725}},{1,{24,24},{675,925}},{1,{24,24},{925,425}},{1,{24,24},{675,425}},{1,{24,24},{700,900}},{1,{24,24},{275,150}},{1,{24,24},{775,825}},{1,{24,24},{525,0}},{1,{24,24},{900,700}},{1,{24,24},{925,675}},{1,{24,24},{700,200}},{1,{24,24},{300,700}},{1,{24,24},{425,275}},{1,{24,24},{950,650}},{1,{24,24},{775,925}},{1,{24,24},{200,100}},{1,{24,24},{325,100}},{1,{24,24},{625,950}},{1,{24,24},{675,300}},{1,{24,24},{200,275}},{1,{24,24},{725,475}},{1,{24,24},{875,150}},{1,{24,24},{500,575}},{1,{24,24},{675,900}},{1,{24,24},{575,425}},{1,{24,24},{750,825}},{1,{24,24},{50,475}},{1,{24,24},{450,150}},{1,{24,24},{75,325}},{1,{24,24},{75,525}},{1,{24,24},{50,800}},{1,{24,24},{425,425}},{1,{24,24},{700,0}},{1,{24,24},{575,375}},{1,{24,24},{500,250}},{1,{24,24},{850,725}},{1,{24,24},{250,750}},{1,{24,24},{725,850}},{1,{24,24},{150,675}},{1,{24,24},{225,175}},{1,{24,24},{975,100}},{1,{24,24},{25,225}},{1,{24,24},{350,175}},{1,{24,24},{450,0}},{1,{24,24},{500,775}},{1,{24,24},{75,425}},{1,{24,24},{475,850}},{1,{24,24},{750,450}},{1,{24,24},{900,175}},{1,{24,24},{875,625}},{2,{24,24},{75,25}},{1,{24,24},{350,700}},{1,{24,24},{950,625}},{1,{24,24},{300,925}},{1,{24,24},{875,175}},{1,{24,24},{300,25}},{1,{24,24},{575,975}},{1,{24,24},{300,400}},{1,{24,24},{550,825}},{1,{24,24},{350,950}},{1,{24,24},{150,0}},{1,{24,24},{975,600}},{1,{24,24},{25,175}},{1,{24,24},{150,925}},{1,{24,24},{375,950}},{1,{24,24},{625,925}},{1,{24,24},{600,875}},{1,{24,24},{475,500}},{1,{24,24},{650,900}},{1,{24,24},{700,375}},{1,{24,24},{125,800}},{1,{24,24},{650,275}},{1,{24,24},{625,125}},{1,{24,24},{300,650}},{2,{24,24},{50,275}},{2,{24,24},{200,100}},{1,{24,24},{800,175}},{1,{24,24},{25,675}},{1,{24,24},{300,550}},{1,{24,24},{250,675}},{1,{24,24},{350,375}},{1,{24,24},{100,50}},{1,{24,24},{800,750}},{1,{24,24},{875,675}},{1,{24,24},{500,50}},{1,{24,24},{125,425}},{1,{24,24},{550,975}},{1,{24,24},{125,150}},{1,{24,24},{375,25}},{1,{24,24},{600,925}},{2,{24,24},{0,50}},{1,{24,24},{675,850}},{1,{24,24},{700,825}},{1,{24,24},{800,100}},{1,{24,24},{725,800}},{1,{24,24},{300,175}},{1,{24,24},{575,725}},{1,{24,24},{950,175}},{1,{24,24},{275,750}},{1,{24,24},{625,300}},{1,{24,24},{800,725}},{1,{24,24},{825,700}},{1,{24,24},{850,650}},{1,{24,24},{625,450}},{1,{24,24},{650,500}},{1,{24,24},{850,675}},{1,{24,24},{575,325}},{1,{24,24},{875,650}},{1,{24,24},{525,625}},{1,{24,24},{325,725}},{1,{24,24},{150,150}},{1,{24,24},{975,550}},{1,{24,24},{825,675}},{1,{24,24},{800,400}},{1,{24,24},{625,875}},{1,{24,24},{675,825}},{1,{24,24},{725,875}},{1,{24,24},{750,525}},{1,{24,24},{725,725}},{1,{24,24},{850,50}},{1,{24,24},{225,675}},{1,{24,24},{750,0}},{1,{24,24},{200,175}},{1,{24,24},{300,800}},{1,{24,24},{400,775}},{1,{24,24},{725,775}},{1,{24,24},{75,150}},{1,{24,24},{750,750}},{1,{24,24},{775,725}},{1,{24,24},{125,400}},{1,{24,24},{350,325}},{1,{24,24},{925,575}},{1,{24,24},{525,25}},{1,{24,24},{400,325}},{1,{24,24},{425,175}},{1,{24,24},{975,525}},{2,{24,24},{250,75}},{1,{24,24},{850,200}},{1,{24,24},{550,925}},{1,{24,24},{625,725}},{1,{24,24},{325,550}},{1,{24,24},{650,825}},{1,{24,24},{675,800}},{1,{24,24},{200,225}},{1,{24,24},{725,750}},{1,{24,24},{750,725}},{1,{24,24},{500,650}},{1,{24,24},{525,75}},{2,{24,24},{100,0}},{1,{24,24},{450,800}},{1,{24,24},{925,500}},{1,{24,24},{975,275}},{2,{24,24},{100,175}},{1,{24,24},{175,400}},{1,{24,24},{500,950}},{1,{24,24},{700,150}},{1,{24,24},{200,450}},{1,{24,24},{875,600}},{1,{24,24},{900,575}},{1,{24,24},{925,550}},{1,{24,24},{850,225}},{1,{24,24},{750,800}},{1,{24,24},{500,675}},{1,{24,24},{475,975}},{1,{24,24},{750,700}},{1,{24,24},{550,900}},{1,{24,24},{800,150}},{1,{24,24},{25,875}},{1,{24,24},{575,550}},{1,{24,24},{25,50}},{1,{24,24},{425,550}},{1,{24,24},{575,250}},{1,{24,24},{250,225}},{1,{24,24},{825,725}},{1,{24,24},{250,200}},{1,{24,24},{375,925}},{1,{24,24},{125,475}},{1,{24,24},{400,175}},{1,{24,24},{525,375}},{1,{24,24},{625,825}},{1,{24,24},{375,700}},{1,{24,24},{650,800}},{1,{24,24},{700,750}},{1,{24,24},{825,475}},{1,{24,24},{125,700}},{1,{24,24},{875,575}},{1,{24,24},{425,750}},{1,{24,24},{925,25}},{1,{24,24},{900,550}},{1,{24,24},{900,50}},{1,{24,24},{525,700}},{1,{24,24},{925,525}},{1,{24,24},{550,225}},{1,{24,24},{450,275}},{1,{24,24},{625,0}},{1,{24,24},{25,25}},{1,{24,24},{25,300}},{1,{24,24},{250,975}},{1,{24,24},{950,500}},{1,{24,24},{425,300}},{1,{24,24},{975,475}},{1,{24,24},{375,500}},{1,{24,24},{250,500}},{1,{24,24},{175,650}},{1,{24,24},{975,300}},{1,{24,24},{350,250}},{1,{24,24},{475,950}},{1,{24,24},{175,350}},{1,{24,24},{125,50}},{1,{24,24},{500,925}},{2,{24,24},{250,25}},{1,{24,24},{875,775}},{1,{24,24},{600,825}},{1,{24,24},{700,725}},{1,{24,24},{150,475}},{1,{24,24},{175,475}},{1,{24,24},{675,750}},{1,{24,24},{750,675}},{1,{24,24},{775,650}},{1,{24,24},{375,650}},{1,{24,24},{575,750}},{1,{24,24},{175,925}},{2,{24,24},{50,175}},{1,{24,24},{350,50}},{1,{24,24},{725,600}},{1,{24,24},{825,650}},{1,{24,24},{475,50}},{1,{24,24},{50,850}},{1,{24,24},{425,975}},{1,{24,24},{100,425}},{1,{24,24},{500,900}},{1,{24,24},{525,875}},{1,{24,24},{325,600}},{1,{24,24},{575,825}},{1,{24,24},{25,425}},{1,{24,24},{175,850}},{1,{24,24},{175,150}},{1,{24,24},{300,125}},{1,{24,24},{775,225}},{1,{24,24},{0,700}},{1,{24,24},{150,650}},{1,{24,24},{275,50}},{1,{24,24},{825,775}},{1,{24,24},{325,500}},{1,{24,24},{675,725}},{1,{24,24},{475,375}},{1,{24,24},{125,850}},{1,{24,24},{375,800}},{1,{24,24},{800,550}},{1,{24,24},{850,400}},{1,{24,24},{825,575}},{1,{24,24},{900,500}},{1,{24,24},{850,850}},{1,{24,24},{700,50}},{1,{24,24},{400,975}},{1,{24,24},{425,950}},{1,{24,24},{275,850}},{1,{24,24},{350,725}},{1,{24,24},{575,650}},{1,{24,24},{950,325}},{1,{24,24},{50,825}},{1,{24,24},{450,925}},{1,{24,24},{775,775}},{1,{24,24},{500,875}},{1,{24,24},{575,800}},{1,{24,24},{275,725}},{1,{24,24},{600,950}},{1,{24,24},{625,750}},{1,{24,24},{150,575}},{1,{24,24},{250,950}},{1,{24,24},{825,250}},{1,{24,24},{0,500}},{1,{24,24},{725,900}},{1,{24,24},{675,700}},{1,{24,24},{650,575}},{1,{24,24},{975,825}},{1,{24,24},{400,75}},{1,{24,24},{850,125}},{1,{24,24},{0,925}},{1,{24,24},{100,475}},{1,{24,24},{25,625}},{1,{24,24},{750,625}},{1,{24,24},{675,100}},{1,{24,24},{800,575}},{1,{24,24},{850,525}},{1,{24,24},{25,350}},{1,{24,24},{825,550}},{1,{24,24},{925,450}},{1,{24,24},{50,350}},{1,{24,24},{950,425}},{1,{24,24},{625,175}},{1,{24,24},{675,275}},{1,{24,24},{875,500}},{1,{24,24},{450,750}},{1,{24,24},{850,0}},{1,{24,24},{450,900}},{1,{24,24},{525,825}},{1,{24,24},{800,0}},{1,{24,24},{550,800}},{1,{24,24},{325,125}},{1,{24,24},{575,775}},{2,{24,24},{175,150}},{1,{24,24},{625,850}},{1,{24,24},{500,850}},{1,{24,24},{650,700}},{1,{24,24},{725,625}},{1,{24,24},{925,100}},{1,{24,24},{700,650}},{1,{24,24},{375,675}},{1,{24,24},{675,400}},{1,{24,24},{825,525}},{1,{24,24},{0,600}},{1,{24,24},{500,600}},{1,{24,24},{900,450}},{1,{24,24},{400,200}},{1,{24,24},{800,250}},{1,{24,24},{50,200}},{1,{24,24},{75,575}},{1,{24,24},{350,975}},{1,{24,24},{725,425}},{1,{24,24},{75,775}},{1,{24,24},{875,50}},{1,{24,24},{400,925}},{1,{24,24},{525,250}},{1,{24,24},{850,500}},{1,{24,24},{875,450}},{1,{24,24},{650,950}},{1,{24,24},{600,400}},{1,{24,24},{550,625}},{1,{24,24},{0,800}},{1,{24,24},{800,625}},{1,{24,24},{50,725}},{1,{24,24},{875,250}},{1,{24,24},{150,975}},{1,{24,24},{575,200}},{1,{24,24},{325,350}},{1,{24,24},{275,400}},{1,{24,24},{325,975}},{1,{24,24},{125,200}},{1,{24,24},{475,700}},{1,{24,24},{100,300}},{1,{24,24},{625,700}},{1,{24,24},{100,550}},{1,{24,24},{600,250}},{1,{24,24},{275,675}},{1,{24,24},{950,150}},{1,{24,24},{625,275}},{1,{24,24},{650,450}},{1,{24,24},{650,675}},{1,{24,24},{825,925}},{1,{24,24},{700,625}},{1,{24,24},{250,0}},{1,{24,24},{500,625}},{1,{24,24},{100,700}},{1,{24,24},{150,700}},{1,{24,24},{825,500}},{1,{24,24},{850,475}},{1,{24,24},{450,875}},{1,{24,24},{900,425}},{1,{24,24},{200,675}},{1,{24,24},{675,525}},{1,{24,24},{925,400}},{1,{24,24},{425,875}},{1,{24,24},{975,200}},{1,{24,24},{350,925}},{1,{24,24},{475,825}},{1,{24,24},{600,900}},{1,{24,24},{600,700}},{1,{24,24},{525,600}},{1,{24,24},{900,125}},{1,{24,24},{950,400}},{1,{24,24},{325,375}},{1,{24,24},{775,700}},{1,{24,24},{225,250}},{1,{24,24},{200,650}},{1,{24,24},{700,600}},{1,{24,24},{675,625}},{1,{24,24},{750,550}},{1,{24,24},{200,75}},{1,{24,24},{775,525}},{1,{24,24},{950,350}},{2,{24,24},{100,100}},{1,{24,24},{400,150}},{1,{24,24},{725,575}},{1,{24,24},{775,675}},{1,{24,24},{75,300}},{1,{24,24},{50,875}},{1,{24,24},{850,450}},{1,{24,24},{325,325}},{1,{24,24},{875,425}},{1,{24,24},{925,375}},{1,{24,24},{900,400}},{1,{24,24},{200,550}},{1,{24,24},{300,975}},{1,{24,24},{475,200}},{1,{24,24},{875,850}},{1,{24,24},{200,50}},{1,{24,24},{450,825}},{1,{24,24},{975,0}},{1,{24,24},{600,675}},{1,{24,24},{325,25}},{1,{24,24},{625,650}},{1,{24,24},{225,775}},{1,{24,24},{675,600}},{1,{24,24},{725,550}},{1,{24,24},{825,450}},{1,{24,24},{250,25}},{1,{24,24},{775,500}},{1,{24,24},{525,750}},{2,{24,24},{100,200}},{1,{24,24},{925,350}},{1,{24,24},{875,400}},{1,{24,24},{275,975}},{1,{24,24},{300,950}},{1,{24,24},{850,150}},{1,{24,24},{350,900}},{1,{24,24},{400,850}},{1,{24,24},{425,825}},{1,{24,24},{475,775}},{1,{24,24},{525,950}},{1,{24,24},{950,125}},{1,{24,24},{550,700}},{1,{24,24},{625,625}},{1,{24,24},{600,650}},{1,{24,24},{650,600}},{1,{24,24},{675,575}},{1,{24,24},{275,625}},{1,{24,24},{975,675}},{1,{24,24},{175,25}},{1,{24,24},{825,425}},{1,{24,24},{775,625}},{1,{24,24},{75,100}},{1,{24,24},{950,300}},{1,{24,24},{50,50}},{1,{24,24},{925,325}},{1,{24,24},{500,350}},{1,{24,24},{225,475}},{1,{24,24},{250,700}},{1,{24,24},{650,75}},{1,{24,24},{350,100}},{1,{24,24},{875,100}},{1,{24,24},{900,375}},{1,{24,24},{650,400}},{1,{24,24},{200,600}},{1,{24,24},{375,850}},{1,{24,24},{375,450}},{1,{24,24},{600,175}},{1,{24,24},{400,825}},{1,{24,24},{175,200}},{1,{24,24},{725,225}},{1,{24,24},{450,650}},{1,{24,24},{500,725}},{1,{24,24},{50,600}},{1,{24,24},{600,625}},{1,{24,24},{625,600}},{1,{24,24},{575,75}},{1,{24,24},{725,500}},{1,{24,24},{800,875}},{1,{24,24},{0,300}},{1,{24,24},{800,425}},{1,{24,24},{525,500}},{1,{24,24},{575,525}},{1,{24,24},{0,825}},{1,{24,24},{0,725}},{1,{24,24},{675,550}},{1,{24,24},{450,500}},{1,{24,24},{850,275}},{1,{24,24},{900,325}},{1,{24,24},{925,300}},{1,{24,24},{550,200}},{1,{24,24},{225,975}},{1,{24,24},{525,325}},{1,{24,24},{200,575}},{1,{24,24},{325,850}},{1,{24,24},{0,375}},{1,{24,24},{675,250}},{1,{24,24},{325,875}},{1,{24,24},{750,25}},{1,{24,24},{350,850}},{1,{24,24},{900,800}},{1,{24,24},{100,975}},{1,{24,24},{350,600}},{1,{24,24},{375,825}},{1,{24,24},{925,50}},{1,{24,24},{125,600}},{1,{24,24},{925,250}},{1,{24,24},{525,675}},{1,{24,24},{200,350}},{1,{24,24},{625,575}},{1,{24,24},{725,150}},{1,{24,24},{650,550}},{1,{24,24},{400,600}},{1,{24,24},{75,375}},{1,{24,24},{150,75}},{1,{24,24},{500,800}},{1,{24,24},{225,275}},{1,{24,24},{850,350}},{1,{24,24},{900,300}},{1,{24,24},{925,275}},{1,{24,24},{450,200}},{1,{24,24},{950,250}},{1,{24,24},{25,500}},{1,{24,24},{0,250}},{1,{24,24},{600,850}},{1,{24,24},{175,800}},{1,{24,24},{625,25}},{1,{24,24},{275,900}},{1,{24,24},{700,400}},{1,{24,24},{425,225}},{1,{24,24},{200,975}},{1,{24,24},{300,875}},{1,{24,24},{900,0}},{1,{24,24},{750,650}},{1,{24,24},{475,75}},{1,{24,24},{475,250}},{1,{24,24},{975,500}},{1,{24,24},{525,650}},{1,{24,24},{50,650}},{1,{24,24},{500,825}},{1,{24,24},{375,350}},{1,{24,24},{0,200}},{1,{24,24},{150,100}},{1,{24,24},{775,25}},{1,{24,24},{625,550}},{1,{24,24},{450,725}},{1,{24,24},{675,500}},{1,{24,24},{725,450}},{1,{24,24},{250,800}},{1,{24,24},{200,425}},{1,{24,24},{575,125}},{1,{24,24},{175,500}},{1,{24,24},{950,100}},{1,{24,24},{800,375}},{1,{24,24},{825,350}},{1,{24,24},{50,575}},{1,{24,24},{675,475}},{1,{24,24},{400,700}},{1,{24,24},{125,625}},{1,{24,24},{900,275}},{1,{24,24},{875,300}},{1,{24,24},{125,875}},{1,{24,24},{950,225}},{1,{24,24},{400,800}},{1,{24,24},{700,125}},{1,{24,24},{825,125}},{1,{24,24},{950,600}},{1,{24,24},{175,125}},{1,{24,24},{125,25}},{1,{24,24},{975,375}},{1,{24,24},{150,25}},{1,{24,24},{575,400}},{1,{24,24},{75,0}},{1,{24,24},{300,850}},{1,{24,24},{325,825}},{1,{24,24},{400,750}},{1,{24,24},{425,700}},{1,{24,24},{375,50}},{1,{24,24},{350,800}},{1,{24,24},{925,600}},{1,{24,24},{400,450}},{1,{24,24},{625,525}},{1,{24,24},{0,775}},{1,{24,24},{750,425}},{1,{24,24},{975,750}},{1,{24,24},{775,375}},{1,{24,24},{800,350}},{1,{24,24},{900,875}},{1,{24,24},{300,200}},{1,{24,24},{975,150}},{1,{24,24},{25,75}},{1,{24,24},{950,200}},{1,{24,24},{500,100}},{1,{24,24},{225,900}},{1,{24,24},{50,500}},{1,{24,24},{800,125}},{1,{24,24},{650,925}},{1,{24,24},{550,100}},{1,{24,24},{225,925}},{1,{24,24},{800,25}},{1,{24,24},{350,775}},{1,{24,24},{450,675}},{1,{24,24},{25,725}},{1,{24,24},{475,650}},{1,{24,24},{775,550}},{2,{24,24},{125,25}},{1,{24,24},{975,225}},{1,{24,24},{600,525}},{1,{24,24},{475,750}},{2,{24,24},{0,125}},{1,{24,24},{675,450}},{1,{24,24},{725,400}},{1,{24,24},{75,975}},{1,{24,24},{700,325}},{1,{24,24},{450,525}},{1,{24,24},{925,200}},{1,{24,24},{200,925}},{1,{24,24},{250,550}},{1,{24,24},{825,600}},{1,{24,24},{150,950}},{1,{24,24},{225,0}},{1,{24,24},{275,25}},{1,{24,24},{125,450}},{2,{24,24},{150,50}},{1,{24,24},{675,0}},{1,{24,24},{350,750}},{1,{24,24},{575,50}},{1,{24,24},{750,925}},{1,{24,24},{225,50}},{1,{24,24},{625,500}},{1,{24,24},{525,575}},{1,{24,24},{550,75}},{1,{24,24},{550,550}},{1,{24,24},{600,500}},{1,{24,24},{200,625}},{1,{24,24},{550,850}},{1,{24,24},{650,350}},{1,{24,24},{100,775}},{1,{24,24},{850,250}},{1,{24,24},{825,175}},{1,{24,24},{50,100}},{1,{24,24},{900,200}},{1,{24,24},{375,175}},{1,{24,24},{375,400}},{1,{24,24},{175,625}},{1,{24,24},{925,175}},{1,{24,24},{975,125}},{1,{24,24},{175,900}},{1,{24,24},{650,375}},{1,{24,24},{125,725}},{1,{24,24},{300,775}},{1,{24,24},{100,0}},{1,{24,24},{150,500}},{2,{24,24},{0,75}},{1,{24,24},{25,950}},{1,{24,24},{650,625}},{1,{24,24},{125,900}},{1,{24,24},{525,550}},{1,{24,24},{925,75}},{1,{24,24},{900,250}},{1,{24,24},{825,300}},{1,{24,24},{575,500}},{1,{24,24},{750,50}},{1,{24,24},{275,575}},{1,{24,24},{475,600}},{1,{24,24},{475,25}},{1,{24,24},{775,350}},{1,{24,24},{425,25}},{1,{24,24},{875,200}},{1,{24,24},{175,875}},{1,{24,24},{650,325}},{1,{24,24},{200,125}},{1,{24,24},{400,250}},{1,{24,24},{775,400}},{1,{24,24},{975,50}},{1,{24,24},{300,750}},{1,{24,24},{50,25}},{1,{24,24},{400,550}},{1,{24,24},{400,650}},{1,{24,24},{425,0}},{1,{24,24},{750,600}},{1,{24,24},{525,975}},{1,{24,24},{175,975}},{1,{24,24},{250,50}},{1,{24,24},{825,875}},{1,{24,24},{900,750}},{2,{24,24},{225,125}},{1,{24,24},{550,500}},{1,{24,24},{400,400}},{1,{24,24},{350,525}},{1,{24,24},{525,425}},{1,{24,24},{625,250}},{1,{24,24},{225,550}},{1,{24,24},{800,450}},{1,{24,24},{450,25}},{1,{24,24},{25,550}},{1,{24,24},{300,275}},{1,{24,24},{175,525}},{1,{24,24},{650,650}},{1,{24,24},{500,225}},{1,{24,24},{550,150}},{1,{24,24},{975,75}},{1,{24,24},{675,375}},{1,{24,24},{525,725}},{1,{24,24},{100,900}},{1,{24,24},{700,350}},{1,{24,24},{50,975}},{1,{24,24},{0,25}},{1,{24,24},{75,950}},{1,{24,24},{100,925}},{1,{24,24},{425,650}},{1,{24,24},{200,825}},{1,{24,24},{150,875}},{1,{24,24},{225,800}},{1,{24,24},{250,775}},{1,{24,24},{300,0}},{1,{24,24},{275,600}},{1,{24,24},{775,750}},{1,{24,24},{100,450}},{1,{24,24},{325,200}},{1,{24,24},{300,725}},{1,{24,24},{350,675}},{1,{24,24},{250,175}},{1,{24,24},{425,600}},{1,{24,24},{600,425}},{1,{24,24},{675,350}},{1,{24,24},{75,825}},{1,{24,24},{925,150}},{1,{24,24},{725,300}},{1,{24,24},{825,200}},{1,{24,24},{850,175}},{1,{24,24},{125,500}},{1,{24,24},{225,375}},{1,{24,24},{450,400}},{1,{24,24},{50,525}},{1,{24,24},{0,650}},{1,{24,24},{450,250}},{1,{24,24},{975,975}},{1,{24,24},{825,825}},{1,{24,24},{925,125}},{1,{24,24},{200,800}},{1,{24,24},{300,500}},{1,{24,24},{75,925}},{1,{24,24},{400,0}},{1,{24,24},{325,750}},{1,{24,24},{425,325}},{1,{24,24},{325,675}},{1,{24,24},{450,125}},{1,{24,24},{675,200}},{1,{24,24},{475,0}},{1,{24,24},{375,625}},{1,{24,24},{275,200}},{1,{24,24},{425,575}},{1,{24,24},{375,150}},{1,{24,24},{550,25}},{1,{24,24},{875,800}},{1,{24,24},{500,500}},{1,{24,24},{250,725}},{2,{24,24},{50,200}},{1,{24,24},{700,875}},{1,{24,24},{325,475}},{1,{24,24},{550,775}},{1,{24,24},{625,375}},{1,{24,24},{800,200}},{1,{24,24},{875,125}},{1,{24,24},{950,50}},{1,{24,24},{975,25}},{1,{24,24},{400,475}},{1,{24,24},{375,100}},{1,{24,24},{700,75}},{1,{24,24},{0,975}},{1,{24,24},{50,925}},{1,{24,24},{100,875}},{1,{24,24},{700,700}},{1,{24,24},{225,950}},{1,{24,24},{200,775}},{1,{24,24},{300,675}},{1,{24,24},{350,625}},{1,{24,24},{225,150}},{1,{24,24},{600,475}},{1,{24,24},{325,175}},{1,{24,24},{0,350}},{1,{24,24},{275,925}},{1,{24,24},{525,450}},{1,{24,24},{475,100}},{1,{24,24},{400,575}},{1,{24,24},{600,375}},{1,{24,24},{600,325}},{1,{24,24},{650,225}},{1,{24,24},{700,275}},{1,{24,24},{725,250}},{1,{24,24},{775,200}},{1,{24,24},{475,900}},{1,{24,24},{625,50}},{1,{24,24},{250,525}},{1,{24,24},{825,0}},{1,{24,24},{650,0}},{1,{24,24},{825,150}},{1,{24,24},{475,300}},{1,{24,24},{125,225}},{1,{24,24},{900,75}},{1,{24,24},{575,700}},{1,{24,24},{25,925}},{1,{24,24},{50,900}},{1,{24,24},{650,200}},{1,{24,24},{100,850}},{1,{24,24},{350,500}},{1,{24,24},{675,125}},{1,{24,24},{150,800}},{1,{24,24},{100,150}},{1,{24,24},{325,250}},{1,{24,24},{125,825}},{1,{24,24},{325,625}},{1,{24,24},{850,375}},{1,{24,24},{300,50}},{1,{24,24},{25,850}},{1,{24,24},{350,550}},{1,{24,24},{625,150}},{1,{24,24},{650,300}},{1,{24,24},{250,375}},{1,{24,24},{825,750}},{1,{24,24},{575,875}},{1,{24,24},{775,600}},{1,{24,24},{25,900}},{1,{24,24},{475,275}},{1,{24,24},{475,425}},{1,{24,24},{150,775}},{1,{24,24},{225,700}},{1,{24,24},{275,650}},{1,{24,24},{425,200}},{1,{24,24},{300,625}},{1,{24,24},{425,100}},{1,{24,24},{500,200}},{1,{24,24},{775,325}},{1,{24,24},{400,525}},{1,{24,24},{900,925}},{1,{24,24},{775,125}},{1,{24,24},{475,450}},{1,{24,24},{525,400}},{1,{24,24},{975,925}},{2,{24,24},{75,200}},{1,{24,24},{825,100}},{1,{24,24},{0,125}},{1,{24,24},{850,75}},{1,{24,24},{150,750}},{1,{24,24},{750,500}},{1,{24,24},{875,975}},{1,{24,24},{500,75}},{1,{24,24},{400,500}},{1,{24,24},{450,450}},{1,{24,24},{950,0}},{1,{24,24},{200,250}},{1,{24,24},{325,0}},{1,{24,24},{700,850}},{1,{24,24},{350,350}},{1,{24,24},{75,275}},{1,{24,24},{600,800}},{1,{24,24},{750,150}},{1,{24,24},{100,800}},{1,{24,24},{625,325}},{1,{24,24},{125,750}},{1,{24,24},{125,375}},{1,{24,24},{175,700}},{1,{24,24},{475,225}},{1,{24,24},{550,300}},{1,{24,24},{225,650}},{1,{24,24},{450,975}},{1,{24,24},{450,425}},{1,{24,24},{525,350}},{1,{24,24},{550,325}},{1,{24,24},{0,750}},{1,{24,24},{275,425}},{2,{24,24},{250,100}},{1,{24,24},{350,650}},{1,{24,24},{625,350}},{1,{24,24},{925,950}},{1,{24,24},{825,50}},{1,{24,24},{25,825}},{1,{24,24},{800,525}},{1,{24,24},{400,350}},{1,{24,24},{150,175}},{1,{24,24},{775,300}},{1,{24,24},{800,775}},{1,{24,24},{450,700}},{1,{24,24},{75,875}},{1,{24,24},{800,50}},{1,{24,24},{200,475}},{1,{24,24},{300,450}},{1,{24,24},{50,775}},{1,{24,24},{75,750}},{1,{24,24},{650,750}},{1,{24,24},{350,475}},{1,{24,24},{450,375}},{1,{24,24},{600,750}},{1,{24,24},{50,625}},{1,{24,24},{25,700}},{1,{24,24},{525,300}},{1,{24,24},{650,175}},{1,{24,24},{125,0}},{1,{24,24},{25,775}},{1,{24,24},{225,575}},{1,{24,24},{175,550}},{1,{24,24},{575,150}},{1,{24,24},{550,250}},{1,{24,24},{650,150}},{1,{24,24},{725,350}},{1,{24,24},{600,575}},{1,{24,24},{325,300}},{1,{24,24},{950,275}},{1,{24,24},{600,125}},{1,{24,24},{600,450}},{1,{24,24},{275,500}},{1,{24,24},{600,150}},{1,{24,24},{775,0}},{1,{24,24},{500,275}},{1,{24,24},{350,875}},{1,{24,24},{650,125}},{1,{24,24},{50,700}},{1,{24,24},{175,175}},{1,{24,24},{175,575}},{1,{24,24},{325,950}},{1,{24,24},{450,75}},{1,{24,24},{25,125}},{1,{24,24},{300,300}},{1,{24,24},{225,625}},{1,{24,24},{100,825}},{1,{24,24},{525,225}},{1,{24,24},{300,475}},{1,{24,24},{350,75}},{1,{24,24},{650,250}},{1,{24,24},{650,100}},{1,{24,24},{50,675}},{1,{24,24},{75,75}},{1,{24,24},{450,350}},{1,{24,24},{300,425}},{1,{24,24},{125,650}},{1,{24,24},{300,150}},{1,{24,24},{700,25}},{1,{24,24},{200,500}},{1,{24,24},{100,375}},{1,{24,24},{375,550}},{1,{24,24},{75,600}},{1,{24,24},{375,900}},{1,{24,24},{300,825}},{1,{24,24},{200,850}},{1,{24,24},{500,150}},{1,{24,24},{250,250}},{1,{24,24},{700,525}},{1,{24,24},{725,700}},{1,{24,24},{175,450}},{1,{24,24},{875,900}},{1,{24,24},{500,125}},{1,{24,24},{525,100}},{1,{24,24},{775,800}},{1,{24,24},{150,450}},{1,{24,24},{175,425}},{1,{24,24},{200,400}},{1,{24,24},{100,500}},{1,{24,24},{225,875}},{1,{24,24},{150,425}},{1,{24,24},{75,175}},{1,{24,24},{225,350}},{1,{24,24},{425,150}},{1,{24,24},{50,225}},{1,{24,24},{325,700}},{1,{24,24},{575,625}},{1,{24,24},{25,375}},{1,{24,24},{450,600}},{1,{24,24},{50,150}},{1,{24,24},{675,975}},{1,{24,24},{500,25}},{1,{24,24},{375,375}},{1,{24,24},{100,400}},{1,{24,24},{275,225}},{1,{24,24},{0,475}},{1,{24,24},{950,75}},{1,{24,24},{100,950}},{1,{24,24},{700,800}},{1,{24,24},{250,125}},{2,{24,24},{200,0}},{1,{24,24},{225,75}},{1,{24,24},{125,100}}}}}
iconIndices: { string } = icons[1]
idIndices: { string } = icons[2]
iconRegistry: { [number]: { number | { number } } } = icons[3]

Lucide.Icons = iconIndices
function Lucide.GetAsset(name: string)
        local size = 48

        local iconIndex = table.find(iconIndices, name)

        if not iconIndex then
                return nil
        end

        local currentDifference = math.huge
        local currentSize = size

        for registrySize, _ in iconRegistry do
                local diff = math.abs(size - registrySize)

                if diff < currentDifference then
                        currentDifference = diff
                        currentSize = registrySize
                end
        end

        local icon = iconRegistry[currentSize][iconIndex]
        if icon then
                return {
                        IconName = name,
                        Url = idIndices[icon[1]],
                        ImageRectSize = Vector2.new(icon[2][1], icon[2][2]),
                        ImageRectOffset = Vector2.new(icon[3][1], icon[3][2]),
                }
        end

        return nil
end

return Lucide

]=]

local Library = loadstring([=[
local cloneref = (cloneref or clonereference or function(instance: any)
        return instance
end)
local InputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TextService: TextService = cloneref(game:GetService("TextService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local Teams: Teams = cloneref(game:GetService("Teams"))
local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
Mouse = cloneref(LocalPlayer:GetMouse())

DrawingLib = { drawing_replaced = true, new = function(...) error("Drawing is not supported.") end }
IsBadDrawingLib = false

if typeof(getgenv) == "function" and typeof(getgenv().Drawing) == "table" then
    DrawingLib = getgenv().Drawing
end

setclipboard = setclipboard or nil
local getgenv = getgenv or function()
        return shared
end
local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
local GetHUI = gethui or function()
        return CoreGui
end

local assert = function(condition, errorMessage)
        if not condition then
                error(if errorMessage then errorMessage else "assert failed", 3)
        end
end

local function SafeParentUI(Instance: Instance, Parent: Instance | () -> Instance)
        local success, _error = pcall(function()
                if not Parent then
                        Parent = CoreGui
                end

                local DestinationParent
                if typeof(Parent) == "function" then
                        DestinationParent = Parent()
                else
                        DestinationParent = Parent
                end

                Instance.Parent = DestinationParent
        end)

        if not (success and Instance.Parent) then
                Instance.Parent = LocalPlayer:WaitForChild("PlayerGui", math.huge)
        end
end

local function ParentUI(UI: Instance, SkipHiddenUI: boolean?)
        if SkipHiddenUI then
                SafeParentUI(UI, CoreGui)
                return
        end

        pcall(ProtectGui, UI)
        SafeParentUI(UI, GetHUI)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder = 999
ScreenGui.ResetOnSpawn = false
ParentUI(ScreenGui)

-- UI Scale for mobile support
local UIScaleInstance = Instance.new("UIScale")
UIScaleInstance.Scale = 1
UIScaleInstance.Parent = ScreenGui

-- Auto-detect mobile on load and adjust UI
task.spawn(function()
    task.wait(2)
    local viewport = workspace.CurrentCamera.ViewportSize
    if viewport.X < 600 then
        -- Phone: scale down + shrink window
        UIScaleInstance.Scale = 0.65
        if LibraryMainOuterFrame then
            LibraryMainOuterFrame.Size = UDim2.fromOffset(420, 400)
        end
    elseif viewport.X < 900 then
        -- Tablet: medium scale
        UIScaleInstance.Scale = 0.8
        if LibraryMainOuterFrame then
            LibraryMainOuterFrame.Size = UDim2.fromOffset(480, 460)
        end
    end
end)

local ModalElement = Instance.new("TextButton")
ModalElement.BackgroundTransparency = 1
ModalElement.Modal = false
ModalElement.Size = UDim2.fromScale(0, 0)
ModalElement.AnchorPoint = Vector2.zero
ModalElement.Text = ""
ModalElement.ZIndex = -999
ModalElement.Parent = ScreenGui

local LibraryMainOuterFrame = nil

local Toggles = {}
local Options = {}
local Labels = {}
local Buttons = {}
local Tooltips = {}
local Dialogues = {}

local BaseURL = ""
local CustomImageManager = {}
local CustomImageManagerAssets = {
    Cursor = {
        RobloxId = 9619665977,
        Path = "LinoriaLib/assets/Cursor.png",
        URL = BaseURL .. "assets/Cursor.png",

        Id = nil,
    },

    DropdownArrow = {
        RobloxId = 6282522798,
        Path = "LinoriaLib/assets/DropdownArrow.png",
        URL = BaseURL .. "assets/DropdownArrow.png",

        Id = nil,
    },

    Checker = {
        RobloxId = 12977615774,
        Path = "LinoriaLib/assets/Checker.png",
        URL = BaseURL .. "assets/Checker.png",

        Id = nil,
    },

    CheckerLong = {
        RobloxId = 12978095818,
        Path = "LinoriaLib/assets/CheckerLong.png",
        URL = BaseURL .. "assets/CheckerLong.png",

        Id = nil,
    },

    SaturationMap = {
        RobloxId = 4155801252,
        Path = "LinoriaLib/assets/SaturationMap.png",
        URL = BaseURL .. "assets/SaturationMap.png",

        Id = nil,
    }
}
do
    local function RecursiveCreatePath(Path: string, IsFile: boolean?)
        if not isfolder or not makefolder then
            return
        end

        local Segments = Path:split("/")
        local TraversedPath = ""

        if IsFile then
            table.remove(Segments, #Segments)
        end

        for _, Segment in ipairs(Segments) do
            if not isfolder(TraversedPath .. Segment) then
                makefolder(TraversedPath .. Segment)
            end

            TraversedPath = TraversedPath .. Segment .. "/"
        end

        return TraversedPath
    end

    function CustomImageManager.AddAsset(AssetName: string, RobloxAssetId: number, URL: string, ForceRedownload: boolean?)
        if CustomImageManagerAssets[AssetName] ~= nil then
            error(string.format("Asset %q already exists", AssetName))
        end

        assert(typeof(RobloxAssetId) == "number", "RobloxAssetId must be a number")

        CustomImageManagerAssets[AssetName] = {
            RobloxId = RobloxAssetId,
            Path = string.format("Obsidian/custom_assets/%s", AssetName),
            URL = URL,

            Id = nil,
        }

        CustomImageManager.DownloadAsset(AssetName, ForceRedownload)
    end

    function CustomImageManager.GetAsset(AssetName: string)
        if not CustomImageManagerAssets[AssetName] then
            return nil
        end

        local AssetData = CustomImageManagerAssets[AssetName]
        if AssetData.Id then
            return AssetData.Id
        end

        local AssetID = string.format("rbxassetid://%s", AssetData.RobloxId)

        if getcustomasset then
            local Success, NewID = pcall(getcustomasset, AssetData.Path)

            if Success and NewID then
                AssetID = NewID
            end
        end

        AssetData.Id = AssetID
        return AssetID
    end

    function CustomImageManager.DownloadAsset(AssetName: string, ForceRedownload: boolean?)

        return true, nil
    end

    for AssetName, _ in CustomImageManagerAssets do
        CustomImageManager.DownloadAsset(AssetName)
    end
end

local DPIScale = 1;
local Library = {
    Registry = {};
    RegistryMap = {};
    HudRegistry = {};

    FontColor = Color3.fromRGB(245, 245, 250);
    MainColor = Color3.fromRGB(35, 32, 38);
    BackgroundColor = Color3.fromRGB(22, 20, 24);

    AccentColor = Color3.fromRGB(220, 25, 25);
    DisabledAccentColor = Color3.fromRGB(120, 120, 120);

    OutlineColor = Color3.fromRGB(50, 45, 50);
    DisabledOutlineColor = Color3.fromRGB(60, 60, 68);

    DisabledTextColor = Color3.fromRGB(152, 152, 158);

    RiskColor = Color3.fromRGB(255, 50, 50);

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};
    DependencyGroupboxes = {};

    UnloadSignals = {};
    Signals = {};

    ActiveTab = nil;
    TotalTabs = 0;

    ScreenGui = ScreenGui;
    KeybindFrame = nil;
    KeybindContainer = nil;
    Window = { Holder = nil; Tabs = {}; };

    VideoLink = "";

    Toggled = false;
    ToggleKeybind = nil;

    IsMobile = false;
    DevicePlatform = Enum.Platform.None;

    CanDrag = true;
    CantDragForced = false;

    Unloaded = false;

    Notify = nil;
    NotifySide = "Left";
    ShowCustomCursor = true;
    ShowToggleFrameInKeybinds = true;
    NotifyOnError = false;

    SaveManager = nil;
    ThemeManager = nil;

    Toggles = Toggles;
    Options = Options;
    Labels = Labels;
    Buttons = Buttons;
    Dialogues = Dialogues;
    ActiveDialog = nil;

    ImageManager = CustomImageManager;
    ShowCursorBinding = string.sub(tostring({}), 10);
}

if RunService:IsStudio() then
   Library.IsMobile = InputService.TouchEnabled and not InputService.MouseEnabled
else
    pcall(function() Library.DevicePlatform = InputService:GetPlatform() end)
    Library.IsMobile = (Library.DevicePlatform == Enum.Platform.Android or Library.DevicePlatform == Enum.Platform.IOS)
end

Library.MinSize = if Library.IsMobile then Vector2.new(550, 200) else Vector2.new(500, 350)

local function ApplyDPIScale(Position)
    return UDim2.new(Position.X.Scale, Position.X.Offset * DPIScale, Position.Y.Scale, Position.Y.Offset * DPIScale)
end

local function ApplyTextScale(TextSize)
    return TextSize * DPIScale
end

local function GetTableSize(t)
    local n = 0
    for _, _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function GetPlayers(ExcludeLocalPlayer, ReturnInstances)
    local PlayerList = Players:GetPlayers()

    if ExcludeLocalPlayer then
        local Idx = table.find(PlayerList, LocalPlayer)

        if Idx then
            table.remove(PlayerList, Idx)
        end
    end

    table.sort(PlayerList, function(Player1, Player2)
        return Player1.Name:lower() < Player2.Name:lower()
    end)

    if ReturnInstances == true then
        return PlayerList
    end

    local FixedPlayerList = {}
    for _, player in next, PlayerList do
        FixedPlayerList[#FixedPlayerList + 1] = player.Name
    end

    return FixedPlayerList
end

local function GetTeams(ReturnInstances)
    local TeamList = Teams:GetTeams()

    table.sort(TeamList, function(Team1, Team2)
        return Team1.Name:lower() < Team2.Name:lower()
    end)

    if ReturnInstances == true then
        return TeamList
    end

    local FixedTeamList = {}
    for _, team in next, TeamList do
        FixedTeamList[#FixedTeamList + 1] = team.Name
    end

    return FixedTeamList
end

local function Trim(Text: string)
    return Text:match("^%s*(.-)%s*$")
end

type Icon = {
    Url: string,
    Id: number,
    IconName: string,
    ImageRectOffset: Vector2,
    ImageRectSize: Vector2,
}

type IconModule = {
    Icons: { string },
    GetAsset: (Name: string) -> Icon?,
}

local FetchIcons, Icons = pcall(function()
    return (loadstring(
        lucide_embedded_source
    ) :: () -> IconModule)()
end)

function IsValidCustomIcon(Icon: string)
    return typeof(Icon) == "string"
        and (Icon:match("rbxasset") or Icon:match("roblox%.com/asset/%?id=") or Icon:match("rbxthumb://type="))
end

function Library:GetIcon(IconName: string)
    if not FetchIcons then
        return
    end

    local Success, Icon = pcall(Icons.GetAsset, IconName)
    if not Success then
        return
    end

    return Icon
end

function Library:GetCustomIcon(IconName: string)
    if not IsValidCustomIcon(IconName) then
        return Library:GetIcon(IconName)
    else
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
            Custom = true,
        }
    end
end

function Library:SetIconModule(module: IconModule)
    FetchIcons = true
    Icons = module
end

function Library:GetBetterColor(Color: Color3, Add: number): Color3
    Add = Add * 2
    return Color3.fromRGB(
        math.clamp(Color.R * 255 + Add, 0, 255),
        math.clamp(Color.G * 255 + Add, 0, 255),
        math.clamp(Color.B * 255 + Add, 0, 255)
    )
end

function Library:Validate(Table: { [string]: any }, Template: { [string]: any }): { [string]: any }
    if typeof(Table) ~= "table" then
        return Template
    end

    for k, v in pairs(Template) do
        if typeof(k) == "number" then
            continue
        end

        if typeof(v) == "table" then
            Table[k] = Library:Validate(Table[k], v)
        elseif Table[k] == nil then
            Table[k] = v
        end
    end

    return Table
end

function Library:SetDPIScale(value: number)
    assert(type(value) == "number", "Expected type number for DPI scale but got " .. typeof(value))

    DPIScale = value / 100
    Library.MinSize = (if Library.IsMobile then Vector2.new(550, 200) else Vector2.new(500, 350)) * DPIScale
end

function Library:SafeCallback(Func, ...)

    if not (Func and typeof(Func) == "function") then
        return
    end

    local Result = table.pack(xpcall(Func, function(Error)
        task.defer(error, debug.traceback(Error, 2))
        if Library.NotifyOnError then
            Library:Notify(Error)
        end

        return Error
    end, ...))

    if not Result[1] then
        return nil
    end

    return table.unpack(Result, 2, Result.n)
end

function Library:AttemptSave()
    if (not Library.SaveManager) then return end
    Library.SaveManager:Save()
end

function Library:Create(Class, Properties)
    local _Instance = Class

    if typeof(Class) == "string" then
        _Instance = Instance.new(Class)
    end

    for Property, Value in next, Properties do
        if (Property == "Size" or Property == "Position") then
            Value = ApplyDPIScale(Value)
        elseif Property == "TextSize" then
            Value = ApplyTextScale(Value)
        end

        local success, err = pcall(function()
            _Instance[Property] = Value
        end)

        if (not success) then
            warn(err)
        end
    end

    return _Instance
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1

    return Library:Create("UIStroke", {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    })
end

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create("TextLabel", {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    })

    Library:ApplyTextStroke(_Instance)

    Library:AddToRegistry(_Instance, {
        TextColor3 = "FontColor";
    }, IsHud)

    return Library:Create(_Instance, Properties)
end

function Library:MakeDraggable(Instance, Cutoff, IsMainWindow)
    Instance.Active = true

    if Library.IsMobile == false then
        -- ============================================================
        -- SMOOTH DRAG SYSTEM (Illusionary Hub style)
        -- Uses direct InputBegan on the instance + RenderStepped loop
        -- for frame-perfect cursor tracking. No delay, no jitter.
        -- ============================================================
        local Dragging = false
        local DragStart = Vector2.zero
        local StartPos = UDim2.new()
        local RenderConn = nil

        local function startDrag(mousePos)
            Dragging = true
            DragStart = mousePos
            StartPos = Instance.Position

            -- Kill any existing render loop
            if RenderConn then
                RenderConn:Disconnect()
                RenderConn = nil
            end

            -- RenderStepped loop = perfect 1:1 cursor tracking, no lag
            RenderConn = RunService.RenderStepped:Connect(function()
                if not Dragging then
                    if RenderConn then
                        RenderConn:Disconnect()
                        RenderConn = nil
                    end
                    return
                end
                local mp = InputService:GetMouseLocation()
                local delta = mp - DragStart
                Instance.Position = UDim2.new(
                    StartPos.X.Scale,
                    StartPos.X.Offset + delta.X,
                    StartPos.Y.Scale,
                    StartPos.Y.Offset + delta.Y
                )
            end)
        end

        local function endDrag()
            Dragging = false
            if RenderConn then
                RenderConn:Disconnect()
                RenderConn = nil
            end
        end

        Instance.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if IsMainWindow == true and Library.CantDragForced == true then
                    return
                end
                -- Check that the window is visible before allowing drag
                if IsMainWindow == true and Library.Window and Library.Window.Holder then
                    if not Library.Window.Holder.Visible then return end
                end

                local mousePos = InputService:GetMouseLocation()
                local objPos = Vector2.new(
                    mousePos.X - Instance.AbsolutePosition.X,
                    mousePos.Y - Instance.AbsolutePosition.Y
                )

                -- Cutoff check: only allow drag if click is within cutoff
                -- (we set cutoff=10000 so dragging works from anywhere)
                if objPos.Y > (Cutoff or 40) then
                    return
                end
                -- Also reject clicks outside the window bounds
                if objPos.X < 0 or objPos.Y < 0 then
                    return
                end
                if objPos.X > Instance.AbsoluteSize.X or objPos.Y > Instance.AbsoluteSize.Y then
                    return
                end

                startDrag(mousePos)
            end
        end)

        -- End drag on global mouse release (works even if cursor left window)
        InputService.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if Dragging then
                    endDrag()
                end
            end
        end)

        -- Safety: kill drag if window becomes invisible
        if IsMainWindow and Library.Window and Library.Window.Holder then
            Library.Window.Holder:GetPropertyChangedSignal("Visible"):Connect(function()
                if not Library.Window.Holder.Visible and Dragging then
                    endDrag()
                end
            end)
        end
    else
        -- ============================================================
        -- MOBILE DRAG (touch) — also uses RenderStepped for smoothness
        -- ============================================================
        local Dragging = false
        local DragInput = nil
        local DragStart = Vector2.zero
        local StartPos = UDim2.new()
        local RenderConn = nil

        local function startTouchDrag(input)
            DragInput = input
            DragStart = input.Position
            StartPos = Instance.Position
            Dragging = true

            if RenderConn then
                RenderConn:Disconnect()
                RenderConn = nil
            end

            RenderConn = RunService.RenderStepped:Connect(function()
                if not Dragging then
                    if RenderConn then
                        RenderConn:Disconnect()
                        RenderConn = nil
                    end
                    return
                end
                -- Find the active touch matching our DragInput
                local cur = nil
                for _, t in ipairs(InputService:GetTouches()) do
                    if t.UserInputState == Enum.UserInputState.Change then
                        cur = t
                        break
                    end
                end
                if cur then
                    local delta = cur.Position - DragStart
                    Instance.Position = UDim2.new(
                        StartPos.X.Scale,
                        StartPos.X.Offset + delta.X,
                        StartPos.Y.Scale,
                        StartPos.Y.Offset + delta.Y
                    )
                end
            end)
        end

        local function endTouchDrag()
            Dragging = false
            DragInput = nil
            if RenderConn then
                RenderConn:Disconnect()
                RenderConn = nil
            end
        end

        InputService.TouchStarted:Connect(function(Input)
            if IsMainWindow == true and Library.CantDragForced == true then
                return
            end

            if not Dragging and Library:MouseIsOverFrame(Instance, Input) then
                if IsMainWindow == true and Library.Window and Library.Window.Holder then
                    if not Library.Window.Holder.Visible then return end
                end

                local objPos = Vector2.new(
                    Input.Position.X - Instance.AbsolutePosition.X,
                    Input.Position.Y - Instance.AbsolutePosition.Y
                )
                if objPos.Y > (Cutoff or 40) then
                    return
                end
                if objPos.X < 0 or objPos.Y < 0 then
                    return
                end
                if objPos.X > Instance.AbsoluteSize.X or objPos.Y > Instance.AbsoluteSize.Y then
                    return
                end

                startTouchDrag(Input)
            end
        end)

        InputService.TouchEnded:Connect(function(Input)
            if Input == DragInput then
                endTouchDrag()
            end
        end)
    end
end

function Library:MakeDraggableUsingParent(Instance, Parent, Cutoff, IsMainWindow)
    Instance.Active = true

    if Library.IsMobile == false then
        Instance.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if IsMainWindow == true and Library.CantDragForced == true then
                    return
                end

                local ObjPos = Vector2.new(
                    Mouse.X - Parent.AbsolutePosition.X,
                    Mouse.Y - Parent.AbsolutePosition.Y
                )

                if ObjPos.Y > (Cutoff or 40) then
                    return
                end

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    Parent.Position = UDim2.new(
                        0,
                        Mouse.X - ObjPos.X + (Parent.Size.X.Offset * Parent.AnchorPoint.X),
                        0,
                        Mouse.Y - ObjPos.Y + (Parent.Size.Y.Offset * Parent.AnchorPoint.Y)
                    )

                    RunService.RenderStepped:Wait()
                end
            end
        end)
    else
        Library:MakeDraggable(Parent, Cutoff, IsMainWindow)
    end
end

function Library:MakeResizable(Instance, MinSize)
    if Library.IsMobile then
        return
    end

    Instance.Active = true

    local ResizerImage_Size = 25 * DPIScale
    local ResizerImage_HoverTransparency = 0.5

    local Resizer = Library:Create("Frame", {
        SizeConstraint = Enum.SizeConstraint.RelativeXX;
        BackgroundColor3 = Color3.new(0, 0, 0);
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 30, 0, 30);
        Position = UDim2.new(1, -30, 1, -30);
        Visible = true;
        ClipsDescendants = true;
        ZIndex = 1;
        Parent = Instance;
    })

    local ResizerImage = Library:Create("ImageButton", {
        BackgroundColor3 = Library.AccentColor;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(2, 0, 2, 0);
        Position = UDim2.new(1, -30, 1, -30);
        ZIndex = 2;
        Parent = Resizer;
    })

    local ResizerImageUICorner = Library:Create("UICorner", {
        CornerRadius = UDim.new(0.5, 0);
        Parent = ResizerImage;
    })

    Library:AddToRegistry(ResizerImage, { BackgroundColor3 = "AccentColor"; })

    Resizer.Size = UDim2.fromOffset(ResizerImage_Size, ResizerImage_Size)
    Resizer.Position = UDim2.new(1, -ResizerImage_Size, 1, -ResizerImage_Size)
    MinSize = MinSize or Library.MinSize

    local OffsetPos
    Resizer.Parent = Instance

    local function FinishResize(Transparency)
        ResizerImage.Position = UDim2.new()
        ResizerImage.Size = UDim2.new(2, 0, 2, 0)
        ResizerImage.Parent = Resizer
        ResizerImage.BackgroundTransparency = Transparency
        ResizerImageUICorner.Parent = ResizerImage
        OffsetPos = nil
    end

    ResizerImage.MouseButton1Down:Connect(function()
        if not OffsetPos then
            OffsetPos = Vector2.new(Mouse.X - (Instance.AbsolutePosition.X + Instance.AbsoluteSize.X), Mouse.Y - (Instance.AbsolutePosition.Y + Instance.AbsoluteSize.Y))

            ResizerImage.BackgroundTransparency = 1
            ResizerImage.Size = UDim2.fromOffset(Library.ScreenGui.AbsoluteSize.X, Library.ScreenGui.AbsoluteSize.Y)
            ResizerImage.Position = UDim2.new()
            ResizerImageUICorner.Parent = nil
            ResizerImage.Parent = Library.ScreenGui
        end
    end)

    ResizerImage.MouseMoved:Connect(function()
        if OffsetPos then
            local MousePos = Vector2.new(Mouse.X - OffsetPos.X, Mouse.Y - OffsetPos.Y)
            local FinalSize = Vector2.new(math.clamp(MousePos.X - Instance.AbsolutePosition.X, MinSize.X, math.huge), math.clamp(MousePos.Y - Instance.AbsolutePosition.Y, MinSize.Y, math.huge))
            Instance.Size = UDim2.fromOffset(FinalSize.X, FinalSize.Y)
        end
    end)

    ResizerImage.MouseEnter:Connect(function()
        FinishResize(ResizerImage_HoverTransparency)
    end)

    ResizerImage.MouseLeave:Connect(function()
        FinishResize(1)
    end)

    ResizerImage.MouseButton1Up:Connect(function()
        FinishResize(ResizerImage_HoverTransparency)
    end)
end

function Library:AddToolTip(InfoStr, DisabledInfoStr, HoverInstance)
    InfoStr = typeof(InfoStr) == "string" and InfoStr or nil
    DisabledInfoStr = typeof(DisabledInfoStr) == "string" and DisabledInfoStr or nil

    local Tooltip = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;

        ZIndex = 100;
        Parent = Library.ScreenGui;

        Visible = false;
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1);

        TextSize = 14;
        Text = InfoStr;
        TextColor3 = Library.FontColor;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1;

        Parent = Tooltip;
    })

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
    })

    Library:AddToRegistry(Label, {
        TextColor3 = "FontColor",
    })

    local TooltipTable = {
        Tooltip = Tooltip;
        Disabled = false;

        Signals = {};
    }
    local IsHovering = false

    local function UpdateText(Text)
        if Text == nil then return end

        local X, Y = Library:GetTextBounds(Text, Library.Font, 14 * DPIScale)

        Label.Text = Text
        Tooltip.Size = UDim2.fromOffset(X + 5, Y + 4)
        Label.Size = UDim2.fromOffset(X, Y)
    end

    local function GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal)
        local ConnectionType = typeof(Connection)
        if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
            table.insert(TooltipTable.Signals, Connection)
        end

        return Connection
    end

    UpdateText(InfoStr)

    GiveSignal(HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            Tooltip.Visible = false
            return
        end

        if not TooltipTable.Disabled then
            if InfoStr == nil or InfoStr == "" then
                Tooltip.Visible = false
                return
            end

            if Label.Text ~= InfoStr then
                UpdateText(InfoStr)
            end
        else
            if DisabledInfoStr == nil or DisabledInfoStr == "" then
                Tooltip.Visible = false
                return
            end

            if Label.Text ~= DisabledInfoStr then
                UpdateText(DisabledInfoStr)
            end
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            if TooltipTable.Disabled == true and DisabledInfoStr == nil then break end

            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end

        IsHovering = false
        Tooltip.Visible = false
    end))

    GiveSignal(HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end))

    if LibraryMainOuterFrame then
        GiveSignal(LibraryMainOuterFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if LibraryMainOuterFrame.Visible == false then
                IsHovering = false
                Tooltip.Visible = false
            end
        end))
    end

    function TooltipTable:Destroy()
        for Idx = #TooltipTable.Signals, 1, -1 do
            local Connection = table.remove(TooltipTable.Signals, Idx)
            if Connection and Connection.Connected then
                Connection:Disconnect()
            end
        end

        Tooltip:Destroy()
    end

    table.insert(Tooltips, TooltipTable)
    return TooltipTable
end

function Library:MouseIsOverFrame(Frame, Input)
    local Pos = Mouse
    if Library.IsMobile and Input then
        Pos = Input.Position
    end

    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
    if Pos.X >= AbsPos.X and Pos.X <= AbsPos.X + AbsSize.X
        and Pos.Y >= AbsPos.Y and Pos.Y <= AbsPos.Y + AbsSize.Y then

        return true
    end

    return false
end

function Library:IsFrameInsideDialog(Frame)
    if not Library.ActiveDialog then return false end

    local Pos = Frame.AbsolutePosition
    local AbsPos, AbsSize = Library.ActiveDialog.Container.AbsolutePosition, Library.ActiveDialog.Container.AbsoluteSize

    if Pos.X >= AbsPos.X and Pos.X <= AbsPos.X + AbsSize.X
        and Pos.Y >= AbsPos.Y and Pos.Y <= AbsPos.Y + AbsSize.Y then

        return true
    end

    return false
end

function Library:MouseIsOverOpenedFrame(Input)

    if Library.ActiveDialog then
        if Library:MouseIsOverFrame(Library.ActiveDialog.Container, Input) then
            return false
        end

        return true
    end

    for Frame, _ in next, Library.OpenedFrames do
        if Library:MouseIsOverFrame(Frame, Input) then
            return true
        end
    end

    return false
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault, condition)
    local function undoHighlight()
        local Reg = Library.RegistryMap[Instance]

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx
            end
        end
    end

    local function doHighlight()
        if condition and not condition() then
            undoHighlight()
            return
        end

        if Library.ActiveDialog and not Library:IsFrameInsideDialog(Instance) then
            undoHighlight()
            return
        end

        local Reg = Library.RegistryMap[Instance]

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx
            end
        end
    end

    HighlightInstance.MouseEnter:Connect(doHighlight)
    HighlightInstance.MouseMoved:Connect(doHighlight)
    HighlightInstance.MouseLeave:Connect(undoHighlight)
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update()
    end
end

function Library:UpdateDependencyGroupboxes()
    for _, Depbox in next, Library.DependencyGroupboxes do
        Depbox:Update()
    end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB
end

function Library:GetTextBounds(Text, Font, Size, Resolution)

    if typeof(Resolution) == "number" then
        Resolution = Vector2.new(Resolution, 10000)
    end

    local Bounds = TextService:GetTextSize(Text:gsub("<%/?[%w:]+[^>]*>", ""), Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, S, V / 1.5)
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    }

    table.insert(Library.Registry, Data)
    Library.RegistryMap[Instance] = Data

    if IsHud then
        table.insert(Library.HudRegistry, Data)
    end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance]

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx)
            end
        end

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx)
            end
        end

        Library.RegistryMap[Instance] = nil
    end
end

function Library:UpdateColorsUsingRegistry()

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if typeof(ColorIdx) == "string" then
                Object.Instance[Property] = Library[ColorIdx]
            elseif typeof(ColorIdx) == "function" then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal)
    local ConnectionType = typeof(Connection)
    if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
        table.insert(Library.Signals, Connection)
    end

    return Connection
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        if Connection and Connection.Connected then
            Connection:Disconnect()
        end
    end

    for _, UnloadCallback in Library.UnloadSignals do
        Library:SafeCallback(UnloadCallback)
    end

    for _, Tooltip in Tooltips do
        Library:SafeCallback(Tooltip.Destroy, Tooltip)
    end

    Library.Unloaded = true
    ScreenGui:Destroy()

    getgenv().Linoria = nil
end

function Library:OnUnload(Callback)
    table.insert(Library.UnloadSignals, Callback)
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.Unloaded then
        return
    end

    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance)
    end
end))

local Templates = {

    Window = {
        Title = "No Title",
        AutoShow = false,
        Position = UDim2.fromOffset(175, 50),
        Size = UDim2.fromOffset(0, 0),
        AnchorPoint = Vector2.zero,
        TabPadding = 1,
        MenuFadeTime = 0.2,
        NotifySide = "Left",
        ShowCustomCursor = true,
        UnlockMouseWhileOpen = true,
        Center = false
    },

    Video = {
        Video = "",
        Looped = false,
        Playing = false,
        Volume = 1,
        Height = 200,
        Visible = true,
    },
    UIPassthrough = {
        Instance = nil,
        Height = 24,
        Visible = true,
    }
}

local BaseAddons = {}
do
    local BaseAddonsFuncs = {}

        function BaseAddonsFuncs:AddKeyPicker(Idx, Info)
        local ParentObj = self
        local ToggleLabel = self.TextLabel

        assert(Info.Default, string.format("AddKeyPicker (IDX: %s): Missing default value.", tostring(Idx)))

        local KeyPicker = {
            Value = nil;
            Modifiers = {};
            DisplayValue = nil;

            Toggled = false;
            Mode = Info.Mode or "Toggle";
            Type = "KeyPicker";
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        }

        if KeyPicker.Mode == "Press" then
            assert(ParentObj.Type == "Label", "KeyPicker with the mode \"Press\" can be only applied on Labels.")

            KeyPicker.SyncToggleState = false
            Info.Modes = { "Press" }
            Info.Mode = "Press"
        end

        if KeyPicker.SyncToggleState then
            Info.Modes = { "Toggle", "Hold" }

            if not table.find(Info.Modes, Info.Mode) then
                Info.Mode = "Toggle"
            end
        end

        local Picking = false

        local SpecialKeys = {
            ["MB1"] = Enum.UserInputType.MouseButton1,
            ["MB2"] = Enum.UserInputType.MouseButton2,
            ["MB3"] = Enum.UserInputType.MouseButton3
        }

        local SpecialKeysInput = {
            [Enum.UserInputType.MouseButton1] = "MB1",
            [Enum.UserInputType.MouseButton2] = "MB2",
            [Enum.UserInputType.MouseButton3] = "MB3"
        }

        local Modifiers = {
            ["LAlt"] = Enum.KeyCode.LeftAlt,
            ["RAlt"] = Enum.KeyCode.RightAlt,

            ["LCtrl"] = Enum.KeyCode.LeftControl,
            ["RCtrl"] = Enum.KeyCode.RightControl,

            ["LShift"] = Enum.KeyCode.LeftShift,
            ["RShift"] = Enum.KeyCode.RightShift,

            ["Tab"] = Enum.KeyCode.Tab,
            ["CapsLock"] = Enum.KeyCode.CapsLock
        }

        local ModifiersInput = {
            [Enum.KeyCode.LeftAlt] = "LAlt",
            [Enum.KeyCode.RightAlt] = "RAlt",

            [Enum.KeyCode.LeftControl] = "LCtrl",
            [Enum.KeyCode.RightControl] = "RCtrl",

            [Enum.KeyCode.LeftShift] = "LShift",
            [Enum.KeyCode.RightShift] = "RShift",

            [Enum.KeyCode.Tab] = "Tab",
            [Enum.KeyCode.CapsLock] = "CapsLock"
        }

        local IsModifierInput = function(Input)
            return Input.UserInputType == Enum.UserInputType.Keyboard and ModifiersInput[Input.KeyCode] ~= nil
        end

        local GetActiveModifiers = function()
            local ActiveModifiers = {}

            for Name, Input in Modifiers do
                if table.find(ActiveModifiers, Name) then continue end
                if not InputService:IsKeyDown(Input) then continue end

                table.insert(ActiveModifiers, Name)
            end

            return ActiveModifiers
        end

        local AreModifiersHeld = function(Required)
            if not (typeof(Required) == "table" and GetTableSize(Required) > 0) then
                return true
            end

            local ActiveModifiers = GetActiveModifiers()
            local Holding = true

            for _, Name in Required do
                if table.find(ActiveModifiers, Name) then continue end

                Holding = false
                break
            end

            return Holding
        end

        local IsInputDown = function(Input)
            if not Input then
                return false
            end

            if SpecialKeysInput[Input.UserInputType] ~= nil then
                return InputService:IsMouseButtonPressed(Input.UserInputType) and not InputService:GetFocusedTextBox()
            elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                return InputService:IsKeyDown(Input.KeyCode) and not InputService:GetFocusedTextBox()
            else
                return false
            end
        end

        local ConvertToInputModifiers = function(CurrentModifiers)
            local InputModifiers = {}

            for _, name in CurrentModifiers do
                table.insert(InputModifiers, Modifiers[name])
            end

            return InputModifiers
        end

        local VerifyModifiers = function(CurrentModifiers)
            if typeof(CurrentModifiers) ~= "table" then
                return {}
            end

            local ValidModifiers = {}

            for _, name in CurrentModifiers do
                if not Modifiers[name] then continue end

                table.insert(ValidModifiers, name)
            end

            return ValidModifiers
        end

        local PickOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        })

        local PickInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        })

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        })

        local KeybindsToggle = {}
        do
            local KeybindsToggleContainer = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 18);
                Visible = false;
                ZIndex = 110;
                Parent = Library.KeybindContainer;
            })

            local KeybindsToggleOuter = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 13, 0, 13);
                Position = UDim2.new(0, 0, 0, 6);
                Visible = true;
                ZIndex = 110;
                Parent = KeybindsToggleContainer;
            })

            Library:AddToRegistry(KeybindsToggleOuter, {
                BorderColor3 = "Black";
            })

            local KeybindsToggleInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 111;
                Parent = KeybindsToggleOuter;
            })

            Library:AddToRegistry(KeybindsToggleInner, {
                BackgroundColor3 = "MainColor";
                BorderColor3 = "OutlineColor";
            })

            local KeybindsToggleLabel = Library:CreateLabel({
                BackgroundTransparency = 1;
                Size = UDim2.new(0, 216, 1, 0);
                Position = UDim2.new(1, 6, 0, -1);
                TextSize = 14;
                Text = "";
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 111;
                Parent = KeybindsToggleInner;
            })

            Library:Create("UIListLayout", {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = KeybindsToggleLabel;
            })

            local KeybindsToggleRegion = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(0, 170, 1, 0);
                ZIndex = 113;
                Parent = KeybindsToggleOuter;
            })

            Library:OnHighlight(KeybindsToggleRegion, KeybindsToggleOuter,
                { BorderColor3 = "AccentColor" },
                { BorderColor3 = "Black" },
                function()
                    return true
                end
            )

            function KeybindsToggle:Display(State)
                KeybindsToggleInner.BackgroundColor3 = State and Library.AccentColor or Library.MainColor
                KeybindsToggleInner.BorderColor3 = State and Library.AccentColorDark or Library.OutlineColor
                KeybindsToggleLabel.TextColor3 = State and Library.AccentColor or Library.FontColor

                Library.RegistryMap[KeybindsToggleInner].Properties.BackgroundColor3 = State and "AccentColor" or "MainColor"
                Library.RegistryMap[KeybindsToggleInner].Properties.BorderColor3 = State and "AccentColorDark" or "OutlineColor"
                Library.RegistryMap[KeybindsToggleLabel].Properties.TextColor3 = State and "AccentColor" or "FontColor"
            end

            function KeybindsToggle:SetText(Text)
                KeybindsToggleLabel.Text = Text
            end

            function KeybindsToggle:SetVisibility(bool)
                KeybindsToggleContainer.Visible = bool
            end

            function KeybindsToggle:SetNormal(bool)
                KeybindsToggle.Normal = bool

                KeybindsToggleOuter.BackgroundTransparency = if KeybindsToggle.Normal then 1 else 0

                KeybindsToggleInner.BackgroundTransparency = if KeybindsToggle.Normal then 1 else 0
                KeybindsToggleInner.BorderSizePixel = if KeybindsToggle.Normal then 0 else 1

                KeybindsToggleLabel.Position = if KeybindsToggle.Normal then UDim2.new(1, -13, 0, -1) else UDim2.new(1, 6, 0, -1)
            end

            KeyPicker.DoClick = function(...) end
            Library:GiveSignal(KeybindsToggleRegion.InputBegan:Connect(function(Input)
                if Library.Unloaded then
                    return
                end

                if KeybindsToggle.Normal then return end

                if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                    KeyPicker.Toggled = not KeyPicker.Toggled
                    KeyPicker:DoClick()
                end
            end))

            KeybindsToggle.Loaded = true
        end

        local ModeSelectOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 80, 0, 0);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        })

        local function UpdateMenuOuterPos()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y)
        end

        UpdateMenuOuterPos()
        ToggleLabel:GetPropertyChangedSignal("AbsolutePosition"):Connect(UpdateMenuOuterPos)

        local ModeSelectInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 0, 3);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        })

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        })

        local Modes = Info.Modes or { "Always", "Toggle", "Hold" }
        local ModeButtons = {}
        local UnbindButton = {}

        for Idx, Mode in next, Modes do
            local ModeButton = {}

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            })
            ModeSelectInner.Size = ModeSelectInner.Size + UDim2.new(0, 0, 0, 15)
            ModeSelectOuter.Size = ModeSelectOuter.Size + UDim2.new(0, 0, 0, 18)

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect()
                end

                KeyPicker.Mode = Mode

                Label.TextColor3 = Library.AccentColor
                Library.RegistryMap[Label].Properties.TextColor3 = "AccentColor"

                ModeSelectOuter.Visible = false
            end

            function ModeButton:Deselect()
                KeyPicker.Mode = nil

                Label.TextColor3 = Library.FontColor
                Library.RegistryMap[Label].Properties.TextColor3 = "FontColor"
            end

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select()
                end
            end)

            if Mode == KeyPicker.Mode then
                ModeButton:Select()
            end

            ModeButtons[Mode] = ModeButton
        end

        do
            local UnbindInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Position = UDim2.new(0, 0, 0, ModeSelectInner.Size.Y.Offset + 3);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 15;
                Parent = ModeSelectOuter;
            })

            ModeSelectOuter.Size = ModeSelectOuter.Size + UDim2.new(0, 0, 0, 18)

            Library:AddToRegistry(UnbindInner, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            local UnbindLabel = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = "Unbind Key";
                ZIndex = 16;
                Parent = UnbindInner;
            })

            KeyPicker.SetValue = function(...) end
            function UnbindButton:UnbindKey()
                KeyPicker:SetValue({ nil, KeyPicker.Mode, {} })
                ModeSelectOuter.Visible = false
            end

            UnbindLabel.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    UnbindButton:UnbindKey()
                end
            end)
        end

        function KeyPicker:Display(Text)
            DisplayLabel.Text = Text or KeyPicker.DisplayValue

            PickOuter.Size = UDim2.new(0, 999999, 0, 18)
            RunService.RenderStepped:Wait()
            PickOuter.Size = UDim2.new(0, math.max(28, DisplayLabel.TextBounds.X + 8), 0, 18)
        end

        function KeyPicker:Update()
            if Info.NoUI then
                return
            end

            local State = KeyPicker:GetState()
            local ShowToggle = Library.ShowToggleFrameInKeybinds and KeyPicker.Mode == "Toggle"

            if KeyPicker.SyncToggleState and ParentObj.Value ~= State then
                ParentObj:SetValue(State)
            end

            if KeybindsToggle.Loaded then
                KeybindsToggle:SetNormal(not ShowToggle)

                KeybindsToggle:SetVisibility(true)
                KeybindsToggle:SetText(string.format("[%s] %s (%s)", tostring(KeyPicker.DisplayValue), Info.Text, KeyPicker.Mode))
                KeybindsToggle:Display(State)
            end

            local YSize = 0
            local XSize = 0

            for _, Frame in next, Library.KeybindContainer:GetChildren() do
                if Frame:IsA("Frame") and Frame.Visible then
                    YSize = YSize + 18
                    local Label = Frame:FindFirstChild("TextLabel", true)
                    if not Label then continue end

                    local LabelSize = Label.TextBounds.X + 20
                    if (LabelSize > XSize) then
                        XSize = LabelSize
                    end
                end
            end

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 220), 0, (YSize + 23 + 6) * DPIScale)
            UpdateMenuOuterPos()
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == "Always" then
                return true

            elseif KeyPicker.Mode == "Hold" then
                local Key = KeyPicker.Value
                if Key == "None" then
                    return false
                end

                if not AreModifiersHeld(KeyPicker.Modifiers) then
                    return false
                end

                if SpecialKeys[Key] ~= nil then
                    return InputService:IsMouseButtonPressed(SpecialKeys[Key]) and not InputService:GetFocusedTextBox()
                else
                    return InputService:IsKeyDown(Enum.KeyCode[Key]) and not InputService:GetFocusedTextBox()
                end

            else
                return KeyPicker.Toggled
            end
        end

        function KeyPicker:SetValue(Data, SkipCallback)
            local Key, Mode, Modifiers = Data[1], Data[2], Data[3]

            local IsKeyValid, UserInputType = pcall(function()
                if Key == "None" then
                    Key = nil
                    return nil
                end

                if SpecialKeys[Key] == nil then
                    return Enum.KeyCode[Key]
                end

                return SpecialKeys[Key]
            end)

            if Key == nil then
                KeyPicker.Value = "None"
            elseif IsKeyValid then
                KeyPicker.Value = Key
            else
                KeyPicker.Value = "Unknown"
            end

            KeyPicker.Modifiers = VerifyModifiers(if typeof(Modifiers) == "table" then Modifiers else KeyPicker.Modifiers)
            KeyPicker.DisplayValue = if GetTableSize(KeyPicker.Modifiers) > 0 then (table.concat(KeyPicker.Modifiers, " + ") .. " + " .. KeyPicker.Value) else KeyPicker.Value

            DisplayLabel.Text = KeyPicker.DisplayValue

            if Mode ~= nil and ModeButtons[Mode] ~= nil then
                ModeButtons[Mode]:Select()
            end

            KeyPicker:Display()
            KeyPicker:Update()

            if SkipCallback == true then return end
            local NewModifiers = ConvertToInputModifiers(KeyPicker.Modifiers)
            Library:SafeCallback(KeyPicker.ChangedCallback, UserInputType, NewModifiers)
            Library:SafeCallback(KeyPicker.Changed, UserInputType, NewModifiers)
        end

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback

        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if KeyPicker.Mode == "Press" then
                if KeyPicker.Toggled and Info.WaitForCallback == true then
                    return
                end

                KeyPicker.Toggled = true
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)

            if KeyPicker.Mode == "Press" then
                KeyPicker.Toggled = false
            end
        end

        function KeyPicker:SetModePickerVisibility(bool)
            ModeSelectOuter.Visible = bool
        end

        function KeyPicker:GetModePickerVisibility()
            return ModeSelectOuter.Visible
        end

        PickOuter.InputBegan:Connect(function(PickerInput)
            if PickerInput.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true

                KeyPicker:Display("...")

                local Input
                local ActiveModifiers = {}

                local GetInput = function()
                    Input = InputService.InputBegan:Wait()
                    if InputService:GetFocusedTextBox() then
                        return true
                    end

                    return false
                end

                repeat
                    task.wait()

                    KeyPicker:Display("...")

                    if GetInput() then
                        Picking = false
                        KeyPicker:Update()
                        return
                    end

                    if Input.KeyCode == Enum.KeyCode.Escape then
                        break
                    end

                    if IsModifierInput(Input) then
                        local StopLoop = false

                        repeat
                            task.wait()
                            if InputService:IsKeyDown(Input.KeyCode) then
                                task.wait(0.075)

                                if InputService:IsKeyDown(Input.KeyCode) then

                                    if not table.find(ActiveModifiers, ModifiersInput[Input.KeyCode]) then
                                        ActiveModifiers[#ActiveModifiers + 1] = ModifiersInput[Input.KeyCode]
                                        KeyPicker:Display(table.concat(ActiveModifiers, " + ") .. " + ...")
                                    end

                                    if GetInput() then
                                        StopLoop = true
                                        break
                                    end

                                    if Input.KeyCode == Enum.KeyCode.Escape then
                                        break
                                    end

                                    if not IsModifierInput(Input) then
                                        break
                                    end
                                else
                                    if not table.find(ActiveModifiers, ModifiersInput[Input.KeyCode]) then
                                        break
                                    end
                                end
                            end
                        until false

                        if StopLoop then
                            Picking = false
                            KeyPicker:Update()
                            return
                        end
                    end

                    break
                until false

                local Key = "Unknown"
                if SpecialKeysInput[Input.UserInputType] ~= nil then
                    Key = SpecialKeysInput[Input.UserInputType]
                elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                    Key = Input.KeyCode == Enum.KeyCode.Escape and "None" or Input.KeyCode.Name
                end

                ActiveModifiers = if Input.KeyCode == Enum.KeyCode.Escape or Key == "Unknown" then {} else ActiveModifiers

                KeyPicker.Toggled = false
                KeyPicker:SetValue({ Key, KeyPicker.Mode, ActiveModifiers })

                repeat task.wait() until not IsInputDown(Input) or InputService:GetFocusedTextBox()
                Picking = false

            elseif PickerInput.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                local visible = KeyPicker:GetModePickerVisibility()

                if visible == false then
                    for _, option in next, Options do
                        if option.Type == "KeyPicker" then
                            option:SetModePickerVisibility(false)
                        end
                    end
                end

                KeyPicker:SetModePickerVisibility(not visible)
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            if KeyPicker.Value == "Unknown" then return end

            if (not Picking) and (not InputService:GetFocusedTextBox()) then
                local Key = KeyPicker.Value
                local HoldingModifiers = AreModifiersHeld(KeyPicker.Modifiers)
                local HoldingKey = false

                if HoldingModifiers then
                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            HoldingKey = true
                        end
                    elseif SpecialKeysInput[Input.UserInputType] == Key then
                        HoldingKey = true
                    end
                end

                if KeyPicker.Mode == "Toggle" then
                    if HoldingKey then
                        KeyPicker.Toggled = not KeyPicker.Toggled
                        KeyPicker:DoClick()
                    end
                elseif KeyPicker.Mode == "Press" then
                    if HoldingKey then
                        KeyPicker:DoClick()
                    end
                end

                KeyPicker:Update()
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    KeyPicker:SetModePickerVisibility(false)
                end
            end
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            if (not Picking) then
                KeyPicker:Update()
            end
        end))

        KeyPicker:SetValue({ Info.Default, Info.Mode or "Toggle", Info.DefaultModifiers }, true)
        KeyPicker.DisplayFrame = PickOuter

        KeyPicker.Default = KeyPicker.Value
        KeyPicker.DefaultModifiers = table.clone(KeyPicker.Modifiers or {})

        Options[Idx] = KeyPicker

        return self
    end

    function BaseAddonsFuncs:AddColorPicker(Idx, Info)
        local ParentObj = self
        local ToggleLabel = self.TextLabel

        assert(Info.Default, string.format("AddColorPicker (IDX: %s): Missing default value.", tostring(Idx)))

        local ColorPicker = {
            Value = Info.Default;

            Transparency = Info.Transparency or 0;
            Type = "ColorPicker";
            Title = typeof(Info.Title) == "string" and Info.Title or "Color picker",
            Callback = Info.Callback or function(Color) end;
            Changed = nil,
        }

        local PreviousValues = {
            Value = nil,
            Transparency = nil
        }

        local function RunCallback()
            local NewValue = ColorPicker.Value
            local NewTransparency = ColorPicker.Transparency

            if NewValue == PreviousValues.Value and NewTransparency == PreviousValues.Transparency then
                return
            end

            PreviousValues.Value = ColorPicker.Value
            PreviousValues.Transparency = ColorPicker.Transparency

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value, ColorPicker.Transparency)
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value, ColorPicker.Transparency)
        end

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color:ToHSV()

            ColorPicker.Hue = H
            ColorPicker.Sat = S
            ColorPicker.Vib = V
        end

        ColorPicker:SetHSVFromRGB(ColorPicker.Value)

        local DisplayFrame = Library:Create("Frame", {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        })

        Library:Create("ImageLabel", {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = CustomImageManager.GetAsset("Checker");
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        })

        local PickerFrameOuter = Library:Create("Frame", {
            Name = "Color";
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        })

        DisplayFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18)
        end)

        local PickerFrameInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        })

        local Highlight = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        })

        local SatVibMapOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        })

        local SatVibMapInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        })

        local SatVibMap = Library:Create("ImageLabel", {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = CustomImageManager.GetAsset("SaturationMap");
            Parent = SatVibMapInner;
        })

        local CursorOuter = Library:Create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = CustomImageManager.GetAsset("Cursor");
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        })

        Library:Create("ImageLabel", {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = CustomImageManager.GetAsset("Cursor");
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        })

        local HueSelectorInner = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        })

        local HueCursor = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        })

        local HueBoxOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        })

        local HueBoxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        })

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        })

        local HueBox = Library:Create("TextBox", {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = "Hex color",
            Text = "#FFFFFF",
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        })

        Library:ApplyTextStroke(HueBox)

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        })

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild("TextBox"), {
            Text = "255, 255, 255",
            PlaceholderText = "RGB color",
            TextColor3 = Library.FontColor
        })

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor

        if Info.Transparency then
            TransparencyBoxOuter = Library:Create("Frame", {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            })

            TransparencyBoxInner = Library:Create("Frame", {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            })

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = "OutlineColor" })

            Library:Create("ImageLabel", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = CustomImageManager.GetAsset("CheckerLong");
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            })

            TransparencyCursor = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            })
        end

        Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        })

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create("Frame", {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            })

            Library:Create("UIListLayout", {
                Name = "Layout",
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            })

            Library:Create("UIPadding", {
                Name = "Padding",
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            })

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA("TextLabel") then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            function ContextMenu:Show()
                if Library.IsMobile then
                    Library.CanDrag = false
                end

                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                if Library.IsMobile then
                    Library.CanDrag = true
                end

                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if typeof(Callback) ~= "function" then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                Library:OnHighlight(Button, Button,
                    { TextColor3 = "AccentColor" },
                    { TextColor3 = "FontColor" }
                )

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 or Input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption("Copy color", function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify("Copied color!", 2)
            end)

            ColorPicker.SetValueRGB = function(...) end
            ContextMenu:AddOption("Paste color", function()
                if not Library.ColorClipboard then
                    Library:Notify("You have not copied a color!", 2)
                    return
                end

                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)

            ContextMenu:AddOption("Copy HEX", function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify("Copied hex code to clipboard!", 2)
            end)

            ContextMenu:AddOption("Copy RGB", function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ", "))
                Library:Notify("Copied RGB values to clipboard!", 2)
            end)
        end
        ColorPicker.ContextMenu = ContextMenu

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor"; })
        Library:AddToRegistry(Highlight, { BackgroundColor3 = "AccentColor"; })
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor"; })

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
        Library:AddToRegistry(RgbBox, { TextColor3 = "FontColor", })
        Library:AddToRegistry(HueBox, { TextColor3 = "FontColor", })

        local SequenceTable = {}

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
        end

        Library:Create("UIGradient", {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        })

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            })

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0)
            end

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0)
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0)

            HueBox.Text = "#" .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ", ")
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, ColorPicker)
        end

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == "Color" then
                    Frame.Visible = false
                    Library.OpenedFrames[Frame] = nil
                end
            end

            PickerFrameOuter.Visible = true
            Library.OpenedFrames[PickerFrameOuter] = true
        end

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false
            Library.OpenedFrames[PickerFrameOuter] = nil
        end

        function ColorPicker:SetValue(HSV, Transparency)
            if typeof(HSV) == "Color3" then
                ColorPicker:SetValueRGB(HSV, Transparency)
                return
            end

            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])

            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Display()

            RunCallback()
        end

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Display()

            RunCallback()
        end

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == "Color3" then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match("(%d+),%s*(%d+),%s*(%d+)")
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                    local MinX = SatVibMap.AbsolutePosition.X
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX)

                    local MinY = SatVibMap.AbsolutePosition.Y
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX)
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display()

                    RunCallback()

                    RunService.RenderStepped:Wait()
                end

                Library:AttemptSave()
            end
        end)

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display()

                    RunCallback()

                    RunService.RenderStepped:Wait()
                end

                Library:AttemptSave()
            end
        end)

        DisplayFrame.InputBegan:Connect(function(Input)
            if Library:MouseIsOverOpenedFrame(Input) then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end)

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX)

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX))
                        ColorPicker:Display()

                        RunCallback()

                        RunService.RenderStepped:Wait()
                    end

                    Library:AttemptSave()
                end
            end)
        end

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide()
                end

                if not Library:MouseIsOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:MouseIsOverFrame(ContextMenu.Container) and not Library:MouseIsOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display()
        ColorPicker.DisplayFrame = DisplayFrame

        ColorPicker.Default = ColorPicker.Value

        Options[Idx] = ColorPicker

        return self
    end

    function BaseAddonsFuncs:AddDropdown(Idx, Info)
        Info.ReturnInstanceInstead = if typeof(Info.ReturnInstanceInstead) == "boolean" then Info.ReturnInstanceInstead else false

        if Info.SpecialType == "Player" then
            Info.ExcludeLocalPlayer = if typeof(Info.ExcludeLocalPlayer) == "boolean" then Info.ExcludeLocalPlayer else false

            Info.Values = GetPlayers(Info.ExcludeLocalPlayer, Info.ReturnInstanceInstead)
            Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeams(Info.ReturnInstanceInstead)
            Info.AllowNull = true
        end

        assert(Info.Values, string.format("AddDropdown (IDX: %s): Missing dropdown value list.", tostring(Idx)))
        if not (Info.AllowNull or Info.Default) then
            Info.Default = 1
            warn(string.format("AddDropdown (IDX: %s): Missing default value, selected the first index instead. Pass `AllowNull` as true if this was intentional.", tostring(Idx)))
        end

        Info.Searchable = if typeof(Info.Searchable) == "boolean" then Info.Searchable else false
        Info.FormatDisplayValue = if typeof(Info.FormatDisplayValue) == "function" then Info.FormatDisplayValue else nil
        Info.FormatListValue = if typeof(Info.FormatListValue) == "function" then Info.FormatListValue else nil

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            DisabledValues = Info.DisabledValues or {};

            Multi = Info.Multi;
            Type = "Dropdown";
            SpecialType = Info.SpecialType;
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            Callback = Info.Callback or function(Value) end;
            Changed = Info.Changed or function(Value) end;

            OriginalText = Info.Text; Text = Info.Text;
            ExcludeLocalPlayer = Info.ExcludeLocalPlayer;
            ReturnInstanceInstead = Info.ReturnInstanceInstead;
        }

        local Tooltip

        local ParentObj = self
        local ToggleLabel = self.TextLabel
        local Container = self.Container

        local RelativeOffset = 0

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA("UIListLayout") then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset
            end
        end

        local DropdownOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 60, 0, 18);
            Visible = Dropdown.Visible;
            ZIndex = 6;
            Parent = ToggleLabel;
        })

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = "Black";
        })

        local DropdownInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        })

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        })

        local DropdownInnerSearch
        if Info.Searchable then
            DropdownInnerSearch = Library:Create("TextBox", {
                BackgroundTransparency = 1;
                Visible = false;

                Position = UDim2.new(0, 5, 0, 0);
                Size = UDim2.new(0.9, -5, 1, 0);

                Font = Library.Font;
                PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
                PlaceholderText = "Search...";

                Text = "";
                TextColor3 = Library.FontColor;
                TextSize = 14;
                TextStrokeTransparency = 0;
                TextXAlignment = Enum.TextXAlignment.Left;

                ClearTextOnFocus = false;

                ZIndex = 7;
                Parent = DropdownOuter;
            })

            Library:ApplyTextStroke(DropdownInnerSearch)

            Library:AddToRegistry(DropdownInnerSearch, {
                TextColor3 = "FontColor";
            })
        end

        local DropdownArrow = Library:Create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = CustomImageManager.GetAsset("DropdownArrow");
            ZIndex = 8;
            Parent = DropdownInner;
        })

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = "--";
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = false;
            TextTruncate = Enum.TextTruncate.AtEnd;
            RichText = true;
            ZIndex = 7;
            Parent = DropdownInner;
        })

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                return not Dropdown.Disabled
            end
        )

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, DropdownOuter)
            Tooltip.Disabled = Dropdown.Disabled
        end

        local MAX_DROPDOWN_ITEMS = if typeof(Info.MaxVisibleDropdownItems) == "number" then math.clamp(Info.MaxVisibleDropdownItems, 4, 16) else 8

        local ListOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        })

        local OpenedXSizeForList = 0

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1)
        end

        local function RecalculateListSize(YSize)
            local Y = YSize or math.clamp(GetTableSize(Dropdown.Values) * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            ListOuter.Size = UDim2.fromOffset(ListOuter.Visible and OpenedXSizeForList or DropdownOuter.AbsoluteSize.X + 0.5, Y)
        end

        RecalculateListPosition()
        RecalculateListSize()

        DropdownOuter:GetPropertyChangedSignal("AbsolutePosition"):Connect(RecalculateListPosition)
        DropdownOuter:GetPropertyChangedSignal("AbsoluteSize"):Connect(RecalculateListSize)

        local ListInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        })

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local Scrolling = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        })

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = "AccentColor"
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        })

        function Dropdown:UpdateColors()
            ItemList.TextColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            DropdownArrow.ImageColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
        end

        function Dropdown:GenerateDisplayText(SelectedValue)
            local Str = ""

            if Info.Multi and typeof(SelectedValue) == "table" then
                for Idx, Value in next, Dropdown.Values do
                    if SelectedValue[Value] then
                        Str = Str .. tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(Value) or Value) .. ", "
                    end
                end

                Str = Str:sub(1, #Str - 2)
                Str = (Str == "" and "--" or Str)
            else
                if not SelectedValue then
                    return "--"
                end

                Str = tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(SelectedValue) or SelectedValue)
            end

            return Str
        end

        function Dropdown:Display()
            local Str = Dropdown:GenerateDisplayText(Dropdown.Value)
            ItemList.Text = Str

            local X = ListOuter.Visible and OpenedXSizeForList or Library:GetTextBounds(ItemList.Text, Library.Font, ItemList.TextSize, Vector2.new(ToggleLabel.AbsoluteSize.X, math.huge)) + 26
            DropdownOuter.Size = UDim2.new(0, X, 0, 18)
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {}

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value)
                end

                return T
            else
                return Dropdown.Value and 1 or 0
            end
        end

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local DisabledValues = Dropdown.DisabledValues
            local Buttons = {}

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA("UIListLayout") then
                    Element:Destroy()
                end
            end

            local Count = 0
            OpenedXSizeForList = DropdownOuter.AbsoluteSize.X + 0.5

            for Idx, Value in next, Values do
                local StringValue = tostring(Info.FormatListValue and Info.FormatListValue(Value) or Value)
                if Info.Searchable and not string.lower(StringValue):match(string.lower(DropdownInnerSearch.Text)) then
                    continue
                end

                local IsDisabled = table.find(DisabledValues, StringValue)
                local Table = {}

                Count = Count + 1

                local Button = Library:Create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    Text = "";
                    ZIndex = 23;
                    Parent = Scrolling;
                })

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = "MainColor";
                    BorderColor3 = "OutlineColor";
                })

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(StringValue)) or StringValue;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    RichText = true;
                    ZIndex = 25;
                    Parent = Button;
                })

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = IsDisabled and "DisabledAccentColor" or "AccentColor", ZIndex = 24 },
                    { BorderColor3 = "OutlineColor", ZIndex = 23 }
                )

                local Selected

                if Info.Multi then
                    Selected = Dropdown.Value[Value]
                else
                    Selected = Dropdown.Value == Value
                end

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value]
                    else
                        Selected = Dropdown.Value == Value
                    end

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or (IsDisabled and Library.DisabledAccentColor or Library.FontColor)
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and "AccentColor" or (IsDisabled and "DisabledAccentColor" or "FontColor")
                end

                if not IsDisabled then
                    Button.MouseButton1Click:Connect(function(Input)
                        local Try = not Selected

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try

                                if Selected then
                                    Dropdown.Value[Value] = true
                                else
                                    Dropdown.Value[Value] = nil
                                end
                            else
                                Selected = Try

                                if Selected then
                                    Dropdown.Value = Value
                                else
                                    Dropdown.Value = nil
                                end

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton()
                                end
                            end

                            Table:UpdateButton()
                            Dropdown:Display()

                            Library:UpdateDependencyBoxes()
                            Library:UpdateDependencyGroupboxes()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)

                            Library:AttemptSave()
                        end
                    end)
                end

                Table:UpdateButton()
                Dropdown:Display()

                local Str = Dropdown:GenerateDisplayText(Value)
                local X = Library:GetTextBounds(Str, Library.Font, ItemList.TextSize, Vector2.new(ToggleLabel.AbsoluteSize.X, math.huge)) + 26
                if X > OpenedXSizeForList then
                    OpenedXSizeForList = X
                end

                Buttons[Button] = Table
            end

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * (20 * DPIScale)) + 1)

            Scrolling.Visible = false
            Scrolling.Visible = true

            local Y = math.clamp(Count * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            RecalculateListSize(Y)
        end

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValues(NewValues)
            if typeof(NewValues) == "table" then
                for _, val in pairs(NewValues) do
                    table.insert(Dropdown.Values, val)
                end
            elseif typeof(NewValues) == "string" then
                table.insert(Dropdown.Values, NewValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabledValues(NewValues)
            if NewValues then
                Dropdown.DisabledValues = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddDisabledValues(DisabledValues)
            if typeof(DisabledValues) == "table" then
                for _, val in pairs(DisabledValues) do
                    table.insert(Dropdown.DisabledValues, val)
                end
            elseif typeof(DisabledValues) == "string" then
                table.insert(Dropdown.DisabledValues, DisabledValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetVisible(Visibility)
            Dropdown.Visible = Visibility

            DropdownOuter.Visible = Dropdown.Visible
            if not Dropdown.Visible then
                Dropdown:CloseDropdown()
            end
        end

        function Dropdown:SetDisabled(Disabled)
            Dropdown.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            if Disabled then
                Dropdown:CloseDropdown()
            end

            Dropdown:Display()
            Dropdown:UpdateColors()
        end

        function Dropdown:OpenDropdown()
            if Dropdown.Disabled then
                return
            end

            if Library.IsMobile then
                Library.CanDrag = false
            end

            if Info.Searchable then
                ItemList.Visible = false
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = true
            end

            ListOuter.Visible = true
            Library.OpenedFrames[ListOuter] = true
            DropdownArrow.Rotation = 180

            Dropdown:Display()
            RecalculateListSize()
        end

        function Dropdown:CloseDropdown()
            if Library.IsMobile then
                Library.CanDrag = true
            end

            if Info.Searchable then
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = false
                ItemList.Visible = true
            end

            ListOuter.Visible = false
            Library.OpenedFrames[ListOuter] = nil
            DropdownArrow.Rotation = 0

            Dropdown:Display()
            RecalculateListSize()
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func

        end

        function Dropdown:SetValue(Value)
            if Dropdown.Multi then
                local Table = {}

                for Val, Active in pairs(Value or {}) do
                    if typeof(Active) ~= "boolean" then
                        Table[Active] = true
                    elseif Active and table.find(Dropdown.Values, Val) then
                        Table[Val] = true
                    end
                end

                Dropdown.Value = Table
            else
                if table.find(Dropdown.Values, Value) then
                    Dropdown.Value = Value
                elseif not Value then
                    Dropdown.Value = nil
                end
            end

            Dropdown:BuildDropdownList()

            if not Dropdown.Disabled then
                Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
            end
        end

        function Dropdown:SetText(...)

            return
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown()
                else
                    Dropdown:OpenDropdown()
                end
            end
        end)

        if Info.Searchable then
            DropdownInnerSearch:GetPropertyChangedSignal("Text"):Connect(function()
                Dropdown:BuildDropdownList()
            end)
        end

        InputService.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - (20 * DPIScale) - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown()
                end
            end
        end)

        Dropdown:BuildDropdownList()
        Dropdown:Display()

        local Defaults = {}

        if typeof(Info.Default) == "string" then
            local DefaultIdx = table.find(Dropdown.Values, Info.Default)
            if DefaultIdx then
                table.insert(Defaults, DefaultIdx)
            end

        elseif typeof(Info.Default) == "table" then
            for _, Value in next, Info.Default do
                local DefaultIdx = table.find(Dropdown.Values, Value)
                if DefaultIdx then
                    table.insert(Defaults, DefaultIdx)
                end
            end

        elseif typeof(Info.Default) == "number" and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index]
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end

        task.delay(0.1, Dropdown.UpdateColors, Dropdown)

        Dropdown.DisplayFrame = DropdownOuter
        if ParentObj.Addons then
            table.insert(ParentObj.Addons, Dropdown)
        end

        Dropdown.Default = Defaults
        Dropdown.DefaultValues = Dropdown.Values

        Options[Idx] = Dropdown

        return self
    end

    BaseAddons.__index = BaseAddonsFuncs
    BaseAddons.__namecall = function(Table, Key, ...)
        return BaseAddonsFuncs[Key](...)
    end
end

local BaseGroupbox = {}
do
    local BaseGroupboxFuncs = {}

    function BaseGroupboxFuncs:AddBlank(Size, Visible)
        local Groupbox = self
        local Container = Groupbox.Container

        return Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            Visible = if typeof(Visible) == "boolean" then Visible else true;
            ZIndex = 1;
            Parent = Container;
        })
    end

    function BaseGroupboxFuncs:AddDivider(...)
        local Params = select(1, ...)
        local Text
        local MarginTop = 2
        local MarginBottom = 9

        if typeof(Params) == "table" then
            Text = Params.Text
            MarginTop = Params.MarginTop or Params.Margin or 2
            MarginBottom = Params.MarginBottom or Params.Margin or 9
        elseif typeof(Params) == "string" then
            Text = Params
        end

        local Groupbox = self
        local Container = self.Container

        Groupbox:AddBlank(MarginTop)

        local DividerOuter
        if Text then
            DividerOuter = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, -4, 0, 14);
                ZIndex = 5;
                Parent = Container;
            })

            Library:CreateLabel({
                AutomaticSize = Enum.AutomaticSize.X;
                BackgroundTransparency = 1;
                Position = UDim2.fromScale(0.5, 0.5);
                AnchorPoint = Vector2.new(0.5, 0.5);
                Size = UDim2.fromScale(1, 0);
                Text = Text;
                TextSize = 14;
                TextTransparency = 0.5;
                TextXAlignment = Enum.TextXAlignment.Center;
                ZIndex = 6;
                Parent = DividerOuter;
                RichText = true;
            })

            local X = select(1, Library:GetTextBounds(Text, Library.Font, 14 * DPIScale))
            local SizeX = math.floor(X / 2) + (10 * DPIScale)

            local LeftOuter = Library:Create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5);
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromScale(0, 0.5);
                Size = UDim2.new(0.5, -SizeX, 0, 5);
                ZIndex = 5;
                Parent = DividerOuter;
            })
            local LeftInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = LeftOuter;
            })

            local RightOuter = Library:Create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5);
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromScale(1, 0.5);
                Size = UDim2.new(0.5, -SizeX, 0, 5);
                ZIndex = 5;
                Parent = DividerOuter;
            })
            local RightInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = RightOuter;
            })

            Library:AddToRegistry(LeftOuter, { BorderColor3 = "Black"; })
            Library:AddToRegistry(LeftInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
            Library:AddToRegistry(RightOuter, { BorderColor3 = "Black"; })
            Library:AddToRegistry(RightInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
        else
            DividerOuter = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 5);
                ZIndex = 5;
                Parent = Container;
            })

            local DividerInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = DividerOuter;
            })

            Library:AddToRegistry(DividerOuter, {
                BorderColor3 = "Black";
            })

            Library:AddToRegistry(DividerInner, {
                BackgroundColor3 = "MainColor";
                BorderColor3 = "OutlineColor";
            })
        end

        Groupbox:AddBlank(MarginBottom)
        Groupbox:Resize()

        table.insert(Groupbox.Elements, {
            Holder = DividerOuter,
            Type = "Divider",
        })
    end

    function BaseGroupboxFuncs:AddLabel(...)
        local Data = {}

        if select(2, ...) ~= nil and typeof(select(2, ...)) == "table" then
            if select(1, ...) ~= nil then
                assert(typeof(select(1, ...)) == "string", "Expected string for Idx, got " .. typeof(select(1, ...)))
            end

            local Params = select(2, ...)

            Data.Text = Params.Text or ""
            Data.DoesWrap = Params.DoesWrap or false
            Data.Idx = select(1, ...)
        else
            Data.Text = select(1, ...) or ""
            Data.DoesWrap = select(2, ...) or false
            Data.Idx = select(3, ...) or nil
        end

        Data.OriginalText = Data.Text

        local Label = {
            Type = "Label"
        }

        local Groupbox = self
        local Container = Groupbox.Container

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Data.Text;
            TextWrapped = Data.DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
            RichText = true;
        })

        if Data.DoesWrap then
            local Y = select(2, Library:GetTextBounds(Data.Text, Library.Font, 14 * DPIScale, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create("UIListLayout", {
                Padding = UDim.new(0, 4 * DPIScale);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            })
        end

        Label.TextLabel = TextLabel
        Label.Container = Container

        function Label:SetText(Text)
            TextLabel.Text = Text

            if Data.DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14 * DPIScale, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize()
        end

        if (not Data.DoesWrap) then
            setmetatable(Label, BaseAddons)
        end

        Groupbox:AddBlank(5)
        Groupbox:Resize()

        table.insert(Groupbox.Elements, Label)

        if Data.Idx then

            Labels[Data.Idx] = Label
        else
            table.insert(Labels, Label)
        end

        return Label
    end

    function BaseGroupboxFuncs:AddButton(...)
        local Button = typeof(select(1, ...)) == "table" and select(1, ...) or {
            Text = select(1, ...),
            Func = select(2, ...)
        }
        Button.OriginalText = Button.Text
        Button.Func = Button.Func or Button.Callback
        assert(typeof(Button.Func) == "function", "AddButton: `Func` callback is missing.")

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container
        local IsVisible = if typeof(Button.Visible) == "boolean" then Button.Visible else true

        local function CreateBaseButton(Button)
            local Outer = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                Visible = IsVisible;
                ZIndex = 5;
            })

            local Inner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            })

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
                RichText = true;
            })

            Library:Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            })

            Library:AddToRegistry(Outer, {
                BorderColor3 = "Black";
            })

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = "MainColor";
                BorderColor3 = "OutlineColor";
            })

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = "AccentColor" },
                { BorderColor3 = "Black" }
            )

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new("BindableEvent")
                local connection = event:Once(function(...)

                    if typeof(validator) == "function" and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame(Input) then
                    return false
                end

                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    return true
                elseif Input.UserInputType == Enum.UserInputType.Touch then
                    return true
                else
                    return false
                end
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if Button.Disabled then
                    return
                end

                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = "AccentColor" })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = "Are you sure?"
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = "FontColor" })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, "Locked", false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func)
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddButton(...)
            local SubButton = typeof(select(1, ...)) == "table" and select(1, ...) or {
                Text = select(1, ...),
                Func = select(2, ...)
            }
            SubButton.OriginalText = SubButton.Text
            SubButton.Func = SubButton.Func or SubButton.Callback
            assert(typeof(SubButton.Func) == "function", "AddButton: `Func` callback is missing.")

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20 * DPIScale)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.new(1, -3, 0, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:UpdateColors()
                SubButton.Label.TextColor3 = SubButton.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            end

            function SubButton:AddToolTip(tooltip, disabledTooltip)
                if typeof(tooltip) == "string" or typeof(disabledTooltip) == "string" then
                    if SubButton.TooltipTable then
                        SubButton.TooltipTable:Destroy()
                    end

                    SubButton.TooltipTable = Library:AddToolTip(tooltip, disabledTooltip, self.Outer)
                    SubButton.TooltipTable.Disabled = SubButton.Disabled
                end

                return SubButton
            end

            function SubButton:SetDisabled(Disabled)
                SubButton.Disabled = Disabled

                if SubButton.TooltipTable then
                    SubButton.TooltipTable.Disabled = Disabled
                end

                SubButton:UpdateColors()
            end

            function SubButton:SetText(Text)
                if typeof(Text) == "string" then
                    SubButton.Text = Text
                    SubButton.Label.Text = SubButton.Text
                end
            end

            if typeof(SubButton.Tooltip) == "string" or typeof(SubButton.DisabledTooltip) == "string" then
                SubButton.TooltipTable = SubButton:AddToolTip(SubButton.Tooltip, SubButton.DisabledTooltip, SubButton.Outer)
                SubButton.TooltipTable.Disabled = SubButton.Disabled
            end

            task.delay(0.1, SubButton.UpdateColors, SubButton)
            InitEvents(SubButton)

            table.insert(Buttons, SubButton)
            return SubButton
        end

        function Button:UpdateColors()
            Button.Label.TextColor3 = Button.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
        end

        function Button:AddToolTip(tooltip, disabledTooltip)
            if typeof(tooltip) == "string" or typeof(disabledTooltip) == "string" then
                if Button.TooltipTable then
                    Button.TooltipTable:Destroy()
                end

                Button.TooltipTable = Library:AddToolTip(tooltip, disabledTooltip, self.Outer)
                Button.TooltipTable.Disabled = Button.Disabled
            end

            return Button
        end

        if typeof(Button.Tooltip) == "string" or typeof(Button.DisabledTooltip) == "string" then
            Button.TooltipTable = Button:AddToolTip(Button.Tooltip, Button.DisabledTooltip, Button.Outer)
            Button.TooltipTable.Disabled = Button.Disabled
        end

        function Button:SetVisible(Visibility)
            IsVisible = Visibility

            Button.Outer.Visible = IsVisible
            if Blank then Blank.Visible = IsVisible end

            Groupbox:Resize()
        end

        function Button:SetText(Text)
            if typeof(Text) == "string" then
                Button.Text = Text
                Button.Label.Text = Button.Text
            end
        end

        function Button:SetDisabled(Disabled)
            Button.Disabled = Disabled

            if Button.TooltipTable then
                Button.TooltipTable.Disabled = Disabled
            end

            Button:UpdateColors()
        end

        task.delay(0.1, Button.UpdateColors, Button)
        Blank = Groupbox:AddBlank(5, IsVisible)
        Groupbox:Resize()

        table.insert(Groupbox.Elements, Button)
        table.insert(Buttons, Button)

        return Button
    end

    function BaseGroupboxFuncs:AddInput(Idx, Info)
        assert(Info.Text, string.format("AddInput (IDX: %s): Missing `Text` string.", tostring(Idx)))

        Info.ClearTextOnFocus = if typeof(Info.ClearTextOnFocus) == "boolean" then Info.ClearTextOnFocus else true

        local Textbox = {
            Value = Info.Default or "";
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            AllowEmpty = if typeof(Info.AllowEmpty) == "boolean" then Info.AllowEmpty else true;
            EmptyReset = if typeof(Info.EmptyReset) == "string" then Info.EmptyReset else "---";
            Type = "Input";

            Callback = Info.Callback or function(Value) end;
        }

        local Groupbox = self
        local Container = Groupbox.Container
        local Blank

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        })

        Groupbox:AddBlank(1)

        local TextBoxOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        })

        local TextBoxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        })

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" }
        )

        local TooltipTable
        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            TooltipTable = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, TextBoxOuter)
            TooltipTable.Disabled = Textbox.Disabled
        end

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        })

        local TextBoxContainer = Library:Create("Frame", {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create("TextBox", {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or "";

            Text = Info.Default or (if Textbox.AllowEmpty == false then Textbox.EmptyReset else "---");
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            TextEditable = not Textbox.Disabled;
            ClearTextOnFocus = not Textbox.Disabled and Info.ClearTextOnFocus;

            ZIndex = 7;
            Parent = TextBoxContainer;
        })

        Library:ApplyTextStroke(Box)

        Library:AddToRegistry(Box, {
            TextColor3 = "FontColor";
        })

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func

        end

        function Textbox:UpdateColors()
            Box.TextColor3 = Textbox.Disabled and Library.DisabledAccentColor or Library.FontColor

            Library.RegistryMap[Box].Properties.TextColor3 = Textbox.Disabled and "DisabledAccentColor" or "FontColor"
        end

        function Textbox:Display()
            TextBoxOuter.Visible = Textbox.Visible
            InputLabel.Visible = Textbox.Visible
            if Blank then Blank.Visible = Textbox.Visible end

            Groupbox:Resize()
        end

        function Textbox:SetValue(Text)
            if not Textbox.AllowEmpty and Trim(Text) == "" then
                Text = Textbox.EmptyReset
            end

            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength)
            end

            if Textbox.Numeric then
                if #tostring(Text) > 0 and not tonumber(Text) then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text
            Box.Text = Text

            if not Textbox.Disabled then
                Library:SafeCallback(Textbox.Callback, Textbox.Value)
                Library:SafeCallback(Textbox.Changed, Textbox.Value)
            end
        end

        function Textbox:SetVisible(Visibility)
            Textbox.Visible = Visibility

            Textbox:Display()
        end

        function Textbox:SetDisabled(Disabled)
            Textbox.Disabled = Disabled

            Box.TextEditable = not Disabled
            Box.ClearTextOnFocus = not Disabled and Info.ClearTextOnFocus

            if TooltipTable then
                TooltipTable.Disabled = Disabled
            end

            Textbox:UpdateColors()
        end

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        else
            Box:GetPropertyChangedSignal("Text"):Connect(function()
                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        end

        local function Update()
            local PADDING = 2
            local reveal = TextBoxContainer.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then

                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else

                local cursor = Box.CursorPosition
                if cursor ~= -1 then

                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    local currentCursorPos = Box.Position.X.Offset + width

                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal("Text"):Connect(Update)
        Box:GetPropertyChangedSignal("CursorPosition"):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Blank = Groupbox:AddBlank(5, Textbox.Visible)
        task.delay(0.1, Textbox.UpdateColors, Textbox)
        Textbox:Display()
        Groupbox:Resize()

        Textbox.Default = Textbox.Value

        table.insert(Groupbox.Elements, Textbox)
        Options[Idx] = Textbox

        return Textbox
    end

    function BaseGroupboxFuncs:AddToggle(Idx, Info)
        assert(Info.Text, string.format("AddInput (IDX: %s): Missing `Text` string.", tostring(Idx)))

        local Toggle = {
            Value = Info.Default or false;
            Type = "Toggle";
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            Risky = if typeof(Info.Risky) == "boolean" then Info.Risky else false;
            OriginalText = Info.Text; Text = Info.Text;

            Callback = Info.Callback or function(Value) end;
            Addons = {};
        }

        local Blank
        local Tooltip
        local Groupbox = self
        local Container = Groupbox.Container

        local ToggleContainer = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -4, 0, 13);
            Visible = Toggle.Visible;
            ZIndex = 5;
            Parent = Container;
        })

        local ToggleOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            Visible = Toggle.Visible;
            ZIndex = 5;
            Parent = ToggleContainer;
        })

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = "Black";
        })

        local ToggleInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        })

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(1, -19, 0, 11);
            Position = UDim2.new(0, 19, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleContainer;
            RichText = true;
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        })

        local ToggleRegion = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        })

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                if Toggle.Disabled then
                    return false
                end

                for _, Addon in next, Toggle.Addons do
                    if Library:MouseIsOverFrame(Addon.DisplayFrame) then return false end
                end
                return true
            end
        )

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, ToggleRegion)
            Tooltip.Disabled = Toggle.Disabled
        end

        function Toggle:Display()
            if Toggle.Disabled then
                ToggleLabel.TextColor3 = Library.DisabledTextColor

                ToggleInner.BackgroundColor3 = Toggle.Value and Library.DisabledAccentColor or Library.MainColor
                ToggleInner.BorderColor3 = Library.DisabledOutlineColor

                Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and "DisabledAccentColor" or "MainColor"
                Library.RegistryMap[ToggleInner].Properties.BorderColor3 = "DisabledOutlineColor"
                Library.RegistryMap[ToggleLabel].Properties.TextColor3 = "DisabledTextColor"

                return
            end

            ToggleLabel.TextColor3 = Toggle.Risky and Library.RiskColor or Color3.new(1, 1, 1)

            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and "AccentColor" or "MainColor"
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and "AccentColorDark" or "OutlineColor"

            Library.RegistryMap[ToggleLabel].Properties.TextColor3 = Toggle.Risky and "RiskColor" or nil
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func

        end

        function Toggle:SetValue(Bool)
            if Toggle.Disabled then
                return
            end

            Bool = (not not Bool)

            Toggle.Value = Bool
            Toggle:Display()

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            if not Toggle.Disabled then
                Library:SafeCallback(Toggle.Callback, Toggle.Value)
                Library:SafeCallback(Toggle.Changed, Toggle.Value)
            end

            Library:UpdateDependencyBoxes()
            Library:UpdateDependencyGroupboxes()
        end

        function Toggle:SetVisible(Visibility)
            Toggle.Visible = Visibility

            ToggleOuter.Visible = Toggle.Visible
            if Blank then Blank.Visible = Toggle.Visible end

            Groupbox:Resize()
        end

        function Toggle:SetDisabled(Disabled)
            Toggle.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            Toggle:Display()
        end

        function Toggle:SetText(Text)
            if typeof(Text) == "string" then
                Toggle.Text = Text
                ToggleLabel.Text = Toggle.Text
            end
        end

        ToggleRegion.InputBegan:Connect(function(Input)
            if Toggle.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                for _, Addon in next, Toggle.Addons do
                    if Library:MouseIsOverFrame(Addon.DisplayFrame) then return end
                end

                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave()
            end
        end)

        if Toggle.Risky == true then
            Library:RemoveFromRegistry(ToggleLabel)

            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = "RiskColor" })
        end

        Toggle:Display()
        Blank = Groupbox:AddBlank(Info.BlankSize or 5 + 2, Toggle.Visible)
        Groupbox:Resize()

        Toggle.TextLabel = ToggleLabel
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Default = Toggle.Value

        table.insert(Groupbox.Elements, Toggle)
        Toggles[Idx] = Toggle

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Toggle
    end

    function BaseGroupboxFuncs:AddSlider(Idx, Info)
        assert(Info.Default,    string.format("AddSlider (IDX: %s): Missing default value.", tostring(Idx)))
        assert(Info.Text,       string.format("AddSlider (IDX: %s): Missing slider text.", tostring(Idx)))
        assert(Info.Min,        string.format("AddSlider (IDX: %s): Missing minimum value.", tostring(Idx)))
        assert(Info.Max,        string.format("AddSlider (IDX: %s): Missing maximum value.", tostring(Idx)))
        assert(Info.Rounding,   string.format("AddSlider (IDX: %s): Missing rounding value.", tostring(Idx)))

        local Slider = {
            Value = Info.Default;

            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = "Slider";
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            OriginalText = Info.Text; Text = Info.Text;

            Prefix = typeof(Info.Prefix) == "string" and Info.Prefix or "";
            Suffix = typeof(Info.Suffix) == "string" and Info.Suffix or "";

            Callback = Info.Callback or function(Value) end;
        }

        local Blanks = {}
        local SliderText = nil
        local Groupbox = self
        local Container = Groupbox.Container
        local Tooltip

        if not Info.Compact then
            SliderText = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                Visible = Slider.Visible;
                ZIndex = 5;
                Parent = Container;
                RichText = true;
            })

            table.insert(Blanks, Groupbox:AddBlank(3, Slider.Visible))
        end

        local SliderOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            Visible = Slider.Visible;
            ZIndex = 5;
            Parent = Container;
        })

        SliderOuter:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            Slider.MaxSize = SliderOuter.AbsoluteSize.X - 2
        end)

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = "Black";
        })

        local SliderInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        })

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local Fill = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        })

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = "AccentColor";
            BorderColor3 = "AccentColorDark";
        })

        local HideBorderRight = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        })

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = "AccentColor";
        })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = "Infinite";
            ZIndex = 9;
            Parent = SliderInner;
            RichText = true;
        })

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                return not Slider.Disabled
            end
        )

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, SliderOuter)
            Tooltip.Disabled = Slider.Disabled
        end

        function Slider:UpdateColors()
            if SliderText then
                SliderText.TextColor3 = Slider.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            end
            DisplayLabel.TextColor3 = Slider.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)

            HideBorderRight.BackgroundColor3 = Slider.Disabled and Library.DisabledAccentColor or Library.AccentColor

            Fill.BackgroundColor3 = Slider.Disabled and Library.DisabledAccentColor or Library.AccentColor
            Fill.BorderColor3 = Slider.Disabled and Library.DisabledOutlineColor or Library.AccentColorDark

            Library.RegistryMap[HideBorderRight].Properties.BackgroundColor3 = Slider.Disabled and "DisabledAccentColor" or "AccentColor"

            Library.RegistryMap[Fill].Properties.BackgroundColor3 = Slider.Disabled and "DisabledAccentColor" or "AccentColor"
            Library.RegistryMap[Fill].Properties.BorderColor3 = Slider.Disabled and "DisabledOutlineColor" or "AccentColorDark"
        end

        function Slider:Display()
            local CustomDisplayText = nil
            if Info.FormatDisplayValue then
                CustomDisplayText = Info.FormatDisplayValue(Slider, Slider.Value)
            end

            if CustomDisplayText then
                DisplayLabel.Text = tostring(CustomDisplayText)
            else
                local FormattedValue = (Slider.Value == 0 or Slider.Value == -0) and "0" or tostring(Slider.Value)
                if Info.Compact then
                    DisplayLabel.Text = string.format("%s: %s%s%s", Slider.Text, Slider.Prefix, FormattedValue, Slider.Suffix)

                elseif Info.HideMax then
                    DisplayLabel.Text = string.format("%s%s%s", Slider.Prefix, FormattedValue, Slider.Suffix)

                else
                    DisplayLabel.Text = string.format("%s%s%s/%s%s%s",
                        Slider.Prefix, FormattedValue, Slider.Suffix,
                        Slider.Prefix, tostring(Slider.Max), Slider.Suffix)
                end
            end

            local X = Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, 1)
            Fill.Size = UDim2.new(X, 0, 1, 0)

            HideBorderRight.Visible = not (X == 1 or X == 0)
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func

        end

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value)
            end

            return tonumber(string.format("%." .. Slider.Rounding .. "f", Value))
        end

        function Slider:GetValueFromXScale(X)
            return Round(Library:MapValue(X, 0, 1, Slider.Min, Slider.Max))
        end

        function Slider:SetMax(Value)
            assert(Value > Slider.Min, "Max value cannot be less than the current min value.")

            Slider.Value = math.clamp(Slider.Value, Slider.Min, Value)
            Slider.Max = Value
            Slider:Display()
        end

        function Slider:SetMin(Value)
            assert(Value < Slider.Max, "Min value cannot be greater than the current max value.")

            Slider.Value = math.clamp(Slider.Value, Value, Slider.Max)
            Slider.Min = Value
            Slider:Display()
        end

        function Slider:SetValue(Str)
            if Slider.Disabled then
                return
            end

            local Num = tonumber(Str)

            if (not Num) then
                return
            end

            Num = math.clamp(Num, Slider.Min, Slider.Max)

            Slider.Value = Num
            Slider:Display()

            if not Slider.Disabled then
                Library:SafeCallback(Slider.Callback, Slider.Value)
                Library:SafeCallback(Slider.Changed, Slider.Value)
            end
        end

        function Slider:SetVisible(Visibility)
            Slider.Visible = Visibility

            if SliderText then SliderText.Visible = Slider.Visible end
            SliderOuter.Visible = Slider.Visible

            for _, Blank in pairs(Blanks) do
                Blank.Visible = Slider.Visible
            end

            Groupbox:Resize()
        end

        function Slider:SetDisabled(Disabled)
            Slider.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            Slider:UpdateColors()
        end

        function Slider:SetText(Text)
            if typeof(Text) == "string" then
                Slider.Text = Text

                if SliderText then SliderText.Text = Slider.Text end
                Slider:Display()
            end
        end

        function Slider:SetPrefix(Prefix)
            if typeof(Prefix) == "string" then
                Slider.Prefix = Prefix
                Slider:Display()
            end
        end

        function Slider:SetSuffix(Suffix)
            if typeof(Suffix) == "string" then
                Slider.Suffix = Suffix
                Slider:Display()
            end
        end

        SliderInner.InputBegan:Connect(function(Input)
            if Slider.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                if Library.IsMobile then
                    Library.CanDrag = false
                end

                local Sides = {}
                if Library.Window then
                    Sides = Library.Window.Tabs[Library.ActiveTab]:GetSides()
                end

                for _, Side in pairs(Sides) do
                    if typeof(Side) == "Instance" then
                        if Side:IsA("ScrollingFrame") then
                            Side.ScrollingEnabled = false
                        end
                    end
                end

                local mPos = Mouse.X
                local gPos = Fill.AbsoluteSize.X
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos)

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                    local nMPos = Mouse.X
                    local nXOffset = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize)
                    local nXScale = Library:MapValue(nXOffset, 0, Slider.MaxSize, 0, 1)

                    local nValue = Slider:GetValueFromXScale(nXScale)
                    local OldValue = Slider.Value
                    Slider.Value = nValue

                    Slider:Display()

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value)
                        Library:SafeCallback(Slider.Changed, Slider.Value)
                    end

                    RunService.RenderStepped:Wait()
                end

                if Library.IsMobile then
                    Library.CanDrag = true
                end

                for _, Side in pairs(Sides) do
                    if typeof(Side) == "Instance" then
                        if Side:IsA("ScrollingFrame") then
                            Side.ScrollingEnabled = true
                        end
                    end
                end

                Library:AttemptSave()
            end
        end)

        task.delay(0.1, Slider.UpdateColors, Slider)
        Slider:Display()
        table.insert(Blanks, Groupbox:AddBlank(Info.BlankSize or 6, Slider.Visible))
        Groupbox:Resize()

        Slider.Default = Slider.Value

        table.insert(Groupbox.Elements, Slider)
        Options[Idx] = Slider

        return Slider
    end

    function BaseGroupboxFuncs:AddDropdown(Idx, Info)
        Info.ReturnInstanceInstead = if typeof(Info.ReturnInstanceInstead) == "boolean" then Info.ReturnInstanceInstead else false

        if Info.SpecialType == "Player" then
            Info.ExcludeLocalPlayer = if typeof(Info.ExcludeLocalPlayer) == "boolean" then Info.ExcludeLocalPlayer else false

            Info.Values = GetPlayers(Info.ExcludeLocalPlayer, Info.ReturnInstanceInstead)
            Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeams(Info.ReturnInstanceInstead)
            Info.AllowNull = true
        end

        assert(Info.Values, string.format("AddDropdown (IDX: %s): Missing dropdown value list.", tostring(Idx)))
        if not (Info.AllowNull or Info.Default) then
            Info.Default = 1
            warn(string.format("AddDropdown (IDX: %s): Missing default value, selected the first index instead. Pass `AllowNull` as true if this was intentional.", tostring(Idx)))
        end

        Info.Searchable = if typeof(Info.Searchable) == "boolean" then Info.Searchable else false
        Info.FormatDisplayValue = if typeof(Info.FormatDisplayValue) == "function" then Info.FormatDisplayValue else nil
        Info.FormatListValue = if typeof(Info.FormatListValue) == "function" then Info.FormatListValue else nil

        if (not Info.Text) then
            Info.Compact = true
        end

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            DisabledValues = Info.DisabledValues or {};

            Multi = Info.Multi;
            Type = "Dropdown";
            SpecialType = Info.SpecialType;
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            Callback = Info.Callback or function(Value) end;
            Changed = Info.Changed or function(Value) end;

            OriginalText = Info.Text; Text = Info.Text;
            ExcludeLocalPlayer = Info.ExcludeLocalPlayer;
            ReturnInstanceInstead = Info.ReturnInstanceInstead;
        }

        local DropdownLabel
        local Blank
        local CompactBlank
        local Tooltip
        local Groupbox = self
        local Container = Groupbox.Container

        local RelativeOffset = 0

        if not Info.Compact then
            DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                Visible = Dropdown.Visible;
                ZIndex = 5;
                Parent = Container;
                RichText = true;
            })

            CompactBlank = Groupbox:AddBlank(3, Dropdown.Visible)
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA("UIListLayout") then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset
            end
        end

        local DropdownOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            Visible = Dropdown.Visible;
            ZIndex = 5;
            Parent = Container;
        })

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = "Black";
        })

        local DropdownInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        })

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        })

        local DropdownInnerSearch
        if Info.Searchable then
            DropdownInnerSearch = Library:Create("TextBox", {
                BackgroundTransparency = 1;
                Visible = false;

                Position = UDim2.new(0, 5, 0, 0);
                Size = UDim2.new(0.9, -5, 1, 0);

                Font = Library.Font;
                PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
                PlaceholderText = "Search...";

                Text = "";
                TextColor3 = Library.FontColor;
                TextSize = 14;
                TextStrokeTransparency = 0;
                TextXAlignment = Enum.TextXAlignment.Left;

                ClearTextOnFocus = false;

                ZIndex = 7;
                Parent = DropdownOuter;
            })

            Library:ApplyTextStroke(DropdownInnerSearch)

            Library:AddToRegistry(DropdownInnerSearch, {
                TextColor3 = "FontColor";
            })
        end

        local DropdownArrow = Library:Create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = CustomImageManager.GetAsset("DropdownArrow");
            ZIndex = 8;
            Parent = DropdownInner;
        })

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = "--";
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = false;
            TextTruncate = Enum.TextTruncate.AtEnd;
            RichText = true;
            ZIndex = 7;
            Parent = DropdownInner;
        })

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                return not Dropdown.Disabled
            end
        )

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, DropdownOuter)
            Tooltip.Disabled = Dropdown.Disabled
        end

        local MAX_DROPDOWN_ITEMS = if typeof(Info.MaxVisibleDropdownItems) == "number" then math.clamp(Info.MaxVisibleDropdownItems, 4, 16) else 8

        local ListOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        })

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1)
        end

        local function RecalculateListSize(YSize)
            local Y = YSize or math.clamp(GetTableSize(Dropdown.Values) * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X + 0.5, Y)
        end

        RecalculateListPosition()
        RecalculateListSize()

        DropdownOuter:GetPropertyChangedSignal("AbsolutePosition"):Connect(RecalculateListPosition)

        local ListInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        })

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local Scrolling = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        })

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = "AccentColor"
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        })

        function Dropdown:UpdateColors()
            if DropdownLabel then
                DropdownLabel.TextColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            end

            ItemList.TextColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            DropdownArrow.ImageColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
        end

        function Dropdown:Display()
            local Values = Dropdown.Values
            local Str = ""

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(Value) or Value) .. ", "
                    end
                end

                Str = Str:sub(1, #Str - 2)
                ItemList.Text = (Str == "" and "--" or Str)
            else
                if not Dropdown.Value then
                    ItemList.Text = "--"
                    return
                end

                ItemList.Text = tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(Dropdown.Value) or Dropdown.Value)
            end
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {}

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value)
                end

                return T
            else
                return Dropdown.Value and 1 or 0
            end
        end

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local DisabledValues = Dropdown.DisabledValues
            local Buttons = {}

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA("UIListLayout") then
                    Element:Destroy()
                end
            end

            local Count = 0
            for Idx, Value in next, Values do
                local StringValue = tostring(Info.FormatListValue and Info.FormatListValue(Value) or Value)
                if Info.Searchable and not string.lower(StringValue):match(string.lower(DropdownInnerSearch.Text)) then
                    continue
                end

                local IsDisabled = table.find(DisabledValues, StringValue)
                local Table = {}

                Count = Count + 1

                local Button = Library:Create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    Text = "";
                    ZIndex = 23;
                    Parent = Scrolling;
                })

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = "MainColor";
                    BorderColor3 = "OutlineColor";
                })

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(StringValue)) or StringValue;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    RichText = true;
                    ZIndex = 25;
                    Parent = Button;
                })

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = IsDisabled and "DisabledAccentColor" or "AccentColor", ZIndex = 24 },
                    { BorderColor3 = "OutlineColor", ZIndex = 23 }
                )

                local Selected

                if Info.Multi then
                    Selected = Dropdown.Value[Value]
                else
                    Selected = Dropdown.Value == Value
                end

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value]
                    else
                        Selected = Dropdown.Value == Value
                    end

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or (IsDisabled and Library.DisabledAccentColor or Library.FontColor)
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and "AccentColor" or (IsDisabled and "DisabledAccentColor" or "FontColor")
                end

                if not IsDisabled then
                    Button.MouseButton1Click:Connect(function(Input)
                        local Try = not Selected

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try

                                if Selected then
                                    Dropdown.Value[Value] = true
                                else
                                    Dropdown.Value[Value] = nil
                                end
                            else
                                Selected = Try

                                if Selected then
                                    Dropdown.Value = Value
                                else
                                    Dropdown.Value = nil
                                end

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton()
                                end
                            end

                            Table:UpdateButton()
                            Dropdown:Display()

                            Library:UpdateDependencyBoxes()
                            Library:UpdateDependencyGroupboxes()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)

                            Library:AttemptSave()
                        end
                    end)
                end

                Table:UpdateButton()
                Dropdown:Display()

                Buttons[Button] = Table
            end

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * (20 * DPIScale)) + 1)

            Scrolling.Visible = false
            Scrolling.Visible = true

            local Y = math.clamp(Count * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            RecalculateListSize(Y)
        end

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValues(NewValues)
            if typeof(NewValues) == "table" then
                for _, val in pairs(NewValues) do
                    table.insert(Dropdown.Values, val)
                end
            elseif typeof(NewValues) == "string" then
                table.insert(Dropdown.Values, NewValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabledValues(NewValues)
            if NewValues then
                Dropdown.DisabledValues = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddDisabledValues(DisabledValues)
            if typeof(DisabledValues) == "table" then
                for _, val in pairs(DisabledValues) do
                    table.insert(Dropdown.DisabledValues, val)
                end
            elseif typeof(DisabledValues) == "string" then
                table.insert(Dropdown.DisabledValues, DisabledValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetVisible(Visibility)
            Dropdown.Visible = Visibility

            DropdownOuter.Visible = Dropdown.Visible
            if DropdownLabel then DropdownLabel.Visible = Dropdown.Visible end

            if Blank then Blank.Visible = Dropdown.Visible end
            if CompactBlank then CompactBlank.Visible = Dropdown.Visible end

            if not Dropdown.Visible then Dropdown:CloseDropdown() end

            Groupbox:Resize()
        end

        function Dropdown:SetDisabled(Disabled)
            Dropdown.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            if Disabled then
                Dropdown:CloseDropdown()
            end

            Dropdown:Display()
            Dropdown:UpdateColors()
        end

        function Dropdown:OpenDropdown()
            if Dropdown.Disabled then
                return
            end

            if Library.IsMobile then
                Library.CanDrag = false
            end

            if Info.Searchable then
                ItemList.Visible = false
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = true
            end

            ListOuter.Visible = true
            Library.OpenedFrames[ListOuter] = true
            DropdownArrow.Rotation = 180

            RecalculateListSize()
        end

        function Dropdown:CloseDropdown()
            if Library.IsMobile then
                Library.CanDrag = true
            end

            if Info.Searchable then
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = false
                ItemList.Visible = true
            end

            ListOuter.Visible = false
            Library.OpenedFrames[ListOuter] = nil
            DropdownArrow.Rotation = 0
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func

        end

        function Dropdown:SetValue(Value)
            if Dropdown.Multi then
                local Table = {}

                for Val, Active in pairs(Value or {}) do
                    if typeof(Active) ~= "boolean" then
                        Table[Active] = true
                    elseif Active and table.find(Dropdown.Values, Val) then
                        Table[Val] = true
                    end
                end

                Dropdown.Value = Table
            else
                if table.find(Dropdown.Values, Value) then
                    Dropdown.Value = Value
                elseif not Value then
                    Dropdown.Value = nil
                end
            end

            Dropdown:BuildDropdownList()

            if not Dropdown.Disabled then
                Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
            end
        end

        function Dropdown:SetText(Text)
            if typeof(Text) == "string" then
                if Info.Compact then Info.Compact = false end
                Dropdown.Text = Text

                if DropdownLabel then DropdownLabel.Text = Dropdown.Text end
                Dropdown:Display()
            end
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown()
                else
                    Dropdown:OpenDropdown()
                end
            end
        end)

        if Info.Searchable then
            DropdownInnerSearch:GetPropertyChangedSignal("Text"):Connect(function()
                Dropdown:BuildDropdownList()
            end)
        end

        InputService.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - (20 * DPIScale) - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown()
                end
            end
        end)

        Dropdown:BuildDropdownList()
        Dropdown:Display()

        local Defaults = {}

        if typeof(Info.Default) == "string" then
            local DefaultIdx = table.find(Dropdown.Values, Info.Default)
            if DefaultIdx then
                table.insert(Defaults, DefaultIdx)
            end
        elseif typeof(Info.Default) == "table" then
            for _, Value in next, Info.Default do
                local DefaultIdx = table.find(Dropdown.Values, Value)
                if DefaultIdx then
                    table.insert(Defaults, DefaultIdx)
                end
            end
        elseif typeof(Info.Default) == "number" and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index]
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end

        task.delay(0.1, Dropdown.UpdateColors, Dropdown)
        Blank = Groupbox:AddBlank(Info.BlankSize or 5, Dropdown.Visible)
        Groupbox:Resize()

        Dropdown.Default = Defaults
        Dropdown.DefaultValues = Dropdown.Values

        table.insert(Groupbox.Elements, Dropdown)
        Options[Idx] = Dropdown

        return Dropdown
    end

    function BaseGroupboxFuncs:AddViewport(Idx, Info)
        local Dragging, Pinching = false, false
        local LastMousePos, LastPinchDist = nil, 0

        local Viewport = {
            Object = if Info.Clone then Info.Object:Clone() else Info.Object,
            Camera = if not Info.Camera then Instance.new("Camera") else Info.Camera,
            Interactive = Info.Interactive,
            AutoFocus = Info.AutoFocus,
            Height = if typeof(Info.Height) == "number" and Info.Height > 0 then Info.Height else 200,
            Visible = Info.Visible,
            Type = "Viewport",
        }

        assert(
            typeof(Viewport.Object) == "Instance" and (Viewport.Object:IsA("BasePart") or Viewport.Object:IsA("Model")),
            "Instance must be a BasePart or Model."
        )

        assert(
            typeof(Viewport.Camera) == "Instance" and Viewport.Camera:IsA("Camera"),
            "Camera must be a valid Camera instance."
        )

        local function GetModelSize(model)
            if model:IsA("BasePart") then
                return model.Size
            end

            return select(2, model:GetBoundingBox())
        end

        local function FocusCamera()
            local ModelSize = GetModelSize(Viewport.Object)
            local MaxExtent = math.max(ModelSize.X, ModelSize.Y, ModelSize.Z)
            local CameraDistance = MaxExtent * 2
            local ModelPosition = Viewport.Object:GetPivot().Position

            Viewport.Camera.CFrame =
                CFrame.new(ModelPosition + Vector3.new(0, MaxExtent / 2, CameraDistance), ModelPosition)
        end

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Viewport.Visible,
            Parent = Container,
        })

        local Box = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = Holder,
        })

        Library:AddToRegistry(Box, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ViewportFrame = Library:Create("ViewportFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = Box,
            CurrentCamera = Viewport.Camera,
            Active = Viewport.Interactive,
            ZIndex = 7
        })

        ViewportFrame.MouseEnter:Connect(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in pairs(Library.Window.Tabs[Library.ActiveTab]:GetSides()) do
                if typeof(Side) == "Instance" then
                    if Side:IsA("ScrollingFrame") then
                        Side.ScrollingEnabled = false
                    end
                end
            end
        end)

        ViewportFrame.MouseLeave:Connect(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in pairs(Library.Window.Tabs[Library.ActiveTab]:GetSides()) do
                if typeof(Side) == "Instance" then
                    if Side:IsA("ScrollingFrame") then
                        Side.ScrollingEnabled = true
                    end
                end
            end
        end)

        ViewportFrame.InputBegan:Connect(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = true
                LastMousePos = input.Position
            elseif input.UserInputType == Enum.UserInputType.Touch and not Pinching then
                Dragging = true
                LastMousePos = input.Position
            end
        end)

        Library:GiveSignal(InputService.InputEnded:Connect(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = false
            elseif input.UserInputType == Enum.UserInputType.Touch then
                Dragging = false
            end
        end))

        Library:GiveSignal(InputService.InputChanged:Connect(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Dragging or Pinching then
                return
            end

            if
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                local MouseDelta = input.Position - LastMousePos
                LastMousePos = input.Position

                local Position = Viewport.Object:GetPivot().Position
                local Camera = Viewport.Camera

                local RotationY = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -MouseDelta.X * 0.01)
                Camera.CFrame = CFrame.new(Position) * RotationY * CFrame.new(-Position) * Camera.CFrame

                local RotationX = CFrame.fromAxisAngle(Camera.CFrame.RightVector, -MouseDelta.Y * 0.01)
                local PitchedCFrame = CFrame.new(Position) * RotationX * CFrame.new(-Position) * Camera.CFrame

                if PitchedCFrame.UpVector.Y > 0.1 then
                    Camera.CFrame = PitchedCFrame
                end
            end
        end))

        ViewportFrame.InputChanged:Connect(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseWheel then
                local ZoomAmount = input.Position.Z * 2
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * ZoomAmount
            end
        end)

        Library:GiveSignal(InputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Library:MouseIsOverFrame(ViewportFrame, touchPositions[1]) then
                return
            end

            if state == Enum.UserInputState.Begin then
                Pinching = true
                Dragging = false
                LastPinchDist = (touchPositions[1] - touchPositions[2]).Magnitude
            elseif state == Enum.UserInputState.Change then
                local currentDist = (touchPositions[1] - touchPositions[2]).Magnitude
                local delta = (currentDist - LastPinchDist) * 0.1
                LastPinchDist = currentDist
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * delta
            elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                Pinching = false
            end
        end))

        Viewport.Object.Parent = ViewportFrame
        if Viewport.AutoFocus then
            FocusCamera()
        end

        function Viewport:SetObject(Object: Instance, Clone: boolean?)
            assert(Object, "Object cannot be nil.")

            if Clone then
                Object = Object:Clone()
            end

            if Viewport.Object then
                Viewport.Object:Destroy()
            end

            Viewport.Object = Object
            Viewport.Object.Parent = ViewportFrame

            Groupbox:Resize()
        end

        function Viewport:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")
            Viewport.Height = Height

            Holder.Size = UDim2.new(1, -4, 0, Viewport.Height)
            Groupbox:Resize()
        end

        function Viewport:Focus()
            if not Viewport.Object then
                return
            end

            FocusCamera()
        end

        function Viewport:SetCamera(Camera: Instance)
            assert(
                Camera and typeof(Camera) == "Instance" and Camera:IsA("Camera"),
                "Camera must be a valid Camera instance."
            )

            Viewport.Camera = Camera
            ViewportFrame.CurrentCamera = Camera
        end

        function Viewport:SetInteractive(Interactive: boolean)
            Viewport.Interactive = Interactive
            ViewportFrame.Active = Interactive
        end

        function Viewport:SetVisible(Visible: boolean)
            Viewport.Visible = Visible

            Holder.Visible = Viewport.Visible
            if Blank then Blank.Visible = Viewport.Visible end

            Groupbox:Resize()
        end

        Viewport:SetHeight(Viewport.Height)

        Blank = Groupbox:AddBlank(10, Viewport.Visible)
        Groupbox:Resize()

        Viewport.Holder = Holder
        Viewport.Container = Container

        table.insert(Groupbox.Elements, Viewport)
        Options[Idx] = Viewport

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Viewport
    end

    function BaseGroupboxFuncs:AddImage(Idx, Info)
        local Image = {
            Image = Info.Image,
            Color = Info.Color,
            RectOffset = Info.RectOffset,
            RectSize = Info.RectSize,
            Height = if typeof(Info.Height) == "number" and Info.Height > 0 then Info.Height else 200,
            ScaleType = Info.ScaleType,
            Transparency = Info.Transparency,
            BackgroundTransparency = tonumber(Info.BackgroundTransparency) or 0,

            Visible = Info.Visible,
            Type = "Image",
        }

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Image.Visible,
            Parent = Container,
        })

        local Box = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            BackgroundTransparency = Image.BackgroundTransparency,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = Holder,
        })

        Library:AddToRegistry(Box, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ImageProperties = {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = Image.Image,
            ImageTransparency = Image.Transparency,
            ImageColor3 = Image.Color,
            ImageRectOffset = Image.RectOffset,
            ImageRectSize = Image.RectSize,
            ScaleType = Image.ScaleType,
            ZIndex = 7,
            Parent = Box,
        }

        local Icon = Library:GetCustomIcon(ImageProperties.Image)
        assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        ImageProperties.Image = Icon.Url
        ImageProperties.ImageRectOffset = Icon.ImageRectOffset
        ImageProperties.ImageRectSize = Icon.ImageRectSize

        local ImageLabel = Library:Create("ImageLabel", ImageProperties)

        function Image:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")
            Image.Height = Height

            Holder.Size = UDim2.new(1, -4, 0, Image.Height)
            Groupbox:Resize()
        end

        function Image:SetImage(NewImage: string)
            assert(typeof(NewImage) == "string", "Image must be a string.")

            local Icon = Library:GetCustomIcon(NewImage)
            assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            NewImage = Icon.Url
            Image.RectOffset = Icon.ImageRectOffset
            Image.RectSize = Icon.ImageRectSize

            ImageLabel.Image = NewImage
            Image.Image = NewImage
        end

        function Image:SetColor(Color: Color3)
            assert(typeof(Color) == "Color3", "Color must be a Color3 value.")

            ImageLabel.ImageColor3 = Color
            Image.Color = Color
        end

        function Image:SetRectOffset(RectOffset: Vector2)
            assert(typeof(RectOffset) == "Vector2", "RectOffset must be a Vector2 value.")

            ImageLabel.ImageRectOffset = RectOffset
            Image.RectOffset = RectOffset
        end

        function Image:SetRectSize(RectSize: Vector2)
            assert(typeof(RectSize) == "Vector2", "RectSize must be a Vector2 value.")

            ImageLabel.ImageRectSize = RectSize
            Image.RectSize = RectSize
        end

        function Image:SetScaleType(ScaleType: Enum.ScaleType)
            assert(
                typeof(ScaleType) == "EnumItem" and ScaleType:IsA("ScaleType"),
                "ScaleType must be a valid Enum.ScaleType."
            )

            ImageLabel.ScaleType = ScaleType
            Image.ScaleType = ScaleType
        end

        function Image:SetTransparency(Transparency: number)
            assert(typeof(Transparency) == "number", "Transparency must be a number between 0 and 1.")
            assert(Transparency >= 0 and Transparency <= 1, "Transparency must be between 0 and 1.")

            ImageLabel.ImageTransparency = Transparency
            Image.Transparency = Transparency
        end

        function Image:SetVisible(Visible: boolean)
            Image.Visible = Visible

            Holder.Visible = Image.Visible
            if Blank then Blank.Visible = Image.Visible end

            Groupbox:Resize()
        end

        Image:SetHeight(Image.Height)

        Blank = Groupbox:AddBlank(10, Image.Visible)
        Groupbox:Resize()

        Image.Holder = Holder
        Image.Container = Container

        table.insert(Groupbox.Elements, Image)
        Options[Idx] = Image

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Image
    end

    function BaseGroupboxFuncs:AddVideo(Idx, Info)
        Info = Library:Validate(Info, Templates.Video)

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        local Video = {
            Video = Info.Video,
            Looped = Info.Looped,
            Playing = Info.Playing,
            Volume = Info.Volume,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "Video",
        }

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Video.Visible,
            Parent = Container,
        })

        local Box = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = Holder,
        })

        Library:AddToRegistry(Box, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local VideoFrameInstance = Library:Create("VideoFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Video = Video.Video,
            Looped = Video.Looped,
            Volume = Video.Volume,
            ZIndex = 7,
            Parent = Box,
        })

        VideoFrameInstance.Playing = Video.Playing

        function Video:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Video.Height = Height
            Holder.Size = UDim2.new(1, -4, 0, Height)
            Groupbox:Resize()
        end

        function Video:SetVideo(NewVideo: string)
            assert(typeof(NewVideo) == "string", "Video must be a string.")

            VideoFrameInstance.Video = NewVideo
            Video.Video = NewVideo
        end

        function Video:SetLooped(Looped: boolean)
            assert(typeof(Looped) == "boolean", "Looped must be a boolean.")

            VideoFrameInstance.Looped = Looped
            Video.Looped = Looped
        end

        function Video:SetVolume(Volume: number)
            assert(typeof(Volume) == "number", "Volume must be a number between 0 and 10.")

            VideoFrameInstance.Volume = Volume
            Video.Volume = Volume
        end

        function Video:SetPlaying(Playing: boolean)
            assert(typeof(Playing) == "boolean", "Playing must be a boolean.")

            VideoFrameInstance.Playing = Playing
            Video.Playing = Playing
        end

        function Video:Play()
            VideoFrameInstance.Playing = true
            Video.Playing = true
        end

        function Video:Pause()
            VideoFrameInstance.Playing = false
            Video.Playing = false
        end

        function Video:SetVisible(Visible: boolean)
            Video.Visible = Visible

            Holder.Visible = Video.Visible
            if Blank then Blank.Visible = Video.Visible end

            Groupbox:Resize()
        end

        Video:SetHeight(Video.Height)

        Blank = Groupbox:AddBlank(10, Video.Visible)
        Groupbox:Resize()

        Video.Holder = Holder
        Video.Container = Container
        Video.VideoFrame = VideoFrameInstance

        table.insert(Groupbox.Elements, Video)
        Options[Idx] = Video

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Video
    end

    function BaseGroupboxFuncs:AddUIPassthrough(Idx, Info)
        Info = Library:Validate(Info, Templates.UIPassthrough)

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        assert(Info.Instance, "Instance must be provided.")
        assert(
            typeof(Info.Instance) == "Instance" and Info.Instance:IsA("GuiBase2d"),
            "Instance must inherit from GuiBase2d."
        )
        assert(typeof(Info.Height) == "number" and Info.Height > 0, "Height must be a number greater than 0.")

        local Passthrough = {
            Instance = Info.Instance,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "UIPassthrough",
        }

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Passthrough.Visible,
            Parent = Container,
        })

        Passthrough.Instance.Parent = Holder
        pcall(function() Passthrough.Instance.ZIndex = 7 end)

        function Passthrough:SetHeight(Height: number)
            assert(typeof(Height) == "number" and Height > 0, "Height must be a number greater than 0.")

            Passthrough.Height = Height
            Holder.Size = UDim2.new(1, -4, 0, Height)
            Groupbox:Resize()
        end

        function Passthrough:SetInstance(Instance: Instance)
            assert(Instance, "Instance must be provided.")
            assert(
                typeof(Instance) == "Instance" and Instance:IsA("GuiBase2d"),
                "Instance must inherit from GuiBase2d."
            )

            if Passthrough.Instance then
                Passthrough.Instance.Parent = nil
            end

            Passthrough.Instance = Instance
            Passthrough.Instance.Parent = Holder
            pcall(function() Passthrough.Instance.ZIndex = 7 end)
        end

        function Passthrough:SetVisible(Visible: boolean)
            Passthrough.Visible = Visible

            Holder.Visible = Passthrough.Visible
            if Blank then Blank.Visible = Passthrough.Visible end

            Groupbox:Resize()
        end

        Passthrough:SetHeight(Passthrough.Height)

        Blank = Groupbox:AddBlank(10, Passthrough.Visible)
        Groupbox:Resize()

        Passthrough.Holder = Holder
        Passthrough.Container = Container

        table.insert(Groupbox.Elements, Passthrough)
        Options[Idx] = Passthrough

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Passthrough
    end

    function BaseGroupboxFuncs:AddDependencyBox()
        local Depbox = {
            Elements = {};
            Dependencies = {};
            TableType = "DepBox";
        }

        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        })

        local Frame = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        })

        local Layout = Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        })

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y)
            Groupbox:Resize()
        end

        Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Depbox:Resize()
        end)

        Holder:GetPropertyChangedSignal("Visible"):Connect(function()
            Depbox:Resize()
        end)

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1]
                local Value = Dependency[2]

                if if Elem.Multi then not table.find(Elem:GetActiveValues(), Value) else Elem.Value ~= Value then
                    Holder.Visible = false
                    Depbox:Resize()
                    return
                end
            end

            Holder.Visible = true
            Depbox:Resize()
        end

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(typeof(Dependency) == "table", "SetupDependencies: Dependency is not of type `table`.")
                assert(Dependency[1], "SetupDependencies: Dependency is missing element argument.")
                assert(Dependency[2] ~= nil, "SetupDependencies: Dependency is missing value argument.")
            end

            Depbox.Dependencies = Dependencies
            Depbox:Update()
        end

        Depbox.Container = Frame

        setmetatable(Depbox, BaseGroupbox)

        table.insert(Groupbox.Elements, Depbox)
        table.insert(Library.DependencyBoxes, Depbox)

        return Depbox
    end

    function BaseGroupboxFuncs:AddDependencyGroupbox()
        local ParentGroupbox = self
        local Tab = ParentGroupbox.Tab

        local DepGroupbox = {
            Elements = {};
            Dependencies = {};
            TableType = "DepGroupbox";
        }

        local BoxOuter = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 0, 507 + 2);
            ZIndex = 2;
            Parent = ParentGroupbox.Side == 1 and Tab.LeftSideFrame or Tab.RightSideFrame;
        })

        Library:AddToRegistry(BoxOuter, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        local BoxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Color3.new(0, 0, 0);

            Size = UDim2.new(1, -2, 1, -2);
            Position = UDim2.new(0, 1, 0, 1);
            ZIndex = 4;
            Parent = BoxOuter;
        })

        Library:AddToRegistry(BoxInner, {
            BackgroundColor3 = "BackgroundColor";
        })

        local Highlight = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 5;
            Parent = BoxInner;
        })

        Library:AddToRegistry(Highlight, {
            BackgroundColor3 = "AccentColor";
        })

        local Container = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 4, 0, 10);
            Size = UDim2.new(1, -4, 1, -10);
            ZIndex = 1;
            Parent = BoxInner;
        })

        Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Container;
        })

        function DepGroupbox:Resize()
            local Size = 0

            for _, Element in next, DepGroupbox.Container:GetChildren() do
                if (not Element:IsA("UIListLayout")) and Element.Visible then
                    Size = Size + Element.Size.Y.Offset
                end
            end

            BoxOuter.Size = UDim2.new(1, 0, 0, (10 * DPIScale + Size) + 2 + 2)
        end

        function DepGroupbox:Update()
            for _, Dependency in next, DepGroupbox.Dependencies do
                local Elem = Dependency[1]
                local Value = Dependency[2]

                if if Elem.Multi then not table.find(Elem:GetActiveValues(), Value) else Elem.Value ~= Value then
                    BoxOuter.Visible = false
                    DepGroupbox:Resize()
                    return
                end
            end

            BoxOuter.Visible = true
            DepGroupbox:Resize()
        end

        function DepGroupbox:SetupDependencies(Dependencies)
            for _, Dependency in pairs(Dependencies) do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            DepGroupbox.Dependencies = Dependencies
            DepGroupbox:Update()
        end

        DepGroupbox.Container = Container
        setmetatable(DepGroupbox, BaseGroupbox)

        DepGroupbox:Resize()

        table.insert(Tab.DependencyGroupboxes, DepGroupbox)
        table.insert(Library.DependencyGroupboxes, DepGroupbox)

        return DepGroupbox
    end

    BaseGroupbox.__index = BaseGroupboxFuncs
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return BaseGroupboxFuncs[Key](...)
    end
end

do
    local KeybindOuter = Library:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    })

    local KeybindInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    })

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
    }, true)

    local ColorFrame = Library:Create("Frame", {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    })

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = "AccentColor";
    }, true)

    local _KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = "Keybinds";
        ZIndex = 104;
        Parent = KeybindInner;
    })
    Library:MakeDraggable(KeybindOuter)

    local KeybindContainer = Library:Create("Frame", {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    })

    Library:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    })

    Library:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter
    Library.KeybindContainer = KeybindContainer
    Library:MakeDraggable(KeybindOuter)
end

do
    local WatermarkOuter = Library:Create("Frame", {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    })

    local WatermarkInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    })

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = "AccentColor";
    })

    local InnerFrame = Library:Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    })

    local Gradient = Library:Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    })

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            })
        end
    })

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        RichText = true;
        ZIndex = 203;
        Parent = InnerFrame;
    })

    Library.Watermark = WatermarkOuter
    Library.WatermarkText = WatermarkLabel
    Library:MakeDraggable(Library.Watermark)

    function Library:SetWatermarkVisibility(Bool)
        Library.Watermark.Visible = Bool
    end

    function Library:SetWatermark(Text)
        local X, Y = Library:GetTextBounds(Text, Library.Font, 14)
        Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3)
        Library:SetWatermarkVisibility(true)

        Library.WatermarkText.Text = Text
    end
end

do
    Library.LeftNotificationArea = Library:Create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 11000;
        Parent = ScreenGui;
    })

    Library:Create("UIListLayout", {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.LeftNotificationArea;
    })

    Library.RightNotificationArea = Library:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 11000;
        Parent = ScreenGui;
    })

    Library:Create("UIListLayout", {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        HorizontalAlignment = Enum.HorizontalAlignment.Right;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.RightNotificationArea;
    })

    function Library:SetNotifySide(Side: string)
        Library.NotifySide = Side
    end

    function Library:Notify(...)
        local Data = {}
        local Info = select(1, ...)

        if typeof(Info) == "table" then
            Data.Title = Info.Title and tostring(Info.Title) or ""
            Data.Description = tostring(Info.Description)
            Data.Time = Info.Time or 5
            Data.SoundId = Info.SoundId
            Data.Steps = Info.Steps
            Data.Persist = Info.Persist
            Data.Icon = Info.Icon
            Data.IconColor = Info.IconColor
        else
            Data.Title = ""
            Data.Description = tostring(Info)
            Data.Time = select(2, ...) or 5
            Data.SoundId = select(3, ...)
        end
        Data.Destroyed = false

        local DeletedInstance = false
        local DeleteConnection = nil
        if typeof(Data.Time) == "Instance" then
            DeleteConnection = Data.Time.Destroying:Connect(function()
                DeletedInstance = true
                DeleteConnection:Disconnect()
                DeleteConnection = nil
            end)
        end

        local Side = string.lower(Library.NotifySide)
        local XSize, YSize = Library:GetTextBounds(Data.Description, Library.Font, 14)
        YSize = YSize + 7

        local NotifyOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 0, 0, YSize);
            ClipsDescendants = true;
            ZIndex = 11000;
            Visible = false;
            Name = "Notif";
            Parent = Side == "left" and Library.LeftNotificationArea or Library.RightNotificationArea;
        })

        local NotifyInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 11001;
            Parent = NotifyOuter;
        })

        Library:AddToRegistry(NotifyInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        }, true)

        local InnerFrame = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Position = UDim2.new(0, 1, 0, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 11002;
            Parent = NotifyInner;
        })

        local Gradient = Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
            Rotation = -90;
            Parent = InnerFrame;
        })

        Library:AddToRegistry(Gradient, {
            Color = function()
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                    ColorSequenceKeypoint.new(1, Library.MainColor),
                })
            end
        })

        local ExtraWidth = 0
        local TextPosition = Side == "left" and UDim2.new(0, 4, 0, 0) or UDim2.new(1, -4, 0, 0)
        local TextSizeOffsetX = -4
        local TextSizeOffsetY = 0

        local IconLabel
        if Data.Icon then
            local ParsedIcon = Library:GetCustomIcon(Data.Icon)
            if ParsedIcon then
                ExtraWidth = ExtraWidth + 20
                TextSizeOffsetX = TextSizeOffsetX - 20
                TextSizeOffsetY = TextSizeOffsetY - 2

                if Side == "left" then
                    TextPosition = UDim2.new(0, 24, 0, 0)
                end

                IconLabel = Library:Create("ImageLabel", {
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = if Side == "left" then UDim2.new(0, 6, 0.5, 0) else UDim2.new(0, 4, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14),
                    Image = ParsedIcon.Url,
                    ImageColor3 = Data.IconColor or Library.FontColor,
                    ImageRectOffset = ParsedIcon.ImageRectOffset,
                    ImageRectSize = ParsedIcon.ImageRectSize,
                    ZIndex = 11004,
                    Parent = InnerFrame,
                })

                if not Data.IconColor then
                    Library:AddToRegistry(IconLabel, {
                        ImageColor3 = "FontColor";
                    }, true)
                end

                if Side == "right" then
                    TextPosition = UDim2.new(1, -8, 0, 0)
                end
            end
        end

        local NotifyLabel = Library:CreateLabel({
            AnchorPoint = Side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0);
            Position = TextPosition;
            Size = UDim2.new(1, TextSizeOffsetX, 1, TextSizeOffsetY);
            Text = (Data.Title == "" and "" or "[" .. Data.Title .. "] ") .. tostring(Data.Description);
            TextXAlignment = Side == "left" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right;
            TextSize = 14;
            ZIndex = 11003;
            RichText = true;
            Parent = InnerFrame;
        })

        local SideColor = Library:Create("Frame", {
            AnchorPoint = Side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0);
            Position = Side == "left" and UDim2.new(0, -1, 0, -1) or UDim2.new(1, -1, 0, -1);
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 3, 1, 2);
            ZIndex = 11004;
            Parent = NotifyOuter;
        })

        Library:AddToRegistry(SideColor, {
            BackgroundColor3 = "AccentColor";
        }, true)

        function Data:Resize()
            XSize, YSize = Library:GetTextBounds(NotifyLabel.Text, Library.Font, 14)
            YSize = YSize + 7

            pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize * DPIScale + 8 + 4 + ExtraWidth, 0, YSize), "Out", "Quad", 0.4, true)
        end

        function Data:ChangeTitle(NewText)
            NewText = NewText == nil and "" or tostring(NewText)
            Data.Title = NewText
            NotifyLabel.Text = (Data.Title == "" and "" or "[" .. Data.Title .. "] ") .. tostring(Data.Description)
            Data:Resize()
        end

        function Data:ChangeDescription(NewText)
            if NewText == nil then return end
            NewText = tostring(NewText)
            Data.Description = NewText
            NotifyLabel.Text = (Data.Title == "" and "" or "[" .. Data.Title .. "] ") .. tostring(Data.Description)
            Data:Resize()
        end

        function Data:ChangeStep(...)
        end

        function Data:Destroy()
            Data.Destroyed = true

            if typeof(Data.Time) == "Instance" then
                pcall(Data.Time.Destroy, Data.Time)
            end

            if DeleteConnection then
                DeleteConnection:Disconnect()
            end

            pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), "Out", "Quad", 0.4, true)
            task.wait(0.4)
            NotifyOuter:Destroy()
        end

        Data:Resize()

        if Data.SoundId then
            Library:Create("Sound", {
                SoundId = "rbxassetid://" .. tostring(Data.SoundId):gsub("rbxassetid://", "");
                Volume = 3;
                PlayOnRemove = true;
                Parent = game:GetService("SoundService");
            }):Destroy()
        end

        NotifyOuter.Visible = true
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize * DPIScale + 8 + 4 + ExtraWidth, 0, YSize), "Out", "Quad", 0.4, true)

        task.delay(0.4, function()
            if Data.Persist then
                return
            elseif typeof(Data.Time) == "Instance" then
                repeat
                    task.wait()
                until DeletedInstance or Data.Destroyed
            else
                task.wait(Data.Time or 5)
            end

            if not Data.Destroyed then
                Data:Destroy()
            end
        end)

        return Data
    end
end

function Library:CreateWindow(...)
    local Arguments = { ... }
    local WindowInfo = Templates.Window

    if typeof(Arguments[1]) == "table" then
        WindowInfo = Library:Validate(Arguments[1], Templates.Window)
    else
        WindowInfo = Library:Validate({
            Title = Arguments[1],
            AutoShow = Arguments[2] or false
        }, Templates.Window)
    end

    local ViewportSize: Vector2 = workspace.CurrentCamera.ViewportSize
    if RunService:IsStudio() and ViewportSize.X <= 5 and ViewportSize.Y <= 5 then
        repeat
            ViewportSize = workspace.CurrentCamera.ViewportSize
            task.wait()
        until ViewportSize.X > 5 and ViewportSize.Y > 5
    end

    if WindowInfo.Size == UDim2.fromOffset(0, 0) then
        WindowInfo.Size = if Library.IsMobile then UDim2.fromOffset(550, math.clamp(ViewportSize.Y - 35, 200, 600)) else UDim2.fromOffset(550, 600)
    end

    Library.NotifySide = WindowInfo.NotifySide
    Library.ShowCustomCursor = WindowInfo.ShowCustomCursor

    if WindowInfo.TabPadding <= 0 then WindowInfo.TabPadding = 1 end
    if WindowInfo.Center then WindowInfo.Position = UDim2.new(0.5, -WindowInfo.Size.X.Offset / 2, 0.5, -WindowInfo.Size.Y.Offset / 2) end

    local Window = {
        Tabs = {};

        OriginalTitle = WindowInfo.Title;
        Title = WindowInfo.Title;
    }

    local Outer = Library:Create("Frame", {
        AnchorPoint = WindowInfo.AnchorPoint;
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = WindowInfo.Position;
        Size = WindowInfo.Size;
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
        Name = "Window";
    })

    local ShadowGradient = Instance.new("UIGradient")
    ShadowGradient.Name = "ZX_ShadowGradient"
    ShadowGradient.Rotation = 90
    ShadowGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 13, 16)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(28, 25, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 36, 42)),
    })
    ShadowGradient.Parent = Outer

    local TopGlow = Instance.new("Frame")
    TopGlow.Name = "ZX_TopGlow"
    TopGlow.BackgroundTransparency = 1
    TopGlow.Size = UDim2.new(1, 0, 0, 3)
    TopGlow.Position = UDim2.new(0, 0, 0, 0)
    TopGlow.ZIndex = 2
    TopGlow.Parent = Outer

    local TopGlowGradient = Instance.new("UIGradient")
    TopGlowGradient.Rotation = 90
    TopGlowGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 15, 15)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 32, 38)),
    })
    TopGlowGradient.Parent = TopGlow

    local SheenFrame = Instance.new("Frame")
    SheenFrame.Name = "ZX_Sheen"
    SheenFrame.BackgroundTransparency = 1
    SheenFrame.Size = UDim2.new(2, 0, 1, 0)
    SheenFrame.Position = UDim2.new(-1, 0, 0, 0)
    SheenFrame.ZIndex = 3
    SheenFrame.ClipsDescendants = true
    SheenFrame.Parent = Outer

    local SheenImage = Instance.new("ImageLabel")
    SheenImage.Name = "ZX_SheenImage"
    SheenImage.BackgroundTransparency = 1
    SheenImage.Size = UDim2.new(0.3, 0, 1, 0)
    SheenImage.Position = UDim2.new(0, 0, 0, 0)
    SheenImage.Image = "rbxassetid://5028857084"
    SheenImage.ImageColor3 = Color3.fromRGB(180, 20, 20)
    SheenImage.ImageTransparency = 0.85
    SheenImage.ScaleType = Enum.ScaleType.Slice
    SheenImage.SliceCenter = Rect.new(0, 0, 1, 1)
    SheenImage.ZIndex = 3
    SheenImage.Parent = SheenFrame

    local OuterClip = Instance.new("Frame")
    OuterClip.Name = "ZX_OuterClip"
    OuterClip.BackgroundTransparency = 1
    OuterClip.Size = UDim2.new(1, 0, 1, 0)
    OuterClip.Position = UDim2.new(0, 0, 0, 0)
    OuterClip.ZIndex = 1
    OuterClip.ClipsDescendants = true
    OuterClip.Parent = Outer
    SheenFrame.Parent = OuterClip

    local StrokeGradient = Instance.new("UIGradient")
    StrokeGradient.Name = "ZX_StrokeGradient"
    StrokeGradient.Rotation = 45
    StrokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 10, 10)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 20, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 10, 10)),
    })

    local OuterStroke = Instance.new("UIStroke")
    OuterStroke.Name = "ZX_OuterStroke"
    OuterStroke.Thickness = 1.5
    OuterStroke.Transparency = 0.4
    OuterStroke.Color = Color3.fromRGB(80, 15, 15)
    OuterStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    OuterStroke.Parent = Outer

    local StrokeGradientClone = StrokeGradient:Clone()
    StrokeGradientClone.Parent = OuterStroke

    task.spawn(function()
        local sheenPos = -0.4
        local sheenDir = 1
        while true do
            local dt = RunService.RenderStepped:Wait()
            if not Outer or not Outer.Parent then break end
            if not Outer.Visible then continue end
            sheenPos = sheenPos + dt * 0.15 * sheenDir
            if sheenPos > 1.1 then
                sheenPos = -0.4
            end
            SheenImage.Position = UDim2.new(sheenPos, 0, 0, 0)
        end
    end)
    
    -- ZX Logo background watermark
    local ZXLogoBg = Instance.new("Frame")
    ZXLogoBg.Name = "ZXLogoBg"
    ZXLogoBg.BackgroundTransparency = 1
    ZXLogoBg.Size = UDim2.new(1, 0, 1, 0)
    ZXLogoBg.Position = UDim2.new(0, 0, 0, 0)
    ZXLogoBg.ZIndex = 0
    ZXLogoBg.Parent = Outer

    local ZXLogo = Instance.new("TextLabel")
    ZXLogo.Name = "ZXWatermark"
    ZXLogo.BackgroundTransparency = 1
    ZXLogo.Size = UDim2.new(2, 0, 2, 0)
    ZXLogo.Position = UDim2.new(-0.5, 0, -0.5, 0)
    ZXLogo.Text = "ZX"
    ZXLogo.Font = Enum.Font.GothamBlack
    ZXLogo.TextSize = 150
    ZXLogo.TextColor3 = Color3.fromRGB(30, 6, 6)
    ZXLogo.TextStrokeColor3 = Color3.fromRGB(15, 3, 3)
    ZXLogo.TextStrokeTransparency = 0.7
    ZXLogo.TextTransparency = 0.82
    ZXLogo.Rotation = -30
    ZXLogo.ZIndex = 0
    ZXLogo.Parent = ZXLogoBg

    local ZXLogo2 = Instance.new("TextLabel")
    ZXLogo2.Name = "ZXWatermark2"
    ZXLogo2.BackgroundTransparency = 1
    ZXLogo2.Size = UDim2.new(1.5, 0, 1.5, 0)
    ZXLogo2.Position = UDim2.new(-0.25, 0, -0.25, 0)
    ZXLogo2.Text = "ZytheraX"
    ZXLogo2.Font = Enum.Font.GothamBold
    ZXLogo2.TextSize = 40
    ZXLogo2.TextColor3 = Color3.fromRGB(25, 5, 5)
    ZXLogo2.TextTransparency = 0.9
    ZXLogo2.Rotation = -30
    ZXLogo2.ZIndex = 0
    ZXLogo2.Parent = ZXLogoBg
    LibraryMainOuterFrame = Outer
    -- Use a large cutoff (10000) so the window can be dragged from
    -- anywhere, not just the top 25 pixels. This fixes the "can't move
    -- the window" issue reported on weak executors.
    Library:MakeDraggable(Outer, 10000, true)
    if WindowInfo.Resizable then Library:MakeResizable(Outer, Library.MinSize) end

    Library._WindowOuter = Outer
    Library._SavePosFile = "ZytheraX_UI_Position.json"
    Library._SavePosEnabled = false
    Library._SavePosThread = nil

    function Library:LoadSavedPosition()
        pcall(function()
            if isfile and isfile(self._SavePosFile) then
                local data = game:GetService("HttpService"):JSONDecode(readfile(self._SavePosFile))
                if data and type(data.x) == "number" and type(data.y) == "number" then
                    -- Validate position is within viewport bounds.
                    -- If saved position is offscreen or invalid (e.g. 0,0 from
                    -- a previous bug), ignore it and let Center handle it.
                    local viewport = workspace.CurrentCamera.ViewportSize
                    local winSize = self._WindowOuter.Size
                    local winW = winSize.X.Offset
                    local winH = winSize.Y.Offset
                    -- Reject if window would be entirely offscreen or at (0,0)
                    if data.x < -50 or data.y < -50 then return end
                    if data.x > viewport.X - 50 or data.y > viewport.Y - 50 then return end
                    -- Reject obviously invalid (0,0) saved position
                    if data.x == 0 and data.y == 0 then return end
                    self._WindowOuter.Position = UDim2.new(0, data.x, 0, data.y)
                end
            end
        end)
    end

    function Library:SavePositionNow()
        pcall(function()
            if writefile and self._WindowOuter then
                local pos = self._WindowOuter.Position
                writefile(self._SavePosFile, game:GetService("HttpService"):JSONEncode({x = pos.X.Offset, y = pos.Y.Offset}))
            end
        end)
    end

    function Library:StartAutoSavePosition()
        if self._SavePosThread then return end
        self._SavePosEnabled = true
        self._SavePosThread = task.spawn(function()
            local lastSave = 0
            local lastX, lastY = -1, -1
            while self._SavePosEnabled do
                pcall(function()
                    local pos = Library._WindowOuter.Position
                    local x, y = pos.X.Offset, pos.Y.Offset
                    if x ~= lastX or y ~= lastY then
                        lastX, lastY = x, y
                        if tick() - lastSave > 1 then
                            lastSave = tick()
                            Library:SavePositionNow()
                        end
                    end
                end)
                task.wait(0.5)
            end
        end)
    end

    function Library:StopAutoSavePosition()
        self._SavePosEnabled = false
        self._SavePosThread = nil
    end

    function Library:ResetPosition()
        pcall(function()
            self._WindowOuter.Position = UDim2.new(0.5, -self._WindowOuter.Size.X.Offset / 2, 0.5, -self._WindowOuter.Size.Y.Offset / 2)
        end)
    end

    Library:LoadSavedPosition()

    local Inner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    })

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "AccentColor";
    })

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = WindowInfo.Title or "";
        TextXAlignment = Enum.TextXAlignment.Left;
        RichText = true;
        ZIndex = 1;
        Parent = Inner;
    })

    local MainSectionOuter = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        ZIndex = 1;
        Parent = Inner;
    })

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = "BackgroundColor";
        BorderColor3 = "OutlineColor";
    })

    local MainSectionInner = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    })

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = "BackgroundColor";
    })

    local TabArea = Library:Create("ScrollingFrame", {
        ScrollingDirection = Enum.ScrollingDirection.X;
        CanvasSize = UDim2.new(0, 0, 2, 0);
        HorizontalScrollBarInset = Enum.ScrollBarInset.Always;
        AutomaticCanvasSize = Enum.AutomaticSize.XY;
        ScrollBarThickness = 0;
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8 - WindowInfo.TabPadding, 0, 4);
        Size = UDim2.new(1, -10, 0, 26);
        ZIndex = 1;
        Parent = MainSectionInner;
    })

    local TabListLayout = Library:Create("UIListLayout", {
        Padding = UDim.new(0, WindowInfo.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        Parent = TabArea;
    })

    Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.new(0, 0, 0, 0);
        LayoutOrder = -1;
        BackgroundTransparency = 1;
        ZIndex = 1;
        Parent = TabArea;
    })
    Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.new(0, 0, 0, 0);
        LayoutOrder = 9999999;
        BackgroundTransparency = 1;
        ZIndex = 1;
        Parent = TabArea;
    })

    local TabContainer = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 2;
        Parent = MainSectionInner;
    })

    local InnerVideoBackground = Library:Create("VideoFrame", {
        BackgroundColor3 = Library.MainColor;
        BorderMode = Enum.BorderMode.Inset;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 2;
        Visible = false;
        Volume = 0;
        Looped = true;
        Parent = TabContainer;
    })
    Library.InnerVideoBackground = InnerVideoBackground

    local BackgroundImage = Library:Create("ImageLabel", {
        Image = "";
        Position = UDim2.fromScale(0, 0);
        Size = UDim2.fromScale(1, 1);
        ScaleType = Enum.ScaleType.Stretch;
        ZIndex = 2;
        BackgroundTransparency = 1;
        ImageTransparency = 0.75;
        Parent = TabContainer;
        Visible = false;
    })

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
    })

    function Window:SetWindowTitle(Title)
        if typeof(Title) == "string" then
            Window.Title = Title
            WindowLabel.Text = Window.Title
        end
    end

    function Window:SetBackgroundImage(NewImage)
        if tonumber(NewImage) then
            NewImage = "rbxassetid://" .. NewImage
        end

        assert(typeof(NewImage) == "string", "Image must be a string.")

        local Icon = Library:GetCustomIcon(NewImage)
        if not Icon then
            BackgroundImage.Visible = false
            return
        end

        assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        BackgroundImage.Image = Icon.Url
        BackgroundImage.ImageRectOffset = Icon.ImageRectOffset
        BackgroundImage.ImageRectSize = Icon.ImageRectSize

        BackgroundImage.Visible = true
    end

    function Window:AddDialog(Idx, Info)
        assert(Info.Title, "AddDialog: Missing `Title` string.")
        assert(Info.Description, "AddDialog: Missing `Description` string.")

        local DialogFrame
        local DialogOverlay
        local DialogContainer
        local ButtonsHolder
        local FooterButtonsList = {}

        DialogOverlay = Library:Create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            Active = false,
            ZIndex = 9000,
            Visible = true,
            Parent = LibraryMainOuterFrame,
        })
        TweenService:Create(DialogOverlay, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.5,
        }):Play()

        DialogFrame = Library:Create("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Color3.new(0, 0, 0),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(300, 0),
            ZIndex = 9001,
            Visible = true,
            Parent = DialogOverlay,
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            AutoButtonColor = false,
        })

        local DialogInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.AccentColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 9002,
            Parent = DialogFrame,
        })

        Library:AddToRegistry(DialogFrame, {
            BackgroundColor3 = "BackgroundColor",
        })

        Library:AddToRegistry(DialogInner, {
            BackgroundColor3 = "MainColor",
            BorderColor3 = "AccentColor",
        })

        local InnerContainer = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 9003,
            Parent = DialogInner,
        })
        local DialogScale = Library:Create("UIScale", {
            Scale = 0.95,
            Parent = DialogFrame,
        })
        TweenService:Create(DialogScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Scale = 1
        }):Play()

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
            PaddingTop = UDim.new(0, 15),
            Parent = InnerContainer,
        })
        local _InnerListLayout = Library:Create("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = InnerContainer,
        })

        local HeaderContainer = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9003,
            Parent = InnerContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = HeaderContainer,
        })
        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = HeaderContainer,
        })

        local TitleRow = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9003,
            Parent = HeaderContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = TitleRow,
        })

        local TitleLabel = Library:CreateLabel({
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Title or "Dialog",
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 9003,
            Parent = TitleRow,
            RichText = true,
        })
        if Info.TitleColor then
            TitleLabel.TextColor3 = Info.TitleColor
        else
            Library:AddToRegistry(TitleLabel, { TextColor3 = "FontColor" })
        end

        local DescriptionLabel = Library:CreateLabel({
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Description or "Description",
            TextSize = 14,
            TextTransparency = Info.DescriptionColor and 0 or 0.2,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 9003,
            LayoutOrder = 2,
            Parent = HeaderContainer,
            RichText = true,
        })
        if Info.DescriptionColor then
            DescriptionLabel.TextColor3 = Info.DescriptionColor
        else
            Library:AddToRegistry(DescriptionLabel, { TextColor3 = "FontColor" })
        end

        DialogContainer = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
            Visible = false,
            ZIndex = 9003,
            Parent = InnerContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = DialogContainer,
        })

        local _Sep2 = Library:Create("Frame", {
            BackgroundColor3 = Library.OutlineColor,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 1),
            LayoutOrder = 5,
            ZIndex = 9003,
            Parent = InnerContainer,
        })
        Library:AddToRegistry(_Sep2, {
            BackgroundColor3 = "OutlineColor",
        })

        ButtonsHolder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 6,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Wraps = true,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ButtonsHolder,
        })
        Library:Create("UIPadding", {
            PaddingTop = UDim.new(0, 0),
            Parent = ButtonsHolder,
        })

        local Dialog = {
            Elements = {},
            Container = DialogContainer,
        }

        function Dialog:Resize()
            local MaxWidth = LibraryMainOuterFrame.AbsoluteSize.X * 0.75
            local MinWidth = 400 * DPIScale

            local TotalButtonWidth = 0
            local ButtonCount = 0
            local HasButtons = false

            for _, BtnWrap in pairs(FooterButtonsList) do
                HasButtons = true
                ButtonCount = ButtonCount + 1
                TotalButtonWidth = TotalButtonWidth + BtnWrap.Container.Size.X.Offset
            end

            local TargetWidth = MinWidth
            if HasButtons then
                local RequiredWidth = TotalButtonWidth + ((ButtonCount - 1) * 8 * DPIScale) + (30 * DPIScale)
                TargetWidth = math.max(MinWidth, math.min(RequiredWidth, MaxWidth))
            end

            local DescY = select(2, Library:GetTextBounds(DescriptionLabel.Text, Library.Font, 14 * DPIScale, TargetWidth - (30 * DPIScale)))
            DescriptionLabel.Size = UDim2.new(1, 0, 0, DescY)

            local HasElements = false
            for _, v in pairs(DialogContainer:GetChildren()) do
                if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
                    HasElements = true
                    break
                end
            end

            if HasElements then
                for _, v in pairs(DialogContainer:GetDescendants()) do
                    if not v:IsA("GuiObject") then continue end
                    if v:GetAttribute("ZIndexApplied") then continue end

                    v:SetAttribute("ZIndexApplied", true)
                    v.ZIndex = v.ZIndex + 9003
                end
            end

            DialogContainer.Visible = HasElements

            ButtonsHolder.Visible = HasButtons
            _Sep2.Visible = HasButtons

            DialogFrame.Size = UDim2.fromOffset(TargetWidth, 0)
        end

        function Dialog:SetTitle(Title)
            TitleLabel.Text = Title
            Dialog:Resize()
        end

        function Dialog:SetDescription(Description)
            DescriptionLabel.Text = Description
            Dialog:Resize()
        end

        function Dialog:Dismiss()
            TweenService:Create(DialogScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.95 }):Play()
            TweenService:Create(DialogOverlay, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()

            task.delay(0.1, function()
                DialogOverlay:Destroy()
            end)

            if Library.Dialogues then Library.Dialogues[Idx] = nil end
            Library.ActiveDialog = nil
        end

        DialogOverlay.MouseButton1Click:Connect(function()
            if Info.OutsideClickDismiss then
                Dialog:Dismiss()
            end
        end)

        function Dialog:RemoveFooterButton(ButtonIdx)
            if FooterButtonsList[ButtonIdx] then
                FooterButtonsList[ButtonIdx].Container:Destroy()
                FooterButtonsList[ButtonIdx] = nil
            end
        end

        function Dialog:SetButtonDisabled(ButtonIdx, Disabled)
            if FooterButtonsList[ButtonIdx] and type(FooterButtonsList[ButtonIdx].SetDisabled) == "function" then
                FooterButtonsList[ButtonIdx]:SetDisabled(Disabled)
            end
        end

        function Dialog:SetButtonOrder(ButtonIdx, Order)
            if FooterButtonsList[ButtonIdx] and FooterButtonsList[ButtonIdx].Container then
                FooterButtonsList[ButtonIdx].Container.LayoutOrder = Order
            end
        end

        function Dialog:AddFooterButton(ButtonIdx, ButtonInfo)
            Dialog:RemoveFooterButton(ButtonIdx)

            local WaitTime = ButtonInfo.WaitTime or 0
            local Variant = ButtonInfo.Variant or "Primary"

            local BtnInnerColor = Library.MainColor
            local BtnBorderColor = Library.OutlineColor
            local DestructiveColor = Color3.fromRGB(220, 38, 38)

            if Variant == "Primary" then
                BtnBorderColor = Library.AccentColor
            elseif Variant == "Secondary" then
                BtnInnerColor = Library.BackgroundColor
                BtnBorderColor = Library.OutlineColor
            elseif Variant == "Destructive" then
                BtnBorderColor = DestructiveColor
            elseif Variant == "Ghost" then
                BtnBorderColor = Library.MainColor
            end

            local LabelX = select(1, Library:GetTextBounds(ButtonInfo.Title or ButtonIdx, Library.Font, 14 * DPIScale))
            local BtnW = LabelX + (24 * DPIScale)
            local BtnH = 20 * DPIScale

            local ButtonContainer = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0),
                BorderColor3 = Color3.new(0, 0, 0),
                Size = UDim2.fromOffset(BtnW, BtnH),
                LayoutOrder = ButtonInfo.Order or 0,
                ZIndex = 9003,
                Parent = ButtonsHolder,
            })
            Library:AddToRegistry(ButtonContainer, { BorderColor3 = "Black" })

            local TextBtn = Library:Create("TextButton", {
                BackgroundColor3 = BtnInnerColor,
                BorderColor3 = BtnBorderColor,
                BorderMode = Enum.BorderMode.Inset,
                BackgroundTransparency = WaitTime > 0 and 0.5 or 0,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                AutoButtonColor = false,
                ZIndex = 9004,
                Parent = ButtonContainer,
            })

            if Variant == "Primary" then
                Library:AddToRegistry(TextBtn, { BackgroundColor3 = "MainColor", BorderColor3 = "AccentColor" })
            elseif Variant == "Secondary" then
                Library:AddToRegistry(TextBtn, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
            elseif Variant == "Ghost" then
                Library:AddToRegistry(TextBtn, { BackgroundColor3 = "MainColor", BorderColor3 = "MainColor" })
            end

            Library:Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)),
                }),
                Rotation = 90,
                Parent = TextBtn,
            })

            local HighlightBorderColor = Variant == "Destructive" and DestructiveColor or Library.AccentColor
            ButtonContainer.MouseEnter:Connect(function()
                ButtonContainer.BorderColor3 = HighlightBorderColor
            end)
            ButtonContainer.MouseLeave:Connect(function()
                ButtonContainer.BorderColor3 = Color3.new(0, 0, 0)
            end)

            local TextColor = Library.FontColor
            if Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end

            local BtnLabel = Library:CreateLabel({
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or ButtonIdx,
                TextColor3 = TextColor,
                TextTransparency = WaitTime > 0 and 0.5 or 0,
                TextSize = 14 * DPIScale,
                ZIndex = 9005,
                Parent = TextBtn,
            })

            if Variant ~= "Destructive" then
                Library:AddToRegistry(BtnLabel, { TextColor3 = "FontColor" })
            end

            local ProgressBar
            if WaitTime > 0 then
                ProgressBar = Library:Create("Frame", {
                    BackgroundColor3 = Library.AccentColor,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, -2),
                    Size = UDim2.new(0, 0, 0, 2),
                    ZIndex = 2,
                    Parent = TextBtn,
                })
                Library:AddToRegistry(ProgressBar, { BackgroundColor3 = "AccentColor" })
            end

            local IsActive = WaitTime <= 0

            local ButtonWrap = {
                Container = ButtonContainer,
                SetDisabled = function(self, Disabled)
                    IsActive = not Disabled
                    if Disabled then
                        TweenService:Create(TextBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.5 }):Play()
                        TweenService:Create(BtnLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.5 }):Play()
                    else
                        TweenService:Create(TextBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
                        TweenService:Create(BtnLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
                    end
                end
            }

            TextBtn.MouseButton1Click:Connect(function()
                if not IsActive then return end

                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Dialog)
                end

                if Info.AutoDismiss ~= false then
                    Dialog:Dismiss()
                end
            end)

            if WaitTime > 0 then
                TweenService:Create(ProgressBar, TweenInfo.new(WaitTime, Enum.EasingStyle.Linear), {
                    Size = UDim2.new(1, 0, 0, 2)
                }):Play()

                task.delay(WaitTime, function()
                    ButtonWrap:SetDisabled(false)

                    if ProgressBar then
                        TweenService:Create(ProgressBar, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            BackgroundTransparency = 1
                        }):Play()
                    end
                end)
            end

            FooterButtonsList[ButtonIdx] = ButtonWrap
        end

        if Info.FooterButtons then
            for BIdx, BInfo in pairs(Info.FooterButtons) do
                if type(BIdx) == "number" and BInfo.Id then BIdx = BInfo.Id end
                Dialog:AddFooterButton(BIdx, BInfo)
            end
        end

        setmetatable(Dialog, BaseGroupbox)

        Library.Dialogues[Idx] = Dialog
        Library.ActiveDialog = Dialog

        Dialog:Resize()

        return Dialog
    end

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
            DependencyGroupboxes = {};
            WarningBox = {
                Bottom = false,
                IsNormal = false,
                LockSize = false,
                Visible = false,
                Title = "WARNING",
                Text = ""
            };
            OriginalName = Name;
            Name = Name;
            TableType = "Tab";
        }

        local TabButtonWidth = Library:GetTextBounds(Tab.Name, Library.Font, 16)

        local TabButton = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 0.85, 0);
            ZIndex = 1;
            Parent = TabArea;
        })

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Tab.Name;
            ZIndex = 1;
            Parent = TabButton;
        })

        local Blocker = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        })

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = "MainColor";
        })

        local TabFrame = Library:Create("Frame", {
            Name = "TabFrame",
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        })

        local TopBarLabelStroke
        local TopBarHighlight
        local TopBar, TopBarInner, TopBarLabel, TopBarTextLabel, TopBarScrollingFrame
do
            TopBar = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.fromRGB(248, 51, 51);
                BorderMode = Enum.BorderMode.Inset;
                Position = UDim2.new(0, 7, 0, 7);
                Size = UDim2.new(1, -13, 0, 0);
                ZIndex = 2;
                Parent = TabFrame;
                Visible = false;
            })

            TopBarInner = Library:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(117, 22, 17);
                BorderColor3 = Color3.new();

                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = TopBar;
            })

            TopBarHighlight = Library:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 75, 75);
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = TopBarInner;
            })

            TopBarScrollingFrame = Library:Create("ScrollingFrame", {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, -8, 1, 0);
                CanvasSize = UDim2.new(0, 0, 0, 0);
                AutomaticCanvasSize = Enum.AutomaticSize.Y;
                ScrollBarThickness = 3;
                ZIndex = 5;
                Parent = TopBarInner;
            })

            TopBarLabel = Library:Create("TextLabel", {
                BackgroundTransparency = 1;
                Font = Library.Font;
                TextStrokeTransparency = 0;
                RichText = true;

                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = "Text";
                TextXAlignment = Enum.TextXAlignment.Left;
                TextColor3 = Color3.fromRGB(255, 55, 55);
                ZIndex = 5;
                Parent = TopBarScrollingFrame;
            })

            TopBarLabelStroke = Library:ApplyTextStroke(TopBarLabel)
            TopBarLabelStroke.Color = Color3.fromRGB(174, 3, 3)

            TopBarTextLabel = Library:CreateLabel({
                RichText = true;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, 0, 0, 14);
                TextSize = 14;
                Text = "Text";
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Top;
                ZIndex = 5;
                Parent = TopBarScrollingFrame;
            })

            Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 5);
                Visible = true;
                ZIndex = 1;
                Parent = TopBarInner;
            })
        end

        local LeftSide = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 7, 0, 7);
            Size = UDim2.new(0.5, -10, 1, -14);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = "";
            TopImage = "";
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        })

        local RightSide = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 5, 0, 7);
            Size = UDim2.new(0.5, -10, 1, -14);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = "";
            TopImage = "";
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        })

        Tab.LeftSideFrame = LeftSide
        Tab.RightSideFrame = RightSide

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        })

        if Library.IsMobile then
            local SidesValues = {
                ["Left"] = tick(),
                ["Right"] = tick(),
            }

            LeftSide:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                Library.CanDrag = false

                local ChangeTick = tick()
                SidesValues.Left = ChangeTick
                task.wait(0.15)

                if SidesValues.Left == ChangeTick then
                    Library.CanDrag = true
                end
            end)

            RightSide:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                Library.CanDrag = false

                local ChangeTick = tick()
                SidesValues.Right = ChangeTick
                task.wait(0.15)

                if SidesValues.Right == ChangeTick then
                    Library.CanDrag = true
                end
            end)
        end

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y)
            end)
        end

        function Tab:Resize()
            if TopBar.Visible == true then
                local MaximumSize = math.floor(TabFrame.AbsoluteSize.Y / 3.25)
                local Size = 27 + select(2, Library:GetTextBounds(TopBarTextLabel.Text, Library.Font, 14, Vector2.new(TopBarTextLabel.AbsoluteSize.X, math.huge)))

                if Tab.WarningBox.LockSize == true and Size >= MaximumSize then
                    Size = MaximumSize
                end

                if Tab.WarningBox.Bottom == true then
                    TopBar.Position = UDim2.new(0, 7, 1, -(Size + 7))
                else
                    TopBar.Position = UDim2.new(0, 7, 0, 7)
                end

                TopBar.Size = UDim2.new(1, -13, 0, Size)
                Size = Size + 10

                if TopBar.Position.Y.Offset > 0 then
                    LeftSide.Position = UDim2.new(0, 7, 0, 7 + Size)
                    LeftSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)

                    RightSide.Position = UDim2.new(0.5, 5, 0, 7 + Size)
                    RightSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)
                else
                    LeftSide.Position = UDim2.new(0, 7, 0, 7)
                    LeftSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)

                    RightSide.Position = UDim2.new(0.5, 5, 0, 7)
                    RightSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)
                end
            else
                LeftSide.Position = UDim2.new(0, 7, 0, 7)
                LeftSide.Size = UDim2.new(0.5, -10, 1, -14)

                RightSide.Position = UDim2.new(0.5, 5, 0, 7)
                RightSide.Size = UDim2.new(0.5, -10, 1, -14)
            end
        end

        function Tab:UpdateWarningBox(Info)
            if typeof(Info.Bottom) == "boolean"     then Tab.WarningBox.Bottom      = Info.Bottom end
            if typeof(Info.IsNormal) == "boolean"   then Tab.WarningBox.IsNormal      = Info.IsNormal end
            if typeof(Info.LockSize) == "boolean"   then Tab.WarningBox.LockSize    = Info.LockSize end
            if typeof(Info.Visible) == "boolean"    then Tab.WarningBox.Visible     = Info.Visible end
            if typeof(Info.Title) == "string"       then Tab.WarningBox.Title       = Info.Title end
            if typeof(Info.Text) == "string"        then Tab.WarningBox.Text        = Info.Text end

            TopBar.Visible = Tab.WarningBox.Visible
            TopBarLabel.Text = Tab.WarningBox.Title
            TopBarTextLabel.Text = Tab.WarningBox.Text
            if TopBar.Visible then Tab:Resize()
end

            TopBar.BorderColor3 = Tab.WarningBox.IsNormal == true and Color3.fromRGB(27, 42, 53) or Color3.fromRGB(248, 51, 51)
            TopBarInner.BorderColor3 = Tab.WarningBox.IsNormal == true and Library.OutlineColor or Color3.fromRGB(0, 0, 0)
            TopBarInner.BackgroundColor3 = Tab.WarningBox.IsNormal == true and Library.BackgroundColor or Color3.fromRGB(117, 22, 17)
            TopBarHighlight.BackgroundColor3 = Tab.WarningBox.IsNormal == true and Library.AccentColor or Color3.fromRGB(255, 75, 75)

            TopBarLabel.TextColor3 = Tab.WarningBox.IsNormal == true and Library.FontColor or Color3.fromRGB(255, 55, 55)
            TopBarLabelStroke.Color = Tab.WarningBox.IsNormal == true and Library.Black or Color3.fromRGB(174, 3, 3)

            if not Library.RegistryMap[TopBarInner] then Library:AddToRegistry(TopBarInner, {}) end
            if not Library.RegistryMap[TopBarHighlight] then Library:AddToRegistry(TopBarHighlight, {}) end
            if not Library.RegistryMap[TopBarLabel] then Library:AddToRegistry(TopBarLabel, {}) end
            if not Library.RegistryMap[TopBarLabelStroke] then Library:AddToRegistry(TopBarLabelStroke, {}) end

            Library.RegistryMap[TopBarInner].Properties.BorderColor3 = Tab.WarningBox.IsNormal == true and "OutlineColor" or nil
            Library.RegistryMap[TopBarInner].Properties.BackgroundColor3 = Tab.WarningBox.IsNormal == true and "BackgroundColor" or nil
            Library.RegistryMap[TopBarHighlight].Properties.BackgroundColor3 = Tab.WarningBox.IsNormal == true and "AccentColor" or nil

            Library.RegistryMap[TopBarLabel].Properties.TextColor3 = Tab.WarningBox.IsNormal == true and "FontColor" or nil
            Library.RegistryMap[TopBarLabelStroke].Properties.Color = Tab.WarningBox.IsNormal == true and "Black" or nil
        end

        function Tab:ShowTab()
            Library.ActiveTab = Name
            for _, Tab in next, Window.Tabs do
                Tab:HideTab()
            end

            Blocker.BackgroundTransparency = 0
            TabButton.BackgroundColor3 = Library.MainColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = "MainColor"
            TabFrame.Visible = true

            Tab:Resize()
        end
        Tab.Show = Tab.ShowTab

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1
            TabButton.BackgroundColor3 = Library.BackgroundColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = "BackgroundColor"
            TabFrame.Visible = false
        end
        Tab.Hide = Tab.HideTab

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position
            TabListLayout:ApplyLayout()
        end

        function Tab:GetSides()
            return { ["Left"] = LeftSide, ["Right"] = RightSide }
        end

        function Tab:SetName(Name)
            if typeof(Name) == "string" then
                Tab.Name = Name

                local TabButtonWidth = Library:GetTextBounds(Tab.Name, Library.Font, 16)

                TabButton.Size = UDim2.new(0, TabButtonWidth + 8 + 4, 0.85, 0)
                TabButtonLabel.Text = Tab.Name
            end
        end

        function Tab:AddGroupbox(Info)
            local Groupbox = {
                Elements = {};
                Side = Info.Side;
                Tab = Tab;
                TableType = "Groupbox";
            }

            local BoxOuter = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            })

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            local BoxInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);

                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            })

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = "BackgroundColor";
            })

            local Highlight = Library:Create("Frame", {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            })

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = "AccentColor";
            })

            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            })

            local Container = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            })

            Library:Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            })

            function Groupbox:Resize()
                local Size = 0

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA("UIListLayout")) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset
                    end
                end

                BoxOuter.Size = UDim2.new(1, 0, 0, (20 * DPIScale + Size) + 2 + 2)
            end

            Groupbox.Container = Container
            setmetatable(Groupbox, BaseGroupbox)

            Groupbox:AddBlank(3)
            Groupbox:Resize()

            Tab.Groupboxes[Info.Name] = Groupbox

            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; })
        end

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; })
        end

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            }

            local BoxOuter = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            })

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            local BoxInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);

                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            })

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = "BackgroundColor";
            })

            local Highlight = Library:Create("Frame", {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            })

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = "AccentColor";
            })

            local TabboxButtons = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            })

            Library:Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            })

            function Tabbox:AddTab(Name)
                local Tab = {
                    Elements = {};
                    Container = nil;
                    TableType = "TabboxTab";
                }

                local Button = Library:Create("Frame", {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                })

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = "MainColor";
                })

                Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                    RichText = true;
                })

                local Block = Library:Create("Frame", {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                })

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = "BackgroundColor";
                })

                local Container = Library:Create("Frame", {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                })

                Library:Create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                })

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide()
                    end

                    Container.Visible = true
                    Block.Visible = true

                    Button.BackgroundColor3 = Library.BackgroundColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = "BackgroundColor"

                    Tab:Resize()
                end

                function Tab:Hide()
                    Container.Visible = false
                    Block.Visible = false

                    Button.BackgroundColor3 = Library.MainColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = "MainColor"
                end

                function Tab:Resize()
                    local TabCount = 0

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1
                    end

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA("UIListLayout") then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0)
                        end
                    end

                    if (not Container.Visible) then
                        return
                    end

                    local Size = 0

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA("UIListLayout")) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset
                        end
                    end

                    BoxOuter.Size = UDim2.new(1, 0, 0, (20 * DPIScale + Size) + 2 + 2)
                end

                Button.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                        Tab:Show()
                        Tab:Resize()
                    end
                end)

                Tab.Container = Container
                Tabbox.Tabs[Name] = Tab

                setmetatable(Tab, BaseGroupbox)

                Tab:AddBlank(3)
                Tab:Resize()

                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show()
                end

                return Tab
            end

            Tab.Tabboxes[Info.Name or ""] = Tabbox

            return Tabbox
        end

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; })
        end

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; })
        end

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                Tab:ShowTab()
            end
        end)

        TopBar:GetPropertyChangedSignal("Visible"):Connect(function()
            Tab:Resize()
        end)

        Library.TotalTabs = Library.TotalTabs + 1
        if Library.TotalTabs == 1 then
            Tab:ShowTab()
        end

        Window.Tabs[Name] = Tab
        return Tab
    end

    local TransparencyCache = {}
    local Toggled = false
    local Fading = false

    function Window:Toggle(Toggling)
        if typeof(Toggling) == "boolean" and Toggling == Toggled then return end
        if Fading then return end

        local FadeTime = WindowInfo.MenuFadeTime
        Fading = true
        Toggled = (not Toggled)

        Library.Toggled = Toggled
        if WindowInfo.UnlockMouseWhileOpen then
            ModalElement.Modal = Library.Toggled
        end

        if Toggled then

            Outer.Visible = true

            if DrawingLib.drawing_replaced ~= true and IsBadDrawingLib ~= true then
                IsBadDrawingLib = not (pcall(function()
                    local Cursor = DrawingLib.new("Triangle")
                    Cursor.Thickness = 1
                    Cursor.Filled = true
                    Cursor.Visible = Library.ShowCustomCursor

                    local CursorOutline = DrawingLib.new("Triangle")
                    CursorOutline.Thickness = 1
                    CursorOutline.Filled = false
                    CursorOutline.Color = Color3.new(0, 0, 0)
                    CursorOutline.Visible = Library.ShowCustomCursor

                    local OldMouseIconState = InputService.MouseIconEnabled
                    local ShowCursorBinding = Library.ShowCursorBinding
                    pcall(function() RunService:UnbindFromRenderStep(ShowCursorBinding) end)
                    RunService:BindToRenderStep(ShowCursorBinding, Enum.RenderPriority.Camera.Value - 1, function()
                        InputService.MouseIconEnabled = not Library.ShowCustomCursor
                        local mPos = InputService:GetMouseLocation()
                        local X, Y = mPos.X, mPos.Y
                        Cursor.Color = Library.AccentColor
                        Cursor.PointA = Vector2.new(X, Y)
                        Cursor.PointB = Vector2.new(X + 16, Y + 6)
                        Cursor.PointC = Vector2.new(X + 6, Y + 16)
                        Cursor.Visible = Library.ShowCustomCursor
                        CursorOutline.PointA = Cursor.PointA
                        CursorOutline.PointB = Cursor.PointB
                        CursorOutline.PointC = Cursor.PointC
                        CursorOutline.Visible = Library.ShowCustomCursor

                        if not Toggled or (not ScreenGui or not ScreenGui.Parent) then
                            InputService.MouseIconEnabled = OldMouseIconState
                            if Cursor then Cursor:Destroy() end
                            if CursorOutline then CursorOutline:Destroy() end
                            RunService:UnbindFromRenderStep(ShowCursorBinding)
                        end
                    end)
                end))
            end
        end

        for _, Option in Options do
            task.spawn(function()
                if Option.Type == "Dropdown" then
                    Option:CloseDropdown()

                elseif Option.Type == "KeyPicker" then
                    Option:SetModePickerVisibility(false)

                elseif Option.Type == "ColorPicker" then
                    Option.ContextMenu:Hide()
                    Option:Hide()
                end
            end)
        end

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {}

            if Desc:IsA("ImageLabel") then
                table.insert(Properties, "ImageTransparency")
                table.insert(Properties, "BackgroundTransparency")

            elseif Desc:IsA("TextLabel") or Desc:IsA("TextBox") then
                table.insert(Properties, "TextTransparency")

            elseif Desc:IsA("Frame") or Desc:IsA("ScrollingFrame") then
                table.insert(Properties, "BackgroundTransparency")

            elseif Desc:IsA("UIStroke") then
                table.insert(Properties, "Transparency")
            end

            local Cache = TransparencyCache[Desc]

            if (not Cache) then
                Cache = {}
                TransparencyCache[Desc] = Cache
            end

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop]
                end

                if Cache[Prop] == 1 then
                    continue
                end

                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play()
            end
        end

        task.wait(FadeTime)
        Outer.Visible = Toggled
        Fading = false
    end

    function Library:Toggle(Toggling)
        return Window:Toggle(Toggling)
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if Library.Unloaded then
            return
        end

        if typeof(Library.ToggleKeybind) == "table" and Library.ToggleKeybind.Type == "KeyPicker" then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end

        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Library.IsMobile then
        local ToggleUIOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0.008, 0, 0.018, 0);
            Size = UDim2.new(0, 77, 0, 30);
            ZIndex = 200;
            Visible = true;
            Parent = ScreenGui;
        })

        local ToggleUIInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.AccentColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 201;
            Parent = ToggleUIOuter;
        })

        Library:AddToRegistry(ToggleUIInner, {
            BorderColor3 = "AccentColor";
        })

        local ToggleUIInnerFrame = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Position = UDim2.new(0, 1, 0, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 202;
            Parent = ToggleUIInner;
        })

        local ToggleUIGradient = Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
            Rotation = -90;
            Parent = ToggleUIInnerFrame;
        })

        Library:AddToRegistry(ToggleUIGradient, {
            Color = function()
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                    ColorSequenceKeypoint.new(1, Library.MainColor),
                })
            end
        })

        local ToggleUIButton = Library:Create("TextButton", {
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -4, 1, 0);
            BackgroundTransparency = 1;
            Font = Library.Font;
            Text = "Toggle UI";
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextStrokeTransparency = 0;
            ZIndex = 203;
            Parent = ToggleUIInnerFrame;
        })

        Library:MakeDraggableUsingParent(ToggleUIButton, ToggleUIOuter)

        ToggleUIButton.MouseButton1Down:Connect(function()
            Library:Toggle()
        end)

        local LockUIOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0.008, 0, 0.075, 0);
            Size = UDim2.new(0, 77, 0, 30);
            ZIndex = 200;
            Visible = true;
            Parent = ScreenGui;
        })

        local LockUIInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.AccentColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 201;
            Parent = LockUIOuter;
        })

        Library:AddToRegistry(LockUIInner, {
            BorderColor3 = "AccentColor";
        })

        local LockUIInnerFrame = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Position = UDim2.new(0, 1, 0, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 202;
            Parent = LockUIInner;
        })

        local LockUIGradient = Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
            Rotation = -90;
            Parent = LockUIInnerFrame;
        })

        Library:AddToRegistry(LockUIGradient, {
            Color = function()
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                    ColorSequenceKeypoint.new(1, Library.MainColor),
                })
            end
        })

        local LockUIButton = Library:Create("TextButton", {
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -4, 1, 0);
            BackgroundTransparency = 1;
            Font = Library.Font;
            Text = "Lock UI";
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextStrokeTransparency = 0;
            ZIndex = 203;
            Parent = LockUIInnerFrame;
        })

        Library:MakeDraggableUsingParent(LockUIButton, LockUIOuter)

        LockUIButton.MouseButton1Down:Connect(function()
            Library.CantDragForced = not Library.CantDragForced
            LockUIButton.Text = Library.CantDragForced and "Unlock UI" or "Lock UI"
        end)
    end

    Window:SetBackgroundImage(WindowInfo.BackgroundImage or "")
    if WindowInfo.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer
    Library.Window = Window

    return Window
end

local function OnPlayerChange()
    if Library.Unloaded then
        return
    end

    local PlayerList, ExcludedPlayerList = GetPlayers(false, true), GetPlayers(true, true)
    local StringPlayerList, StringExcludedPlayerList = GetPlayers(false, false), GetPlayers(true, false)

    for _, Value in next, Options do
        if Value.SetValues and Value.Type == "Dropdown" and Value.SpecialType == "Player" then
            Value:SetValues(
                if Value.ReturnInstanceInstead then
                    (if Value.ExcludeLocalPlayer then ExcludedPlayerList else PlayerList)
                else
                    (if Value.ExcludeLocalPlayer then StringExcludedPlayerList else StringPlayerList)
            )
        end
    end
end

local function OnTeamChange()
    if Library.Unloaded then
        return
    end

    local TeamList = GetTeams(false)
    local StringTeamList = GetTeams(true)

    for _, Value in next, Options do
        if Value.SetValues and Value.Type == "Dropdown" and Value.SpecialType == "Team" then
            Value:SetValues(if Value.ReturnInstanceInstead then TeamList else StringTeamList)
        end
    end
end

Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange))
Library:GiveSignal(Players.PlayerRemoving:Connect(OnPlayerChange))

Library:GiveSignal(Teams.ChildAdded:Connect(OnTeamChange))
Library:GiveSignal(Teams.ChildRemoved:Connect(OnTeamChange))

local RainbowStep = 0
local Hue = 0

Library:GiveSignal(RunService.RenderStepped:Connect(function(Delta)
    if Library.Unloaded then
        return
    end

    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400)

        if Hue > 1 then
            Hue = 0
        end

        Library.CurrentRainbowHue = Hue
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
    end
end))

getgenv().Linoria = Library
if getgenv().skip_getgenv_linoria ~= true then getgenv().Library = Library end
return Library

]=])()
local ThemeManager = loadstring([=[
local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func)
    return func
end)

local httprequest = request or http_request or (http and http.request)
local getassetfunc = getcustomasset

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles;

local assert = function(condition, errorMessage)
    if (not condition) then
        error(if errorMessage then errorMessage else "assert failed", 3)
    end
end

if typeof(clonefunction) == "function" then

    local
        isfolder_copy,
        isfile_copy,
        listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)

    local isfolder_success, isfolder_error = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            if success then return data else return false end
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            if success then return data else return false end
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            if success then return data else return {} end
        end
    end
end

local ThemeManager = {} do
        local ThemeFields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "VideoLink" }
        ThemeManager.Folder = "ZytheraXHub"
        ThemeManager.DefaultTheme = 'Zythera'

        ThemeManager.Library = nil
        ThemeManager.BuiltInThemes = {

                ['Zythera']       = { 1, { FontColor = "f0f0f5", MainColor = "1c1c23", AccentColor = "e11e1e", BackgroundColor = "14141a", OutlineColor = "2d2d34" } },
                ['Zythera Dark']  = { 2, { FontColor = "dcdcdc", MainColor = "14141a", AccentColor = "b51515", BackgroundColor = "0e0e12", OutlineColor = "202028" } },
                ['Fatality']      = { 3, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d" } },
                ['Jester']        = { 4, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
                ['Mint']          = { 5, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
                ['Tokyo Night']   = { 6, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232" } },
                ['Ubuntu']        = { 7, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919" } },
                ['Quartz']        = { 8, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f" } },
        }

        function ApplyBackgroundVideo(videoLink)
                if
                        typeof(videoLink) ~= "string" or
                        not (getassetfunc and writefile and readfile and isfile) or
                        not (ThemeManager.Library and ThemeManager.Library.InnerVideoBackground)
                then return; end;

                local videoInstance = ThemeManager.Library.InnerVideoBackground;
                local extension = videoLink:match(".*/(.-)?") or videoLink:match(".*/(.-)$"); extension = tostring(extension);
                local filename = string.sub(extension, 0, -6);
                local _, domain = videoLink:match("^(https?://)([^/]+)"); domain = tostring(domain);

                if videoLink == "" then
                        videoInstance:Pause();
                        videoInstance.Video = "";
                        videoInstance.Visible = false;
                        return
                end
                if #extension > 5 and string.sub(extension, -5) ~= ".webm" then return; end;

                local videoFile = ThemeManager.Folder .. "/themes/" .. string.gsub(domain .. filename, 0, 249) .. ".webm";
                if not isfile(videoFile) then
                        local success, requestRes = pcall(httprequest, { Url = videoLink, Method = 'GET' })
                        if not (success and typeof(requestRes) == "table" and typeof(requestRes.Body) == "string") then return; end;

                        writefile(videoFile, requestRes.Body)
                end

                videoInstance.Video = getassetfunc(videoFile);
                videoInstance.Visible = true;
                videoInstance:Play();
        end

        function ThemeManager:SetLibrary(library)
                self.Library = library
        end

        function ThemeManager:GetPaths()
            local paths = {}

                local parts = self.Folder:split('/')
                for idx = 1, #parts do
                        paths[#paths + 1] = table.concat(parts, '/', 1, idx)
                end

                paths[#paths + 1] = self.Folder .. '/themes'

                return paths
        end

        function ThemeManager:BuildFolderTree()
                local paths = self:GetPaths()

                for i = 1, #paths do
                        local str = paths[i]
                        if isfolder(str) then continue end
                        makefolder(str)
                end
        end

        function ThemeManager:CheckFolderTree()
                if isfolder(self.Folder) then return end
                self:BuildFolderTree()

                task.wait(0.1)
        end

        function ThemeManager:SetFolder(folder)
                self.Folder = folder;
                self:BuildFolderTree()
        end

        function ThemeManager:ApplyTheme(theme)
                local customThemeData = self:GetCustomTheme(theme)
                local data = customThemeData or self.BuiltInThemes[theme]

                if not data then return end

                if self.Library.InnerVideoBackground ~= nil then
                        self.Library.InnerVideoBackground.Visible = false
                end

                local scheme = data[2]
                for idx, col in next, customThemeData or scheme do
                        if idx == "VideoLink" then
                                self.Library[idx] = col

                                if self.Library.Options[idx] then
                                        self.Library.Options[idx]:SetValue(col)
                                end

                                ApplyBackgroundVideo(col)
                        else
                                self.Library[idx] = Color3.fromHex(col)

                                if self.Library.Options[idx] then
                                        self.Library.Options[idx]:SetValueRGB(Color3.fromHex(col))
                                end
                        end
                end

                self:ThemeUpdate()
        end

        function ThemeManager:ThemeUpdate()

                if self.Library.InnerVideoBackground ~= nil then
                        self.Library.InnerVideoBackground.Visible = false
                end

                for i, field in next, ThemeFields do
                        if self.Library.Options and self.Library.Options[field] then
                                self.Library[field] = self.Library.Options[field].Value

                                if field == "VideoLink" then
                                        ApplyBackgroundVideo(self.Library.Options[field].Value)
                                end
                        end
                end

                self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
                self.Library:UpdateColorsUsingRegistry()
        end

        function ThemeManager:GetCustomTheme(file)
                local path = self.Folder .. '/themes/' .. file .. '.json'
                if not isfile(path) then
                        return nil
                end

                local data = readfile(path)
                local success, decoded = pcall(HttpService.JSONDecode, HttpService, data)

                if not success then
                        return nil
                end

                return decoded
        end

        function ThemeManager:LoadDefault()
                local theme = 'Zythera'
                local content = isfile(self.Folder .. '/themes/default.txt') and readfile(self.Folder .. '/themes/default.txt')

                local isDefault = true
                if content then
                        if self.BuiltInThemes[content] then
                                theme = content
                        elseif self:GetCustomTheme(content) then
                                theme = content
                                isDefault = false;
                        end
                elseif self.BuiltInThemes[self.DefaultTheme] then
                        theme = self.DefaultTheme
                end

                if isDefault then
                        self.Library.Options.ThemeManager_ThemeList:SetValue(theme)
                else
                        self:ApplyTheme(theme)
                end
        end

        function ThemeManager:SaveDefault(theme)
                writefile(self.Folder .. '/themes/default.txt', theme)
        end

        function ThemeManager:SaveCustomTheme(file)
                if file:gsub(' ', '') == '' then
                        self.Library:Notify('Invalid file name for theme (empty)', 3)
                        return
                end

                local theme = {}
                for _, field in next, ThemeFields do
                        if field == "VideoLink" then
                                theme[field] = self.Library.Options[field].Value
                        else
                                theme[field] = self.Library.Options[field].Value:ToHex()
                        end
                end

                writefile(self.Folder .. '/themes/' .. file .. '.json', HttpService:JSONEncode(theme))
        end

        function ThemeManager:Delete(name)
                if (not name) then
                        return false, 'no config file is selected'
                end

                local file = self.Folder .. '/themes/' .. name .. '.json'
                if not isfile(file) then return false, 'invalid file' end

                local success = pcall(delfile, file)
                if not success then return false, 'delete file error' end

                return true
        end

        function ThemeManager:ReloadCustomThemes()
                local list = listfiles(self.Folder .. '/themes')

                local out = {}
                for i = 1, #list do
                        local file = list[i]
                        if file:sub(-5) == '.json' then

                                local pos = file:find('.json', 1, true)
                                local start = pos

                                local char = file:sub(pos, pos)
                                while char ~= '/' and char ~= '\\' and char ~= '' do
                                        pos = pos - 1
                                        char = file:sub(pos, pos)
                                end

                                if char == '/' or char == '\\' then
                                        table.insert(out, file:sub(pos + 1, start - 1))
                                end
                        end
                end

                return out
        end

        function ThemeManager:CreateThemeManager(groupbox)
                groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor });
                groupbox:AddLabel('Main color') :AddColorPicker('MainColor', { Default = self.Library.MainColor });
                groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor });
                groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor });
                groupbox:AddLabel('Font color') :AddColorPicker('FontColor', { Default = self.Library.FontColor });
                groupbox:AddInput('VideoLink', { Text = '.webm Video Background (Link)', Default = self.Library.VideoLink });

                local ThemesArray = {}
                for Name, Theme in next, self.BuiltInThemes do
                        table.insert(ThemesArray, Name)
                end

                table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

                groupbox:AddDivider()

                groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })
                groupbox:AddButton('Set as default', function()
                        self:SaveDefault(self.Library.Options.ThemeManager_ThemeList.Value)
                        self.Library:Notify(string.format('Set default theme to %q', self.Library.Options.ThemeManager_ThemeList.Value))
                end)

                self.Library.Options.ThemeManager_ThemeList:OnChanged(function()
                        self:ApplyTheme(self.Library.Options.ThemeManager_ThemeList.Value)
                end)

                groupbox:AddDivider()

                groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
                groupbox:AddButton('Create theme', function()
                        local name = self.Library.Options.ThemeManager_CustomThemeName.Value
                        if name:gsub(" ", "") == "" then
                self.Library:Notify("Invalid theme name (empty)", 2)
                return
            end

            self:SaveCustomTheme(name)

            self.Library:Notify(string.format("Created theme %q", name))
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)

                groupbox:AddDivider()

                groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })
                groupbox:AddButton('Load theme', function()
                        local name = self.Library.Options.ThemeManager_CustomThemeList.Value

                        self:ApplyTheme(name)
                        self.Library:Notify(string.format('Loaded theme %q', name))
                end)
                groupbox:AddButton('Overwrite theme', function()
                        local name = self.Library.Options.ThemeManager_CustomThemeList.Value

                        self:SaveCustomTheme(name)
                        self.Library:Notify(string.format('Overwrote config %q', name))
                end)
                groupbox:AddButton('Delete theme', function()
                        local name = self.Library.Options.ThemeManager_CustomThemeList.Value

                        local success, err = self:Delete(name)
                        if not success then
                                self.Library:Notify('Failed to delete theme: ' .. err)
                                return
                        end

                        self.Library:Notify(string.format('Deleted theme %q', name))
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)
                groupbox:AddButton('Refresh list', function()
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)
                groupbox:AddButton('Set as default', function()
                        if self.Library.Options.ThemeManager_CustomThemeList.Value ~= nil and self.Library.Options.ThemeManager_CustomThemeList.Value ~= '' then
                                self:SaveDefault(self.Library.Options.ThemeManager_CustomThemeList.Value)
                                self.Library:Notify(string.format('Set default theme to %q', self.Library.Options.ThemeManager_CustomThemeList.Value))
                        end
                end)
                groupbox:AddButton('Reset default', function()
                        local success = pcall(delfile, self.Folder .. '/themes/default.txt')
                        if not success then
                                self.Library:Notify('Failed to reset default: delete file error')
                                return
                        end

                        self.Library:Notify('Set default theme to nothing')
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)

                self:LoadDefault()

                local function UpdateTheme() self:ThemeUpdate() end
                self.Library.Options.BackgroundColor:OnChanged(UpdateTheme)
                self.Library.Options.MainColor:OnChanged(UpdateTheme)
                self.Library.Options.AccentColor:OnChanged(UpdateTheme)
                self.Library.Options.OutlineColor:OnChanged(UpdateTheme)
                self.Library.Options.FontColor:OnChanged(UpdateTheme)
        end

        function ThemeManager:CreateGroupBox(tab)
                assert(self.Library, 'ThemeManager:CreateGroupBox -> Must set ThemeManager.Library first!')
                return tab:AddLeftGroupbox('Themes')
        end

        function ThemeManager:ApplyToTab(tab)
                assert(self.Library, 'ThemeManager:ApplyToTab -> Must set ThemeManager.Library first!')
                local groupbox = self:CreateGroupBox(tab)
                self:CreateThemeManager(groupbox)
        end

        function ThemeManager:ApplyToGroupbox(groupbox)
                assert(self.Library, 'ThemeManager:ApplyToGroupbox -> Must set ThemeManager.Library first!')
                self:CreateThemeManager(groupbox)
        end

        ThemeManager:BuildFolderTree()
end

getgenv().LinoriaThemeManager = ThemeManager
return ThemeManager
]=])()
local SaveManager = loadstring([=[
local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func)
    return func
end)

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles;

local assert = function(condition, errorMessage)
    if (not condition) then
        error(if errorMessage then errorMessage else "assert failed", 3)
    end
end

if typeof(clonefunction) == "function" then

    local
        isfolder_copy,
        isfile_copy,
        listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)

    local isfolder_success, isfolder_error = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            if success then return data else return false end
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            if success then return data else return false end
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            if success then return data else return {} end
        end
    end
end

local SaveManager = {} do
    SaveManager.Folder = "LinoriaLibSettings"
    SaveManager.SubFolder = ""
    SaveManager.Ignore = {}
    SaveManager.Library = nil
    SaveManager.UseLoadingOrder = false
    SaveManager.LoadingOrder = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = 'Toggle', idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Toggles[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = 'Slider', idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        ColorPicker = {
            Save = function(idx, object)
                return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value, modifiers = object.Modifiers }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValue({ data.key, data.mode, data.modifiers })
                end
            end,
        },
        Input = {
            Save = function(idx, object)
                return { type = 'Input', idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.text and type(data.text) == 'string' then
                    SaveManager.Library.Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    function SaveManager:SetLoadingOrder(enabled, order)
        self.UseLoadingOrder = enabled

        if typeof(order) == "table" then
            self.LoadingOrder = order
        end
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
            "ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
            "VideoLink",
        })
    end

    function SaveManager:CheckSubFolder(createFolder)
        if typeof(self.SubFolder) ~= "string" or self.SubFolder == "" then return false end

        if createFolder == true then
            if not isfolder(self.Folder .. "/settings/" .. self.SubFolder) then
                makefolder(self.Folder .. "/settings/" .. self.SubFolder)
            end
        end

        return true
    end

    function SaveManager:GetPaths()
        local paths = {}

        local parts = self.Folder:split('/')
        for idx = 1, #parts do
            local path = table.concat(parts, '/', 1, idx)
            if not table.find(paths, path) then paths[#paths + 1] = path end
        end

        paths[#paths + 1] = self.Folder .. '/themes'
        paths[#paths + 1] = self.Folder .. '/settings'

        if self:CheckSubFolder(false) then
            local subFolder = self.Folder .. "/settings/" .. self.SubFolder
            parts = subFolder:split('/')

            for idx = 1, #parts do
                local path = table.concat(parts, '/', 1, idx)
                if not table.find(paths, path) then paths[#paths + 1] = path end
            end
        end

        return paths
    end

    function SaveManager:BuildFolderTree()
        local paths = self:GetPaths()

        for i = 1, #paths do
            local str = paths[i]
            if isfolder(str) then continue end

            makefolder(str)
        end
    end

    function SaveManager:CheckFolderTree()
        if isfolder(self.Folder) then return end
        SaveManager:BuildFolderTree()

        task.wait(0.1)
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree()
    end

    function SaveManager:SetSubFolder(folder)
        self.SubFolder = folder;
        self:BuildFolderTree()
    end

    function SaveManager:Save(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local fullPath = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            fullPath = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        local data = {
            objects = {}
        }

        for idx, toggle in next, self.Library.Toggles do
            if not toggle.Type then continue end
            if not self.Parser[toggle.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
        end

        for idx, option in next, self.Library.Options do
            if not option.Type then continue end
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end

        local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not success then
            return false, 'failed to encode data'
        end

        writefile(fullPath, encoded)
        return true
    end

    function SaveManager:Load(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
        if not success then return false, 'decode error' end

        if self.UseLoadingOrder == true and typeof(self.LoadingOrder) == "table" then
            table.sort(decoded.objects, function(a, b)
                local aIndex = table.find(self.LoadingOrder, a.type) or math.huge
                local bIndex = table.find(self.LoadingOrder, b.type) or math.huge
                return aIndex < bIndex
            end)
        end

        for _, option in decoded.objects do
            if not option.type then continue end
            if not self.Parser[option.type] then continue end
            if self.Ignore[option.idx] then continue end

            task.spawn(self.Parser[option.type].Load, option.idx, option)
        end

        return true
    end

    function SaveManager:Delete(name)
        if (not name) then
            return false, 'no config file is selected'
        end

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        local success = pcall(delfile, file)
        if not success then return false, 'delete file error' end

        return true
    end

    function SaveManager:RefreshConfigList()
        local success, data = pcall(function()
            SaveManager:CheckFolderTree()

            local list = {}
            local out = {}

            if SaveManager:CheckSubFolder(true) then
                list = listfiles(self.Folder .. "/settings/" .. self.SubFolder)
            else
                list = listfiles(self.Folder .. "/settings")
            end
            if typeof(list) ~= "table" then list = {} end

            for i = 1, #list do
                local file = list[i]
                if file:sub(-5) == '.json' then

                    local pos = file:find('.json', 1, true)
                    local start = pos

                    local char = file:sub(pos, pos)
                    while char ~= '/' and char ~= '\\' and char ~= '' do
                        pos = pos - 1
                        char = file:sub(pos, pos)
                    end

                    if char == '/' or char == '\\' then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end

            return out
        end)

        if (not success) then
            if self.Library then
                self.Library:Notify('Failed to load config list: ' .. tostring(data))
            else
                warn('Failed to load config list: ' .. tostring(data))
            end

            return {}
        end

        return data
    end

    function SaveManager:GetAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                return "none"
            end

            name = tostring(name)
            return if name == "" then "none" else name
        end

        return "none"
    end

    function SaveManager:LoadAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                self.Library:Notify('Failed to load autoload config: write file error')
                return
            end

            local success, err = self:Load(name)
            if not success then
                self.Library:Notify('Failed to load autoload config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Auto loaded config %q', name))
        end
    end

    function SaveManager:SaveAutoloadConfig(name)
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(writefile, autoLoadPath, name)
        if not success then return false, 'write file error' end

        return true, ""
    end

    function SaveManager:DeleteAutoLoadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(delfile, autoLoadPath)
        if not success then return false, 'delete file error' end

        return true, ""
    end

    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, 'SaveManager:BuildConfigSection -> Must set SaveManager.Library')

        local section = tab:AddRightGroupbox('Configuration')

        section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
        section:AddButton('Create config', function()
            local name = self.Library.Options.SaveManager_ConfigName.Value

            if name:gsub(' ', '') == '' then
                self.Library:Notify('Invalid config name (empty)', 2)
                return
            end

            local success, err = self:Save(name)
            if not success then
                self.Library:Notify('Failed to create config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Created config %q', name))

            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddDivider()

        section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })
        section:AddButton('Load config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Load(name)
            if not success then
                self.Library:Notify('Failed to load config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Loaded config %q', name))
        end)
        section:AddButton('Overwrite config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Save(name)
            if not success then
                self.Library:Notify('Failed to overwrite config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Overwrote config %q', name))
        end)

        section:AddButton('Delete config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Delete(name)
            if not success then
                self.Library:Notify('Failed to delete config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Deleted config %q', name))
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Refresh list', function()
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Set as autoload', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:SaveAutoloadConfig(name)
            if not success then
                self.Library:Notify('Failed to set autoload config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Set %q to auto load', name))
            self.AutoloadConfigLabel:SetText('Current autoload config: ' .. name)
        end)
        section:AddButton('Reset autoload', function()
            local success, err = self:DeleteAutoLoadConfig()
            if not success then
                self.Library:Notify('Failed to set autoload config: ' .. err)
                return
            end

            self.Library:Notify('Set autoload to none')
            self.AutoloadConfigLabel:SetText('Current autoload config: none')
        end)

        self.AutoloadConfigLabel = section:AddLabel("Current autoload config: " .. self:GetAutoloadConfig(), true)

        self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
    end

    SaveManager:BuildFolderTree()
end

return SaveManager

]=])()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = true
Library.NotifySide = "Left"

local Window = Library:CreateWindow({
        Title = 'ZytheraX',
        Center = true,
        AutoShow = false,
        Resizable = false,
        ShowCustomCursor = true,
        UnlockMouseWhileOpen = true,
        NotifySide = "Left",
        TabPadding = 8,
        MenuFadeTime = 0.2,

        Size = UDim2.fromOffset(560, 540),
})

do
local LoadingScreenGui = Instance.new("ScreenGui")
LoadingScreenGui.Name = "ZytheraXLoadingScreen"
LoadingScreenGui.IgnoreGuiInset = true
LoadingScreenGui.ResetOnSpawn = false
LoadingScreenGui.DisplayOrder = 9999
LoadingScreenGui.Parent = gethui and gethui() or game:GetService("CoreGui")

local LoadingBg = Instance.new("Frame")
LoadingBg.Name = "Background"
LoadingBg.Size = UDim2.new(1, 0, 1, 0)
LoadingBg.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
LoadingBg.BorderSizePixel = 0
LoadingBg.Parent = LoadingScreenGui

local BgGradient = Instance.new("UIGradient")
BgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 14, 16)),
    ColorSequenceKeypoint.new(0.7, Color3.fromRGB(8, 6, 8)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 2, 3)),
})
BgGradient.Rotation = 0
BgGradient.Parent = LoadingBg

local LoadingContainer = Instance.new("Frame")
LoadingContainer.Name = "Container"
LoadingContainer.Size = UDim2.new(0, 420, 0, 300)
LoadingContainer.Position = UDim2.new(0.5, -210, 0.5, -150)
LoadingContainer.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
LoadingContainer.BorderSizePixel = 0
LoadingContainer.Parent = LoadingBg

local LoadingCorner = Instance.new("UICorner")
LoadingCorner.CornerRadius = UDim.new(0, 10)
LoadingCorner.Parent = LoadingContainer

local LoadingBorder = Instance.new("UIStroke")
LoadingBorder.Color = Color3.fromRGB(35, 28, 30)
LoadingBorder.Thickness = 1
LoadingBorder.Transparency = 0
LoadingBorder.Parent = LoadingContainer

local ZxLogo = Instance.new("TextLabel")
ZxLogo.Name = "ZXLogo"
ZxLogo.Size = UDim2.new(1, 0, 0, 70)
ZxLogo.Position = UDim2.new(0, 0, 0, 30)
ZxLogo.BackgroundTransparency = 1
ZxLogo.Font = Enum.Font.GothamBlack
ZxLogo.TextSize = 58
ZxLogo.TextColor3 = Color3.fromRGB(255, 255, 255)
ZxLogo.Text = 'ZytheraX'
ZxLogo.RichText = true
ZxLogo.Parent = LoadingContainer

local LogoLine = Instance.new("Frame")
LogoLine.Name = "LogoLine"
LogoLine.Size = UDim2.new(0, 40, 0, 2)
LogoLine.Position = UDim2.new(0.5, -20, 0, 110)
LogoLine.BackgroundColor3 = Color3.fromRGB(225, 30, 30)
LogoLine.BorderSizePixel = 0
LogoLine.Parent = LoadingContainer

local LogoLineCorner = Instance.new("UICorner")
LogoLineCorner.CornerRadius = UDim.new(1, 0)
LogoLineCorner.Parent = LogoLine

local LoadingTitle = Instance.new("TextLabel")
LoadingTitle.Name = "Title"
LoadingTitle.Size = UDim2.new(1, 0, 0, 22)
LoadingTitle.Position = UDim2.new(0, 0, 0, 125)
LoadingTitle.BackgroundTransparency = 1
LoadingTitle.Font = Enum.Font.GothamMedium
LoadingTitle.TextSize = 16
LoadingTitle.TextColor3 = Color3.fromRGB(230, 230, 235)
LoadingTitle.Text = "ZytheraX"
LoadingTitle.Parent = LoadingContainer

local LoadingSubtitle = Instance.new("TextLabel")
LoadingSubtitle.Name = "Subtitle"
LoadingSubtitle.Size = UDim2.new(1, 0, 0, 18)
LoadingSubtitle.Position = UDim2.new(0, 0, 0, 155)
LoadingSubtitle.BackgroundTransparency = 1
LoadingSubtitle.Font = Enum.Font.Gotham
LoadingSubtitle.TextSize = 12
LoadingSubtitle.TextColor3 = Color3.fromRGB(120, 120, 130)
LoadingSubtitle.Text = "Initializing..."
LoadingSubtitle.Parent = LoadingContainer

local ProgressBg = Instance.new("Frame")
ProgressBg.Name = "ProgressBg"
ProgressBg.Size = UDim2.new(0, 340, 0, 4)
ProgressBg.Position = UDim2.new(0.5, -170, 0, 195)
ProgressBg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
ProgressBg.BorderSizePixel = 0
ProgressBg.Parent = LoadingContainer

local ProgressCorner = Instance.new("UICorner")
ProgressCorner.CornerRadius = UDim.new(1, 0)
ProgressCorner.Parent = ProgressBg

local ProgressFill = Instance.new("Frame")
ProgressFill.Name = "ProgressFill"
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(225, 30, 30)
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBg
ProgressFill.ClipsDescendants = true

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(1, 0)
FillCorner.Parent = ProgressFill

local ProgressText = Instance.new("TextLabel")
ProgressText.Name = "ProgressText"
ProgressText.Size = UDim2.new(1, 0, 0, 20)
ProgressText.Position = UDim2.new(0, 0, 0, 210)
ProgressText.BackgroundTransparency = 1
ProgressText.Font = Enum.Font.GothamMedium
ProgressText.TextSize = 12
ProgressText.TextColor3 = Color3.fromRGB(180, 180, 190)
ProgressText.Text = "0%"
ProgressText.Parent = LoadingContainer

local HintText = Instance.new("TextLabel")
HintText.Name = "Hint"
HintText.Size = UDim2.new(1, 0, 0, 16)
HintText.Position = UDim2.new(0, 0, 0, 255)
HintText.BackgroundTransparency = 1
HintText.Font = Enum.Font.Gotham
HintText.TextSize = 10
HintText.TextColor3 = Color3.fromRGB(90, 90, 100)
HintText.Text = "use at your own risk"
HintText.Parent = LoadingContainer

local animTime = 0

task.spawn(function()
    while LoadingScreenGui and LoadingScreenGui.Parent do
        animTime = animTime + 0.04

        pcall(function()
            local pulse = (math.sin(animTime * 1.2) + 1) / 2
            ZxLogo.TextTransparency = 0.05 + (pulse * 0.1)
        end)

        pcall(function()
            local breath = (math.sin(animTime * 1.5) + 1) / 2
            LogoLine.Size = UDim2.new(0, 40 + breath * 8, 0, 2)
            LogoLine.Position = UDim2.new(0.5, -20 - breath * 4, 0, 110)
        end)

        task.wait()
    end
end)

local loadingStartTime = tick()
local loadingDuration = 3.0
local loadingSteps = {
    { time = 0.0,  text = "initializing core..." },
    { time = 0.5,  text = "loading modules..." },
    { time = 1.0,  text = "setting up combat..." },
    { time = 1.5,  text = "loading visuals..." },
    { time = 2.0,  text = "applying hooks..." },
    { time = 2.5,  text = "finalizing..." },
}

task.spawn(function()
    local stepIdx = 1
    while true do
        local elapsed = tick() - loadingStartTime
        local progress = math.clamp(elapsed / loadingDuration, 0, 1)

        local easedProgress = 1 - ((1 - progress) ^ 2.5)

        ProgressFill.Size = UDim2.new(easedProgress, 0, 1, 0)
        ProgressText.Text = tostring(math.floor(easedProgress * 100)) .. "%"

        if stepIdx <= #loadingSteps and elapsed >= loadingSteps[stepIdx].time then
            LoadingSubtitle.Text = loadingSteps[stepIdx].text
            stepIdx = stepIdx + 1
        end

        if elapsed >= loadingDuration then
            break
        end
        task.wait(0.04)
    end

    ProgressFill.Size = UDim2.new(1, 0, 1, 0)
    ProgressText.Text = "100%"
    LoadingSubtitle.Text = "ready"
    task.wait(0.35)

    local fadeStart = tick()
    while tick() - fadeStart < 0.5 do
        local alpha = (tick() - fadeStart) / 0.5
        LoadingBg.BackgroundTransparency = alpha
        LoadingContainer.BackgroundTransparency = alpha
        LoadingBorder.Transparency = alpha
        LoadingTitle.TextTransparency = alpha
        LoadingSubtitle.TextTransparency = alpha
        ProgressBg.BackgroundTransparency = alpha
        ProgressFill.BackgroundTransparency = alpha
        ProgressText.TextTransparency = alpha
        HintText.TextTransparency = alpha
        ZxLogo.TextTransparency = alpha
        LogoLine.BackgroundTransparency = alpha
        task.wait()
    end

    LoadingScreenGui:Destroy()

    pcall(function()
        -- Force the window to be centered after loading, regardless of
        -- any saved position that may have been loaded. This fixes the
        -- "window appears top-left on load" issue.
        if LibraryMainOuterFrame then
            local viewport = workspace.CurrentCamera.ViewportSize
            local winSize = LibraryMainOuterFrame.Size
            LibraryMainOuterFrame.Position = UDim2.new(
                0.5, -winSize.X.Offset / 2,
                0.5, -winSize.Y.Offset / 2
            )
        end
        Library:Toggle(true)
    end)
end)
end

task.wait(0.2)

local Tabs = {
        Legit = Window:AddTab("Legit"),
        Rage = Window:AddTab("Rage"),
        ESP = Window:AddTab("ESP"),
        Visuals = Window:AddTab("Visuals"),
        Player = Window:AddTab("Player"),
        World = Window:AddTab("World"),
        Misc = Window:AddTab("Misc"),
        ["UI Settings"] = Window:AddTab("UI Settings"),
}

RageModeGroup = Tabs.Rage:AddLeftGroupbox("Rage Bot")
RageControlGroup = Tabs.Rage:AddRightGroupbox("Rage Bot Settings")
SilentAimGroup = Tabs.Legit:AddLeftGroupbox("Silent Aim")
GunModsAimGroup = Tabs.Legit:AddLeftGroupbox("Gun Mods")
GunModsAmmoGroup = GunModsAimGroup
GunModsMiscGroup = GunModsAimGroup
HoldBotGroup = Tabs.Legit:AddRightGroupbox("Aimbot")
TeamCheckGroup = Tabs.Legit:AddLeftGroupbox("Team Check")
HoldBotTargetGroup = HoldBotGroup
TriggerBotGroup = Tabs.Legit:AddRightGroupbox("Trigger Bot")
OrbitGroup = Tabs.Legit:AddRightGroupbox("Orbit")
StickToTargetGroup = Tabs.Legit:AddRightGroupbox("Stick to Target")
SniperModeGroup = Tabs.Legit:AddLeftGroupbox("Sniper Mode")
AntiAimGroup = Tabs.Legit:AddLeftGroupbox("Anti Aim")
EspGroup = Tabs.ESP:AddLeftGroupbox("ESP Elements")
EspVisualGroup = Tabs.ESP:AddRightGroupbox("Neon Chams")
Esp3DGroup = Tabs.ESP:AddRightGroupbox("3D ESP & Hitbox")
VisualsGroup = Tabs.Visuals:AddLeftGroupbox("Visual Customization")
-- SkyColorGroup transferred to World tab (see below)
GrenadeEffectsGroup = Tabs.Visuals:AddRightGroupbox("Grenade Effects")
WinStreakGroup = Tabs.Visuals:AddRightGroupbox("Chat Win Streak Simulator")

-- ═════════════════════════════════════════════════════════════════
-- WORLD TAB — Atmosphere + Color Correction + Lighting + Sky + World Effects
-- (مأخوذ من Purple Ghost + world-related features من Visuals tab)
-- ═════════════════════════════════════════════════════════════════
WorldAtmosphereGroup     = Tabs.World:AddLeftGroupbox("Atmosphere")
WorldColorCorrectionGroup = Tabs.World:AddRightGroupbox("Color Correction")
WorldLightingGroup       = Tabs.World:AddRightGroupbox("Lighting")
SkyColorGroup            = Tabs.World:AddLeftGroupbox("Sky Color Override")
WorldEffectsGroup        = Tabs.World:AddLeftGroupbox("World Effects")
PlayerMovementGroup = Tabs.Player:AddLeftGroupbox("Movement")
PlayerTogglesGroup = Tabs.Player:AddRightGroupbox("Toggles & Emergency")
PlayerFlyGroup = Tabs.Player:AddRightGroupbox("Fly")
TeleportKillGroup = Tabs.Player:AddLeftGroupbox("Teleport Kill")
PlayerServerGroup = Tabs.Player:AddRightGroupbox("Server")
UnlockAllGroup = Tabs.Misc:AddLeftGroupbox("Unlock All")
MiscGroup = Tabs.Misc:AddLeftGroupbox("Device Spoofer Options")
TeamDebugGroup = Tabs.Misc:AddRightGroupbox("Team Debug")
RewardsGroup = Tabs.Misc:AddRightGroupbox("Rewards & Codes")

task.wait(0.1)

TeamCheck = {
    Enabled = true,
    DebugMode = false,
}

SilentAim = {
    Enabled = false,
    Prediction = 0.10,
    WallCheck = false,
    HitPart = "Head",
    HitCooldown = 0.05,
    HitChance = 100,
    FOV = 150,
    FovVisible = false,
    FovFilled = false,
    FovColor = Color3.fromRGB(255, 255, 255),
    FovRainbow = false,
    MaxDistance = 2000,
    ProjectilePrediction = false,
    _lastHitTime = 0,
}

-- Silent Aim: HitChance controlled by user (0-100%)
-- Sniper/Bow always 100% (slow fire = every shot counts)
-- User controls the rest via slider
local function silentAimShouldHit()
    -- Check if using slow weapon (sniper/bow/crossbow/rpg) = always 100%
    local localPlr = game:GetService("Players").LocalPlayer
    local weaponName = ""
    if localPlr then
        local char = localPlr.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                weaponName = (tool.Name or ""):lower()
            end
        end
    end
    local isSlowWeapon = weaponName:find("sniper") or
        weaponName:find("bow") or
        weaponName:find("crossbow") or
        weaponName:find("rpg") or
        weaponName:find("marksman") or
        weaponName:find("shotgun") or
        false

    if isSlowWeapon then
        return true  -- Sniper/Bow = always 100%
    end

    -- Other weapons = use user's HitChance setting
    if SilentAim.HitChance >= 100 then return true end
    if SilentAim.HitChance <= 0 then return false end
    return math.random(1, 100) <= SilentAim.HitChance
end

-- ═════════════════════════════════════════════════════════════════
-- SMART MOVEMENT PREDICTION SYSTEM
-- Tracks per-player velocity history with smoothing + acceleration
-- compensation for much more accurate, human-like target leading.
-- ═════════════════════════════════════════════════════════════════
getgenv().ZX_VelocityHistory = getgenv().ZX_VelocityHistory or {}
VelocityHistory = getgenv().ZX_VelocityHistory
VELOCITY_SAMPLES = 5  -- number of frames to average
VELOCITY_SAMPLE_INTERVAL = 0.03  -- sample every 30ms

-- Update velocity history for a player's HRP (called from render loop)
local function updateVelocityHistory(player, hrp)
    if not player or not hrp then return end
    local now = tick()
    local entry = VelocityHistory[player]
    if not entry then
        entry = { samples = {}, lastSample = 0, smoothedVel = Vector3.zero, accel = Vector3.zero, lastVel = Vector3.zero }
        VelocityHistory[player] = entry
    end

    -- Sample at fixed interval
    if now - entry.lastSample < VELOCITY_SAMPLE_INTERVAL then return end

    local rawVel = hrp.AssemblyLinearVelocity or Vector3.zero
    if rawVel.Magnitude < 0.01 then rawVel = hrp.Velocity or Vector3.zero end

    -- Compute instantaneous acceleration
    local dt = math.max(now - entry.lastSample, 0.001)
    entry.accel = (rawVel - entry.lastVel) / dt

    -- Push to history
    table.insert(entry.samples, { vel = rawVel, t = now })
    if #entry.samples > VELOCITY_SAMPLES then
        table.remove(entry.samples, 1)
    end

    -- Weighted average (recent samples weighted higher)
    local totalWeight = 0
    local weightedSum = Vector3.zero
    local n = #entry.samples
    for i, s in ipairs(entry.samples) do
        local w = i  -- newer samples (higher index) weighted more
        weightedSum = weightedSum + s.vel * w
        totalWeight = totalWeight + w
    end
    if totalWeight > 0 then
        entry.smoothedVel = weightedSum / totalWeight
    end
    entry.lastVel = rawVel
    entry.lastSample = now
end

-- Get smoothed velocity + acceleration for a player
local function getSmoothedVelocity(player)
    local entry = VelocityHistory[player]
    if not entry then return Vector3.zero, Vector3.zero end
    return entry.smoothedVel or Vector3.zero, entry.accel or Vector3.zero
end

-- Clean up disconnected players
task.spawn(function()
    while true do
        task.wait(5)
        for plr, _ in pairs(VelocityHistory) do
            if not plr.Parent or not plr.Character then
                VelocityHistory[plr] = nil
            end
        end
    end
end)

-- ═════════════════════════════════════════════════════════════════
-- SMART PREDICTION v3 — Pro Accuracy, Cached Ping
-- Improvements:
-- - Cached ping (no per-frame Stats lookup = no lag)
-- - Tighter prediction clamp (0.2s max = less overshoot)
-- - Reduced jitter for better accuracy
-- - Smarter acceleration damping
-- ═════════════════════════════════════════════════════════════════
_predPingCache = 0
_predPingUpdate = 0

local function computeSmartPrediction(targetPos, targetRoot, player, basePredictionTime)
    if not targetRoot then return targetPos end

    local vel, accel = getSmoothedVelocity(player)

    -- Fallback to raw velocity if no history
    if vel.Magnitude < 0.01 then
        vel = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
    end

    local targetSpeed = vel.Magnitude

    -- ── CACHED PING (update every 2s) ──
    local now = tick()
    if now - _predPingUpdate > 2 then
        _predPingUpdate = now
        pcall(function()
            local stats = game:GetService("Stats")
            _predPingCache = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
    end
    local pingComp = (_predPingCache or 0) / 1000

    -- ── ADAPTIVE PREDICTION TIME ──
    -- Slower targets = less prediction (more accurate)
    -- Faster targets = more prediction (lead them)
    local speedFactor = math.min(targetSpeed / 60, 1.2)

    local camPos = camera and camera.CFrame.Position or Vector3.zero
    local dist3D = (targetPos - camPos).Magnitude
    local distFactor = math.clamp(dist3D / 400, 0, 1)

    -- Clamp to 0.2s for accuracy (was 0.25 = too much overshoot)
    local t = math.min(
        basePredictionTime * (0.5 + speedFactor * 0.5) + distFactor * 0.02 + pingComp * 0.3,
        0.2
    )

    -- ── LINEAR PREDICTION ──
    local predicted = targetPos + vel * t

    -- ── ACCELERATION COMPENSATION (only for fast targets, damped) ──
    if accel.Magnitude > 10 and targetSpeed > 5 then
        local accelDamp = math.clamp(1 - (targetSpeed / 120), 0.3, 0.5)
        predicted = predicted + accel * 0.5 * t * t * accelDamp
    end

    -- ── GRAVITY COMPENSATION (only for jumping targets) ──
    local yVel = vel.Y
    if math.abs(yVel) > 5 then
        local g = workspace.Gravity
        local gravityDamp = 0.4 + distFactor * 0.2
        predicted = predicted + Vector3.new(0, -g * t * t * gravityDamp * 0.35, 0)
    end

    -- ── MINIMAL JITTER (pro = accurate) ──
    local jitterAmount = math.clamp(0.02 - distFactor * 0.015, 0.005, 0.02)
    local jitter = Vector3.new(
        (math.random() - 0.5) * jitterAmount,
        (math.random() - 0.5) * jitterAmount * 0.5,
        (math.random() - 0.5) * jitterAmount
    )
    predicted = predicted + jitter

    return predicted
end

TriggerBot = {
    Enabled = false,
    Delay = 0.05,
    WallCheck = true,
    Keybind = false,
    LastDetected = 0,
}

-- Sniper Mode: ADS -> wait -> fire -> release ADS
-- Activates only when a target is inside a small FOV threshold,
-- simulating a real sniper shot. Useful for sniper rifles in Rivals.
SniperMode = {
    Enabled = false,
    Threshold = 40,        -- target must be within this many pixels of crosshair
    Delay = 0.23,          -- ADS delay before firing (seconds)
    Cooldown = 0.85,       -- wait after firing before next shot
    LastShot = 0,          -- timestamp of last shot
    IsFiring = false,      -- currently in the ADS-fire sequence
}

-- P100 ANTI-AIM SYSTEM (Enhanced Lookdown + Multi-layer)
-- Modes: Lookdown (Camera + Neck C0) + Jitter + Desync
-- This manipulates the character's Neck Motor6D C0 and HumanoidRootPart CFrame
-- to make enemy aimbots miss.
AntiAim = {
    Enabled = false,
    Pitch = 85,              -- degrees (0=forward, 85=look down, 180=back)
    Yaw = 0,                 -- degrees (0=forward, 90=right, 180=back, -90=left)
    _conn1 = nil,
    _conn2 = nil,
    _conn3 = nil,
}

EspSettings = {
    EspBoxes = false,
    EspFilledBoxes = false,
    EspLines = false,
    EspHealth = false,
    EspNames = false,
    EspDistance = false,
    EspChams = false,
    EspSkeleton = false,
    EspGlowChams = false,
    EspEnemyWeapons = false,
    EspColorMode = "Blue",
    EspFilledColorMode = "Blue",
    EspChamsColorMode = "Cyan",
    EspGlowColorMode = "Cyan",
    MaxEspDistance = 400,
    BoxThickness = 1.5,
    LineThickness = 1.0,
    BoxSizeMultiplier = 1300,
    ChamsBrightness = 5.0,
    GlowBrightness = 3.0,
    FilledBoxTransparency = 0.4,
    HeadScale = 1.0,
    TeamCheckESP = false,
    ArrowESP = false,
    _arrows = {},
    -- Highlight Pulse (ported from deobfuscated script — sine-wave transparency)
    HighlightPulse = false,
    HighlightPulseSpeed = 1.0,
    HighlightPulseRange = 0.4,
    -- Corner Box ESP (4-corner brackets instead of full box)
    EspCornerBox = false,
}

-- AutoShoot settings (ported from deobfuscated Midnight script)
AutoShootSettings = {
    Enabled = false,
    Radius = 100,              -- pixel radius around crosshair
    AntiFriendlyFire = true,
    RequireVisible = true,
    HitPart = "Head",          -- which part to aim at
    BurstCount = 3,            -- shots per burst
    BurstDelay = 0.05,         -- delay between burst shots (seconds)
    Cooldown = 0.2,            -- cooldown between bursts (seconds)
    _lastFire = 0,
    _conn = nil,
    _lastTarget = nil,
    _currentAimPos = nil,
    _burstShotsLeft = 0,       -- remaining shots in current burst
    _lastBurstTime = 0,        -- when the last burst started
}

VisualSettings = {
    CrosshairEnabled = false,
    CrosshairColorMode = "Purple",
    HideSmoke = false,
    HideFlashbang = false,
    LockIndicator = false,

    SkyColorEnabled = false,
    AmbientColor = Color3.fromRGB(80, 80, 100),
    SkyBrightness = 1.5,
    SkyClockTime = 12,

    -- Advanced Bullet Tracer with Trail effect (Neon Part + Trail)
    BulletTracerEnabled = false,
    BulletTracerColorName = "Toothpaste",
    BulletTracerLifetime = 10,
    BulletTracerSpeed = 600,

    -- Weapon Latex (ForceField material on viewmodel arms)
    WeaponLatexEnabled = false,

    -- Arm Latex (ForceField on arms specifically)
    ArmLatexEnabled = false,

    -- Bloom Effect Controls
    BloomEnabled = false,
    BloomIntensity = 20,

    -- Thirdperson Mode
    ThirdpersonEnabled = false,
    ThirdpersonDistance = 12,
    ThirdpersonActivation = "Always on",  -- Always on / K / O / P

    -- FOV Override (gameplay FOV, not UI)
    FOVOverrideEnabled = false,
    FOVOverrideValue = 120,

    -- World Visual Effects
    WorldColorEnabled = false,
    WorldColorName = "white",
    FogEnabled = false,
    FogColorName = "white",
    FogDistance = 1000,
    WeatherType = "None",  -- None / Rain / Snow
    NightModeEnabled = false,
}

-- World color presets (for Ambient + Fog)
WORLD_COLOR_PRESETS = {
    ["red"] = Color3.fromRGB(255, 0, 0),
    ["orange"] = Color3.fromRGB(255, 165, 0),
    ["yellow"] = Color3.fromRGB(255, 255, 0),
    ["green"] = Color3.fromRGB(0, 255, 0),
    ["skyblue"] = Color3.fromRGB(135, 206, 235),
    ["blue"] = Color3.fromRGB(0, 0, 255),
    ["violet"] = Color3.fromRGB(238, 130, 238),
    ["pink"] = Color3.fromRGB(255, 192, 203),
    ["white"] = Color3.fromRGB(255, 255, 255),
    ["brown"] = Color3.fromRGB(139, 69, 19),
}

-- Bullet Tracer color presets
BULLET_TRACER_COLORS = {
    ["Red"] = Color3.fromRGB(255, 0, 0),
    ["Green"] = Color3.fromRGB(0, 255, 0),
    ["Pink"] = Color3.fromRGB(255, 50, 255),
    ["Toothpaste"] = Color3.fromRGB(72, 176, 243),
    ["White"] = Color3.fromRGB(255, 223, 255),
}

MiscSettings = {
    SpoofEnabled = false,
    SelectedDevice = "Controller",
    TargetPlayer = "ABG",
    StreakValue = "14",
    AutoFindMe = true,
    CustomEnderName = "Dallas",
}

GunMods = {
    MasterEnabled = false,
    NoRecoil = false,
    NoSpread = false,
    RapidFire = false,
    FireRateMultiplier = 1.0,
    ZeroSpreadIL = false,
    ZeroRecoilIL = false,
    OneShot = false,
    InfiniteAmmo = false,
    InstantReload = false,
    InstantEquip = false,
    NoBulletDrop = false,
    MaxPierce = false,
    NoCooldowns = false,
}

RageMode = {
    Enabled = false,
    AimStyle = "Visible",
    AimSpeed = 0.18,
    Wallbang = false,
    WallCheck = false,
    AutoWinEnabled = false,
    UseKeybind = true,
    UseFOV = false,
    FOV = 250,
    MaxDistance = math.huge,
    HeadshotRate = 100,
    HitPart = "Head",
    ShowTracer = true,
    TracerStart = "Cursor",
    TracerColor = Color3.fromRGB(255, 50, 50),
    TracerThickness = 1,
    ShowAmmoLine = false,
    HideWhileReloading = false,
    ShowStatusDisplay = true,
    ClickSpeed = 0.015,
    FovVisible = false,
    FovFilled = false,
    FovColor = Color3.fromRGB(255, 0, 0),
    FovRainbow = false,
    SpamLock = false,
    RageModeRMB = false,
    AutoShot = true,
}

HoldBot = {
    Enabled = false,
    UseKeybind = true,
    UseSmoothing = false,
    SmoothingValue = 3,
    Prediction = false,
    PersistentTarget = false,
    TargetBehindWalls = false,
    UseTargetZone = false,
    TargetZoneDistance = 1500,
    FOV = 250,
    FovVisible = false,
    FovFilled = false,
    FovColorMode = "Cyan",
    FovColor = Color3.fromRGB(0, 255, 255),
    FovRainbow = false,
    MaxDistance = 2000,
    HitPart = "Head",

    ReactionTime = 0.25,
    _lastTargetSwitch = 0,
}


PlayerSettings = {
    InfiniteJump = false,
    PanicKeyEnabled = false,
    JumpPowerEnabled = false,
    JumpPower = 50,
    WalkSpeedEnabled = false,
    WalkSpeed = 50,
    NoclipEnabled = false,
    AirWalkEnabled = false,
    SlideBoost = false,
    SlideBoostPower = 4,
    FlyEnabled = false,
    FlySpeed = 80,
    FullbrightEnabled = false,
    AntiRagdollEnabled = false,
    AntiAfkEnabled = false,
    GravityValue = 196,

    AutoBhop = false,

    CustomFOV = false,
    FOVValue = 90,

    ShowFPS = false,

    OrbitEnabled = false,
    OrbitRadius = 8,
    OrbitSpeed = 3,
    OrbitHeight = 3,
    OrbitMaxDistance = 400,

    -- Stick to Target: يلصق اللاعب بالـ target ويتحرك معاه
    StickToTargetEnabled = false,
    StickUseSmooth = false,
    StickSmoothness = 50,        -- 0-100 (0=instant, 100=very smooth)
    StickBeneathPlayer = false,  -- يلصق تحت الـ target بدل جنبه
    StickMaxDistance = 400,

    -- Auto Walk: walks toward current aim target automatically
    AutoWalkEnabled = false,
    AutoWalkMethod = "Normal",  -- Normal / Strafing / Jumping / JumpStrafe / Flanking

    -- Air Strafe: allows air movement control (bhop-style).
    -- Adjusts HRP velocity based on MoveDirection when in the air.
    AirStrafeEnabled = false,
    AirStrafeStrength = 20,

    -- Auto Jump: jumps automatically when touching the ground.
    -- Great for keeping momentum in bhop-style movement.
    AutoJumpEnabled = false,

    -- Circle Strafe: boosts horizontal velocity when A/D pressed on ground.
    -- Great for strafe jumping.
    CircleStrafeEnabled = false,

    -- Quick Stop: zeroes horizontal velocity when standing still, to
    -- prevent unwanted sliding.
    QuickStopEnabled = false,
}

orbitState = {
    currentAngle = 0,
    currentTarget = nil,
}

-- Critical service references (kept in main scope — needed everywhere)
local lp = player
local camera = workspace.CurrentCamera
local rs = RunService
local ts = TweenService
local uis = UserInputService
local Lighting = game:GetService("Lighting")

-- ═════════════════════════════════════════════════════════════════
-- ANTI-BAN PROTECTION (Rivals new security update bypass)
-- Blocks weak table creation from anti-cheat controllers
-- Also blocks Kick on LocalPlayer
-- ═════════════════════════════════════════════════════════════════
do
    local oldKick = lp.Kick
    local mtHook
    mtHook = hookfunction(getrenv().setmetatable, newcclosure(function(t, mt)
        if mt and type(mt) == "table" and rawget(mt, "__mode") then
            local mode = rawget(mt, "__mode")
            if mode == "kv" or mode == "v" or mode == "k" then
                if debug.traceback():find("MiscellaneousController") or debug.traceback():find("CameraSecurity") or debug.traceback():find("AnalyticsPipelineController") then
                    return mtHook({1,2,3}, {})
                end
            end
        end
        return mtHook(t, mt)
    end))
    hookfunction(oldKick, newcclosure(function(self, ...)
        if self == lp then return end
        return oldKick(self, ...)
    end))
end

local isTeammateOrbit = nil

local function findNearestEnemy()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local nearestDist = math.huge
    local nearestPlr = nil

    local maxDist = PlayerSettings.OrbitMaxDistance or 400
    for _, plr in pairs(players:GetPlayers()) do
        if plr ~= player and plr.Character then

            if isTeammateOrbit and isTeammateOrbit(plr) then continue end
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and tHum and tHum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude

                if dist <= maxDist and dist < nearestDist then
                    nearestDist = dist
                    nearestPlr = plr
                end
            end
        end
    end
    return nearestPlr
end

local function orbitStep(deltaTime)
    if not PlayerSettings.OrbitEnabled then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    local target = findNearestEnemy()
    orbitState.currentTarget = target
    if not target or not target.Character then return end
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    if not tRoot or not tHum or tHum.Health <= 0 then return end

    if hum and hum.AutoRotate then
        pcall(function() hum.AutoRotate = false end)
    end

    orbitState.currentAngle = orbitState.currentAngle + (PlayerSettings.OrbitSpeed * deltaTime)

    local targetPos = tRoot.Position
    local radius = PlayerSettings.OrbitRadius
    local height = PlayerSettings.OrbitHeight
    local offsetX = math.cos(orbitState.currentAngle) * radius
    local offsetZ = math.sin(orbitState.currentAngle) * radius
    local newPos = Vector3.new(targetPos.X + offsetX, targetPos.Y + height, targetPos.Z + offsetZ)
    local lookAt = targetPos + Vector3.new(0, height, 0)

    pcall(function()
        root.CFrame = CFrame.new(newPos, lookAt)

        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
end

rsOrbit = cloneref(game:GetService("RunService"))
rsOrbit.Stepped:Connect(function(_, deltaTime)
    pcall(orbitStep, deltaTime)
end)

RunService.Heartbeat:Connect(function()
    if not PlayerSettings.OrbitEnabled then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and not hum.AutoRotate then
                pcall(function() hum.AutoRotate = true end)
            end
        end
    end
end)

-- ═════════════════════════════════════════════════════════════════
-- STICK TO TARGET — يلصق اللاعب بالـ target ويتحرك معاه
-- ═════════════════════════════════════════════════════════════════
stickState = {
    currentTarget = nil,
    lastTargetPos = nil,
}

local function findStickTarget()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local nearestDist = math.huge
    local nearestPlr = nil
    local maxDist = PlayerSettings.StickMaxDistance or 400

    for _, plr in pairs(players:GetPlayers()) do
        if plr ~= player and plr.Character then
            if isTeammateOrbit and isTeammateOrbit(plr) then continue end
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and tHum and tHum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude
                if dist <= maxDist and dist < nearestDist then
                    nearestDist = dist
                    nearestPlr = plr
                end
            end
        end
    end
    return nearestPlr
end

local function stickStep(deltaTime)
    if not PlayerSettings.StickToTargetEnabled then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    local target = findStickTarget()
    stickState.currentTarget = target
    if not target or not target.Character then return end
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    if not tRoot or not tHum or tHum.Health <= 0 then return end

    -- queda لـ target position
    local targetPos = tRoot.Position

    -- لو Stick Beneath Player = true → يلصق تحت الـ target
    local stickPos
    if PlayerSettings.StickBeneathPlayer then
        stickPos = targetPos - Vector3.new(0, tRoot.Size.Y / 2 + root.Size.Y / 2 + 0.5, 0)
    else
        -- يلصق جنب الـ target (نفس المكان تقريباً)
        stickPos = targetPos
    end

    -- بني الـ CFrame بحيث نبص على الـ target
    local lookAt = targetPos
    local targetCFrame = CFrame.new(stickPos, lookAt)

    pcall(function()
        if PlayerSettings.StickUseSmooth then
            -- Smooth sticking: lerp بين الموقع الحالي والموقع المطلوب
            -- الـ smoothness (0-100) بيتحول لـ alpha (0-1)
            -- 0 = instant, 100 = very slow/smooth
            local alpha = 1.0 - (PlayerSettings.StickSmoothness / 100)
            alpha = math.clamp(alpha, 0.01, 1.0)
            -- استخدم frame-rate independent lerp
            local smoothAlpha = 1.0 - math.pow(1.0 - alpha, deltaTime * 60)
            root.CFrame = root.CFrame:Lerp(targetCFrame, smoothAlpha)
        else
            -- Instant sticking
            root.CFrame = targetCFrame
        end

        -- وقّف الـ velocity عشان ما يحصلش sliding
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)

    -- وقّف AutoRotate عشان اللاعب يفضل باصص على الـ target
    if hum and hum.AutoRotate then
        pcall(function() hum.AutoRotate = false end)
    end

    stickState.lastTargetPos = targetPos
end

rsStick = cloneref(game:GetService("RunService"))
rsStick.Stepped:Connect(function(_, deltaTime)
    pcall(stickStep, deltaTime)
end)

-- لو الـ stick متعطل → رجّع AutoRotate
RunService.Heartbeat:Connect(function()
    if not PlayerSettings.StickToTargetEnabled then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and not hum.AutoRotate then
                pcall(function() hum.AutoRotate = true end)
            end
        end
    end
end)

TeleportKillSettings = {
    Enabled = false,
    TargetPlayerName = "",
    Distance = 3,
    AutoReconnect = true,
}
tpKillConnection = nil
tpKillTarget = nil

DeviceMapping = {
    ["PC"] = "MouseKeyboard",
    ["Controller"] = "Gamepad",
    ["Mobile"] = "Touch",
    ["VR"] = "VR"
}

uis.JumpRequest:Connect(function()
    if PlayerSettings.InfiniteJump then
        local char = lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            -- LinearVelocity boost (from Saint Hub — gives height control)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local lv = Instance.new("LinearVelocity")
                lv.MaxForce = math.huge
                lv.VectorVelocity = Vector3.new(
                    hrp.AssemblyLinearVelocity.X,
                    PlayerSettings.JumpPower or 50,
                    hrp.AssemblyLinearVelocity.Z
                )
                lv.RelativeTo = Enum.ActuatorRelativeTo.World
                lv.Parent = hrp
                task.delay(0.1, function()
                    if lv and lv.Parent then lv:Destroy() end
                end)
            end
        end
    end
end)

RunService.Stepped:Connect(function()
    if PlayerSettings.AutoBhop then
        local char = lp.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and uis:IsKeyDown(Enum.KeyCode.Space) then
                hum.Jump = true
            end
        end
    end
end)

-- Air Strafe + Auto Jump + Circle Strafe + Quick Stop
-- All movement features run on RenderStepped at Character priority for
-- smooth feel.
RunService:BindToRenderStep("ZytheraXAirMovement", Enum.RenderPriority.Character.Value, function()
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    -- Auto Jump: when enabled, jumps automatically on landing
    if PlayerSettings.AutoJumpEnabled and hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    -- Air Strafe: when enabled and in the air, redirect velocity based
    -- on the player's MoveDirection. This allows bhop-style air control.
    if PlayerSettings.AirStrafeEnabled and hum.FloorMaterial == Enum.Material.Air then
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            root.Velocity = Vector3.new(
                moveDir.X * PlayerSettings.AirStrafeStrength,
                root.Velocity.Y,  -- preserve Y velocity (gravity/jump)
                moveDir.Z * PlayerSettings.AirStrafeStrength
            )
        end
    end

    -- Circle Strafe: when on ground and A/D pressed, boost horizontal
    -- velocity using WalkSpeed. Great for strafe jumping.
    if PlayerSettings.CircleStrafeEnabled and hum.FloorMaterial ~= Enum.Material.Air then
        local strafeVec = Vector3.new()
        if uis:IsKeyDown(Enum.KeyCode.A) then
            strafeVec = strafeVec + Vector3.new(-1, 0, 0)
        end
        if uis:IsKeyDown(Enum.KeyCode.D) then
            strafeVec = strafeVec + Vector3.new(1, 0, 0)
        end
        if strafeVec.Magnitude > 0 then
            root.Velocity = Vector3.new(
                strafeVec.X * hum.WalkSpeed,
                root.Velocity.Y,
                strafeVec.Z * hum.WalkSpeed
            )
        end
    end

    -- Quick Stop: if horizontal velocity is tiny and the player isn't
    -- moving, zero out horizontal velocity to prevent unwanted sliding.
    if PlayerSettings.QuickStopEnabled then
        local vel = root.Velocity
        if Vector3.new(vel.X, 0, vel.Z).Magnitude < 0.1 and hum.MoveDirection.Magnitude == 0 then
            root.Velocity = Vector3.new(0, vel.Y, 0)
        end
    end
end)

-- ============================================================
-- ANTI-AIM SYSTEM — P100 Lookdown (Camera + Neck) + Yaw
-- ============================================================
do
    local function findNeckMotor(char)
        if not char then return nil end
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("Motor6D") then
                local name = string.lower(v.Name or "")
                if name == "neck" or name == "neck0" or name:find("neck") then
                    return v
                end
            end
        end
        return nil
    end

    local _neckMotor = nil
    local _neckOrigC0 = nil

    local function hookCharacter(char)
        if not char then return end
        _neckMotor = findNeckMotor(char)
        if _neckMotor then
            _neckOrigC0 = _neckMotor.C0
        end
    end

    if lp.Character then
        hookCharacter(lp.Character)
    end
    lp.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        hookCharacter(char)
    end)

    local function applyAntiAim()
        pcall(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local pos = cam.CFrame.Position

            -- LAYER 1: Camera Lookdown (P100 style)
            -- Pitch controls how much down we look
            local pitchAmount = AntiAim.Pitch / 90  -- 0 to 1 (0=forward, 1=full down)
            local lookDir = Vector3.new(0, -pitchAmount, -0.01)
            cam.CFrame = CFrame.new(pos, pos + lookDir)

            -- LAYER 2: Neck C0 Lookdown (makes head hitbox point at ground)
            if _neckMotor and _neckMotor.Parent and _neckOrigC0 then
                local pitchRad = math.rad(AntiAim.Pitch)
                local yawRad = math.rad(AntiAim.Yaw)
                local rotation = CFrame.Angles(pitchRad, yawRad, 0)
                _neckMotor.C0 = _neckOrigC0 * rotation
            end

            -- LAYER 3: Yaw — apply to HumanoidRootPart (rotates character)
            if AntiAim.Yaw ~= 0 then
                local char = lp.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum then
                        hum.AutoRotate = false
                        local yawRad = math.rad(AntiAim.Yaw)
                        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yawRad, 0)
                    end
                end
            end
        end)
    end

    AntiAim._conn1 = RunService.Heartbeat:Connect(function()
        if AntiAim.Enabled then applyAntiAim() end
    end)
    AntiAim._conn2 = RunService.Stepped:Connect(function()
        if AntiAim.Enabled then applyAntiAim() end
    end)
    AntiAim._conn3 = RunService.RenderStepped:Connect(function()
        if AntiAim.Enabled then applyAntiAim() end
    end)

    getgenv().ZX_AntiAim = {
        restore = function()
            if _neckMotor and _neckMotor.Parent and _neckOrigC0 then
                pcall(function()
                    _neckMotor.C0 = _neckOrigC0
                end)
            end
            pcall(function()
                local char = lp.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.AutoRotate = true end
                end
            end)
        end,
    }
end

-- ============================================================
-- ADVANCED AUTO-SHOOT (ported from deobfuscated Midnight script)
-- Finds the nearest enemy within a pixel radius around the crosshair,
-- does a raycast wall check, then fires (mouse1press + mouse1release).
-- Separate from AutoWin — this is a standalone triggerbot-like feature.
-- ============================================================
do
    -- Raycast wall check: returns true if target's Head is visible from camera
    -- Uses the same wall check as get_best_target (the working one)
    local function isVisible(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return false end
        local head = targetPlayer.Character:FindFirstChild("Head")
        if not head then return false end
        local cam = workspace.CurrentCamera
        if not cam then return false end
        local camPos = cam.CFrame.Position
        local headPos = head.Position
        local direction = headPos - camPos

        local filterList = { lp.Character }
        for _, otherPlr in ipairs(GetCachedPlayers()) do
            if otherPlr ~= lp and otherPlr ~= targetPlayer and otherPlr.Character then
                filterList[#filterList + 1] = otherPlr.Character
            end
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = filterList
        rayParams.IgnoreWater = true
        rayParams.RespectCanCollide = true

        local result = workspace:Raycast(camPos, direction, rayParams)
        if result and result.Instance and result.Instance:IsA("BasePart") then
            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
            if hitChar ~= targetPlayer.Character then
                local inst = result.Instance
                if inst.CanCollide or inst.Transparency < 1 then
                    return false
                end
            end
        end
        return true
    end

    -- ============================================================
    -- SMART AUTO-SHOOT — Uses get_best_target + mousemoverel for aiming
    -- Instead of blindly clicking, this system:
    -- 1. Finds the best target using the SAME get_best_target logic as aimbot
    -- 2. Smoothly moves the mouse toward the target using mousemoverel
    -- 3. Fires when crosshair is close enough to the target's hitbox
    -- 4. Has configurable trigger delay (simulates human reaction time)
    -- ============================================================

    -- Find the best target using the SAME logic as get_best_target
    -- but with a smaller FOV for the trigger radius
    local function findSmartTarget()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local camPos = cam.CFrame.Position
        local center = uis:GetMouseLocation()
        local radius = AutoShootSettings.Radius
        local best = nil
        local shortestDist = math.huge
        local playerList = GetCachedPlayers()

        local HIT_PARTS = {"HitboxHead", "PhysicalHitboxHead", "Head", "UpperTorso", "HumanoidRootPart"}

        for _, p in ipairs(playerList) do
            if p ~= lp and p.Character then
                if AutoShootSettings.AntiFriendlyFire and isTeammate(p) then
                    -- skip
                else
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        -- Find the hit part
                        local hitPart = nil
                        for _, partName in ipairs(HIT_PARTS) do
                            hitPart = p.Character:FindFirstChild(partName)
                            if hitPart and hitPart:IsA("BasePart") then break end
                        end
                        if hitPart then
                            local partPos = hitPart.Position
                            local pos, onScreen = cam:WorldToViewportPoint(partPos)
                            if onScreen and pos.Z > 0 then
                                local dx = pos.X - center.X
                                local dy = pos.Y - center.Y
                                local dist = math.sqrt(dx * dx + dy * dy)
                                if dist < radius and dist < shortestDist then
                                    -- Wall check — ONLY when RequireVisible is ON
                                    local isVisible = true
                                    if AutoShootSettings.RequireVisible then
                                        local direction = partPos - camPos
                                        local filterList = { lp.Character }
                                        for _, otherPlr in ipairs(playerList) do
                                            if otherPlr ~= lp and otherPlr ~= p and otherPlr.Character then
                                                filterList[#filterList + 1] = otherPlr.Character
                                            end
                                        end
                                        local rayParams = RaycastParams.new()
                                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                                        rayParams.FilterDescendantsInstances = filterList
                                        rayParams.IgnoreWater = true
                                        rayParams.RespectCanCollide = true
                                        local result = workspace:Raycast(camPos, direction, rayParams)
                                        if result and result.Instance and result.Instance:IsA("BasePart") then
                                            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                                            if hitChar ~= p.Character then
                                                -- Hit something that's NOT the target = wall
                                                isVisible = false
                                            end
                                        end
                                    end
                                    if isVisible then
                                        shortestDist = dist
                                        best = { player = p, part = hitPart, screenPos = Vector2.new(pos.X, pos.Y), dist = dist }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    -- Start AutoShoot — smart mouse aiming + trigger
    local function startAutoShoot()
        if AutoShootSettings._conn then
            AutoShootSettings._conn:Disconnect()
            AutoShootSettings._conn = nil
        end
        AutoShootSettings._lastTarget = nil
        AutoShootSettings._currentAimPos = nil
        AutoShootSettings._lastFire = 0

        AutoShootSettings._conn = RunService.RenderStepped:Connect(function()
            pcall(function()
                if not AutoShootSettings.Enabled then return end

                local target = findSmartTarget()

                if target then
                    local now = tick()
                    local center = uis:GetMouseLocation()
                    local targetPos = target.screenPos

                    -- Calculate distance to target
                    local dx = targetPos.X - center.X
                    local dy = targetPos.Y - center.Y
                    local dist = math.sqrt(dx * dx + dy * dy)

                    -- Fire when crosshair is close enough to target (within ~15px)
                    if dist < 15 then
                        -- Burst fire logic
                        if AutoShootSettings._burstShotsLeft > 0 then
                            -- Still in a burst — fire next shot if delay elapsed
                            if now - AutoShootSettings._lastFire >= AutoShootSettings.BurstDelay then
                                AutoShootSettings._lastFire = now
                                AutoShootSettings._burstShotsLeft = AutoShootSettings._burstShotsLeft - 1
                                if mouse1press and mouse1release then
                                    mouse1press()
                                    task.wait(0.02)
                                    mouse1release()
                                elseif mouse1click then
                                    mouse1click()
                                end
                            end
                        else
                            -- Not in burst — check cooldown and start new burst
                            if now - AutoShootSettings._lastBurstTime >= AutoShootSettings.Cooldown then
                                AutoShootSettings._lastBurstTime = now
                                AutoShootSettings._burstShotsLeft = AutoShootSettings.BurstCount - 1
                                AutoShootSettings._lastFire = now
                                if mouse1press and mouse1release then
                                    mouse1press()
                                    task.wait(0.02)
                                    mouse1release()
                                elseif mouse1click then
                                    mouse1click()
                                end
                            end
                        end
                    else
                        -- Crosshair not on target — reset burst
                        AutoShootSettings._burstShotsLeft = 0
                    end
                else
                    -- No target — reset
                    AutoShootSettings._lastTarget = nil
                    AutoShootSettings._burstShotsLeft = 0
                end
            end)
        end)
    end

    local function stopAutoShoot()
        if AutoShootSettings._conn then
            AutoShootSettings._conn:Disconnect()
            AutoShootSettings._conn = nil
        end
        AutoShootSettings._lastTarget = nil
        AutoShootSettings._currentAimPos = nil
        AutoShootSettings._burstShotsLeft = 0
    end

    getgenv().ZX_AutoShoot = {
        start = startAutoShoot,
        stop = stopAutoShoot,
        findTarget = findSmartTarget,
    }

    -- Auto-start the loop once (it self-checks Enabled flag)
    task.spawn(function()
        task.wait(2)
        startAutoShoot()
    end)
end

-- Auto Walk: walks toward current aim target automatically.
-- 5 movement modes:
--   Normal      -> walk straight to target
--   Strafing    -> walk + lateral sine wave movement
--   Jumping     -> walk + jump when running
--   JumpStrafe  -> walk + jump + lateral sine wave
--   Flanking    -> circle around the target
-- Stops if user manually presses WASD or Space.
RunService:BindToRenderStep("ZytheraXAutoWalk", Enum.RenderPriority.Character.Value, function()
    if not PlayerSettings.AutoWalkEnabled then return end

    local lpChar = lp.Character
    if not lpChar then return end
    local lpHum = lpChar:FindFirstChildOfClass("Humanoid")
    local lpRoot = lpChar:FindFirstChild("HumanoidRootPart")
    if not lpHum or not lpRoot then return end

    -- Find current aim target (uses SilentAim > RageMode > HoldBot)
    local walkTarget = nil
    if SilentAim.Enabled then
        walkTarget = get_best_target(SilentAim)
    elseif RageMode.Enabled then
        walkTarget = get_best_target(RageMode)
    elseif HoldBot.Enabled then
        walkTarget = get_best_target(HoldBot)
    end

    -- If no target, release any held movement keys and exit
    if not walkTarget or not walkTarget.Parent then
        if keyrelease then
            pcall(keyrelease, 87)  -- W
            pcall(keyrelease, 65)  -- A
            pcall(keyrelease, 83)  -- S
            pcall(keyrelease, 68)  -- D
            pcall(keyrelease, 32)  -- Space
        end
        return
    end

    local targetChar = walkTarget.Parent
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- Stop if user is manually pressing movement keys
    if uis:IsKeyDown(Enum.KeyCode.W) or uis:IsKeyDown(Enum.KeyCode.A)
        or uis:IsKeyDown(Enum.KeyCode.S) or uis:IsKeyDown(Enum.KeyCode.D)
        or uis:IsKeyDown(Enum.KeyCode.Space) then
        if keyrelease then
            pcall(keyrelease, 87)
            pcall(keyrelease, 65)
            pcall(keyrelease, 83)
            pcall(keyrelease, 68)
            pcall(keyrelease, 32)
        end
        return
    end

    -- Compute target position with prediction
    local targetPos = targetRoot.Position + targetRoot.Velocity * 0.5
    local movePos = targetPos
    local shouldJump = false
    local strafeAmp = 5
    local flankAmp = 10
    local tickNow = tick()

    local method = PlayerSettings.AutoWalkMethod
    if method == "Strafing" then
        movePos = targetPos + lpRoot.CFrame.RightVector * math.sin(tickNow * 0.5) * strafeAmp
    elseif method == "Jumping" then
        shouldJump = (lpHum:GetState() == Enum.HumanoidStateType.Running)
    elseif method == "JumpStrafe" then
        movePos = targetPos + lpRoot.CFrame.RightVector * math.sin(tickNow * 0.5) * strafeAmp
        shouldJump = (lpHum:GetState() == Enum.HumanoidStateType.Running)
    elseif method == "Flanking" then
        local angle = tickNow * 0.5
        movePos = targetPos + Vector3.new(math.cos(angle) * flankAmp, 0, math.sin(angle) * flankAmp)
        if lpHum:GetState() == Enum.HumanoidStateType.Running then
            shouldJump = math.random() < 0.3
        end
    end

    -- Use keypress/keyrelease for production (real input simulation)
    if keypress and keyrelease then
        -- Release all first
        pcall(keyrelease, 87)
        pcall(keyrelease, 65)
        pcall(keyrelease, 83)
        pcall(keyrelease, 68)

        local dir = (movePos - lpRoot.Position).Unit
        local fwd = dir:Dot(lpRoot.CFrame.LookVector)
        local right = dir:Dot(lpRoot.CFrame.RightVector)
        local threshold = 0.2

        if fwd > threshold then
            pcall(keypress, 87)  -- W
        elseif fwd < -threshold then
            pcall(keypress, 83)  -- S
        end
        if right > threshold then
            pcall(keypress, 68)  -- D
        elseif right < -threshold then
            pcall(keypress, 65)  -- A
        end

        if shouldJump and lpHum.FloorMaterial ~= Enum.Material.Air then
            pcall(keypress, 32)  -- Space
            task.wait(0.1)
            pcall(keyrelease, 32)
        end
    else
        -- Fallback: Humanoid:MoveTo (works on all executors but less legit)
        if (movePos - lpRoot.Position).Magnitude > 1 then
            lpHum:MoveTo(movePos)
        end
        if shouldJump and lpHum.FloorMaterial ~= Enum.Material.Air then
            lpHum.Jump = true
        end
    end
end)

-- FPS counter in shared table (avoids top-level locals)
_fps = { frames = 0, tick = tick(), current = 0, label = nil }
pcall(function()
    _fps.label = Drawing.new("Text")
    _fps.label.Visible = false
    _fps.label.Color = Color3.fromRGB(130, 60, 255)
    _fps.label.Size = 16
    _fps.label.Center = false
    _fps.label.Outline = true
    _fps.label.Position = Vector2.new(15, 15)
    _fps.label.Font = 2
end)

RunService.RenderStepped:Connect(function()

    _fps.frames = _fps.frames + 1
    if tick() - _fps.tick >= 1 then
        _fps.current = _fps.frames
        _fps.frames = 0
        _fps.tick = tick()
    end

    if _fps.label then
        if PlayerSettings.ShowFPS then
            _fps.label.Visible = true
            _fps.label.Text = "ZytheraX | FPS: " .. _fps.current
        else
            _fps.label.Visible = false
        end
    end

    if PlayerSettings.CustomFOV then
        pcall(function()
            camera.FieldOfView = PlayerSettings.FOVValue
        end)
    end
end)

mouseMoveFunc = mousemoverel or (input and input.mousemoverel)

-- Advanced auto-fire: tries 3 different executor click methods
-- so it works on the widest range of executors. Falls back gracefully.
getgenv().ZX_autoFire = function()
    pcall(function()
        if mouse1click then
            mouse1click()
            return
        end
    end)
    pcall(function()
        if mousebuttonclick then
            mousebuttonclick(1)
            return
        end
    end)
    pcall(function()
        if click then
            click()
            return
        end
    end)
    pcall(function()
        if mouse1press and mouse1release then
            mouse1press()
            task.wait(0.01)
            mouse1release()
        end
    end)
end

local function autoFire()
    getgenv().ZX_autoFire()
end

-- Spawn an advanced bullet tracer when the local player fires.
-- Uses a Neon Part + Trail effect for a professional look.
-- Wrapped in `do...end` to avoid LuaJIT's 200-local-variable limit.
do
    local DebrisService = game:GetService("Debris")
    local function spawnAdvancedBulletTracer()
        if not VisualSettings.BulletTracerEnabled then return end

        local lpChar = lp.Character
        if not lpChar then return end
        local head = lpChar:FindFirstChild("Head")
        if not head then return end

        local tracerColor = BULLET_TRACER_COLORS[VisualSettings.BulletTracerColorName]
            or BULLET_TRACER_COLORS["Toothpaste"]

        -- Create the bullet part
        local bulletPart = Instance.new("Part")
        bulletPart.Size = Vector3.new(0.9, 0.5, 1)
        bulletPart.Color = tracerColor
        bulletPart.Material = Enum.Material.Neon
        bulletPart.Anchored = false
        bulletPart.CanCollide = false
        bulletPart.CanQuery = false
        bulletPart.CastShadow = false
        bulletPart.CFrame = head.CFrame
        bulletPart.Parent = workspace

        -- Add two attachments for the Trail
        local att0 = Instance.new("Attachment", bulletPart)
        att0.Position = Vector3.new(0, 0, -0.15)
        local att1 = Instance.new("Attachment", bulletPart)
        att1.Position = Vector3.new(0, 0, 0.15)

        -- Add the Trail effect
        local trail = Instance.new("Trail")
        trail.Attachment0 = att0
        trail.Attachment1 = att1
        trail.FaceCamera = true
        trail.Lifetime = VisualSettings.BulletTracerLifetime
        trail.LightEmission = 1
        trail.LightInfluence = 0
        trail.Brightness = 8
        trail.Color = ColorSequence.new(tracerColor)
        trail.Transparency = NumberSequence.new(0)
        trail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.319),
            NumberSequenceKeypoint.new(1, 0.319)
        })
        trail.Enabled = true
        trail.Parent = bulletPart

        -- Add BodyVelocity to propel the bullet forward
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(100000, 100000, 100000)
        bv.Velocity = camera.CFrame.LookVector * VisualSettings.BulletTracerSpeed
        bv.Parent = bulletPart

        -- Auto-cleanup after 13 seconds
        DebrisService:AddItem(bulletPart, 13)
    end

    -- Hook the bullet tracer to fire when the player clicks
    uis.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            spawnAdvancedBulletTracer()
        end
    end)
end

------------------------------------------------------------------
-- Thirdperson Mode + FOV Override + World Visual Effects
-- Wrapped in `do...end` to avoid LuaJIT's 200-local-variable limit.
-- Functions are exposed via getgenv().ZX_Visuals so the UI toggles
-- can call them.
------------------------------------------------------------------
local ZX_Visuals = {}
getgenv().ZX_Visuals = ZX_Visuals

do
    -- Thirdperson Mode: switches camera to Classic + zooms out.
    local origCameraMaxZoom = lp.CameraMaxZoomDistance
    local origCameraMinZoom = lp.CameraMinZoomDistance
    local origFieldOfView = camera.FieldOfView

    local function applyThirdperson()
        local char = lp.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        task.wait(0.05)
        if VisualSettings.ThirdpersonEnabled then
            lp.CameraMode = Enum.CameraMode.Classic
            lp.CameraMaxZoomDistance = VisualSettings.ThirdpersonDistance
            lp.CameraMinZoomDistance = VisualSettings.ThirdpersonDistance
        else
            lp.CameraMode = Enum.CameraMode.LockFirstPerson
            lp.CameraMaxZoomDistance = origCameraMaxZoom
            lp.CameraMinZoomDistance = origCameraMinZoom
        end
    end

    -- FOV Override
    local function applyFOVOverride()
        if VisualSettings.FOVOverrideEnabled then
            camera.FieldOfView = VisualSettings.FOVOverrideValue
        else
            camera.FieldOfView = origFieldOfView
        end
    end

    -- World Color (Lighting.Ambient)
    local function applyWorldColor()
        if VisualSettings.WorldColorEnabled then
            local color = WORLD_COLOR_PRESETS[VisualSettings.WorldColorName]
            if color then
                Lighting.Ambient = color
            end
        else
            Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        end
    end

    -- Fog Controls
    local function applyFog()
        if VisualSettings.FogEnabled then
            Lighting.FogStart = 0
            Lighting.FogEnd = VisualSettings.FogDistance
            local fogColor = WORLD_COLOR_PRESETS[VisualSettings.FogColorName]
            if fogColor then
                Lighting.FogColor = fogColor
            end
        else
            Lighting.FogEnd = 100000
        end
    end

    -- Weather Effects (spawn a Part above the player)
    local function applyWeather()
        local existing = workspace:FindFirstChild("ZytheraXWeatherPart")
        if existing then existing:Destroy() end
        if VisualSettings.WeatherType == "None" then return end
        local part = Instance.new("Part")
        part.Name = "ZytheraXWeatherPart"
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new(1000, 1, 1000)
        part.Position = Vector3.new(0, 100, 0)
        part.Transparency = 0.5
        if VisualSettings.WeatherType == "Rain" then
            part.Material = Enum.Material.Glass
            part.Color = Color3.fromRGB(170, 170, 255)
        elseif VisualSettings.WeatherType == "Snow" then
            part.Material = Enum.Material.Snow
            part.Color = Color3.fromRGB(255, 255, 255)
        end
        part.Parent = workspace
    end

    -- Night Mode
    local function applyNightMode()
        if VisualSettings.NightModeEnabled then
            Lighting.TimeOfDay = "00:00:00"
            Lighting.Brightness = 1
            Lighting.Ambient = Color3.fromRGB(20, 20, 30)
            Lighting.OutdoorAmbient = Color3.fromRGB(10, 10, 20)
        else
            Lighting.TimeOfDay = "14:00:00"
            Lighting.Brightness = 2
            Lighting.Ambient = Color3.fromRGB(128, 128, 128)
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end
    end

    -- Expose functions to outer scope
    ZX_Visuals.applyThirdperson = applyThirdperson
    ZX_Visuals.applyFOVOverride = applyFOVOverride
    ZX_Visuals.applyWorldColor = applyWorldColor
    ZX_Visuals.applyFog = applyFog
    ZX_Visuals.applyWeather = applyWeather
    ZX_Visuals.applyNightMode = applyNightMode

    -- Thirdperson toggle keybind (K/O/P)
    uis.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if VisualSettings.ThirdpersonActivation ~= "Always on" then
            if input.KeyCode == Enum.KeyCode[VisualSettings.ThirdpersonActivation] then
                VisualSettings.ThirdpersonEnabled = not VisualSettings.ThirdpersonEnabled
                applyThirdperson()
            end
        end
    end)

    -- Re-apply thirdperson on character respawn
    lp.CharacterAdded:Connect(function()
        task.wait(0.5)
        if VisualSettings.ThirdpersonEnabled and VisualSettings.ThirdpersonActivation == "Always on" then
            applyThirdperson()
        end
    end)

    -- Periodic re-apply for FOV (game may override it)
    task.spawn(function()
        while true do
            pcall(applyFOVOverride)
            task.wait(2)
        end
    end)
end

-- (UI callbacks call ZX_Visuals.X() directly to avoid local pollution)

------------------------------------------------------------------
-- Weapon Latex + Arm Latex + Bloom Effect + Player ESP Highlight
-- All visual toggles created here. Run on a Stepped loop to keep
-- applying to new viewmodel arms as the player switches weapons.
-- Wrapped in `do...end` to avoid LuaJIT's 200-local-variable limit.
------------------------------------------------------------------
do
    -- Find the local viewmodel (Rivals puts it in workspace:ViewModels)
    local function findViewModel()
        local vms = workspace:FindFirstChild("ViewModels")
        if vms then
            for _, m in ipairs(vms:GetChildren()) do
                if m:IsA("Model") then return m end
            end
        end
        -- Also check PlayerScripts-style viewmodel
        local lpChar = lp.Character
        if lpChar then
            for _, c in ipairs(lpChar:GetChildren()) do
                if c:IsA("Model") and c.Name:lower():find("view") then
                    return c
                end
            end
        end
        return nil
    end

    -- Apply ForceField material to the viewmodel's arms (Weapon Latex)
    local function applyWeaponLatex()
        if not VisualSettings.WeaponLatexEnabled then return end
        local vm = findViewModel()
        if not vm then return end
        for _, part in ipairs(vm:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name:lower():find("arm") or part.Name:lower():find("hand")) then
                part.Material = Enum.Material.ForceField
                part.Color = Color3.fromRGB(170, 170, 255)
                part.Reflectance = 0.12
            end
        end
    end

    -- Apply ForceField material specifically to character arms (Arm Latex)
    local function applyArmLatex()
        if not VisualSettings.ArmLatexEnabled then return end
        local lpChar = lp.Character
        if not lpChar then return end
        for _, part in ipairs(lpChar:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name:lower():find("arm") or part.Name:lower():find("hand")) then
                part.Material = Enum.Material.ForceField
                part.Color = Color3.fromRGB(170, 170, 255)
                part.Reflectance = 0.12
            end
        end
    end

    -- Run latex application every 0.5s (cheap, catches weapon switches)
    task.spawn(function()
        while true do
            pcall(applyWeaponLatex)
            pcall(applyArmLatex)
            task.wait(0.5)
        end
    end)

    ------------------------------------------------------------------
    -- Bloom Effect Controls
    -- Finds any BloomEffect in Lighting and lets you tune it.
    ------------------------------------------------------------------
    local currentBloomEffect = nil
    local function findBloomEffect()
        for _, child in ipairs(game:GetService("Lighting"):GetDescendants()) do
            if child:IsA("BloomEffect") then
                return child
            end
        end
        return nil
    end

    local function applyBloomSettings()
        if not currentBloomEffect then
            currentBloomEffect = findBloomEffect()
        end
        if currentBloomEffect then
            currentBloomEffect.Enabled = VisualSettings.BloomEnabled
            currentBloomEffect.Intensity = VisualSettings.BloomIntensity / 10
        end
    end

    -- Re-apply when a new BloomEffect is added to Lighting
    game:GetService("Lighting").DescendantAdded:Connect(function(d)
        if d:IsA("BloomEffect") then
            currentBloomEffect = d
            applyBloomSettings()
        end
    end)

    -- Apply bloom settings every 2s
    task.spawn(function()
        while true do
            pcall(applyBloomSettings)
            task.wait(2)
        end
    end)

    ------------------------------------------------------------------
    -- Player ESP Highlight (AlwaysOnTop)
    -- Adds a Highlight to every enemy that shows through walls.
    -- More reliable than Drawing ESP which gets occluded by geometry.
    ------------------------------------------------------------------
    local ESPHighlightCache = {}

    local function applyESPHighlight(player)
        if player == lp then return end
        local char = player.Character
        if not char then return end

        -- Remove existing
        if ESPHighlightCache[player] then
            ESPHighlightCache[player]:Destroy()
            ESPHighlightCache[player] = nil
        end

        -- Skip if disabled or teammate
        if not EspSettings.EspChams then return end
        if isTeammate(player) then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        local hl = Instance.new("Highlight")
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 1
        hl.FillColor = Color3.fromRGB(255, 255, 255)
        hl.Parent = char
        ESPHighlightCache[player] = hl
    end

    local function removeESPHighlight(player)
        if ESPHighlightCache[player] then
            ESPHighlightCache[player]:Destroy()
            ESPHighlightCache[player] = nil
        end
    end

    -- Hook into player added/removed/character added
    players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function()
            task.wait(0.2)
            applyESPHighlight(p)
        end)
        p.CharacterRemoving:Connect(function()
            removeESPHighlight(p)
        end)
    end)

    players.PlayerRemoving:Connect(removeESPHighlight)

    -- Apply to existing players + their future character spawns
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= lp then
            if p.Character then
                applyESPHighlight(p)
            end
            p.CharacterAdded:Connect(function()
                task.wait(0.2)
                applyESPHighlight(p)
            end)
            p.CharacterRemoving:Connect(function()
                removeESPHighlight(p)
            end)
        end
    end

    -- Periodic re-application (catches the case where existing toggle was
    -- enabled but no player had a character yet)
    task.spawn(function()
        while true do
            if EspSettings.EspChams then
                for _, p in ipairs(players:GetPlayers()) do
                    if p ~= lp and p.Character then
                        if not ESPHighlightCache[p] or not ESPHighlightCache[p].Parent then
                            applyESPHighlight(p)
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end

-- Fly state in shared table (avoids top-level locals)
local _flyState = { active = false, bodyMovers = {}, conn = nil }

local function stopFly()
    _flyState.active = false
    if _flyState.conn then _flyState.conn:Disconnect(); _flyState.conn = nil end
    for _, m in pairs(_flyState.bodyMovers) do
        if m and m.Parent then m:Destroy() end
    end
    _flyState.bodyMovers = {}
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
    end
end

local function startFly(speed)
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    for _, m in pairs(_flyState.bodyMovers) do
        if m and m.Parent then m:Destroy() end
    end
    _flyState.bodyMovers = {}
    _flyState.active = true
    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.one * 9e9
    bv.Velocity = Vector3.zero
    bv.Parent = root
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.one * 9e9
    bg.P = 9e4
    bg.CFrame = root.CFrame
    bg.Parent = root
    _flyState.bodyMovers = { bv, bg }
    _flyState.conn = rs.Heartbeat:Connect(function()
        if not _flyState.active then stopFly(); return end
        local char2 = lp.Character
        local root2 = char2 and char2:FindFirstChild("HumanoidRootPart")
        if not root2 or not bv.Parent or not bg.Parent then stopFly(); return end
        local cam = workspace.CurrentCamera
        local vel = Vector3.zero
        if uis:IsKeyDown(Enum.KeyCode.W)         then vel = vel + cam.CFrame.LookVector  end
        if uis:IsKeyDown(Enum.KeyCode.S)         then vel = vel - cam.CFrame.LookVector  end
        if uis:IsKeyDown(Enum.KeyCode.D)         then vel = vel + cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.A)         then vel = vel - cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space)     then vel = vel + Vector3.yAxis end
        if uis:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.yAxis end
        ts:Create(bv, TweenInfo.new(0.1), { Velocity = vel * speed }):Play()
        bg.CFrame = cam.CFrame.Rotation + root2.Position
    end)
end

-- Use a shared table for orig* values to avoid consuming top-level locals
-- (LuaJIT 200-local-limit fix)
_origLighting = {}

local function setFullbright(on)
    if on then
        _origLighting.Ambient = Lighting.Ambient
        _origLighting.Bright = Lighting.Brightness
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.GlobalShadows = false
    else
        if _origLighting.Ambient then Lighting.Ambient = _origLighting.Ambient end
        if _origLighting.Bright  then Lighting.Brightness = _origLighting.Bright end
        Lighting.GlobalShadows = true
    end
end

local function applySkyColor()
    if not VisualSettings.SkyColorEnabled then

        if _origLighting.SkyAmbient then
            Lighting.Ambient = _origLighting.SkyAmbient
            Lighting.Brightness = _origLighting.SkyBright
            Lighting.ClockTime = _origLighting.SkyClock
            Lighting.OutdoorAmbient = _origLighting.SkyOutdoor
            _origLighting.SkyAmbient = nil
        end
        return
    end

    if not _origLighting.SkyAmbient then
        _origLighting.SkyAmbient = Lighting.Ambient
        _origLighting.SkyBright = Lighting.Brightness
        _origLighting.SkyClock = Lighting.ClockTime
        _origLighting.SkyOutdoor = Lighting.OutdoorAmbient
    end

    Lighting.Ambient = VisualSettings.AmbientColor
    Lighting.OutdoorAmbient = VisualSettings.AmbientColor
    Lighting.Brightness = VisualSettings.SkyBrightness or 1.5
    Lighting.ClockTime = VisualSettings.SkyClockTime or 12
end

-- Shared table for anti-ragdoll/afk connections (avoids top-level locals)
_antiConns = { ragdoll = nil, afk = nil }

local function setAntiRagdoll(on)
    if _antiConns.ragdoll then _antiConns.ragdoll:Disconnect(); _antiConns.ragdoll = nil end
    local function apply(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not on)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not on)
            hum.BreakJointsOnDeath = not on
        end
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                v.Enabled = not on
            end
        end
    end
    apply(lp.Character)
    if on then
        _antiConns.ragdoll = lp.CharacterAdded:Connect(function(char)
            task.wait(0.1)
            apply(char)
        end)
    end
end

local function setupAntiAfk(on)
    if _antiConns.afk then _antiConns.afk:Disconnect(); _antiConns.afk = nil end
    if on then
        _antiConns.afk = lp.Idled:Connect(function()
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end)
    end
end

local function serverhop()
    local HttpS = cloneref(game:GetService("HttpService"))
    local TeleportS = cloneref(game:GetService("TeleportService"))
    local ok, data = pcall(function()
        return HttpS:JSONDecode(game:HttpGetAsync(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    if not ok then
        Library:Notify({ Title = "Serverhop", Description = "Failed to fetch servers.", Time = 4 })
        return
    end
    local best = nil
    for _, v in pairs(data.data) do
        if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= game.JobId then
            if not best or v.playing > best.playing then best = v end
        end
    end
    if best then
        Library:Notify({ Title = "Serverhop", Description = "Hopping to another server...", Time = 3 })
        task.wait(0.5)
        TeleportS:TeleportToPlaceInstance(game.PlaceId, best.id)
    else
        Library:Notify({ Title = "Serverhop", Description = "No other servers found.", Time = 4 })
    end
end

local function rejoin()
    local TeleportS = cloneref(game:GetService("TeleportService"))
    Library:Notify({ Title = "Rejoin", Description = "Rejoining server...", Time = 3 })
    task.wait(0.5)
    if #Players:GetPlayers() <= 1 then
        TeleportS:Teleport(game.PlaceId, lp)
    else
        TeleportS:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
    end
end

lockLabelGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
lockIndicatorCache = nil
lockIndicatorCacheTime = 0
lockLabelGui.Name = "ZytheraLockIndicator"
lockLabelGui.ResetOnSpawn = false
lockLabelGui.Enabled = true
lockLabel = Instance.new("TextLabel", lockLabelGui)
lockLabel.Size = UDim2.new(0, 250, 0, 25)
lockLabel.Position = UDim2.new(1, -260, 0, 10)
lockLabel.BackgroundTransparency = 1
lockLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
lockLabel.Font = Enum.Font.Code
lockLabel.TextSize = 12
lockLabel.TextXAlignment = Enum.TextXAlignment.Right
lockLabel.Text = "SCANNING..."
lockLabel.Visible = false

SAFovBg = Drawing.new("Circle")
SAFovBg.Thickness = 0
SAFovBg.Color = Color3.fromRGB(25, 25, 30)
SAFovBg.Transparency = 0.4
SAFovBg.Filled = true

SAFovRing = Drawing.new("Circle")
SAFovRing.Thickness = 1.5
SAFovRing.Color = Color3.fromRGB(255, 30, 30)
SAFovRing.Transparency = 0.8
SAFovRing.Filled = false

RageFovBg = Drawing.new("Circle")
RageFovBg.Thickness = 0
RageFovBg.Color = Color3.fromRGB(25, 25, 30)
RageFovBg.Transparency = 0.4
RageFovBg.Filled = true

RageFovRing = Drawing.new("Circle")
RageFovRing.Thickness = 1.5
RageFovRing.Color = Color3.fromRGB(255, 0, 0)
RageFovRing.Transparency = 0.8
RageFovRing.Filled = false

HoldBotFovBg = Drawing.new("Circle")
HoldBotFovBg.Thickness = 0
HoldBotFovBg.Color = Color3.fromRGB(25, 25, 30)
HoldBotFovBg.Transparency = 0.4
HoldBotFovBg.Filled = true

HoldBotFovRing = Drawing.new("Circle")
HoldBotFovRing.Thickness = 1.5
HoldBotFovRing.Color = Color3.fromRGB(0, 200, 255)
HoldBotFovRing.Transparency = 0.8
HoldBotFovRing.Filled = false

task.wait(0.1)

rs.RenderStepped:Connect(function()
    local mousePos = uis:GetMouseLocation()
    local center = mousePos

    local rainbowColor = Color3.fromHSV(tick() % 5 / 5, 1, 1)

    local saColor = SilentAim.FovColor or Color3.fromRGB(255, 255, 255)
    if SilentAim.FovRainbow then saColor = rainbowColor end
    SAFovBg.Radius = SilentAim.FOV
    SAFovBg.Position = center
    SAFovBg.Color = saColor
    SAFovBg.Visible = SilentAim.Enabled and SilentAim.FovVisible and SilentAim.FovFilled
    SAFovRing.Radius = SilentAim.FOV
    SAFovRing.Position = center
    SAFovRing.Color = saColor
    SAFovRing.Visible = SilentAim.Enabled and SilentAim.FovVisible

    local rageColor = RageMode.FovColor or Color3.fromRGB(255, 0, 0)
    if RageMode.FovRainbow then rageColor = rainbowColor end
    RageFovBg.Radius = RageMode.FOV
    RageFovBg.Position = center
    RageFovBg.Color = rageColor
    RageFovBg.Visible = RageMode.Enabled and RageMode.UseFOV and RageMode.FovVisible and RageMode.FovFilled
    RageFovRing.Radius = RageMode.FOV
    RageFovRing.Position = center
    RageFovRing.Color = rageColor
    RageFovRing.Visible = RageMode.Enabled and RageMode.UseFOV and RageMode.FovVisible

    local hbColor = HoldBot.FovColor or Color3.fromRGB(0, 200, 255)
    if HoldBot.FovRainbow then
        hbColor = rainbowColor
    end
    HoldBotFovBg.Radius = HoldBot.FOV
    HoldBotFovBg.Position = center
    HoldBotFovBg.Color = hbColor
    HoldBotFovBg.Visible = HoldBot.Enabled and HoldBot.FovVisible and HoldBot.FovFilled
    HoldBotFovRing.Radius = HoldBot.FOV
    HoldBotFovRing.Position = center
    HoldBotFovRing.Color = hbColor
    HoldBotFovRing.Visible = HoldBot.Enabled and HoldBot.FovVisible

    if VisualSettings.LockIndicator then
        lockLabel.Visible = true
        if not lockIndicatorCache or tick() - lockIndicatorCacheTime > 0.1 then
            lockIndicatorCacheTime = tick()
            local lockedTarget = nil
            if SilentAim.Enabled then
                lockedTarget = get_best_target(SilentAim)
            elseif RageMode.Enabled then
                lockedTarget = get_best_target(RageMode)
            elseif HoldBot.Enabled then
                lockedTarget = get_best_target(HoldBot)
            end
            lockIndicatorCache = lockedTarget
        end
        if lockIndicatorCache and lockIndicatorCache.Parent then
            local targetPlayer = players:GetPlayerFromCharacter(lockIndicatorCache.Parent)
            if targetPlayer then
                lockLabel.Text = "LOCKED: " .. targetPlayer.Name:upper()
                lockLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
            end
        else
            lockLabel.Text = "SCANNING..."
            lockLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    else
        lockLabel.Visible = false
    end
end)

-- Player cache + team cache (kept in main scope so the rest of the
-- script can see them — previously wrapped in a `do...end` block that
-- made them local-only and caused "attempt to index nil with 'lastUpdate'"
-- at line 11305 on every render frame.)
CachedPlayers = players:GetPlayers()
PlayerCacheTick = 0
local function GetCachedPlayers()
    local now = tick()
    if now - PlayerCacheTick > 1 then
        CachedPlayers = players:GetPlayers()
        PlayerCacheTick = now
    end
    return CachedPlayers
end

players.PlayerAdded:Connect(function()
    CachedPlayers = players:GetPlayers()
    PlayerCacheTick = tick()
end)
players.PlayerRemoving:Connect(function()
    CachedPlayers = players:GetPlayers()
    PlayerCacheTick = tick()
end)

-- ═══════════════════════════════════════════════════════════════════
-- HITBOX EXPANDER + 3D ESP SPHERE (ported from Bangers ESP)
-- Increases enemy HRP Size for easier hits + optional 3D sphere visual
-- ═══════════════════════════════════════════════════════════════════
getgenv().ZX_HitboxExpander = getgenv().ZX_HitboxExpander or {
    Enabled = false,
    Size = 10,
    Transparency = 1,  -- invisible by default
    _originalSizes = {},  -- character -> original HRP size
    _spheres = {},        -- character -> sphere Part
}

local HitboxExpander = getgenv().ZX_HitboxExpander

local function applyHitboxToCharacter(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Save original if not saved
    if not HitboxExpander._originalSizes[char] then
        HitboxExpander._originalSizes[char] = {
            Size = hrp.Size,
            Transparency = hrp.Transparency,
            CanCollide = hrp.CanCollide,
        }
    end
    pcall(function()
        hrp.Size = Vector3.new(HitboxExpander.Size, HitboxExpander.Size, HitboxExpander.Size)
        hrp.Transparency = HitboxExpander.Transparency
        hrp.CanCollide = false
    end)
end

local function restoreHitboxForCharacter(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local orig = HitboxExpander._originalSizes[char]
    if orig then
        pcall(function()
            hrp.Size = orig.Size
            hrp.Transparency = orig.Transparency
            hrp.CanCollide = orig.CanCollide
        end)
        HitboxExpander._originalSizes[char] = nil
    end
end

local function applyHitboxToAllEnemies()
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= lp and p.Character then
            if not isTeammate(p) then
                applyHitboxToCharacter(p.Character)
            end
        end
    end
end

local function restoreAllHitboxes()
    for _, p in ipairs(players:GetPlayers()) do
        if p.Character then
            restoreHitboxForCharacter(p.Character)
        end
    end
    -- Also clear orphans
    for char, _ in pairs(HitboxExpander._originalSizes) do
        restoreHitboxForCharacter(char)
    end
    HitboxExpander._originalSizes = {}
end

-- 3D ESP Sphere system
getgenv().ZX_ESPSphere = getgenv().ZX_ESPSphere or {
    Enabled = false,
    Size = 6,
    Color = Color3.fromRGB(0, 255, 0),
    Transparency = 0.7,
    _spheres = {},
}

local ESPSphere = getgenv().ZX_ESPSphere

local function addSphereToCharacter(char)
    if not char then return end
    if ESPSphere._spheres[char] then return end  -- already has
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    pcall(function()
        local sphere = Instance.new("Part")
        sphere.Name = "ZX_ESPSphere"
        sphere.Shape = Enum.PartType.Ball
        sphere.Size = Vector3.new(ESPSphere.Size, ESPSphere.Size, ESPSphere.Size)
        sphere.Material = Enum.Material.ForceField
        sphere.Color = ESPSphere.Color
        sphere.Transparency = ESPSphere.Transparency
        sphere.CanCollide = false
        sphere.Anchored = false
        sphere.Massless = true
        sphere.CastShadow = false
        sphere.Parent = char

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = hrp
        weld.Part1 = sphere
        weld.Parent = sphere

        ESPSphere._spheres[char] = sphere
    end)
end

local function removeSphereFromCharacter(char)
    local sphere = ESPSphere._spheres[char]
    if sphere then
        pcall(function() sphere:Destroy() end)
        ESPSphere._spheres[char] = nil
    end
end

local function addSpheresToAllEnemies()
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= lp and p.Character then
            if not isTeammate(p) then
                addSphereToCharacter(p.Character)
            end
        end
    end
end

local function removeAllSpheres()
    for char, sphere in pairs(ESPSphere._spheres) do
        pcall(function() sphere:Destroy() end)
    end
    ESPSphere._spheres = {}
    -- Also clean any stray spheres in workspace
    for _, p in ipairs(players:GetPlayers()) do
        if p.Character then
            local s = p.Character:FindFirstChild("ZX_ESPSphere")
            if s then pcall(function() s:Destroy() end) end
        end
    end
end

-- Background loop: apply hitbox/sphere to new characters
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            for _, p in ipairs(players:GetPlayers()) do
                if p ~= lp and p.Character then
                    local char = p.Character
                    local isAlly = isTeammate(p)
                    -- Hitbox
                    if HitboxExpander.Enabled and not isAlly then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            -- Only re-apply if size drifted (anti-restore by game)
                            if hrp.Size.X < HitboxExpander.Size - 0.1 then
                                applyHitboxToCharacter(char)
                            end
                        end
                    elseif not HitboxExpander.Enabled then
                        -- Don't restore here (done on toggle off)
                    end
                    -- Sphere
                    if ESPSphere.Enabled and not isAlly then
                        if not ESPSphere._spheres[char] then
                            addSphereToCharacter(char)
                        end
                    elseif not ESPSphere.Enabled and ESPSphere._spheres[char] then
                        removeSphereFromCharacter(char)
                    end
                end
            end
        end)
        -- Clean up disconnected players' spheres
        for char, _ in pairs(ESPSphere._spheres) do
            if not char.Parent then
                ESPSphere._spheres[char] = nil
            end
        end
    end
end)

-- Hook character added/removed for new spawns
players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if HitboxExpander.Enabled and not isTeammate(p) then
            applyHitboxToCharacter(char)
        end
        if ESPSphere.Enabled and not isTeammate(p) then
            addSphereToCharacter(char)
        end
    end)
    p.CharacterRemoving:Connect(function(char)
        removeSphereFromCharacter(char)
        -- Don't restore hitbox here — game cleans up the character anyway
        HitboxExpander._originalSizes[char] = nil
    end)
end)

teamCache = {
    myTeamID = nil,
    lastUpdate = 0,
}

local function UpdateTeamCache()
    teamCache.myTeamID = lp:GetAttribute("TeamID")
    teamCache.lastUpdate = tick()
end

UpdateTeamCache()

lp:GetAttributeChangedSignal("TeamID"):Connect(function()
    UpdateTeamCache()
end)

local function isTeammate(player)
    if not TeamCheck.Enabled then return false end

    local myTeamID = teamCache.myTeamID
    local theirTeamID = player:GetAttribute("TeamID")

    if myTeamID ~= nil and theirTeamID ~= nil and myTeamID ~= 0 and theirTeamID ~= 0 and myTeamID == theirTeamID then
        if TeamCheck.DebugMode then
            print("[TeamCheck] " .. player.Name .. " is TEAMMATE (TeamID: " .. tostring(myTeamID) .. ")")
        end
        return true
    end

    local myTeam = lp.Team
    local theirTeam = player.Team
    if myTeam and theirTeam and myTeam == theirTeam then
        if TeamCheck.DebugMode then
            print("[TeamCheck] " .. player.Name .. " is TEAMMATE (Player.Team match)")
        end
        return true
    end

    local myAttrTeam = lp:GetAttribute("Team")
    local theirAttrTeam = player:GetAttribute("Team")
    if myAttrTeam and theirAttrTeam and myAttrTeam == theirAttrTeam then
        if TeamCheck.DebugMode then
            print("[TeamCheck] " .. player.Name .. " is TEAMMATE (Team attribute match)")
        end
        return true
    end

    return false
end

isTeammateOrbit = isTeammate

local function get_best_target(config)
    local target = nil
    local bestDist = config.FOV
    local center = uis:GetMouseLocation()
    local maxDistance = config.MaxDistance or math.huge

    local currentPart = config.HitPart or "Head"

    local HEAD_PART_CHAIN = {
        "HitboxHead",
        "PhysicalHitboxHead",
        "Head",
        "HumanoidRootPart",
    }

    local function resolveHitPart(char, userPick)
        if not char then return nil end
        if userPick ~= "Head" then

            return char:FindFirstChild(userPick)
        end

        for _, partName in ipairs(HEAD_PART_CHAIN) do
            local part = char:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                return part
            end
        end
        return nil
    end

    local camPos = camera.CFrame.Position
    local liveLpChar = lp.Character
    local useWallCheck = config.WallCheck == true
    local playerList = GetCachedPlayers()

    for _, v in ipairs(playerList) do
        if v ~= lp and v.Character then

            if isTeammate(v) then continue end

            local humanoid = v.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                continue
            end

            local hitPart = resolveHitPart(v.Character, currentPart)
            if not hitPart then
                continue
            end
            local partPos = hitPart.Position
            local pos, onScreen = camera:WorldToViewportPoint(partPos)
            if onScreen then
                local mag = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if mag < config.FOV then

                    local dist3D = (camPos - partPos).Magnitude
                    if dist3D > maxDistance then
                        continue
                    end

                    local isVisible = true

                    if useWallCheck then
                        local liveTargetChar = v.Character
                        local direction = partPos - camPos
                        local filterList = {liveLpChar}
                        for _, otherPlr in ipairs(playerList) do
                            if otherPlr ~= lp and otherPlr ~= v and otherPlr.Character then
                                filterList[#filterList + 1] = otherPlr.Character
                            end
                        end
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        rayParams.FilterDescendantsInstances = filterList
                        rayParams.IgnoreWater = true
                        rayParams.RespectCanCollide = true
                        local result = workspace:Raycast(camPos, direction, rayParams)

                        if result and result.Instance and result.Instance:IsA("BasePart") then

                            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                            if hitChar ~= liveTargetChar then
                                local inst = result.Instance
                                if inst.CanCollide or inst.Transparency < 1 then
                                    isVisible = false
                                end
                            end
                        end
                    end

                    if isVisible and mag < bestDist then
                        bestDist = mag
                        target = hitPart
                    end
                end
            end
        end
    end
    return target
end

-- Crosshair constants + UI elements.
-- Built inside a `do...end` block to avoid LuaJIT's 200-local-variable
-- limit per function. Element references that the render loop needs
-- are stored in the shared ZX_Crosshair table.
ZX_Crosshair = {
    presets = {
        ["Red"] = Color3.fromRGB(255, 50, 50),
        ["Blue"] = Color3.fromRGB(0, 180, 255),
        ["Purple"] = Color3.fromRGB(160, 32, 240),
        ["Yellow"] = Color3.fromRGB(255, 230, 50),
        ["Pink"] = Color3.fromRGB(255, 105, 180),
        ["Orange"] = Color3.fromRGB(255, 140, 0),
        ["Cyan"] = Color3.fromRGB(0, 255, 255)
    },
    SPIN_SPEED = 45,
    THICKNESS = 3,
    BASE_LENGTH = 14,
    MIN_GAP = 4,
    MAX_GAP = 12,
    PULSE_SPEED = 3,
    timePassed = 0,
}
getgenv().ZX_Crosshair = ZX_Crosshair

do
    local gui = Instance.new("ScreenGui")
    gui.Name = "AnimatedCrosshairGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = lp:WaitForChild("PlayerGui")

    local anchor = Instance.new("Frame", gui)
    anchor.Name = "Anchor"
    anchor.Size = UDim2.new(0, 0, 0, 0)
    anchor.Position = UDim2.new(0.5, 0, 0.5, 0)
    anchor.BackgroundTransparency = 1
    anchor.AnchorPoint = Vector2.new(0.5, 0.5)

    local function createLine(name, anchorPoint)
        local line = Instance.new("Frame", anchor)
        line.Name = name
        line.BorderSizePixel = 0
        line.AnchorPoint = anchorPoint
        local stroke = Instance.new("UIStroke", line)
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 1.5
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        return line
    end

    ZX_Crosshair.anchor = anchor
    ZX_Crosshair.cTop = createLine("TopLine", Vector2.new(0.5, 1))
    ZX_Crosshair.cBottom = createLine("BottomLine", Vector2.new(0.5, 0))
    ZX_Crosshair.cLeft = createLine("LeftLine", Vector2.new(1, 0.5))
    ZX_Crosshair.cRight = createLine("RightLine", Vector2.new(0, 0.5))
end

-- Convenience locals removed to free top-level locals (LuaJIT 200 limit).
-- Code now accesses ZX_Crosshair.presets, ZX_Crosshair.anchor,
-- ZX_Crosshair.cTop, etc. directly.

EspGui = Instance.new("ScreenGui")
EspGui.Name = "CoreAssetCache"
EspGui.ResetOnSpawn = false
EspGui.IgnoreGuiInset = true
EspGui.Parent = lp:WaitForChild("PlayerGui")

HEALTH_BAR_WIDTH, HEALTH_BAR_OFFSET = 3, 5
EspRegistry = {}

SkeletonCache = {}

OriginalHeadSizes = {}

local function createEspElements(p)
    if p == lp or EspRegistry[p] then return end
    local elements = {}

    local BoxFrame = Instance.new("Frame", EspGui)
    BoxFrame.BackgroundTransparency = 1
    BoxFrame.Visible = false
    local Outline = Instance.new("Frame", BoxFrame)
    Outline.Size = UDim2.new(1, 0, 1, 0)
    Outline.BackgroundTransparency = 1
    local Stroke = Instance.new("UIStroke", Outline)
    Stroke.Thickness = EspSettings.BoxThickness
    elements.Box = BoxFrame
    elements.BoxStroke = Stroke

    local FilledBox = Instance.new("Frame", EspGui)
    FilledBox.BorderSizePixel = 0
    FilledBox.Visible = false
    elements.FilledBox = FilledBox

    local TracerLine = Instance.new("Frame", EspGui)
    TracerLine.AnchorPoint = Vector2.new(0.5, 0.5)
    TracerLine.BorderSizePixel = 0
    TracerLine.Visible = false
    elements.Tracer = TracerLine

    local HealthContainer = Instance.new("Frame", EspGui)
    HealthContainer.BackgroundColor3 = Color3.fromRGB(0,0,0)
    HealthContainer.BackgroundTransparency = 0.3
    HealthContainer.BorderSizePixel = 0
    HealthContainer.Visible = false
    local HealthFill = Instance.new("Frame", HealthContainer)
    HealthFill.BorderSizePixel = 0
    HealthFill.AnchorPoint = Vector2.new(0, 1)
    HealthFill.Position = UDim2.new(0, 0, 1, 0)
    elements.HealthBar = HealthContainer
    elements.HealthFill = HealthFill

    local TagLabel = Instance.new("TextLabel", EspGui)
    TagLabel.BackgroundTransparency = 1
    TagLabel.AnchorPoint = Vector2.new(0.5, 1)
    TagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TagLabel.Font = Enum.Font.FredokaOne
    TagLabel.TextSize = 13
    TagLabel.Visible = false
    local TextStroke = Instance.new("UIStroke", TagLabel)
    TextStroke.Color = Color3.fromRGB(0,0,0)
    TextStroke.Thickness = 1.5
    elements.Tag = TagLabel

    local DistLabel = Instance.new("TextLabel", EspGui)
    DistLabel.BackgroundTransparency = 1
    DistLabel.AnchorPoint = Vector2.new(0.5, 0)
    DistLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
    DistLabel.Font = Enum.Font.FredokaOne
    DistLabel.TextSize = 11
    DistLabel.Visible = false
    local DistStroke = Instance.new("UIStroke", DistLabel)
    DistStroke.Color = Color3.fromRGB(0,0,0)
    DistStroke.Thickness = 1.5
    elements.DistTag = DistLabel

    local WeaponTag = Instance.new("TextLabel", EspGui)
    WeaponTag.BackgroundTransparency = 1
    WeaponTag.AnchorPoint = Vector2.new(0.5, 0)
    WeaponTag.TextColor3 = Color3.fromRGB(255, 200, 80)
    WeaponTag.Font = Enum.Font.FredokaOne
    WeaponTag.TextSize = 10
    WeaponTag.Visible = false
    local WeaponStroke = Instance.new("UIStroke", WeaponTag)
    WeaponStroke.Color = Color3.fromRGB(0,0,0)
    WeaponStroke.Thickness = 1.5
    elements.WeaponTag = WeaponTag

    elements.CurrentCham = nil
    elements.CurrentGlowCham = nil
    EspRegistry[p] = elements

end
local function removeEspElements(p)
    if EspRegistry[p] then
        if EspRegistry[p].CurrentCham then
            EspRegistry[p].CurrentCham:Destroy()
        end
        if EspRegistry[p].CurrentGlowCham then
            EspRegistry[p].CurrentGlowCham:Destroy()
        end
        for _, obj in pairs(EspRegistry[p]) do
            if typeof(obj) == "Instance" then obj:Destroy() end
        end
        EspRegistry[p] = nil
    end

    if SkeletonCache[p] then
        for _, line in ipairs(SkeletonCache[p]) do
            pcall(function() line:Remove() end)
        end
        SkeletonCache[p] = nil
    end
end

for _, p in ipairs(players:GetPlayers()) do createEspElements(p) end
players.PlayerAdded:Connect(createEspElements)
players.PlayerRemoving:Connect(removeEspElements)

task.wait(0.1)

local pipelineConnection

local holdBotPrevX, holdBotPrevY = 0, 0
holdBotCurrentTarget = nil

local rageLastFire = 0

pipelineConnection = rs.RenderStepped:Connect(function(deltaTime)

    if tick() - teamCache.lastUpdate > 5 then
        UpdateTeamCache()
    end

    local holdBotActive = false
    if HoldBot.Enabled then
        if HoldBot.UseKeybind then
            holdBotActive = (Options.HoldBotKey ~= nil) and (Options.HoldBotKey:GetState() == true)
        else
            holdBotActive = true
        end
    end

    if holdBotActive then

        local target = nil

        if HoldBot.PersistentTarget and holdBotCurrentTarget then

            local persistChar = holdBotCurrentTarget.Parent
            if persistChar then
                local hum = persistChar:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then

                    local partName = holdBotCurrentTarget.Name
                    target = persistChar:FindFirstChild(partName)

                    if target and HoldBot.UseTargetZone then
                        local rootPart = persistChar:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
                            if dist > HoldBot.TargetZoneDistance then
                                target = nil
                            end
                        end
                    end

                    if target and not HoldBot.TargetBehindWalls then
                        local liveLpChar = lp.Character
                        local origin = camera.CFrame.Position
                        local targetPos = target.Position
                        local direction = targetPos - origin
                        local filterList = {liveLpChar}
                        for _, otherPlr in ipairs(players:GetPlayers()) do
                            if otherPlr ~= lp and otherPlr ~= v and otherPlr.Character then
                                filterList[#filterList + 1] = otherPlr.Character
                            end
                        end
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        rayParams.FilterDescendantsInstances = filterList
                        rayParams.IgnoreWater = true
                        rayParams.RespectCanCollide = true
                        local result = workspace:Raycast(origin, direction, rayParams)
                        if result and result.Instance and result.Instance:IsA("BasePart") then
                            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                            if hitChar ~= persistChar then
                                local inst = result.Instance
                                if inst.CanCollide or inst.Transparency < 1 then
                                    target = nil
                                end
                            end
                        end
                    end
                end
            end
            if not target then
                holdBotCurrentTarget = nil
            end
        end

        if not target then

            local holdBotConfig = {
                FOV = HoldBot.FOV,
                MaxDistance = HoldBot.MaxDistance,
                HitPart = HoldBot.HitPart,
                WallCheck = not HoldBot.TargetBehindWalls,
            }
            target = get_best_target(holdBotConfig)

            if target and HoldBot.UseTargetZone then
                local rootPart = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
                    if dist > HoldBot.TargetZoneDistance then
                        target = nil
                    end
                end
            end

            if HoldBot.PersistentTarget and target then
                holdBotCurrentTarget = target
            end
        end

        if target and target.Position then
            local targetPosition = target.Position

            -- REACTION TIME: Delay aim movement when switching to a new target
            -- This makes the aimbot look human — it doesn't snap instantly
            local now = tick()
            local isNewTarget = (HoldBot._lastTargetSwitch == 0 or target ~= holdBotCurrentTarget)

            if isNewTarget then
                HoldBot._lastTargetSwitch = now + 0.25
                holdBotCurrentTarget = target
            end

            -- Still in reaction delay — don't move aim yet
            if now < HoldBot._lastTargetSwitch then
                return
            end

            if HoldBot.Prediction and target.Parent and target.Parent:FindFirstChild("HumanoidRootPart") then
                local hrp = target.Parent.HumanoidRootPart
                local distance = (camera.CFrame.Position - hrp.Position).Magnitude
                local velocity = hrp.AssemblyLinearVelocity
                local projectileSpeed = 900
                local travelTime = distance / projectileSpeed
                if travelTime > 0 and travelTime <= 0.15 then
                    local dirToTarget = (hrp.Position - camera.CFrame.Position).Unit
                    local lateralVel = velocity - dirToTarget * velocity:Dot(dirToTarget)
                    local scale = 1
                    local t = travelTime
                    if t < 0.04 then
                        scale = 0
                    elseif t < 0.12 then
                        scale = (t - 0.04) / 0.08
                    end
                    targetPosition = targetPosition + lateralVel * travelTime * scale
                elseif travelTime > 0.15 then
                    local predictionFactor = 0.08 * (1 - math.min(0.6, distance / 1000))
                    targetPosition = targetPosition + (velocity * predictionFactor)
                end
            end

            local targetPos = camera:WorldToViewportPoint(targetPosition)
            local mousePos = uis:GetMouseLocation()

            local rawDeltaX = targetPos.X - mousePos.X
            local rawDeltaY = targetPos.Y - mousePos.Y

            if HoldBot.UseSmoothing then
                local sm = math.max(HoldBot.SmoothingValue, 1)

                -- ═══════════════════════════════════════════════════════════
                -- SMOOTHING SYSTEM (rivals-rewrite style + curve)
                -- Based on rivals-rewrite: mousemoverel(delta / divisor)
                -- With custom curve: each level has unique divisor
                -- 1-10: gradual increase (~25% per level)
                -- 10-20: fine increase (~8% per level)
                -- ═══════════════════════════════════════════════════════════

                -- DIVISOR TABLE: higher = slower, lower = faster
                local SMOOTH_DIVISOR = {
                    [1]  = 1.12, [2]  = 1.49, [3]  = 1.96, [4]  = 2.61, [5]  = 3.36,
                    [6]  = 4.39, [7]  = 5.70, [8]  = 7.37, [9]  = 8.86, [10] = 10.23,
                    [11] = 11.07, [12] = 11.90, [13] = 12.83, [14] = 13.86, [15] = 14.91,
                    [16] = 16.18, [17] = 17.50, [18] = 18.88, [19] = 20.37, [20] = 22.06,
                }

                local divisor = SMOOTH_DIVISOR[sm] or 11.0

                -- rivals-rewrite approach: simple division
                local moveX = rawDeltaX / divisor
                local moveY = rawDeltaY / divisor

                -- Jitter (user-controlled)
                local jitterAmount = getgenv().ZX_CustomJitter or 0.008
                moveX = moveX + (math.random() - 0.5) * jitterAmount
                moveY = moveY + (math.random() - 0.5) * jitterAmount

                -- Deadzone
                if math.abs(moveX) < 0.04 then moveX = 0 end
                if math.abs(moveY) < 0.04 then moveY = 0 end

                holdBotPrevX = moveX
                holdBotPrevY = moveY
                if mouseMoveFunc then
                    pcall(function() mouseMoveFunc(moveX, moveY) end)
                end
                        else
                -- No smoothing: still cap speed hard
                local distToTarget = math.sqrt(rawDeltaX * rawDeltaX + rawDeltaY * rawDeltaY)
                local maxSpeed = math.clamp(distToTarget * 0.25, 2, 20)
                local clampedX = math.clamp(rawDeltaX, -maxSpeed, maxSpeed)
                local clampedY = math.clamp(rawDeltaY, -maxSpeed, maxSpeed)
                if mouseMoveFunc then
                    pcall(function() mouseMoveFunc(clampedX, clampedY) end)
                end
            end
        else

            holdBotPrevX = holdBotPrevX * 0.5
            holdBotPrevY = holdBotPrevY * 0.5
            -- Decay velocity state when not tracking
            if HoldBot._velX then HoldBot._velX = HoldBot._velX * 0.5 end
            if HoldBot._velY then HoldBot._velY = HoldBot._velY * 0.5 end
            if HoldBot._lerpRamp then HoldBot._lerpRamp = HoldBot._lerpRamp * 0.5 end
        end
    else

        holdBotPrevX = 0
        holdBotPrevY = 0
        holdBotCurrentTarget = nil
        -- Reset velocity state completely when aimbot inactive
        HoldBot._velX = 0
        HoldBot._velY = 0
        HoldBot._lerpRamp = 0
    end

    local rageActive = false
    if RageMode.Enabled then
        if RageMode.UseKeybind then
            rageActive = (Options.RageModeKey ~= nil) and (Options.RageModeKey:GetState() == true)
        else
            rageActive = true
        end
    end

    if rageActive then
        local target = get_best_target(RageMode)
        if target then
            if RageMode.AimStyle == "Visible" then

                local targetPos, onScreen = camera:WorldToViewportPoint(target.Position)
                if onScreen then
                    local mousePos = uis:GetMouseLocation()
                    local delta = (Vector2.new(targetPos.X, targetPos.Y) - mousePos) * RageMode.AimSpeed
                    delta = Vector2.new(
                        math.clamp(delta.X, -50, 50),
                        math.clamp(delta.Y, -50, 50)
                    )
                    if mouseMoveFunc then
                        pcall(function() mouseMoveFunc(delta.X, delta.Y) end)
                    end
                end
            end

            local now = tick()
            if now - rageLastFire >= RageMode.ClickSpeed then
                rageLastFire = now
                autoFire()
            end
        end
    end

    if RageMode.SpamLock and uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local target = get_best_target(RageMode)
        if target and target.Position then
            local targetPosition = target.Position
            if target.Parent and target.Parent:FindFirstChild("HumanoidRootPart") then
                local hrp = target.Parent.HumanoidRootPart
                local velocity = hrp.AssemblyLinearVelocity
                local distance = (camera.CFrame.Position - hrp.Position).Magnitude
                local projectileSpeed = 900
                local travelTime = distance / projectileSpeed
                if travelTime > 0 and travelTime <= 0.15 then
                    local dirToTarget = (hrp.Position - camera.CFrame.Position).Unit
                    local lateralVel = velocity - dirToTarget * velocity:Dot(dirToTarget)
                    local scale = 1
                    if travelTime < 0.04 then scale = 0
                    elseif travelTime < 0.12 then scale = (travelTime - 0.04) / 0.08 end
                    targetPosition = targetPosition + lateralVel * travelTime * scale
                end
            end
            local targetPos, onScreen = camera:WorldToViewportPoint(targetPosition)
            if onScreen then
                local mousePos = uis:GetMouseLocation()
                local deltaX = targetPos.X - mousePos.X
                local deltaY = targetPos.Y - mousePos.Y
                local sm = 1.5  -- lower = faster (was 3, now 1.5 = ~35% faster response)
                local lerpFactor = 1 - math.exp(-(1 / sm) * deltaTime * 20)
                lerpFactor = math.clamp(lerpFactor, 0, 0.97)
                local moveX = deltaX * lerpFactor
                local moveY = deltaY * lerpFactor
                moveX = math.clamp(moveX, -180, 180)
                moveY = math.clamp(moveY, -180, 180)
                if mouseMoveFunc then
                    pcall(function() mouseMoveFunc(moveX, moveY) end)
                end
            end
        end
    end

    -- (Rage Mode RMB removed per user request)

    if TriggerBot.Enabled then
        local triggerShouldFire = false

        if TriggerBot.Keybind then
            triggerShouldFire = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        else
            triggerShouldFire = true
        end

        if triggerShouldFire then
            -- V13.3: Fast Trigger Bot - raycast from camera through crosshair
            -- Hits ANY body part (Head, Torso, UpperTorso, LeftArm, RightArm, LeftLeg, RightLeg)
            -- Much faster than the old per-part distance check
            local mouseLocation = uis:GetMouseLocation()
            local camPos = camera.CFrame.Position
            local rayDir = (mouseLocation and camera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y).Direction * 5000) or camera.CFrame.LookVector * 5000

            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {lp.Character}
            rp.IgnoreWater = true
            rp.RespectCanCollide = false

            local result = workspace:Raycast(camPos, rayDir, rp)
            local triggerHit = false

            if result and result.Instance then
                -- Check if we hit a player character
                local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                if hitChar then
                    local hitPlr = game:GetService("Players"):GetPlayerFromCharacter(hitChar)
                    if hitPlr and hitPlr ~= lp and not isTeammate(hitPlr) then
                        local hum = hitChar:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            triggerHit = true
                        end
                    end
                end
            end

            -- Fallback: also check via screen-space distance (for edge cases where raycast misses)
            if not triggerHit then
                local crosshairPos = Vector2.new(mouseLocation.X, mouseLocation.Y)
                for _, plr in ipairs(GetCachedPlayers()) do
                    if plr ~= lp and plr.Character and not isTeammate(plr) then
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            -- Check ALL body parts
                            for _, part in ipairs(plr.Character:GetChildren()) do
                                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                    local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                                    if onScreen and pos.Z > 0 then
                                        -- Use part size for dynamic tolerance
                                        local tolerance = math.clamp(part.Size.Magnitude * 2, 8, 30)
                                        local mag = (Vector2.new(pos.X, pos.Y) - crosshairPos).Magnitude
                                        if mag <= tolerance then
                                            triggerHit = true
                                            break
                                        end
                                    end
                                end
                            end
                            if triggerHit then break end
                        end
                    end
                end
            end

            if triggerHit then
                autoFire()
            end
        end
    end

    -- Sniper Mode: ADS -> delay -> fire -> release ADS
    -- Only fires when target is inside the small SniperMode.Threshold
    -- around the crosshair and the cooldown has elapsed.
    if SniperMode.Enabled and not SniperMode.IsFiring then
        local sniperTarget = get_best_target(SilentAim)
        if sniperTarget then
            local screenPos, onScreen = camera:WorldToViewportPoint(sniperTarget.Position)
            if onScreen then
                local mouseLoc = uis:GetMouseLocation()
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
                if dist <= SniperMode.Threshold and (tick() - SniperMode.LastShot) >= SniperMode.Cooldown then
                    SniperMode.IsFiring = true
                    task.spawn(function()
                        -- ADS (right mouse button down)
                        if mouse2press then pcall(mouse2press) end
                        task.wait(SniperMode.Delay)
                        -- Fire (left click)
                        if mouse1click then
                            pcall(mouse1click)
                        elseif mouse1press and mouse1release then
                            pcall(mouse1press)
                            task.wait(0.01)
                            pcall(mouse1release)
                        end
                        task.wait(0.14)
                        -- Release ADS
                        if mouse2release then pcall(mouse2release) end
                        SniperMode.LastShot = tick()
                        task.wait(SniperMode.Cooldown)
                        SniperMode.IsFiring = false
                    end)
                end
            end
        end
    end

    if VisualSettings.CrosshairEnabled then
        ZX_Crosshair.anchor.Visible = true
        local workingColor = VisualSettings.CrosshairColorMode == "Rainbow" and Color3.fromHSV(tick() % 5 / 5, 1, 1) or ZX_Crosshair.presets[VisualSettings.CrosshairColorMode] or Color3.fromRGB(255, 50, 50)
        ZX_Crosshair.cTop.BackgroundColor3 = workingColor; ZX_Crosshair.cBottom.BackgroundColor3 = workingColor; ZX_Crosshair.cLeft.BackgroundColor3 = workingColor; ZX_Crosshair.cRight.BackgroundColor3 = workingColor

        ZX_Crosshair.anchor.Rotation = (ZX_Crosshair.anchor.Rotation + (ZX_Crosshair.SPIN_SPEED * deltaTime)) % 360
        ZX_Crosshair.timePassed = ZX_Crosshair.timePassed + (deltaTime * ZX_Crosshair.PULSE_SPEED)
        local alpha = (math.sin(ZX_Crosshair.timePassed) + 1) / 2
        local currentGap = ZX_Crosshair.MIN_GAP + (alpha * (ZX_Crosshair.MAX_GAP - ZX_Crosshair.MIN_GAP))

        ZX_Crosshair.cTop.Size = UDim2.new(0, ZX_Crosshair.THICKNESS, 0, ZX_Crosshair.BASE_LENGTH); ZX_Crosshair.cTop.Position = UDim2.new(0, 0, 0, -currentGap)
        ZX_Crosshair.cBottom.Size = UDim2.new(0, ZX_Crosshair.THICKNESS, 0, ZX_Crosshair.BASE_LENGTH); ZX_Crosshair.cBottom.Position = UDim2.new(0, 0, 0, currentGap)
        ZX_Crosshair.cLeft.Size = UDim2.new(0, ZX_Crosshair.BASE_LENGTH, 0, ZX_Crosshair.THICKNESS); ZX_Crosshair.cLeft.Position = UDim2.new(0, -currentGap, 0, 0)
        ZX_Crosshair.cRight.Size = UDim2.new(0, ZX_Crosshair.BASE_LENGTH, 0, ZX_Crosshair.THICKNESS); ZX_Crosshair.cRight.Position = UDim2.new(0, currentGap, 0, 0)
    else
        ZX_Crosshair.anchor.Visible = false
    end

    local globalRainbow = Color3.fromHSV(tick() % 5 / 5, 1, 1)
    local boxColor = EspSettings.EspColorMode == "Rainbow" and globalRainbow or ZX_Crosshair.presets[EspSettings.EspColorMode] or Color3.fromRGB(0, 180, 255)
    local filledBoxColor = EspSettings.EspFilledColorMode == "Rainbow" and globalRainbow or ZX_Crosshair.presets[EspSettings.EspFilledColorMode] or Color3.fromRGB(0, 180, 255)
    local chamColor = EspSettings.EspChamsColorMode == "Rainbow" and globalRainbow or ZX_Crosshair.presets[EspSettings.EspChamsColorMode] or Color3.fromRGB(0, 255, 255)

    -- ============================================================
    -- ARROW ESP: Draw triangles pointing at off-screen enemies
    -- ============================================================
    if EspSettings.ArrowESP then
        local mousePos = uis:GetMouseLocation()
        local vp = camera.ViewportSize
        local center = Vector2.new(vp.X / 2, vp.Y / 2)
        local arrowIdx = 0
        for _, v in ipairs(GetCachedPlayers()) do
            if v ~= lp and v.Character and not isTeammate(v) then
                local hum = v.Character:FindFirstChildOfClass("Humanoid")
                local hrp = v.Character:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                    local screenPos = Vector2.new(pos.X, pos.Y)
                    local dist = (screenPos - center).Magnitude
                    -- Only show arrow if enemy is off-screen or outside FOV
                    if not onScreen or dist > SilentAim.FOV then
                        arrowIdx = arrowIdx + 1
                        if not EspSettings._arrows[arrowIdx] then
                            local tri = SafeDrawing.new("Triangle")
                            tri.Thickness = 1
                            tri.Filled = true
                            tri.Color = boxColor
                            tri.Visible = false
                            EspSettings._arrows[arrowIdx] = tri
                        end
                        local arrow = EspSettings._arrows[arrowIdx]
                        local dir = (screenPos - center)
                        if dir.Magnitude > 0 then
                            dir = dir.Unit
                        else
                            dir = Vector2.new(0, -1)
                        end
                        local radius = math.min(vp.X, vp.Y) / 2 - 20
                        local arrowPos = center + dir * radius
                        local perp = Vector2.new(-dir.Y, dir.X)
                        arrow.PointA = arrowPos + dir * 8
                        arrow.PointB = arrowPos - dir * 8 + perp * 8
                        arrow.PointC = arrowPos - dir * 8 - perp * 8
                        arrow.Color = boxColor
                        arrow.Visible = true
                    end
                end
            end
        end
        -- Hide unused arrows
        for i = arrowIdx + 1, #EspSettings._arrows do
            if EspSettings._arrows[i] then
                EspSettings._arrows[i].Visible = false
            end
        end
    else
        -- Hide all arrows when disabled
        for i = 1, #EspSettings._arrows do
            if EspSettings._arrows[i] then
                EspSettings._arrows[i].Visible = false
            end
        end
    end

    for player, cache in pairs(EspRegistry) do
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if rootPart and humanoid and humanoid.Health > 0 then

            local isTeamPlayer = isTeammate(player)
            if isTeamPlayer and EspSettings.TeamCheckESP then

                cache.Box.Visible = false
                cache.FilledBox.Visible = false
                cache.Tracer.Visible = false
                cache.HealthBar.Visible = false
                cache.Tag.Visible = false
                cache.DistTag.Visible = false
                cache.WeaponTag.Visible = false
                if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end
                if SkeletonCache[player] then
                    for _, line in ipairs(SkeletonCache[player]) do
                        line.Visible = false
                    end
                end
            else
            local teamBoxColor = isTeamPlayer and Color3.fromRGB(0, 255, 255) or boxColor
            local teamFilledColor = isTeamPlayer and Color3.fromRGB(0, 200, 200) or filledBoxColor
            local teamChamColor = isTeamPlayer and Color3.fromRGB(0, 255, 255) or chamColor
            local teamGlowColor = isTeamPlayer and Color3.fromRGB(0, 255, 255) or (EspSettings.EspGlowColorMode == "Rainbow" and globalRainbow or ZX_Crosshair.presets[EspSettings.EspGlowColorMode] or Color3.fromRGB(0, 255, 255))
            local screenPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            local distance = (camera.CFrame.Position - rootPart.Position).Magnitude

            if onScreen and distance <= EspSettings.MaxEspDistance and distance >= 1 then
                local sizeX = EspSettings.BoxSizeMultiplier / distance
                local sizeY = sizeX * 1.45
                local boxPosX = screenPos.X - (sizeX / 2)
                local boxPosY = screenPos.Y - (sizeY / 2)

                if EspSettings.EspBoxes then
                    cache.Box.Position = UDim2.new(0, boxPosX, 0, boxPosY)
                    cache.Box.Size = UDim2.new(0, sizeX, 0, sizeY)
                    cache.BoxStroke.Thickness = EspSettings.BoxThickness
                    cache.BoxStroke.Color = teamBoxColor
                    cache.Box.Visible = true
                else cache.Box.Visible = false end

                if EspSettings.EspFilledBoxes then
                    cache.FilledBox.Position = UDim2.new(0, boxPosX, 0, boxPosY)
                    cache.FilledBox.Size = UDim2.new(0, sizeX, 0, sizeY)
                    cache.FilledBox.BackgroundColor3 = teamFilledColor
                    cache.FilledBox.BackgroundTransparency = EspSettings.FilledBoxTransparency
                    cache.FilledBox.Visible = true
                else cache.FilledBox.Visible = false end

                if EspSettings.EspLines then
                    local vSize = camera.ViewportSize
                    local startX, startY = vSize.X / 2, vSize.Y
                    local dx, dy = screenPos.X - startX, screenPos.Y - startY
                    local length = math.sqrt(dx^2 + dy^2)
                    local angle = math.atan2(dy, dx)
                    cache.Tracer.Position = UDim2.new(0, startX + dx/2, 0, startY + dy/2)
                    cache.Tracer.Size = UDim2.new(0, length, 0, EspSettings.LineThickness)
                    cache.Tracer.BackgroundColor3 = teamBoxColor
                    cache.Tracer.Rotation = math.deg(angle)
                    cache.Tracer.Visible = true
                else cache.Tracer.Visible = false end

                if EspSettings.EspHealth then
                    local hPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    cache.HealthBar.Position = UDim2.new(0, boxPosX - HEALTH_BAR_OFFSET - HEALTH_BAR_WIDTH, 0, boxPosY)
                    cache.HealthBar.Size = UDim2.new(0, HEALTH_BAR_WIDTH, 0, sizeY)
                    cache.HealthFill.Size = UDim2.new(1, 0, hPercent, 0)
                    cache.HealthFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50):Lerp(Color3.fromRGB(0, 255, 140), hPercent)
                    cache.HealthBar.Visible = true
                else cache.HealthBar.Visible = false end

                if EspSettings.EspNames then
                    cache.Tag.Position = UDim2.new(0, screenPos.X, 0, boxPosY - 4)
                    cache.Tag.Text = player.DisplayName
                    cache.Tag.TextSize = math.clamp(14 - (distance / 100), 10, 14)
                    cache.Tag.Visible = true
                else cache.Tag.Visible = false end

                if EspSettings.EspDistance then
                    cache.DistTag.Position = UDim2.new(0, screenPos.X, 0, boxPosY + sizeY + 2)
                    cache.DistTag.Text = string.format("%d Studs", math.floor(distance))
                    cache.DistTag.TextSize = math.clamp(12 - (distance / 100), 9, 12)
                    cache.DistTag.Visible = true
                else cache.DistTag.Visible = false end

                if EspSettings.EspChams then
                    if not cache.CurrentCham or cache.CurrentCham.Parent ~= character then
                        if cache.CurrentCham then cache.CurrentCham:Destroy() end

                        local freshHighlight = Instance.new("Highlight")
                        freshHighlight.Name = "NeonEngineStorage"
                        freshHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        freshHighlight.Parent = character
                        cache.CurrentCham = freshHighlight
                    end

                    local neonMultiplier = EspSettings.ChamsBrightness
                    cache.CurrentCham.FillColor = Color3.new(teamChamColor.R * neonMultiplier, teamChamColor.G * neonMultiplier, teamChamColor.B * neonMultiplier)
                    cache.CurrentCham.OutlineColor = Color3.new(teamChamColor.R * neonMultiplier, teamChamColor.G * neonMultiplier, teamChamColor.B * neonMultiplier)
                    -- Apply pulse effect if enabled (sine-wave breathing transparency)
                    if EspSettings.HighlightPulse then
                        -- Use player's UserId for offset so each player pulses out-of-phase
                        local uid = (player and player.UserId) or 0
                        local phase = (math.sin((tick() + uid % 10 * 0.4) * EspSettings.HighlightPulseSpeed * math.pi * 2) * 0.5 + 0.5)
                        local baseFill = 0.2
                        local range = math.clamp(EspSettings.HighlightPulseRange, 0, 0.95)
                        cache.CurrentCham.FillTransparency = baseFill + phase * (range - baseFill)
                        cache.CurrentCham.OutlineTransparency = 0 + phase * range * 0.5
                    else
                        cache.CurrentCham.FillTransparency = 0.2
                        cache.CurrentCham.OutlineTransparency = 0
                    end
                    cache.CurrentCham.Enabled = true
                else
                    if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                end

                if EspSettings.EspGlowChams then
                    if not cache.CurrentGlowCham or cache.CurrentGlowCham.Parent ~= character then
                        if cache.CurrentGlowCham then cache.CurrentGlowCham:Destroy() end
                        local glowHL = Instance.new("Highlight")
                        glowHL.Name = "GlowEngineStorage"
                        glowHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        glowHL.Parent = character
                        cache.CurrentGlowCham = glowHL
                    end
                    local glowMult = EspSettings.GlowBrightness
                    cache.CurrentGlowCham.FillColor = Color3.new(
                        math.clamp(teamGlowColor.R * glowMult, 0, 1),
                        math.clamp(teamGlowColor.G * glowMult, 0, 1),
                        math.clamp(teamGlowColor.B * glowMult, 0, 1)
                    )
                    cache.CurrentGlowCham.OutlineColor = teamGlowColor
                    -- Apply pulse to glow chams too
                    if EspSettings.HighlightPulse then
                        local uid = (player and player.UserId) or 0
                        local phase = (math.sin((tick() + uid % 10 * 0.4) * EspSettings.HighlightPulseSpeed * math.pi * 2) * 0.5 + 0.5)
                        local range = math.clamp(EspSettings.HighlightPulseRange, 0, 0.95)
                        cache.CurrentGlowCham.FillTransparency = 0.5 + phase * (range - 0.5)
                        cache.CurrentGlowCham.OutlineTransparency = phase * range * 0.5
                    else
                        cache.CurrentGlowCham.FillTransparency = 0.5
                        cache.CurrentGlowCham.OutlineTransparency = 0
                    end
                    cache.CurrentGlowCham.Enabled = true
                else
                    if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end
                end

                if EspSettings.EspEnemyWeapons then
                    local weaponName = getEnemyWeaponName(player)
                    cache.WeaponTag.Position = UDim2.new(0, screenPos.X, 0, boxPosY + sizeY + 14)
                    cache.WeaponTag.Text = "[" .. weaponName .. "]"
                    cache.WeaponTag.TextSize = math.clamp(10 - (distance / 120), 8, 10)
                    cache.WeaponTag.Visible = true
                else
                    cache.WeaponTag.Visible = false
                end

                if EspSettings.EspSkeleton then
                    local boneConnections = {}

                    local head = character:FindFirstChild("Head")
                    local torso = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
                    local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm")
                    local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
                    local leftLeg = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftUpperLeg")
                    local rightLeg = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg")
                    local leftLowerArm = character:FindFirstChild("LeftLowerArm")
                    local rightLowerArm = character:FindFirstChild("RightLowerArm")
                    local leftLowerLeg = character:FindFirstChild("LeftLowerLeg")
                    local rightLowerLeg = character:FindFirstChild("RightLowerLeg")

                    if head and torso then
                        table.insert(boneConnections, {head, torso})
                        if leftArm then table.insert(boneConnections, {torso, leftArm}) end
                        if rightArm then table.insert(boneConnections, {torso, rightArm}) end
                        if leftLeg then table.insert(boneConnections, {torso, leftLeg}) end
                        if rightLeg then table.insert(boneConnections, {torso, rightLeg}) end

                        if leftLowerArm and leftArm then table.insert(boneConnections, {leftArm, leftLowerArm}) end
                        if rightLowerArm and rightArm then table.insert(boneConnections, {rightArm, rightLowerArm}) end
                        if leftLowerLeg and leftLeg then table.insert(boneConnections, {leftLeg, leftLowerLeg}) end
                        if rightLowerLeg and rightLeg then table.insert(boneConnections, {rightLeg, rightLowerLeg}) end
                    end

                    if not SkeletonCache[player] then SkeletonCache[player] = {} end
                    local skLines = SkeletonCache[player]
                    while #skLines < #boneConnections do
                        local ok, line = pcall(function() return Drawing.new("Line") end)
                        if ok and line then
                            line.Visible = false
                            line.Color = teamBoxColor
                            line.Thickness = 1.5
                            line.Transparency = 1
                            table.insert(skLines, line)
                        else
                            break
                        end
                    end

                    for i, conn in ipairs(boneConnections) do
                        local line = skLines[i]
                        if line then
                            local from3d, onScreen1 = camera:WorldToViewportPoint(conn[1].Position)
                            local to3d, onScreen2 = camera:WorldToViewportPoint(conn[2].Position)
                            if onScreen1 and onScreen2 then
                                line.From = Vector2.new(from3d.X, from3d.Y)
                                line.To = Vector2.new(to3d.X, to3d.Y)
                                line.Color = teamBoxColor
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        end
                    end

                    for i = #boneConnections + 1, #skLines do
                        if skLines[i] then skLines[i].Visible = false end
                    end
                else

                    if SkeletonCache[player] then
                        for _, line in ipairs(SkeletonCache[player]) do
                            line.Visible = false
                        end
                    end
                end

                if EspSettings.HeadScale > 1 then
                    local head = character:FindFirstChild("Head")
                    if head and head:IsA("BasePart") then
                        if not OriginalHeadSizes[head] then
                            OriginalHeadSizes[head] = head.Size
                        end
                        pcall(function()
                            head.Size = OriginalHeadSizes[head] * EspSettings.HeadScale
                            head.Massless = true
                            head.CanCollide = false
                        end)
                    end
                end
            else
                cache.Box.Visible = false; cache.FilledBox.Visible = false; cache.Tracer.Visible = false; cache.HealthBar.Visible = false; cache.Tag.Visible = false; cache.DistTag.Visible = false; cache.WeaponTag.Visible = false; if cache.CurrentCham then cache.CurrentCham.Enabled = false end; if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end

                if SkeletonCache[player] then
                    for _, line in ipairs(SkeletonCache[player]) do
                        line.Visible = false
                    end
                end
            end
            end
        else
            cache.Box.Visible = false; cache.FilledBox.Visible = false; cache.Tracer.Visible = false; cache.HealthBar.Visible = false; cache.Tag.Visible = false; cache.DistTag.Visible = false; cache.WeaponTag.Visible = false; if cache.CurrentCham then cache.CurrentCham.Enabled = false end; if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end

            if SkeletonCache[player] then
                for _, line in ipairs(SkeletonCache[player]) do
                    line.Visible = false
                end
            end
        end
    end
end)

local function RestoreHeadScales()
    for head, size in pairs(OriginalHeadSizes) do
        if head and head.Parent then
            pcall(function()
                head.Size = size
                head.Massless = false
            end)
        end
    end
    OriginalHeadSizes = {}
end

task.wait(0.1)

local WallbangEngine

uis.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if PlayerSettings.PanicKeyEnabled and input.KeyCode == Enum.KeyCode.P then

        SilentAim.Enabled = false
        SilentAim.ProjectilePrediction = false
        getgenv().silentAimTargetPos = nil
        TriggerBot.Enabled = false
        TriggerBot.LastDetected = 0
        RageMode.Enabled = false
        RageMode.WallCheck = false
        RageMode.Wallbang = false
        if WallbangEngine and WallbangEngine.stop then WallbangEngine:stop() end
        getgenv().silentAimTargetPos = nil
        HoldBot.Enabled = false
        PlayerSettings.SlideBoost = false
        VisualSettings.LockIndicator = false
        lockLabel.Visible = false
        GunMods.MasterEnabled = false
        GunMods.NoRecoil = false
        GunMods.NoSpread = false
        GunMods.RapidFire = false
        GunMods.OneShot = false
        GunMods.InfiniteAmmo = false
        GunMods.InstantReload = false
        GunMods.InstantEquip = false
        GunMods.NoBulletDrop = false
        GunMods.MaxPierce = false
        GunMods.NoCooldowns = false
        GunMods.FireRateMultiplier = 1.0
        GunMods.ZeroSpreadIL = false
        GunMods.ZeroRecoilIL = false

        RageMode.AutoWinEnabled = false
        RageMode.Wallbang = false
        RageMode.AimStyle = "Visible"
        RageMode.AimSpeed = 0.18
        stopAutoWin()

        -- Disable Auto Walk on panic
        PlayerSettings.AutoWalkEnabled = false
        if keyrelease then
                pcall(keyrelease, 87)
                pcall(keyrelease, 65)
                pcall(keyrelease, 83)
                pcall(keyrelease, 68)
                pcall(keyrelease, 32)
        end

        -- Disable Sniper Mode on panic
        SniperMode.Enabled = false
        SniperMode.IsFiring = false
        if mouse2release then pcall(mouse2release) end
        if mouse1release then pcall(mouse1release) end

        stopTeleportKill()

        if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(false) end
        if Toggles.TriggerBotEnabled then Toggles.TriggerBotEnabled:SetValue(false) end
        if Toggles.RageModeEnabled then Toggles.RageModeEnabled:SetValue(false) end
        if Toggles.HoldBotEnabled then Toggles.HoldBotEnabled:SetValue(false) end
        if Toggles.GunModsMaster then Toggles.GunModsMaster:SetValue(false) end
        if Toggles.GunModsZeroSpreadIL then Toggles.GunModsZeroSpreadIL:SetValue(false) end
        if Toggles.GunModsZeroRecoilIL then Toggles.GunModsZeroRecoilIL:SetValue(false) end
        if Options.GunModsFireRateMultiplier then Options.GunModsFireRateMultiplier:SetValue(1.0) end
        if Toggles.AutoWin1v1 then Toggles.AutoWin1v1:SetValue(false) end
        if Toggles.RageWallbang then Toggles.RageWallbang:SetValue(false) end
        if Toggles.RageWallCheck then Toggles.RageWallCheck:SetValue(false) end
        if Toggles.AutoWalkEnabled then Toggles.AutoWalkEnabled:SetValue(false) end
        if Toggles.SniperModeEnabled then Toggles.SniperModeEnabled:SetValue(false) end
        if Toggles.AntiKatanaEnabled then Toggles.AntiKatanaEnabled:SetValue(false) end
        if Toggles.AirStrafeEnabled then Toggles.AirStrafeEnabled:SetValue(false) end
        if Toggles.AutoJumpEnabled then Toggles.AutoJumpEnabled:SetValue(false) end
        if Toggles.BulletTracerEnabled then Toggles.BulletTracerEnabled:SetValue(false) end
        if Toggles.WeaponLatexEnabled then Toggles.WeaponLatexEnabled:SetValue(false) end
        if Toggles.ArmLatexEnabled then Toggles.ArmLatexEnabled:SetValue(false) end
        if Toggles.AntiAimEnabled then Toggles.AntiAimEnabled:SetValue(false) end
        if Toggles.CircleStrafeEnabled then Toggles.CircleStrafeEnabled:SetValue(false) end
        if Toggles.QuickStopEnabled then Toggles.QuickStopEnabled:SetValue(false) end
        if Toggles.ThirdpersonEnabled then Toggles.ThirdpersonEnabled:SetValue(false) end
        if Toggles.FOVOverrideEnabled then Toggles.FOVOverrideEnabled:SetValue(false) end
        if Toggles.WorldColorEnabled then Toggles.WorldColorEnabled:SetValue(false) end
        if Toggles.FogEnabled then Toggles.FogEnabled:SetValue(false) end
        if Toggles.NightModeEnabled then Toggles.NightModeEnabled:SetValue(false) end
        if Options.WeatherType then Options.WeatherType:SetValue("None") end

        holdBotPrevX = 0
        holdBotPrevY = 0
        holdBotCurrentTarget = nil

        if WallbangStealthState then
            WallbangStealthState.enabled = false
        end

        EspSettings.HeadScale = 1.0
        RestoreHeadScales()

        if Options.HeadHitboxScale then Options.HeadHitboxScale:SetValue(1) end

        SAFovRing.Visible = false; SAFovBg.Visible = false
        RageFovRing.Visible = false; RageFovBg.Visible = false
        HoldBotFovRing.Visible = false; HoldBotFovBg.Visible = false

        PlayerSettings.FlyEnabled = false
        stopFly()
        if Toggles.FlyToggle then Toggles.FlyToggle:SetValue(false) end

        PlayerSettings.FullbrightEnabled = false
        setFullbright(false)
        if Toggles.FullbrightToggle then Toggles.FullbrightToggle:SetValue(false) end

        PlayerSettings.AntiRagdollEnabled = false
        setAntiRagdoll(false)
        if Toggles.AntiRagdollToggle then Toggles.AntiRagdollToggle:SetValue(false) end

        PlayerSettings.WalkSpeedEnabled = false
        if Toggles.WalkSpeedEnabled then Toggles.WalkSpeedEnabled:SetValue(false) end

        PlayerSettings.GravityValue = 196
        workspace.Gravity = 196
        if Options.GravitySlider then Options.GravitySlider:SetValue(196) end
    end
end)

rs.Stepped:Connect(function()
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if PlayerSettings.WalkSpeedEnabled then
        pcall(function()
            hum.WalkSpeed = PlayerSettings.WalkSpeed
        end)
    end

    if PlayerSettings.JumpPowerEnabled then
        pcall(function()
            hum.JumpPower = PlayerSettings.JumpPower
        end)
    end

    if PlayerSettings.NoclipEnabled then
        pcall(function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
end)

rs.RenderStepped:Connect(function()

    if PlayerSettings.GravityValue ~= 196 then
        pcall(function()
            workspace.Gravity = PlayerSettings.GravityValue
        end)
    end

    if PlayerSettings.AirWalkEnabled then
        pcall(function()
            local char = lp.Character
            if char then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local velocity = rootPart.AssemblyLinearVelocity
                    if velocity.Y < 0 then
                        rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
                    end
                end
            end
        end)
    end

    if PlayerSettings.SlideBoost then
        pcall(function()
            local char2 = lp.Character
            if char2 then
                local rootPart = char2:FindFirstChild("HumanoidRootPart")
                if rootPart and uis:IsKeyDown(Enum.KeyCode.LeftControl) then
                    local dt = 1/60
                    rootPart.CFrame = rootPart.CFrame + (camera.CFrame.LookVector * PlayerSettings.SlideBoostPower * dt)
                end
            end
        end)
    end

    -- Update velocity history for all enemy players (for smart prediction)
    pcall(function()
        for _, plr in ipairs(GetCachedPlayers()) do
            if plr ~= lp and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    updateVelocityHistory(plr, hrp)
                end
            end
        end
    end)
end)

local walkSpeedHeartbeatConn = nil

local function startWalkSpeedEnforce()
    if walkSpeedHeartbeatConn then return end
    walkSpeedHeartbeatConn = RunService.Heartbeat:Connect(function()
        if PlayerSettings.WalkSpeedEnabled then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum.WalkSpeed = PlayerSettings.WalkSpeed end)
                end
            end
        end
    end)
    -- Protected SpeedHack: hook GetPropertyChangedSignal so server can't reset
    pcall(function()
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local walkConn
                walkConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    if PlayerSettings.WalkSpeedEnabled then
                        pcall(function() hum.WalkSpeed = PlayerSettings.WalkSpeed end)
                    end
                end)
                table.insert(walkSpeedConns or {}, walkConn)
            end
        end
    end)
end

local function stopWalkSpeedEnforce()
    if walkSpeedHeartbeatConn then
        walkSpeedHeartbeatConn:Disconnect()
        walkSpeedHeartbeatConn = nil
    end
end

startWalkSpeedEnforce()

local ProjSpeedCache = {}
local ProjSpeedLoaded = false
local function getProjectileSpeed()
    if ProjSpeedLoaded then return ProjSpeedCache end
    ProjSpeedLoaded = true
    pcall(function()
        local RS = ReplicatedStorage
        local Items = require(RS:WaitForChild("Modules", 5):WaitForChild("ItemLibrary", 5)).Items
        for name, data in pairs(Items) do
            if typeof(data) == "table" and data.ShootProjectileSpeed then
                ProjSpeedCache[name] = data.ShootProjectileSpeed
            end
        end
    end)
    return ProjSpeedCache
end

local function getCurrentWeaponName()
    local char = lp.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    return nil
end

local function calculateProjectilePrediction(targetPos, targetRoot, weaponName, basePrediction)
    if not SilentAim.ProjectilePrediction then return targetPos end
    local speeds = getProjectileSpeed()
    local projSpeed = speeds[weaponName] or 900
    local camPos = camera.CFrame.Position
    local dist = (targetPos - camPos).Magnitude
    if dist <= 0 or projSpeed <= 0 then return targetPos end

    local travelTime = dist / projSpeed

    -- Use smoothed velocity when available (more accurate than raw)
    local targetPlayer = nil
    if targetRoot and targetRoot.Parent then
        for _, plr in ipairs(GetCachedPlayers()) do
            if plr.Character == targetRoot.Parent then
                targetPlayer = plr
                break
            end
        end
    end
    local estVel, estAccel = Vector3.zero, Vector3.zero
    if targetPlayer then
        estVel, estAccel = getSmoothedVelocity(targetPlayer)
    end
    if estVel.Magnitude < 0.01 then
        estVel = targetRoot and targetRoot.AssemblyLinearVelocity or Vector3.zero
    end

    local leadFactor = 1
    if travelTime < 0.04 then
        leadFactor = 0
    elseif travelTime < 0.12 then
        leadFactor = (travelTime - 0.04) / (0.12 - 0.04)
    end

    local dir = (targetPos - camPos)
    local dirUnit = dir.Magnitude > 0 and (dir / dir.Magnitude) or Vector3.zero
    local lateral = estVel - dirUnit * estVel:Dot(dirUnit)

    local predicted = targetPos + lateral * travelTime * leadFactor

    -- Acceleration compensation for fast-changing targets
    if estAccel.Magnitude > 5 and travelTime > 0.04 then
        predicted = predicted + estAccel * 0.5 * travelTime * travelTime * 0.6
    end

    if basePrediction > 0 and targetRoot then
        predicted = predicted + (estVel * basePrediction)
    end
    return predicted
end

local EnemyWeaponCache = {}
local function getEnemyWeaponName(player)
    if EnemyWeaponCache[player] then return EnemyWeaponCache[player] end
    local char = player.Character
    if not char then return "—" end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        EnemyWeaponCache[player] = tool.Name
        return tool.Name
    end
    EnemyWeaponCache[player] = nil
    return "—"
end

task.spawn(function()
    while task.wait(2) do
        if Library.Unloaded then break end
        EnemyWeaponCache = {}
    end
end)

local function FireSpoof(wantedDeviceName)
    local actual = "MouseKeyboard"
    local wanted = DeviceMapping[wantedDeviceName] or "Gamepad"

    local success, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes")
            :WaitForChild("Replication")
            :WaitForChild("Fighter")
            :WaitForChild("SetControls")
    end)

    if success and remote then
        remote:FireServer(actual)
        task.wait(0.3)
        remote:FireServer(wanted)
    end
end

task.spawn(function()
    while task.wait(5) do
        if MiscSettings.SpoofEnabled then
            FireSpoof(MiscSettings.SelectedDevice)
        end
        if Library.Unloaded then break end
    end
end)

getgenv().AutoWinConnection = nil
getgenv().AutoShootConnection = nil

local function applyAutoWinItemLibMods()

    pcall(function()
        local RS = ReplicatedStorage
        local Items = require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)).Items
        local exceptions = {["Sniper"] = true, ["Crossbow"] = true, ["Bow"] = true, ["RPG"] = true}
        for name, data in pairs(Items) do
            if typeof(data) == "table" and not exceptions[name] then
                if data.ShootSpread then data.ShootSpread = 0 end
                if data.ShootAccuracy then data.ShootAccuracy = 0 end
                if data.ShootRecoil then data.ShootRecoil = 0 end
                if data.ShootCooldown then data.ShootCooldown = 0.05 end
                if data.ShootBurstCooldown then data.ShootBurstCooldown = 0.05 end
            end
        end
    end)
end

getgenv().WallbangConnection = nil

WallbangStealthState = {
    enabled = false,
    applied = {},
    debugLog = {},
    statFound = {
        ProjectileWallClipPreventionEnabled = 0,
        RaycastPierceCount = 0,
        RaycastGrabSmallHitboxes = 0,

        WallClipPrevention = 0,
        PierceCount = 0,
        MaxPierce = 0,
        Penetration = 0,
        CanPierce = 0,
        IgnoreWalls = 0,
    },
}

local function wbDebug(msg)
    local entry = string.format("[WB] %s", msg)
    table.insert(WallbangStealthState.debugLog, entry)
    if #WallbangStealthState.debugLog > 20 then
        table.remove(WallbangStealthState.debugLog, 1)
    end

    print(entry)
end

local function applyStealthToItem(name, data)
    if typeof(data) ~= "table" then return false end
    if WallbangStealthState.applied[data] then return false end
    WallbangStealthState.applied[data] = true

    if data.ProjectileWallClipPreventionEnabled ~= nil then
        WallbangStealthState.statFound.ProjectileWallClipPreventionEnabled =
            WallbangStealthState.statFound.ProjectileWallClipPreventionEnabled + 1
    end
    if data.RaycastPierceCount ~= nil then
        WallbangStealthState.statFound.RaycastPierceCount =
            WallbangStealthState.statFound.RaycastPierceCount + 1
    end
    if data.RaycastGrabSmallHitboxes ~= nil then
        WallbangStealthState.statFound.RaycastGrabSmallHitboxes =
            WallbangStealthState.statFound.RaycastGrabSmallHitboxes + 1
    end

    for _, alt in ipairs({"WallClipPrevention", "PierceCount", "MaxPierce", "Penetration", "CanPierce", "IgnoreWalls"}) do
        if data[alt] ~= nil then
            WallbangStealthState.statFound[alt] = WallbangStealthState.statFound[alt] + 1
        end
    end

    local overrides = {

        ProjectileWallClipPreventionEnabled = false,
        RaycastPierceCount = 999,
        RaycastGrabSmallHitboxes = true,

        WallClipPrevention = false,
        PierceCount = 999,
        MaxPierce = 999,
        Penetration = 999,
        CanPierce = true,
        IgnoreWalls = true,

        AlwaysHit = true,
        HitChance = 1.0,

        WallDamageMultiplier = 1.0,
        DamageFalloffPerWall = 0.0,
    }

    local mt = getrawmetatable and getrawmetatable(data)
    local oldIndex = mt and mt.__index
    local oldNewIndex = mt and mt.__newindex

    local hooked = false

    local indexHook = function(t, k)
        if WallbangStealthState.enabled and overrides[k] ~= nil then
            return overrides[k]
        end
        if type(oldIndex) == "function" then
            return oldIndex(t, k)
        end
        return rawget(t, k)
    end

    local newIndexHook = function(t, k, v)
        if WallbangStealthState.enabled and overrides[k] ~= nil then
            return
        end
        if type(oldNewIndex) == "function" then
            return oldNewIndex(t, k, v)
        end
        return rawset(t, k, v)
    end

    if hookmetamethod and getrawmetatable then
        pcall(function()
            hookmetamethod(data, "__index", indexHook)
            hookmetamethod(data, "__newindex", newIndexHook)
            hooked = true
        end)
    end

    if not hooked and setmetatable then
        pcall(function()

            local baseMT = mt or {}
            local newMT = {}
            for k, v in pairs(baseMT) do
                newMT[k] = v
            end
            newMT.__index = indexHook
            newMT.__newindex = newIndexHook
            newMT.__zythera_wallbang = true
            if setmetatable then
                setmetatable(data, newMT)
                hooked = true
            end
        end)
    end

    if not hooked then
        if WallbangStealthState.enabled then
            for k, v in pairs(overrides) do
                if data[k] ~= nil or k == "ProjectileWallClipPreventionEnabled"
                   or k == "RaycastPierceCount" or k == "RaycastGrabSmallHitboxes" then
                    rawset(data, k, v)
                end
            end
        end
    end

    return true
end

local function applyWallbangMods()
    pcall(function()
        local RS = ReplicatedStorage
        local ok, ItemLibrary = pcall(function()
            return require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10))
        end)
        if not ok or not ItemLibrary or not ItemLibrary.Items then
            wbDebug("ItemLibrary.Items not found — wallbang mods skipped")
            return
        end

        local Items = ItemLibrary.Items
        local count = 0
        local itemCount = 0

        for name, data in pairs(Items) do
            if typeof(data) == "table" then
                itemCount = itemCount + 1
                if applyStealthToItem(name, data) then
                    count = count + 1
                end
            end
        end

        wbDebug(string.format(
            "applied stealth to %d/%d items | keys found: WCP=%d RPC=%d RGSH=%d | (alt: WCPv=%d PC=%d MP=%d Pen=%d CP=%d IW=%d)",
            count, itemCount,
            WallbangStealthState.statFound.ProjectileWallClipPreventionEnabled,
            WallbangStealthState.statFound.RaycastPierceCount,
            WallbangStealthState.statFound.RaycastGrabSmallHitboxes,
            WallbangStealthState.statFound.WallClipPrevention,
            WallbangStealthState.statFound.PierceCount,
            WallbangStealthState.statFound.MaxPierce,
            WallbangStealthState.statFound.Penetration,
            WallbangStealthState.statFound.CanPierce,
            WallbangStealthState.statFound.IgnoreWalls
        ))
    end)
end

local function startWallbang()

    WallbangStealthState.enabled = true
    applyWallbangMods()

    if WallbangEngine and WallbangEngine.start then
        WallbangEngine:start()
    else

        task.spawn(function()
            task.wait(1)
            if WallbangEngine and WallbangEngine.start then
                WallbangEngine:start()
            end
        end)
    end
end

local autoWinLastFire = 0

local function startAutoWin()

    SilentAim.Enabled = true
    if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(true) end

    applyAutoWinItemLibMods()

    if getgenv().AutoWinConnection then getgenv().AutoWinConnection = nil end
    if getgenv().AutoShootConnection then getgenv().AutoShootConnection:Disconnect() end

    getgenv().AutoShootConnection = RunService.RenderStepped:Connect(function()
        if not RageMode.AutoWinEnabled then return end
        pcall(function()
            -- Anti-Katana: don't fire if any enemy is deflecting
            if getgenv().ZX_AntiKatanaEnabled and getgenv().ZX_AntiKatanaEnabled() and getgenv().ZX_IsEnemyDeflecting and getgenv().ZX_IsEnemyDeflecting() then
                return
            end

            local camera = workspace.CurrentCamera
            local best = nil
            local shortest = math.huge

            -- Use 3D distance from local player's character (not camera
            -- crosshair). This makes the auto shoot pick the closest
            -- enemy in world space — the one nearest to the player's
            -- body, not the one nearest to the screen center.
            local lpChar = lp.Character
            local lpRoot = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
            local lpPos = lpRoot and lpRoot.Position or camera.CFrame.Position

            for _, plr in ipairs(GetCachedPlayers()) do
                if plr ~= lp and plr.Character and not isTeammate(plr) then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        -- Try Head first, then UpperTorso, then Torso
                        -- (R15 chars may have UpperTorso, R6 has Torso)
                        local hitPart = plr.Character:FindFirstChild("Head")
                            or plr.Character:FindFirstChild("UpperTorso")
                            or plr.Character:FindFirstChild("Torso")
                            or plr.Character:FindFirstChild("HumanoidRootPart")
                        if hitPart then
                            -- 3D distance from local player to this enemy
                            local d3D = (lpPos - hitPart.Position).Magnitude
                            if d3D < shortest then
                                -- Still require target to be on screen so we
                                -- don't fire at enemies we can't even see.
                                local pos, onScreen = camera:WorldToViewportPoint(hitPart.Position)
                                if onScreen and pos.Z > 0 then
                                    shortest = d3D
                                    best = plr
                                end
                            end
                        end
                    end
                end
            end

            if best then
                local now = tick()
                if now - autoWinLastFire >= 0.05 then
                    autoWinLastFire = now
                    autoFire()
                end
            end
        end)
    end)

    getgenv().AutoWinConnection = task.spawn(function()
        while RageMode.AutoWinEnabled do
            applyAutoWinItemLibMods()
            task.wait(2)
        end
    end)

    Library:Notify({
        Title = "Auto Win 1v1",
        Description = "Enabled — Silent Aim + Fire Rate + Auto Shoot ✅",
        Time = 5
    })
end

local function stopAutoWin()

    if getgenv().AutoShootConnection then
        getgenv().AutoShootConnection:Disconnect()
        getgenv().AutoShootConnection = nil
    end
    if getgenv().AutoWinConnection then
        getgenv().AutoWinConnection = nil
    end

    SilentAim.Enabled = false
    if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(false) end

    Library:Notify({
        Title = "Auto Win 1v1",
        Description = "Disabled ❌",
        Time = 4
    })
end

local function findTpTarget(partialName)
    if not partialName or partialName == "" then return nil end
    local lowerName = string.lower(partialName)
    for _, plr in pairs(players:GetPlayers()) do
        if plr ~= lp then
            if string.find(string.lower(plr.Name), lowerName) or string.find(string.lower(plr.DisplayName), lowerName) then
                return plr
            end
        end
    end
    return nil
end

local function startTeleportKill(targetPlayer)
    tpKillTarget = targetPlayer
    TeleportKillSettings.Enabled = true
    if tpKillConnection then tpKillConnection:Disconnect() end
    tpKillConnection = RunService.Heartbeat:Connect(function()
        if not TeleportKillSettings.Enabled or not tpKillTarget then return end
        local myChar = lp.Character
        local targetChar = tpKillTarget.Character
        if myChar and targetChar then
            local myRoot = myChar:FindFirstChild("HumanoidRootPart")
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
            if myRoot and targetRoot then
                myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, TeleportKillSettings.Distance)
            end
        end
    end)
end

local function stopTeleportKill()
    TeleportKillSettings.Enabled = false
    if tpKillConnection then
        tpKillConnection:Disconnect()
        tpKillConnection = nil
    end
end

lp.CharacterAdded:Connect(function()
    task.wait(1)
    if TeleportKillSettings.Enabled and TeleportKillSettings.AutoReconnect and tpKillTarget then
        startTeleportKill(tpKillTarget)
    end
end)

-- Protected SpeedHack: re-hook on respawn
lp.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if PlayerSettings.WalkSpeedEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.WalkSpeed = PlayerSettings.WalkSpeed end)
            hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if PlayerSettings.WalkSpeedEnabled then
                    pcall(function() hum.WalkSpeed = PlayerSettings.WalkSpeed end)
                end
            end)
        end
    end
end)

do
local ItemLibBackup = {}
local ItemLibLoaded = false

task.spawn(function()
    task.wait(5)
    local RS = ReplicatedStorage
    local success, Items = pcall(function()
        return require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)).Items
    end)
    if not success or not Items then return end
    ItemLibLoaded = true

    for name, data in pairs(Items) do
        if typeof(data) == "table" then
            ItemLibBackup[name] = {
                ShootCooldown = data.ShootCooldown,
                ShootBurstCooldown = data.ShootBurstCooldown,
                ShootSpread = data.ShootSpread,
                ShootAccuracy = data.ShootAccuracy,
                ShootRecoil = data.ShootRecoil,
            }
        end
    end

    local exceptions = { ["Sniper"] = true, ["Crossbow"] = true, ["Bow"] = true, ["RPG"] = true }

    local function applyItemLibMods()
        for name, data in pairs(Items) do
            if typeof(data) == "table" and not exceptions[name] and ItemLibBackup[name] then

                if GunMods.MasterEnabled and GunMods.RapidFire and GunMods.FireRateMultiplier ~= 1.0 then
                    if data.ShootCooldown and ItemLibBackup[name].ShootCooldown then
                        data.ShootCooldown = ItemLibBackup[name].ShootCooldown * GunMods.FireRateMultiplier
                    end
                    if data.ShootBurstCooldown and ItemLibBackup[name].ShootBurstCooldown then
                        data.ShootBurstCooldown = ItemLibBackup[name].ShootBurstCooldown * GunMods.FireRateMultiplier
                    end
                end

                if GunMods.MasterEnabled and GunMods.ZeroSpreadIL then
                    if data.ShootSpread then data.ShootSpread = 0 end
                    if data.ShootAccuracy then data.ShootAccuracy = 0 end
                end

                if GunMods.MasterEnabled and GunMods.ZeroRecoilIL then
                    if data.ShootRecoil then data.ShootRecoil = 0 end
                end
            end
        end
    end

    while true do
        if GunMods.MasterEnabled and (GunMods.RapidFire or GunMods.ZeroSpreadIL or GunMods.ZeroRecoilIL) then
            pcall(applyItemLibMods)
        end
        if Library.Unloaded then break end
        task.wait(2)
    end
end)

do

local RageTracer = Drawing.new("Line")
RageTracer.Visible = false
RageTracer.Color = Color3.fromRGB(255, 50, 50)
RageTracer.Thickness = 1
RageTracer.Transparency = 1

local RageTracerBeamPart = Instance.new("Part")
RageTracerBeamPart.Name = "RageTracerBeam"
RageTracerBeamPart.Anchored = true
RageTracerBeamPart.CanCollide = false
RageTracerBeamPart.CanQuery = false
RageTracerBeamPart.CastShadow = false
RageTracerBeamPart.Material = Enum.Material.Neon
RageTracerBeamPart.Color = Color3.fromRGB(255, 50, 50)
RageTracerBeamPart.Transparency = 1
RageTracerBeamPart.Size = Vector3.new(0.15, 0.15, 1)

RageTracerBeamPart.Parent = nil

local RAGE_TRACER_DURATION = 0.4
rageTracerShowUntil = 0

uis.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if RageMode.Enabled and RageMode.ShowTracer then
            rageTracerShowUntil = tick() + RAGE_TRACER_DURATION
        end
    end
end)

local function getTracerOrigin3D()
    local camPos = camera.CFrame.Position
    local lpChar = lp.Character
    if lpChar then
        local head = lpChar:FindFirstChild("Head")
        if head then

            return head.Position
        end
    end
    return camPos
end

local function positionBeamBetween(p1, p2, color3, thickness)
    if not p1 or not p2 then return end
    local dist = (p2 - p1).Magnitude
    if dist < 0.1 then return end
    local mid = (p1 + p2) * 0.5
    local lookAt = p2
    local cf = CFrame.lookAt(mid, lookAt)
    RageTracerBeamPart.CFrame = cf
    RageTracerBeamPart.Size = Vector3.new(thickness, thickness, dist)
    RageTracerBeamPart.Color = color3
    RageTracerBeamPart.Parent = workspace
end

task.spawn(function()
    while true do
        local now = tick()

        local autoShootActive = false
        local manualActive = now < rageTracerShowUntil
        local shouldShow = RageMode.Enabled and RageMode.ShowTracer and (autoShootActive or manualActive)

        if shouldShow then
            local target = get_best_target(RageMode)
            if target and target.Parent and target.Position then
                local targetWorld = target.Position
                local targetPos2D, onScreen = camera:WorldToViewportPoint(targetWorld)

                if onScreen then
                    local startPos2D
                    if RageMode.TracerStart == "Cursor" then
                        startPos2D = uis:GetMouseLocation()
                    elseif RageMode.TracerStart == "Bottom" then
                        startPos2D = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                    else
                        startPos2D = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                    end
                    RageTracer.From = startPos2D
                    RageTracer.To = Vector2.new(targetPos2D.X, targetPos2D.Y)
                    RageTracer.Color = RageMode.TracerColor
                    RageTracer.Thickness = RageMode.TracerThickness

                    if autoShootActive then
                        RageTracer.Transparency = 1
                    else
                        local remaining = rageTracerShowUntil - now
                        local alpha = math.clamp(remaining / RAGE_TRACER_DURATION, 0, 1)
                        RageTracer.Transparency = 1 - alpha
                    end
                    RageTracer.Visible = true
                else
                    RageTracer.Visible = false
                end

                local origin3D = getTracerOrigin3D()
                positionBeamBetween(origin3D, targetWorld, RageMode.TracerColor, math.max(RageMode.TracerThickness * 0.1, 0.1))
                if autoShootActive then
                    RageTracerBeamPart.Transparency = 0.2
                else
                    local remaining = rageTracerShowUntil - now
                    local alpha = math.clamp(remaining / RAGE_TRACER_DURATION, 0, 1)
                    RageTracerBeamPart.Transparency = 1 - alpha * 0.7
                end
            else
                RageTracer.Visible = false
                RageTracerBeamPart.Parent = nil
            end
        else
            RageTracer.Visible = false
            RageTracerBeamPart.Parent = nil
        end
        task.wait(0.02)
    end
end)

------------------------------------------------------------------
-- ANTI RIOT KATANA (Advanced — based on rivals-rewrite approach)
-- 3-tier detection system:
--   Tier 1: ReplicateFromServer hook (EARLY WARNING — fires before
--           particles appear, using cached DeflectDuration per item)
--   Tier 2: FighterController Entity.RootPart particle check
--   Tier 3: HRP _katana_deflect_active_not_local particle check
-- Plus: raycast visibility check — only blocks when enemy is visible
--       (so we don't waste blocks on enemies behind walls)
-- Sends notifications on deflect start/stop.
-- Blocks Silent Aim + Rage Bot redirect while any visible enemy deflects.
------------------------------------------------------------------
task.spawn(function()
local AntiKatana = {
    Enabled = false,
    _wasDeflecting = false,
    _lastNotifyTime = 0,
    -- Early-warning cache: player -> expiry tick
    -- Set by ReplicateFromServer hook, used BEFORE particles appear
    _deflectCache = {},
    -- Per-item DeflectDuration map: itemName -> duration (seconds)
    _itemDurations = {},
    -- Per-player hooked EquippedItem tracking (avoid double-hooking)
    _hookedItems = {},
    -- Per-player currently-deflecting status (for notifications)
    _playerStatus = {},
}

-- ============================================================
-- MODULE ACCESS (cached lazily)
-- ============================================================
local _fighterCtrl = nil
local _itemLib = nil

local function getFighterController()
    if _fighterCtrl then return _fighterCtrl end
    pcall(function()
        local ps = lp:WaitForChild("PlayerScripts", 5)
        local ctrl = ps:WaitForChild("Controllers", 5)
        _fighterCtrl = require(ctrl:WaitForChild("FighterController", 5))
    end)
    return _fighterCtrl
end

local function getItemLibrary()
    if _itemLib then return _itemLib end
    pcall(function()
        _itemLib = require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("ItemLibrary", 5))
    end)
    return _itemLib
end

-- ============================================================
-- ITEM DURATION CACHE: build map of itemName -> DeflectDuration
-- Called once when Anti-Katana is enabled, refreshed every 10s
-- ============================================================
local function refreshItemDurations()
    local lib = getItemLibrary()
    if not lib then return end
    pcall(function()
        -- ItemLibrary.Items is a table of item instances
        local items = lib.Items or lib.items or lib
        for name, item in pairs(items) do
            if type(item) == "table" then
                -- Check multiple possible deflect duration field names
                local dur = item.DeflectDuration
                    or item.DeflectTime
                    or item.BlockDuration
                    or item.ParryDuration
                if dur and type(dur) == "number" then
                    AntiKatana._itemDurations[name] = dur
                end
                -- Also check if item is a katana-type (has deflect ability)
                if item.IsKatana or item.IsRiotKatana or item.IsDeflectable then
                    AntiKatana._itemDurations[name] = AntiKatana._itemDurations[name] or 1
                end
            end
        end
    end)
end

-- ============================================================
-- NEW ANTI-KATANA DETECTION (primesto.fx style - ViewModels based)
-- Simpler and more reliable than particle detection.
-- Detects if enemy is holding a katana-type weapon by parsing
-- the ViewModels folder, then checks distance + facing direction.
-- ============================================================

-- Get the weapon name a player is currently holding
-- ViewModels in Rivals stores models named like "PlayerName - Weapon - WeaponName"
local function getEnemyHeldWeaponName(player)
    if not player then return nil end
    local vms = workspace:FindFirstChild("ViewModels")
    if not vms then return nil end
    for _, m in ipairs(vms:GetChildren()) do
        if m:IsA("Model") then
            local parts = string.split(m.Name, " - ")
            if #parts >= 1 and parts[1] == player.Name then
                -- Weapon name is the 3rd part (or 2nd if no separator)
                if #parts >= 3 then return parts[3] end
                if #parts >= 2 then return parts[2] end
                return m.Name
            end
        end
    end
    return nil
end

-- Check if a weapon name is a katana-type (deflect-capable)
local function isKatanaWeaponName(weaponName)
    if not weaponName then return false end
    local lname = string.lower(weaponName)
    -- Common katana-type weapon keywords in Rivals
    if string.find(lname, "katana") then return true end
    if string.find(lname, "sword") then return true end
    if string.find(lname, "blade") then return true end
    if string.find(lname, "sabre") or string.find(lname, "saber") then return true end
    return false
end

-- VISIBILITY CHECK: raycast from local HRP to enemy target part
local function isEnemyVisible(targetChar)
    local lpChar = lp.Character
    if not lpChar then return false end
    local lpHrp = lpChar:FindFirstChild("HumanoidRootPart")
    if not lpHrp then return false end
    local targetHead = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHead then return false end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { lpChar }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local origin = lpHrp.Position
    local dir = (targetHead.Position - origin)
    local result = workspace:Raycast(origin, dir, params)
    if not result then return true end
    if result.Instance and result.Instance:IsDescendantOf(targetChar) then
        return true
    end
    return false
end

-- ============================================================
-- MAIN CHECK: Is a SPECIFIC player currently deflecting?
-- New approach: enemy is "deflecting" if they hold a katana-type
-- weapon, are within 30 studs, and facing us.
-- ============================================================
local function isPlayerDeflecting(player)
    if not player or player == lp then return false end
    if not player.Character then return false end
    local pChar = player.Character
    local hum = pChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if isTeammate(player) then return false end

    -- Get the weapon this player is holding
    local weaponName = getEnemyHeldWeaponName(player)
    if not weaponName then return false end

    -- Check if it's a katana-type weapon
    if not isKatanaWeaponName(weaponName) then return false end

    -- Check distance - katana deflect range is short (~25-30 studs)
    local lpChar = lp.Character
    if not lpChar then return false end
    local lpHrp = lpChar:FindFirstChild("HumanoidRootPart")
    local pHrp = pChar:FindFirstChild("HumanoidRootPart")
    if not lpHrp or not pHrp then return false end

    local dist = (lpHrp.Position - pHrp.Position).Magnitude
    if dist > 35 then return false end  -- out of katana range

    -- Check if enemy is facing us (they need to face us to deflect)
    local dir = (lpHrp.Position - pHrp.Position)
    if dir.Magnitude > 0 then
        local forward = pHrp.CFrame.LookVector
        if forward:Dot(dir.Unit) < 0.2 then return false end  -- not facing us enough
    end

    return true
end

-- ============================================================
-- CHECK: Is any VISIBLE enemy deflecting?
-- (only blocks when we'd actually shoot at them)
-- ============================================================
local function isAnyVisibleEnemyDeflecting()
    if not AntiKatana.Enabled then return false, nil end
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= lp and p.Character then
            if isPlayerDeflecting(p) then
                if isEnemyVisible(p.Character) then
                    return true, p.Name
                end
            end
        end
    end
    return false, nil
end

-- Keep refreshItemDurations + hookEquippedItems as no-ops (called elsewhere)
local function refreshItemDurations() end
local function hookEquippedItems() end

-- ============================================================
-- NOTIFICATION LOOP: notify on deflect start/stop
-- ============================================================
task.spawn(function()
    while true do
        if AntiKatana.Enabled then
            local deflecting, deflectName = isAnyVisibleEnemyDeflecting()

            -- Started deflecting
            if deflecting and not AntiKatana._wasDeflecting then
                AntiKatana._wasDeflecting = true
                local now = tick()
                if now - AntiKatana._lastNotifyTime > 1 then
                    AntiKatana._lastNotifyTime = now
                    if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Anti Katana", deflectName .. " is deflecting! Shots blocked.", "warning")
                    end
                end
            -- Stopped deflecting
            elseif not deflecting and AntiKatana._wasDeflecting then
                AntiKatana._wasDeflecting = false
                local now = tick()
                if now - AntiKatana._lastNotifyTime > 1 then
                    AntiKatana._lastNotifyTime = now
                    if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Anti Katana", "Deflect ended. Shots resumed.", "success")
                    end
                end
            end
        end
        task.wait(0.1)  -- faster polling for responsive notifications
    end
end)

RageModeGroup:AddToggle("AntiKatanaEnabled", {
        Text = "Anti Katana (ViewModel Detect)",
        Default = false,
        Tooltip = "ViewModels-based katana detection (primesto.fx style):\n1. Reads enemy held weapon from ViewModels folder\n2. Checks if it's a katana/sword/blade type\n3. Verifies enemy is within 35 studs AND facing you\n4. Blocks Silent Aim/Rage Bot shots at deflecting enemies\n5. Shows top warning when enemy holds katana nearby\nAlso pauses ALL features while enemy deflects.",
})
Toggles.AntiKatanaEnabled:OnChanged(function()
        AntiKatana.Enabled = Toggles.AntiKatanaEnabled.Value
        if AntiKatana.Enabled then
                -- Build item duration cache immediately on enable
                refreshItemDurations()
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Anti Katana", "Enabled — ViewModels detection active.", "success")
                end
        else
                -- Clear all caches on disable
                AntiKatana._deflectCache = {}
                AntiKatana._hookedItems = {}
                AntiKatana._wasDeflecting = false
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Anti Katana", "Disabled", "warning")
                end
        end
end)

-- Expose the check so it can be used in the raycast hook
-- Use the NON-visibility version (check ALL enemies, not just visible ones)
getgenv().ZX_IsEnemyDeflecting = function()
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= lp and isPlayerDeflecting(p) then
                return true
            end
        end
        return false
end

-- Also expose a version that returns the player name
getgenv().ZX_IsAnyEnemyDeflecting = function()
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= lp and isPlayerDeflecting(p) then
                return true, p.Name
            end
        end
        return false, nil
end

-- SMART ANTI-KATANA: When any enemy deflects, disable ALL script features temporarily
getgenv().ZX_AntiKatanaPause = false  -- global pause flag

task.spawn(function()
    local wasDeflecting = false
    while true do
        task.wait(0.1)
        if AntiKatana.Enabled then
            local deflecting, deflectName = false, nil
            for _, p in ipairs(players:GetPlayers()) do
                if p ~= lp and isPlayerDeflecting(p) then
                    deflecting = true
                    deflectName = p.Name
                    break
                end
            end
            
            if deflecting and not wasDeflecting then
                -- Enemy STARTED deflecting
                wasDeflecting = true
                getgenv().ZX_AntiKatanaPause = true
                if getgenv().ZX_Notify then
                    getgenv().ZX_Notify("Anti Katana", deflectName .. " is deflecting! All features paused.", "warning")
                end
            elseif not deflecting and wasDeflecting then
                -- Enemy STOPPED deflecting
                wasDeflecting = false
                getgenv().ZX_AntiKatanaPause = false
                if getgenv().ZX_Notify then
                    getgenv().ZX_Notify("Anti Katana", "Deflect ended. All features resumed.", "success")
                end
            end
        else
            getgenv().ZX_AntiKatanaPause = false
            wasDeflecting = false
        end
    end
end)

getgenv().ZX_AntiKatanaEnabled = function() return AntiKatana.Enabled end
end)

RageModeGroup:AddToggle("RageBotEnable", {
        Text = "Rage Bot Enable",
        Default = RageMode.Enabled,
        Tooltip = "Master toggle for Rage Bot. Turn this ON first, then configure other settings below. Turning it OFF stops Wallbang, Spam Lock, Rage Mode, and Auto Shoot.",
})
Toggles.RageBotEnable:OnChanged(function()
        RageMode.Enabled = Toggles.RageBotEnable.Value
        if RageMode.Enabled then
            -- Auto-enable ALL weapon modifications when Rage Bot is turned ON
            task.spawn(function()
                task.wait(0.1)
                pcall(function() if Toggles.GunModsMaster and not Toggles.GunModsMaster.Value then Toggles.GunModsMaster:SetValue(true) end end)
                task.wait(0.05)
                pcall(function() if Toggles.GunModsNoRecoil and not Toggles.GunModsNoRecoil.Value then Toggles.GunModsNoRecoil:SetValue(true) end end)
                pcall(function() if Toggles.GunModsNoSpread and not Toggles.GunModsNoSpread.Value then Toggles.GunModsNoSpread:SetValue(true) end end)
                pcall(function() if Toggles.GunModsRapidFire and not Toggles.GunModsRapidFire.Value then Toggles.GunModsRapidFire:SetValue(true) end end)
                pcall(function() if Toggles.GunModsOneShot and not Toggles.GunModsOneShot.Value then Toggles.GunModsOneShot:SetValue(true) end end)
                pcall(function() if Toggles.GunModsInfAmmo and not Toggles.GunModsInfAmmo.Value then Toggles.GunModsInfAmmo:SetValue(true) end end)
                pcall(function() if Toggles.GunModsInstantReload and not Toggles.GunModsInstantReload.Value then Toggles.GunModsInstantReload:SetValue(true) end end)
                pcall(function() if Toggles.GunModsInstantEquip and not Toggles.GunModsInstantEquip.Value then Toggles.GunModsInstantEquip:SetValue(true) end end)
                pcall(function() if Toggles.GunModsNoBulletDrop and not Toggles.GunModsNoBulletDrop.Value then Toggles.GunModsNoBulletDrop:SetValue(true) end end)
                pcall(function() if Toggles.GunModsMaxPierce and not Toggles.GunModsMaxPierce.Value then Toggles.GunModsMaxPierce:SetValue(true) end end)
                pcall(function() if Toggles.GunModsNoCooldowns and not Toggles.GunModsNoCooldowns.Value then Toggles.GunModsNoCooldowns:SetValue(true) end end)
                pcall(function() if Toggles.GunModWalkSpeed and not Toggles.GunModWalkSpeed.Value then Toggles.GunModWalkSpeed:SetValue(true) end end)
            end)
        else
            if RageMode.Wallbang then
                RageMode.Wallbang = false
                pcall(function() WallbangEngine:stop() end)
                if Toggles.RageWallbang then Toggles.RageWallbang:SetValue(false) end
            end
            if RageMode.SpamLock then
                RageMode.SpamLock = false
                if Toggles.SpamLockEnabled then Toggles.SpamLockEnabled:SetValue(false) end
            end
            RageTracer.Visible = false
            RageTracerBeamPart.Parent = nil
            rageTracerShowUntil = 0
        end
end)

RageModeGroup:AddToggle("SpamLockEnabled", {
        Text = "Spam Lock (LMB)",
        Default = false,
        Tooltip = "Hold LEFT MOUSE BUTTON for smooth aimbot that tracks enemy heads. Range limited to 500 studs. Requires Rage Bot Enable to be ON.",
})
Toggles.SpamLockEnabled:OnChanged(function()
        RageMode.SpamLock = Toggles.SpamLockEnabled.Value
        -- Auto-enable Rage Bot when Spam Lock is turned on
        if RageMode.SpamLock and not RageMode.Enabled then
                RageMode.Enabled = true
                if Toggles.RageBotEnable then Toggles.RageBotEnable:SetValue(true) end
        end
end)

RageModeGroup:AddToggle("RageUseFOV", {
        Text = "Use FOV (Legit Rage)",
        Default = RageMode.UseFOV,
        Tooltip = "When ON: Rage Mode only targets players within the FOV circle (more legit). When OFF: targets entire screen (classic rage).",
})
Toggles.RageUseFOV:OnChanged(function()
        RageMode.UseFOV = Toggles.RageUseFOV.Value

        if RageMode.UseFOV then
            RageMode.FOV = Options.RageFOVRadius and Options.RageFOVRadius.Value or 250
        else
            RageMode.FOV = math.huge
        end
end)

RageModeGroup:AddToggle("RageShowFOV", {
        Text = "Show FOV Circle",
        Default = false,
        Tooltip = "Show/hide the red FOV circle for Rage Mode. Only visible when Use FOV is enabled.",
})
Toggles.RageShowFOV:OnChanged(function()
        RageMode.FovVisible = Toggles.RageShowFOV.Value
end)

RageModeGroup:AddToggle("RageFillFOV", {
        Text = "Filled FOV Circle",
        Default = false,
        Tooltip = "Fill the FOV circle with transparent color (only when Show FOV is on).",
})
Toggles.RageFillFOV:OnChanged(function()
        RageMode.FovFilled = Toggles.RageFillFOV.Value
end)

RageControlGroup:AddLabel("FOV Circle Color"):AddColorPicker("RageFovColor", {
        Default = Color3.fromRGB(255, 0, 0),
        Title = "Rage Mode FOV Color",
})
Options.RageFovColor:OnChanged(function()
        RageMode.FovColor = Options.RageFovColor.Value
        RageMode.FovRainbow = false
end)

RageControlGroup:AddToggle("RageFovRainbow", {
        Text = "Rainbow FOV Color",
        Default = false,
})
Toggles.RageFovRainbow:OnChanged(function()
        RageMode.FovRainbow = Toggles.RageFovRainbow.Value
end)

RageControlGroup:AddSlider("RageFOVRadius", {
        Text = "Rage FOV Radius",
        Default = 250,
        Min = 50,
        Max = 1000,
        Rounding = 0,
        Tooltip = "FOV radius for Rage Mode (only applies when Use FOV is enabled)",
})
Options.RageFOVRadius:OnChanged(function()
        if RageMode.UseFOV then
            RageMode.FOV = Options.RageFOVRadius.Value
        end
end)

RageModeGroup:AddToggle("RageWallbang", {
        Text = "Wallbang (Ultimate)",
        Default = RageMode.Wallbang,
        Tooltip = "Combined wallbang: Desync + Shot Data Hook + FighterController hooks. Bullets/melees always hit enemy regardless of walls. Requires Rage Bot Enable to be ON.",
})
Toggles.RageWallbang:OnChanged(function()

        if Toggles.RageWallbang.Value and not RageMode.Enabled then
            Toggles.RageWallbang:SetValue(false)
            if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Rage Bot", "Enable Rage Bot first!", "warning")
            end
            return
        end
        RageMode.Wallbang = Toggles.RageWallbang.Value
        if RageMode.Wallbang and RageMode.Enabled then
            startWallbang()
            -- Enable Enhanced Wallbang (FighterController hooks) automatically
            if getgenv().ZX_EnhancedWB then
                getgenv().ZX_EnhancedWB.Enabled = true
            end
            if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Wallbang", "Ultimate wallbang enabled — bullets pierce all walls.", "success")
            end
        else
            if WallbangEngine and WallbangEngine.stop then
                WallbangEngine:stop()
            end
            if getgenv().ZX_EnhancedWB then
                getgenv().ZX_EnhancedWB.Enabled = false
            end
            if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Wallbang", "Disabled.", "warning")
            end
        end
end)

RageModeGroup:AddToggle("RageShowTracer", {
        Text = "Bullet Tracer",
        Default = true,
        Tooltip = "Automatically draws a tracer line from your cursor to the target whenever you click/fire. Works for both manual fire and Auto Shoot.",
})
Toggles.RageShowTracer:OnChanged(function()
        RageMode.ShowTracer = Toggles.RageShowTracer.Value
        if not RageMode.ShowTracer then
            RageTracer.Visible = false
        end
end)

-- ============================================================
-- AUTO SHOOT (simple spam-fire with keybind)
-- ============================================================
getgenv().ZX_AutoShootSimple = getgenv().ZX_AutoShootSimple or {
    Enabled = false,
    Active = false,
    Thread = nil,
    WallCheck = true,
    _lastWallCheck = 0,
}

getgenv()._ZX_SetupAutoShootSimple = function()
    local AutoShootSimple = getgenv().ZX_AutoShootSimple

    local function autoShootHasVisibleTarget()
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local camPos = cam.CFrame.Position
    local playerList = GetCachedPlayers()
    local lpChar = lp.Character

    local HIT_PARTS = {"HitboxHead", "PhysicalHitboxHead", "Head", "UpperTorso", "HumanoidRootPart"}
    local foundVisible = false

    for _, p in ipairs(playerList) do
        if p ~= lp and p.Character and not isTeammate(p) then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hitPart = nil
                for _, partName in ipairs(HIT_PARTS) do
                    hitPart = p.Character:FindFirstChild(partName)
                    if hitPart and hitPart:IsA("BasePart") then break end
                end
                if hitPart then
                    local partPos = hitPart.Position
                    local direction = partPos - camPos
                    local dist3D = direction.Magnitude
                    if dist3D < 1500 then  -- within range
                        local filterList = { lpChar }
                        for _, otherPlr in ipairs(playerList) do
                            if otherPlr ~= lp and otherPlr ~= p and otherPlr.Character then
                                filterList[#filterList + 1] = otherPlr.Character
                            end
                        end
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        rayParams.FilterDescendantsInstances = filterList
                        rayParams.IgnoreWater = true
                        rayParams.RespectCanCollide = true
                        local result = workspace:Raycast(camPos, direction, rayParams)
                        if result and result.Instance and result.Instance:IsA("BasePart") then
                            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                            if hitChar == p.Character then
                                -- Enemy is visible (no wall between us)
                                foundVisible = true
                                break
                            end
                        else
                            -- No hit = clear line of sight
                            foundVisible = true
                            break
                        end
                    end
                end
            end
        end
        if foundVisible then break end
    end
    return foundVisible
end

function AutoShootSimple.startLoop()
    if AutoShootSimple.Active then return end
    AutoShootSimple.Active = true
    AutoShootSimple.Thread = task.spawn(function()
        while AutoShootSimple.Active do
            local hasInput = false

            -- WALL CHECK: if enabled, only fire when enemy is visible (not behind wall)
            if AutoShootSimple.WallCheck then
                local now = tick()
                -- Throttle wall check to every 50ms (20 checks/sec)
                if now - (AutoShootSimple._lastWallCheck or 0) >= 0.05 then
                    AutoShootSimple._lastWallCheck = now
                    AutoShootSimple._hasVisibleTarget = autoShootHasVisibleTarget()
                end
                -- If no visible target, don't fire
                if not AutoShootSimple._hasVisibleTarget then
                    task.wait(0.05)
                    continue
                end
            end

            pcall(function()
                if mouse1press and mouse1release then
                    hasInput = true
                    mouse1press()
                    task.wait(0.025)
                    mouse1release()
                    task.wait(0.020)
                elseif mouse1click then
                    hasInput = true
                    mouse1click()
                    task.wait(0.045)
                end
            end)
            if not hasInput then
                AutoShootSimple.Active = false
                return
            end
            task.wait(0.001)
        end
    end)
end

function AutoShootSimple.stopLoop()
    AutoShootSimple.Active = false
    pcall(function()
        if mouse1release then mouse1release() end
    end)
end
end
getgenv()._ZX_SetupAutoShootSimple()

RageModeGroup:AddToggle("AutoShootSimple", {
        Text = "Auto Shoot",
        Default = false,
        Tooltip = "Spam-fires at MAX SPEED. Press E (keybind) to fire. Wall Check ON = won't fire if enemy is behind a wall. Requires Rage Bot Enable to be ON.",
})
Toggles.AutoShootSimple:OnChanged(function()
        local AS = getgenv().ZX_AutoShootSimple
        if Toggles.AutoShootSimple.Value and not RageMode.Enabled then
            Toggles.AutoShootSimple:SetValue(false)
            if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Rage Bot", "Enable Rage Bot first!", "warning")
            end
            return
        end
        AS.Enabled = Toggles.AutoShootSimple.Value
        if not AS.Enabled and AS.Active then
            AS.stopLoop()
        end
end)

RageModeGroup:AddToggle("AutoShootWallCheck", {
        Text = "Auto Shoot Wall Check",
        Default = true,
        Tooltip = "When ON: Auto Shoot only fires when enemy is visible (not behind wall). When OFF: fires regardless of walls (needs Wallbang for bullets to hit).",
})
Toggles.AutoShootWallCheck:OnChanged(function()
        getgenv().ZX_AutoShootSimple.WallCheck = Toggles.AutoShootWallCheck.Value
end)

RageModeGroup:AddLabel("Auto Shoot Key"):AddKeyPicker("AutoShootSimpleKey", {
        Default = "E",
        SyncToggleState = false,
        Mode = "Toggle",
        NoUI = false,
        Text = "Auto Shoot keybind",
})

RunService.Heartbeat:Connect(function()
    if not Options.AutoShootSimpleKey then return end
    local AS = getgenv().ZX_AutoShootSimple
    local ok, keyState = pcall(function() return Options.AutoShootSimpleKey:GetState() end)
    if not ok then return end
    local canFire = RageMode.Enabled and AS.Enabled and keyState
    if canFire and not AS.Active then
        AS.startLoop()
    elseif not canFire and AS.Active then
        AS.stopLoop()
    end
end)

RageControlGroup:AddDropdown("RageTracerStart", {
        Text = "Tracer Start",
        Values = {"Cursor", "Bottom", "Center"},
        Default = 1,
        Multi = false,
})
Options.RageTracerStart:OnChanged(function()
        RageMode.TracerStart = Options.RageTracerStart.Value
end)

RageControlGroup:AddSlider("RageTracerThickness", {
        Text = "Tracer Thickness",
        Default = 1,
        Min = 1,
        Max = 5,
        Rounding = 0,
})
Options.RageTracerThickness:OnChanged(function()
        RageMode.TracerThickness = Options.RageTracerThickness.Value
end)

-- ═══════════════════════════════════════════════════════════════════
-- ADVANCED AUTO-SHOOT — Smart triggerbot with useful settings
-- ═══════════════════════════════════════════════════════════════════
RageControlGroup:AddToggle("AutoShootEnabled", {
        Text = "Auto Shoot (Crosshair)",
        Default = false,
        Tooltip = "Automatically fires when an enemy is within the pixel radius around your crosshair.",
})
Toggles.AutoShootEnabled:OnChanged(function()
        AutoShootSettings.Enabled = Toggles.AutoShootEnabled.Value
        if AutoShootSettings.Enabled then
                if getgenv().ZX_AutoShoot and getgenv().ZX_AutoShoot.start then
                        getgenv().ZX_AutoShoot.start()
                end
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Auto Shoot", "Enabled.", "success")
                end
        else
                if getgenv().ZX_AutoShoot and getgenv().ZX_AutoShoot.stop then
                        getgenv().ZX_AutoShoot.stop()
                end
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Auto Shoot", "Disabled.", "warning")
                end
        end
end)

RageControlGroup:AddSlider("AutoShootRadius", {
        Text = "Trigger Radius",
        Default = 100,
        Min = 10,
        Max = 500,
        Rounding = 0,
        Suffix = " px",
        Tooltip = "Pixel radius around crosshair. Smaller = more precise (need to aim close), Larger = more forgiving.",
})
Options.AutoShootRadius:OnChanged(function()
        AutoShootSettings.Radius = Options.AutoShootRadius.Value
end)

RageControlGroup:AddSlider("AutoShootBurstCount", {
        Text = "Burst Count",
        Default = 3,
        Min = 1,
        Max = 10,
        Rounding = 0,
        Suffix = " shots",
        Tooltip = "Number of shots to fire per burst. 1 = single shot, 3 = burst fire, 10 = full spray.",
})
Options.AutoShootBurstCount:OnChanged(function()
        AutoShootSettings.BurstCount = Options.AutoShootBurstCount.Value
end)

RageControlGroup:AddSlider("AutoShootBurstDelay", {
        Text = "Burst Delay",
        Default = 50,
        Min = 0,
        Max = 300,
        Rounding = 0,
        Suffix = " ms",
        Tooltip = "Delay between each shot in a burst. Lower = faster burst, Higher = more controlled.",
})
Options.AutoShootBurstDelay:OnChanged(function()
        AutoShootSettings.BurstDelay = Options.AutoShootBurstDelay.Value / 1000
end)

RageControlGroup:AddSlider("AutoShootCooldown", {
        Text = "Cooldown Between Bursts",
        Default = 200,
        Min = 0,
        Max = 2000,
        Rounding = 0,
        Suffix = " ms",
        Tooltip = "Wait time between bursts. Prevents spam-firing. 0 = no cooldown, 500ms = controlled rate.",
})
Options.AutoShootCooldown:OnChanged(function()
        AutoShootSettings.Cooldown = Options.AutoShootCooldown.Value / 1000
end)

RageControlGroup:AddToggle("AutoShootWallCheck", {
        Text = "Wall Check",
        Default = true,
        Tooltip = "Only fires if there's a clear line of sight to the enemy (no walls between you).",
})
Toggles.AutoShootWallCheck:OnChanged(function()
        AutoShootSettings.RequireVisible = Toggles.AutoShootWallCheck.Value
end)

RageControlGroup:AddToggle("AutoShootAntiFriendly", {
        Text = "Anti-Friendly Fire",
        Default = true,
        Tooltip = "Skips teammates when looking for Auto Shoot targets.",
})
Toggles.AutoShootAntiFriendly:OnChanged(function()
        AutoShootSettings.AntiFriendlyFire = Toggles.AutoShootAntiFriendly.Value
end)


OrbitGroup:AddToggle("OrbitEnabled", {
        Text = "Enable Orbit",
        Default = PlayerSettings.OrbitEnabled,
        Tooltip = "Auto-orbit around the nearest enemy (skips teammates & dead players). Fully automatic — no target selection needed.",
})
Toggles.OrbitEnabled:OnChanged(function()
        PlayerSettings.OrbitEnabled = Toggles.OrbitEnabled.Value
end)

OrbitGroup:AddSlider("OrbitRadiusSlider", {
        Text = "Orbit Radius",
        Default = PlayerSettings.OrbitRadius,
        Min = 3,
        Max = 30,
        Rounding = 1,
        Suffix = " studs",
        Tooltip = "Distance from target (smaller=closer orbit, larger=wider orbit)",
})
Options.OrbitRadiusSlider:OnChanged(function()
        PlayerSettings.OrbitRadius = Options.OrbitRadiusSlider.Value
end)

OrbitGroup:AddSlider("OrbitMaxDistanceSlider", {
        Text = "Max Distance",
        Default = PlayerSettings.OrbitMaxDistance,
        Min = 50,
        Max = 2000,
        Rounding = 0,
        Suffix = " studs",
        Tooltip = "Max range to find a target. Orbit won't activate unless an enemy is within this distance. Default 400.",
})
Options.OrbitMaxDistanceSlider:OnChanged(function()
        PlayerSettings.OrbitMaxDistance = Options.OrbitMaxDistanceSlider.Value
end)

OrbitGroup:AddSlider("OrbitSpeedSlider", {
        Text = "Orbit Speed",
        Default = PlayerSettings.OrbitSpeed,
        Min = 0.5,
        Max = 15,
        Rounding = 1,
        Suffix = " rad/s",
        Tooltip = "Rotation speed (higher=faster orbit). 3 = moderate, 10 = very fast",
})
Options.OrbitSpeedSlider:OnChanged(function()
        PlayerSettings.OrbitSpeed = Options.OrbitSpeedSlider.Value
end)

OrbitGroup:AddSlider("OrbitHeightSlider", {
        Text = "Height Offset",
        Default = PlayerSettings.OrbitHeight,
        Min = -5,
        Max = 15,
        Rounding = 1,
        Suffix = " studs",
        Tooltip = "Height above target. 0=ground level, 3=slightly floating, 15=high above",
})
Options.OrbitHeightSlider:OnChanged(function()
        PlayerSettings.OrbitHeight = Options.OrbitHeightSlider.Value
end)

OrbitGroup:AddLabel("Orbit Key"):AddKeyPicker("OrbitKey", {
        Default = "X",
        SyncToggleState = false,
        Mode = "Toggle",
        NoUI = false,
        Text = "Orbit keybind",
})

RunService.Heartbeat:Connect(function()
        if not Options.OrbitKey then return end
        local ok, keyState = pcall(function() return Options.OrbitKey:GetState() end)
        if not ok then return end
        if keyState ~= PlayerSettings.OrbitEnabled then
                PlayerSettings.OrbitEnabled = keyState
        end
end)

-- ═════════════════════════════════════════════════════════════════
-- STICK TO TARGET UI
-- ═════════════════════════════════════════════════════════════════
StickToTargetGroup:AddToggle("StickToTargetEnabled", {
        Text = "Stick to Target",
        Default = PlayerSettings.StickToTargetEnabled,
        Tooltip = "Sticks your character to the nearest enemy and follows them.",
})
Toggles.StickToTargetEnabled:OnChanged(function()
        PlayerSettings.StickToTargetEnabled = Toggles.StickToTargetEnabled.Value
end)

StickToTargetGroup:AddLabel("Stick Key"):AddKeyPicker("StickKey", {
        Default = "I",
        SyncToggleState = false,
        Mode = "Toggle",
        NoUI = false,
        Text = "Stick keybind",
})

StickToTargetGroup:AddToggle("StickUseSmooth", {
        Text = "Use Smooth Sticking",
        Default = PlayerSettings.StickUseSmooth,
        Tooltip = "ON = smoothly move to target (lerp).\\nOFF = instant teleport to target.",
})
Toggles.StickUseSmooth:OnChanged(function()
        PlayerSettings.StickUseSmooth = Toggles.StickUseSmooth.Value
end)

StickToTargetGroup:AddSlider("StickSmoothness", {
        Text = "Smooth Sticking",
        Default = PlayerSettings.StickSmoothness,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "/100",
        Tooltip = "0 = instant, 100 = very smooth (only works if 'Use Smooth Sticking' is ON).",
})
Options.StickSmoothness:OnChanged(function()
        PlayerSettings.StickSmoothness = Options.StickSmoothness.Value
end)

StickToTargetGroup:AddToggle("StickBeneathPlayer", {
        Text = "Stick Beneath Player",
        Default = PlayerSettings.StickBeneathPlayer,
        Tooltip = "ON = stick under the target (below them).\\nOFF = stick at same position as target.",
})
Toggles.StickBeneathPlayer:OnChanged(function()
        PlayerSettings.StickBeneathPlayer = Toggles.StickBeneathPlayer.Value
end)

-- Handle keybind → toggle sync (safe — no infinite loop)
-- بنـ check الـ keybind state ولو اختلف عن الـ toggle الحالي، نـ update الـ toggle
-- بس بنـ check إن الـ setValue مش هتعمل loop
local _stickKeyLastState = nil
RunService.Heartbeat:Connect(function()
        if not Options.StickKey then return end
        local ok, keyState = pcall(function() return Options.StickKey:GetState() end)
        if not ok then return end
        -- لو الـ state اتغير (مش مجرد مختلف عن الـ toggle)
        if keyState ~= _stickKeyLastState then
                _stickKeyLastState = keyState
                PlayerSettings.StickToTargetEnabled = keyState
                -- نـ update الـ toggle UI بس لو مختلف عشان نتجنب loop
                pcall(function()
                        if Toggles.StickToTargetEnabled and Toggles.StickToTargetEnabled.Value ~= keyState then
                                Toggles.StickToTargetEnabled:SetValue(keyState)
                        end
                end)
        end
end)

-- ═════════════════════════════════════════════════════════════════
-- WORLD TAB — Controls (Atmosphere + Color Correction + Lighting)
-- منقول من Purple Ghost
-- ═════════════════════════════════════════════════════════════════

local _ZXLighting = game:GetService("Lighting")

-- ColorCorrectionEffect helper
local _ZX_cc = _ZXLighting:FindFirstChildOfClass("ColorCorrectionEffect")
local function _ZX_getCC()
    if not _ZX_cc or not _ZX_cc.Parent then
        _ZX_cc = _ZXLighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if not _ZX_cc then
            _ZX_cc = Instance.new("ColorCorrectionEffect")
            _ZX_cc.Parent = _ZXLighting
        end
    end
    return _ZX_cc
end

-- Atmosphere helper
local _ZX_atmo = _ZXLighting:FindFirstChildOfClass("Atmosphere")
local function _ZX_getAtmo()
    if not _ZX_atmo or not _ZX_atmo.Parent then
        _ZX_atmo = _ZXLighting:FindFirstChildOfClass("Atmosphere")
        if not _ZX_atmo then
            _ZX_atmo = Instance.new("Atmosphere")
            _ZX_atmo.Parent = _ZXLighting
        end
    end
    return _ZX_atmo
end

-- ─── Atmosphere groupbox ───
WorldAtmosphereGroup:AddToggle("WorldAtmoEnabled", {
    Text = "Enabled",
    Default = false,
    Tooltip = "Toggle atmosphere effects (fog/density/haze).",
})
Toggles.WorldAtmoEnabled:OnChanged(function()
    if not Toggles.WorldAtmoEnabled.Value then
        local a = _ZX_getAtmo()
        a.Density = 0
        a.Haze = 0
        a.Glare = 0
        a.Offset = 0
    end
end)

WorldAtmosphereGroup:AddLabel("Color"):AddColorPicker("WorldAtmoColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Atmosphere Color",
})
Options.WorldAtmoColor:OnChanged(function()
    _ZX_getAtmo().Color = Options.WorldAtmoColor.Value
end)

WorldAtmosphereGroup:AddLabel("Decay"):AddColorPicker("WorldAtmoDecay", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Atmosphere Decay",
})
Options.WorldAtmoDecay:OnChanged(function()
    _ZX_getAtmo().Decay = Options.WorldAtmoDecay.Value
end)

WorldAtmosphereGroup:AddSlider("WorldAtmoGlare", {
    Text = "Glare",
    Default = 25,
    Min = 0,
    Max = 100,
    Rounding = 0,
})
Options.WorldAtmoGlare:OnChanged(function()
    _ZX_getAtmo().Glare = Options.WorldAtmoGlare.Value / 10
end)

WorldAtmosphereGroup:AddSlider("WorldAtmoHaze", {
    Text = "Haze",
    Default = 10,
    Min = 0,
    Max = 100,
    Rounding = 0,
})
Options.WorldAtmoHaze:OnChanged(function()
    _ZX_getAtmo().Haze = Options.WorldAtmoHaze.Value
end)

WorldAtmosphereGroup:AddSlider("WorldAtmoOffset", {
    Text = "Offset",
    Default = 37,
    Min = 0,
    Max = 100,
    Rounding = 0,
})
Options.WorldAtmoOffset:OnChanged(function()
    _ZX_getAtmo().Offset = Options.WorldAtmoOffset.Value / 100
end)

WorldAtmosphereGroup:AddSlider("WorldAtmoDensity", {
    Text = "Density",
    Default = 49,
    Min = 0,
    Max = 100,
    Rounding = 0,
})
Options.WorldAtmoDensity:OnChanged(function()
    _ZX_getAtmo().Density = Options.WorldAtmoDensity.Value / 100
end)

-- ─── Color Correction groupbox ───
WorldColorCorrectionGroup:AddToggle("WorldCCEnabled", {
    Text = "Enabled",
    Default = false,
})
Toggles.WorldCCEnabled:OnChanged(function()
    _ZX_getCC().Enabled = Toggles.WorldCCEnabled.Value
end)

WorldColorCorrectionGroup:AddSlider("WorldCCSaturation", {
    Text = "Saturation",
    Default = 10,
    Min = -100,
    Max = 100,
    Rounding = 0,
})
Options.WorldCCSaturation:OnChanged(function()
    _ZX_getCC().Saturation = Options.WorldCCSaturation.Value / 10
end)

WorldColorCorrectionGroup:AddSlider("WorldCCContrast", {
    Text = "Contrast",
    Default = -5,
    Min = -100,
    Max = 100,
    Rounding = 0,
})
Options.WorldCCContrast:OnChanged(function()
    _ZX_getCC().Contrast = Options.WorldCCContrast.Value / 10
end)

WorldColorCorrectionGroup:AddSlider("WorldCCBrightness", {
    Text = "Brightness",
    Default = -1,
    Min = -100,
    Max = 100,
    Rounding = 0,
})
Options.WorldCCBrightness:OnChanged(function()
    _ZX_getCC().Brightness = Options.WorldCCBrightness.Value / 100
end)

-- ─── Lighting groupbox ───
WorldLightingGroup:AddToggle("WorldLAmbient", {
    Text = "Ambient",
    Default = false,
})
WorldLightingGroup:AddLabel("Ambient Color"):AddColorPicker("WorldLAmbientColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Ambient Color",
})
Options.WorldLAmbientColor:OnChanged(function()
    if Toggles.WorldLAmbient and Toggles.WorldLAmbient.Value then
        _ZXLighting.Ambient = Options.WorldLAmbientColor.Value
    end
end)

WorldLightingGroup:AddToggle("WorldLColorShiftBot", {
    Text = "ColorShift Bottom",
    Default = false,
})
WorldLightingGroup:AddLabel("ColorShift Bottom"):AddColorPicker("WorldLCSBColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "ColorShift Bottom",
})
Options.WorldLCSBColor:OnChanged(function()
    if Toggles.WorldLColorShiftBot and Toggles.WorldLColorShiftBot.Value then
        _ZXLighting.ColorShift_Bottom = Options.WorldLCSBColor.Value
    end
end)

WorldLightingGroup:AddToggle("WorldLColorShiftTop", {
    Text = "ColorShift Top",
    Default = false,
})
WorldLightingGroup:AddLabel("ColorShift Top"):AddColorPicker("WorldLCSTColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "ColorShift Top",
})
Options.WorldLCSTColor:OnChanged(function()
    if Toggles.WorldLColorShiftTop and Toggles.WorldLColorShiftTop.Value then
        _ZXLighting.ColorShift_Top = Options.WorldLCSTColor.Value
    end
end)

WorldLightingGroup:AddToggle("WorldLFogColor", {
    Text = "Fog Color",
    Default = false,
})
WorldLightingGroup:AddLabel("Fog"):AddColorPicker("WorldLFogColor", {
    Default = Color3.fromRGB(200, 200, 200),
    Title = "Fog Color",
})
Options.WorldLFogColor:OnChanged(function()
    if Toggles.WorldLFogColor and Toggles.WorldLFogColor.Value then
        _ZXLighting.FogColor = Options.WorldLFogColor.Value
    end
end)

WorldLightingGroup:AddSlider("WorldLFogEnd", {
    Text = "Fog End",
    Default = 2510,
    Min = 0,
    Max = 10000,
    Rounding = 0,
    Suffix = " studs",
})
Options.WorldLFogEnd:OnChanged(function()
    _ZXLighting.FogEnd = Options.WorldLFogEnd.Value
end)

WorldLightingGroup:AddSlider("WorldLFogStart", {
    Text = "Fog Start",
    Default = 0,
    Min = 0,
    Max = 5000,
    Rounding = 0,
    Suffix = " studs",
})
Options.WorldLFogStart:OnChanged(function()
    _ZXLighting.FogStart = Options.WorldLFogStart.Value
end)

WorldLightingGroup:AddToggle("WorldLExposure", {
    Text = "Exposure",
    Default = false,
})
WorldLightingGroup:AddSlider("WorldLExposureVal", {
    Text = "Exposure",
    Default = -11,
    Min = -100,
    Max = 100,
    Rounding = 0,
})
Options.WorldLExposureVal:OnChanged(function()
    if Toggles.WorldLExposure and Toggles.WorldLExposure.Value then
        _ZXLighting.ExposureCompensation = Options.WorldLExposureVal.Value / 10
    end
end)

WorldLightingGroup:AddToggle("WorldLBrightness", {
    Text = "Brightness",
    Default = false,
})
WorldLightingGroup:AddSlider("WorldLBrightnessVal", {
    Text = "Brightness",
    Default = 17,
    Min = 0,
    Max = 50,
    Rounding = 0,
})
Options.WorldLBrightnessVal:OnChanged(function()
    if Toggles.WorldLBrightness and Toggles.WorldLBrightness.Value then
        _ZXLighting.Brightness = Options.WorldLBrightnessVal.Value / 10
    end
end)

WorldLightingGroup:AddToggle("WorldLClockTime", {
    Text = "Clock Time",
    Default = false,
})
WorldLightingGroup:AddSlider("WorldLClockTimeVal", {
    Text = "Clock",
    Default = 114,
    Min = 0,
    Max = 240,
    Rounding = 0,
    Suffix = " h",
})
Options.WorldLClockTimeVal:OnChanged(function()
    if Toggles.WorldLClockTime and Toggles.WorldLClockTime.Value then
        _ZXLighting.ClockTime = Options.WorldLClockTimeVal.Value / 10
    end
end)

WorldLightingGroup:AddToggle("WorldLGlobalShadows", {
    Text = "Global Shadows",
    Default = false,
})
Toggles.WorldLGlobalShadows:OnChanged(function()
    _ZXLighting.GlobalShadows = Toggles.WorldLGlobalShadows.Value
end)

WorldLightingGroup:AddDropdown("WorldLTechnology", {
    Text = "Technology",
    Values = { "Compatibility", "Voxel", "ShadowMap", "Future" },
    Default = 3,
    Multi = false,
    Tooltip = "Changes the rendering technology used by Lighting.",
})
Options.WorldLTechnology:OnChanged(function()
    local techName = Options.WorldLTechnology.Value
    pcall(function()
        _ZXLighting.Technology = Enum.Technology[techName]
    end)
end)

SilentAimGroup:AddToggle("SilentAimEnabled", {
        Text = "Silent Aim Enabled (Need Spam)",
        Default = SilentAim.Enabled,
        Tooltip = "Redirects bullet raycasts to target (no visible mouse movement)",
})
Toggles.SilentAimEnabled:OnChanged(function()
        SilentAim.Enabled = Toggles.SilentAimEnabled.Value
end)

-- HitChance تم استبداله بنظام مؤقت داخلي (on 0.10s / off 0.10s)


SilentAimGroup:AddSlider("SAPrediction", {
        Text = "Prediction",
        Default = SilentAim.Prediction,
        Min = 0,
        Max = 0.2,
        Rounding = 3,
        Tooltip = "Movement prediction time (seconds). Lower = more responsive, higher = more lead for fast targets.",
})
Options.SAPrediction:OnChanged(function()
        SilentAim.Prediction = Options.SAPrediction.Value
end)

SilentAimGroup:AddDropdown("SAHitPart", {
        Text = "Target Part",
        Values = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Pelvis", "Random" },
        Default = 1,
        Multi = false,
        Tooltip = "Where to redirect your bullets. Head = headshots, UpperTorso = body shots, Random = random body part each shot.",
})
Options.SAHitPart:OnChanged(function()
        SilentAim.HitPart = Options.SAHitPart.Value
end)


SilentAimGroup:AddToggle("SAFovVisible", {
        Text = "Show FOV Circle",
        Default = SilentAim.FovVisible,
})
Toggles.SAFovVisible:OnChanged(function()
        SilentAim.FovVisible = Toggles.SAFovVisible.Value
end)

SilentAimGroup:AddToggle("SAFovFilled", {
        Text = "Filled FOV Circle",
        Default = SilentAim.FovFilled,
})
Toggles.SAFovFilled:OnChanged(function()
        SilentAim.FovFilled = Toggles.SAFovFilled.Value
end)

SilentAimGroup:AddLabel("FOV Circle Color"):AddColorPicker("SAFovColor", {
        Default = Color3.fromRGB(255, 255, 255),
        Title = "Silent Aim FOV Color",
})
Options.SAFovColor:OnChanged(function()
        SilentAim.FovColor = Options.SAFovColor.Value
        SilentAim.FovRainbow = false
end)

SilentAimGroup:AddToggle("SAFovRainbow", {
        Text = "Rainbow FOV Color",
        Default = false,
})
Toggles.SAFovRainbow:OnChanged(function()
        SilentAim.FovRainbow = Toggles.SAFovRainbow.Value
end)

SilentAimGroup:AddSlider("SAFovRadius", {
        Text = "FOV Radius Size",
        Default = SilentAim.FOV,
        Min = 50,
        Max = 400,
        Rounding = 0,
})
Options.SAFovRadius:OnChanged(function()
        SilentAim.FOV = Options.SAFovRadius.Value
end)

SilentAimGroup:AddSlider("SAMaxDistance", {
        Text = "Max Distance (studs)",
        Default = 2000,
        Min = 100,
        Max = 2000,
        Rounding = 0,
        Suffix = " studs",
        Tooltip = "Maximum distance to target enemies.",
})
Options.SAMaxDistance:OnChanged(function()
        SilentAim.MaxDistance = Options.SAMaxDistance.Value
end)

SilentAimGroup:AddToggle("SAProjectilePrediction", {
        Text = "Projectile Prediction",
        Default = SilentAim.ProjectilePrediction,
        Tooltip = "Uses weapon projectile speed from ItemLibrary for accurate long-range prediction",
})
Toggles.SAProjectilePrediction:OnChanged(function()
        SilentAim.ProjectilePrediction = Toggles.SAProjectilePrediction.Value
end)

TeamCheckGroup:AddToggle("TeamCheckEnabled", {
        Text = "Team Check",
        Default = TeamCheck.Enabled,
        Tooltip = "Prevents targeting teammates — ON by default!",
})
Toggles.TeamCheckEnabled:OnChanged(function()
        TeamCheck.Enabled = Toggles.TeamCheckEnabled.Value
end)

HoldBotGroup:AddToggle("HoldBotEnabled", {
        Text = "Aimbot Enabled",
        Default = HoldBot.Enabled,
        Tooltip = "Smooth aim assist — hold key to aim at nearest target",
})
Toggles.HoldBotEnabled:OnChanged(function()
        HoldBot.Enabled = Toggles.HoldBotEnabled.Value
end)

HoldBotGroup:AddToggle("HoldBotKeybind", {
        Text = "Use Keybind (Hold to Aim)",
        Default = HoldBot.UseKeybind,
        Tooltip = "When enabled, Aimbot only activates while holding the key",
})
Toggles.HoldBotKeybind:OnChanged(function()
        HoldBot.UseKeybind = Toggles.HoldBotKeybind.Value
end)

HoldBotGroup:AddLabel("Aimbot Key"):AddKeyPicker("HoldBotKey", {
        Default = "CapsLock",
        Mode = "Hold",
        NoUI = false,
        Text = "Aimbot keybind",
})

HoldBotGroup:AddToggle("HoldBotSmoothing", {
        Text = "Use Smoothing",
        Default = HoldBot.UseSmoothing,
        Tooltip = "Enable for smooth aim movement, disable for instant snap",
})
Toggles.HoldBotSmoothing:OnChanged(function()
        HoldBot.UseSmoothing = Toggles.HoldBotSmoothing.Value
end)

-- SMOOTHING VALUE SLIDER (1-20, only lerp changes per level)
HoldBotGroup:AddSlider("HoldBotSmoothingValue", {
        Text = "Smoothing Value",
        Default = HoldBot.SmoothingValue,
        Min = 1,
        Max = 20,
        Rounding = 0,
        Tooltip = "1=Fastest, 20=Slowest. rivals-rewrite style: delta / divisor. Curve: 1-10 gradual, 10-20 fine control.",
})
Options.HoldBotSmoothingValue:OnChanged(function()
        HoldBot.SmoothingValue = Options.HoldBotSmoothingValue.Value
end)

HoldBotGroup:AddToggle("HoldBotPrediction", {
        Text = "Movement Prediction",
        Default = HoldBot.Prediction,
        Tooltip = "Leads moving targets by predicting their movement",
})
Toggles.HoldBotPrediction:OnChanged(function()
        HoldBot.Prediction = Toggles.HoldBotPrediction.Value
end)

HoldBotGroup:AddToggle("HoldBotPersistent", {
        Text = "Persistent Target",
        Default = HoldBot.PersistentTarget,
        Tooltip = "Won't switch targets until you release the key",
})
Toggles.HoldBotPersistent:OnChanged(function()
        HoldBot.PersistentTarget = Toggles.HoldBotPersistent.Value
end)

HoldBotGroup:AddToggle("HoldBotWallCheck", {
        Text = "Wall Check",
        Default = not HoldBot.TargetBehindWalls,
        Tooltip = "Only aim at visible players (not behind walls)",
})
Toggles.HoldBotWallCheck:OnChanged(function()
        HoldBot.TargetBehindWalls = not Toggles.HoldBotWallCheck.Value
end)

HoldBotGroup:AddDropdown("HoldBotHitPart", {
        Values = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
        Default = 1,
        Multi = false,
        Text = "Target Part",
})
Options.HoldBotHitPart:OnChanged(function()
        HoldBot.HitPart = Options.HoldBotHitPart.Value
end)

HoldBotGroup:AddToggle("HoldBotFovVisible", {
        Text = "Show FOV Circle",
        Default = HoldBot.FovVisible,
})
Toggles.HoldBotFovVisible:OnChanged(function()
        HoldBot.FovVisible = Toggles.HoldBotFovVisible.Value
end)

HoldBotGroup:AddToggle("HoldBotFovFilled", {
        Text = "Filled FOV Circle",
        Default = HoldBot.FovFilled,
})
Toggles.HoldBotFovFilled:OnChanged(function()
        HoldBot.FovFilled = Toggles.HoldBotFovFilled.Value
end)

HoldBotGroup:AddLabel("FOV Circle Color"):AddColorPicker("HoldBotFovColor", {
        Default = Color3.fromRGB(0, 255, 255),
        Title = "Aimbot FOV Color",
})
Options.HoldBotFovColor:OnChanged(function()
        HoldBot.FovColor = Options.HoldBotFovColor.Value
        HoldBot.FovRainbow = false
end)

HoldBotGroup:AddToggle("HoldBotFovRainbow", {
        Text = "Rainbow FOV Color",
        Default = false,
        Tooltip = "Cycles the FOV circle through all colors automatically.",
})
Toggles.HoldBotFovRainbow:OnChanged(function()
        HoldBot.FovRainbow = Toggles.HoldBotFovRainbow.Value
end)

HoldBotGroup:AddSlider("HoldBotFovRadius", {
        Text = "FOV Radius Size",
        Default = HoldBot.FOV,
        Min = 50,
        Max = 600,
        Rounding = 0,
})
Options.HoldBotFovRadius:OnChanged(function()
        HoldBot.FOV = Options.HoldBotFovRadius.Value
end)

-- Jitter control slider (user controls jitter amount directly)
HoldBotGroup:AddSlider("AimbotJitterControl", {
        Text = "Jitter (human shake: 0=none, 0.05=strong)",
        Default = 0.008,
        Min = 0.0,
        Max = 0.050,
        Rounding = 3,
        Tooltip = "Random micro-movements to look human. 0 = none, 0.05 = very shaky.",
})
Options.AimbotJitterControl:OnChanged(function()
        getgenv().ZX_CustomJitter = Options.AimbotJitterControl.Value
end)

TriggerBotGroup:AddToggle("TriggerBotEnabled", {
        Text = "Enable Trigger Bot",
        Default = TriggerBot.Enabled,
        Tooltip = "Automatically fires when your crosshair is on an enemy",
})
Toggles.TriggerBotEnabled:OnChanged(function()
        TriggerBot.Enabled = Toggles.TriggerBotEnabled.Value
end)

TriggerBotGroup:AddSlider("TriggerBotDelay", {
        Text = "Trigger Delay",
        Default = TriggerBot.Delay,
        Min = 0.01,
        Max = 0.3,
        Rounding = 2,
        Suffix = "s",
        Tooltip = "Delay before firing after detecting target (lower=faster, higher=more legit)",
})
Options.TriggerBotDelay:OnChanged(function()
        TriggerBot.Delay = Options.TriggerBotDelay.Value
end)

TriggerBotGroup:AddToggle("TriggerBotWallCheck", {
        Text = "Wall Check",
        Default = TriggerBot.WallCheck,
        Tooltip = "Only fire if target is visible (not behind walls)",
})
Toggles.TriggerBotWallCheck:OnChanged(function()
        TriggerBot.WallCheck = Toggles.TriggerBotWallCheck.Value
end)

TriggerBotGroup:AddToggle("TriggerBotKeybind", {
        Text = "Hold RMB to Fire",
        Default = TriggerBot.Keybind,
        Tooltip = "When ON, only fires while holding right mouse button",
})
Toggles.TriggerBotKeybind:OnChanged(function()
        TriggerBot.Keybind = Toggles.TriggerBotKeybind.Value
end)

SniperModeGroup:AddToggle("SniperModeEnabled", {
        Text = "Enable Sniper Mode",
        Default = SniperMode.Enabled,
        Tooltip = "When ON: aims at target -> ADS (RMB) -> waits -> fires -> releases ADS. Useful for sniper rifles.",
})
Toggles.SniperModeEnabled:OnChanged(function()
        SniperMode.Enabled = Toggles.SniperModeEnabled.Value
end)

SniperModeGroup:AddSlider("SniperModeThreshold", {
        Text = "Fire Threshold (px)",
        Default = SniperMode.Threshold,
        Min = 5,
        Max = 200,
        Rounding = 0,
        Suffix = " px",
        Tooltip = "Distance from crosshair within which sniper will fire. Lower = more accurate aim required.",
})
Options.SniperModeThreshold:OnChanged(function()
        SniperMode.Threshold = Options.SniperModeThreshold.Value
end)

SniperModeGroup:AddSlider("SniperModeDelay", {
        Text = "ADS Delay",
        Default = SniperMode.Delay,
        Min = 0.05,
        Max = 1.0,
        Rounding = 2,
        Suffix = " s",
        Tooltip = "How long to hold ADS before firing. Higher = more legit, lower = faster.",
})
Options.SniperModeDelay:OnChanged(function()
        SniperMode.Delay = Options.SniperModeDelay.Value
end)

SniperModeGroup:AddSlider("SniperModeCooldown", {
        Text = "Shot Cooldown",
        Default = SniperMode.Cooldown,
        Min = 0.1,
        Max = 3.0,
        Rounding = 2,
        Suffix = " s",
        Tooltip = "Wait time after each shot before next sniper fire is allowed.",
})
Options.SniperModeCooldown:OnChanged(function()
        SniperMode.Cooldown = Options.SniperModeCooldown.Value
end)

------------------------------------------------------------------
-- P100 ANTI-AIM SYSTEM (Enhanced Lookdown + Multi-layer)
-- Modes: Lookdown (Camera + Neck C0) + Jitter + Desync
------------------------------------------------------------------
AntiAimGroup:AddToggle("AntiAimEnabled", {
        Text = "Enable Anti-Aim",
        Default = AntiAim.Enabled,
        Tooltip = "When ON: forces camera to look at specified pitch/yaw angle. Makes enemy aimbots miss.",
})
Toggles.AntiAimEnabled:OnChanged(function()
        AntiAim.Enabled = Toggles.AntiAimEnabled.Value
        if AntiAim.Enabled then
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Anti-Aim", "Enabled.", "success")
                end
        else
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Anti-Aim", "Disabled.", "warning")
                end
        end
end)

AntiAimGroup:AddSlider("AntiAimPitch", {
        Text = "Lookdown Pitch",
        Default = 85,
        Min = 0,
        Max = 90,
        Rounding = 0,
        Suffix = "°",
        Tooltip = "0° = forward, 85° = look at ground (P100 default), 90° = full down.",
})
Options.AntiAimPitch:OnChanged(function()
        AntiAim.Pitch = Options.AntiAimPitch.Value
end)

AntiAimGroup:AddSlider("AntiAimYaw", {
        Text = "Yaw Offset",
        Default = 0,
        Min = -180,
        Max = 180,
        Rounding = 0,
        Suffix = "°",
        Tooltip = "Rotates character. 0° = forward, 90° = right, -90° = left, 180° = backward.",
})
Options.AntiAimYaw:OnChanged(function()
        AntiAim.Yaw = Options.AntiAimYaw.Value
end)

    end
    pcall(function()
        local char = lp.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = true end
        end
    end)
end

task.wait(0.15)

do
local PresetsGroup = Tabs.Legit:AddLeftGroupbox("Quick Presets")

PresetsGroup:AddButton("Legit Preset", function()

        SilentAim.Enabled = true
        SilentAim.ProjectilePrediction = true
        SilentAim.HitPart = "UpperTorso"
        SilentAim.HitCooldown = 0.03
        SilentAim.HitChance = 100
        SilentAim.FOV = 120
        SilentAim.MaxDistance = 300
        SilentAim.Prediction = 0.02
        if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(true) end
        if Toggles.SAProjectilePrediction then Toggles.SAProjectilePrediction:SetValue(true) end
        if Options.SAHitPart then Options.SAHitPart:SetValue("UpperTorso") end
        if Options.SAHitCooldown then Options.SAHitCooldown:SetValue(30) end
        if Options.SAFovRadius then Options.SAFovRadius:SetValue(120) end
        if Options.SAPrediction then Options.SAPrediction:SetValue(0.02) end

        RageMode.Enabled = false
        if Toggles.RageModeEnabled then Toggles.RageModeEnabled:SetValue(false) end
        GunMods.MasterEnabled = false
        if Toggles.GunModsMaster then Toggles.GunModsMaster:SetValue(false) end
end)

PresetsGroup:AddButton("Visuals Preset", function()

        EspSettings.EspBoxes = true
        EspSettings.EspChams = true
        EspSettings.EspNames = true
        EspSettings.EspDistance = true
        EspSettings.EspHealth = true
        EspSettings.EspEnemyWeapons = true
        EspSettings.EspGlowChams = true
        VisualSettings.LockIndicator = true
        VisualSettings.HideSmoke = true
        VisualSettings.HideFlashbang = true
        if Toggles.EspBoxOutlines then Toggles.EspBoxOutlines:SetValue(true) end
        if Toggles.EspChamsToggle then Toggles.EspChamsToggle:SetValue(true) end
        if Toggles.EspNamesToggle then Toggles.EspNamesToggle:SetValue(true) end
        if Toggles.EspDistanceToggle then Toggles.EspDistanceToggle:SetValue(true) end
        if Toggles.EspHealthToggle then Toggles.EspHealthToggle:SetValue(true) end
        if Toggles.EspEnemyWeaponsToggle then Toggles.EspEnemyWeaponsToggle:SetValue(true) end
        if Toggles.EspGlowChamsToggle then Toggles.EspGlowChamsToggle:SetValue(true) end
        if Toggles.LockIndicatorToggle then Toggles.LockIndicatorToggle:SetValue(true) end
        if Toggles.HideSmoke then Toggles.HideSmoke:SetValue(true) end
        if Toggles.HideFlashbang then Toggles.HideFlashbang:SetValue(true) end

        SilentAim.Enabled = false
        if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(false) end
        RageMode.Enabled = false
        if Toggles.RageModeEnabled then Toggles.RageModeEnabled:SetValue(false) end
        GunMods.MasterEnabled = false
        if Toggles.GunModsMaster then Toggles.GunModsMaster:SetValue(false) end
end)
end

do
local GunModApplyButton
task.spawn(function()
    task.wait(5)
    local RS = cloneref(game:GetService("ReplicatedStorage"))
    local ItemLib = RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)
    if not ItemLib then return end

    local function applyGunModsNow()
        local ok, lib = pcall(function() return require(ItemLib) end)
        if not ok or not lib or not lib.Items then
            Library:Notify({Title = "Gun Mods", Description = "ItemLibrary not found", Time = 3})
            return
        end
        for weaponName, weaponData in pairs(lib.Items) do
            if type(weaponData) == "table" then
                pcall(function()
                    if GunMods.NoRecoil then
                        if weaponData.Recoil then weaponData.Recoil = 0 end
                        if weaponData.CameraRecoil then weaponData.CameraRecoil = 0 end
                        if weaponData.ShootRecoil then weaponData.ShootRecoil = 0 end
                        if weaponData.RecoilAmount then weaponData.RecoilAmount = 0 end
                    end
                    if GunMods.NoSpread then
                        if weaponData.Spread then weaponData.Spread = 0 end
                        if weaponData.ShootSpread then weaponData.ShootSpread = 0 end
                        if weaponData.ShootAccuracy then weaponData.ShootAccuracy = 0 end
                        if weaponData.Accuracy then weaponData.Accuracy = 0 end
                        if weaponData.BulletSpread then weaponData.BulletSpread = 0 end
                    end
                    if GunMods.RapidFire then
                        if weaponData.FireRate then weaponData.FireRate = 0.01 end
                        if weaponData.FireDelay then weaponData.FireDelay = 0.01 end
                        if weaponData.ShootDelay then weaponData.ShootDelay = 0.01 end
                        if weaponData.Cooldown then weaponData.Cooldown = 0.01 end
                    end
                    if GunMods.OneShot then
                        if weaponData.Damage then weaponData.Damage = 9999 end
                        if weaponData.BaseDamage then weaponData.BaseDamage = 9999 end
                        if weaponData.HitDamage then weaponData.HitDamage = 9999 end
                    end
                    if GunMods.InfiniteAmmo then
                        if weaponData.MaxAmmo then weaponData.MaxAmmo = 99999 end
                        if weaponData.ClipSize then weaponData.ClipSize = 99999 end
                        if weaponData.MagazineSize then weaponData.MagazineSize = 99999 end
                    end
                    if GunMods.InstantReload then
                        if weaponData.ReloadTime then weaponData.ReloadTime = 0 end
                        if weaponData.ReloadDuration then weaponData.ReloadDuration = 0 end
                    end
                    if GunMods.InstantEquip then
                        if weaponData.EquipTime then weaponData.EquipTime = 0 end
                        if weaponData.DeployTime then weaponData.DeployTime = 0 end
                    end
                    if GunMods.NoBulletDrop then
                        if weaponData.BulletDrop then weaponData.BulletDrop = 0 end
                        if weaponData.Gravity then weaponData.Gravity = 0 end
                        if weaponData.BulletGravity then weaponData.BulletGravity = 0 end
                    end
                    if GunMods.MaxPierce then
                        if weaponData.Pierce then weaponData.Pierce = 999 end
                        if weaponData.MaxPierce then weaponData.MaxPierce = 999 end
                        if weaponData.Penetration then weaponData.Penetration = 999 end
                    end
                    if GunMods.NoCooldowns then
                        if weaponData.Cooldown then weaponData.Cooldown = 0 end
                        if weaponData.AbilityCooldown then weaponData.AbilityCooldown = 0 end
                        if weaponData.MeleeCooldown then weaponData.MeleeCooldown = 0 end
                    end
                end)
            end
        end
        Library:Notify({Title = "Gun Mods", Description = "Mods applied to ItemLibrary", Time = 3})
    end
    _G.ZytheraApplyGunMods = applyGunModsNow
end)

GunModsAimGroup:AddToggle("GunModsMaster", {
        Text = "Enable Gun Mods",
        Default = GunMods.MasterEnabled,
        Tooltip = "Master toggle — must be ON for any gun mod to work",
})
Toggles.GunModsMaster:OnChanged(function()
        GunMods.MasterEnabled = Toggles.GunModsMaster.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then
                _G.ZytheraApplyGunMods()
        end
end)

GunModsAimGroup:AddToggle("GunModsNoRecoil", {
        Text = "No Recoil",
        Default = GunMods.NoRecoil,
        Tooltip = "Zero camera kick when shooting",
})
Toggles.GunModsNoRecoil:OnChanged(function()
        GunMods.NoRecoil = Toggles.GunModsNoRecoil.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAimGroup:AddToggle("GunModsNoSpread", {
        Text = "No Spread / Perfect Accuracy",
        Default = GunMods.NoSpread,
        Tooltip = "Bullets go exactly where you aim — no random deviation",
})
Toggles.GunModsNoSpread:OnChanged(function()
        GunMods.NoSpread = Toggles.GunModsNoSpread.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAimGroup:AddToggle("GunModsRapidFire", {
        Text = "Rapid Fire",
        Default = GunMods.RapidFire,
        Tooltip = "Removes fire rate delay — full auto on everything",
})
Toggles.GunModsRapidFire:OnChanged(function()
        GunMods.RapidFire = Toggles.GunModsRapidFire.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAimGroup:AddToggle("GunModsOneShot", {
        Text = "One Shot Kill",
        Default = GunMods.OneShot,
        Tooltip = "Maximizes damage to instantly kill on hit",
})
Toggles.GunModsOneShot:OnChanged(function()
        GunMods.OneShot = Toggles.GunModsOneShot.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModsInfAmmo", {
        Text = "Infinite Ammo",
        Default = GunMods.InfiniteAmmo,
        Tooltip = "Never run out of ammo in your magazine",
})
Toggles.GunModsInfAmmo:OnChanged(function()
        GunMods.InfiniteAmmo = Toggles.GunModsInfAmmo.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModsInstantReload", {
        Text = "Instant Reload",
        Default = GunMods.InstantReload,
        Tooltip = "Reload time becomes zero",
})
Toggles.GunModsInstantReload:OnChanged(function()
        GunMods.InstantReload = Toggles.GunModsInstantReload.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModsInstantEquip", {
        Text = "Instant Equip",
        Default = GunMods.InstantEquip,
        Tooltip = "Weapon equip/swap animation is instant",
})
Toggles.GunModsInstantEquip:OnChanged(function()
        GunMods.InstantEquip = Toggles.GunModsInstantEquip.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModWalkSpeed", {
        Text = "Super Walk Speed",
        Default = false,
        Tooltip = "Increases weapon-specific walk speed multiplier",
})
Toggles.GunModWalkSpeed:OnChanged(function()
        PlayerSettings.GunModWalkSpeed = Toggles.GunModWalkSpeed.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddToggle("GunModsNoBulletDrop", {
        Text = "No Bullet Drop",
        Default = GunMods.NoBulletDrop,
        Tooltip = "Bullets travel in a straight line — no gravity arc",
})
Toggles.GunModsNoBulletDrop:OnChanged(function()
        GunMods.NoBulletDrop = Toggles.GunModsNoBulletDrop.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddToggle("GunModsMaxPierce", {
        Text = "Max Pierce / Infinite Hits",
        Default = GunMods.MaxPierce,
        Tooltip = "Bullets pass through all targets — infinite penetration",
})
Toggles.GunModsMaxPierce:OnChanged(function()
        GunMods.MaxPierce = Toggles.GunModsMaxPierce.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddToggle("GunModsNoCooldowns", {
        Text = "No Cooldowns (Melee/Abilities)",
        Default = GunMods.NoCooldowns,
        Tooltip = "Removes all cooldown timers on melee and abilities",
})
Toggles.GunModsNoCooldowns:OnChanged(function()
        GunMods.NoCooldowns = Toggles.GunModsNoCooldowns.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddButton("Apply Mods Now", function()
        if _G.ZytheraApplyGunMods then
                _G.ZytheraApplyGunMods()
        else
                Library:Notify({Title = "Gun Mods", Description = "Still loading ItemLibrary...", Time = 3})
        end
end)

GunModsMiscGroup:AddButton("Reset All Gun Mods", function()
        Library:Notify({Title = "Gun Mods", Description = "Please rejoin server to restore original weapon values.", Time = 4})
end)

-- (Removed conflicting "Target Behind Walls" toggle — use "Wall Check"
-- toggle above instead, which is the single source of truth for
-- HoldBot.TargetBehindWalls.)

HoldBotTargetGroup:AddToggle("HoldBotTargetZone", {
        Text = "Use Target Zone",
        Default = HoldBot.UseTargetZone,
        Tooltip = "Only target players within a specific distance",
})
Toggles.HoldBotTargetZone:OnChanged(function()
        HoldBot.UseTargetZone = Toggles.HoldBotTargetZone.Value
end)

HoldBotTargetGroup:AddSlider("HoldBotTargetZoneDistance", {
        Text = "Target Zone Distance",
        Default = HoldBot.TargetZoneDistance,
        Min = 100,
        Max = 3000,
        Rounding = 0,
        Suffix = " studs",
})
Options.HoldBotTargetZoneDistance:OnChanged(function()
        HoldBot.TargetZoneDistance = Options.HoldBotTargetZoneDistance.Value
end)

HoldBotTargetGroup:AddSlider("HoldBotMaxDistance", {
        Text = "Max Range",
        Default = HoldBot.MaxDistance,
        Min = 100,
        Max = 2000,
        Rounding = 0,
        Suffix = " studs",
})
Options.HoldBotMaxDistance:OnChanged(function()
        HoldBot.MaxDistance = Options.HoldBotMaxDistance.Value
end)
end

task.spawn(function()

    task.wait(5)

    local RS = ReplicatedStorage
    local Modules = RS:WaitForChild("Modules", 10)
    if not Modules then return end

    local recoilKeys = {"Recoil", "CameraRecoil", "RecoilAmount", "Kick", "CameraKick", "RecoilUp", "RecoilSide", "VerticalRecoil", "HorizontalRecoil"}
    local spreadKeys = {"Spread", "Accuracy", "BulletSpread", "HipFireSpread", "ADS_Spread", "MaxSpread", "MinSpread", "ConeOfFire", "Deviation"}
    local fireRateKeys = {"FireRate", "RateOfFire", "FireDelay", "ShootDelay", "Cooldown", "FireInterval", "RPM", "RoundPerMinute", "DelayBetweenShots"}
    local ammoKeys = {"Ammo", "MaxAmmo", "ClipSize", "MagazineSize", "AmmoCapacity", "AmmoPerClip"}
    local reloadKeys = {"ReloadTime", "ReloadDuration", "ReloadSpeed", "TimeToReload"}
    local equipKeys = {"EquipTime", "EquipDuration", "DeployTime", "DrawTime", "TimeToEquip"}
    local bulletDropKeys = {"BulletDrop", "Gravity", "BulletGravity", "ProjectileGravity", "DropRate"}
    local pierceKeys = {"Pierce", "Penetration", "MaxPierce", "MaxPenetration", "HitCount", "MaxTargets"}
    local damageKeys = {"Damage", "DamageAmount", "BaseDamage", "HitDamage", "AttackDamage"}
    local cooldownKeys = {"Cooldown", "CooldownTime", "AbilityCooldown", "MeleeCooldown", "SkillCooldown", "CastDelay"}

    local function applyGunMods(configTable, tableName)
        if type(configTable) ~= "table" then return end

        pcall(function()

            if GunMods.NoRecoil then
                for _, key in ipairs(recoilKeys) do
                    if configTable[key] ~= nil then
                        if type(configTable[key]) == "number" then
                            configTable[key] = 0
                        elseif type(configTable[key]) == "table" then

                            for subKey, _ in pairs(configTable[key]) do
                                if type(configTable[key][subKey]) == "number" then
                                    configTable[key][subKey] = 0
                                end
                            end
                        end
                    end
                end
            end

            if GunMods.NoSpread then
                for _, key in ipairs(spreadKeys) do
                    if configTable[key] ~= nil then
                        if type(configTable[key]) == "number" then
                            configTable[key] = 0
                        elseif type(configTable[key]) == "table" then
                            for subKey, _ in pairs(configTable[key]) do
                                if type(configTable[key][subKey]) == "number" then
                                    configTable[key][subKey] = 0
                                end
                            end
                        end
                    end
                end
            end

            if GunMods.RapidFire then
                for _, key in ipairs(fireRateKeys) do
                    if configTable[key] ~= nil then
                        if type(configTable[key]) == "number" then
                            if key == "RPM" or key == "RoundPerMinute" then
                                configTable[key] = 3000
                            else
                                configTable[key] = 0.01
                            end
                        end
                    end
                end
            end

            if GunMods.InfiniteAmmo then
                for _, key in ipairs(ammoKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 9999
                    end
                end
            end

            if GunMods.InstantReload then
                for _, key in ipairs(reloadKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end

            if GunMods.InstantEquip then
                for _, key in ipairs(equipKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end

            if GunMods.NoBulletDrop then
                for _, key in ipairs(bulletDropKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end

            if GunMods.MaxPierce then
                for _, key in ipairs(pierceKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 999
                    end
                end
            end

            if GunMods.OneShot then
                for _, key in ipairs(damageKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 9999
                    end
                end
            end

            if GunMods.NoCooldowns then
                for _, key in ipairs(cooldownKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end
        end)
    end

    local function scanForConfigs(parent, depth)
        if depth > 4 then return end
        if not parent then return end

        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ModuleScript") then
                local nameLower = string.lower(child.Name)
                local isWeaponModule = nameLower:find("weapon") or nameLower:find("gun") or nameLower:find("firearm")
                    or nameLower:find("config") or nameLower:find("setting") or nameLower:find("stat")
                    or nameLower:find("data") or nameLower:find("balance") or nameLower:find("attribute")

                if isWeaponModule then
                    pcall(function()
                        local success, config = pcall(function()
                            return require(child)
                        end)
                        if success and type(config) == "table" then
                            applyGunMods(config, child.Name)

                            for subKey, subVal in pairs(config) do
                                if type(subVal) == "table" then
                                    applyGunMods(subVal, child.Name .. "." .. subKey)

                                    for deepKey, deepVal in pairs(subVal) do
                                        if type(deepVal) == "table" then
                                            applyGunMods(deepVal, child.Name .. "." .. subKey .. "." .. deepKey)
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            end
            scanForConfigs(child, depth + 1)
        end
    end

    local function gunModsLoop()
        while true do
            if GunMods.MasterEnabled then
                scanForConfigs(Modules, 0)

                scanForConfigs(RS, 0)

                local tools = player:FindFirstChild("Backpack")
                if tools then
                    for _, tool in ipairs(tools:GetChildren()) do
                        if tool:IsA("Tool") then
                            for _, child in ipairs(tool:GetDescendants()) do
                                if child:IsA("ModuleScript") or child:IsA("Configuration") or child:IsA("IntValue") or child:IsA("NumberValue") then

                                    if child:IsA("NumberValue") then
                                        local nameLower = string.lower(child.Name)
                                        if GunMods.NoRecoil and (nameLower:find("recoil") or nameLower:find("kick")) then
                                            child.Value = 0
                                        elseif GunMods.NoSpread and (nameLower:find("spread") or nameLower:find("accuracy")) then
                                            child.Value = 0
                                        elseif GunMods.RapidFire and (nameLower:find("firerate") or nameLower:find("firedelay") or nameLower:find("cooldown")) then
                                            child.Value = 0.01
                                        elseif GunMods.InfiniteAmmo and (nameLower:find("ammo") or nameLower:find("clip") or nameLower:find("magazine")) then
                                            child.Value = 9999
                                        elseif GunMods.InstantReload and nameLower:find("reload") then
                                            child.Value = 0
                                        elseif GunMods.InstantEquip and nameLower:find("equip") then
                                            child.Value = 0
                                        elseif GunMods.NoBulletDrop and (nameLower:find("drop") or nameLower:find("gravity")) then
                                            child.Value = 0
                                        elseif GunMods.MaxPierce and (nameLower:find("pierce") or nameLower:find("penetration")) then
                                            child.Value = 999
                                        elseif GunMods.OneShot and nameLower:find("damage") then
                                            child.Value = 9999
                                        end
                                    end

                                    if child:IsA("ModuleScript") then
                                        pcall(function()
                                            local success, config = pcall(function() return require(child) end)
                                            if success and type(config) == "table" then
                                                applyGunMods(config, tool.Name .. "/" .. child.Name)
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(2)
        end
    end

    task.spawn(gunModsLoop)
end)

task.wait(0.15)

do

task.spawn(function()

local hideSmokeConn = nil
local hideFlashConn = nil

local function handleSmokeGrenade(inst)
    if not inst or not inst.Parent then return end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ParticleEmitter") then
            d.Enabled = false
        elseif d:IsA("BasePart") then
            d.Transparency = 1
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 1
        end
    end
    task.defer(function()
        if inst and inst.Parent then inst:Destroy() end
    end)
end

local function startHideSmoke()
    if hideSmokeConn then return end

    for _, v in ipairs(workspace:GetDescendants()) do
        if v and v.Name == "Smoke Grenade" then handleSmokeGrenade(v) end
    end

    hideSmokeConn = workspace.DescendantAdded:Connect(function(child)
        if not VisualSettings.HideSmoke then return end
        if typeof(child) == "Instance" and child.Name == "Smoke Grenade" then
            handleSmokeGrenade(child)
        end
    end)
end

local function stopHideSmoke()
    if hideSmokeConn then hideSmokeConn:Disconnect(); hideSmokeConn = nil end
end

local function handleFlashInstance(inst)
    if not inst then return end
    task.defer(function()
        if inst and inst.Parent then inst:Destroy() end
    end)
end

local function startHideFlash()
    if hideFlashConn then return end

    for _, v in ipairs(workspace:GetDescendants()) do
        if v and (v.Name == "FlashbangEffect" or v.Name:lower():find("flash")) then
            handleFlashInstance(v)
        end
    end

    hideFlashConn = workspace.DescendantAdded:Connect(function(child)
        if not VisualSettings.HideFlashbang then return end
        if child and (child.Name == "FlashbangEffect" or child.Name:lower():find("flash")) then
            handleFlashInstance(child)
        end
    end)

    task.spawn(function()
        while VisualSettings.HideFlashbang do
            if Library.Unloaded then break end
            pcall(function()
                local playerGui = lp:FindFirstChildOfClass("PlayerGui")
                if playerGui then
                    for _, gui in ipairs(playerGui:GetChildren()) do
                        for _, child in ipairs(gui:GetDescendants()) do
                            if child:IsA("Frame") or child:IsA("ImageLabel") then
                                local nameLower = child.Name:lower()
                                if nameLower:find("flash") or nameLower:find("blind") or nameLower:find("stun") or nameLower:find("whiteout") then
                                    child.Visible = false
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.3)
        end
    end)
end

local function stopHideFlash()
    if hideFlashConn then hideFlashConn:Disconnect(); hideFlashConn = nil end
end

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end

        if VisualSettings.HideSmoke then
            if not hideSmokeConn then startHideSmoke() end
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj.Name == "Smoke Grenade" then handleSmokeGrenade(obj) end
                    if obj:IsA("Smoke") or (obj:IsA("ParticleEmitter") and (obj.Name:lower():find("smoke") or obj.Parent.Name:lower():find("smoke"))) then
                        obj.Enabled = false
                    end
                end
            end)
        else
            stopHideSmoke()
        end

        if VisualSettings.HideFlashbang then
            if not hideFlashConn then startHideFlash() end
        else
            stopHideFlash()
        end
    end
end)
end)
end

-- ============================================================
-- PURPLE GHOST ESP SYSTEM (self-contained)
-- ScreenGui-based ESP with Box/Filled/Tracers/Health/Names/Distance/Chams
-- ============================================================

getgenv()._ZX_PGEsp = (function()
    local Settings = {
        EspBoxes = false,
        EspFilledBoxes = false,
        EspLines = false,
        EspHealth = false,
        EspNames = false,
        EspDistance = false,
        EspChams = false,
        EspBoxColor = Color3.fromRGB(100, 200, 255),
        EspFilledColor = Color3.fromRGB(100, 200, 255),
        EspTracerColor = Color3.fromRGB(150, 200, 255),
        EspHealthColor = Color3.fromRGB(0, 255, 0),
        EspNameColor = Color3.fromRGB(255, 255, 255),
        EspDistanceColor = Color3.fromRGB(220, 220, 220),
        EspChamsColor = Color3.fromRGB(100, 200, 255),
        MaxEspDistance = 400,
        BoxThickness = 1,
        LineThickness = 1,
        BoxSizeMultiplier = 1200,
        FilledBoxTransparency = 0.5,
        ChamsBrightness = 5.0,
        TracerPosition = "Bottom",
    }

    local _lp = game:GetService("Players").LocalPlayer
    local _players = game:GetService("Players")
    local _rs = game:GetService("RunService")
    local _camera = workspace.CurrentCamera

    local HEALTH_BAR_WIDTH, HEALTH_BAR_OFFSET = 3, 5
    local EspRegistry = {}
    local EspGui = nil
    local conn = nil

    local function createEspElements(p)
        if p == _lp or EspRegistry[p] then return end
        local elements = {}

        local BoxFrame = Instance.new("Frame", EspGui)
        BoxFrame.BackgroundTransparency = 1
        BoxFrame.Visible = false
        local Outline = Instance.new("Frame", BoxFrame)
        Outline.Size = UDim2.new(1, 0, 1, 0)
        Outline.BackgroundTransparency = 1
        local Stroke = Instance.new("UIStroke", Outline)
        Stroke.Thickness = Settings.BoxThickness
        elements.Box = BoxFrame
        elements.BoxStroke = Stroke

        local FilledBox = Instance.new("Frame", EspGui)
        FilledBox.BorderSizePixel = 0
        FilledBox.Visible = false
        elements.FilledBox = FilledBox

        local TracerLine = Instance.new("Frame", EspGui)
        TracerLine.AnchorPoint = Vector2.new(0.5, 0.5)
        TracerLine.BorderSizePixel = 0
        TracerLine.Visible = false
        elements.Tracer = TracerLine

        local HealthContainer = Instance.new("Frame", EspGui)
        HealthContainer.BackgroundColor3 = Color3.fromRGB(0,0,0)
        HealthContainer.BackgroundTransparency = 0.3
        HealthContainer.BorderSizePixel = 0
        HealthContainer.Visible = false
        local HealthFill = Instance.new("Frame", HealthContainer)
        HealthFill.BorderSizePixel = 0
        HealthFill.AnchorPoint = Vector2.new(0, 1)
        HealthFill.Position = UDim2.new(0, 0, 1, 0)
        elements.HealthBar = HealthContainer
        elements.HealthFill = HealthFill

        local TagLabel = Instance.new("TextLabel", EspGui)
        TagLabel.BackgroundTransparency = 1
        TagLabel.AnchorPoint = Vector2.new(0.5, 1)
        TagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TagLabel.Font = Enum.Font.GothamMedium
        TagLabel.TextSize = 12
        TagLabel.Visible = false
        local TextStroke = Instance.new("UIStroke", TagLabel)
        TextStroke.Color = Color3.fromRGB(0, 0, 0)
        TextStroke.Thickness = 1
        elements.Tag = TagLabel

        local DistLabel = Instance.new("TextLabel", EspGui)
        DistLabel.BackgroundTransparency = 1
        DistLabel.AnchorPoint = Vector2.new(0.5, 0)
        DistLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        DistLabel.Font = Enum.Font.GothamMedium
        DistLabel.TextSize = 11
        DistLabel.Visible = false
        local DistStroke = Instance.new("UIStroke", DistLabel)
        DistStroke.Color = Color3.fromRGB(0, 0, 0)
        DistStroke.Thickness = 1
        elements.DistTag = DistLabel

        elements.CurrentCham = nil
        EspRegistry[p] = elements
    end

    local function removeEspElements(p)
        if EspRegistry[p] then
            if EspRegistry[p].CurrentCham then
                EspRegistry[p].CurrentCham:Destroy()
            end
            for _, obj in pairs(EspRegistry[p]) do
                if typeof(obj) == "Instance" then obj:Destroy() end
            end
            EspRegistry[p] = nil
        end
    end

    local function start()
        if conn then return end
        EspGui = Instance.new("ScreenGui")
        EspGui.Name = "ZaiPGEsp"
        EspGui.ResetOnSpawn = false
        EspGui.IgnoreGuiInset = true
        pcall(function() EspGui.Parent = game:GetService("CoreGui") end)
        if not EspGui.Parent then
            EspGui.Parent = _lp:WaitForChild("PlayerGui")
        end

        for _, p in ipairs(_players:GetPlayers()) do createEspElements(p) end
        _players.PlayerAdded:Connect(createEspElements)
        _players.PlayerRemoving:Connect(removeEspElements)

        conn = _rs.RenderStepped:Connect(function()
            for playerObj, cache in pairs(EspRegistry) do
                local character = playerObj.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                -- Team Check: skip teammates if enabled (in global EspSettings)
                if EspSettings and EspSettings.TeamCheckESP and playerObj ~= _lp then
                    local _skip = false
                    pcall(function()
                        if isTeammate and isTeammate(playerObj) then _skip = true end
                    end)
                    if _skip then
                        cache.Box.Visible = false; cache.FilledBox.Visible = false; cache.Tracer.Visible = false
                        cache.HealthBar.Visible = false; cache.Tag.Visible = false; cache.DistTag.Visible = false
                        if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                        continue
                    end
                end

                if rootPart and humanoid and humanoid.Health > 0 then
                    local screenPos, onScreen = _camera:WorldToViewportPoint(rootPart.Position)
                    local distance = (_camera.CFrame.Position - rootPart.Position).Magnitude

                    if onScreen and distance <= Settings.MaxEspDistance and distance >= 1 then
                        local sizeX = Settings.BoxSizeMultiplier / distance
                        local sizeY = sizeX * 1.45
                        local boxPosX = screenPos.X - (sizeX / 2)
                        local boxPosY = screenPos.Y - (sizeY / 2)

                        if Settings.EspBoxes then
                            cache.Box.Position = UDim2.new(0, boxPosX, 0, boxPosY)
                            cache.Box.Size = UDim2.new(0, sizeX, 0, sizeY)
                            cache.BoxStroke.Thickness = Settings.BoxThickness
                            cache.BoxStroke.Color = Settings.EspBoxColor
                            cache.Box.Visible = true
                        else cache.Box.Visible = false end

                        if Settings.EspFilledBoxes then
                            cache.FilledBox.Position = UDim2.new(0, boxPosX, 0, boxPosY)
                            cache.FilledBox.Size = UDim2.new(0, sizeX, 0, sizeY)
                            cache.FilledBox.BackgroundColor3 = Settings.EspFilledColor
                            cache.FilledBox.BackgroundTransparency = Settings.FilledBoxTransparency
                            cache.FilledBox.Visible = true
                        else cache.FilledBox.Visible = false end

                        if Settings.EspLines then
                            local vSize = _camera.ViewportSize
                            local startX, startY, endX, endY
                            if Settings.TracerPosition == "Top" then
                                startX, startY = vSize.X / 2, 0
                            elseif Settings.TracerPosition == "Center" then
                                startX, startY = vSize.X / 2, vSize.Y / 2
                            else
                                startX, startY = vSize.X / 2, vSize.Y
                            end
                            endX, endY = screenPos.X, screenPos.Y
                            local dx, dy = endX - startX, endY - startY
                            local length = math.sqrt(dx^2 + dy^2)
                            local angle = math.atan2(dy, dx)
                            cache.Tracer.Position = UDim2.new(0, startX + dx/2, 0, startY + dy/2)
                            cache.Tracer.Size = UDim2.new(0, length, 0, Settings.LineThickness)
                            cache.Tracer.BackgroundColor3 = Settings.EspTracerColor
                            cache.Tracer.Rotation = math.deg(angle)
                            cache.Tracer.Visible = true
                        else cache.Tracer.Visible = false end

                        if Settings.EspHealth then
                            local hPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            cache.HealthBar.Position = UDim2.new(0, boxPosX - HEALTH_BAR_OFFSET - HEALTH_BAR_WIDTH, 0, boxPosY)
                            cache.HealthBar.Size = UDim2.new(0, HEALTH_BAR_WIDTH, 0, sizeY)
                            cache.HealthFill.Size = UDim2.new(1, 0, hPercent, 0)
                            cache.HealthFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50):Lerp(Settings.EspHealthColor, hPercent)
                            cache.HealthBar.Visible = true
                        else cache.HealthBar.Visible = false end

                        if Settings.EspNames then
                            cache.Tag.Position = UDim2.new(0, screenPos.X, 0, boxPosY - 4)
                            cache.Tag.Text = playerObj.DisplayName
                            cache.Tag.TextColor3 = Settings.EspNameColor
                            cache.Tag.TextSize = math.clamp(14 - (distance / 100), 10, 14)
                            cache.Tag.Visible = true
                        else cache.Tag.Visible = false end

                        if Settings.EspDistance then
                            cache.DistTag.Position = UDim2.new(0, screenPos.X, 0, boxPosY + sizeY + 2)
                            cache.DistTag.Text = string.format("%d Studs", math.floor(distance))
                            cache.DistTag.TextColor3 = Settings.EspDistanceColor
                            cache.DistTag.TextSize = math.clamp(12 - (distance / 100), 9, 12)
                            cache.DistTag.Visible = true
                        else cache.DistTag.Visible = false end

                        if Settings.EspChams then
                            if not cache.CurrentCham or cache.CurrentCham.Parent ~= character then
                                if cache.CurrentCham then cache.CurrentCham:Destroy() end
                                local freshHighlight = Instance.new("Highlight")
                                freshHighlight.Name = "ZaiPGCham"
                                freshHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                freshHighlight.Parent = character
                                cache.CurrentCham = freshHighlight
                            end
                            local neonMultiplier = Settings.ChamsBrightness
                            local cc = Settings.EspChamsColor
                            cache.CurrentCham.FillColor = Color3.new(cc.R * neonMultiplier, cc.G * neonMultiplier, cc.B * neonMultiplier)
                            cache.CurrentCham.OutlineColor = Color3.new(cc.R * neonMultiplier, cc.G * neonMultiplier, cc.B * neonMultiplier)
                            cache.CurrentCham.FillTransparency = 0.2
                            cache.CurrentCham.OutlineTransparency = 0
                            cache.CurrentCham.Enabled = true
                        else
                            if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                        end
                    else
                        cache.Box.Visible = false; cache.FilledBox.Visible = false; cache.Tracer.Visible = false
                        cache.HealthBar.Visible = false; cache.Tag.Visible = false; cache.DistTag.Visible = false
                        if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                    end
                else
                    cache.Box.Visible = false; cache.FilledBox.Visible = false; cache.Tracer.Visible = false
                    cache.HealthBar.Visible = false; cache.Tag.Visible = false; cache.DistTag.Visible = false
                    if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                end
            end
        end)
    end

    local function stop()
        if conn then conn:Disconnect() conn = nil end
        for p, _ in pairs(EspRegistry) do removeEspElements(p) end
        if EspGui then EspGui:Destroy() EspGui = nil end
    end

    return {
        Settings = Settings,
        start = start,
        stop = stop,
    }
end)()

local _PG_ESP = getgenv()._ZX_PGEsp
local _PG_S = _PG_ESP.Settings

-- ============================================================
-- ESP UI (Purple Ghost style)
-- ============================================================

-- EspGroup = "ESP Elements" (Left)
EspGroup:AddToggle("EspBoxOutlines", {
    Text = "Box Outlines",
    Default = false,
}):AddColorPicker("EspBoxColor", {
    Default = Color3.fromRGB(100, 200, 255),
})
Toggles.EspBoxOutlines:OnChanged(function()
    _PG_S.EspBoxes = Toggles.EspBoxOutlines.Value
    if _PG_S.EspBoxes or _PG_S.EspFilledBoxes or _PG_S.EspLines or _PG_S.EspHealth or _PG_S.EspNames or _PG_S.EspDistance or _PG_S.EspChams then
        _PG_ESP.start()
    elseif not (_PG_S.EspBoxes or _PG_S.EspFilledBoxes or _PG_S.EspLines or _PG_S.EspHealth or _PG_S.EspNames or _PG_S.EspDistance or _PG_S.EspChams) then
        _PG_ESP.stop()
    end
end)
Options.EspBoxColor:OnChanged(function()
    _PG_S.EspBoxColor = Options.EspBoxColor.Value
end)

EspGroup:AddToggle("EspFilledBoxes", {
    Text = "Filled Boxes",
    Default = false,
}):AddColorPicker("EspFilledColor", {
    Default = Color3.fromRGB(100, 200, 255),
})
Toggles.EspFilledBoxes:OnChanged(function()
    _PG_S.EspFilledBoxes = Toggles.EspFilledBoxes.Value
    if _PG_S.EspFilledBoxes then _PG_ESP.start() end
end)
Options.EspFilledColor:OnChanged(function()
    _PG_S.EspFilledColor = Options.EspFilledColor.Value
end)

EspGroup:AddSlider("FilledBoxTransparencySlider", {
    Text = "Filled Transparency",
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
Options.FilledBoxTransparencySlider:OnChanged(function()
    _PG_S.FilledBoxTransparency = Options.FilledBoxTransparencySlider.Value / 100
end)

EspGroup:AddToggle("EspLineTracers", {
    Text = "Line Tracers",
    Default = false,
}):AddColorPicker("EspTracerColor", {
    Default = Color3.fromRGB(150, 200, 255),
})
Toggles.EspLineTracers:OnChanged(function()
    _PG_S.EspLines = Toggles.EspLineTracers.Value
    if _PG_S.EspLines then _PG_ESP.start() end
end)
Options.EspTracerColor:OnChanged(function()
    _PG_S.EspTracerColor = Options.EspTracerColor.Value
end)

EspGroup:AddDropdown("TracerPositionDropdown", {
    Values = {"Top", "Center", "Bottom"},
    Default = 3,
    Multi = false,
    Text = "Tracer Position",
})
Options.TracerPositionDropdown:OnChanged(function()
    _PG_S.TracerPosition = Options.TracerPositionDropdown.Value
end)

EspGroup:AddDivider()

EspGroup:AddToggle("EspHealthBars", {
    Text = "Health Bars",
    Default = false,
}):AddColorPicker("EspHealthColor", {
    Default = Color3.fromRGB(0, 255, 0),
})
Toggles.EspHealthBars:OnChanged(function()
    _PG_S.EspHealth = Toggles.EspHealthBars.Value
    if _PG_S.EspHealth then _PG_ESP.start() end
end)
Options.EspHealthColor:OnChanged(function()
    _PG_S.EspHealthColor = Options.EspHealthColor.Value
end)

EspGroup:AddToggle("EspNames", {
    Text = "Player Names",
    Default = false,
}):AddColorPicker("EspNameColor", {
    Default = Color3.fromRGB(255, 255, 255),
})
Toggles.EspNames:OnChanged(function()
    _PG_S.EspNames = Toggles.EspNames.Value
    if _PG_S.EspNames then _PG_ESP.start() end
end)
Options.EspNameColor:OnChanged(function()
    _PG_S.EspNameColor = Options.EspNameColor.Value
end)

EspGroup:AddToggle("EspDistance", {
    Text = "Distance Tags",
    Default = false,
}):AddColorPicker("EspDistanceColor", {
    Default = Color3.fromRGB(220, 220, 220),
})
Toggles.EspDistance:OnChanged(function()
    _PG_S.EspDistance = Toggles.EspDistance.Value
    if _PG_S.EspDistance then _PG_ESP.start() end
end)
Options.EspDistanceColor:OnChanged(function()
    _PG_S.EspDistanceColor = Options.EspDistanceColor.Value
end)

EspGroup:AddDivider()

EspGroup:AddSlider("MaxEspDistance", {
    Text = "Max Distance",
    Default = 400,
    Min = 50,
    Max = 2000,
    Rounding = 0,
    Suffix = " studs",
})
Options.MaxEspDistance:OnChanged(function()
    _PG_S.MaxEspDistance = Options.MaxEspDistance.Value
end)

EspGroup:AddSlider("BoxThickness", {
    Text = "Box Thickness",
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 1,
})
Options.BoxThickness:OnChanged(function()
    _PG_S.BoxThickness = Options.BoxThickness.Value
end)

EspGroup:AddSlider("LineThickness", {
    Text = "Tracer Thickness",
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 1,
})
Options.LineThickness:OnChanged(function()
    _PG_S.LineThickness = Options.LineThickness.Value
end)

EspGroup:AddSlider("BoxSizeMultiplier", {
    Text = "Box Scale",
    Default = 1200,
    Min = 800,
    Max = 2000,
    Rounding = 0,
})
Options.BoxSizeMultiplier:OnChanged(function()
    _PG_S.BoxSizeMultiplier = Options.BoxSizeMultiplier.Value
end)

EspGroup:AddDivider()

EspGroup:AddToggle("TeamCheckESP", {
    Text = "Team Check",
    Default = false,
    Tooltip = "Skips showing ESP on teammates (only show enemies).",
})
Toggles.TeamCheckESP:OnChanged(function()
    EspSettings.TeamCheckESP = Toggles.TeamCheckESP.Value
end)

-- EspVisualGroup = "Neon Chams" (Right)
EspVisualGroup:AddToggle("EspChamsToggle", {
    Text = "Enable Neon Chams",
    Default = false,
})
Toggles.EspChamsToggle:OnChanged(function()
    _PG_S.EspChams = Toggles.EspChamsToggle.Value
    if _PG_S.EspChams then _PG_ESP.start() else
        if not (_PG_S.EspBoxes or _PG_S.EspFilledBoxes or _PG_S.EspLines or _PG_S.EspHealth or _PG_S.EspNames or _PG_S.EspDistance) then
            _PG_ESP.stop()
        end
    end
end)

EspVisualGroup:AddLabel("Chams Color"):AddColorPicker("EspChamsColor", {
    Default = Color3.fromRGB(100, 200, 255),
})
Options.EspChamsColor:OnChanged(function()
    _PG_S.EspChamsColor = Options.EspChamsColor.Value
end)

EspVisualGroup:AddSlider("ChamsBrightnessSlider", {
    Text = "Glow Power",
    Default = 5,
    Min = 1,
    Max = 15,
    Rounding = 1,
})
Options.ChamsBrightnessSlider:OnChanged(function()
    _PG_S.ChamsBrightness = Options.ChamsBrightnessSlider.Value
end)

EspVisualGroup:AddDivider()
EspVisualGroup:AddLabel("Advanced Features", true)
EspVisualGroup:AddLabel("Professional wallhack ESP")
EspVisualGroup:AddLabel("Real-time player tracking")
EspVisualGroup:AddLabel("Customizable glow effects")

VisualsGroup:AddToggle("AnimatedCrosshair", {
        Text = "Animated Crosshair",
        Default = VisualSettings.CrosshairEnabled,
})
Toggles.AnimatedCrosshair:OnChanged(function()
        VisualSettings.CrosshairEnabled = Toggles.AnimatedCrosshair.Value
end)

VisualsGroup:AddDropdown("CrosshairColorPresets", {
        Values = {"Red", "Blue", "Purple", "Yellow", "Pink", "Orange", "Cyan", "Green", "White", "Rainbow"},
        Default = 3,
        Multi = false,
        Text = "Crosshair Color Presets",
})
Options.CrosshairColorPresets:OnChanged(function()
        VisualSettings.CrosshairColorMode = Options.CrosshairColorPresets.Value
end)

SkyColorGroup:AddToggle("SkyColorEnabled", {
        Text = "Sky Color Override",
        Default = false,
        Tooltip = "Override the game's sky color and lighting with your custom colors below.",
})
Toggles.SkyColorEnabled:OnChanged(function()
        VisualSettings.SkyColorEnabled = Toggles.SkyColorEnabled.Value
        applySkyColor()
end)

SkyColorGroup:AddLabel("Sky & Ambient Color"):AddColorPicker("SkyCustomColor", {
        Default = Color3.fromRGB(80, 80, 100),
        Title = "Sky Color (Ambient + Outdoor)",
})
Options.SkyCustomColor:OnChanged(function()
        VisualSettings.AmbientColor = Options.SkyCustomColor.Value
        applySkyColor()
end)

SkyColorGroup:AddSlider("SkyBrightness", {
        Text = "Brightness",
        Default = 1.5,
        Min = 0,
        Max = 3,
        Rounding = 2,
        Tooltip = "How bright the scene is. 0= pitch black, 2= normal, 3= very bright.",
})
Options.SkyBrightness:OnChanged(function()
        VisualSettings.SkyBrightness = Options.SkyBrightness.Value
        applySkyColor()
end)

SkyColorGroup:AddSlider("SkyClockTime", {
        Text = "Time of Day",
        Default = 12,
        Min = 0,
        Max = 24,
        Rounding = 1,
        Suffix = "h",
        Tooltip = "0=midnight, 6=dawn, 12=noon, 18=dusk, 24=midnight again.",
})
Options.SkyClockTime:OnChanged(function()
        VisualSettings.SkyClockTime = Options.SkyClockTime.Value
        applySkyColor()
end)

GrenadeEffectsGroup:AddToggle("HideSmoke", {
        Text = "Hide Smoke",
        Default = VisualSettings.HideSmoke,
        Tooltip = "Removes smoke grenade visual effects (Smoke, ParticleEmitters, smoke Parts)",
})
Toggles.HideSmoke:OnChanged(function()
        VisualSettings.HideSmoke = Toggles.HideSmoke.Value
end)

GrenadeEffectsGroup:AddToggle("HideFlashbang", {
        Text = "Hide Flashbang",
        Default = VisualSettings.HideFlashbang,
        Tooltip = "Removes flashbang screen effects (flash/blind GUI overlays)",
})
Toggles.HideFlashbang:OnChanged(function()
        VisualSettings.HideFlashbang = Toggles.HideFlashbang.Value
end)

GrenadeEffectsGroup:AddToggle("LockIndicatorToggle", {
        Text = "Lock Indicator",
        Default = VisualSettings.LockIndicator,
        Tooltip = "Shows LOCKED: NAME / SCANNING... indicator in top-right corner",
})
Toggles.LockIndicatorToggle:OnChanged(function()
        VisualSettings.LockIndicator = Toggles.LockIndicatorToggle.Value
end)

------------------------------------------------------------------
-- Advanced Visual Features (Bullet Tracer + Latex + Bloom)
------------------------------------------------------------------
VisualsGroup:AddDivider()
VisualsGroup:AddLabel("Advanced Bullet Tracer", true)

VisualsGroup:AddToggle("BulletTracerEnabled", {
        Text = "Bullet Tracer (Trail)",
        Default = VisualSettings.BulletTracerEnabled,
        Tooltip = "Spawns a Neon Part with a Trail effect every time you fire. Professional look.",
})
Toggles.BulletTracerEnabled:OnChanged(function()
        VisualSettings.BulletTracerEnabled = Toggles.BulletTracerEnabled.Value
end)

VisualsGroup:AddDropdown("BulletTracerColor", {
        Values = {"Red", "Green", "Pink", "Toothpaste", "White"},
        Default = 4,
        Multi = false,
        Text = "Tracer Color",
})
Options.BulletTracerColor:OnChanged(function()
        VisualSettings.BulletTracerColorName = Options.BulletTracerColor.Value
end)

VisualsGroup:AddSlider("BulletTracerLifetime", {
        Text = "Trail Lifetime",
        Default = VisualSettings.BulletTracerLifetime,
        Min = 1,
        Max = 30,
        Rounding = 0,
        Suffix = " s",
        Tooltip = "How long the trail effect stays visible.",
})
Options.BulletTracerLifetime:OnChanged(function()
        VisualSettings.BulletTracerLifetime = Options.BulletTracerLifetime.Value
end)

VisualsGroup:AddSlider("BulletTracerSpeed", {
        Text = "Bullet Speed",
        Default = VisualSettings.BulletTracerSpeed,
        Min = 100,
        Max = 2000,
        Rounding = 0,
        Suffix = " studs/s",
        Tooltip = "How fast the bullet part travels forward.",
})
Options.BulletTracerSpeed:OnChanged(function()
        VisualSettings.BulletTracerSpeed = Options.BulletTracerSpeed.Value
end)

VisualsGroup:AddDivider()
VisualsGroup:AddLabel("Weapon & Arm Latex", true)

VisualsGroup:AddToggle("WeaponLatexEnabled", {
        Text = "Weapon Latex (Viewmodel)",
        Default = VisualSettings.WeaponLatexEnabled,
        Tooltip = "Applies ForceField material to the viewmodel's arms. Aesthetic purple glow.",
})
Toggles.WeaponLatexEnabled:OnChanged(function()
        VisualSettings.WeaponLatexEnabled = Toggles.WeaponLatexEnabled.Value
end)

VisualsGroup:AddToggle("ArmLatexEnabled", {
        Text = "Arm Latex (Character)",
        Default = VisualSettings.ArmLatexEnabled,
        Tooltip = "Applies ForceField material to your character's arms. Visible in third person.",
})
Toggles.ArmLatexEnabled:OnChanged(function()
        VisualSettings.ArmLatexEnabled = Toggles.ArmLatexEnabled.Value
end)

VisualsGroup:AddDivider()
VisualsGroup:AddLabel("Bloom Effect", true)

VisualsGroup:AddToggle("BloomEnabled", {
        Text = "Enable Bloom",
        Default = VisualSettings.BloomEnabled,
        Tooltip = "Toggles the game's BloomEffect. Adds a soft glow to bright areas.",
})
Toggles.BloomEnabled:OnChanged(function()
        VisualSettings.BloomEnabled = Toggles.BloomEnabled.Value
end)

VisualsGroup:AddSlider("BloomIntensity", {
        Text = "Bloom Intensity",
        Default = VisualSettings.BloomIntensity,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Tooltip = "Higher = more bloom glow. Scale /10 internally.",
})
Options.BloomIntensity:OnChanged(function()
        VisualSettings.BloomIntensity = Options.BloomIntensity.Value
end)

------------------------------------------------------------------
-- Thirdperson + FOV Override + World Visual Effects
------------------------------------------------------------------
VisualsGroup:AddDivider()
VisualsGroup:AddLabel("Thirdperson & FOV", true)

VisualsGroup:AddToggle("ThirdpersonEnabled", {
        Text = "Thirdperson Mode",
        Default = VisualSettings.ThirdpersonEnabled,
        Tooltip = "Switches camera to Classic + zooms out. Lets you see your character.",
})
Toggles.ThirdpersonEnabled:OnChanged(function()
        VisualSettings.ThirdpersonEnabled = Toggles.ThirdpersonEnabled.Value
        ZX_Visuals.applyThirdperson()
end)

VisualsGroup:AddSlider("ThirdpersonDistance", {
        Text = "Thirdperson Distance",
        Default = VisualSettings.ThirdpersonDistance,
        Min = 5,
        Max = 30,
        Rounding = 0,
        Tooltip = "How far the camera zooms out in thirdperson.",
})
Options.ThirdpersonDistance:OnChanged(function()
        VisualSettings.ThirdpersonDistance = Options.ThirdpersonDistance.Value
        if VisualSettings.ThirdpersonEnabled then
                ZX_Visuals.applyThirdperson()
        end
end)

VisualsGroup:AddDropdown("ThirdpersonActivation", {
        Values = {"Always on", "K", "O", "P"},
        Default = 1,
        Multi = false,
        Text = "Activation Key",
        Tooltip = "Always on = always thirdperson | K/O/P = toggle with that key.",
})
Options.ThirdpersonActivation:OnChanged(function()
        VisualSettings.ThirdpersonActivation = Options.ThirdpersonActivation.Value
        if VisualSettings.ThirdpersonEnabled then
                if Options.ThirdpersonActivation.Value == "Always on" then
                        ZX_Visuals.applyThirdperson()
                else
                        VisualSettings.ThirdpersonEnabled = false
                        ZX_Visuals.applyThirdperson()
                end
        end
end)

VisualsGroup:AddToggle("FOVOverrideEnabled", {
        Text = "FOV Override",
        Default = VisualSettings.FOVOverrideEnabled,
        Tooltip = "Overrides the game's FieldOfView. Higher = wider view.",
})
Toggles.FOVOverrideEnabled:OnChanged(function()
        VisualSettings.FOVOverrideEnabled = Toggles.FOVOverrideEnabled.Value
        ZX_Visuals.applyFOVOverride()
end)

VisualsGroup:AddSlider("FOVOverrideValue", {
        Text = "FOV Value",
        Default = VisualSettings.FOVOverrideValue,
        Min = 70,
        Max = 170,
        Rounding = 0,
        Tooltip = "Gameplay FOV value (70-170). Higher = wider view.",
})
Options.FOVOverrideValue:OnChanged(function()
        VisualSettings.FOVOverrideValue = Options.FOVOverrideValue.Value
        if VisualSettings.FOVOverrideEnabled then
                ZX_Visuals.applyFOVOverride()
        end
end)

------------------------------------------------------------------
-- World Visual Effects (Color + Fog + Weather + Night)
-- Moved to World tab (WorldEffectsGroup)
------------------------------------------------------------------

WorldEffectsGroup:AddToggle("WorldColorEnabled", {
        Text = "World Color",
        Default = VisualSettings.WorldColorEnabled,
        Tooltip = "Changes Lighting.Ambient to a custom color.",
})
Toggles.WorldColorEnabled:OnChanged(function()
        VisualSettings.WorldColorEnabled = Toggles.WorldColorEnabled.Value
        ZX_Visuals.applyWorldColor()
end)

WorldEffectsGroup:AddDropdown("WorldColorName", {
        Values = {"red", "orange", "yellow", "green", "skyblue", "blue", "violet", "pink", "white", "brown"},
        Default = 9,
        Multi = false,
        Text = "World Color",
})
Options.WorldColorName:OnChanged(function()
        VisualSettings.WorldColorName = Options.WorldColorName.Value
        if VisualSettings.WorldColorEnabled then
                ZX_Visuals.applyWorldColor()
        end
end)

WorldEffectsGroup:AddToggle("FogEnabled", {
        Text = "Fog",
        Default = VisualSettings.FogEnabled,
        Tooltip = "Adds fog to the world. Adjusts FogStart/FogEnd/FogColor.",
})
Toggles.FogEnabled:OnChanged(function()
        VisualSettings.FogEnabled = Toggles.FogEnabled.Value
        ZX_Visuals.applyFog()
end)

WorldEffectsGroup:AddDropdown("FogColorName", {
        Values = {"red", "orange", "yellow", "green", "skyblue", "blue", "violet", "pink", "white", "brown"},
        Default = 9,
        Multi = false,
        Text = "Fog Color",
})
Options.FogColorName:OnChanged(function()
        VisualSettings.FogColorName = Options.FogColorName.Value
        if VisualSettings.FogEnabled then
                ZX_Visuals.applyFog()
        end
end)

WorldEffectsGroup:AddSlider("FogDistance", {
        Text = "Fog Distance",
        Default = VisualSettings.FogDistance,
        Min = 100,
        Max = 10000,
        Rounding = 0,
        Tooltip = "How far the fog extends. Lower = thicker fog.",
})
Options.FogDistance:OnChanged(function()
        VisualSettings.FogDistance = Options.FogDistance.Value
        if VisualSettings.FogEnabled then
                ZX_Visuals.applyFog()
        end
end)

WorldEffectsGroup:AddDropdown("WeatherType", {
        Values = {"None", "Rain", "Snow"},
        Default = 1,
        Multi = false,
        Text = "Weather Effect",
        Tooltip = "Spawns a large Part above the player to simulate rain/snow.",
})
Options.WeatherType:OnChanged(function()
        VisualSettings.WeatherType = Options.WeatherType.Value
        ZX_Visuals.applyWeather()
end)

WorldEffectsGroup:AddToggle("NightModeEnabled", {
        Text = "Night Mode",
        Default = VisualSettings.NightModeEnabled,
        Tooltip = "Sets TimeOfDay to midnight + darkens Ambient/OutdoorAmbient.",
})
Toggles.NightModeEnabled:OnChanged(function()
        VisualSettings.NightModeEnabled = Toggles.NightModeEnabled.Value
        ZX_Visuals.applyNightMode()
end)

WinStreakGroup:AddInput("StreakTargetPlayer", {
        Default = MiscSettings.TargetPlayer,
        Numeric = false,
        Finished = true,
        Text = "Target Player Name",
        Tooltip = "The player whose streak was broken",
        Placeholder = "e.g. ABG",
})
Options.StreakTargetPlayer:OnChanged(function()
        MiscSettings.TargetPlayer = Options.StreakTargetPlayer.Value
end)

WinStreakGroup:AddInput("StreakCountNumber", {
        Default = MiscSettings.StreakValue,
        Numeric = true,
        Finished = true,
        Text = "Win Streak Count",
        Tooltip = "The amount of consecutive wins ended",
        Placeholder = "e.g. 14",
})
Options.StreakCountNumber:OnChanged(function()
        MiscSettings.StreakValue = Options.StreakCountNumber.Value
end)

WinStreakGroup:AddToggle("AutoDetectMyName", {
        Text = "Auto-Detect My Name",
        Default = MiscSettings.AutoFindMe,
        Tooltip = "Automatically reads your current game display name for the credit",
})
Toggles.AutoDetectMyName:OnChanged(function()
        MiscSettings.AutoFindMe = Toggles.AutoDetectMyName.Value
end)

WinStreakGroup:AddInput("StreakCustomEnder", {
        Default = MiscSettings.CustomEnderName,
        Numeric = false,
        Finished = true,
        Text = "Custom 'Ended By' Name",
        Tooltip = "Used when Auto-Detect My Name is disabled",
        Placeholder = "e.g. Dallas",
})
Options.StreakCustomEnder:OnChanged(function()
        MiscSettings.CustomEnderName = Options.StreakCustomEnder.Value
end)

WinStreakGroup:AddButton({
        Text = "Send Fake Server Message",
        Func = function()
                local TextChatService = game:GetService("TextChatService")
                local StarterGui = game:GetService("StarterGui")

                local enderName = MiscSettings.AutoFindMe and player.DisplayName or MiscSettings.CustomEnderName
                if enderName == "" then enderName = "Dallas" end

                local targetName = MiscSettings.TargetPlayer ~= "" and MiscSettings.TargetPlayer or "ABG"
                local streakVal = MiscSettings.StreakValue ~= "" and MiscSettings.StreakValue or "14"

                local completeMessage = string.format(
                        "[SERVER] %s's %s win streak was ended by %s (@%s)!",
                        targetName,
                        streakVal,
                        enderName,
                        string.lower(enderName)
                )

                if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                        local channel = TextChatService:FindFirstChild("RBXGeneral", true) or TextChatService.TextChannels.RBXSystem
                        channel:DisplaySystemMessage('<font color="rgb(224, 130, 41)"><b>' .. completeMessage .. '</b></font>')
                else
                        pcall(function()
                                StarterGui:SetCore("ChatMakeSystemMessage", {
                                        Text = completeMessage,
                                        Color = Color3.fromRGB(224, 130, 41),
                                        Font = Enum.Font.FredokaOne,
                                        TextSize = 18
                                })
                        end)
                end
        end,
        DoubleClick = false
})

do
local SlideToEnemy = {
    Enabled = false,
    DistanceBehind = 5,
    HeightAbove = 3,
    Speed = 50,
    Conn = nil,
}

local function findClosestEnemyForSlide()
    local lp = game:GetService("Players").LocalPlayer
    local char = lp.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest = nil
    local closestDist = math.huge
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        if p ~= lp and p.Character then
            local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if pHrp and hum and hum.Health > 0 then
                local d = (pHrp.Position - hrp.Position).Magnitude
                if d < closestDist and d < 200 then
                    closestDist = d
                    closest = p.Character
                end
            end
        end
    end
    return closest
end

local function startSlideToEnemy()
    if SlideToEnemy.Conn then return end
    SlideToEnemy.Conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
        local lp = game:GetService("Players").LocalPlayer
        local char = lp.Character
        if not char then return end
        local myHrp = char:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end
        local target = findClosestEnemyForSlide()
        if not target then return end
        local targetHrp = target:FindFirstChild("HumanoidRootPart")
        if not targetHrp then return end

        local goalPos = targetHrp.Position - targetHrp.CFrame.LookVector * SlideToEnemy.DistanceBehind + Vector3.new(0, SlideToEnemy.HeightAbove, 0)
        local direction = (goalPos - myHrp.Position)
        if direction.Magnitude > 0.5 then
            local unit = direction.Unit
            myHrp.CFrame = myHrp.CFrame + unit * SlideToEnemy.Speed * dt
        end
    end)
end

local function stopSlideToEnemy()
    if SlideToEnemy.Conn then
        SlideToEnemy.Conn:Disconnect()
        SlideToEnemy.Conn = nil
    end
end

PlayerMovementGroup:AddDivider()
PlayerMovementGroup:AddLabel("Slide to Enemy")
PlayerMovementGroup:AddToggle("SlideToEnemyEnabled", {
        Text = "Slide to Enemy",
        Default = false,
        Tooltip = "Slides your character behind + above the nearest enemy. Great for confusing aimbots and getting close quickly.",
})
Toggles.SlideToEnemyEnabled:OnChanged(function()
        SlideToEnemy.Enabled = Toggles.SlideToEnemyEnabled.Value
        if SlideToEnemy.Enabled then
            startSlideToEnemy()
        else
            stopSlideToEnemy()
        end
end)

PlayerMovementGroup:AddDivider()
PlayerMovementGroup:AddLabel("Auto Walk (Follow Target)")
PlayerMovementGroup:AddToggle("AutoWalkEnabled", {
        Text = "Enable Auto Walk",
        Default = PlayerSettings.AutoWalkEnabled,
        Tooltip = "Automatically walks toward your current aim target. Stops if you press WASD or Space.",
})
Toggles.AutoWalkEnabled:OnChanged(function()
        PlayerSettings.AutoWalkEnabled = Toggles.AutoWalkEnabled.Value
        if not PlayerSettings.AutoWalkEnabled and keyrelease then
                pcall(keyrelease, 87)
                pcall(keyrelease, 65)
                pcall(keyrelease, 83)
                pcall(keyrelease, 68)
                pcall(keyrelease, 32)
        end
end)

PlayerMovementGroup:AddDropdown("AutoWalkMethod", {
        Values = {"Normal", "Strafing", "Jumping", "JumpStrafe", "Flanking"},
        Default = 1,
        Multi = false,
        Text = "Movement Method",
        Tooltip = "Normal=walk straight | Strafing=walk+sine wave | Jumping=walk+jump | JumpStrafe=both | Flanking=circle around target",
})
Options.AutoWalkMethod:OnChanged(function()
        PlayerSettings.AutoWalkMethod = Options.AutoWalkMethod.Value
end)

------------------------------------------------------------------
-- Air Strafe + Auto Jump (bhop-style movement)
------------------------------------------------------------------
PlayerMovementGroup:AddDivider()
PlayerMovementGroup:AddLabel("Air Movement (Bhop)", true)

PlayerMovementGroup:AddToggle("AirStrafeEnabled", {
        Text = "Air Strafe",
        Default = PlayerSettings.AirStrafeEnabled,
        Tooltip = "Allows air movement control. Adjusts HRP velocity based on MoveDirection while in the air.",
})
Toggles.AirStrafeEnabled:OnChanged(function()
        PlayerSettings.AirStrafeEnabled = Toggles.AirStrafeEnabled.Value
end)

PlayerMovementGroup:AddSlider("AirStrafeStrength", {
        Text = "Strafe Strength",
        Default = PlayerSettings.AirStrafeStrength,
        Min = 5,
        Max = 100,
        Rounding = 0,
        Tooltip = "Higher = stronger air control. 20 is a good default.",
})
Options.AirStrafeStrength:OnChanged(function()
        PlayerSettings.AirStrafeStrength = Options.AirStrafeStrength.Value
end)

PlayerMovementGroup:AddToggle("AutoJumpEnabled", {
        Text = "Auto Jump (Bhop)",
        Default = PlayerSettings.AutoJumpEnabled,
        Tooltip = "Jumps automatically when touching the ground. Great for keeping momentum in bhop.",
})
Toggles.AutoJumpEnabled:OnChanged(function()
        PlayerSettings.AutoJumpEnabled = Toggles.AutoJumpEnabled.Value
end)

PlayerMovementGroup:AddToggle("CircleStrafeEnabled", {
        Text = "Circle Strafe (Ground)",
        Default = PlayerSettings.CircleStrafeEnabled,
        Tooltip = "Boosts horizontal velocity when A/D pressed on ground. Great for strafe jumping.",
})
Toggles.CircleStrafeEnabled:OnChanged(function()
        PlayerSettings.CircleStrafeEnabled = Toggles.CircleStrafeEnabled.Value
end)

PlayerMovementGroup:AddToggle("QuickStopEnabled", {
        Text = "Quick Stop (Anti-Slide)",
        Default = PlayerSettings.QuickStopEnabled,
        Tooltip = "Zeroes horizontal velocity when standing still. Prevents unwanted sliding.",
})
Toggles.QuickStopEnabled:OnChanged(function()
        PlayerSettings.QuickStopEnabled = Toggles.QuickStopEnabled.Value
end)

PlayerMovementGroup:AddSlider("SlideDistanceBehind", {
        Text = "Distance Behind",
        Default = 5,
        Min = 1,
        Max = 20,
        Rounding = 1,
        Suffix = " studs",
})
Options.SlideDistanceBehind:OnChanged(function()
        SlideToEnemy.DistanceBehind = Options.SlideDistanceBehind.Value
end)

PlayerMovementGroup:AddSlider("SlideHeightAbove", {
        Text = "Height Above",
        Default = 3,
        Min = 0,
        Max = 15,
        Rounding = 1,
        Suffix = " studs",
})
Options.SlideHeightAbove:OnChanged(function()
        SlideToEnemy.HeightAbove = Options.SlideHeightAbove.Value
end)

PlayerMovementGroup:AddSlider("SlideSpeed", {
        Text = "Slide Speed",
        Default = 50,
        Min = 10,
        Max = 200,
        Rounding = 0,
        Suffix = " studs/s",
})
Options.SlideSpeed:OnChanged(function()
        SlideToEnemy.Speed = Options.SlideSpeed.Value
end)
end

PlayerMovementGroup:AddToggle("WalkSpeedEnabled", {
        Text = "Custom Walk Speed",
        Default = PlayerSettings.WalkSpeedEnabled,
        Tooltip = "Override your walk speed (Always Active — keeps reapplying every frame)",
})
Toggles.WalkSpeedEnabled:OnChanged(function()
        PlayerSettings.WalkSpeedEnabled = Toggles.WalkSpeedEnabled.Value
        if not PlayerSettings.WalkSpeedEnabled then

            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.WalkSpeed = 16 end) end
            end
        end
end)

PlayerMovementGroup:AddSlider("WalkSpeedValue", {
        Text = "Walk Speed",
        Default = PlayerSettings.WalkSpeed,
        Min = 16,
        Max = 200,
        Rounding = 0,
        Tooltip = "16 = default, higher = faster",
})
Options.WalkSpeedValue:OnChanged(function()
        PlayerSettings.WalkSpeed = Options.WalkSpeedValue.Value

        if PlayerSettings.WalkSpeedEnabled then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.WalkSpeed = PlayerSettings.WalkSpeed end) end
            end
        end
end)

PlayerMovementGroup:AddButton("Reset Walk Speed", function()
        PlayerSettings.WalkSpeedEnabled = false
        if Toggles.WalkSpeedEnabled then Toggles.WalkSpeedEnabled:SetValue(false) end
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.WalkSpeed = 16 end) end
        end
        if Options.WalkSpeedValue then Options.WalkSpeedValue:SetValue(16) end
        Library:Notify({
            Title = "Walk Speed",
            Description = "Always Active turned off, speed reset to 16",
            Time = 3
        })
end)

PlayerMovementGroup:AddDivider()

PlayerMovementGroup:AddToggle("JumpPowerEnabled", {
        Text = "Custom Jump Power",
        Default = PlayerSettings.JumpPowerEnabled,
        Tooltip = "Override your jump power",
})
Toggles.JumpPowerEnabled:OnChanged(function()
        PlayerSettings.JumpPowerEnabled = Toggles.JumpPowerEnabled.Value
        if not PlayerSettings.JumpPowerEnabled then

            local char = lp.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.JumpPower = 50 end) end
            end
        end
end)

PlayerMovementGroup:AddSlider("JumpPowerValue", {
        Text = "Jump Power",
        Default = PlayerSettings.JumpPower,
        Min = 1,
        Max = 300,
        Rounding = 0,
        Tooltip = "50 = default, higher = jump higher",
})
Options.JumpPowerValue:OnChanged(function()
        PlayerSettings.JumpPower = Options.JumpPowerValue.Value
end)

PlayerTogglesGroup:AddToggle("AutoBhop", {
        Text = "Auto BunnyHop",
        Default = PlayerSettings.AutoBhop,
        Tooltip = "Automatically jumps when holding Space (good for movement)",
})
Toggles.AutoBhop:OnChanged(function()
        PlayerSettings.AutoBhop = Toggles.AutoBhop.Value
end)

PlayerTogglesGroup:AddToggle("CustomFOV", {
        Text = "Custom Camera FOV",
        Default = PlayerSettings.CustomFOV,
        Tooltip = "Override the game's camera Field of View (zoom in/out)",
})
Toggles.CustomFOV:OnChanged(function()
        PlayerSettings.CustomFOV = Toggles.CustomFOV.Value
        if not PlayerSettings.CustomFOV then
            pcall(function() camera.FieldOfView = 70 end)
        end
end)

PlayerTogglesGroup:AddSlider("FOVValue", {
        Text = "FOV Value",
        Default = PlayerSettings.FOVValue,
        Min = 70,
        Max = 120,
        Rounding = 0,
        Tooltip = "Camera Field of View (70=default, 120=wide angle)",
})
Options.FOVValue:OnChanged(function()
        PlayerSettings.FOVValue = Options.FOVValue.Value
end)

PlayerTogglesGroup:AddToggle("ShowFPS", {
        Text = "Show FPS Counter",
        Default = PlayerSettings.ShowFPS,
        Tooltip = "Shows an FPS counter in the top-left corner (purple)",
})
Toggles.ShowFPS:OnChanged(function()
        PlayerSettings.ShowFPS = Toggles.ShowFPS.Value
end)

PlayerTogglesGroup:AddButton("Server Hop", function()
        serverHop()
end)

PlayerTogglesGroup:AddToggle("InfiniteJump", {
        Text = "Infinite Jump",
        Default = PlayerSettings.InfiniteJump,
        Tooltip = "Jump unlimited times in the air",
})
Toggles.InfiniteJump:OnChanged(function()
        PlayerSettings.InfiniteJump = Toggles.InfiniteJump.Value
end)

PlayerTogglesGroup:AddToggle("NoclipToggle", {
        Text = "Noclip (Walk Through Walls)",
        Default = PlayerSettings.NoclipEnabled,
        Tooltip = "Walk through walls and objects",
})
Toggles.NoclipToggle:OnChanged(function()
        PlayerSettings.NoclipEnabled = Toggles.NoclipToggle.Value
        if not PlayerSettings.NoclipEnabled then

            local char = lp.Character
            if char then
                pcall(function()
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end)
            end
        end
end)

PlayerTogglesGroup:AddToggle("AirWalkToggle", {
        Text = "Air Walk (No Fall)",
        Default = PlayerSettings.AirWalkEnabled,
        Tooltip = "Stay in the air — disable gravity fall",
})
Toggles.AirWalkToggle:OnChanged(function()
        PlayerSettings.AirWalkEnabled = Toggles.AirWalkToggle.Value
end)

PlayerMovementGroup:AddToggle("SlideBoostToggle", {
        Text = "Slide Boost",
        Default = PlayerSettings.SlideBoost,
        Tooltip = "Speed boost while crouching (hold LeftCtrl)",
})
Toggles.SlideBoostToggle:OnChanged(function()
        PlayerSettings.SlideBoost = Toggles.SlideBoostToggle.Value
end)

PlayerMovementGroup:AddSlider("SlideBoostPowerSlider", {
        Text = "Slide Boost Power",
        Default = PlayerSettings.SlideBoostPower,
        Min = 1,
        Max = 15,
        Rounding = 1,
        Tooltip = "Higher = faster slide (4 = default)",
})
Options.SlideBoostPowerSlider:OnChanged(function()
        PlayerSettings.SlideBoostPower = Options.SlideBoostPowerSlider.Value
end)

PlayerMovementGroup:AddDivider()

PlayerMovementGroup:AddSlider("GravitySlider", {
        Text = "Gravity",
        Default = PlayerSettings.GravityValue,
        Min = 10,
        Max = 400,
        Rounding = 0,
        Tooltip = "196 = default, lower = less gravity",
})
Options.GravitySlider:OnChanged(function()
        PlayerSettings.GravityValue = Options.GravitySlider.Value
        if PlayerSettings.GravityValue == 196 then
            pcall(function() workspace.Gravity = 196 end)
        end
end)

PlayerTogglesGroup:AddDivider()

PlayerTogglesGroup:AddToggle("PanicKeyToggle", {
        Text = "Panic Key (P = Kill All)",
        Default = PlayerSettings.PanicKeyEnabled,
        Tooltip = "Press P to instantly disable ALL combat features",
})
Toggles.PanicKeyToggle:OnChanged(function()
        PlayerSettings.PanicKeyEnabled = Toggles.PanicKeyToggle.Value
end)

PlayerTogglesGroup:AddDivider()

PlayerTogglesGroup:AddToggle("FullbrightToggle", {
        Text = "Fullbright",
        Default = PlayerSettings.FullbrightEnabled,
        Tooltip = "Maximum brightness — no more dark areas",
})
Toggles.FullbrightToggle:OnChanged(function()
        PlayerSettings.FullbrightEnabled = Toggles.FullbrightToggle.Value
        setFullbright(PlayerSettings.FullbrightEnabled)
end)

PlayerTogglesGroup:AddToggle("AntiRagdollToggle", {
        Text = "Anti-Ragdoll",
        Default = PlayerSettings.AntiRagdollEnabled,
        Tooltip = "Prevent ragdolling and falling down — auto-reapplies on respawn",
})
Toggles.AntiRagdollToggle:OnChanged(function()
        PlayerSettings.AntiRagdollEnabled = Toggles.AntiRagdollToggle.Value
        setAntiRagdoll(PlayerSettings.AntiRagdollEnabled)
end)

PlayerTogglesGroup:AddToggle("AntiAfkToggle", {
        Text = "Anti-AFK",
        Default = PlayerSettings.AntiAfkEnabled,
        Tooltip = "Prevents being kicked for being idle",
})
Toggles.AntiAfkToggle:OnChanged(function()
        PlayerSettings.AntiAfkEnabled = Toggles.AntiAfkToggle.Value
        setupAntiAfk(PlayerSettings.AntiAfkEnabled)
end)

PlayerFlyGroup:AddToggle("FlyToggle", {
        Text = "Fly",
        Default = PlayerSettings.FlyEnabled,
        Tooltip = "Fly using BodyVelocity+BodyGyro — WASD + Space/Shift",
})
Toggles.FlyToggle:OnChanged(function()
        PlayerSettings.FlyEnabled = Toggles.FlyToggle.Value
        if PlayerSettings.FlyEnabled then
            startFly(PlayerSettings.FlySpeed)
        else
            stopFly()
        end
end)

PlayerFlyGroup:AddSlider("FlySpeedSlider", {
        Text = "Fly Speed",
        Default = PlayerSettings.FlySpeed,
        Min = 10,
        Max = 500,
        Rounding = 0,
        Tooltip = "80 = default fly speed",
})
Options.FlySpeedSlider:OnChanged(function()
        PlayerSettings.FlySpeed = Options.FlySpeedSlider.Value
        if _flyState.active then
            stopFly()
            task.wait(0.05)
            startFly(PlayerSettings.FlySpeed)
        end
end)

PlayerServerGroup:AddButton("Serverhop", function()
        serverhop()
end)

PlayerServerGroup:AddButton("Rejoin", function()
        rejoin()
end)

TeleportKillGroup:AddInput("TpKillTargetName", {
        Default = TeleportKillSettings.TargetPlayerName,
        Numeric = false,
        Finished = true,
        Text = "Target Player Name",
        Tooltip = "Enter player name (partial match works)",
})
Options.TpKillTargetName:OnChanged(function()
        TeleportKillSettings.TargetPlayerName = Options.TpKillTargetName.Value
end)

TeleportKillGroup:AddSlider("TpKillDistance", {
        Text = "Teleport Distance (studs)",
        Default = TeleportKillSettings.Distance,
        Min = 1,
        Max = 20,
        Rounding = 0,
        Tooltip = "How far behind the target you teleport (1=very close, 20=far)",
})
Options.TpKillDistance:OnChanged(function()
        TeleportKillSettings.Distance = Options.TpKillDistance.Value
end)

TeleportKillGroup:AddToggle("TpKillAutoReconnect", {
        Text = "Auto-Reconnect on Respawn",
        Default = TeleportKillSettings.AutoReconnect,
        Tooltip = "Automatically resume teleporting after you respawn",
})
Toggles.TpKillAutoReconnect:OnChanged(function()
        TeleportKillSettings.AutoReconnect = Toggles.TpKillAutoReconnect.Value
end)

TeleportKillGroup:AddButton("Start Teleport Kill", function()
        local targetName = TeleportKillSettings.TargetPlayerName
        if targetName == "" then
                Library:Notify({
                        Title = "Teleport Kill",
                        Description = "Enter a player name first!",
                        Time = 4
                })
                return
        end
        local target = findTpTarget(targetName)
        if not target then
                Library:Notify({
                        Title = "Teleport Kill",
                        Description = "Player not found: " .. targetName,
                        Time = 4
                })
                return
        end
        startTeleportKill(target)
        Library:Notify({
                Title = "Teleport Kill",
                Description = "Teleporting to " .. target.Name .. " ✅",
                Time = 4
        })
end)

TeleportKillGroup:AddButton("Stop Teleport Kill", function()
        stopTeleportKill()
        Library:Notify({
                Title = "Teleport Kill",
                Description = "Teleport stopped ❌",
                Time = 4
        })
end)

UnlockAllGroup:AddToggle("EnableUnlockAllSwish", {
        Text = "Enable Unlock All",
        Default = false,
        Tooltip = "Unlocks ALL skins locally. Equip them in the game's loadout menu.",
})
Toggles.EnableUnlockAllSwish:OnChanged(function()
        if Toggles.EnableUnlockAllSwish.Value then
                task.spawn(function()
                        if getgenv()._startCosmeticUnlocker then
                                getgenv()._startCosmeticUnlocker()
                        end
                        if getgenv().ZX_Notify then
                                getgenv().ZX_Notify("Unlock All", "All skins unlocked! Equip them in your loadout.", "success")
                        end
                end)
        end
end)

UnlockAllGroup:AddToggle("UnlockAllEmotes", {
        Text = "Unlock All Emotes",
        Default = false,
        Tooltip = "Unlocks all emotes locally - use any emote in the wheel",
}):OnChanged(function(value)
        if value then
                task.spawn(function()
                        task.wait(1)
                        local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
                        local Controllers = PlayerScripts:WaitForChild("Controllers")
                        local Modules = ReplicatedStorage:WaitForChild("Modules")
                        local ok1, CosmeticLibrary = pcall(require, Modules:WaitForChild("CosmeticLibrary"))
                        local ok2, EmoteController = pcall(require, Controllers:WaitForChild("EmoteController"))
                        local ok3, FighterController = pcall(require, Controllers:WaitForChild("FighterController"))
                        local ok4, PlayerDataController = pcall(require, Controllers:WaitForChild("PlayerDataController"))
                        if not (ok1 and ok2 and ok3 and ok4) then return end
                        local isLocalEmoting = false
                        local localEmoteObject = nil
                        local hookedEntities = setmetatable({}, { __mode = "k" })
                        local function safeFire(signal)
                                if not signal then return end
                                if type(signal) == "table" then
                                        if type(signal.Fire) == "function" then pcall(function() signal:Fire() end)
                                        elseif type(signal.fire) == "function" then pcall(function() signal:fire() end) end
                                elseif typeof(signal) == "Instance" and signal:IsA("BindableEvent") then
                                        pcall(function() signal:Fire() end)
                                end
                        end
                        local function applyHooksToEntity(entity)
                                if not entity or hookedEntities[entity] then return end
                                hookedEntities[entity] = true
                                local oldIsEmoting = entity.IsEmoting
                                if oldIsEmoting then
                                        entity.IsEmoting = function(self, ...)
                                                if isLocalEmoting then return true end
                                                return oldIsEmoting(self, ...)
                                        end
                                end
                                local oldGetCurrentEmote = entity.GetCurrentEmote
                                if oldGetCurrentEmote then
                                        entity.GetCurrentEmote = function(self, ...)
                                                if isLocalEmoting and localEmoteObject then return localEmoteObject end
                                                return oldGetCurrentEmote(self, ...)
                                        end
                                end
                        end
                        local function setupFighter(fighter)
                                if fighter.IsLocalPlayer then
                                        if fighter.Entity then applyHooksToEntity(fighter.Entity) end
                                        fighter.EntityAdded:Connect(function(entity) applyHooksToEntity(entity) end)
                                end
                        end
                        for _, fighter in pairs(FighterController.Objects) do setupFighter(fighter) end
                        FighterController.ObjectAdded:Connect(setupFighter)
                        local oldOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
                        CosmeticLibrary.OwnsCosmetic = function(self, inventory, cosmeticName)
                                local cosmetic = CosmeticLibrary.Cosmetics[cosmeticName]
                                if cosmetic and cosmetic.Type == "Emote" then return true end
                                return oldOwnsCosmetic(self, inventory, cosmeticName)
                        end
                        local oldCanEmote = EmoteController.CanEmote
                        EmoteController.CanEmote = function(self, p2)
                                local success, result = pcall(oldCanEmote, self, p2)
                                if success and result then return true end
                                local fighter = FighterController:GetFighter(LocalPlayer)
                                if fighter and fighter.IsLocalPlayer and fighter:IsAlive() then
                                        local entity = fighter.Entity
                                        if entity and not entity:Get("IsFrozen") then return true end
                                end
                                return false
                        end
                        local currentLocalEmote = nil
                        local runningConnection = nil
                        local previousCameraMode = nil
                        local previousMinZoom = nil
                        local function stopCurrentLocalEmote()
                                isLocalEmoting = false
                                localEmoteObject = nil
                                pcall(function()
                                        if previousCameraMode then LocalPlayer.CameraMode = previousCameraMode previousCameraMode = nil end
                                        if previousMinZoom then LocalPlayer.CameraMinZoomDistance = previousMinZoom previousMinZoom = nil end
                                end)
                                local fighter = FighterController:GetFighter(LocalPlayer)
                                local entity = fighter and fighter.Entity
                                if entity and entity.EmoteStatusChanged then safeFire(entity.EmoteStatusChanged) end
                                if currentLocalEmote then pcall(function() currentLocalEmote:Destroy() end) currentLocalEmote = nil end
                        end
                        local function setupHumanoidMonitoring(character)
                                if not character then return end
                                local humanoid = character:WaitForChild("Humanoid", 10)
                                if not humanoid then return end
                                if runningConnection then runningConnection:Disconnect() end
                                runningConnection = humanoid.Running:Connect(function(speed)
                                        if speed > 0.1 then stopCurrentLocalEmote() end
                                end)
                        end
                        setupHumanoidMonitoring(LocalPlayer.Character)
                        LocalPlayer.CharacterAdded:Connect(setupHumanoidMonitoring)
                        local oldUseEmoteByName = EmoteController.UseEmoteByName
                        EmoteController.UseEmoteByName = function(self, emoteName)
                                stopCurrentLocalEmote()
                                local ownsEmote = oldOwnsCosmetic(CosmeticLibrary, PlayerDataController:Get("CosmeticInventory"), emoteName)
                                pcall(function() oldUseEmoteByName(self, emoteName) end)
                                if not ownsEmote then
                                        task.spawn(function()
                                                local EmotesFolder = Modules:FindFirstChild("Emotes")
                                                local emoteModule = EmotesFolder and EmotesFolder:FindFirstChild(emoteName)
                                                local character = LocalPlayer.Character
                                                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                                                if emoteModule and humanoid then
                                                        task.wait(0.1)
                                                        pcall(function()
                                                                currentLocalEmote = require(emoteModule).new(humanoid)
                                                                previousCameraMode = LocalPlayer.CameraMode
                                                                previousMinZoom = LocalPlayer.CameraMinZoomDistance
                                                                LocalPlayer.CameraMode = Enum.CameraMode.Classic
                                                                LocalPlayer.CameraMinZoomDistance = 8
                                                                isLocalEmoting = true
                                                                localEmoteObject = currentLocalEmote
                                                                local fighter = FighterController:GetFighter(LocalPlayer)
                                                                local entity = fighter and fighter.Entity
                                                                if entity and entity.EmoteStatusChanged then safeFire(entity.EmoteStatusChanged) end
                                                                task.defer(currentLocalEmote.Simulate, currentLocalEmote)
                                                                currentLocalEmote.Destroying:Wait()
                                                                if isLocalEmoting then stopCurrentLocalEmote() end
                                                        end)
                                                end
                                        end)
                                end
                        end
                        Library:Notify({Title = "Emotes", Description = "All emotes unlocked!", Time = 3})
                end)
        end
end)

UnlockAllGroup:AddButton("Clear Saved Unlock All Config", function()
        pcall(function()
                if isfile and isfile("unlockall/config.json") then
                        delfile("unlockall/config.json")
                end
        end)
        if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Unlock All", "Saved config cleared.", "warning")
        end
end)

MiscGroup:AddToggle("EnableDeviceSpoofer", {
        Text = "Enable Device Spoofer",
        Default = MiscSettings.SpoofEnabled,
})
Toggles.EnableDeviceSpoofer:OnChanged(function()
        MiscSettings.SpoofEnabled = Toggles.EnableDeviceSpoofer.Value
        if MiscSettings.SpoofEnabled then
                FireSpoof(MiscSettings.SelectedDevice)
        end
end)

MiscGroup:AddDropdown("SelectTargetDevice", {
        Values = {"Controller", "PC", "Mobile", "VR"},
        Default = 1,
        Multi = false,
        Text = "Select Target Device",
})
Options.SelectTargetDevice:OnChanged(function()
        MiscSettings.SelectedDevice = Options.SelectTargetDevice.Value
        if MiscSettings.SpoofEnabled then
                FireSpoof(MiscSettings.SelectedDevice)
        end
end)

TeamDebugGroup:AddButton("Show My Team Info", function()
        UpdateTeamCache()
        local teamID = teamCache.myTeamID
        Library:Notify({
                Title = "Team Info",
                Description = "TeamID: " .. (teamID ~= nil and tostring(teamID) or "nil"),
                Time = 6
        })
end)

TeamDebugGroup:AddButton("Show All Players Teams", function()
        UpdateTeamCache()
        local myTeamID = teamCache.myTeamID
        local count = 0
        local teammateCount = 0
        local enemyCount = 0
        for _, v in pairs(players:GetPlayers()) do
                if v ~= lp then
                        count = count + 1
                        if isTeammate(v) then
                                teammateCount = teammateCount + 1
                        else
                                enemyCount = enemyCount + 1
                        end
                end
        end
        Library:Notify({
                Title = "Team Scan",
                Description = string.format(
                        "My TeamID: %s | Teammates: %d | Enemies: %d | Total: %d",
                        myTeamID ~= nil and tostring(myTeamID) or "nil",
                        teammateCount,
                        enemyCount,
                        count
                ),
                Time = 6
        })
end)

TeamDebugGroup:AddButton("Refresh Team Cache", function()
        UpdateTeamCache()
        Library:Notify({
                Title = "Team Cache",
                Description = "Refreshed! TeamID=" .. tostring(teamCache.myTeamID),
                Time = 4
        })
end)

TeamDebugGroup:AddButton("Toggle Team Check Debug Mode", function()
        TeamCheck.DebugMode = not TeamCheck.DebugMode
        Library:Notify({
                Title = "Team Debug",
                Description = "Debug mode: " .. (TeamCheck.DebugMode and "ON" or "OFF"),
                Time = 4
        })
end)

------------------------------------------------------------------
-- Auto-Claim Rewards + Auto-Redeem Codes (from Rivals Rewrite)
-- Uses correct remote paths: Remotes.Data.ClaimXxx + Remotes.Data.RedeemCode
-- RedeemCode uses InvokeServer (RemoteFunction), not FireServer
------------------------------------------------------------------
RewardsGroup:AddButton("Claim All Rewards", function()
        task.spawn(function()
                local RS = game:GetService("ReplicatedStorage")
                local remotes = RS:FindFirstChild("Remotes")
                if not remotes then
                        Library:Notify({Title = "Rewards", Description = "Remotes folder not found!", Time = 4})
                        return
                end
                local dataRemotes = remotes:FindFirstChild("Data")
                if not dataRemotes then
                        Library:Notify({Title = "Rewards", Description = "Data remotes not found!", Time = 4})
                        return
                end
                local claimed = 0
                pcall(function()
                        if dataRemotes:FindFirstChild("ClaimLikeReward") then
                                dataRemotes.ClaimLikeReward:FireServer()
                                claimed = claimed + 1
                        end
                end)
                pcall(function()
                        if dataRemotes:FindFirstChild("ClaimFavoriteReward") then
                                dataRemotes.ClaimFavoriteReward:FireServer()
                                claimed = claimed + 1
                        end
                end)
                pcall(function()
                        if dataRemotes:FindFirstChild("ClaimNotificationsReward") then
                                dataRemotes.ClaimNotificationsReward:FireServer()
                                claimed = claimed + 1
                        end
                end)
                pcall(function()
                        if dataRemotes:FindFirstChild("ClaimWelcomeBackGift") then
                                dataRemotes.ClaimWelcomeBackGift:FireServer()
                                claimed = claimed + 1
                        end
                end)
                Library:Notify({
                        Title = "Rewards",
                        Description = "Claimed " .. claimed .. " rewards!",
                        Time = 4
                })
        end)
end)

RewardsGroup:AddButton("Redeem All Codes", function()
        task.spawn(function()
                local RS = game:GetService("ReplicatedStorage")
                local remotes = RS:FindFirstChild("Remotes")
                if not remotes then
                        Library:Notify({Title = "Codes", Description = "Remotes folder not found!", Time = 4})
                        return
                end
                local dataRemotes = remotes:FindFirstChild("Data")
                if not dataRemotes then
                        Library:Notify({Title = "Codes", Description = "Data remotes not found!", Time = 4})
                        return
                end
                local redeemRemote = dataRemotes:FindFirstChild("RedeemCode")
                if not redeemRemote then
                        Library:Notify({Title = "Codes", Description = "RedeemCode remote not found!", Time = 4})
                        return
                end

                -- Also try VerifyTwitter
                pcall(function()
                        if dataRemotes:FindFirstChild("VerifyTwitter") then
                                dataRemotes.VerifyTwitter:FireServer()
                        end
                end)

                -- Correct codes from Rivals Rewrite
                local codes = {"COMMUNITY19", "FREE131", "BONUS", "ROBLOX_RTC", "BOOST"}
                local redeemed = 0
                for _, code in ipairs(codes) do
                        pcall(function()
                                -- RedeemCode is a RemoteFunction, use InvokeServer
                                redeemRemote:InvokeServer(code)
                                redeemed = redeemed + 1
                                task.wait(0.3)
                        end)
                end
                Library:Notify({
                        Title = "Codes",
                        Description = "Tried " .. redeemed .. " codes. Check your inventory!",
                        Time = 4
                })
        end)
end)

do
local HexFeaturesGroup = Tabs.Misc:AddRightGroupbox("Extra Features")

HexFeaturesGroup:AddToggle("ProximityAlertEnabled", {
        Text = "Proximity Alert",
        Default = false,
        Tooltip = "Notifies you when an enemy gets within the set distance. 3 second cooldown between alerts.",
})
Toggles.ProximityAlertEnabled:OnChanged(function()
        local enabled = Toggles.ProximityAlertEnabled.Value
        if enabled then
                task.spawn(function()
                        local lastAlert = 0
                        while Toggles.ProximityAlertEnabled and Toggles.ProximityAlertEnabled.Value do
                                pcall(function()
                                        local lp = game:GetService("Players").LocalPlayer
                                        local char = lp.Character
                                        if not char then return end
                                        local hrp = char:FindFirstChild("HumanoidRootPart")
                                        if not hrp then return end
                                        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                                                if p ~= lp and p.Character then
                                                        local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
                                                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                                                        if pHrp and hum and hum.Health > 0 then
                                                                local dist = (hrp.Position - pHrp.Position).Magnitude
                                                                if dist <= 30 then
                                                                        if tick() - lastAlert > 3 then
                                                                                lastAlert = tick()
                                                                                if getgenv().ZX_Notify then
                                                                                        getgenv().ZX_Notify("Proximity Alert", p.Name .. " is " .. math.floor(dist) .. " studs away!", "warning")
                                                                                end
                                                                        end
                                                                        break
                                                                end
                                                        end
                                                end
                                        end
                                end)
                                task.wait(0.2)
                        end
                end)
        end
end)

HexFeaturesGroup:AddSlider("ProximityAlertDistance", {
        Text = "Alert Distance",
        Default = 30,
        Min = 10,
        Max = 200,
        Rounding = 0,
        Suffix = " studs",
        Tooltip = "How close an enemy needs to be to trigger the alert.",
})

HexFeaturesGroup:AddToggle("AntiAFKEnabled", {
        Text = "Anti-AFK",
        Default = false,
        Tooltip = "Jitters camera + simulates click every 12-18 seconds to prevent AFK kick.",
})
Toggles.AntiAFKEnabled:OnChanged(function()
        if Toggles.AntiAFKEnabled.Value then
                task.spawn(function()
                        while Toggles.AntiAFKEnabled and Toggles.AntiAFKEnabled.Value do
                                task.wait(math.random(12, 18))
                                if not Toggles.AntiAFKEnabled or not Toggles.AntiAFKEnabled.Value then break end
                                pcall(function()
                                        -- V13.4: Use mouse movement instead of camera manipulation
                                        if mousemoverel then
                                                mousemoverel(math.random(-15, 15), math.random(-15, 15))
                                        end
                                        task.wait(0.1)
                                        if mouse1click then
                                                mouse1click()
                                        end
                                end)
                        end
                end)
        end
end)

HexFeaturesGroup:AddToggle("RejoinOnKickEnabled", {
        Text = "Rejoin on Kick",
        Default = false,
        Tooltip = "Automatically rejoins the same server if you get kicked. Retries on teleport failure.",
})
Toggles.RejoinOnKickEnabled:OnChanged(function()
        if Toggles.RejoinOnKickEnabled.Value then
                local lp = game:GetService("Players").LocalPlayer
                lp.OnTeleport:Connect(function(state)
                        if state == Enum.TeleportState.Failed and Toggles.RejoinOnKickEnabled and Toggles.RejoinOnKickEnabled.Value then
                                task.wait(3)
                                pcall(function()
                                        game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
                                end)
                        end
                end)
                game:GetService("Players").PlayerRemoving:Connect(function(p)
                        if p == lp and Toggles.RejoinOnKickEnabled and Toggles.RejoinOnKickEnabled.Value then
                                task.wait(1)
                                pcall(function()
                                        game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
                                end)
                        end
                end)
        end
end)

-- AC Protection toggle REMOVED — protection is always ON, cannot be disabled

end
MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

MenuGroup:AddSlider("UIScaleSlider", {
        Text = "UI Scale (Mobile)",
        Default = 100,
        Min = 40,
        Max = 150,
        Rounding = 0,
        Suffix = " %",
        Tooltip = "Scale the entire UI. Lower = smaller (fits mobile). Higher = bigger.",
})
Options.UIScaleSlider:OnChanged(function()
        if UIScaleInstance then
                UIScaleInstance.Scale = Options.UIScaleSlider.Value / 100
        end
end)

MenuGroup:AddSlider("WindowHeightSlider", {
        Text = "Window Height (Mobile)",
        Default = 540,
        Min = 350,
        Max = 700,
        Rounding = 0,
        Suffix = " px",
        Tooltip = "Adjust window height. Lower = shorter (better for mobile screens).",
})
Options.WindowHeightSlider:OnChanged(function()
        if LibraryMainOuterFrame then
                local newH = Options.WindowHeightSlider.Value
                local newW = math.floor(newH * 1.04)
                local curPos = LibraryMainOuterFrame.Position
                local oldW = LibraryMainOuterFrame.Size.X.Offset
                local oldH = LibraryMainOuterFrame.Size.Y.Offset
                local newX = curPos.X.Offset + (oldW - newW) / 2
                local newY = curPos.Y.Offset + (oldH - newH) / 2
                LibraryMainOuterFrame.Size = UDim2.fromOffset(newW, newH)
                LibraryMainOuterFrame.Position = UDim2.new(0, newX, 0, newY)
        end
end)

MenuGroup:AddButton({
        Text = "Auto-Detect Mobile",
        Func = function()
                local viewport = workspace.CurrentCamera.ViewportSize
                if viewport.X < 600 then
                        Options.UIScaleSlider:SetValue(65)
                        Options.WindowHeightSlider:SetValue(400)
                        Library:Notify({Title = "Mobile", Description = "Phone detected! UI scaled + window shrunk.", Time = 4})
                elseif viewport.X < 900 then
                        Options.UIScaleSlider:SetValue(80)
                        Options.WindowHeightSlider:SetValue(460)
                        Library:Notify({Title = "Mobile", Description = "Tablet detected! UI adjusted.", Time = 4})
                else
                        Options.UIScaleSlider:SetValue(100)
                        Options.WindowHeightSlider:SetValue(540)
                        Library:Notify({Title = "Mobile", Description = "PC detected! Default size.", Time = 4})
                end
        end,
        DoubleClick = false,
})

MenuGroup:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible,
        Text = "Open Keybind Menu",
        Callback = function(value) Library.KeybindFrame.Visible = value end
})

MenuGroup:AddToggle("ShowCustomCursor", {
        Text = "Custom Cursor",
        Default = true,
        Callback = function(Value) Library.ShowCustomCursor = Value end
})

MenuGroup:AddDropdown("DragMode", {
        Text = "Window Drag Mode",
        Values = { "Header Only", "Anywhere" },
        Default = 2,
        Multi = false,
        Tooltip = "Header Only = drag from title bar only | Anywhere = drag from anywhere in the window (Linoria default)",
})
Options.DragMode:OnChanged(function()
        local mode = Options.DragMode.Value

        if LibraryMainOuterFrame then

                Library:Notify({
                        Title = "Drag Mode",
                        Description = "Drag mode: " .. mode .. " (applied)",
                        Time = 3
                })
        end
end)

MenuGroup:AddSlider("WindowSizeSlider", {
        Text = "Window Size",
        Default = 540,
        Min = 450,
        Max = 750,
        Rounding = 0,
        Suffix = " px",
        Tooltip = "Adjust the window height (width scales proportionally)",
})
Options.WindowSizeSlider:OnChanged(function()
        local newSize = Options.WindowSizeSlider.Value
        if LibraryMainOuterFrame then
                pcall(function()
                        local newWidth = math.floor(newSize * 1.07)
                        local newHeight = newSize
                        -- Get current position so we can keep the window centered
                        -- after resizing. This prevents the window from jumping
                        -- to top-left when the size changes.
                        local curPos = LibraryMainOuterFrame.Position
                        local oldW = LibraryMainOuterFrame.Size.X.Offset
                        local oldH = LibraryMainOuterFrame.Size.Y.Offset
                        -- Adjust position to keep center the same
                        local newX = curPos.X.Offset + (oldW - newWidth) / 2
                        local newY = curPos.Y.Offset + (oldH - newHeight) / 2
                        LibraryMainOuterFrame.Size = UDim2.fromOffset(newWidth, newHeight)
                        LibraryMainOuterFrame.Position = UDim2.new(0, newX, 0, newY)
                end)
        end
end)

MenuGroup:AddButton({
        Text = "Reset Window Position",
        Func = function()
                if LibraryMainOuterFrame then
                        pcall(function()
                                local viewportSize = workspace.CurrentCamera.ViewportSize
                                LibraryMainOuterFrame.Position = UDim2.new(
                                        0.5, -LibraryMainOuterFrame.Size.X.Offset / 2,
                                        0.5, -LibraryMainOuterFrame.Size.Y.Offset / 2
                                )
                        end)
                end
                Library:Notify({
                        Title = "Window",
                        Description = "Position reset to center",
                        Time = 3
                })
        end,
        DoubleClick = false,
})

MenuGroup:AddButton({
        Text = "Save Window Position",
        Func = function()
                if Library.SavePositionNow then
                        Library:SavePositionNow()
                end
                Library:Notify({
                        Title = "Window",
                        Description = "Position saved! Will load on next launch.",
                        Time = 3
                })
        end,
        DoubleClick = false,
})

MenuGroup:AddToggle("AutoSavePosition", {
        Text = "Auto-Save Position",
        Default = false,
        Tooltip = "Automatically saves window position while you drag. Position loads on next launch.",
})
Toggles.AutoSavePosition:OnChanged(function()
        if Toggles.AutoSavePosition.Value then
                if Library.StartAutoSavePosition then
                        Library:StartAutoSavePosition()
                end
        else
                if Library.StopAutoSavePosition then
                        Library:StopAutoSavePosition()
                end
        end
end)

MenuGroup:AddButton({
        Text = "Clear Saved Position",
        Func = function()
                pcall(function()
                        if isfile and isfile("ZytheraX_UI_Position.json") then
                                delfile("ZytheraX_UI_Position.json")
                        end
                end)
                Library:Notify({
                        Title = "Window",
                        Description = "Saved position cleared.",
                        Time = 3
                })
        end,
        DoubleClick = false,
})

MenuGroup:AddDivider()

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
        Default = "RightControl",
        NoUI = true,
        Text = "Menu keybind"
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton({
        Text = "Unload UI (Delete Cheat)",
        Func = function()
                Library:Unload()
        end,
        DoubleClick = false,
})

do -- V13.1: wrap watermark+FPS+AC+serverhop to reduce main scope locals
local WatermarkConnection
Library:OnUnload(function()
        if WatermarkConnection then WatermarkConnection:Disconnect() end
        if pipelineConnection then pipelineConnection:Disconnect() end
        crosshairGui:Destroy()
        EspGui:Destroy()
        SAFovRing:Destroy()
        SAFovBg:Destroy()
        RageFovRing:Destroy()
        RageFovBg:Destroy()
        HoldBotFovRing:Destroy()
        HoldBotFovBg:Destroy()
        for _, cache in pairs(EspRegistry) do
                if cache.CurrentCham then cache.CurrentCham:Destroy() end
        end

        for _, lines in pairs(SkeletonCache) do
                for _, line in ipairs(lines) do
                        pcall(function() line:Remove() end)
                end
        end
        SkeletonCache = {}

        RestoreHeadScales()

        stopTeleportKill()

        RageMode.AutoWinEnabled = false
        stopAutoWin()
        Library.Unloaded = true
        print("Unloaded Zythera-X via Custom Hook Engine.")
end)

getgenv()._ZX_SetupWatermark = function()
local FrameTimer = tick()
local PingTimer = tick()
local FrameCounter = 0
local FPS = 60
local CachedPing = 0
local CanDoPing = false

pcall(function()
    local stats = game:GetService("Stats")
    local network = stats and stats:FindFirstChild("Network")
    local dataPing = network and network:FindFirstChild("ServerStatsItem")
    if dataPing and dataPing:FindFirstChild("Data Ping") then
        CanDoPing = true
    end
end)

local function RefreshPing()
    if not CanDoPing then return end
    pcall(function()
        CachedPing = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
end
RefreshPing()

WatermarkConnection = RunService.RenderStepped:Connect(function()
        FrameCounter = FrameCounter + 1

        if (tick() - FrameTimer) >= 1 then
                FPS = FrameCounter
                FrameTimer = tick()
                FrameCounter = 0

                RefreshPing()
        end

        local brand = 'ZytheraX'
        if CanDoPing then
                Library:SetWatermark((brand .. " | %d fps | %d ms"):format(
                        math.floor(FPS),
                        CachedPing
                ))
        else
                Library:SetWatermark((brand .. " | %d fps"):format(
                        math.floor(FPS)
                ))
        end
end)
end
getgenv()._ZX_SetupWatermark()

getgenv().silentAimTargetPos = nil

WallbangEngine = {
    active = false,
    desyncActive = false,
    currentTarget = nil,
    currentDesyncTarget = nil,
    targetFinderConn = nil,
    desyncConn = nil,
    desyncRestoreName = "__wb_restore",
    oldStartShooting = nil,
    desyncTimer = nil,
    gunModule = nil,
    utilityModule = nil,
    initialized = false,
    modsApplied = false,
}

function WallbangEngine:init()
    if self.initialized then return true end

    local playerScripts = lp:WaitForChild("PlayerScripts", 10)
    if not playerScripts then return false end

    local gunModuleRef = playerScripts:FindFirstChild("Modules")
    if gunModuleRef then
        gunModuleRef = gunModuleRef:FindFirstChild("ItemTypes")
        if gunModuleRef then
            gunModuleRef = gunModuleRef:FindFirstChild("Gun")
        end
    end

    if not gunModuleRef then return false end

    local success, gun = pcall(function()
        return require(gunModuleRef)
    end)
    if not success or not gun then return false end

    self.gunModule = gun

    local RS = ReplicatedStorage
    local utilRef = RS:FindFirstChild("Modules")
    if utilRef then
        utilRef = utilRef:FindFirstChild("Utility")
    end
    if utilRef then
        local succ, util = pcall(function()
            return require(utilRef)
        end)
        if succ and util then
            self.utilityModule = util
        end
    end

    self.initialized = true
    return true
end

function WallbangEngine:setup()
    if not self.gunModule then return end
    if self.oldStartShooting then return end

    local engine = self
    self.oldStartShooting = (clonefunction and clonefunction(self.gunModule.StartShooting)) or self.gunModule.StartShooting
    self.usedHookfunction = false

    local hookFn = function(gunSelf, ...)
        local results = {engine.oldStartShooting(gunSelf, ...)}

        if not gunSelf.ClientFighter or not gunSelf.ClientFighter.IsLocalPlayer then
            return unpack(results)
        end

        if not engine.active then
            return unpack(results)
        end

        local shotData = results[3]
        if not shotData or typeof(shotData) ~= "table" then
            return unpack(results)
        end

        local targetPlayer = engine.currentTarget
        if not targetPlayer or not targetPlayer.Character then
            return unpack(results)
        end

        results[4] = true

        if not engine.desyncActive or engine.currentDesyncTarget ~= targetPlayer then
            engine:desyncStart(targetPlayer)

            task.wait(0.05)
        end

        if engine.desyncTimer then
            task.cancel(engine.desyncTimer)
            engine.desyncTimer = nil
        end

        local enemyHead = targetPlayer.Character:FindFirstChild("Head")
        if not enemyHead then return unpack(results) end

        local headPos = enemyHead.Position
        local headCFrame = enemyHead.CFrame

        local offsetX = math.random(-2, 2) / 10
        local offsetY = math.random(-2, 2) / 10
        local offsetZ = math.random(-2, 2) / 10
        local targetPos = headPos + Vector3.new(offsetX, offsetY, offsetZ)

        local originPos = targetPos - Vector3.new(0, 2, 0)
        local lookAtCF = CFrame.lookAt(originPos, targetPos)
        local relativePos = headCFrame:ToObjectSpace(CFrame.new(targetPos))

        if engine.utilityModule and engine.utilityModule.EncodeCFrame then
            shotData[utf8.char(0)] = engine.utilityModule:EncodeCFrame(CFrame.new(originPos, targetPos) * CFrame.Angles(lookAtCF:ToOrientation()))
            shotData[utf8.char(1)] = engine.utilityModule:EncodeCFrame(CFrame.new(targetPos) * CFrame.Angles(lookAtCF:ToOrientation()))
            shotData[utf8.char(2)] = enemyHead
            shotData[utf8.char(3)] = engine.utilityModule:EncodeCFrame(relativePos)
        end

        engine.desyncTimer = task.delay(0.3, function()
            engine:desyncStop()
        end)

        return unpack(results)
    end

    if newcclosure then
        hookFn = newcclosure(hookFn)
    end

    local hooked = false
    pcall(function()
        if hookfunction then
            hookfunction(self.gunModule.StartShooting, hookFn)
            hooked = true
            engine.usedHookfunction = true
        end
    end)

    if not hooked then
        self.gunModule.StartShooting = hookFn
        engine.usedHookfunction = false
    end
end

function WallbangEngine:findTarget()
    local myChar = lp.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest = nil
    local closestDist = math.huge
    local MAX_DISTANCE = 9999

    for _, plr in next, players:GetPlayers() do
        if plr == lp then continue end
        if isTeammate(plr) then continue end

        local char = plr.Character
        if not char then continue end

        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildWhichIsA("Humanoid")

        if not (root and head and hum and hum.Health > 0) then continue end

        local dist = (myRoot.Position - root.Position).Magnitude
        if dist > MAX_DISTANCE then continue end

        if dist < closestDist then
            closestDist = dist
            closest = plr
        end
    end

    return closest
end

function WallbangEngine:desyncStart(targetPlayer)

    if self.desyncConn then self.desyncConn:Disconnect() end
    pcall(function()
        RunService:UnbindFromRenderStep(self.desyncRestoreName)
    end)

    self.desyncActive = true
    self.currentDesyncTarget = targetPlayer

    local engine = self
    local desyncStartTime = tick()

    local MAX_DESYNC_DURATION = 0.4

    local savedCFrame, savedVel, savedRotVel

    self.desyncConn = RunService.Heartbeat:Connect(function()
        if not engine.desyncActive then return end

        if tick() - desyncStartTime > MAX_DESYNC_DURATION then
            engine:desyncStop()
            return
        end

        local myChar = lp.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            engine:desyncStop()
            return
        end

        savedCFrame = myRoot.CFrame
        savedVel = myRoot.AssemblyLinearVelocity
        savedRotVel = myRoot.AssemblyAngularVelocity

        pcall(function()
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, -3, 0)
        end)

        local restoreFn
        restoreFn = function()
            if not engine.desyncActive or not savedCFrame then return end
            pcall(function()
                myRoot.CFrame = savedCFrame
                myRoot.AssemblyLinearVelocity = savedVel
                myRoot.AssemblyAngularVelocity = savedRotVel
            end)

            pcall(function()
                RunService:UnbindFromRenderStep(engine.desyncRestoreName)
            end)
        end

        if newcclosure then
            restoreFn = newcclosure(restoreFn)
        end

        pcall(function()
            RunService:BindToRenderStep(engine.desyncRestoreName, 101, restoreFn)
        end)
    end)
end

function WallbangEngine:desyncStop()
    self.desyncActive = false
    self.currentDesyncTarget = nil
    if self.desyncConn then
        self.desyncConn:Disconnect()
        self.desyncConn = nil
    end
    pcall(function()
        RunService:UnbindFromRenderStep(self.desyncRestoreName)
    end)
end

function WallbangEngine:start()
    self.active = true

    if WallbangStealthState then
        WallbangStealthState.enabled = true
    end

    if not self.initialized then
        if not self:init() then
            Library:Notify({
                Title = "Wallbang",
                Description = "Failed to load Gun module! Retrying...",
                Time = 5
            })

            task.delay(3, function()
                if self.active and self:init() then
                    self:setup()
                    self:startTargetFinder()

                    if not self.modsApplied then
                        applyWallbangMods()
                        self.modsApplied = true
                    end
                    Library:Notify({
                        Title = "Wallbang",
                        Description = "FULL POWER ACTIVE!",
                        Time = 3
                    })
                end
            end)
            return
        end
    end

    self:setup()

    self:startTargetFinder()

    if not self.modsApplied then
        applyWallbangMods()
        self.modsApplied = true
    end

    task.spawn(function()
        while self.active and RageMode.Wallbang and RageMode.Enabled do
            task.wait(5)

            pcall(function()
                local RS = ReplicatedStorage
                local Items = require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)).Items
                local needsReapply = false
                local trackedCount = 0
                local itemCount = 0
                for name, data in pairs(Items) do
                    if typeof(data) == "table" then
                        itemCount = itemCount + 1
                        if WallbangStealthState.applied[data] then
                            trackedCount = trackedCount + 1
                        end

                        local rawVal = rawget(data, "ProjectileWallClipPreventionEnabled")
                        local readVal = data.ProjectileWallClipPreventionEnabled
                        if rawVal == true and readVal == true then

                            needsReapply = true
                            break
                        end
                    end
                end

                if trackedCount < itemCount then
                    needsReapply = true
                end
                if needsReapply then
                    wbDebug(string.format("re-applying (tracked %d/%d items)", trackedCount, itemCount))
                    applyWallbangMods()
                end
            end)
        end
    end)

    Library:Notify({
        Title = "Wallbang",
        Description = "FULL POWER ACTIVE!",
        Time = 3
    })
end

function WallbangEngine:startTargetFinder()
    if self.targetFinderConn then self.targetFinderConn:Disconnect() end

    self.targetFinderConn = RunService.Heartbeat:Connect(function()
        if not self.active then return end
        self.currentTarget = self:findTarget()
    end)
end

function WallbangEngine:stop()
    self.active = false
    self.currentTarget = nil

    if WallbangStealthState then
        WallbangStealthState.enabled = false
        wbDebug("wallbang disabled — stealth hooks now pass-through")
    end

    self:desyncStop()

    if self.targetFinderConn then
        self.targetFinderConn:Disconnect()
        self.targetFinderConn = nil
    end

    if self.desyncTimer then
        task.cancel(self.desyncTimer)
        self.desyncTimer = nil
    end

    if self.oldStartShooting and self.gunModule then

        if self.usedHookfunction and hookfunction then
            pcall(function()
                hookfunction(self.gunModule.StartShooting, self.oldStartShooting)
            end)
        end

        self.gunModule.StartShooting = self.oldStartShooting
        self.oldStartShooting = nil
        self.usedHookfunction = false
    end

    getgenv().silentAimTargetPos = nil
end
-- ════════════════════════════════════════════════════════════════════
-- SILENT AIM — op src (adapted for ZytheraX)
-- __namecall hook على workspace:Raycast — بيشتغل مع كل الأسلحة بما فيها الـ sniper
-- التعديلات: FOV + Team Check + HitChance toggle/slider + Target finder + Max Distance
-- ════════════════════════════════════════════════════════════════════

local _SA_inHook = false
local _SA_isMobile = uis.TouchEnabled and not uis.KeyboardEnabled

-- ════════════════════════════════════════════════════════════════════
-- SA Settings (local — مش related بالـ SilentAim table القديم)
-- ════════════════════════════════════════════════════════════════════
local _SA = {
    enabled = false,
    fov = 150,
    headchance = 10,           -- نسبة ضرب الـ Head (10%)
    teamCheck = false,         -- Team Check
    hitChanceEnabled = false,  -- Enable HitChance toggle
    hitChance = 100,           -- HitChance slider (0-100)
    maxDistance = 2000,        -- Max Distance (studs)
}

-- ════════════════════════════════════════════════════════════════════
-- Body parts pool (مطابق لـ op src)
-- ════════════════════════════════════════════════════════════════════
local _SA_bodyparts = {
    "Torso", "HumanoidRootPart", "UpperTorso", "LowerTorso",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
}

-- ════════════════════════════════════════════════════════════════════
-- Mouse position (mobile support)
-- ════════════════════════════════════════════════════════════════════
local function _SA_getMousePos()
    if _SA_isMobile then
        local touches = uis:GetTouches()
        if touches and #touches > 0 then
            return Vector2.new(touches[1].Position.X, touches[1].Position.Y)
        end
        return Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
    end
    return uis:GetMouseLocation()
end

-- ════════════════════════════════════════════════════════════════════
-- Check if character is alive
-- ════════════════════════════════════════════════════════════════════
local function _SA_alive(char)
    if not char then return false end
    local ok, res = pcall(function()
        if not char:IsDescendantOf(workspace) then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        return true
    end)
    return ok and res
end

-- ════════════════════════════════════════════════════════════════════
-- Pick a body part (with head chance)
-- ════════════════════════════════════════════════════════════════════
local function _SA_getpart(char)
    local hitPart = SilentAim.HitPart or "Head"
    -- لو "Random" → اختار body part عشوائي (نفس الـ op src logic)
    if hitPart == "Random" then
        if math.random(1, 100) <= _SA.headchance then
            local h = char:FindFirstChild("Head")
            if h then return h end
        end
        local pool = table.clone(_SA_bodyparts)
        for i = #pool, 2, -1 do
            local j = math.random(1, i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        for _, name in ipairs(pool) do
            local p = char:FindFirstChild(name)
            if p then return p end
        end
        return char:FindFirstChild("Head")
    end
    -- لو مش Random → استخدم الـ HitPart المحدد بالظبط
    local p = char:FindFirstChild(hitPart)
    if p then return p end
    -- fallback لو الـ part مش موجود
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

-- ════════════════════════════════════════════════════════════════════
-- Visibility check (can we see the target?)
-- ════════════════════════════════════════════════════════════════════
local _SA_rparams = RaycastParams.new()
_SA_rparams.FilterType = Enum.RaycastFilterType.Exclude

local function _SA_canSee(part, char)
    local mychar = lp.Character
    if not mychar then return true end
    local root = mychar:FindFirstChild("HumanoidRootPart") or mychar:FindFirstChild("Torso")
    if not root then return true end
    local ok, result = pcall(function()
        _SA_rparams.FilterDescendantsInstances = {mychar}
        return workspace:Raycast(root.Position, part.Position - root.Position, _SA_rparams)
    end)
    if not ok then return true end
    if not result then return true end
    return result.Instance:IsDescendantOf(char)
end

-- ════════════════════════════════════════════════════════════════════
-- مؤقت داخلي — بديل الـ HitChance
-- السايلنت ايم بيشتغل 0.20s ثم يطفي 0.20s أوتوماتيك (داخلي، مش في الواجهة)
-- ده يخلي ~50% من الـ shots تـ hit بشكل طبيعي من غير ما المستخدم يتحكم فيه
-- ════════════════════════════════════════════════════════════════════
local _SA_ON_TIME = 0.20   -- 200ms شغّال
local _SA_OFF_TIME = 0.20  -- 200ms متعطل
local _SA_lastToggleTime = 0

local function _SA_shouldHit()
    local now = tick()
    local cycleTime = _SA_ON_TIME + _SA_OFF_TIME
    local elapsed = now - _SA_lastToggleTime
    if elapsed >= cycleTime then
        _SA_lastToggleTime = now
        elapsed = 0
    end
    -- لو في الـ ON period → true (سايلنت ايم شغّال)
    -- لو في الـ OFF period → false (سايلنت ايم متعطل)
    return elapsed < _SA_ON_TIME
end

-- ════════════════════════════════════════════════════════════════════
-- Target finder (مطابق لـ op src + Team Check + Max Distance)
-- ════════════════════════════════════════════════════════════════════
local function _SA_getTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local mouse = _SA_getMousePos()
    local bestdist = _SA.fov
    local besttarget = nil
    local camPos = cam.CFrame.Position

    for _, plr in ipairs(players:GetPlayers()) do
        if plr == lp then continue end
        local char = plr.Character
        if not char then continue end
        if not _SA_alive(char) then continue end
        -- Team Check
        if _SA.teamCheck and isTeammate(plr) then continue end
        local refpart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not refpart then continue end
        -- Max Distance check
        local worldDist = (refpart.Position - camPos).Magnitude
        if worldDist > _SA.maxDistance then continue end
        local ok, screenpos, onscreen = pcall(function()
            return cam:WorldToViewportPoint(refpart.Position)
        end)
        if not ok or not onscreen then continue end
        local dist = (Vector2.new(screenpos.X, screenpos.Y) - mouse).Magnitude
        if dist < bestdist then
            if _SA_canSee(refpart, char) then
                bestdist = dist
                besttarget = _SA_getpart(char)
            end
        end
    end
    return besttarget
end

-- ════════════════════════════════════════════════════════════════════
-- Detect if a ray is a "shoot ray" (from camera/HRP/Head)
-- ════════════════════════════════════════════════════════════════════
local function _SA_isShootRay(origin, direction)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local mychar = lp.Character
    if not mychar then return false end
    local campos = cam.CFrame.Position
    local camdist = (origin - campos).Magnitude
    local hrp = mychar:FindFirstChild("HumanoidRootPart")
    local head = mychar:FindFirstChild("Head")
    local hrdist = hrp and (origin - hrp.Position).Magnitude or math.huge
    local headdist = head and (origin - head.Position).Magnitude or math.huge
    return camdist <= 25 or hrdist <= 15 or headdist <= 15
end

-- ════════════════════════════════════════════════════════════════════
-- Main __namecall hook (مطابق لـ op src بالظبط)
-- ════════════════════════════════════════════════════════════════════
local _SA_oldnc
_SA_oldnc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if _SA.enabled and not _SA_inHook and method == "Raycast" and self == workspace then
        local args = {...}
        local origin = args[1]
        local direction = args[2]
        local params = args[3]
        if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
            if _SA_isShootRay(origin, direction) then
                if _SA_shouldHit() then
                    _SA_inHook = true
                    local target = _SA_getTarget()
                    _SA_inHook = false
                    if target then
                        local newdir = (target.Position - origin).Unit * direction.Magnitude
                        setnamecallmethod(method)
                        return _SA_oldnc(self, origin, newdir, params)
                    end
                end
            end
        end
    end

    setnamecallmethod(method)
    return _SA_oldnc(self, ...)
end))

-- ════════════════════════════════════════════════════════════════════
-- Sync _SA settings with existing SilentAim UI toggles
-- ════════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(2)
    -- Sync enabled
    local function syncSA()
        _SA.enabled = SilentAim.Enabled
        _SA.fov = SilentAim.FOV or 150
        _SA.maxDistance = SilentAim.MaxDistance or 2000
        -- Toggle Mode settings بتـ read من globals (بيـ update من الـ UI مباشرة)
    end

    -- Initial sync
    syncSA()

    -- Keep syncing every 0.5s (in case UI changed)
    task.spawn(function()
        while true do
            task.wait(0.5)
            syncSA()
        end
    end)
end)

-- ════════════════════════════════════════════════════════════════════
-- UI: Team Check + HitChance toggle + Max Distance
-- (ضيفهم في SilentAimGroup الموجود)
-- ════════════════════════════════════════════════════════════════════
SilentAimGroup:AddToggle("SATeamCheck", {
    Text = "Team Check",
    Default = false,
    Tooltip = "Skip teammates when finding silent aim targets.",
})
Toggles.SATeamCheck:OnChanged(function()
    _SA.teamCheck = Toggles.SATeamCheck.Value
    SilentAim.TeamCheck = _SA.teamCheck
end)

-- NOTE: SAMaxDistance موجود أصلاً في الـ UI القديم
-- والـ sync loop بياخده أوتوماتيك كل 0.5 ثانية

-- END Silent Aim Hook
-- ════════════════════════════════════════════════════════════════════

-- (Removed: KillFeed, HitSound, Skybox Changer systems to free LuaJIT registers)

-- ═══════════════════════════════════════════════════════════════════
-- ENHANCED WALLBANG ENGINE (using getgc-discovered functions)
-- Hooks GetRaycastWhitelist + GetRaycastRedirection to force pierce
-- Also hooks VerifyTracerData to bypass tracer validation
-- ═══════════════════════════════════════════════════════════════════
do
    local EnhancedWB = {
        Enabled = false,
        _hookedItems = {},
        _origRaycastWhitelist = nil,
        _origRaycastRedirection = nil,
        _origVerifyTracerData = nil,
    }

    -- Try to hook FighterController's raycast functions
    local function hookFighterRaycasts()
        pcall(function()
            local ps = lp:WaitForChild("PlayerScripts", 5)
            local ctrl = ps and ps:WaitForChild("Controllers", 5)
            local fc = ctrl and require(ctrl:WaitForChild("FighterController", 5))
            if not fc then return end

            -- Hook GetRaycastWhitelist if it exists
            if fc.GetRaycastWhitelist and not EnhancedWB._origRaycastWhitelist then
                EnhancedWB._origRaycastWhitelist = fc.GetRaycastWhitelist
                fc.GetRaycastWhitelist = function(self, ...)
                    if EnhancedWB.Enabled then
                        -- Return empty whitelist = no walls block raycast
                        return {}
                    end
                    return EnhancedWB._origRaycastWhitelist(self, ...)
                end
            end

            -- Hook GetRaycastRedirection if it exists
            if fc.GetRaycastRedirection and not EnhancedWB._origRaycastRedirection then
                EnhancedWB._origRaycastRedirection = fc.GetRaycastRedirection
                fc.GetRaycastRedirection = function(self, ...)
                    if EnhancedWB.Enabled then
                        -- Return nil = no redirection = bullet goes straight
                        return nil
                    end
                    return EnhancedWB._origRaycastRedirection(self, ...)
                end
            end
        end)
    end

    -- Hook VerifyTracerData on equipped items (bypass tracer validation)
    local function hookEquippedItemTracers()
        pcall(function()
            local ps = lp:WaitForChild("PlayerScripts", 5)
            local ctrl = ps and ps:WaitForChild("Controllers", 5)
            local fc = ctrl and require(ctrl:WaitForChild("FighterController", 5))
            if not fc or not fc.GetFighter then return end

            local ok, fighter = pcall(function() return fc:GetFighter(lp) end)
            if ok and fighter and fighter.EquippedItem then
                local item = fighter.EquippedItem
                if not EnhancedWB._hookedItems[item] then
                    EnhancedWB._hookedItems[item] = true
                    -- Hook VerifyTracerData if it exists
                    if item.VerifyTracerData and typeof(item.VerifyTracerData) == "function" then
                        local orig = item.VerifyTracerData
                        item.VerifyTracerData = function(self, ...)
                            if EnhancedWB.Enabled then
                                return true  -- always valid
                            end
                            return orig(self, ...)
                        end
                    end
                end
            end
        end)
    end

    -- Background loop to keep hooks active
    task.spawn(function()
        while true do
            task.wait(2)
            if EnhancedWB.Enabled then
                hookFighterRaycasts()
                hookEquippedItemTracers()
            end
        end
    end)

    -- Expose for integration with existing Wallbang toggle
    getgenv().ZX_EnhancedWB = EnhancedWB
end

-- ═══════════════════════════════════════════════════════════════════
-- ANTI-CHEAT PROTECTION SYSTEM (using getgc-discovered functions)
-- Hooks _DetectLocalPlayerActivity + ServerKick + ServerBan to prevent
-- the game from kicking/banning us when cheats are detected.
-- ═══════════════════════════════════════════════════════════════════
do
    local ACProtection = {
        Enabled = true,  -- V13.5: Always ON - this is protection, not a feature
        _hookedFuncs = {},
        _kickCount = 0,
        _banCount = 0,
        _detectCount = 0,
    }

    -- Hook a function on a table/object to block it when enabled
    local function hookBlock(obj, funcName)
        if not obj or not obj[funcName] then return false end
        if ACProtection._hookedFuncs[obj] and ACProtection._hookedFuncs[obj][funcName] then
            return false  -- already hooked
        end
        local orig = obj[funcName]
        if type(orig) ~= "function" then return false end

        ACProtection._hookedFuncs[obj] = ACProtection._hookedFuncs[obj] or {}
        ACProtection._hookedFuncs[obj][funcName] = orig

        obj[funcName] = function(self, ...)
            if ACProtection.Enabled then
                if funcName == "ServerKick" then
                    ACProtection._kickCount = ACProtection._kickCount + 1
                    if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("AC Protection", "Blocked ServerKick #" .. ACProtection._kickCount, "warning")
                    end
                    return nil
                elseif funcName == "ServerBan" then
                    ACProtection._banCount = ACProtection._banCount + 1
                    if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("AC Protection", "Blocked ServerBan #" .. ACProtection._banCount, "warning")
                    end
                    return nil
                elseif funcName == "_DetectLocalPlayerActivity" then
                    ACProtection._detectCount = ACProtection._detectCount + 1
                    return  -- do nothing
                elseif funcName == "ToggleBanned" then
                    return  -- don't toggle ban state
                end
            end
            return orig(self, ...)
        end
        return true
    end

    -- Find and hook AC functions in PlayerScripts/Controllers
    local function findAndHookAC()
        pcall(function()
            local ps = lp:WaitForChild("PlayerScripts", 5)
            if not ps then return end
            local ctrl = ps:WaitForChild("Controllers", 5)
            if not ctrl then return end

            for _, child in ipairs(ctrl:GetChildren()) do
                pcall(function()
                    local mod = require(child)
                    if type(mod) == "table" then
                        if mod._DetectLocalPlayerActivity then
                            hookBlock(mod, "_DetectLocalPlayerActivity")
                        end
                        if mod.ServerKick then
                            hookBlock(mod, "ServerKick")
                        end
                        if mod.ServerBan then
                            hookBlock(mod, "ServerBan")
                        end
                        if mod.ToggleBanned then
                            hookBlock(mod, "ToggleBanned")
                        end
                    end
                end)
            end
        end)
    end

    -- Hook FireServer on kick/ban related remotes
    local function hookRemotes()
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local remotes = rs:FindFirstChild("Remotes")
            if not remotes then return end
            for _, desc in ipairs(remotes:GetDescendants()) do
                if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                    local name = string.lower(desc.Name)
                    if name:find("kick") or name:find("ban") or name:find("detect") then
                        if not ACProtection._hookedFuncs[desc] then
                            ACProtection._hookedFuncs[desc] = true
                            if desc:IsA("RemoteEvent") and desc.FireServer then
                                local origFire = desc.FireServer
                                desc.FireServer = function(self, ...)
                                    if ACProtection.Enabled then return end
                                    return origFire(self, ...)
                                end
                            elseif desc:IsA("RemoteFunction") and desc.InvokeServer then
                                local origInvoke = desc.InvokeServer
                                desc.InvokeServer = function(self, ...)
                                    if ACProtection.Enabled then return nil end
                                    return origInvoke(self, ...)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    getgenv().ZX_ACProtection = ACProtection

    -- Auto-run hooks on script load (passive — only active when Enabled)
    task.spawn(function()
        task.wait(3)
        findAndHookAC()
        hookRemotes()
    end)
end
end -- end do block for watermark+FPS+AC

do -- V13.1: wrap new features section to reduce main scope locals
local function serverHop()
    local placeId = game.PlaceId
    local jobId = game.JobId
    pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"))
        if servers and servers.data then
            for _, srv in pairs(servers.data) do
                if srv.playing < srv.maxPlayers and srv.id ~= jobId then
                    TeleportService:TeleportToPlaceInstance(placeId, srv.id, lp)
                    break
                end
            end
        end
    end)
end
getgenv().serverHop = serverHop

-- ═══════════════════════════════════════════════════════════════════
-- NEW FEATURES (V12): primesto.fx inspired additions
--   Each feature is wrapped in a getgenv() IIFE to stay under
--   LuaJIT's 200-local-per-scope limit.
--   1. Stick to Target (with Knife Dodge) - Rage tab
--   2. Tripmine ESP (Sixth Sense) - ESP tab
--   3. Show Enemy Weapons Panel - ESP tab
--   4. Katana Warning (top label) - integrated with AntiKatana
-- ═══════════════════════════════════════════════════════════════════

-- Shared state table (one global, not many locals)
getgenv().ZX_V12 = getgenv().ZX_V12 or {
    viewModels = nil,
    stick = { Enabled = false, UseSmoothing = false, SmoothingValue = 50, StickBeneathPlayer = false, _conn = nil, _target = nil, _spinRotation = 0, _lastHeartbeat = 0 },
    tripmine = { Enabled = false, MaxDistance = 300, MaxLabels = 50, _labels = {}, _labelCount = 0, _pendingQueue = {}, _pendingSet = {}, _childAddedConn = nil, _childRemovedConn = nil, _renderConn = nil, _queueConn = nil },
    enemyWeapons = { Enabled = false, _container = nil, _screenGui = nil, _labels = {}, _conn = nil, _lastUpdate = 0 },
    katanaWarning = { _label = nil, _screenGui = nil, _expiry = 0 },
}
local ZX_V12 = getgenv().ZX_V12

-- ============================================================
-- IIFE 1: Shared ViewModels helpers
-- ============================================================
getgenv()._ZX_V12_Helpers = (function()
    local function extractPlayerName(modelName)
        local parts = string.split(modelName, " - ")
        if #parts >= 1 then return parts[1] end
        return "Unknown"
    end
    local function extractWeaponName(modelName)
        local parts = string.split(modelName, " - ")
        if #parts >= 3 then return parts[3] end
        if #parts >= 2 then return parts[2] end
        return modelName
    end
    local function getViewModels()
        if not ZX_V12.viewModels then
            ZX_V12.viewModels = workspace:FindFirstChild("ViewModels")
        end
        return ZX_V12.viewModels
    end
    local function getEnemyHeldWeapon(player)
        if not player then return nil end
        local vms = getViewModels()
        if not vms then return nil end
        for _, m in ipairs(vms:GetChildren()) do
            if m:IsA("Model") then
                local pn = extractPlayerName(m.Name)
                if pn == player.Name then
                    return extractWeaponName(m.Name), m
                end
            end
        end
        return nil
    end
    local function getLocalPlayerHeldWeapon()
        if not lp then return nil end
        local vms = getViewModels()
        if not vms then return nil end
        local firstPerson = vms:FindFirstChild("FirstPerson")
        if not firstPerson then return nil end
        for _, child in ipairs(firstPerson:GetChildren()) do
            if child:IsA("Model") then
                return extractWeaponName(child.Name), child
            end
        end
        return nil
    end
    return {
        extractPlayerName = extractPlayerName,
        extractWeaponName = extractWeaponName,
        getEnemyHeldWeapon = getEnemyHeldWeapon,
        getLocalPlayerHeldWeapon = getLocalPlayerHeldWeapon,
    }
end)()

-- ============================================================
-- IIFE 2: Stick to Target (with Knife Dodge)
-- ============================================================
getgenv()._ZX_V12_Stick = (function()
    local ST = ZX_V12.stick
    local STICK_MAX_DISTANCE = 300
    local STICK_BEHIND_DISTANCE = 6
    local STICK_DODGE_DISTANCE = 15
    local STICK_SPIN_SPEED = 12
    local helpers = getgenv()._ZX_V12_Helpers

    local function findTarget()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local look = cam.CFrame.LookVector
        local origin = cam.CFrame.Position
        local best, bestDist = nil, math.huge
        for _, pl in ipairs(players:GetPlayers()) do
            if pl ~= lp and pl.Character then
                local pp = pl.Character.PrimaryPart or pl.Character:FindFirstChild("HumanoidRootPart")
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                if pp and hum and hum.Health > 0 and not isTeammate(pl) then
                    local toTarget = pp.Position - origin
                    local dot = look:Dot(toTarget.Unit)
                    if dot > 0.65 then
                        local dist = toTarget.Magnitude
                        if dist < STICK_MAX_DISTANCE and dist < bestDist then
                            best = pl
                            bestDist = dist
                        end
                    end
                end
            end
        end
        return best
    end

    local function isTargetHoldingKnife(targetPlr)
        if not targetPlr then return false end
        local weaponName = helpers.getEnemyHeldWeapon(targetPlr)
        if not weaponName then return false end
        local lname = string.lower(weaponName)
        if string.find(lname, "knife") then return true end
        if string.find(lname, "katana") then return true end
        if string.find(lname, "machete") then return true end
        if string.find(lname, "blade") then return true end
        if string.find(lname, "sword") then return true end
        return false
    end

    local function start()
        if ST._conn then return end
        ST._lastHeartbeat = tick()
        ST._conn = RunService.Heartbeat:Connect(function()
            if not ST.Enabled then return end
            if not lp or not lp.Character then return end
            local lpRoot = lp.Character.PrimaryPart or lp.Character:FindFirstChild("HumanoidRootPart")
            if not lpRoot then return end

            local now = tick()
            local dt = now - ST._lastHeartbeat
            ST._lastHeartbeat = now

            if not ST._target or not ST._target.Parent then
                ST._target = findTarget()
            else
                local tChar = ST._target.Character
                local tRoot = tChar and (tChar.PrimaryPart or tChar:FindFirstChild("HumanoidRootPart"))
                local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
                if not tRoot or not tHum or tHum.Health <= 0 or isTeammate(ST._target) then
                    ST._target = findTarget()
                end
            end

            if not ST._target or not ST._target.Character then
                return
            end

            local tChar = ST._target.Character
            local tRoot = tChar.PrimaryPart or tChar:FindFirstChild("HumanoidRootPart")
            if not tRoot then return end

            local isHoldingKnife = isTargetHoldingKnife(ST._target)
            local backPos

            if isHoldingKnife then
                ST._spinRotation = ST._spinRotation + STICK_SPIN_SPEED
                local pushDir = (lpRoot.Position - tRoot.Position)
                if pushDir.Magnitude == 0 then pushDir = Vector3.new(1, 0, 0) end
                pushDir = pushDir.Unit
                backPos = tRoot.Position + (pushDir * STICK_DODGE_DISTANCE) + Vector3.new(0, 6.4, 0)
            else
                ST._spinRotation = 0
                local targetPos = tRoot.Position + Vector3.new(0, 6.4, 0)
                if ST.StickBeneathPlayer then
                    backPos = tRoot.Position - Vector3.new(0, 4, 0)
                else
                    backPos = targetPos - (tRoot.CFrame.LookVector.Unit * STICK_BEHIND_DISTANCE)
                end
            end

            local dest = CFrame.new(backPos, tRoot.Position)
            if isHoldingKnife then
                dest = dest * CFrame.Angles(0, ST._spinRotation, 0)
            end

            if lp.Character and lp.Character.PrimaryPart then
                if ST.UseSmoothing then
                    local alpha = math.clamp(ST.SmoothingValue / 100, 0, 1)
                    local lerpAlpha = math.clamp(alpha * (dt * 8), 0, 1)
                    lp.Character:SetPrimaryPartCFrame(lp.Character.PrimaryPart.CFrame:Lerp(dest, lerpAlpha))
                else
                    lp.Character:SetPrimaryPartCFrame(dest)
                end
            end
        end)
    end

    local function stop()
        if ST._conn then
            ST._conn:Disconnect()
            ST._conn = nil
        end
        ST._target = nil
        ST._spinRotation = 0
    end

    return { start = start, stop = stop, findTarget = findTarget, isTargetHoldingKnife = isTargetHoldingKnife }
end)()

-- ============================================================
-- IIFE 3: Tripmine ESP (Sixth Sense)
-- ============================================================
getgenv()._ZX_V12_Tripmine = (function()
    local TE = ZX_V12.tripmine

    local function isTripminePart(part)
        if not part or not part:IsA("BasePart") then return false end
        local vm = workspace:FindFirstChild("ViewModels")
        if vm and part:IsDescendantOf(vm) then return false end
        local cam = workspace.CurrentCamera
        if cam and part:IsDescendantOf(cam) then return false end
        local name = string.lower(part.Name or "")
        if string.find(name, "tripmine") then return true end
        if string.find(name, "subspace") then return true end
        local anc = part:FindFirstAncestorOfClass("Model")
        if anc then
            local aname = string.lower(anc.Name or "")
            if string.find(aname, "tripmine") then return true end
            if string.find(aname, "subspace") then return true end
        end
        return false
    end

    local function makeLabel(part)
        if TE._labels[part] then return end
        if TE._labelCount >= TE.MaxLabels then return end
        if lp and lp.Character and part:IsDescendantOf(lp.Character) then return end
        local cam = workspace.CurrentCamera
        if cam and (part.Position - cam.CFrame.Position).Magnitude > TE.MaxDistance then return end
        local txt = Drawing.new("Text")
        txt.Text = "TRIPMINE"
        txt.Size = 18
        txt.Color = Color3.fromRGB(255, 80, 80)
        txt.Center = true
        txt.Outline = true
        txt.Visible = false
        TE._labels[part] = txt
        TE._labelCount = TE._labelCount + 1
    end

    local function removeLabel(part)
        local d = TE._labels[part]
        if not d then return end
        if d.Remove then d:Remove() end
        TE._labels[part] = nil
        TE._labelCount = TE._labelCount - 1
    end

    local function scanAndCreate()
        local descs = workspace:GetDescendants()
        task.spawn(function()
            for i = 1, #descs do
                if TE._labelCount >= TE.MaxLabels then break end
                local obj = descs[i]
                if obj and obj:IsA("BasePart") and isTripminePart(obj) then
                    if not TE._pendingSet[obj] and not TE._labels[obj] then
                        TE._pendingSet[obj] = true
                        TE._pendingQueue[#TE._pendingQueue + 1] = obj
                    end
                end
                if (i % 50) == 0 then task.wait() end
            end
        end)
    end

    local function enable()
        if TE._renderConn then return end
        scanAndCreate()
        TE._childAddedConn = workspace.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") and isTripminePart(desc)
                and not TE._pendingSet[desc]
                and not TE._labels[desc] then
                TE._pendingSet[desc] = true
                TE._pendingQueue[#TE._pendingQueue + 1] = desc
            end
        end)
        if workspace.DescendantRemoving then
            TE._childRemovedConn = workspace.DescendantRemoving:Connect(function(desc)
                if desc:IsA("BasePart") then removeLabel(desc) end
            end)
        end
        TE._queueConn = RunService.Heartbeat:Connect(function()
            if TE._labelCount >= TE.MaxLabels then return end
            local cam = workspace.CurrentCamera
            local camPos = cam and cam.CFrame.Position or nil
            local toProcess = math.min(50, #TE._pendingQueue)
            for i = 1, toProcess do
                local part = table.remove(TE._pendingQueue, 1)
                if part then TE._pendingSet[part] = nil end
                if part and part.Parent then
                    if isTripminePart(part)
                        and not (camPos and (part.Position - camPos).Magnitude > TE.MaxDistance) then
                        makeLabel(part)
                    end
                end
                if TE._labelCount >= TE.MaxLabels then break end
            end
        end)
        TE._renderConn = RunService.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            if not cam then
                for _, d in pairs(TE._labels) do d.Visible = false end
                return
            end
            local camPos = cam.CFrame.Position
            for part, draw in pairs(TE._labels) do
                if not part or not part.Parent then
                    removeLabel(part)
                else
                    local p, onScreen = cam:WorldToViewportPoint(part.Position)
                    if not onScreen or p.Z <= 0 or (part.Position - camPos).Magnitude > TE.MaxDistance then
                        draw.Visible = false
                    else
                        local dist = (part.Position - camPos).Magnitude
                        local ratio = math.clamp(50 / math.max(dist, 1), 0.125, 1)
                        draw.Size = math.floor(math.clamp(math.floor(32 * ratio), 12, 32))
                        draw.Position = Vector2.new(p.X, p.Y)
                        draw.Visible = true
                    end
                end
            end
        end)
    end

    local function disable()
        if TE._renderConn then TE._renderConn:Disconnect() TE._renderConn = nil end
        if TE._childAddedConn then TE._childAddedConn:Disconnect() TE._childAddedConn = nil end
        if TE._childRemovedConn then TE._childRemovedConn:Disconnect() TE._childRemovedConn = nil end
        if TE._queueConn then TE._queueConn:Disconnect() TE._queueConn = nil end
        TE._pendingQueue = {}
        TE._pendingSet = {}
        for p, _ in pairs(TE._labels) do removeLabel(p) end
        TE._labels = {}
        TE._labelCount = 0
    end

    return { enable = enable, disable = disable }
end)()

-- ============================================================
-- IIFE 4: Show Enemy Weapons Panel
-- ============================================================
getgenv()._ZX_V12_EnemyWeapons = (function()
    local EW = ZX_V12.enemyWeapons

    local function extractWeaponName(modelName)
        local parts = string.split(modelName, " - ")
        if #parts >= 3 then return parts[3] end
        if #parts >= 2 then return parts[2] end
        return modelName
    end

    local function extractPlayerName(modelName)
        local parts = string.split(modelName, " - ")
        if #parts >= 1 then return parts[1] end
        return "Unknown"
    end

    local function createContainer()
        if EW._container then return end
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ZX_EnemyWeaponsPanel"
        screenGui.ResetOnSpawn = false
        screenGui.DisplayOrder = 9999
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pcall(function()
            local cg = game:GetService("CoreGui")
            screenGui.Parent = cg
        end)
        if not screenGui.Parent then
            screenGui.Parent = (lp and lp:FindFirstChild("PlayerGui")) or workspace
        end

        local container = Instance.new("Frame")
        container.Name = "Panel"
        container.Size = UDim2.new(0, 220, 0, 200)
        container.Position = UDim2.new(1, -240, 0, 80)
        container.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
        container.BackgroundTransparency = 0.05
        container.BorderSizePixel = 0
        container.Visible = false
        container.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = container

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(80, 60, 120)
        stroke.Thickness = 1
        stroke.Transparency = 0.4
        stroke.Parent = container

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, 0, 0, 28)
        title.Position = UDim2.new(0, 0, 0, 0)
        title.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
        title.BackgroundTransparency = 0
        title.Text = "ENEMY WEAPONS"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.Parent = container
        local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 8) tc.Parent = title

        local list = Instance.new("Frame")
        list.Name = "List"
        list.Size = UDim2.new(1, 0, 1, -32)
        list.Position = UDim2.new(0, 0, 0, 30)
        list.BackgroundTransparency = 1
        list.Parent = container

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.Name
        layout.Padding = UDim.new(0, 4)
        layout.Parent = list

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 6)
        padding.PaddingRight = UDim.new(0, 6)
        padding.PaddingTop = UDim.new(0, 4)
        padding.Parent = list

        EW._container = container
        EW._screenGui = screenGui
    end

    local function destroyContainer()
        if EW._screenGui then
            pcall(function() EW._screenGui:Destroy() end)
        end
        EW._screenGui = nil
        EW._container = nil
        EW._labels = {}
    end

    local function updateDisplay()
        if not EW.Enabled then return end
        if not EW._container then return end
        local now = tick()
        if now - EW._lastUpdate < 0.2 then return end
        EW._lastUpdate = now
        local vms = workspace:FindFirstChild("ViewModels")
        if not vms then return end
        local seen = {}
        for plr, _ in pairs(EW._labels) do seen[plr] = false end
        for _, m in ipairs(vms:GetChildren()) do
            if m:IsA("Model") then
                local pn = extractPlayerName(m.Name)
                if pn ~= lp.Name then
                    local wpn = extractWeaponName(m.Name)
                    seen[pn] = true
                    if not EW._labels[pn] then
                        local list = EW._container:FindFirstChild("List")
                        if list then
                            local lbl = Instance.new("TextLabel")
                            lbl.Name = "W_" .. pn
                            lbl.Size = UDim2.new(1, 0, 0, 24)
                            lbl.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
                            lbl.BackgroundTransparency = 0.2
                            lbl.Font = Enum.Font.GothamSemibold
                            lbl.TextSize = 12
                            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                            lbl.TextXAlignment = Enum.TextXAlignment.Left
                            lbl.Parent = list
                            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = lbl
                            local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 8) p.Parent = lbl
                            EW._labels[pn] = lbl
                        end
                    end
                    if EW._labels[pn] then
                        EW._labels[pn].Text = pn .. ": " .. wpn
                    end
                end
            end
        end
        for plr, lbl in pairs(EW._labels) do
            if not seen[plr] then
                pcall(function() lbl:Destroy() end)
                EW._labels[plr] = nil
            end
        end
    end

    local function enable()
        createContainer()
        if EW._container then
            EW._container.Visible = true
        end
        if not EW._conn then
            EW._conn = RunService.Heartbeat:Connect(function()
                updateDisplay()
            end)
        end
    end

    local function disable()
        if EW._conn then
            EW._conn:Disconnect()
            EW._conn = nil
        end
        if EW._container then
            EW._container.Visible = false
        end
        for plr, lbl in pairs(EW._labels) do
            pcall(function() lbl:Destroy() end)
        end
        EW._labels = {}
    end

    return { enable = enable, disable = disable, destroyContainer = destroyContainer }
end)()

-- ============================================================
-- IIFE 5: Katana Warning (top label)
-- ============================================================
getgenv()._ZX_V12_KatanaWarning = (function()
    local KW = ZX_V12.katanaWarning
    local helpers = getgenv()._ZX_V12_Helpers

    local function show()
        if not KW._label then
            local sg = Instance.new("ScreenGui")
            sg.Name = "ZX_KatanaWarning"
            sg.ResetOnSpawn = false
            sg.DisplayOrder = 10000
            sg.IgnoreGuiInset = true
            pcall(function() sg.Parent = game:GetService("CoreGui") end)
            if not sg.Parent then
                sg.Parent = (lp and lp:FindFirstChild("PlayerGui")) or workspace
            end
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 400, 0, 40)
            lbl.Position = UDim2.new(0.5, -200, 0, 80)
            lbl.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            lbl.BackgroundTransparency = 0.1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 18
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.Text = "ENEMY IS HOLDING KATANA!"
            lbl.Visible = false
            lbl.Parent = sg
            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = lbl
            local s = Instance.new("UIStroke") s.Thickness = 2 s.Color = Color3.fromRGB(255, 200, 100) s.Parent = lbl
            KW._label = lbl
            KW._screenGui = sg
        end
        KW._label.Visible = true
        KW._expiry = tick() + 1.0
    end

    local function hide()
        if KW._label then
            KW._label.Visible = false
        end
    end

    local function destroy()
        if KW._screenGui then
            pcall(function() KW._screenGui:Destroy() end)
        end
        KW._screenGui = nil
        KW._label = nil
    end

    -- Start katana warning loop (always running, but only shows when AntiKatana is on)
    task.spawn(function()
        while true do
            task.wait(0.1)
            if AntiKatana.Enabled then
                local lpChar = lp.Character
                local lpRoot = lpChar and lpChar:FindFirstChild("HumanoidRootPart")
                if lpRoot then
                    local found = false
                    for _, pl in ipairs(players:GetPlayers()) do
                        if pl ~= lp and pl.Character then
                            local weaponName = helpers.getEnemyHeldWeapon(pl)
                            if weaponName then
                                local lname = string.lower(weaponName)
                                if string.find(lname, "katana") or string.find(lname, "sword") or string.find(lname, "blade") then
                                    local tChar = pl.Character
                                    local hrp = tChar:FindFirstChild("HumanoidRootPart")
                                    if hrp and (lpRoot.Position - hrp.Position).Magnitude <= 150 then
                                        local dir = (lpRoot.Position - hrp.Position)
                                        if dir.Magnitude > 0 then
                                            local forward = hrp.CFrame.LookVector
                                            if forward:Dot(dir.Unit) >= 0.3 then
                                                found = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if found then
                        show()
                    end
                end
            end
            if KW._label and KW._label.Visible and tick() > KW._expiry then
                hide()
            end
        end
    end)

    return { show = show, hide = hide, destroy = destroy }
end)()

-- ============================================================
-- UI: Register new features in tabs (minimal locals here)
-- ============================================================

-- FEATURE 1 UI: Stick to Target — REMOVED from Rage tab (moved to Legit tab)

-- FEATURE 2 UI: Tripmine ESP in ESP tab
local TripmineESPGroup = Tabs.ESP:AddRightGroupbox("Tripmine ESP")

TripmineESPGroup:AddToggle("TripmineESPEnabled", {
    Text = "Tripmine ESP (Sixth Sense)",
    Default = false,
    Tooltip = "Detects all Subspace Tripmines in the workspace and shows a red ESP label on each.\nMax 50 labels, 300 studs range. Critical for spotting hidden traps.",
})
Toggles.TripmineESPEnabled:OnChanged(function()
    ZX_V12.tripmine.Enabled = Toggles.TripmineESPEnabled.Value
    if ZX_V12.tripmine.Enabled then
        getgenv()._ZX_V12_Tripmine.enable()
        Library:Notify({ Title = "Tripmine ESP", Description = "Enabled - scanning for traps!", Time = 3 })
    else
        getgenv()._ZX_V12_Tripmine.disable()
        Library:Notify({ Title = "Tripmine ESP", Description = "Disabled", Time = 3 })
    end
end)

TripmineESPGroup:AddSlider("TripmineESPDistance", {
    Text = "Max Detection Distance",
    Default = 300,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    Tooltip = "Maximum distance (in studs) to detect tripmines.",
})
Options.TripmineESPDistance:OnChanged(function()
    ZX_V12.tripmine.MaxDistance = Options.TripmineESPDistance.Value
end)

-- FEATURE 3 UI: Show Enemy Weapons in ESP tab
local EnemyWeaponsGroup = Tabs.ESP:AddLeftGroupbox("Enemy Weapons Panel")

EnemyWeaponsGroup:AddToggle("EnemyWeaponsEnabled", {
    Text = "Show Enemy Weapons",
    Default = false,
    Tooltip = "Shows a side panel listing each enemy's current weapon.\nUpdates every 0.2s from the ViewModels folder.\nGreat for awareness - know who has sniper, katana, shield, etc.",
})
Toggles.EnemyWeaponsEnabled:OnChanged(function()
    ZX_V12.enemyWeapons.Enabled = Toggles.EnemyWeaponsEnabled.Value
    if ZX_V12.enemyWeapons.Enabled then
        getgenv()._ZX_V12_EnemyWeapons.enable()
        Library:Notify({ Title = "Enemy Weapons", Description = "Panel enabled!", Time = 3 })
    else
        getgenv()._ZX_V12_EnemyWeapons.disable()
        Library:Notify({ Title = "Enemy Weapons", Description = "Panel disabled", Time = 3 })
    end
end)

-- Cleanup on player leaving
players.PlayerRemoving:Connect(function(leaving)
    if leaving == lp then
        pcall(function() getgenv()._ZX_V12_Stick.stop() end)
        pcall(function() getgenv()._ZX_V12_Tripmine.disable() end)
        pcall(function() getgenv()._ZX_V12_EnemyWeapons.disable() end)
        pcall(function() getgenv()._ZX_V12_EnemyWeapons.destroyContainer() end)
        pcall(function() getgenv()._ZX_V12_KatanaWarning.destroy() end)
    end
end)

getgenv().ZX_V12Cleanup = function()
    pcall(function() getgenv()._ZX_V12_Stick.stop() end)
    pcall(function() getgenv()._ZX_V12_Tripmine.disable() end)
    pcall(function() getgenv()._ZX_V12_EnemyWeapons.disable() end)
    pcall(function() getgenv()._ZX_V12_EnemyWeapons.destroyContainer() end)
    pcall(function() getgenv()._ZX_V12_KatanaWarning.destroy() end)
end

-- =================================================================
-- FEATURE 6: NAME SPOOFER (UI-based, real visual spoof)
--   Based on ROMU's name spoofer - scans TextLabels, Billboards,
--   and chat to replace your real name with a spoofed one.
--   Adds verified badge to display name.
--   Toggle + Input + Dropdown + Button in Misc tab.
-- =================================================================
getgenv()._ZX_NameSpoof = (function()
    local NS = {
        Enabled = false,
        SpoofedName = "ZytheraX",
        SpoofedDisplay = "ZytheraX",
        Mode = "Both",       -- "Name", "DisplayName", "Both"
        UseBadge = true,     -- Add verified badge
        Separator = " ",
        _conns = {},
        _charConn = nil,
        _chatHooked = false,
        _realName = nil,
        _realDisplay = nil,
        _badge = nil,
    }

    -- Cached services
    local _Players = game:GetService("Players")
    local _Workspace = game:GetService("Workspace")
    local _CoreGui = nil
    pcall(function() _CoreGui = game:GetService("CoreGui") end)
    local _TextChatService = game:GetService("TextChatService")

    local function getBadge()
        -- Use ✓ checkmark as verified badge (works on all executors)
        return "✓"
    end

    local function getTargetDisplay()
        if NS.UseBadge then
            return NS.SpoofedDisplay .. NS.Separator .. getBadge()
        end
        return NS.SpoofedDisplay
    end

    local function getTargetName()
        return NS.SpoofedName
    end

    -- Replace text in a TextLabel/Button/Box
    local function spoofAndBadge(obj)
        if not NS.Enabled then return end
        if not obj.Text or obj.Text == "" then return end
        local text = obj.Text

        -- Already spoofed - skip
        if text:find(NS.SpoofedDisplay) then return end

        -- If text equals our fake display without badge, add badge
        if NS.UseBadge and text == NS.SpoofedDisplay then
            obj.Text = getTargetDisplay()
            return
        end

        -- Skip if text is just our fake name
        if text == NS.SpoofedName then return end

        local newText = text
        local changed = false

        -- Replace real display name
        if NS.Mode == "DisplayName" or NS.Mode == "Both" then
            if NS._realDisplay and newText:find(NS._realDisplay) then
                newText = newText:gsub(NS._realDisplay, getTargetDisplay())
                changed = true
            end
        end

        -- Replace real username
        if NS.Mode == "Name" or NS.Mode == "Both" then
            if NS._realName and newText:find(NS._realName) then
                newText = newText:gsub(NS._realName, getTargetName())
                changed = true
            end
        end

        if changed and newText ~= obj.Text then
            obj.Text = newText
        end
    end

    local function monitorObject(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            spoofAndBadge(obj)
            local conn = obj:GetPropertyChangedSignal("Text"):Connect(function()
                spoofAndBadge(obj)
            end)
            table.insert(NS._conns, conn)
        end
    end

    local function monitorBillboard(billboard)
        for _, textObj in pairs(billboard:GetDescendants()) do
            if textObj:IsA("TextLabel") then
                local txt = textObj.Text
                if (NS._realDisplay and txt:find(NS._realDisplay))
                    or txt:find(NS.SpoofedDisplay)
                    or (NS._realName and txt:find(NS._realName))
                    or txt:find(NS.SpoofedName) then
                    if NS.Mode == "Name" or NS.Mode == "Both" then
                        textObj.Text = getTargetName()
                    else
                        textObj.Text = getTargetDisplay()
                    end
                end
                local conn = textObj:GetPropertyChangedSignal("Text"):Connect(function()
                    if NS.Mode == "Name" or NS.Mode == "Both" then
                        if textObj.Text ~= getTargetName() then
                            textObj.Text = getTargetName()
                        end
                    else
                        if textObj.Text ~= getTargetDisplay() then
                            textObj.Text = getTargetDisplay()
                        end
                    end
                end)
                table.insert(NS._conns, conn)
            end
        end
        local conn = billboard.DescendantAdded:Connect(function(obj)
            if obj:IsA("TextLabel") then
                if NS.Mode == "Name" or NS.Mode == "Both" then
                    obj.Text = getTargetName()
                else
                    obj.Text = getTargetDisplay()
                end
                local c = obj:GetPropertyChangedSignal("Text"):Connect(function()
                    if NS.Mode == "Name" or NS.Mode == "Both" then
                        if obj.Text ~= getTargetName() then
                            obj.Text = getTargetName()
                        end
                    else
                        if obj.Text ~= getTargetDisplay() then
                            obj.Text = getTargetDisplay()
                        end
                    end
                end)
                table.insert(NS._conns, c)
            end
        end)
        table.insert(NS._conns, conn)
    end

    local function monitorCharacter(char)
        local humanoid = char:WaitForChild("Humanoid", 10)
        if humanoid then
            if NS.Mode == "DisplayName" or NS.Mode == "Both" then
                humanoid.DisplayName = getTargetDisplay()
                local conn = humanoid:GetPropertyChangedSignal("DisplayName"):Connect(function()
                    if NS.Enabled and humanoid.DisplayName ~= getTargetDisplay() then
                        humanoid.DisplayName = getTargetDisplay()
                    end
                end)
                table.insert(NS._conns, conn)
            end
        end
        task.wait(0.5)
        for _, billboard in pairs(char:GetDescendants()) do
            if billboard:IsA("BillboardGui") then
                monitorBillboard(billboard)
            end
        end
    end

    local function findAndMonitorPlots()
        for _, obj in pairs(_Workspace:GetDescendants()) do
            if obj:IsA("BillboardGui") then
                for _, textObj in pairs(obj:GetDescendants()) do
                    if textObj:IsA("TextLabel") then
                        local txt = textObj.Text
                        if (NS._realName and txt:find(NS._realName))
                            or (NS._realDisplay and txt:find(NS._realDisplay))
                            or txt:find(NS.SpoofedName)
                            or txt:find(NS.SpoofedDisplay) then
                            monitorBillboard(obj)
                            break
                        end
                    end
                end
            end
        end
    end

    local function hookChat()
        if NS._chatHooked then return end
        pcall(function()
            if _TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                _TextChatService.OnIncomingMessage = function(message)
                    if not NS.Enabled then return nil end
                    local props = Instance.new("TextChatMessageProperties")
                    if message.TextSource and message.TextSource.UserId == lp.UserId then
                        props.PrefixText = getTargetDisplay()
                    end
                    return props
                end
                NS._chatHooked = true
            end
        end)
    end

    local function enable()
        if NS.Enabled then return end
        NS.Enabled = true
        -- Cache real name/display
        NS._realName = lp.Name
        NS._realDisplay = lp.DisplayName

        -- Hook chat
        hookChat()

        -- Monitor PlayerGui
        pcall(function()
            for _, v in ipairs(lp.PlayerGui:GetDescendants()) do
                monitorObject(v)
            end
            local conn = lp.PlayerGui.DescendantAdded:Connect(monitorObject)
            table.insert(NS._conns, conn)
        end)

        -- Monitor CoreGui (escape menu, leaderboard)
        pcall(function()
            if _CoreGui then
                for _, v in ipairs(_CoreGui:GetDescendants()) do
                    monitorObject(v)
                end
                local conn = _CoreGui.DescendantAdded:Connect(monitorObject)
                table.insert(NS._conns, conn)
            end
        end)

        -- Monitor character
        if lp.Character then
            task.spawn(function() monitorCharacter(lp.Character) end)
        end
        NS._charConn = lp.CharacterAdded:Connect(function(char)
            task.spawn(function() monitorCharacter(char) end)
        end)

        -- Monitor plots in workspace
        task.spawn(function()
            findAndMonitorPlots()
            local conn = _Workspace.DescendantAdded:Connect(function(obj)
                if not NS.Enabled then return end
                if obj:IsA("BillboardGui") then
                    task.wait(0.5)
                    for _, textObj in pairs(obj:GetDescendants()) do
                        if textObj:IsA("TextLabel") then
                            local txt = textObj.Text
                            if (NS._realName and txt:find(NS._realName))
                                or (NS._realDisplay and txt:find(NS._realDisplay))
                                or txt:find(NS.SpoofedName)
                                or txt:find(NS.SpoofedDisplay) then
                                monitorBillboard(obj)
                                break
                            end
                        end
                    end
                end
            end)
            table.insert(NS._conns, conn)
        end)

        Library:Notify({ Title = "Name Spoof", Description = "Enabled - name: " .. NS.SpoofedName, Time = 3 })
    end

    local function disable()
        NS.Enabled = false
        -- Disconnect all
        for _, c in ipairs(NS._conns) do
            pcall(function() c:Disconnect() end)
        end
        NS._conns = {}
        if NS._charConn then
            pcall(function() NS._charConn:Disconnect() end)
            NS._charConn = nil
        end
        -- Reset chat hook (set to nil)
        pcall(function()
            _TextChatService.OnIncomingMessage = nil
        end)
        NS._chatHooked = false
        -- Restore humanoid display name
        pcall(function()
            if lp and lp.Character then
                local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                if hum and NS._realDisplay then
                    hum.DisplayName = NS._realDisplay
                end
            end
        end)
        Library:Notify({ Title = "Name Spoof", Description = "Disabled", Time = 3 })
    end

    local function setName(newName)
        NS.SpoofedName = newName or "ZytheraX"
        NS.SpoofedDisplay = newName or "ZytheraX"
        -- If already enabled, re-scan to update
        if NS.Enabled then
            -- Force refresh humanoid
            pcall(function()
                if lp and lp.Character then
                    local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.DisplayName = getTargetDisplay()
                    end
                end
            end)
        end
    end

    local function setMode(mode)
        NS.Mode = mode or "Both"
    end

    local function setBadge(useBadge)
        NS.UseBadge = useBadge
        if NS.Enabled then
            pcall(function()
                if lp and lp.Character then
                    local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.DisplayName = getTargetDisplay()
                    end
                end
            end)
        end
    end

    return {
        enable = enable,
        disable = disable,
        setName = setName,
        setMode = setMode,
        setBadge = setBadge,
        getState = function() return NS end,
    }
end)()

-- UI: Name Spoof in Misc tab
local NameSpoofGroup = Tabs.Misc:AddLeftGroupbox("Name Spoofer")

NameSpoofGroup:AddToggle("EnableNameSpoof", {
    Text = "Enable Name Spoof",
    Default = false,
    Tooltip = "Real name spoofing! Scans all TextLabels, Billboards, nametags, escape menu, leaderboard, and chat.\\nReplaces your real name with the spoofed one everywhere you can see it.\\nNote: Server-side scripts still see your real name - this is client-side visual only.",
})
Toggles.EnableNameSpoof:OnChanged(function()
    if Toggles.EnableNameSpoof.Value then
        getgenv()._ZX_NameSpoof.enable()
    else
        getgenv()._ZX_NameSpoof.disable()
    end
end)

NameSpoofGroup:AddInput("NameSpoofText", {
    Default = "ZytheraX",
    Numeric = false,
    Finished = true,
    Text = "Spoofed Name",
    Tooltip = "The fake name that will replace your real name everywhere on your screen.",
    Placeholder = "Enter spoofed name...",
})
Options.NameSpoofText:OnChanged(function()
    getgenv()._ZX_NameSpoof.setName(Options.NameSpoofText.Value)
end)

NameSpoofGroup:AddDropdown("NameSpoofMode", {
    Values = {"Both", "Name", "DisplayName"},
    Default = 1,
    Multi = false,
    Text = "Spoof Mode",
    Tooltip = "Both = spoof Name AND DisplayName (recommended)\\nName = spoof only username\\nDisplayName = spoof only display name (nametag)",
})
Options.NameSpoofMode:OnChanged(function()
    getgenv()._ZX_NameSpoof.setMode(Options.NameSpoofMode.Value)
end)

NameSpoofGroup:AddToggle("NameSpoofBadge", {
    Text = "Add Verified Badge ✓",
    Default = true,
    Tooltip = "Adds a green ✓ verified badge after your display name in nametags and chat.\\nLike Roblox verified accounts.",
})
Toggles.NameSpoofBadge:OnChanged(function()
    getgenv()._ZX_NameSpoof.setBadge(Toggles.NameSpoofBadge.Value)
end)

NameSpoofGroup:AddButton("Random Name", function()
    local prefix = {"Pro", "EZ", "God", "King", "Bot", "Rage", "Silent", "Ghost", "Dark", "Xx", "Lx", "Rx"}
    local suffix = {"Player", "Gamer", "Killer", "Hunter", "Master", "Legend", "Sniper", "Slayer", "Boss", "_YT", "_YT", "Pro"}
    local num = math.random(100, 9999)
    local newName = prefix[math.random(1, #prefix)] .. suffix[math.random(1, #suffix)] .. tostring(num)
    if Options.NameSpoofText then
        Options.NameSpoofText:SetValue(newName)
    end
    getgenv()._ZX_NameSpoof.setName(newName)
    Library:Notify({ Title = "Name Spoof", Description = "Name set to: " .. newName, Time = 3 })
end)

-- Cleanup on leaving
players.PlayerRemoving:Connect(function(leaving)
    if leaving == lp then
        pcall(function() getgenv()._ZX_NameSpoof.disable() end)
    end
end)

-- =================================================================
-- END NEW FEATURES
-- =================================================================

-- ═════════════════════════════════════════════════════════════════
-- UNIVERSAL SPOOFER (Name + Level + Winstreak) — IIFE wrapped
-- ═════════════════════════════════════════════════════════════════
getgenv()._ZX_LeaderstatsSpoofer = (function()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Spoof = {
        Enabled = false,
        NameSpoof = false,
        SpoofedName = "Andy",
        EnemyName = "Johnny",
        LevelSpoof = false,
        SpoofedLevel = 996,
        WinstreakSpoof = false,
        SpoofedWinstreak = 56,
        _connections = {},
    }
    getgenv().NameSpooferConfig = Spoof

    local function spoofPlayer(player)
        if not Spoof.NameSpoof then return end
        if player == LocalPlayer then
            pcall(function()
                player.Name = Spoof.SpoofedName
                player.DisplayName = Spoof.SpoofedName
            end)
        else
            pcall(function()
                player.Name = Spoof.EnemyName
                player.DisplayName = Spoof.EnemyName
            end)
        end
    end

    local function spoofLeaderstats(player)
        if player ~= LocalPlayer then return end
        local leaderstats = player:FindFirstChild("CustomLeaderstats")
        if not leaderstats then return end
        if Spoof.LevelSpoof then
            local levelVal = leaderstats:FindFirstChild("Level")
            if levelVal and levelVal:IsA("IntValue") then
                levelVal.Value = Spoof.SpoofedLevel
            end
            pcall(function() player:SetAttribute("Level", Spoof.SpoofedLevel) end)
        end
        if Spoof.WinstreakSpoof then
            local winStreakFolder = leaderstats:FindFirstChild("Win Streak")
            if winStreakFolder and winStreakFolder:IsA("Folder") then
                local streakVal = winStreakFolder:FindFirstChildWhichIsA("IntValue")
                if streakVal then streakVal.Value = Spoof.SpoofedWinstreak end
            elseif winStreakFolder and winStreakFolder:IsA("IntValue") then
                winStreakFolder.Value = Spoof.SpoofedWinstreak
            end
            pcall(function() player:SetAttribute("StatisticDuelsWinStreak", Spoof.SpoofedWinstreak) end)
        end
    end

    local function findAllTitleLabels(instance, results)
        results = results or {}
        if not instance then return results end
        for _, child in ipairs(instance:GetChildren()) do
            if child:IsA("TextLabel") and child.Name == "Title" then
                table.insert(results, child)
            end
            findAllTitleLabels(child, results)
        end
        return results
    end

    local GUI_PATH = {"PlayerGui", "MainGui", "PlayerList", "Container", "Elements", "Container", "Middle", "List", "Container"}

    local function getListContainer()
        local node = LocalPlayer
        for _, name in ipairs(GUI_PATH) do
            if not node then return nil end
            node = node:FindFirstChild(name)
        end
        return node
    end

    local function spoofTitleLabelsInContainer(container)
        if not container then return end
        for _, playerFrame in ipairs(container:GetChildren()) do
            if playerFrame:IsA("Frame") then
                local spoofed = false
                local innerContainer = playerFrame:FindFirstChild("Container")
                if innerContainer and innerContainer:IsA("Frame") then
                    for _, child in ipairs(innerContainer:GetChildren()) do
                        if child:IsA("Frame") then
                            local titleLabel = child:FindFirstChild("Title")
                            if titleLabel and titleLabel:IsA("TextLabel") then
                                local isLocal = titleLabel.Text == LocalPlayer.Name or titleLabel.Text == LocalPlayer.DisplayName
                                titleLabel.Text = isLocal and Spoof.SpoofedName or Spoof.EnemyName
                                spoofed = true
                            end
                        end
                    end
                end
                if not spoofed then
                    local labels = findAllTitleLabels(playerFrame)
                    for _, titleLabel in ipairs(labels) do
                        local isLocal = titleLabel.Text == LocalPlayer.Name or titleLabel.Text == LocalPlayer.DisplayName
                        titleLabel.Text = isLocal and Spoof.SpoofedName or Spoof.EnemyName
                    end
                end
            end
        end
    end

    local function watchContainerForNewFrames(container)
        if not container then return end
        local conn = container.ChildAdded:Connect(function(child)
            if child:IsA("Frame") then
                task.wait(0.1)
                pcall(spoofTitleLabelsInContainer, container)
            end
        end)
        table.insert(Spoof._connections, conn)
    end

    local function startGuiSpoofLoop()
        task.spawn(function()
            local playerGui = LocalPlayer:WaitForChild("PlayerGui", 30)
            if not playerGui then return end
            local monitoredContainer = nil
            while task.wait(0.5) do
                if not Spoof.NameSpoof then continue end
                local listContainer = getListContainer()
                if listContainer and listContainer ~= monitoredContainer then
                    monitoredContainer = listContainer
                    watchContainerForNewFrames(listContainer)
                end
                if listContainer then
                    pcall(spoofTitleLabelsInContainer, listContainer)
                end
            end
        end)
    end

    local function watchLeaderstats(player)
        if player ~= LocalPlayer then return end
        local conn
        conn = player.ChildAdded:Connect(function(child)
            if child.Name == "CustomLeaderstats" then
                task.wait(0.1)
                spoofLeaderstats(player)
                if conn then conn:Disconnect() end
            end
        end)
        table.insert(Spoof._connections, conn)
        spoofLeaderstats(player)
    end

    local function enable()
        if Spoof.Enabled then return end
        Spoof.Enabled = true
        for _, player in ipairs(Players:GetPlayers()) do
            spoofPlayer(player)
            if player == LocalPlayer then watchLeaderstats(player) end
        end
        local playerAddedConn = Players.PlayerAdded:Connect(function(player)
            spoofPlayer(player)
        end)
        table.insert(Spoof._connections, playerAddedConn)
        task.spawn(function()
            while task.wait(3) do
                if Spoof.LevelSpoof or Spoof.WinstreakSpoof then
                    spoofLeaderstats(LocalPlayer)
                end
            end
        end)
        startGuiSpoofLoop()
    end

    local function disable()
        Spoof.Enabled = false
        for _, c in ipairs(Spoof._connections) do pcall(function() c:Disconnect() end) end
        Spoof._connections = {}
    end

    return {enable = enable, disable = disable, getState = function() return Spoof end}
end)()

-- UI: Universal Spoofer in Misc tab
local SpooferGroup = Tabs.Misc:AddLeftGroupbox("Universal Spoofer")

SpooferGroup:AddToggle("EnableNameSpoof", {
    Text = "Enable Name Spoof (UI/TextLabels)",
    Default = false,
    Tooltip = "Real name spoofing! Scans all TextLabels, Billboards, nametags, escape menu, leaderboard, and chat.\nReplaces your real name with the spoofed one everywhere you can see it.",
})
Toggles.EnableNameSpoof:OnChanged(function()
    if Toggles.EnableNameSpoof.Value then
        getgenv()._ZX_LeaderstatsSpoofer.getState().NameSpoof = true
        getgenv()._ZX_LeaderstatsSpoofer.enable()
    else
        getgenv()._ZX_LeaderstatsSpoofer.getState().NameSpoof = false
    end
end)

SpooferGroup:AddInput("NameSpoofText", {
    Default = "ZytheraX",
    Numeric = false,
    Finished = true,
    Text = "Your Spoofed Name",
    Tooltip = "The fake name that will replace your real name everywhere.",
    Placeholder = "Enter spoofed name...",
})
Options.NameSpoofText:OnChanged(function()
    getgenv()._ZX_LeaderstatsSpoofer.getState().SpoofedName = Options.NameSpoofText.Value
end)

SpooferGroup:AddInput("EnemyNameInput", {
    Default = "Johnny",
    Numeric = false,
    Finished = true,
    Text = "Enemy Spoofed Name",
})
Options.EnemyNameInput:OnChanged(function()
    getgenv()._ZX_LeaderstatsSpoofer.getState().EnemyName = Options.EnemyNameInput.Value
end)

SpooferGroup:AddButton("Random Name", function()
    local prefix = {"Pro", "EZ", "God", "King", "Bot", "Rage", "Silent", "Ghost", "Dark", "Xx", "Lx", "Rx"}
    local suffix = {"Player", "Gamer", "Killer", "Hunter", "Master", "Legend", "Sniper", "Slayer", "Boss", "_YT", "_YT", "Pro"}
    local num = math.random(100, 9999)
    local newName = prefix[math.random(1, #prefix)] .. suffix[math.random(1, #suffix)] .. tostring(num)
    if Options.NameSpoofText then
        Options.NameSpoofText:SetValue(newName)
    end
    getgenv()._ZX_LeaderstatsSpoofer.getState().SpoofedName = newName
    Library:Notify({ Title = "Name Spoof", Description = "Name set to: " .. newName, Time = 3 })
end)

SpooferGroup:AddToggle("SpoofLevel", {
    Text = "Spoof Level",
    Default = false,
    Tooltip = "Changes your level in leaderstats (visual only).",
})
Toggles.SpoofLevel:OnChanged(function()
    getgenv()._ZX_LeaderstatsSpoofer.getState().LevelSpoof = Toggles.SpoofLevel.Value
    if Toggles.SpoofLevel.Value and not getgenv()._ZX_LeaderstatsSpoofer.getState().Enabled then
        getgenv()._ZX_LeaderstatsSpoofer.enable()
    end
end)

SpooferGroup:AddSlider("SpoofedLevelInput", {
    Text = "Spoofed Level",
    Default = 996,
    Min = 1,
    Max = 9999,
    Rounding = 0,
})
Options.SpoofedLevelInput:OnChanged(function()
    getgenv()._ZX_LeaderstatsSpoofer.getState().SpoofedLevel = Options.SpoofedLevelInput.Value
end)

SpooferGroup:AddToggle("SpoofWinstreak", {
    Text = "Spoof Winstreak",
    Default = false,
    Tooltip = "Changes your winstreak in leaderstats (visual only).",
})
Toggles.SpoofWinstreak:OnChanged(function()
    getgenv()._ZX_LeaderstatsSpoofer.getState().WinstreakSpoof = Toggles.SpoofWinstreak.Value
    if Toggles.SpoofWinstreak.Value and not getgenv()._ZX_LeaderstatsSpoofer.getState().Enabled then
        getgenv()._ZX_LeaderstatsSpoofer.enable()
    end
end)

SpooferGroup:AddSlider("SpoofedWinstreakInput", {
    Text = "Spoofed Winstreak",
    Default = 56,
    Min = 0,
    Max = 9999,
    Rounding = 0,
})
Options.SpoofedWinstreakInput:OnChanged(function()
    getgenv()._ZX_LeaderstatsSpoofer.getState().SpoofedWinstreak = Options.SpoofedWinstreakInput.Value
end)

-- ═════════════════════════════════════════════════════════════════
-- AUTO WEAPON PICK — IIFE wrapped
-- ═════════════════════════════════════════════════════════════════
getgenv()._ZX_AutoWeaponPick = (function()
    local AWP = {
        Enabled = false,
        Weapons = {"Bow", "Handgun", "Fists", "Grenade"},
        _conn = nil,
    }
    local localPlayer = game:GetService("Players").LocalPlayer
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local weaponPickRemote = nil
    local prePickRemote = nil

    local function fetchRemoteReferences()
        if weaponPickRemote then return true end
        local success = pcall(function()
            weaponPickRemote = replicatedStorage.Remotes.Replication.Fighter.PickWeapons
            prePickRemote = replicatedStorage.Remotes.Duels.PickWeaponsAheadOfTime
        end)
        return success and weaponPickRemote ~= nil
    end

    local function createSelectionPayload()
        local payload = {}
        for index, weaponName in next, AWP.Weapons do
            if weaponName and weaponName ~= "" then
                payload[index] = weaponName
            end
        end
        return payload
    end

    local function attemptWeaponSelection()
        if not fetchRemoteReferences() then return end
        local selectionData = createSelectionPayload()
        if not next(selectionData) then return end
        pcall(function() weaponPickRemote:FireServer(selectionData) end)
        pcall(function() prePickRemote:FireServer(selectionData) end)
    end

    local function start()
        if AWP._conn then return end
        AWP._conn = task.spawn(function()
            while task.wait(0.1) do
                if not AWP.Enabled then break end
                local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
                local selectionInterface = playerGui and playerGui:FindFirstChild("PickWeapons", true)
                if selectionInterface and selectionInterface.Visible then
                    attemptWeaponSelection()
                    repeat
                        task.wait(0.1)
                    until not (selectionInterface and selectionInterface.Visible)
                end
            end
        end)
    end

    local function stop()
        AWP.Enabled = false
    end

    return {start = start, stop = stop, getState = function() return AWP end}
end)()

local AutoWeaponGroup = Tabs.Misc:AddRightGroupbox("Auto Weapon Pick")

AutoWeaponGroup:AddToggle("EnableAutoWeaponPick", {
    Text = "Enable Auto Weapon Pick",
    Default = false,
    Tooltip = "Automatically picks weapons when the duel selection screen appears.\nSet your 4 weapons below.",
})
Toggles.EnableAutoWeaponPick:OnChanged(function()
    local state = getgenv()._ZX_AutoWeaponPick.getState()
    state.Enabled = Toggles.EnableAutoWeaponPick.Value
    if state.Enabled then
        getgenv()._ZX_AutoWeaponPick.start()
    else
        getgenv()._ZX_AutoWeaponPick.stop()
    end
end)

for i = 1, 4 do
    AutoWeaponGroup:AddInput("WeaponSlot" .. i, {
        Default = "",
        Numeric = false,
        Finished = true,
        Text = "Weapon Slot " .. i,
        Placeholder = "e.g. Bow, Handgun, Fists, Grenade",
    })
end

local function updateWeaponsArray()
    local weapons = {}
    for i = 1, 4 do
        local opt = Options["WeaponSlot" .. i]
        if opt and opt.Value and opt.Value ~= "" then
            weapons[i] = opt.Value
        end
    end
    getgenv()._ZX_AutoWeaponPick.getState().Weapons = weapons
end

for i = 1, 4 do
    local opt = Options["WeaponSlot" .. i]
    if opt then
        opt:OnChanged(updateWeaponsArray)
    end
end
end -- end do block for new features

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("ZytheraXHub")
SaveManager:SetFolder("ZytheraXHub/game-config")

task.wait(0.1)

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()