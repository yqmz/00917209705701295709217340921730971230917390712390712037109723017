-- =============================================================================
--  KiciaHook - open-source RIVALS script
-- =============================================================================
--  This is a readable, runnable reconstruction of the KiciaHook feature set for
--  RIVALS, rebuilt by pattern-matching a public deobfuscation against the live
--  game, with additional features and a different UI on top.
-- =============================================================================
(function()

-- -----------------------------------------------------------------------------
-- Global environment resolution
-- -----------------------------------------------------------------------------
-- A candidate env only wins if a key written to it is visible as a bare global
-- read from this script. Solara-tier executors ship a getgenv whose table is
-- disconnected from the real environment (sUNC: "the function environment of
-- getgenv should not be the result of it"), which would otherwise strand the
-- executor stubs below in a dead table nothing can see.
local function ResolveGlobalEnv()
    local candidates = {}
    if type(getgenv) == 'function' then
        local ok, env = pcall(getgenv)
        if ok and type(env) == 'table' then
            table.insert(candidates, env)
        end
    end
    if type(getfenv) == 'function' then
        local ok, env = pcall(getfenv, 0)
        if ok and type(env) == 'table' then
            table.insert(candidates, env)
        end
    end
    for _, env in ipairs(candidates) do
        local wrote = pcall(function() env.__KiciaHookEnvProbe = true end)
        local seen = __KiciaHookEnvProbe == true
        pcall(function() env.__KiciaHookEnvProbe = nil end)
        if wrote and seen then
            return env
        end
    end
    return _G
end

local __kicia_hook_genv = ResolveGlobalEnv()

-- _G mirror: the resolved env can be a per-execution table on executors with a
-- broken getgenv, so the "already running" guard also needs a table that
-- survives re-execution. The Unload button clears both flags.
if __kicia_hook_genv.Executed or _G.__KiciaHookExecuted then
    return
end
__kicia_hook_genv.Executed = true
pcall(function() _G.__KiciaHookExecuted = true end)

-- -----------------------------------------------------------------------------
-- Executor capability stubs
-- -----------------------------------------------------------------------------
-- Executors vary wildly in which functions they implement. Rather than sprinkle
-- `if type(x) == 'function'` everywhere, install harmless no-op stubs for the
-- missing ones and remember which names were stubbed. Features then ask
-- KiciaHookCaps whether support is real before enabling themselves.
do
    local _noop = function() end
    local _genv = __kicia_hook_genv
    local _stubs = {
        getconnections    = function() return {} end,
        hookmetamethod    = function(obj, method, hook) return nil end,
        hookfunction      = function(orig, hook) return orig end,
        newcclosure       = function(f) return f end,
        getnamecallmethod = function() return '' end,
        firetouchinterest = _noop,
        firesignal        = _noop,
        setclipboard      = _noop,
        cloneref          = function(o) return o end,
        gethui            = _noop,
        checkcaller       = function() return false end,
        clonefunction     = function(f) return f end,
        getrawmetatable   = function(o) return getmetatable(o) end,
        setrawmetatable   = function(o, mt) return setmetatable(o, mt) end,
        setreadonly       = _noop,
        isreadonly        = function() return false end,
        getgc             = function() return {} end,
        filtergc          = function() return {} end,
        replicatesignal   = _noop,
        fireclickdetector = _noop,
        fireproximityprompt = _noop,
        getthreadidentity = function() return 0 end,
        setthreadidentity = _noop,
        getsenv           = function() return {} end,
        getscriptfromthread = _noop,
        getcallbackvalue  = _noop,
        getnilinstances   = function() return {} end,
        getinstances      = function() return {} end,
        isfunctionhooked  = function() return false end,
        restorefunction   = _noop,
    }
    -- Every name that got a stub (or was found missing/broken) lands in
    -- _stubbed. Stubs keep bare calls from hard-erroring, but they also make
    -- `type(fn) == 'function'` checks lie -- KiciaHookCaps below is the only
    -- honest way to ask "does this executor really support X".
    local _stubbed = {}
    for name, stub in pairs(_stubs) do
        if rawget(_genv, name) == nil then
            _genv[name] = stub
            _stubbed[name] = true
        end
    end

    -- RIVALS' anti-cheat treats hookfunction itself as a detector surface, so we
    -- never live-probe the executor's implementation while that experience is
    -- active. Since this build only runs in RIVALS the probe is effectively
    -- always skipped; the check is kept so the reason stays visible.
    if game.GameId ~= 6035872082 and _genv.hookfunction ~= _stubs.hookfunction then
        local ok = pcall(_genv.hookfunction, function() end, function() end)
        if not ok then
            _genv.hookfunction = _stubs.hookfunction
            _stubbed.hookfunction = true
        end
    end

    -- Solara and Xeno ship a fake firetouchinterest (it exists, fails sUNC, and
    -- never registers a touch) -- force the stub so capability gates block the
    -- feature instead of letting it spam a broken call every frame.
    local _exName = type(identifyexecutor) == 'function' and identifyexecutor() or ''
    local _exNameLower = string.lower(_exName)
    if _exNameLower:find('solara') or _exNameLower:find('xeno') then
        _genv.firetouchinterest = _noop
        _stubbed.firetouchinterest = true
    end

    -- Globals used by the hook that get no stub (call sites handle nil), but
    -- that support checks still need to know about.
    for _, name in ipairs({ 'queue_on_teleport', 'sethiddenproperty', 'gethiddenproperty', 'getrenv', 'getcallingscript' }) do
        if type(_genv[name]) ~= 'function' then
            _stubbed[name] = true
        end
    end

    -- A getgenv that lost the env probe above is semantically broken even if it
    -- exists (it returns a table detached from the environment).
    if type(getgenv) ~= 'function' then
        _stubbed.getgenv = true
    else
        local ok, env = pcall(getgenv)
        if not (ok and env == _genv) then
            _stubbed.getgenv = true
        end
    end

    -- debug.* executor extensions live inside the standard debug table, so the
    -- global stub pass above never sees them, and the resolved env table is not
    -- guaranteed to proxy dotted reads. Probe them with bare reads here so
    -- Caps.has answers honestly for names like 'debug.getupvalues'.
    local _debugExt = {}
    for _, name in ipairs({ 'getupvalue', 'getupvalues', 'setupvalue', 'getconstant', 'getconstants', 'setconstant', 'getprotos', 'getproto', 'getstack', 'info' }) do
        local ok, value = pcall(function() return debug[name] end)
        _debugExt['debug.' .. name] = (ok and type(value) == 'function') or false
    end

    _genv.KiciaHookCaps = {
        stubbed = _stubbed,
        -- has('name') / has('debug.getupvalue'): true only when the executor
        -- provides a real implementation (existence only -- a function that
        -- exists but is broken, e.g. Solara's sethiddenproperty, still passes;
        -- keep pcall around actual calls).
        has = function(name)
            if _stubbed[name] then
                return false
            end
            local probed = _debugExt[name]
            if probed ~= nil then
                return probed
            end
            local target = _genv
            for part in string.gmatch(name, '[^%.]+') do
                if type(target) ~= 'table' then
                    return false
                end
                local ok, value = pcall(function() return target[part] end)
                if not ok then
                    return false
                end
                target = value
            end
            return type(target) == 'function'
        end,
    }
end

-- -----------------------------------------------------------------------------
-- Supported experiences
-- -----------------------------------------------------------------------------
-- This open-source build ships RIVALS only. GameId (not PlaceId) is used so
-- every place in the universe -- lobby, ranked, casual -- matches one entry.
local Games = {
    ['RIVALS'] = { ID = 6035872082, State = true },
}

repeat task.wait() until game:IsLoaded()

-- Elevate thread identity to 8 before loading the bundled Obsidian UI library.
-- Roblox's capability system gates some Instance writes behind the Plugin
-- capability; identity 8 carries the full capability bitmask (Plugin included).
-- Without this, the loaded chunk and any persistent UI state it creates
-- (Library.ScreenGui, NotificationArea) inherit an identity whose property
-- writes can throw "lacking capability Plugin" when the Notify path runs
-- FillInstance against a fresh Frame.
local function __KiciaHookElevateIdentity()
    if type(setthreadidentity) == 'function' then
        pcall(setthreadidentity, 8)
    end
end
__KiciaHookElevateIdentity()

-- -----------------------------------------------------------------------------
-- Shared module registry
-- -----------------------------------------------------------------------------
-- The build script concatenates every module into one file. Each one is emitted
-- as `__kicia_hook_shared.<name> = function() ... end` at the injection marker
-- below, and RequireSharedModule runs it once and caches the result -- the same
-- contract as Roblox's require(), without needing real ModuleScripts.
local __kicia_hook_shared = {}

local __shared_module_cache = {}

local function RequireSharedModule(name)
    if type(__kicia_hook_shared) ~= 'table' then
        error('Missing shared module table')
    end

    local cached = __shared_module_cache[name]
    if cached ~= nil then
        return cached
    end

    local loader = __kicia_hook_shared[name]
    if type(loader) ~= 'function' then
        error('Missing shared module: ' .. tostring(name))
    end

    local result = loader()
    __shared_module_cache[name] = result
    return result
end

-- Declared BEFORE the injection marker on purpose: shared module bodies close
-- over this scope, so anything declared after the marker would be invisible to
-- them. The error reporter needs Library to show its notifications.
local Library = nil
local ErrorReporter = nil

__kicia_hook_shared.obsidian_icons = function()
-- Vendored from lucide-roblox-direct e8b0019ebd7e18c455bbbd720ed7b610bc6675f7; code is bundled, PNG assets remain runtime-fetched, inline type annotations removed.
local Lucide = {}

local IS_GETCUSTOMASSET_BROKEN = false

if writefile and isfolder and makefolder and getcustomasset then
	if not isfolder("lucide-icons") then
		makefolder("lucide-icons")
	end

	if not isfile("lucide-icons/version.txt") then
		writefile("lucide-icons/version.txt", "2026-08-03T17:46:40.608886867+00:00")
	end

	local ShouldUpdate = readfile("lucide-icons/version.txt") ~= "2026-08-03T17:46:40.608886867+00:00"

	if ShouldUpdate then
		writefile("lucide-icons/version.txt", "2026-08-03T17:46:40.608886867+00:00")
	end

	for spritesheet = 1, 2 do
		if isfile(`lucide-icons/{spritesheet}.png`) and not ShouldUpdate then
			continue
		end

		writefile(
			`lucide-icons/{spritesheet}.png`,
			game:HttpGet(
				`https://raw.githubusercontent.com/mstudio45/lucide-roblox-direct/refs/heads/main/spritesheets/{spritesheet}.png`
			)
		)
	end

	local Success, _Error = pcall(function()
		return getcustomasset("lucide-icons/1.png")
	end)

	IS_GETCUSTOMASSET_BROKEN = not Success
end

local icons = {{"align-vertical-distribute-center","chevron-down","list-restart","table-cells-split","gavel","dna-off","refresh-ccw-dot","venus","bean","circle-question-mark","folder-code","bolt","heater","feather","align-horizontal-distribute-center","grip-vertical","pill-bottle","person-standing","badge-swiss-franc","between-horizontal-end","file-braces-corner","rotate-cw","house-plus","bus-front","shield-ellipsis","between-vertical-end","globe-lock","tags","concierge-bell","bookmark-minus","file-down","picture-in-picture","messages-square","scissors","file-check-corner","phone-call","anchor","hand-helping","text-wrap","birdhouse","wifi-off","cloud-alert","message-square","cloud-download","folder-plus","cctv-off","mirror-round","user-round","pointer","between-horizontal-start","chevrons-up-down","brush","message-circle-more","parentheses","book-up-2","flame","chevrons-up","square-dashed","square-mouse-pointer","superscript","signal","wifi-cog","hexagon","navigation-2-off","eye-off","arrows-up-from-line","file-code-corner","square-centerline-dashed-horizontal","panels-right-bottom","scaling","hash","arrow-left-from-line","ship","ticket-percent","calendar-clock","x","non-binary","voicemail","presentation","tree-palm","badge","captions-off","align-vertical-justify-center","download","mouse-right","lens-convex","focus","diamond-percent","arrow-big-up","volume-x","mouse-pointer-click","origami","hard-drive","grid-2x2-x","package-minus","cloud","pipette","corner-left-down","badge-cent","cloud-lightning","user-round-pen","arrow-left-to-line","book-open-text","monitor-cloud","parking-meter","cat","heart-handshake","dam","trees","ham","circle-pause","chess-king","bean-off","rat","separator-horizontal","ambulance","signal-zero","citrus","phone-missed","calendar-off","chart-column","battery-medium","square-minus","star-check","decimals-arrow-left","folder-output","menu","image-down","terminal","angry","circle-dot-dashed","medal","cake-slice","git-graph","armchair","tickets","qr-code","copy","goal","trending-down","creative-commons","ev-charger","user-star","road","nfc","align-center-horizontal","car","notebook-tabs","ear","videotape","sun-moon","chart-scatter","podium","toolbox","calendar","calendar-cog","gallery-horizontal","clipboard-x","list-sort-ascending","book-open","circle-pile","rectangle-ellipsis","badge-plus","badge-info","file-headphone","bow-arrow","clipboard-pen-line","user-round-key","folder-search","utensils-crossed","arrow-up","arrow-up-from-dot","align-vertical-justify-start","layers-minus","pause","shrub","flag","biceps-flexed","align-horizontal-distribute-end","donut","calendar-plus-2","move-vertical","file-pen-line","badge-russian-ruble","radius","pilcrow","corner-left-up","georgian-lari","cable","book-user","square-arrow-down","circle-plus","view","cctv","circle-arrow-left","square-off","octagon-alert","panel-bottom-dashed","book-a","align-end-vertical","thumbs-up","globe","rabbit","layers-plus","banknote-arrow-down","message-square-off","dice-4","message-circle-x","folder-x","message-circle-warning","map","move","arrow-up-left","award","arrow-down-wide-narrow","unfold-horizontal","lens-concave","motorbike","music-4","shield-x","file-volume","disc-3","file-signal","columns-4","archive-x","square-dashed-kanban","mouse-pointer-2","clock-arrow-up","clock-fading","pencil-sparkles","vegan","star-plus","message-circle-plus","fast-forward","user-pen","chess-knight","wifi-pen","files","send-to-back","alarm-clock","shopping-basket","send","brush-cleaning","skip-back","book-audio","file-scan","message-square-dashed","chevrons-left","umbrella","skip-forward","clipboard-copy","map-pin-off","arrow-up-from-line","circle-chevron-up","circle-small","align-vertical-space-between","lamp-desk","circle-arrow-up","zap","beaker","paintbrush","broccoli","chevron-up","pen-tool","database-check","form","pencil-ruler","dna","arrow-big-down-dash","chart-area","bug-off","card-sim","map-pin-search","eye-dashed","ellipse","spell-check","popcorn","blocks","washing-machine","microchip","badge-minus","cloud-sun","circle","shield-alert","map-minus","separator-vertical","scan-square","ampersands","user-search","fence","square-user-round","sunrise","strikethrough","calendar-days","folder-bookmark","banknote-arrow-up","dollar-sign","message-square-quote","list-minus","cloud-hail","eye-closed","app-window-mac","ellipsis","copy-check","satellite","bookmark-plus","folder-key","coffee","circle-power","hourglass","tickets-plane","folder-git","bomb","layers-2","battery-full","user-minus","chart-gantt","folder-tree","command","badge-dollar-sign","align-start-vertical","briefcase-conveyor-belt","message-circle-question-mark","bluetooth-off","square-square","cannabis","book","grip-horizontal","circle-minus","audio-waveform","moon-star","arrow-down-narrow-wide","database-backup","wand","receipt-turkish-lira","calendar-minus-2","copy-minus","folder-input","book-image","mouse-left","tag-plus","shirt","server-off","move-up","plug-2","chess-rook","brackets","calendar-heart","list-ordered","star-x","mic-off","arrow-big-left","square-split-horizontal","clover","sun-snow","sofa","funnel-x","clock-2","calendar-fold","fish-off","baby","database-x","fold-vertical","hop","paperclip","cigarette","minus","smile-plus","diamond-plus","file-chart-column","triangle-dashed","git-pull-request-closed","badge-check","zoom-out","zoom-in","zodiac-virgo","plug-zap","heading-4","chess-queen","graduation-cap","grid-3x2","zodiac-sagittarius","list-music","square-dashed-bottom-code","clock-7","ethernet-port","scan-text","file-up","shower-head","equal-not","zodiac-pisces","move-down","clock-arrow-down","ticket-slash","ruler","tornado","zodiac-libra","circle-user-round","zodiac-leo","zodiac-gemini","list-filter","map-pin-check","egg-off","square-kanban","cog","dog","folder-closed","swords","spotlight","panel-right-dashed","zodiac-aries","paper-bag","truck-electric","zodiac-aquarius","check-line","save","bubbles","bot","chart-bar-increasing","x-line-top","trash-2","air-vent","swiss-franc","dot","sprout","worm","file-symlink","clipboard-paste","chevron-last","book-heart","workflow","circle-parking","globe-check","cloud-check","panel-left","circle-chevron-right","wine-off","wine","squares-unite","arrow-down-up","git-fork","forward","brain-circuit","between-vertical-start","database","panel-right","wind-arrow-down","message-square-diff","popsicle","log-out","git-branch-plus","clipboard-minus","file-text","wifi-sync","bell-off","wifi-high","table-rows-split","milk-off","tv-minimal","cloud-upload","banknote","wifi","webcam-off","drumstick","wheat-off","calendar-search","wheat","weight-tilde","bell-ring","circle-chevron-left","weight","arrow-down","arrow-up-down","folder-dot","fingerprint-pattern","folder-up","whole-word","monitor","disc-2","trending-up-down","webcam","user-shield","waypoints","tv-minimal-play","circle-stop","align-vertical-space-around","waves-vertical","waves-ladder","waves-horizontal","arrow-big-down","circle-parking-off","calendar-x-2","user-plus","move-diagonal-2","bandage","gallery-horizontal-end","panel-top-dashed","octagon-minus","waves-arrow-down","tram-front","watch","indian-rupee","wand-sparkles","audio-lines","wallpaper","wallet-minimal","wallet-cards","flip-vertical-2","rocket","wallet","ear-off","vote","save-check","volume-off","shield-half","printer","megaphone-off","volume-1","arrow-big-right","section","file-clock","volume","toy-brick","square-chevron-down","dice-1","drill","app-window","shield-check","hand-metal","volleyball","spell-check-2","umbrella-off","video","list-plus","sun-dim","rotate-ccw-key","vibrate","chart-pie","venus-and-mars","cloud-backup","copy-slash","wind","vault","layout-panel-left","badge-x","circle-percent","van","circle-arrow-out-down-right","square-x","italic","chart-column-increasing","utility-pole","step-forward","utensils","a-arrow-down","container","sticker","users-round","users","user-x","user-round-x","user-round-search","log-in","import","badge-turkish-lira","square-terminal","file-music","mic-vocal","beef","route-off","file-user","user-round-cog","square-radical","user-round-check","image-upscale","book-type","smile","signpost-big","user-round-arrow-left","cloudy","user-lock","square-percent","user-key","navigation-off","arrow-left","car-taxi-front","square-play","sparkle","chevrons-right-left","user","map-pin-plus","upload","unplug","square-code","unlink","university","square-pause","align-end-horizontal","ungroup","equal","megaphone","calendar-x","unfold-vertical","lamp-ceiling","egg","undo-2","undo","underline","circle-pound-sterling","video-off","japanese-yen","type-outline","fuel","file-search-corner","library","file-terminal","circle-chevron-down","accessibility","folder-lock","square-library","amphora","turntable","tally-2","turkish-lira","truck","trophy","gamepad-directional","sheet","circle-check-big","triangle-alert","triangle","map-pinned","corner-down-left","circuit-board","trending-up","train-front-tunnel","tree-deciduous","school","folder-open-dot","book-dashed","transgender","chevron-left","bluetooth","tree-pine","receipt-indian-rupee","monitor-stop","traffic-cone","tractor","tower-control","replace-all","touchpad-off","flask-conical","touchpad","funnel","square-star","folder-sync","torus","zodiac-ophiuchus","tool-case","toilet","arrow-up-narrow-wide","fishing-hook","text-quote","toggle-left","timer-reset","frame","calendar-arrow-down","clock-12","star-minus","radar","timer","images","lollipop","book-text","timeline","lamp-floor","file-plus-corner","image","ticket-x","badge-euro","bike","squares-exclude","list-checks","send-horizontal","dices","panel-left-dashed","thermometer-sun","thermometer-snowflake","option","banknote-check","scroll-text","server-plus","thermometer","theater","message-circle-off","toggle-right","pc-case","ferris-wheel","camera-off","text-cursor-input","text-cursor","info","text-align-justify","text-align-end","group","text-align-center","battery","test-tubes","tent-tree","test-tube-diagonal","rectangle-horizontal","bug","tent","telescope","bitcoin","lamp","battery-plus","database-search","tangent","file-diff","phone-off","link","tally-3","spline-pointer","circle-alert","axis-3d","shell","tag","binoculars","tablets","tablet-smartphone","screen-share","rose","table-properties","mail-minus","table-of-contents","table-columns-split","table-cells-merge","table-2","clipboard-pen","bottle-wine","alarm-clock-off","table","list","syringe","square-arrow-right","rotate-ccw-clock","badge-pound-sterling","bookmark-check","switch-camera","wrench-off","square-arrow-out-down-left","a-arrow-up","clock-check","sunset","sun-medium","vibrate-off","mail-check","zodiac-cancer","file-chart-column-increasing","file-code","subscript","chart-column-big","stretch-vertical","stretch-horizontal","cassette-tape","battery-low","monitor-pause","stone","signpost","image-plus","calendar-arrow-up","landmark","fish-symbol","sticky-note-x","loader","bold","dice-2","file-type","clipboard-clock","beer","lectern","chart-bar-stacked","file-check","git-pull-request-create","binary","move-diagonal","sticky-note-check","door-closed","sticky-note","layout-template","stethoscope","step-back","star-off","bookmark-off","hand-heart","scroll","scan-qr-code","message-square-check","star","stamp","squirrel","brain","folder","squircle","snail","key","clock-11","earth-lock","ticket-plus","arrow-up-0-1","bell-electric","square-user","heading","book-open-check","panel-top-close","lasso-select","move-left","square-stack","square-split-vertical","square-slash","bus","square-sigma","bed-single","chart-no-axes-gantt","file-spreadsheet","square-scissors","clipboard-list","square-round-corner","contact-round","leaf","keyboard-off","square-plus","file-badge","battery-warning","mail-question-mark","arrow-down-from-line","briefcase","biohazard","rectangle-circle","braces","scale-3d","panel-top-bottom-dashed","mail-x","square-dashed-mouse-pointer","user-cog","lock-open","square-pilcrow","pizza","list-indent-decrease","arrow-up-wide-narrow","square-pi","clock-5","mouse-pointer","rotate-ccw","align-horizontal-justify-center","database-arrow-down","antenna","memory-stick","scan-eye","square-parking","square-check","heart-plus","receipt-russian-ruble","map-pin-minus-inside","git-merge","gallery-vertical-end","square-m","hand-coins","zodiac-capricorn","wifi-low","square-equal","clock","file-pen","git-compare-arrows","cloud-sun-rain","align-horizontal-justify-start","square-dot","square-divide","square-arrow-right-enter","calendar-plus","square-bottom-dashed-scissors","arrow-down-z-a","bath","square-dashed-bottom","unlink-2","square-chevron-up","pin","folder-check","square-chevron-left","book-key","ribbon","microwave","saudi-riyal","gallery-vertical","square-chart-gantt","square-centerline-dashed-vertical","square-dashed-text","map-pin-pen","move-up-left","square-asterisk","folder-heart","square-arrow-up-right","shield-cog-corner","circle-play","arrow-up-a-z","square-arrow-right-exit","square-dashed-top-solid","square-arrow-out-up-right","square-arrow-out-up-left","circle-ellipsis","swatch-book","receipt-cent","spool","folder-archive","folder-symlink","columns-3","ban","message-square-x","paint-roller","soup","archive","square-arrow-down-right","construction","building-2","circle-slash-2","package","cake","cloud-rain","chart-bar","square","wrench","spray-can","sport-shoe","smartphone","flag-triangle-right","receipt-euro","speech","bell","speaker","sparkles","music-3","chart-bar-big","user-check","proportions","spade","plane","webhook-off","carrot","square-arrow-left","file-cog","circle-dashed","solar-panel","soap-dispenser-droplet","snowflake","mailbox","squares-subtract","smartphone-nfc","chevrons-left-right-ellipsis","split","list-sort-descending","sliders-vertical","forklift","sliders-horizontal","alarm-clock-minus","heart-x","eraser","book-marked","package-search","bluetooth-connected","rotate-ccw-square","chart-no-axes-column","cannabis-off","folder-kanban","message-square-plus","mars-stroke","skull","siren","signature","file-box","signal-medium","paint-bucket","glass-water","signal-low","glasses","piggy-bank","maximize-2","cuboid","cloud-off","check-check","activity","axe","plane-takeoff","sigma","cloud-rain-wind","flower","expand","copy-x","file-axis-3d","radical","chart-column-decreasing","shrimp","bug-play","align-vertical-distribute-start","highlighter","waves-arrow-up","tally-5","shopping-bag","ship-wheel","shield-user","circle-divide","shield-question-mark","shield-plus","shield-off","life-buoy","hard-hat","shield-keyhole","volume-2","battery-charging","russian-ruble","square-arrow-up-left","brick-wall-shield","footprints","shield-cog","building","shield-ban","shield","shelving-unit","tag-x","book-alert","link-2","astroid","bell-minus","image-up","closed-caption","drum","arrow-up-z-a","sun","share","shapes","file-key","settings-2","settings","scissors-line-dashed","server-crash","server-cog","server","ticket-check","combine","search-x","search-slash","mountain","mars","picture-in-picture-2","radio-off","flower-2","search-code","squares-intersect","search-alert","search","keyboard-music","star-half","screen-share-off","code-xml","pencil-line","mails","brain-cog","tablet","loader-circle","pi","trash","book-down","hdmi-port","scan-search","case-upper","circle-fading-arrow-up","redo","croissant","move-down-right","scan-face","barcode","scan-box","scan-barcode","bed","scan","divide","grape","remove-formatting","party-popper","file-chart-pie","save-plus","file-braces","dice-6","save-off","blender","image-minus","zap-off","square-check-big","satellite-dish","sandwich","salad","laptop-minimal","sailboat","monitor-check","map-pin-minus","file-minus-corner","chart-spline","message-square-more","rows-4","chart-candlestick","rows-3","arrow-down-a-z","rows-2","router","move-horizontal","file-sliders","frown","route","cup-soda","rewind","rotate-cw-fading-clock","sword","rotate-3d","roller-coaster","earth","slice","dice-3","milk","mouse-pointer-ban","crown","circle-slash","circle-star","rotate-cw-square","atom","package-x","bed-double","list-chevrons-up-down","circle-dot","file-exclamation-point","hand-fist","message-circle-code","folder-git-2","message-square-code","reply","towel-rack","replace","arrow-big-left-dash","repeat-off","dumbbell","repeat-2","repeat-1","repeat","scale","regex","flashlight","panel-top-open","refrigerator","refresh-cw-off","notebook","redo-2","refresh-cw","square-menu","brick-wall","monitor-smartphone","laptop","scan-line","clock-4","square-arrow-up","book-minus","file-question-mark","rectangle-vertical","rectangle-goggles","save-pen","arrow-down-to-line","receipt-swiss-franc","refresh-ccw","venetian-mask","calendar-check-2","receipt-japanese-yen","spline","banknote-x","git-pull-request-create-arrow","pound-sterling","circle-check","ratio","rainbow","phone","radio-receiver","radio","radiation","timer-off","arrow-big-right-dash","quote","pyramid","puzzle","backpack","projector","list-check","printer-check","power-off","mic-signal","arrow-down-right","power","receipt","wifi-zero","folder-minus","list-collapse","plus","plug","image-off","play-off","play","plane-landing","pin-off","square-chevron-right","mail-search","pill","bone-fracture","microscope","pilcrow-left","pickaxe","piano","tally-1","ampersand","ad","shopping-cart","align-vertical-justify-end","phone-incoming","alarm-smoke","phone-forwarded","file-input","clock-8","hand-grab","cloud-cog","blend","hd","radio-tower","list-tree","droplet","grid-2x2","eye","phi","percent","banana","gpu","pentagon","pencil-off","circle-equal","delete","pen-off","pen-line","headset","text-initial","arrow-up-right","move-right","leafy-green","message-square-dot","file-chart-line","columns-3-cog","parasol","calendar-minus","minimize-2","panels-left-bottom","panel-top","cone","panel-right-open","file-image","panel-right-close","palette","barrel","gallery-thumbnails","panel-left-right-dashed","cpu","panel-left-open","thumbs-down","merge","hamburger","bird","hat-glasses","code","helicopter","panel-bottom-close","panel-bottom","panda","file-video-camera","paintbrush-vertical","kanban","bone","apple","rocking-chair","bot-off","package-plus","package-open","diameter","circle-arrow-out-up-left","package-2","cable-car","arrow-down-left","square-activity","orbit","cigarette-off","omega","message-circle","circle-arrow-out-up-right","locate-fixed","octagon-pause","fold-horizontal","shovel","calendar-1","cloud-moon","square-arrow-out-down-right","nut-off","clock-plus","circle-euro","cloud-snow","anvil","arrow-big-up-dash","nut","notepad-text-dashed","notepad-text","list-video","monitor-off","newspaper","chevrons-down-up","clipboard-plus","circle-x","list-end","network","navigation-2","chevrons-right","navigation","message-square-reply","corner-down-right","music-2","summary","lamp-wall-down","move-up-right","paw-print","ellipsis-vertical","globe-off","square-stop","arrow-up-1-0","align-horizontal-justify-end","scan-heart","align-vertical-distribute-end","heart-crack","airplay","move-down-left","move-3d","message-square-share","monitor-x","bell-check","database-minus","square-pen","mouse-off","lasso","dice-5","octagon","ticket","moon","monitor-up","train-front","bookmark","monitor-speaker","album","monitor-play","chart-bar-decreasing","database-plus","calendar-sync","funnel-plus","store","circle-arrow-down","notebook-pen","egg-fried","message-circle-heart","monitor-dot","corner-right-up","monitor-cog","ruler-dimension-line","user-round-plus","panel-left-close","milestone","pilcrow-right","user-round-minus","mic-audio-lines","mic","mail-plus","case-sensitive","message-square-warning","message-square-text","mouse-pointer-2-off","drone","slash","message-square-lock","aperture","arrow-right-left","message-square-heart","vector-square","circle-gauge","gem","check","text-search","arrow-down-to-dot","monitor-down","message-circle-dashed","chef-hat","message-circle-check","meh","file-archive","signal-high","inbox","flip-horizontal-2","maximize","image-play","align-horizontal-space-between","kayak","calendar-check","database-zap","droplets","calendar-range","map-pin-x-inside","map-pin-x","layout-list","file-search","heart","alarm-clock-plus","circle-dollar-sign","usb","house","receipt-pound-sterling","file-digit","map-pin","id-card","mouse","minimize","mail","magnet","circle-arrow-right","logs","book-x","mirror-rectangular","lock-keyhole-open","lock-keyhole","lock","headphone-off","asterisk","calculator","octagon-x","languages","locate","alarm-clock-check","guitar","loader-pinwheel","beer-off","scooter","square-parking-off","notebook-text","arrow-right-to-line","ticket-minus","tally-4","zodiac-taurus","list-indent-increase","door-open","flag-triangle-left","grid-3x3","file","keyboard","pocket-knife","book-copy","castle","car-front","clock-alert","reply-all","cloud-moon-rain","clipboard-type","list-chevrons-down-up","list-todo","printer-x","link-2-off","list-start","line-style","a-large-small","line-squiggle","line-dot-right-horizontal","map-plus","lightbulb","ligature","library-big","database-arrow-up","arrow-right-from-line","flame-kindling","square-power","layout-panel-top","bring-to-front","layout-grid","layout-freeform","bell-plus","layout-dashboard","layers","laugh","folders","mail-warning","book-plus","land-plot","lamp-wall-up","chevrons-left-right","chart-line","file-lock","cast","circle-fading-plus","clock-10","undo-dot","target","list-filter-plus","key-square","drama","file-type-corner","baseline","martini","contrast","joystick","candy-off","iteration-cw","book-check","iteration-ccw","book-lock","inspection-panel","briefcase-medical","calendars","text-align-start","infinity","hop-off","warehouse","sticky-notes","drafting-compass","save-all","id-card-lanyard","ice-cream-cone","ice-cream-bowl","house-wifi","house-plug","fishing-rod","book-headphones","credit-card","house-heart","hotel","hospital","shredder","panel-bottom-open","heart-pulse","heart-off","heart-minus","balloon","map-pin-plus-inside","bookmark-x","badge-question-mark","pen","file-stack","candy-cane","heading-6","heading-5","gamepad-2","heading-3","heading-2","heading-1","haze","shield-minus","circle-off","dessert","eclipse","church","hard-drive-upload","cylinder","badge-japanese-yen","hard-drive-download","receipt-text","handbag","hand-platter","hand","hammer","file-output","disc-album","grip","arrow-down-0-1","captions","flashlight-off","grid-2x2-check","philippine-peso","badge-alert","globe-x","folder-pen","cross","git-pull-request-draft","chevron-right","sticky-note-minus","square-arrow-down-left","share-2","git-merge-conflict","git-compare","git-commit-vertical","git-commit-horizontal","clipboard","git-branch","chess-pawn","gift","briefcase-business","ghost","message-circle-reply","gauge","triangle-right","folder-clock","gamepad","fullscreen","type","webhook","folder-search-2","align-horizontal-distribute-start","folder-root","folder-open","pointer-off","turtle","camera","compass","folder-cog","git-pull-request","bluetooth-searching","arrow-up-to-line","squircle-dashed","clock-3","badge-percent","shuffle","flask-round","flask-conical-off","grid-2x2-plus","flag-off","box","fish","clock-1","file-heart","fire-extinguisher","space","film","file-x-corner","file-x","corner-up-left","clock-6","zodiac-scorpio","key-round","headphones","tv","contact","file-play","rss","file-minus","at-sign","map-pin-check-inside","sticky-note-off","music","handshake","fan","circle-user","copy-plus","factory","external-link","shrink","euro","equal-approximately","search-check","clipboard-check","columns-2","droplet-off","cloud-sync","align-center-vertical","dock","disc","diff","cloud-fog","mosque","diamond-minus","map-pin-house","package-check","chevron-first","pencil","component","list-x","currency","crosshair","corner-up-right","crop","clock-arrow-left","corner-right-down","copyright","badge-indian-rupee","copyleft","redo-dot","cookie","align-start-horizontal","chart-column-stacked","file-plus","git-pull-request-arrow","computer","decimals-arrow-right","bell-dot","folder-down","coins","club","align-horizontal-space-around","door-closed-locked","cloud-drizzle","diamond","blinds","clock-arrow-right","clock-9","book-search","git-branch-minus","clapperboard","recycle","mountain-snow","luggage","circle-arrow-out-down-left","bot-message-square","phone-outgoing","smartphone-charging","chevrons-down","train-track","chess-bishop","cherry","sticky-note-plus","chart-no-axes-column-increasing","chart-no-axes-column-decreasing","chart-network","chart-no-axes-combined","metronome","case-lower","arrow-down-1-0","caravan","candy","arrow-left-right","lightbulb-off","panels-top-left","beef-off","locate-off","annoyed","test-tube","brick-wall-fire","cooking-pot","boxes","boom-box","book-up","laptop-minimal-check","mail-open","square-function","baggage-claim","variable","arrow-right","archive-restore"},{if getcustomasset and not IS_GETCUSTOMASSET_BROKEN then getcustomasset("lucide-icons/1.png") else "rbxassetid://122605056588923",if getcustomasset and not IS_GETCUSTOMASSET_BROKEN then getcustomasset("lucide-icons/2.png") else "rbxassetid://87013611700945"},{[48]={{1,{24,24},{150,25}},{1,{24,24},{275,350}},{1,{24,24},{400,650}},{1,{24,24},{975,725}},{1,{24,24},{175,750}},{1,{24,24},{300,500}},{1,{24,24},{450,850}},{2,{24,24},{200,100}},{1,{24,24},{75,325}},{1,{24,24},{275,400}},{1,{24,24},{400,500}},{1,{24,24},{75,375}},{1,{24,24},{50,925}},{1,{24,24},{825,25}},{1,{24,24},{25,100}},{1,{24,24},{150,800}},{1,{24,24},{650,600}},{1,{24,24},{375,850}},{1,{24,24},{325,50}},{1,{24,24},{125,300}},{1,{24,24},{650,200}},{1,{24,24},{400,925}},{1,{24,24},{775,225}},{1,{24,24},{0,525}},{1,{24,24},{975,450}},{1,{24,24},{75,350}},{1,{24,24},{525,425}},{1,{24,24},{950,775}},{1,{24,24},{425,325}},{1,{24,24},{325,175}},{1,{24,24},{300,550}},{1,{24,24},{775,475}},{1,{24,24},{750,375}},{1,{24,24},{700,675}},{1,{24,24},{500,350}},{1,{24,24},{300,925}},{1,{24,24},{75,125}},{1,{24,24},{875,100}},{1,{24,24},{825,950}},{1,{24,24},{350,100}},{2,{24,24},{275,100}},{1,{24,24},{575,150}},{1,{24,24},{775,350}},{1,{24,24},{475,250}},{1,{24,24},{0,900}},{1,{24,24},{525,75}},{1,{24,24},{325,800}},{2,{24,24},{25,225}},{1,{24,24},{925,350}},{1,{24,24},{100,325}},{1,{24,24},{625,25}},{1,{24,24},{175,350}},{1,{24,24},{500,600}},{1,{24,24},{800,425}},{1,{24,24},{475,25}},{1,{24,24},{850,50}},{1,{24,24},{600,50}},{1,{24,24},{975,575}},{1,{24,24},{725,825}},{1,{24,24},{900,775}},{1,{24,24},{825,625}},{2,{24,24},{350,25}},{1,{24,24},{0,975}},{1,{24,24},{800,375}},{1,{24,24},{75,750}},{1,{24,24},{200,125}},{1,{24,24},{425,425}},{1,{24,24},{925,600}},{1,{24,24},{925,300}},{1,{24,24},{425,925}},{1,{24,24},{625,350}},{1,{24,24},{50,225}},{1,{24,24},{700,725}},{1,{24,24},{975,850}},{1,{24,24},{275,275}},{2,{24,24},{350,50}},{1,{24,24},{625,550}},{2,{24,24},{25,275}},{1,{24,24},{775,500}},{2,{24,24},{50,50}},{1,{24,24},{250,125}},{1,{24,24},{275,300}},{1,{24,24},{75,100}},{1,{24,24},{50,750}},{1,{24,24},{475,675}},{1,{24,24},{125,900}},{1,{24,24},{600,300}},{1,{24,24},{700,100}},{1,{24,24},{100,150}},{2,{24,24},{250,75}},{1,{24,24},{525,625}},{1,{24,24},{200,975}},{1,{24,24},{675,300}},{1,{24,24},{275,675}},{1,{24,24},{925,275}},{1,{24,24},{100,625}},{1,{24,24},{550,700}},{1,{24,24},{750,25}},{1,{24,24},{250,100}},{1,{24,24},{375,350}},{2,{24,24},{125,125}},{1,{24,24},{0,275}},{1,{24,24},{100,375}},{1,{24,24},{275,850}},{1,{24,24},{775,450}},{1,{24,24},{550,50}},{1,{24,24},{225,750}},{1,{24,24},{300,475}},{2,{24,24},{0,100}},{1,{24,24},{50,900}},{1,{24,24},{450,225}},{1,{24,24},{400,225}},{1,{24,24},{100,300}},{1,{24,24},{975,325}},{1,{24,24},{900,500}},{1,{24,24},{175,25}},{1,{24,24},{850,600}},{1,{24,24},{0,675}},{1,{24,24},{975,275}},{1,{24,24},{100,450}},{1,{24,24},{200,400}},{1,{24,24},{225,175}},{1,{24,24},{750,800}},{1,{24,24},{650,950}},{1,{24,24},{25,750}},{1,{24,24},{50,850}},{1,{24,24},{650,450}},{1,{24,24},{600,400}},{1,{24,24},{925,825}},{1,{24,24},{50,150}},{1,{24,24},{50,600}},{1,{24,24},{775,325}},{1,{24,24},{475,75}},{1,{24,24},{825,125}},{1,{24,24},{25,200}},{1,{24,24},{975,875}},{1,{24,24},{575,700}},{1,{24,24},{75,675}},{1,{24,24},{425,525}},{2,{24,24},{125,0}},{1,{24,24},{575,200}},{1,{24,24},{200,625}},{2,{24,24},{250,25}},{1,{24,24},{700,625}},{1,{24,24},{650,525}},{1,{24,24},{125,0}},{1,{24,24},{175,400}},{1,{24,24},{575,600}},{1,{24,24},{600,225}},{2,{24,24},{75,225}},{1,{24,24},{700,950}},{1,{24,24},{600,25}},{1,{24,24},{975,300}},{1,{24,24},{975,925}},{1,{24,24},{500,75}},{1,{24,24},{250,300}},{1,{24,24},{375,550}},{1,{24,24},{425,275}},{1,{24,24},{375,675}},{1,{24,24},{75,400}},{1,{24,24},{400,275}},{1,{24,24},{650,650}},{1,{24,24},{25,325}},{1,{24,24},{125,225}},{1,{24,24},{250,600}},{1,{24,24},{75,425}},{1,{24,24},{525,175}},{2,{24,24},{175,75}},{1,{24,24},{875,50}},{2,{24,24},{125,150}},{1,{24,24},{225,100}},{1,{24,24},{75,225}},{1,{24,24},{25,150}},{1,{24,24},{475,550}},{1,{24,24},{725,500}},{1,{24,24},{450,975}},{1,{24,24},{900,0}},{1,{24,24},{25,400}},{1,{24,24},{0,125}},{1,{24,24},{175,625}},{1,{24,24},{75,475}},{1,{24,24},{950,225}},{1,{24,24},{0,850}},{1,{24,24},{350,25}},{1,{24,24},{325,950}},{1,{24,24},{675,575}},{1,{24,24},{725,50}},{1,{24,24},{125,800}},{1,{24,24},{500,50}},{1,{24,24},{425,75}},{1,{24,24},{800,700}},{1,{24,24},{350,325}},{2,{24,24},{50,250}},{1,{24,24},{500,100}},{1,{24,24},{450,200}},{1,{24,24},{700,850}},{1,{24,24},{400,775}},{1,{24,24},{600,600}},{1,{24,24},{475,0}},{1,{24,24},{50,75}},{1,{24,24},{875,925}},{1,{24,24},{450,500}},{1,{24,24},{525,750}},{1,{24,24},{450,575}},{1,{24,24},{100,275}},{1,{24,24},{975,150}},{1,{24,24},{550,250}},{1,{24,24},{350,750}},{1,{24,24},{750,175}},{1,{24,24},{375,725}},{1,{24,24},{925,175}},{1,{24,24},{925,250}},{1,{24,24},{25,275}},{1,{24,24},{25,300}},{1,{24,24},{125,150}},{2,{24,24},{125,75}},{1,{24,24},{150,875}},{1,{24,24},{725,425}},{1,{24,24},{850,325}},{1,{24,24},{775,650}},{1,{24,24},{375,500}},{1,{24,24},{400,400}},{1,{24,24},{675,200}},{1,{24,24},{575,175}},{1,{24,24},{75,150}},{1,{24,24},{625,900}},{1,{24,24},{575,575}},{1,{24,24},{725,0}},{1,{24,24},{675,50}},{1,{24,24},{475,750}},{2,{24,24},{275,25}},{1,{24,24},{925,700}},{1,{24,24},{450,650}},{1,{24,24},{850,0}},{2,{24,24},{25,200}},{1,{24,24},{375,250}},{2,{24,24},{250,125}},{1,{24,24},{275,600}},{1,{24,24},{950,450}},{1,{24,24},{50,50}},{1,{24,24},{625,800}},{1,{24,24},{925,475}},{1,{24,24},{200,325}},{1,{24,24},{700,750}},{1,{24,24},{425,50}},{1,{24,24},{750,125}},{1,{24,24},{250,850}},{1,{24,24},{25,600}},{2,{24,24},{25,150}},{1,{24,24},{675,775}},{1,{24,24},{625,75}},{1,{24,24},{275,800}},{1,{24,24},{50,250}},{1,{24,24},{150,500}},{1,{24,24},{200,475}},{1,{24,24},{200,0}},{1,{24,24},{850,175}},{1,{24,24},{300,350}},{2,{24,24},{300,100}},{1,{24,24},{125,275}},{1,{24,24},{700,500}},{1,{24,24},{225,300}},{1,{24,24},{150,475}},{1,{24,24},{600,625}},{1,{24,24},{200,575}},{1,{24,24},{625,300}},{1,{24,24},{500,725}},{1,{24,24},{275,525}},{1,{24,24},{0,225}},{1,{24,24},{475,125}},{1,{24,24},{125,400}},{1,{24,24},{125,450}},{1,{24,24},{175,900}},{1,{24,24},{100,725}},{1,{24,24},{425,400}},{1,{24,24},{600,875}},{1,{24,24},{900,375}},{1,{24,24},{225,225}},{2,{24,24},{0,325}},{1,{24,24},{575,550}},{1,{24,24},{75,275}},{1,{24,24},{175,550}},{1,{24,24},{50,625}},{1,{24,24},{525,875}},{1,{24,24},{425,650}},{1,{24,24},{875,525}},{1,{24,24},{825,550}},{1,{24,24},{125,75}},{2,{24,24},{0,250}},{1,{24,24},{800,50}},{1,{24,24},{950,650}},{1,{24,24},{950,725}},{1,{24,24},{825,825}},{1,{24,24},{225,325}},{1,{24,24},{500,400}},{1,{24,24},{75,300}},{1,{24,24},{200,600}},{1,{24,24},{925,200}},{1,{24,24},{500,550}},{1,{24,24},{400,325}},{1,{24,24},{125,700}},{1,{24,24},{175,50}},{1,{24,24},{375,450}},{1,{24,24},{200,550}},{1,{24,24},{675,675}},{1,{24,24},{275,225}},{1,{24,24},{175,725}},{1,{24,24},{725,25}},{1,{24,24},{300,375}},{1,{24,24},{850,150}},{1,{24,24},{850,975}},{1,{24,24},{275,625}},{1,{24,24},{50,400}},{1,{24,24},{500,525}},{1,{24,24},{275,125}},{2,{24,24},{50,175}},{1,{24,24},{175,425}},{1,{24,24},{800,125}},{1,{24,24},{525,225}},{1,{24,24},{200,150}},{1,{24,24},{175,0}},{1,{24,24},{325,200}},{1,{24,24},{425,675}},{1,{24,24},{175,275}},{1,{24,24},{675,900}},{1,{24,24},{300,275}},{1,{24,24},{375,125}},{1,{24,24},{175,775}},{1,{24,24},{550,125}},{1,{24,24},{50,275}},{1,{24,24},{800,350}},{1,{24,24},{250,25}},{1,{24,24},{225,550}},{2,{24,24},{50,275}},{1,{24,24},{725,575}},{1,{24,24},{150,400}},{1,{24,24},{175,575}},{1,{24,24},{225,675}},{1,{24,24},{250,225}},{1,{24,24},{650,500}},{1,{24,24},{750,950}},{1,{24,24},{675,750}},{1,{24,24},{800,600}},{1,{24,24},{975,200}},{1,{24,24},{375,875}},{1,{24,24},{300,325}},{1,{24,24},{525,0}},{1,{24,24},{175,375}},{1,{24,24},{450,600}},{1,{24,24},{900,725}},{1,{24,24},{675,450}},{1,{24,24},{200,50}},{1,{24,24},{725,850}},{1,{24,24},{50,675}},{1,{24,24},{675,975}},{1,{24,24},{850,625}},{1,{24,24},{450,475}},{1,{24,24},{275,425}},{1,{24,24},{200,350}},{1,{24,24},{175,700}},{1,{24,24},{325,25}},{1,{24,24},{100,675}},{1,{24,24},{550,350}},{1,{24,24},{925,75}},{1,{24,24},{850,375}},{1,{24,24},{525,125}},{1,{24,24},{375,750}},{1,{24,24},{975,500}},{1,{24,24},{675,125}},{1,{24,24},{575,275}},{2,{24,24},{25,100}},{1,{24,24},{725,225}},{1,{24,24},{225,125}},{2,{24,24},{375,50}},{2,{24,24},{400,25}},{2,{24,24},{425,0}},{1,{24,24},{350,900}},{1,{24,24},{425,550}},{1,{24,24},{325,300}},{1,{24,24},{375,575}},{1,{24,24},{225,725}},{2,{24,24},{50,350}},{1,{24,24},{475,575}},{1,{24,24},{675,850}},{1,{24,24},{150,550}},{1,{24,24},{250,575}},{1,{24,24},{800,575}},{1,{24,24},{450,425}},{1,{24,24},{550,875}},{1,{24,24},{325,500}},{2,{24,24},{75,325}},{1,{24,24},{300,850}},{1,{24,24},{50,650}},{1,{24,24},{925,900}},{1,{24,24},{825,525}},{1,{24,24},{950,950}},{2,{24,24},{125,275}},{1,{24,24},{125,550}},{2,{24,24},{150,250}},{2,{24,24},{175,225}},{1,{24,24},{575,475}},{1,{24,24},{375,700}},{1,{24,24},{475,350}},{1,{24,24},{850,700}},{1,{24,24},{700,50}},{1,{24,24},{225,575}},{1,{24,24},{425,475}},{1,{24,24},{775,900}},{1,{24,24},{950,550}},{1,{24,24},{375,825}},{2,{24,24},{250,150}},{1,{24,24},{875,350}},{2,{24,24},{100,50}},{2,{24,24},{275,125}},{1,{24,24},{525,100}},{1,{24,24},{500,850}},{1,{24,24},{150,375}},{1,{24,24},{125,375}},{1,{24,24},{400,200}},{2,{24,24},{375,25}},{2,{24,24},{0,75}},{1,{24,24},{75,0}},{1,{24,24},{850,825}},{1,{24,24},{75,725}},{1,{24,24},{900,600}},{2,{24,24},{25,350}},{1,{24,24},{575,300}},{1,{24,24},{550,150}},{1,{24,24},{225,400}},{1,{24,24},{275,200}},{2,{24,24},{50,325}},{1,{24,24},{475,200}},{1,{24,24},{550,400}},{1,{24,24},{525,200}},{1,{24,24},{425,775}},{1,{24,24},{175,475}},{2,{24,24},{100,275}},{2,{24,24},{75,300}},{1,{24,24},{775,825}},{1,{24,24},{150,125}},{1,{24,24},{850,100}},{1,{24,24},{600,325}},{1,{24,24},{500,25}},{1,{24,24},{50,375}},{1,{24,24},{50,725}},{1,{24,24},{325,875}},{2,{24,24},{150,225}},{1,{24,24},{225,875}},{1,{24,24},{875,400}},{1,{24,24},{825,250}},{1,{24,24},{25,900}},{1,{24,24},{575,125}},{1,{24,24},{525,350}},{2,{24,24},{225,150}},{1,{24,24},{225,200}},{2,{24,24},{325,50}},{1,{24,24},{875,825}},{1,{24,24},{475,650}},{2,{24,24},{150,25}},{1,{24,24},{125,600}},{1,{24,24},{0,375}},{2,{24,24},{175,200}},{2,{24,24},{175,175}},{1,{24,24},{675,150}},{2,{24,24},{25,325}},{1,{24,24},{0,550}},{2,{24,24},{0,350}},{2,{24,24},{75,275}},{1,{24,24},{175,250}},{1,{24,24},{200,450}},{2,{24,24},{50,300}},{1,{24,24},{75,200}},{1,{24,24},{100,200}},{1,{24,24},{350,550}},{1,{24,24},{225,650}},{1,{24,24},{775,150}},{2,{24,24},{375,0}},{1,{24,24},{825,325}},{1,{24,24},{425,375}},{2,{24,24},{100,25}},{2,{24,24},{150,200}},{2,{24,24},{275,0}},{2,{24,24},{200,150}},{2,{24,24},{175,0}},{1,{24,24},{150,525}},{1,{24,24},{0,175}},{2,{24,24},{225,125}},{2,{24,24},{250,100}},{2,{24,24},{275,75}},{1,{24,24},{250,0}},{1,{24,24},{500,175}},{1,{24,24},{550,25}},{2,{24,24},{0,225}},{1,{24,24},{400,750}},{1,{24,24},{125,250}},{1,{24,24},{400,525}},{1,{24,24},{250,950}},{1,{24,24},{375,800}},{2,{24,24},{325,25}},{2,{24,24},{50,25}},{2,{24,24},{350,0}},{1,{24,24},{325,675}},{2,{24,24},{75,250}},{1,{24,24},{75,250}},{2,{24,24},{100,225}},{2,{24,24},{150,175}},{2,{24,24},{175,150}},{1,{24,24},{675,225}},{1,{24,24},{675,650}},{2,{24,24},{125,200}},{1,{24,24},{625,200}},{2,{24,24},{200,125}},{1,{24,24},{600,750}},{2,{24,24},{275,50}},{1,{24,24},{950,475}},{1,{24,24},{700,575}},{1,{24,24},{750,350}},{2,{24,24},{325,0}},{1,{24,24},{150,100}},{1,{24,24},{400,975}},{1,{24,24},{450,400}},{2,{24,24},{225,100}},{2,{24,24},{25,0}},{1,{24,24},{800,725}},{1,{24,24},{625,175}},{1,{24,24},{825,0}},{1,{24,24},{150,75}},{1,{24,24},{475,925}},{1,{24,24},{850,125}},{2,{24,24},{0,300}},{1,{24,24},{625,850}},{2,{24,24},{50,125}},{2,{24,24},{100,200}},{1,{24,24},{425,625}},{1,{24,24},{750,900}},{1,{24,24},{525,800}},{2,{24,24},{150,150}},{1,{24,24},{625,0}},{2,{24,24},{225,75}},{1,{24,24},{550,175}},{1,{24,24},{125,625}},{2,{24,24},{125,250}},{2,{24,24},{0,275}},{1,{24,24},{300,725}},{1,{24,24},{275,100}},{1,{24,24},{425,250}},{2,{24,24},{50,225}},{1,{24,24},{400,250}},{1,{24,24},{900,700}},{1,{24,24},{225,775}},{1,{24,24},{250,350}},{2,{24,24},{75,200}},{1,{24,24},{825,800}},{2,{24,24},{100,175}},{1,{24,24},{0,0}},{1,{24,24},{300,450}},{1,{24,24},{775,850}},{2,{24,24},{175,100}},{2,{24,24},{150,125}},{2,{24,24},{225,50}},{2,{24,24},{50,200}},{2,{24,24},{75,175}},{1,{24,24},{850,225}},{1,{24,24},{375,625}},{1,{24,24},{300,75}},{1,{24,24},{975,625}},{1,{24,24},{50,800}},{1,{24,24},{625,500}},{1,{24,24},{400,25}},{1,{24,24},{375,950}},{1,{24,24},{425,450}},{2,{24,24},{200,50}},{1,{24,24},{850,725}},{2,{24,24},{225,25}},{1,{24,24},{450,550}},{1,{24,24},{500,0}},{1,{24,24},{950,525}},{1,{24,24},{775,675}},{2,{24,24},{250,0}},{1,{24,24},{75,650}},{2,{24,24},{75,150}},{1,{24,24},{575,975}},{2,{24,24},{100,125}},{1,{24,24},{750,425}},{1,{24,24},{300,0}},{1,{24,24},{200,375}},{1,{24,24},{925,650}},{1,{24,24},{725,750}},{1,{24,24},{0,625}},{2,{24,24},{200,75}},{1,{24,24},{200,875}},{2,{24,24},{200,25}},{2,{24,24},{225,0}},{1,{24,24},{700,825}},{2,{24,24},{0,200}},{2,{24,24},{50,150}},{1,{24,24},{625,925}},{1,{24,24},{75,50}},{2,{24,24},{75,125}},{1,{24,24},{300,525}},{1,{24,24},{725,375}},{1,{24,24},{525,50}},{2,{24,24},{100,100}},{1,{24,24},{875,150}},{1,{24,24},{450,375}},{2,{24,24},{200,0}},{2,{24,24},{150,50}},{2,{24,24},{0,175}},{1,{24,24},{325,350}},{2,{24,24},{125,175}},{1,{24,24},{150,850}},{2,{24,24},{100,75}},{1,{24,24},{525,400}},{1,{24,24},{725,150}},{1,{24,24},{75,950}},{1,{24,24},{550,325}},{1,{24,24},{225,425}},{1,{24,24},{50,0}},{1,{24,24},{150,750}},{1,{24,24},{825,725}},{1,{24,24},{100,100}},{2,{24,24},{25,125}},{1,{24,24},{900,825}},{2,{24,24},{50,100}},{2,{24,24},{75,75}},{2,{24,24},{125,25}},{1,{24,24},{250,675}},{1,{24,24},{600,800}},{1,{24,24},{275,375}},{2,{24,24},{50,75}},{2,{24,24},{150,0}},{1,{24,24},{975,125}},{1,{24,24},{0,750}},{1,{24,24},{25,650}},{2,{24,24},{75,50}},{2,{24,24},{25,25}},{2,{24,24},{75,25}},{1,{24,24},{750,625}},{1,{24,24},{100,800}},{1,{24,24},{350,125}},{2,{24,24},{25,50}},{1,{24,24},{200,425}},{1,{24,24},{125,325}},{2,{24,24},{25,75}},{1,{24,24},{875,425}},{1,{24,24},{900,250}},{2,{24,24},{50,0}},{2,{24,24},{0,25}},{2,{24,24},{0,0}},{1,{24,24},{850,475}},{1,{24,24},{975,950}},{1,{24,24},{750,150}},{1,{24,24},{950,975}},{1,{24,24},{425,500}},{1,{24,24},{625,950}},{1,{24,24},{825,100}},{1,{24,24},{925,975}},{2,{24,24},{100,300}},{1,{24,24},{900,975}},{1,{24,24},{925,950}},{1,{24,24},{0,300}},{1,{24,24},{100,775}},{1,{24,24},{875,900}},{1,{24,24},{975,900}},{1,{24,24},{900,950}},{1,{24,24},{575,350}},{1,{24,24},{375,175}},{1,{24,24},{300,400}},{1,{24,24},{975,650}},{1,{24,24},{500,775}},{1,{24,24},{875,975}},{1,{24,24},{400,600}},{1,{24,24},{775,300}},{1,{24,24},{0,475}},{1,{24,24},{950,900}},{1,{24,24},{825,200}},{1,{24,24},{825,50}},{1,{24,24},{425,575}},{1,{24,24},{900,925}},{1,{24,24},{175,175}},{1,{24,24},{0,425}},{1,{24,24},{850,750}},{1,{24,24},{725,325}},{1,{24,24},{975,425}},{1,{24,24},{475,325}},{1,{24,24},{500,700}},{1,{24,24},{950,850}},{1,{24,24},{975,825}},{1,{24,24},{250,925}},{1,{24,24},{50,325}},{1,{24,24},{600,775}},{1,{24,24},{775,625}},{1,{24,24},{925,875}},{1,{24,24},{800,975}},{1,{24,24},{475,625}},{1,{24,24},{950,925}},{1,{24,24},{675,550}},{1,{24,24},{775,75}},{1,{24,24},{450,125}},{1,{24,24},{950,825}},{1,{24,24},{925,850}},{1,{24,24},{275,725}},{1,{24,24},{775,975}},{1,{24,24},{800,950}},{1,{24,24},{100,850}},{1,{24,24},{825,925}},{1,{24,24},{150,250}},{1,{24,24},{850,900}},{1,{24,24},{975,775}},{1,{24,24},{900,850}},{1,{24,24},{600,700}},{1,{24,24},{75,450}},{1,{24,24},{950,800}},{1,{24,24},{750,975}},{1,{24,24},{325,125}},{1,{24,24},{750,275}},{1,{24,24},{200,200}},{1,{24,24},{125,650}},{1,{24,24},{800,925}},{1,{24,24},{350,500}},{1,{24,24},{950,300}},{1,{24,24},{775,275}},{1,{24,24},{875,850}},{1,{24,24},{575,900}},{1,{24,24},{500,150}},{1,{24,24},{350,0}},{1,{24,24},{575,825}},{1,{24,24},{975,750}},{1,{24,24},{425,25}},{1,{24,24},{775,925}},{1,{24,24},{825,875}},{1,{24,24},{625,750}},{1,{24,24},{600,725}},{1,{24,24},{900,800}},{1,{24,24},{675,400}},{1,{24,24},{925,775}},{1,{24,24},{950,750}},{1,{24,24},{700,975}},{1,{24,24},{725,950}},{1,{24,24},{500,200}},{1,{24,24},{100,400}},{1,{24,24},{100,0}},{1,{24,24},{850,850}},{1,{24,24},{200,850}},{1,{24,24},{750,925}},{1,{24,24},{600,900}},{1,{24,24},{550,775}},{1,{24,24},{0,350}},{1,{24,24},{350,150}},{1,{24,24},{825,850}},{2,{24,24},{0,375}},{1,{24,24},{750,750}},{1,{24,24},{25,0}},{1,{24,24},{700,25}},{1,{24,24},{925,750}},{1,{24,24},{725,925}},{2,{24,24},{175,125}},{1,{24,24},{700,375}},{2,{24,24},{225,175}},{1,{24,24},{600,250}},{1,{24,24},{400,450}},{1,{24,24},{800,850}},{1,{24,24},{300,300}},{1,{24,24},{850,800}},{1,{24,24},{875,775}},{1,{24,24},{0,575}},{1,{24,24},{250,150}},{1,{24,24},{150,975}},{1,{24,24},{925,725}},{1,{24,24},{750,700}},{1,{24,24},{500,500}},{1,{24,24},{350,200}},{1,{24,24},{700,325}},{1,{24,24},{150,725}},{1,{24,24},{650,975}},{1,{24,24},{125,925}},{1,{24,24},{100,350}},{1,{24,24},{600,200}},{1,{24,24},{475,400}},{1,{24,24},{650,50}},{1,{24,24},{350,75}},{1,{24,24},{175,850}},{1,{24,24},{375,225}},{1,{24,24},{475,375}},{1,{24,24},{675,275}},{1,{24,24},{450,0}},{1,{24,24},{375,775}},{1,{24,24},{750,875}},{1,{24,24},{125,675}},{1,{24,24},{975,675}},{1,{24,24},{250,775}},{1,{24,24},{800,825}},{1,{24,24},{850,775}},{1,{24,24},{950,675}},{1,{24,24},{300,200}},{1,{24,24},{900,75}},{1,{24,24},{575,800}},{1,{24,24},{875,500}},{1,{24,24},{300,800}},{1,{24,24},{875,750}},{1,{24,24},{675,925}},{1,{24,24},{700,900}},{1,{24,24},{450,75}},{1,{24,24},{725,200}},{1,{24,24},{725,875}},{1,{24,24},{925,550}},{1,{24,24},{975,50}},{1,{24,24},{325,375}},{1,{24,24},{575,250}},{1,{24,24},{950,875}},{1,{24,24},{175,125}},{1,{24,24},{275,150}},{1,{24,24},{925,675}},{1,{24,24},{350,625}},{1,{24,24},{125,350}},{1,{24,24},{275,925}},{1,{24,24},{575,450}},{1,{24,24},{250,900}},{1,{24,24},{650,925}},{1,{24,24},{700,875}},{1,{24,24},{750,825}},{1,{24,24},{550,0}},{1,{24,24},{775,800}},{1,{24,24},{25,375}},{1,{24,24},{0,600}},{1,{24,24},{625,250}},{1,{24,24},{800,775}},{1,{24,24},{600,100}},{1,{24,24},{825,750}},{1,{24,24},{350,400}},{1,{24,24},{225,800}},{1,{24,24},{925,100}},{1,{24,24},{900,675}},{1,{24,24},{700,150}},{1,{24,24},{175,225}},{1,{24,24},{600,475}},{1,{24,24},{0,250}},{1,{24,24},{275,250}},{1,{24,24},{400,50}},{1,{24,24},{675,625}},{1,{24,24},{0,500}},{1,{24,24},{475,875}},{1,{24,24},{300,900}},{1,{24,24},{525,550}},{1,{24,24},{600,925}},{2,{24,24},{125,100}},{1,{24,24},{900,175}},{1,{24,24},{950,625}},{1,{24,24},{525,725}},{1,{24,24},{550,500}},{1,{24,24},{275,50}},{1,{24,24},{975,600}},{1,{24,24},{200,500}},{1,{24,24},{500,650}},{1,{24,24},{475,850}},{1,{24,24},{125,25}},{1,{24,24},{275,500}},{1,{24,24},{0,200}},{1,{24,24},{675,425}},{1,{24,24},{975,400}},{1,{24,24},{650,900}},{1,{24,24},{825,700}},{1,{24,24},{150,825}},{1,{24,24},{800,500}},{1,{24,24},{325,750}},{1,{24,24},{775,175}},{1,{24,24},{325,600}},{1,{24,24},{800,750}},{1,{24,24},{975,0}},{2,{24,24},{200,200}},{2,{24,24},{300,75}},{1,{24,24},{900,650}},{1,{24,24},{625,100}},{1,{24,24},{875,0}},{1,{24,24},{900,50}},{1,{24,24},{200,525}},{1,{24,24},{75,75}},{1,{24,24},{925,625}},{1,{24,24},{950,600}},{1,{24,24},{650,850}},{1,{24,24},{50,500}},{1,{24,24},{950,575}},{1,{24,24},{100,175}},{1,{24,24},{325,75}},{1,{24,24},{650,875}},{2,{24,24},{25,175}},{1,{24,24},{725,800}},{1,{24,24},{575,675}},{1,{24,24},{475,425}},{1,{24,24},{775,750}},{1,{24,24},{225,250}},{1,{24,24},{725,600}},{1,{24,24},{525,600}},{1,{24,24},{650,700}},{1,{24,24},{300,625}},{1,{24,24},{875,650}},{1,{24,24},{900,625}},{1,{24,24},{575,950}},{1,{24,24},{250,825}},{1,{24,24},{200,950}},{1,{24,24},{975,550}},{1,{24,24},{250,650}},{1,{24,24},{550,950}},{1,{24,24},{450,950}},{1,{24,24},{375,300}},{1,{24,24},{125,175}},{1,{24,24},{625,875}},{1,{24,24},{550,975}},{1,{24,24},{675,825}},{1,{24,24},{700,800}},{1,{24,24},{0,650}},{1,{24,24},{875,800}},{1,{24,24},{925,375}},{1,{24,24},{500,975}},{1,{24,24},{525,375}},{1,{24,24},{850,75}},{1,{24,24},{600,150}},{1,{24,24},{175,200}},{1,{24,24},{800,325}},{1,{24,24},{750,450}},{1,{24,24},{800,675}},{1,{24,24},{50,175}},{1,{24,24},{825,675}},{1,{24,24},{375,375}},{1,{24,24},{50,475}},{1,{24,24},{250,425}},{1,{24,24},{800,400}},{1,{24,24},{450,100}},{1,{24,24},{250,475}},{1,{24,24},{350,250}},{1,{24,24},{875,725}},{2,{24,24},{400,0}},{1,{24,24},{925,575}},{1,{24,24},{975,525}},{1,{24,24},{475,975}},{1,{24,24},{0,875}},{1,{24,24},{900,400}},{1,{24,24},{650,825}},{1,{24,24},{150,275}},{1,{24,24},{675,800}},{1,{24,24},{700,775}},{1,{24,24},{875,300}},{1,{24,24},{450,150}},{2,{24,24},{150,75}},{1,{24,24},{650,625}},{1,{24,24},{750,725}},{1,{24,24},{450,800}},{2,{24,24},{125,225}},{1,{24,24},{100,475}},{1,{24,24},{775,725}},{1,{24,24},{375,475}},{1,{24,24},{125,525}},{1,{24,24},{825,650}},{1,{24,24},{875,600}},{1,{24,24},{900,575}},{1,{24,24},{475,600}},{1,{24,24},{800,800}},{1,{24,24},{500,950}},{1,{24,24},{75,550}},{1,{24,24},{525,950}},{1,{24,24},{350,700}},{1,{24,24},{550,900}},{1,{24,24},{650,275}},{1,{24,24},{575,875}},{1,{24,24},{0,75}},{1,{24,24},{100,875}},{1,{24,24},{275,550}},{1,{24,24},{175,300}},{1,{24,24},{850,350}},{1,{24,24},{200,250}},{1,{24,24},{500,825}},{1,{24,24},{50,550}},{1,{24,24},{325,250}},{1,{24,24},{200,700}},{1,{24,24},{950,175}},{1,{24,24},{900,200}},{1,{24,24},{650,800}},{1,{24,24},{725,725}},{1,{24,24},{800,650}},{1,{24,24},{675,175}},{1,{24,24},{875,575}},{1,{24,24},{775,425}},{1,{24,24},{600,350}},{1,{24,24},{900,550}},{1,{24,24},{575,375}},{1,{24,24},{750,500}},{1,{24,24},{825,275}},{1,{24,24},{400,375}},{1,{24,24},{300,425}},{1,{24,24},{550,75}},{1,{24,24},{25,25}},{1,{24,24},{0,325}},{1,{24,24},{475,775}},{1,{24,24},{950,500}},{1,{24,24},{275,450}},{1,{24,24},{625,275}},{1,{24,24},{175,650}},{1,{24,24},{100,650}},{1,{24,24},{725,125}},{1,{24,24},{450,825}},{1,{24,24},{275,325}},{1,{24,24},{500,925}},{1,{24,24},{100,425}},{1,{24,24},{100,75}},{1,{24,24},{975,25}},{2,{24,24},{300,50}},{1,{24,24},{825,900}},{1,{24,24},{650,775}},{1,{24,24},{725,700}},{1,{24,24},{800,625}},{1,{24,24},{100,550}},{1,{24,24},{825,600}},{1,{24,24},{850,575}},{1,{24,24},{875,550}},{1,{24,24},{50,975}},{1,{24,24},{650,325}},{1,{24,24},{925,500}},{2,{24,24},{300,25}},{1,{24,24},{300,100}},{1,{24,24},{800,550}},{1,{24,24},{575,925}},{1,{24,24},{400,125}},{1,{24,24},{675,250}},{1,{24,24},{425,975}},{1,{24,24},{25,500}},{1,{24,24},{500,900}},{1,{24,24},{750,675}},{1,{24,24},{550,850}},{1,{24,24},{725,975}},{1,{24,24},{450,25}},{1,{24,24},{800,250}},{1,{24,24},{150,175}},{1,{24,24},{250,175}},{1,{24,24},{475,525}},{1,{24,24},{600,125}},{1,{24,24},{700,125}},{1,{24,24},{250,75}},{1,{24,24},{975,700}},{1,{24,24},{625,775}},{1,{24,24},{675,725}},{1,{24,24},{150,700}},{1,{24,24},{725,675}},{1,{24,24},{700,700}},{1,{24,24},{725,650}},{1,{24,24},{825,575}},{1,{24,24},{850,550}},{1,{24,24},{750,650}},{1,{24,24},{850,950}},{1,{24,24},{550,200}},{1,{24,24},{450,925}},{1,{24,24},{475,900}},{1,{24,24},{675,475}},{1,{24,24},{875,225}},{1,{24,24},{800,450}},{1,{24,24},{425,850}},{1,{24,24},{650,250}},{1,{24,24},{500,875}},{1,{24,24},{825,775}},{1,{24,24},{550,825}},{1,{24,24},{425,950}},{1,{24,24},{950,75}},{1,{24,24},{625,975}},{1,{24,24},{650,725}},{1,{24,24},{0,725}},{1,{24,24},{550,675}},{1,{24,24},{450,625}},{1,{24,24},{475,50}},{1,{24,24},{800,900}},{1,{24,24},{175,875}},{1,{24,24},{875,375}},{2,{24,24},{100,0}},{1,{24,24},{325,150}},{1,{24,24},{525,450}},{1,{24,24},{850,525}},{1,{24,24},{25,550}},{1,{24,24},{625,50}},{1,{24,24},{475,825}},{1,{24,24},{525,250}},{1,{24,24},{325,825}},{1,{24,24},{950,425}},{1,{24,24},{400,0}},{1,{24,24},{375,975}},{1,{24,24},{400,950}},{1,{24,24},{0,400}},{1,{24,24},{775,600}},{1,{24,24},{325,475}},{1,{24,24},{350,600}},{1,{24,24},{975,350}},{1,{24,24},{750,475}},{1,{24,24},{525,325}},{1,{24,24},{525,825}},{1,{24,24},{625,225}},{1,{24,24},{500,300}},{1,{24,24},{575,775}},{1,{24,24},{275,175}},{1,{24,24},{575,425}},{2,{24,24},{325,75}},{1,{24,24},{850,675}},{1,{24,24},{700,650}},{1,{24,24},{725,625}},{1,{24,24},{750,600}},{1,{24,24},{625,400}},{1,{24,24},{775,575}},{1,{24,24},{300,825}},{1,{24,24},{300,775}},{1,{24,24},{100,750}},{1,{24,24},{575,50}},{1,{24,24},{125,975}},{1,{24,24},{900,450}},{1,{24,24},{325,275}},{1,{24,24},{925,425}},{1,{24,24},{25,225}},{1,{24,24},{950,400}},{1,{24,24},{975,375}},{1,{24,24},{275,875}},{1,{24,24},{650,225}},{1,{24,24},{550,375}},{1,{24,24},{350,975}},{1,{24,24},{375,400}},{1,{24,24},{750,575}},{1,{24,24},{450,875}},{1,{24,24},{800,875}},{1,{24,24},{575,750}},{1,{24,24},{625,700}},{1,{24,24},{550,275}},{1,{24,24},{600,850}},{1,{24,24},{575,225}},{1,{24,24},{450,675}},{1,{24,24},{550,600}},{1,{24,24},{425,350}},{1,{24,24},{225,450}},{1,{24,24},{175,500}},{1,{24,24},{425,900}},{1,{24,24},{100,225}},{1,{24,24},{825,375}},{1,{24,24},{50,350}},{1,{24,24},{675,375}},{1,{24,24},{25,625}},{1,{24,24},{275,575}},{1,{24,24},{950,25}},{1,{24,24},{575,525}},{1,{24,24},{300,600}},{1,{24,24},{275,825}},{1,{24,24},{775,550}},{1,{24,24},{975,975}},{1,{24,24},{825,500}},{1,{24,24},{225,25}},{1,{24,24},{900,425}},{1,{24,24},{650,175}},{1,{24,24},{925,400}},{1,{24,24},{950,375}},{1,{24,24},{875,450}},{1,{24,24},{450,900}},{1,{24,24},{325,975}},{1,{24,24},{800,100}},{1,{24,24},{225,975}},{1,{24,24},{350,950}},{1,{24,24},{400,900}},{1,{24,24},{525,650}},{1,{24,24},{525,775}},{1,{24,24},{375,925}},{1,{24,24},{775,775}},{1,{24,24},{375,150}},{1,{24,24},{950,200}},{1,{24,24},{600,425}},{1,{24,24},{900,475}},{1,{24,24},{225,475}},{1,{24,24},{525,975}},{1,{24,24},{150,325}},{1,{24,24},{775,100}},{1,{24,24},{575,725}},{1,{24,24},{625,675}},{1,{24,24},{550,800}},{1,{24,24},{175,100}},{1,{24,24},{775,525}},{1,{24,24},{425,875}},{2,{24,24},{250,50}},{1,{24,24},{325,225}},{1,{24,24},{850,450}},{1,{24,24},{550,925}},{1,{24,24},{25,350}},{1,{24,24},{700,250}},{1,{24,24},{850,425}},{1,{24,24},{250,400}},{1,{24,24},{950,350}},{1,{24,24},{300,975}},{1,{24,24},{900,350}},{1,{24,24},{400,875}},{1,{24,24},{350,925}},{1,{24,24},{475,800}},{1,{24,24},{925,925}},{1,{24,24},{175,75}},{1,{24,24},{550,725}},{1,{24,24},{600,675}},{1,{24,24},{625,650}},{1,{24,24},{300,50}},{1,{24,24},{675,600}},{1,{24,24},{750,300}},{1,{24,24},{750,525}},{1,{24,24},{825,450}},{1,{24,24},{650,475}},{1,{24,24},{225,50}},{1,{24,24},{800,475}},{1,{24,24},{700,600}},{2,{24,24},{200,175}},{1,{24,24},{125,775}},{1,{24,24},{650,400}},{1,{24,24},{300,950}},{1,{24,24},{325,925}},{1,{24,24},{550,450}},{1,{24,24},{425,825}},{1,{24,24},{400,850}},{1,{24,24},{500,750}},{1,{24,24},{600,650}},{1,{24,24},{750,775}},{1,{24,24},{575,500}},{1,{24,24},{625,625}},{1,{24,24},{25,425}},{1,{24,24},{550,575}},{1,{24,24},{725,525}},{1,{24,24},{825,425}},{1,{24,24},{850,400}},{1,{24,24},{925,800}},{1,{24,24},{150,50}},{1,{24,24},{0,50}},{1,{24,24},{600,825}},{1,{24,24},{50,125}},{1,{24,24},{250,975}},{1,{24,24},{25,75}},{1,{24,24},{275,950}},{1,{24,24},{175,675}},{1,{24,24},{125,575}},{1,{24,24},{925,50}},{1,{24,24},{500,225}},{1,{24,24},{300,150}},{1,{24,24},{550,425}},{1,{24,24},{375,900}},{1,{24,24},{275,775}},{1,{24,24},{750,75}},{1,{24,24},{250,700}},{1,{24,24},{50,775}},{1,{24,24},{350,875}},{1,{24,24},{400,825}},{1,{24,24},{150,225}},{1,{24,24},{400,550}},{1,{24,24},{425,800}},{1,{24,24},{525,700}},{1,{24,24},{675,0}},{1,{24,24},{800,0}},{1,{24,24},{625,600}},{1,{24,24},{650,575}},{1,{24,24},{275,700}},{1,{24,24},{900,875}},{1,{24,24},{325,0}},{1,{24,24},{225,925}},{1,{24,24},{200,825}},{1,{24,24},{200,900}},{1,{24,24},{550,300}},{1,{24,24},{625,125}},{1,{24,24},{825,400}},{1,{24,24},{125,425}},{1,{24,24},{425,700}},{1,{24,24},{950,275}},{1,{24,24},{975,250}},{1,{24,24},{400,350}},{1,{24,24},{350,850}},{1,{24,24},{200,650}},{1,{24,24},{400,800}},{1,{24,24},{675,525}},{1,{24,24},{375,25}},{1,{24,24},{350,575}},{1,{24,24},{450,750}},{1,{24,24},{600,175}},{1,{24,24},{475,725}},{1,{24,24},{900,900}},{1,{24,24},{625,475}},{1,{24,24},{25,925}},{1,{24,24},{375,75}},{1,{24,24},{600,375}},{1,{24,24},{750,0}},{1,{24,24},{25,950}},{1,{24,24},{625,575}},{1,{24,24},{550,650}},{1,{24,24},{650,550}},{1,{24,24},{400,475}},{1,{24,24},{725,475}},{1,{24,24},{100,900}},{1,{24,24},{0,450}},{1,{24,24},{125,100}},{1,{24,24},{650,675}},{1,{24,24},{150,350}},{1,{24,24},{875,325}},{1,{24,24},{900,300}},{1,{24,24},{750,50}},{1,{24,24},{375,275}},{1,{24,24},{975,225}},{1,{24,24},{525,25}},{1,{24,24},{275,0}},{1,{24,24},{875,625}},{1,{24,24},{225,950}},{1,{24,24},{550,100}},{1,{24,24},{275,900}},{1,{24,24},{325,775}},{1,{24,24},{350,300}},{1,{24,24},{100,950}},{1,{24,24},{350,825}},{1,{24,24},{575,325}},{1,{24,24},{575,850}},{1,{24,24},{400,150}},{1,{24,24},{325,400}},{1,{24,24},{725,775}},{1,{24,24},{450,725}},{1,{24,24},{650,75}},{1,{24,24},{650,25}},{1,{24,24},{225,500}},{1,{24,24},{225,0}},{1,{24,24},{125,125}},{1,{24,24},{425,750}},{1,{24,24},{500,675}},{1,{24,24},{475,700}},{1,{24,24},{250,800}},{1,{24,24},{175,950}},{1,{24,24},{675,500}},{1,{24,24},{125,500}},{1,{24,24},{475,225}},{1,{24,24},{75,600}},{1,{24,24},{625,425}},{1,{24,24},{700,475}},{1,{24,24},{775,400}},{1,{24,24},{650,0}},{1,{24,24},{725,450}},{1,{24,24},{900,225}},{1,{24,24},{775,0}},{1,{24,24},{900,275}},{1,{24,24},{775,875}},{1,{24,24},{800,225}},{1,{24,24},{175,975}},{1,{24,24},{700,525}},{1,{24,24},{400,425}},{1,{24,24},{500,450}},{1,{24,24},{600,975}},{1,{24,24},{150,150}},{1,{24,24},{100,50}},{1,{24,24},{925,450}},{1,{24,24},{125,50}},{1,{24,24},{250,725}},{1,{24,24},{50,25}},{1,{24,24},{350,800}},{1,{24,24},{425,725}},{1,{24,24},{875,250}},{1,{24,24},{850,300}},{1,{24,24},{325,100}},{1,{24,24},{175,600}},{1,{24,24},{600,950}},{1,{24,24},{625,525}},{1,{24,24},{550,475}},{1,{24,24},{525,275}},{1,{24,24},{300,875}},{1,{24,24},{875,950}},{1,{24,24},{775,375}},{1,{24,24},{875,275}},{2,{24,24},{0,50}},{1,{24,24},{225,275}},{1,{24,24},{925,225}},{1,{24,24},{0,100}},{1,{24,24},{975,175}},{1,{24,24},{425,175}},{1,{24,24},{150,625}},{1,{24,24},{575,0}},{1,{24,24},{475,450}},{1,{24,24},{900,750}},{1,{24,24},{475,175}},{1,{24,24},{600,575}},{1,{24,24},{500,325}},{1,{24,24},{525,575}},{1,{24,24},{225,900}},{1,{24,24},{675,100}},{1,{24,24},{250,875}},{1,{24,24},{850,500}},{2,{24,24},{100,150}},{1,{24,24},{525,675}},{1,{24,24},{500,625}},{1,{24,24},{700,550}},{2,{24,24},{150,100}},{1,{24,24},{700,425}},{1,{24,24},{600,525}},{1,{24,24},{625,450}},{1,{24,24},{50,525}},{1,{24,24},{825,300}},{1,{24,24},{850,275}},{1,{24,24},{600,550}},{1,{24,24},{800,25}},{1,{24,24},{625,825}},{1,{24,24},{150,950}},{1,{24,24},{200,25}},{1,{24,24},{250,50}},{1,{24,24},{175,925}},{2,{24,24},{300,0}},{1,{24,24},{575,100}},{1,{24,24},{150,775}},{1,{24,24},{500,125}},{1,{24,24},{850,925}},{1,{24,24},{200,75}},{1,{24,24},{200,925}},{1,{24,24},{550,550}},{1,{24,24},{475,150}},{1,{24,24},{600,500}},{1,{24,24},{700,400}},{1,{24,24},{750,100}},{1,{24,24},{925,525}},{1,{24,24},{350,650}},{1,{24,24},{700,200}},{1,{24,24},{800,300}},{1,{24,24},{525,475}},{1,{24,24},{25,125}},{1,{24,24},{75,925}},{1,{24,24},{300,250}},{1,{24,24},{75,700}},{1,{24,24},{725,100}},{1,{24,24},{25,525}},{1,{24,24},{150,925}},{1,{24,24},{125,950}},{1,{24,24},{325,700}},{1,{24,24},{700,175}},{1,{24,24},{75,900}},{1,{24,24},{75,25}},{1,{24,24},{75,575}},{2,{24,24},{175,50}},{1,{24,24},{725,275}},{1,{24,24},{825,475}},{1,{24,24},{325,525}},{1,{24,24},{100,975}},{1,{24,24},{625,375}},{1,{24,24},{450,700}},{1,{24,24},{400,725}},{1,{24,24},{500,575}},{1,{24,24},{725,350}},{1,{24,24},{325,325}},{1,{24,24},{800,275}},{1,{24,24},{400,100}},{1,{24,24},{350,775}},{1,{24,24},{950,125}},{1,{24,24},{925,150}},{1,{24,24},{875,200}},{1,{24,24},{325,650}},{1,{24,24},{175,150}},{1,{24,24},{425,125}},{1,{24,24},{325,850}},{1,{24,24},{675,350}},{1,{24,24},{975,100}},{1,{24,24},{25,50}},{1,{24,24},{75,875}},{1,{24,24},{150,900}},{1,{24,24},{375,50}},{1,{24,24},{675,700}},{1,{24,24},{675,875}},{1,{24,24},{550,625}},{1,{24,24},{225,75}},{1,{24,24},{825,975}},{1,{24,24},{850,875}},{2,{24,24},{0,400}},{1,{24,24},{525,525}},{1,{24,24},{100,700}},{1,{24,24},{25,850}},{1,{24,24},{200,750}},{1,{24,24},{300,575}},{1,{24,24},{900,125}},{1,{24,24},{275,975}},{1,{24,24},{375,100}},{1,{24,24},{575,25}},{1,{24,24},{225,350}},{1,{24,24},{75,625}},{1,{24,24},{800,525}},{1,{24,24},{350,375}},{1,{24,24},{450,250}},{1,{24,24},{700,350}},{1,{24,24},{300,750}},{1,{24,24},{725,550}},{1,{24,24},{825,225}},{1,{24,24},{325,725}},{1,{24,24},{850,200}},{1,{24,24},{0,25}},{1,{24,24},{875,175}},{1,{24,24},{900,150}},{1,{24,24},{950,150}},{1,{24,24},{925,125}},{1,{24,24},{975,75}},{1,{24,24},{100,925}},{1,{24,24},{250,525}},{1,{24,24},{275,25}},{1,{24,24},{875,25}},{1,{24,24},{875,700}},{1,{24,24},{275,750}},{1,{24,24},{250,275}},{1,{24,24},{350,675}},{1,{24,24},{375,650}},{1,{24,24},{200,225}},{1,{24,24},{400,625}},{1,{24,24},{425,600}},{1,{24,24},{525,500}},{1,{24,24},{700,225}},{1,{24,24},{550,525}},{1,{24,24},{50,425}},{1,{24,24},{725,300}},{1,{24,24},{775,250}},{1,{24,24},{50,575}},{1,{24,24},{150,450}},{1,{24,24},{125,725}},{1,{24,24},{600,0}},{1,{24,24},{600,75}},{1,{24,24},{350,350}},{2,{24,24},{175,25}},{1,{24,24},{775,950}},{1,{24,24},{600,450}},{1,{24,24},{25,975}},{1,{24,24},{0,800}},{1,{24,24},{500,375}},{1,{24,24},{350,50}},{1,{24,24},{850,250}},{1,{24,24},{275,475}},{1,{24,24},{125,875}},{1,{24,24},{375,200}},{1,{24,24},{175,825}},{1,{24,24},{400,75}},{1,{24,24},{200,800}},{1,{24,24},{200,275}},{1,{24,24},{250,750}},{1,{24,24},{300,225}},{1,{24,24},{475,100}},{1,{24,24},{975,800}},{1,{24,24},{300,700}},{1,{24,24},{950,50}},{2,{24,24},{25,300}},{1,{24,24},{950,700}},{1,{24,24},{25,775}},{1,{24,24},{625,725}},{1,{24,24},{650,350}},{1,{24,24},{675,325}},{1,{24,24},{700,300}},{1,{24,24},{750,250}},{1,{24,24},{800,200}},{1,{24,24},{75,800}},{1,{24,24},{300,175}},{1,{24,24},{550,225}},{1,{24,24},{825,175}},{1,{24,24},{875,125}},{1,{24,24},{900,100}},{1,{24,24},{525,900}},{1,{24,24},{575,625}},{1,{24,24},{125,850}},{1,{24,24},{175,800}},{1,{24,24},{200,775}},{1,{24,24},{200,175}},{1,{24,24},{225,850}},{1,{24,24},{250,250}},{1,{24,24},{375,0}},{1,{24,24},{575,650}},{1,{24,24},{600,275}},{1,{24,24},{400,175}},{1,{24,24},{375,600}},{1,{24,24},{400,575}},{1,{24,24},{275,650}},{1,{24,24},{450,525}},{1,{24,24},{475,500}},{1,{24,24},{500,475}},{1,{24,24},{575,400}},{1,{24,24},{900,525}},{1,{24,24},{525,150}},{1,{24,24},{775,25}},{1,{24,24},{525,300}},{1,{24,24},{575,75}},{1,{24,24},{700,275}},{1,{24,24},{325,450}},{1,{24,24},{100,250}},{1,{24,24},{725,250}},{1,{24,24},{750,550}},{1,{24,24},{775,200}},{1,{24,24},{825,150}},{1,{24,24},{800,175}},{1,{24,24},{0,950}},{1,{24,24},{25,825}},{1,{24,24},{375,425}},{1,{24,24},{125,825}},{1,{24,24},{75,175}},{1,{24,24},{250,325}},{1,{24,24},{825,75}},{1,{24,24},{325,625}},{1,{24,24},{325,900}},{1,{24,24},{275,75}},{1,{24,24},{475,475}},{1,{24,24},{25,875}},{1,{24,24},{475,300}},{1,{24,24},{650,300}},{1,{24,24},{175,450}},{1,{24,24},{725,900}},{1,{24,24},{850,650}},{1,{24,24},{650,750}},{1,{24,24},{800,150}},{1,{24,24},{875,75}},{1,{24,24},{925,25}},{1,{24,24},{950,0}},{1,{24,24},{400,300}},{1,{24,24},{0,925}},{1,{24,24},{350,275}},{1,{24,24},{75,850}},{1,{24,24},{350,175}},{1,{24,24},{100,825}},{1,{24,24},{400,700}},{1,{24,24},{200,725}},{2,{24,24},{0,125}},{1,{24,24},{450,450}},{1,{24,24},{225,700}},{1,{24,24},{500,425}},{2,{24,24},{75,100}},{2,{24,24},{100,250}},{1,{24,24},{900,25}},{1,{24,24},{150,0}},{1,{24,24},{925,0}},{1,{24,24},{75,825}},{1,{24,24},{950,325}},{2,{24,24},{0,150}},{1,{24,24},{425,150}},{1,{24,24},{500,250}},{1,{24,24},{375,525}},{1,{24,24},{625,325}},{1,{24,24},{150,300}},{1,{24,24},{300,25}},{1,{24,24},{750,850}},{1,{24,24},{250,450}},{1,{24,24},{50,300}},{1,{24,24},{975,475}},{1,{24,24},{725,175}},{1,{24,24},{775,125}},{1,{24,24},{300,650}},{1,{24,24},{50,825}},{1,{24,24},{50,450}},{1,{24,24},{125,750}},{1,{24,24},{375,325}},{1,{24,24},{225,625}},{1,{24,24},{200,675}},{1,{24,24},{775,700}},{1,{24,24},{250,625}},{1,{24,24},{350,525}},{1,{24,24},{325,550}},{1,{24,24},{650,125}},{1,{24,24},{175,525}},{2,{24,24},{25,375}},{1,{24,24},{50,950}},{1,{24,24},{300,675}},{2,{24,24},{125,50}},{1,{24,24},{325,425}},{1,{24,24},{850,25}},{1,{24,24},{875,475}},{1,{24,24},{75,775}},{1,{24,24},{125,200}},{1,{24,24},{400,675}},{1,{24,24},{700,925}},{1,{24,24},{825,350}},{1,{24,24},{750,225}},{1,{24,24},{0,825}},{1,{24,24},{100,575}},{1,{24,24},{150,600}},{1,{24,24},{25,800}},{1,{24,24},{150,675}},{1,{24,24},{475,950}},{1,{24,24},{225,600}},{1,{24,24},{350,475}},{1,{24,24},{525,850}},{1,{24,24},{675,25}},{1,{24,24},{650,100}},{1,{24,24},{775,50}},{1,{24,24},{150,575}},{1,{24,24},{100,25}},{1,{24,24},{250,550}},{1,{24,24},{350,450}},{1,{24,24},{450,350}},{1,{24,24},{425,300}},{1,{24,24},{750,400}},{1,{24,24},{725,75}},{1,{24,24},{350,725}},{1,{24,24},{950,250}},{1,{24,24},{250,375}},{1,{24,24},{450,775}},{1,{24,24},{475,275}},{1,{24,24},{225,825}},{1,{24,24},{350,425}},{1,{24,24},{450,325}},{1,{24,24},{625,150}},{1,{24,24},{500,275}},{1,{24,24},{25,675}},{1,{24,24},{700,75}},{1,{24,24},{25,725}},{1,{24,24},{150,200}},{1,{24,24},{50,700}},{1,{24,24},{500,800}},{1,{24,24},{250,500}},{1,{24,24},{0,150}},{1,{24,24},{225,375}},{1,{24,24},{800,75}},{1,{24,24},{750,200}},{1,{24,24},{450,300}},{1,{24,24},{0,775}},{1,{24,24},{300,125}},{1,{24,24},{325,575}},{1,{24,24},{675,75}},{1,{24,24},{25,700}},{1,{24,24},{50,100}},{1,{24,24},{150,650}},{1,{24,24},{450,275}},{1,{24,24},{650,150}},{1,{24,24},{250,200}},{1,{24,24},{0,700}},{1,{24,24},{100,600}},{1,{24,24},{25,450}},{1,{24,24},{50,875}},{1,{24,24},{700,0}},{1,{24,24},{550,750}},{1,{24,24},{700,450}},{1,{24,24},{750,325}},{1,{24,24},{425,225}},{1,{24,24},{175,325}},{1,{24,24},{925,325}},{1,{24,24},{525,925}},{1,{24,24},{100,525}},{2,{24,24},{75,0}},{1,{24,24},{425,200}},{1,{24,24},{450,175}},{1,{24,24},{675,950}},{1,{24,24},{75,525}},{1,{24,24},{100,500}},{1,{24,24},{125,475}},{1,{24,24},{25,575}},{1,{24,24},{725,400}},{1,{24,24},{75,500}},{1,{24,24},{50,200}},{1,{24,24},{150,425}},{1,{24,24},{350,225}},{1,{24,24},{25,250}},{1,{24,24},{950,100}},{1,{24,24},{900,325}},{1,{24,24},{425,0}},{1,{24,24},{75,975}},{1,{24,24},{25,175}},{1,{24,24},{875,875}},{1,{24,24},{425,100}},{1,{24,24},{225,525}},{1,{24,24},{25,475}},{1,{24,24},{200,300}},{1,{24,24},{450,50}},{1,{24,24},{650,375}},{1,{24,24},{650,425}},{1,{24,24},{875,675}},{1,{24,24},{225,150}},{2,{24,24},{25,250}},{1,{24,24},{200,100}},{1,{24,24},{100,125}}}}}
local iconIndices = icons[1]
local idIndices = icons[2]
local iconRegistry = icons[3]

Lucide.Icons = iconIndices
function Lucide.GetAsset(name)
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
end

__kicia_hook_shared.obsidian_library = function()
-- Vendored from Obsidian b4523805727561499b5b8206e14590371923f343.
-- Local changes: GetMouse removed, Lucide icon data bundled inline, standalone modifier keybinds restored, inline type annotations removed.
local cloneref = (cloneref or clonereference or function(instance)
    return instance
end)
local CoreGui = cloneref(game:GetService("CoreGui"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local SoundService = cloneref(game:GetService("SoundService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local GuiService = cloneref(game:GetService("GuiService"))
local TextService = cloneref(game:GetService("TextService"))
local Teams = cloneref(game:GetService("Teams"))
local TweenService = cloneref(game:GetService("TweenService"))

local getgenv = getgenv or function()
    return shared
end
local setclipboard = setclipboard or nil
local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
    return CoreGui
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local function GetPointerLocation()
    local Location = UserInputService:GetMouseLocation()
    local TopLeftInset = GuiService:GetGuiInset()
    return Location - TopLeftInset
end

local Labels = {}
local Buttons = {}
local Toggles = {}
local Options = {}
local Tooltips = {}

local BaseURL = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local CustomImageManager = {}
local CustomImageManagerAssets = {
    TransparencyTexture = {
        RobloxId = 139785960036434,
        Path = "Obsidian/assets/TransparencyTexture.png",
        URL = BaseURL .. "assets/TransparencyTexture.png",

        Id = nil,
    },

    SaturationMap = {
        RobloxId = 4155801252,
        Path = "Obsidian/assets/SaturationMap.png",
        URL = BaseURL .. "assets/SaturationMap.png",

        Id = nil,
    },

    LoadingIcon = {
        RobloxId = 97544096941083,
        Path = "Obsidian/assets/LoadingIcon.png",
        URL = BaseURL .. "assets/LoadingIcon.png",

        Id = nil,
    },

    CheckIcon = {
        RobloxId = 97682394690683,
        Path = "Obsidian/assets/CheckIcon.png",
        URL = BaseURL .. "assets/CheckIcon.png",

        Id = nil,
    },
}
do
    local function RecursiveCreatePath(Path, IsFile)
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

    function CustomImageManager.AddAsset(
        AssetName,
        RobloxAssetId,
        URL,
        ForceRedownload
    )
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

    function CustomImageManager.GetAsset(AssetName)
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

    function CustomImageManager.DownloadAsset(AssetName, ForceRedownload)
        if not getcustomasset or not writefile or not isfile then
            return false, "missing functions"
        end

        local AssetData = CustomImageManagerAssets[AssetName]

        RecursiveCreatePath(AssetData.Path, true)

        if ForceRedownload ~= true and isfile(AssetData.Path) then
            return true, nil
        end

        local success, errorMessage = pcall(function()
            writefile(AssetData.Path, game:HttpGet(AssetData.URL))
        end)

        return success, errorMessage
    end

    for AssetName, _ in CustomImageManagerAssets do
        CustomImageManager.DownloadAsset(AssetName)
    end
end

local Library = {
    LocalPlayer = LocalPlayer,
    IsRobloxFocused = true,

    --// Device \\--
    DevicePlatform = nil,
    IsMobile = false,

    --// Obsidian Windows \\--
    ScreenGui = nil,
    Window = nil,
    WindowContainer = nil,

    --// Search \\--
    SearchText = "",
    Searching = false,
    GlobalSearch = false,
    LastSearchTab = nil,

    --// Tabs \\--
    ActiveTab = nil,
    Tabs = {},
    TabButtons = {},

    --// Dependency Boxes \\--
    DependencyBoxes = {},

    --// Keybinds Frame \\--
    KeybindFrame = nil,
    KeybindContainer = nil,
    KeybindToggles = {},

    --// Notifications \\--
    Notifications = {},
    NotifySide = "Right",
    NotifyTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

    --// Dialogues \\--
    Dialogues = {},
    ActiveDialog = nil,

    --// Loading Window \\--
    ActiveLoading = nil,

    --// Corners \\--
    Corners = {},
    SpecificCorners = {},

    --// Animations \\--
    TweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

    TabTransitionInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    TabSwipeOffset = 26,
    TabSwipeFrom = "bottom",

    WindowAnimationInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    DropdownTransitionInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    KeyPickerTransitionInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

    GroupboxTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    RotatingChevronTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),

    Animations = {
        ToggleWindow = false,
        TabSwitch = false,
        Groupbox = false,
        Dropdown = false,
        KeyPicker = false
    },

    --// States \\--
    Toggled = false,
    Unloaded = false,

    --// Elements \\--
    Labels = Labels,
    Buttons = Buttons,
    Toggles = Toggles,
    Options = Options,

    --// Options \\--
    ToggleKeybind = Enum.KeyCode.RightControl,
    ShowToggleFrameInKeybinds = true,

    NotifyOnError = false,
    ShowCustomCursor = true,
    ForceCheckbox = false,

    CantDragForced = false,
    DraggableElements = {},

    --// Signals \\--
    Signals = {},
    UnloadSignals = {},

    OriginalMinSize = Vector2.new(480, 360),
    MinSize = Vector2.new(480, 360),
    DPIScale = 1,
    CornerRadius = 4,

    --// Scheme \\--
    IsLightTheme = false,
    Scheme = {
        BackgroundColor = Color3.fromRGB(15, 15, 15),
        MainColor = Color3.fromRGB(25, 25, 25),
        AccentColor = Color3.fromRGB(125, 85, 255),
        OutlineColor = Color3.fromRGB(40, 40, 40),
        FontColor = Color3.new(1, 1, 1),
        Font = Font.fromEnum(Enum.Font.Code),

        RedColor = Color3.fromRGB(255, 50, 50),
        DestructiveColor = Color3.fromRGB(220, 38, 38),
        DarkColor = Color3.new(0, 0, 0),
        WhiteColor = Color3.new(1, 1, 1),

        BackgroundImage = ""
    },

    --// Registry \\--
    Registry = {},
	Scales = {},
	ScalesOffset = {},

    --// Misc \\--
    ImageManager = CustomImageManager,
    ShowCursorBinding = string.sub(tostring({}), 10),

    Notify = nil, Toggle = nil -- we love luau lsp
}

if RunService:IsStudio() then
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        Library.IsMobile = true
        Library.OriginalMinSize = Vector2.new(480, 240)
    else
        Library.IsMobile = false
        Library.OriginalMinSize = Vector2.new(480, 360)
    end
else
    pcall(function()
        Library.DevicePlatform = UserInputService:GetPlatform()
    end)

    Library.IsMobile = (Library.DevicePlatform == Enum.Platform.Android or Library.DevicePlatform == Enum.Platform.IOS)
    Library.OriginalMinSize = Library.IsMobile and Vector2.new(480, 240) or Vector2.new(480, 360)
end

local Templates = {
    --// UI \\--
    Frame = {
        BorderSizePixel = 0,
    },
    ImageLabel = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    },
    ImageButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
    },
    ScrollingFrame = {
        BorderSizePixel = 0,
    },
    TextLabel = {
        BorderSizePixel = 0,
        FontFace = "Font",
        RichText = true,
        TextColor3 = "FontColor",
    },
    TextButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
        FontFace = "Font",
        RichText = true,
        TextColor3 = "FontColor",
    },
    TextBox = {
        BorderSizePixel = 0,
        FontFace = "Font",
        PlaceholderColor3 = function()
            local H, S, V = Library.Scheme.FontColor:ToHSV()
            return Color3.fromHSV(H, S, V / 2)
        end,
        Text = "",
        TextColor3 = "FontColor",
    },
    UIListLayout = {
        SortOrder = Enum.SortOrder.LayoutOrder,
    },
    UIStroke = {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    },

    --// Library \\--
    Window = {
        Title = "No Title",
        Footer = "No Footer",

        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(720, 600),
        IconSize = UDim2.fromOffset(30, 30),

        AutoShow = true,
        Center = true,
        Resizable = true,

        SearchbarSize = UDim2.fromScale(1, 1),
        GlobalSearch = false,

        CornerRadius = 4,
        NotifySide = "Right",
        ShowCustomCursor = true,

        Font = Enum.Font.Code,
        ToggleKeybind = Enum.KeyCode.RightControl,

        ShowMobileButtons = true,
        MobileButtonsSide = "Left",

        UnlockMouseWhileOpen = true,

        EnableSidebarResize = false,
        EnableCompacting = true,
        DisableCompactingSnap = false,
        SidebarCompacted = false,
        MinContainerWidth = 256,

        --// Snapping \\--
        MinSidebarWidth = 128,
        SidebarCompactWidth = 48,
        SidebarCollapseThreshold = 0.5,

        --// Dragging \\--
        CompactWidthActivation = 128,

        --// Background \\--
        BackgroundImage = "",

        --// Animations \\--
        Animations = {
            ToggleWindow = false,
            TabSwitch = false,
            Groupbox = false,
            Dropdown = false,
            KeyPicker = false
        },

        TabTransitionTime = 0.22,
        TabSwipeOffset = 26,
        TabSwipeFrom = "bottom"
    },
    Dialog = {
        Title = "Dialog",
        Description = "Description",
        AutoDismiss = true,
        OutsideClickDismiss = true,
        FooterButtons = {}
    },
    Loading = {
        Title = "mspaint",
        Icon = 95816097006870,
        IconSize = UDim2.fromOffset(30, 30),

        LoadingIcon = CustomImageManager.GetAsset("LoadingIcon"),
        LoadingIconColor = nil,
        LoadingIconTweenTime = 1,

        CurrentStep = 0,
        TotalSteps = 10,

        ShowSidebar = false,
        AutoResizeHeight = false,

        WindowWidth = 450,
        WindowHeight = 275,

        ContentWidth = 450,
        SidebarWidth = 250,
    },
    Toggle = {
        Text = "Toggle",
        Default = false,

        Callback = function() end,
        Changed = function() end,

        Risky = false,
        Disabled = false,
        Visible = true,
    },
    Input = {
        Text = "Input",
        Default = "",
        Finished = false,
        Numeric = false,
        ClearTextOnFocus = true,
        ClearTextOnBlur = false,
        Placeholder = "",
        AllowEmpty = true,
        EmptyReset = "---",

        Callback = function() end,
        Changed = function() end,
        VerifyValue = nil,

        Disabled = false,
        Visible = true,
    },
    Slider = {
        Text = "Slider",
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,

        Prefix = "",
        Suffix = "",

        Callback = function() end,
        Changed = function() end,

        Disabled = false,
        Visible = true,

        AllowRightClickInput = true
    },
    Dropdown = {
        Values = {},
        DisabledValues = {},
        ValueImages = {},

        Multi = false,
        DragSelect = false,
        MaxVisibleDropdownItems = 8,

        Callback = function() end,
        Changed = function() end,

        Disabled = false,
        Visible = true,
    },
    Viewport = {
        Object = nil,
        Camera = nil,
        Clone = true,
        AutoFocus = true,
        Interactive = false,
        Height = 200,
        Visible = true,
    },
    Image = {
        Image = "",
        Transparency = 0,
        BackgroundTransparency = 0,
        Color = Color3.new(1, 1, 1),
        RectOffset = Vector2.zero,
        RectSize = Vector2.zero,
        ScaleType = Enum.ScaleType.Fit,
        Height = 200,
        Visible = true,
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
    },

    --// Addons \\-
    KeyPicker = {
        Text = "KeyPicker",

        Default = "None",
        DefaultModifiers = {},

        Blacklisted = {},
        BlacklistedModifiers = {},
        Whitelisted = {},
        WhitelistedModifiers = {},

        Mode = "Toggle",
        Modes = { "Always", "Toggle", "Hold" },
        SyncToggleState = false,

        Callback = function() end,
        ChangedCallback = function() end,
        Changed = function() end,
        Clicked = function() end,
    },
    ColorPicker = {
        Default = Color3.new(1, 1, 1),

        Callback = function() end,
        Changed = function() end,
    },
}

local Places = {
    Bottom = { 0, 1 },
    Right = { 1, 0 },
}
local Sizes = {
    Left = { 0.5, 1 },
    Right = { 0.5, 1 },
}

--// Scheme Functions \\--
local SchemeReplaceAlias = {
    RedColor = "Red",
    WhiteColor = "White",
    DarkColor = "Dark"
}

local SchemeAlias = {
    Red = "RedColor",
    White = "WhiteColor",
    Dark = "DarkColor"
}

local function GetSchemeValue(Index)
    if not Index then
        return nil
    end

    local ReplaceAliasIndex = SchemeReplaceAlias[Index]
    if ReplaceAliasIndex and Library.Scheme[ReplaceAliasIndex] ~= nil then
        Library.Scheme[Index] = Library.Scheme[ReplaceAliasIndex]
        Library.Scheme[ReplaceAliasIndex] = nil

        return Library.Scheme[Index]
    end

    local AliasIndex = SchemeAlias[Index]
    if AliasIndex and Library.Scheme[AliasIndex] ~= nil then
        return Library.Scheme[AliasIndex]
    end

    return Library.Scheme[Index]
end

--// Basic Functions \\--
local function WaitForEvent(Event, Timeout, Condition)
    local Bindable = Instance.new("BindableEvent")
    local Connection = Event:Once(function(...)
        if not Condition or typeof(Condition) == "function" and Condition(...) then
            Bindable:Fire(true)
        else
            Bindable:Fire(false)
        end
    end)
    task.delay(Timeout, function()
        Connection:Disconnect()
        Bindable:Fire(false)
    end)

    local Result = Bindable.Event:Wait()
    Bindable:Destroy()

    return Result
end

local function IsMouseInput(Input, IncludeM2)
    return Input.UserInputType == Enum.UserInputType.MouseButton1
        or (IncludeM2 == true and Input.UserInputType == Enum.UserInputType.MouseButton2)
        or Input.UserInputType == Enum.UserInputType.Touch
end
local function IsClickInput(Input, IncludeM2)
    return IsMouseInput(Input, IncludeM2)
        and Input.UserInputState == Enum.UserInputState.Begin
        and Library.IsRobloxFocused
end
local function IsHoverInput(Input)
    return (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
        and Input.UserInputState == Enum.UserInputState.Change
end
local function IsDragInput(Input, IncludeM2)
    return IsMouseInput(Input, IncludeM2)
        and (Input.UserInputState == Enum.UserInputState.Begin or Input.UserInputState == Enum.UserInputState.Change)
        and Library.IsRobloxFocused
end
local function IsMouseClickInput(Input)
    return Input.UserInputType == Enum.UserInputType.MouseButton1 or
        Input.UserInputType == Enum.UserInputType.MouseButton2 or
        Input.UserInputType == Enum.UserInputType.MouseButton3
end
local function IsMovementInput(Input)
    return (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
        and Library.IsRobloxFocused
end

local function GetTableSize(Table)
    local Size = 0

    for _, _ in Table do
        Size += 1
    end

    return Size
end
local function StopTween(Tween, Destroy)
    if not Tween then
        return
    end

    if Tween.PlaybackState == Enum.PlaybackState.Playing then
        Tween:Cancel()
    end

    if Destroy == true then
        pcall(Tween.Destroy, Tween)
    end
end
local function Trim(Text)
    return Text:match("^%s*(.-)%s*$")
end
local function Round(Value, Rounding)
    assert(Rounding >= 0, "Invalid rounding number.")

    if Rounding == 0 then
        return math.floor(Value)
    end

    return tonumber(string.format("%." .. Rounding .. "f", Value))
end

local function GetPlayers(ExcludeLocalPlayer)
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

    return PlayerList
end
local function GetTeams()
    local TeamList = Teams:GetTeams()

    table.sort(TeamList, function(Team1, Team2)
        return Team1.Name:lower() < Team2.Name:lower()
    end)

    return TeamList
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in Library.DependencyBoxes do
        Depbox:Update(true)
    end

    if Library.Searching then
        Library:UpdateSearch(Library.SearchText)
    end
end

local function CheckDepbox(Box, Search)
    local VisibleElements = 0

    for _, ElementInfo in Box.Elements do
        if ElementInfo.Type == "Divider" then
            ElementInfo.Holder.Visible = false
            continue
        elseif ElementInfo.SubButton then
            --// Check if any of the Buttons Name matches with Search
            local Visible = false

            --// Check if Search matches Element's Name and if Element is Visible
            if ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                Visible = true
            else
                ElementInfo.Base.Visible = false
            end
            if ElementInfo.SubButton.Text:lower():match(Search) and ElementInfo.SubButton.Visible then
                Visible = true
            else
                ElementInfo.SubButton.Base.Visible = false
            end
            ElementInfo.Holder.Visible = Visible
            if Visible then
                VisibleElements += 1
            end

            continue
        end

        --// Check if Search matches Element's Name and if Element is Visible
        if ElementInfo.Text and ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
            ElementInfo.Holder.Visible = true
            VisibleElements += 1
        else
            ElementInfo.Holder.Visible = false
        end
    end

    for _, Depbox in Box.DependencyBoxes do
        if not Depbox.Visible then
            continue
        end

        VisibleElements += CheckDepbox(Depbox, Search)
    end

    Box.Holder.Visible = VisibleElements > 0
    return VisibleElements
end
local function RestoreDepbox(Box)
    for _, ElementInfo in Box.Elements do
        ElementInfo.Holder.Visible = ElementInfo.Visible ~= false

        if ElementInfo.SubButton then
            ElementInfo.Base.Visible = ElementInfo.Visible
            ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
        end
    end

    Box:Resize()
    Box.Holder.Visible = true

    for _, Depbox in Box.DependencyBoxes do
        if not Depbox.Visible then
            continue
        end

        RestoreDepbox(Depbox)
    end
end

local function ApplySearchToTab(Tab, Search)
    if not Tab then
        return
    end

    local HasVisible = false

    --// Loop through Groupboxes to get Elements Info
    for _, Groupbox in Tab.Groupboxes do
        if Groupbox.Visible == false then
            continue
        end

        local VisibleElements = 0
        for _, ElementInfo in Groupbox.Elements do
            if ElementInfo.Type == "Divider" then
                ElementInfo.Holder.Visible = false
                continue
            elseif ElementInfo.SubButton then
                --// Check if any of the Buttons Name matches with Search
                local Visible = false

                --// Check if Search matches Element's Name and if Element is Visible
                if ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                    Visible = true
                else
                    ElementInfo.Base.Visible = false
                end
                if ElementInfo.SubButton.Text:lower():match(Search) and ElementInfo.SubButton.Visible then
                    Visible = true
                else
                    ElementInfo.SubButton.Base.Visible = false
                end
                ElementInfo.Holder.Visible = Visible

                if Visible then
                    VisibleElements += 1
                end

                continue
            end

            --// Check if Search matches Element's Name and if Element is Visible
            if ElementInfo.Text and ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                ElementInfo.Holder.Visible = true
                VisibleElements += 1
            else
                ElementInfo.Holder.Visible = false
            end
        end

        for _, Depbox in Groupbox.DependencyBoxes do
            if not Depbox.Visible then
                continue
            end

            VisibleElements += CheckDepbox(Depbox, Search)
        end

        --// Update Groupbox Size and Visibility if found any element
        if VisibleElements > 0 then
            Groupbox:Resize()
            HasVisible = true
        end
        Groupbox.BoxHolder.Visible = VisibleElements > 0
    end

    for _, Tabbox in Tab.Tabboxes do
        local VisibleTabs = 0
        local VisibleElements = {}

        for _, SubTab in Tabbox.Tabs do
            VisibleElements[SubTab] = 0

            for _, ElementInfo in SubTab.Elements do
                if ElementInfo.Type == "Divider" then
                    ElementInfo.Holder.Visible = false
                    continue
                elseif ElementInfo.SubButton then
                    --// Check if any of the Buttons Name matches with Search
                    local Visible = false

                    --// Check if Search matches Element's Name and if Element is Visible
                    if ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                        Visible = true
                    else
                        ElementInfo.Base.Visible = false
                    end
                    if ElementInfo.SubButton.Text:lower():match(Search) and ElementInfo.SubButton.Visible then
                        Visible = true
                    else
                        ElementInfo.SubButton.Base.Visible = false
                    end
                    ElementInfo.Holder.Visible = Visible
                    if Visible then
                        VisibleElements[SubTab] += 1
                    end

                    continue
                end

                --// Check if Search matches Element's Name and if Element is Visible
                if ElementInfo.Text and ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                    ElementInfo.Holder.Visible = true
                    VisibleElements[SubTab] += 1
                else
                    ElementInfo.Holder.Visible = false
                end
            end

            for _, Depbox in SubTab.DependencyBoxes do
                if not Depbox.Visible then
                    continue
                end

                VisibleElements[SubTab] += CheckDepbox(Depbox, Search)
            end
        end

        for SubTab, Visible in VisibleElements do
            SubTab.ButtonHolder.Visible = Visible > 0
            if Visible > 0 then
                VisibleTabs += 1
                HasVisible = true

                if Tabbox.ActiveTab == SubTab then
                    SubTab:Resize()
                elseif Tabbox.ActiveTab and VisibleElements[Tabbox.ActiveTab] == 0 then
                    SubTab:Show()
                end
            end
        end

        --// Update Tabbox Visibility if any visible
        Tabbox.BoxHolder.Visible = VisibleTabs > 0
    end

    return HasVisible
end
local function ResetTab(Tab)
    if not Tab then
        return
    end

    for _, Groupbox in Tab.Groupboxes do
        for _, ElementInfo in Groupbox.Elements do
            ElementInfo.Holder.Visible = ElementInfo.Visible ~= false

            if ElementInfo.SubButton then
                ElementInfo.Base.Visible = ElementInfo.Visible
                ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
            end
        end

        for _, Depbox in Groupbox.DependencyBoxes do
            if not Depbox.Visible then
                continue
            end

            RestoreDepbox(Depbox)
        end

        Groupbox:Resize()
        Groupbox.BoxHolder.Visible = Groupbox.Visible ~= false
    end

    for _, Tabbox in Tab.Tabboxes do
        for _, SubTab in Tabbox.Tabs do
            for _, ElementInfo in SubTab.Elements do
                ElementInfo.Holder.Visible = ElementInfo.Visible ~= false

                if ElementInfo.SubButton then
                    ElementInfo.Base.Visible = ElementInfo.Visible
                    ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
                end
            end

            for _, Depbox in SubTab.DependencyBoxes do
                if not Depbox.Visible then
                    continue
                end

                RestoreDepbox(Depbox)
            end

            SubTab.ButtonHolder.Visible = true
        end

        if Tabbox.ActiveTab then
            Tabbox.ActiveTab:Resize()
        end
        Tabbox.BoxHolder.Visible = true
    end
end

function Library:UpdateSearch(SearchText)
    Library.SearchText = SearchText

    local TabsToReset = {}

    if Library.GlobalSearch then
        for _, Tab in Library.Tabs do
            if typeof(Tab) == "table" and not Tab.IsKeyTab then
                table.insert(TabsToReset, Tab)
            end
        end
    elseif Library.LastSearchTab and typeof(Library.LastSearchTab) == "table" then
        table.insert(TabsToReset, Library.LastSearchTab)
    end

    for _, Tab in ipairs(TabsToReset) do
        ResetTab(Tab)
    end

    local Search = SearchText:lower()
    if Trim(Search) == "" then
        Library.Searching = false
        Library.LastSearchTab = nil
        return
    end
    if not Library.GlobalSearch and Library.ActiveTab and Library.ActiveTab.IsKeyTab then
        Library.Searching = false
        Library.LastSearchTab = nil
        return
    end

    Library.Searching = true

    local TabsToSearch = {}

    if Library.GlobalSearch then
        TabsToSearch = TabsToReset
        if #TabsToSearch == 0 then
            for _, Tab in Library.Tabs do
                if typeof(Tab) == "table" and not Tab.IsKeyTab then
                    table.insert(TabsToSearch, Tab)
                end
            end
        end
    elseif Library.ActiveTab then
        table.insert(TabsToSearch, Library.ActiveTab)
    end

    local FirstVisibleTab = nil
    local ActiveHasVisible = false

    for _, Tab in ipairs(TabsToSearch) do
        local HasVisible = ApplySearchToTab(Tab, Search)
        if HasVisible then
            if not FirstVisibleTab then
                FirstVisibleTab = Tab
            end
            if Tab == Library.ActiveTab then
                ActiveHasVisible = true
            end
        end
    end

    if Library.GlobalSearch then
        if ActiveHasVisible and Library.ActiveTab then
            Library.ActiveTab:RefreshSides()
        elseif FirstVisibleTab then
            local SearchMarker = SearchText
            task.defer(function()
                if Library.SearchText ~= SearchMarker then
                    return
                end

                if Library.ActiveTab ~= FirstVisibleTab then
                    FirstVisibleTab:Show()
                end
            end)
        end
        Library.LastSearchTab = nil
    else
        Library.LastSearchTab = Library.ActiveTab
    end
end

function Library:AddToRegistry(Instance, Properties)
    Library.Registry[Instance] = Properties
end

function Library:RemoveFromRegistry(Instance)
    Library.Registry[Instance] = nil
end

function Library:UpdateColorsUsingRegistry()
    for Instance, Properties in Library.Registry do
        for Property, Index in Properties do
            local SchemeValue = GetSchemeValue(Index)

            if SchemeValue or typeof(Index) == "function" then
                Instance[Property] = SchemeValue or Index()
            end
        end
    end
end

function Library:SetDPIScale(DPIScale)
    Library.DPIScale = DPIScale / 100
    Library.MinSize = Library.OriginalMinSize * Library.DPIScale

	for _, UIScale in Library.Scales do
        UIScale.Scale = Library.DPIScale - (tonumber(Library.ScalesOffset[UIScale]) or 0)
    end

    for _, Option in Options do
        if Option.Type == "Dropdown" then
            Option:RecalculateListSize()
        end
    end

    for _, Notification in Library.Notifications do
        Notification:Resize()
    end

    Library:UpdateNotificationPositions(true)
end

function Library:GiveSignal(Connection)
    local ConnectionType = typeof(Connection)
    if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
        table.insert(Library.Signals, Connection)
    end

    return Connection
end

function IsValidCustomIcon(Icon)
    return typeof(Icon) == "string" and (Icon:match("^rbxasset://textures/") or Icon:match("roblox%.com/asset/%?id=") or Icon:match("rbxthumb://type="))
end

local function IsCustomAssetIcon(Icon, IncludeAssetId)
    return typeof(Icon) == "string" and (Icon:match("^content://") or (Icon:match("^rbxasset://%x+/") or Icon:match("^rbxasset://[^/]+/")) or (IncludeAssetId == true and Icon:match("^rbxassetid://")))
end





local FetchIcons, Icons = pcall(function()
    return RequireSharedModule('obsidian_icons')
end)

function Library:GetIcon(IconName)
    if not FetchIcons or not Icons then
        return
    end

    local Success, Icon = pcall(Icons.GetAsset, IconName)
    if not Success then
        return
    end

    return Icon
end

function Library:GetCustomIcon(IconName)
    if not IconName then
        return nil
    end

    if tonumber(IconName) then
        IconName = string.format("rbxassetid://%s", tostring(IconName))
    end

    if IsCustomAssetIcon(IconName, true) then
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
        }
    elseif IsValidCustomIcon(IconName) then
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
            Custom = true,
        }
    end

    local LucideIcon = Library:GetIcon(IconName)
    if LucideIcon then
        return LucideIcon
    end

    return nil
end

function Library:Validate(Table, Template)
    if typeof(Table) ~= "table" then
        return Template
    end

    for k, v in Template do
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

--// Creator Functions \\--
local function FillInstance(Table, Instance)
    local ThemeProperties = Library.Registry[Instance] or {}

    for key, value in Table do
        if key ~= "Text" then
            local SchemeValue = GetSchemeValue(value)

            if SchemeValue or typeof(value) == "function" then
                ThemeProperties[key] = value
                value = SchemeValue or value()
            else
                ThemeProperties[key] = nil
            end
        end

        Instance[key] = value
    end

    if GetTableSize(ThemeProperties) > 0 then
        Library.Registry[Instance] = ThemeProperties
    end
end

local function New(ClassName, Properties)
    local Instance = Instance.new(ClassName)

    if Templates[ClassName] then
        FillInstance(Templates[ClassName], Instance)
    end
    FillInstance(Properties, Instance)

    if Properties["Parent"] and not Properties["ZIndex"] then
        pcall(function()
            Instance.ZIndex = Properties.Parent.ZIndex
        end)
    end

    return Instance
end

--// Main Instances \\-
local function SafeParentUI(Instance, Parent)
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
        Instance.Parent = Library.LocalPlayer:WaitForChild("PlayerGui", math.huge)
    end
end

local function ParentUI(UI, SkipHiddenUI)
    if SkipHiddenUI then
        SafeParentUI(UI, CoreGui)
        return
    end

    pcall(protectgui, UI)
    SafeParentUI(UI, gethui)
end

local ScreenGui = New("ScreenGui", {
    Name = "Obsidian",
    DisplayOrder = 998,
    ResetOnSpawn = false,
})
ParentUI(ScreenGui)
Library.ScreenGui = ScreenGui

ScreenGui.DescendantRemoving:Connect(function(Instance)
    Library:RemoveFromRegistry(Instance)
end)

local ModalElement = New("TextButton", {
    BackgroundTransparency = 1,
    Modal = false,
    Size = UDim2.fromScale(0, 0),
    AnchorPoint = Vector2.zero,
    Text = "",
    ZIndex = -999,
    Parent = ScreenGui,
})

--// Cursor
local Cursor, CursorCustomImage
do
    Cursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Size = UDim2.fromOffset(9, 1),
        Visible = false,
        ZIndex = 11000,
        Parent = ScreenGui,
    })
    New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 2, 1, 2),
        ZIndex = 10999,
        Parent = Cursor,
    })

    local CursorV = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(1, 9),
        ZIndex = 11000,
        Parent = Cursor,
    })
    New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 2, 1, 2),
        ZIndex = 10999,
        Parent = CursorV,
    })

    CursorCustomImage = New("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20),
        ZIndex = 11000,
        Visible = false,
        Parent = Cursor
    })
end

--// Notification \\--
local NotificationArea
local NotifyOrder = {}
do
    NotificationArea = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -6, 0, 6),
        Size = UDim2.new(0, 300, 1, -6),
        Parent = ScreenGui,
    })
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = NotificationArea,
        })
    )
end

--// Lib Functions \\--
function Library:ResetCursorIcon()
    CursorCustomImage.Visible = false
    CursorCustomImage.Size = UDim2.fromOffset(20, 20)
end

function Library:ChangeCursorIcon(ImageId)
    if not ImageId or ImageId == "" then
        Library:ResetCursorIcon()
        return
    end

    local Icon = Library:GetCustomIcon(ImageId)
    assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

    CursorCustomImage.Visible = true
    CursorCustomImage.Image = Icon.Url
    CursorCustomImage.ImageRectOffset = Icon.ImageRectOffset
    CursorCustomImage.ImageRectSize = Icon.ImageRectSize
end

function Library:ChangeCursorIconSize(Size)
    assert(typeof(Size) == "UDim2", "UDim2 expected.")
    CursorCustomImage.Size = Size
end

function Library:GetBetterColor(Color, Add)
    Add = Add * (Library.IsLightTheme and -4 or 2)
    return Color3.fromRGB(
        math.clamp(Color.R * 255 + Add, 0, 255),
        math.clamp(Color.G * 255 + Add, 0, 255),
        math.clamp(Color.B * 255 + Add, 0, 255)
    )
end

function Library:GetLighterColor(Color)
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV(H, math.max(0, S - 0.1), math.min(1, V + 0.1))
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV(H, S, V / 2)
end

function Library:GetKeyString(KeyCode)
    if KeyCode.EnumType == Enum.KeyCode and KeyCode.Value > 33 and KeyCode.Value < 127 then
        return string.char(KeyCode.Value)
    end

    return KeyCode.Name
end

function Library:GetTextBounds(Text, Font, Size, Width)
    local Params = Instance.new("GetTextBoundsParams")
    Params.Text = Text
    Params.RichText = true
    Params.Font = Font
    Params.Size = Size
    Params.Width = Width or workspace.CurrentCamera.ViewportSize.X - 32

    local Bounds = TextService:GetTextBoundsAsync(Params)
    return Bounds.X, Bounds.Y
end

function Library:MouseIsOverFrame(Frame, Position)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
    return Position.X >= AbsPos.X
        and Position.X <= AbsPos.X + AbsSize.X
        and Position.Y >= AbsPos.Y
        and Position.Y <= AbsPos.Y + AbsSize.Y
end

function Library:IsInsideFrame(ParentFrame, Frame)
    local GuiPos = Frame.AbsolutePosition
	local GuiSize = Frame.AbsoluteSize

	local FramePos = ParentFrame.AbsolutePosition
	local FrameSize = ParentFrame.AbsoluteSize

	return GuiPos.X >= FramePos.X
		and GuiPos.X + GuiSize.X <= FramePos.X + FrameSize.X
		and GuiPos.Y >= FramePos.Y
		and GuiPos.Y + GuiSize.Y <= FramePos.Y + FrameSize.Y
end

function Library:SafeCallback(Func, ...)
    if not (Func and typeof(Func) == "function") then
        return
    end

    local Result = table.pack(xpcall(Func, function(Error)
        task.defer(error, debug.traceback(Error, 2))
        if Library.NotifyOnError and Library.Notify then
            Library:Notify(Error)
        end

        return Error
    end, ...))

    if not Result[1] then
        return nil
    end

    return table.unpack(Result, 2, Result.n)
end

function GetOverlappingDraggable(UI, TargetPos)
    local Pos1 = TargetPos or UI.AbsolutePosition
    local Size1 = UI.AbsoluteSize

    for _, Other in ipairs(Library.DraggableElements) do
        if Other == UI or not Other.Visible or not Other.Parent then
            continue
        end

        local Pos2 = Other.AbsolutePosition
        local Size2 = Other.AbsoluteSize

        if Pos1.X < Pos2.X + Size2.X and
            Pos1.X + Size1.X > Pos2.X and
            Pos1.Y < Pos2.Y + Size2.Y and
            Pos1.Y + Size1.Y > Pos2.Y then
            return Other
        end
    end

    return nil
end

function GetNonOverlappingPosition(UI, StartPos)
    local ScreenSize = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)) - Vector2.new(100, 100)
    local Start = StartPos and Vector2.new(StartPos.X.Offset, StartPos.Y.Offset) or Vector2.new(6, 6)
    local Padding = 6

    local CurrentX = Start.X
    local CurrentY = Start.Y

    local Size = UI.AbsoluteSize
    if Size.X == 0 and Size.Y == 0 then
        RunService.RenderStepped:Wait()
        Size = UI.AbsoluteSize
    end

    if Size.X == 0 then Size = Vector2.new(150, 40) end

    local MaxXInColumn = Size.X

    while true do
        local Obstacle = GetOverlappingDraggable(UI, Vector2.new(CurrentX, CurrentY))
        if not Obstacle then
            break
        end

        if Obstacle.AbsoluteSize.X > MaxXInColumn then
            MaxXInColumn = Obstacle.AbsoluteSize.X
        end

        local NextY = Obstacle.AbsolutePosition.Y + Obstacle.AbsoluteSize.Y + Padding
        if NextY + Size.Y > ScreenSize.Y - Padding then
            local NextX = CurrentX + MaxXInColumn + Padding

            if NextX + Size.X > ScreenSize.X - Padding then
                break
            end

            CurrentY = Start.Y
            CurrentX = NextX
            MaxXInColumn = Size.X
        else
            CurrentY = NextY
        end
    end

    return UDim2.fromOffset(CurrentX, CurrentY)
end

function PositionDraggable(UI, StartPos)
    UI.Position = GetNonOverlappingPosition(UI, StartPos)
end

function Library:MakeDraggable(UI, DragFrame, IgnoreToggled, IsMainWindow)
    local StartPos
    local FramePos
    local Dragging = false
    local Changed
    local InputBegan
    local InputChanged

    InputBegan = DragFrame.InputBegan:Connect(function(Input)
        if not IsClickInput(Input) or IsMainWindow and Library.CantDragForced then
            return
        end

        StartPos = Input.Position
        FramePos = UI.Position
        Dragging = true

        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    InputChanged = UserInputService.InputChanged:Connect(function(Input)
        if
            (not IgnoreToggled and not Library.Toggled)
            or (IsMainWindow and Library.CantDragForced)
            or not (ScreenGui and ScreenGui.Parent)
        then
            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end

            return
        end

        if Dragging and IsHoverInput(Input) then
            local Delta = Input.Position - StartPos
            UI.Position =
                UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
        end
    end)

    Library:GiveSignal(InputChanged)
    Library:GiveSignal(InputBegan)

    UI.Destroying:Once(function()
        if InputChanged and InputChanged.Connected then
            InputChanged:Disconnect()
        end

        if InputBegan and InputBegan.Connected then
            InputBegan:Disconnect()
        end

        if Changed and Changed.Connected then
            Changed:Disconnect()
        end

        local IdxChanged = table.find(Library.Signals, InputChanged)
        if IdxChanged then
            table.remove(Library.Signals, IdxChanged)
        end

        local IdxBegan = table.find(Library.Signals, InputBegan)
        if IdxBegan then
            table.remove(Library.Signals, IdxBegan)
        end
    end)
end

function Library:MakeResizable(UI, DragFrame, Callback)
    local StartPos
    local FrameSize
    local Dragging = false
    local Changed
    local InputBegan
    local InputChanged

    InputBegan = DragFrame.InputBegan:Connect(function(Input)
        if not IsClickInput(Input) then
            return
        end

        StartPos = Input.Position
        FrameSize = UI.Size
        Dragging = true

        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    InputChanged = UserInputService.InputChanged:Connect(function(Input)
        if not UI.Visible or not (ScreenGui and ScreenGui.Parent) then
            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end

            return
        end

        if Dragging and IsHoverInput(Input) then
            local Delta = Input.Position - StartPos
            UI.Size = UDim2.new(
                FrameSize.X.Scale,
                math.clamp(FrameSize.X.Offset + Delta.X, Library.MinSize.X, math.huge),
                FrameSize.Y.Scale,
                math.clamp(FrameSize.Y.Offset + Delta.Y, Library.MinSize.Y, math.huge)
            )
            if Callback then
                Library:SafeCallback(Callback)
            end
        end
    end)

    Library:GiveSignal(InputChanged)
    Library:GiveSignal(InputBegan)

    UI.Destroying:Once(function()
        if InputChanged and InputChanged.Connected then
            InputChanged:Disconnect()
        end

        if InputBegan and InputBegan.Connected then
            InputBegan:Disconnect()
        end

        if Changed and Changed.Connected then
            Changed:Disconnect()
        end

        local IdxChanged = table.find(Library.Signals, InputChanged)
        if IdxChanged then
            table.remove(Library.Signals, IdxChanged)
        end

        local IdxBegan = table.find(Library.Signals, InputBegan)
        if IdxBegan then
            table.remove(Library.Signals, IdxBegan)
        end
    end)
end

function Library:MakeCover(Holder, Place)
    local Pos = Places[Place] or { 0, 0 }
    local Size = Sizes[Place] or { 1, 0.5 }

    local Cover = New("Frame", {
        AnchorPoint = Vector2.new(Pos[1], Pos[2]),
        BackgroundColor3 = Holder.BackgroundColor3,
        Position = UDim2.fromScale(Pos[1], Pos[2]),
        Size = UDim2.fromScale(Size[1], Size[2]),
        Parent = Holder,
    })

    return Cover
end

function Library:MakeLine(Frame, Info)
    local Line = New("Frame", {
        AnchorPoint = Info.AnchorPoint or Vector2.zero,
        BackgroundColor3 = "OutlineColor",
        Position = Info.Position,
        Size = Info.Size,
        ZIndex = Info.ZIndex or Frame.ZIndex,
        Parent = Frame,
    })

    return Line
end

function Library:AddOutline(Frame)
    local OutlineStroke = New("UIStroke", {
        Color = "OutlineColor",
        Thickness = 1,
        ZIndex = 2,
        Parent = Frame,
    })
    local ShadowStroke = New("UIStroke", {
        Color = "DarkColor",
        Thickness = 1.5,
        ZIndex = 1,
        Parent = Frame,
    })
    return OutlineStroke, ShadowStroke
end

function Library:AddBlank(Frame, Size)
    return New("Frame", {
        BackgroundTransparency = 1,
        Size = Size or UDim2.fromScale(0, 0),
        Parent = Frame,
    })
end

--// Animations \\--
local TransparencyCache = {}
local ActiveTabTweens = setmetatable({}, { __mode = "k" })

function Library:PlayTabAnimation(TabCanvas, Showing, OnComplete)
    if not TabCanvas then
        if OnComplete then
            OnComplete()
        end

        return
    end

    local Existing = ActiveTabTweens[TabCanvas]
    if Existing then
        StopTween(Existing, true)
        ActiveTabTweens[TabCanvas] = nil
    end

    local BaseZIndex = TabCanvas.ZIndex
    if not (Library.Animations and Library.Animations.TabSwitch) then
        TabCanvas.Visible = Showing
        TabCanvas.GroupTransparency = Showing and 0 or 1
        TabCanvas.Position = UDim2.fromScale(0, 0)
        TabCanvas.ZIndex = BaseZIndex

        if OnComplete then
            OnComplete()
        end

        return
    end

    if Showing then
        local TweenInfo = Library.TabTransitionInfo or TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local Offset = Library.TabSwipeOffset or 26
        local SwipeFrom = string.lower(Library.TabSwipeFrom or "bottom")
        local StartPosition

        if SwipeFrom == "left" then
            StartPosition = UDim2.fromOffset(-Offset, 0)
        elseif SwipeFrom == "top" then
            StartPosition = UDim2.fromOffset(0, -Offset)
        elseif SwipeFrom == "right" then
            StartPosition = UDim2.fromOffset(Offset, 0)
        else -- bottom (Default)
            StartPosition = UDim2.fromOffset(0, Offset)
        end

        TabCanvas.ZIndex = BaseZIndex + 1
        TabCanvas.GroupTransparency = 1
        TabCanvas.Position = StartPosition
        TabCanvas.Visible = true

        local Tween = TweenService:Create(TabCanvas, TweenInfo, {
            GroupTransparency = 0,
            Position = UDim2.fromScale(0, 0)
        })

        ActiveTabTweens[TabCanvas] = Tween
        Tween:Play()

        local Connection; Connection = Tween.Completed:Connect(function(PlaybackState)
            if Connection then
                Connection:Disconnect()
            end

            if ActiveTabTweens[TabCanvas] == Tween then
                ActiveTabTweens[TabCanvas] = nil
            end

            if PlaybackState == Enum.PlaybackState.Cancelled then
                return
            end

            TabCanvas.ZIndex = BaseZIndex
            if OnComplete then
                OnComplete()
            end
        end)
    else
        TabCanvas.GroupTransparency = 1
        TabCanvas.Visible = false
        TabCanvas.Position = UDim2.fromScale(0, 0)
        TabCanvas.ZIndex = BaseZIndex

        if OnComplete then
            OnComplete()
        end
    end
end

--// Deprecated \\--
function Library:MakeOutline(Frame, Corner, ZIndex)
    local Holder = New("Frame", {
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromOffset(-2, -2),
        Size = UDim2.new(1, 4, 1, 4),
        ZIndex = ZIndex,
        Parent = Frame,
    })

    local Outline = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = ZIndex,
        Parent = Holder,
    })

    if Corner and Corner > 0 then
        New("UICorner", {
            CornerRadius = UDim.new(0, Corner + 1),
            Parent = Holder,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, Corner),
            Parent = Outline,
        })
    end

    return Holder, Outline
end

function Library:AddDraggableLabel(...)
    local Params = select(1, ...)
    local Text
    local Icon
    local IconPosition = "left"

    if typeof(Params) == "table" then
        Text = Params.Text
        Icon = Params.Icon
        IconPosition = Params.IconPosition or "left"
    elseif typeof(Params) == "string" then
        Text = Params
        Icon = select(2, ...)
        IconPosition = select(3, ...) or "left"
    end

    if typeof(IconPosition) ~= "string" then
        IconPosition = "left"
    end

    IconPosition = string.lower(IconPosition)
    assert(IconPosition == "left" or IconPosition == "right", "Icon Position needs to be either 'left' or 'right'.")

    local DraggableLabel = {
        Connections = {},
        Destroyed = false
    }

    local IconImage
    local Label = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = "BackgroundColor",
        Size = UDim2.fromOffset(0, 0),
        Position = UDim2.fromOffset(6, 6),
        Text = Text,
        TextSize = 15,
        ZIndex = 10,
        Parent = ScreenGui,
    })

    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Label,
        })
    )

    local Padding = New("UIPadding", {
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 6),
        Parent = Label,
    })
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = Label,
        })
    )

    Library:AddOutline(Label)
    Library:MakeDraggable(Label, Label, true)

    function DraggableLabel:SetText(Text)
        Label.Text = Text
    end

    function DraggableLabel:SetIcon(NewIcon)
        Icon = NewIcon

        local IsNotEmpty = Icon and Trim(tostring(Icon)) ~= ""
        if IsNotEmpty then
            local CustomIcon = Library:GetCustomIcon(Icon)
            assert(CustomIcon, "Icon must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            IconImage = IconImage or New("ImageLabel", {
                BackgroundTransparency = 1,
                ImageColor3 = "FontColor",
                Size = UDim2.fromOffset(16, 16),
                ZIndex = 11,
                Parent = Label,
            })

            IconImage.Image = CustomIcon.Url
            IconImage.ImageRectOffset = CustomIcon.ImageRectOffset
            IconImage.ImageRectSize = CustomIcon.ImageRectSize
        end

        if IconImage then IconImage.Visible = IsNotEmpty end
        DraggableLabel:SetIconPosition(IconPosition)
    end

    function DraggableLabel:SetIconPosition(NewPosition)
        IconPosition = string.lower(NewPosition)
        assert(IconPosition == "left" or IconPosition == "right", "Icon Position needs to be either 'left' or 'right'.")

        local IsNotEmpty = Icon and Trim(tostring(Icon)) ~= ""
        Padding.PaddingLeft = UDim.new(0, (IsNotEmpty and IconPosition == "left") and 34 or 12)
        Padding.PaddingRight = UDim.new(0, (IsNotEmpty and IconPosition == "right") and 34 or 12)

        if IconImage then
            if IconPosition == "left" then
                IconImage.AnchorPoint = Vector2.new(0, 0.5)
                IconImage.Position = UDim2.new(0, -22, 0.5, 0)
            else
                IconImage.AnchorPoint = Vector2.new(1, 0.5)
                IconImage.Position = UDim2.new(1, 22, 0.5, 0)
            end
        end
    end

    function DraggableLabel:SetVisible(Visible)
        Label.Visible = Visible
    end

    DraggableLabel:SetIcon(Icon)
    DraggableLabel.Label = Label

    if not table.find(Library.DraggableElements, Label) then
        table.insert(Library.DraggableElements, Label)
    end

    PositionDraggable(Label, Label.Position)

    function DraggableLabel:Destroy()
        DraggableLabel.Destroyed = true

        if DraggableLabel.Connections then
            for _, connection in DraggableLabel.Connections do
                connection:Disconnect()
            end
        end

        local ElemIdx = table.find(Library.DraggableElements, Label)
        if ElemIdx then
            table.remove(Library.DraggableElements, ElemIdx)
        end

        if Label then
            Label:Destroy()
        end
    end

    return DraggableLabel
end

function Library:AddDraggableButton(...)
    local Params = select(1, ...)

    local Text
    local Func
    local ExcludeScaling
    local ExcludeDragging

    if typeof(Params) == "table" then
        Text = Params.Text
        Func = Params.Callback or Params.Func
        ExcludeScaling = Params.ExcludeScaling
        ExcludeDragging = Params.ExcludeDragging
    elseif typeof(Params) == "string" then
        Text = Params
        Func = select(2, ...)
        ExcludeScaling = select(3, ...)
        ExcludeDragging = select(4, ...)
    end

    local DraggableButton = {
        Connections = {},
        Destroyed = false
    }

    local Button = New("TextButton", {
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        TextSize = 16,
        ZIndex = 10,
        Parent = ScreenGui,
    })
    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Button,
        })
    )
    if not ExcludeScaling then
        table.insert(
            Library.Scales,
            New("UIScale", {
                Parent = Button,
            })
        )
    end
    Library:AddOutline(Button)

    local DragThreshold = if ExcludeDragging then 0.25 else math.huge
    Button.InputBegan:Connect(function(Input)
        if not IsClickInput(Input) then
            return
        end

        local Start = tick()

        local Changed
        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            local IsLikelyDragging = tick() - Start > DragThreshold
            if IsLikelyDragging then
                return
            end

            Library:SafeCallback(Func, DraggableButton)

            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    function DraggableButton:SetText(Text)
        local X, Y = Library:GetTextBounds(Text, Library.Scheme.Font, 16)

        Button.Text = Text
        Button.Size = UDim2.fromOffset(X * 2, Y * 2)
    end

    Library:MakeDraggable(Button, Button, true)
    DraggableButton:SetText(Text)
    DraggableButton.Button = Button

    if not table.find(Library.DraggableElements, Button) then
        table.insert(Library.DraggableElements, Button)
    end

    PositionDraggable(Button, Button.Position)

    function DraggableButton:Destroy()
        DraggableButton.Destroyed = true

        if DraggableButton.Connections then
            for _, connection in DraggableButton.Connections do
                connection:Disconnect()
            end
        end

        local ElemIdx = table.find(Library.DraggableElements, Button)
        if ElemIdx then
            table.remove(Library.DraggableElements, ElemIdx)
        end

        if Button then
            Button:Destroy()
        end
    end

    return DraggableButton
end

function Library:AddDraggableMenu(Name)
    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 10,
        Parent = ScreenGui,
    })
    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Holder,
        })
    )
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = Holder,
        })
    )
    Library:AddOutline(Holder)

    Library:MakeLine(Holder, {
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 1),
    })

    local Label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Text = Name,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = Label,
    })

    local Container = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 35),
        Size = UDim2.new(1, 0, 1, -35),
        Parent = Holder,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 7),
        Parent = Container,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        PaddingTop = UDim.new(0, 7),
        Parent = Container,
    })

    Library:MakeDraggable(Holder, Label, true)

    if not table.find(Library.DraggableElements, Holder) then
        table.insert(Library.DraggableElements, Holder)
    end

    PositionDraggable(Holder, Holder.Position)

    return Holder, Container
end

function Library:AddDraggableImageButton(...)
    local Params = select(1, ...)

    local Icon
    local IconSize
    local Func
    local ExcludeScaling
    local ExcludeDragging

    if typeof(Params) == "table" then
        Icon = Params.Icon
        IconSize = Params.IconSize or 24
        Func = Params.Callback or Params.Func
        ExcludeScaling = Params.ExcludeScaling
        ExcludeDragging = Params.ExcludeDragging
    elseif typeof(Params) == "string" or typeof(Params) == "number" then
        Icon = Params
        IconSize = select(2, ...)
        Func = select(3, ...)
        ExcludeScaling = select(4, ...)
        ExcludeDragging = select(5, ...)
    end

    local DraggableImageButton = {}

    local Button = New("TextButton", {
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(IconSize + 12, IconSize + 12),
        Text = "",
        ZIndex = 10,
        Parent = ScreenGui,
    })

    local IconImage = New("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(IconSize, IconSize),
        ImageColor3 = "FontColor",
        ZIndex = 11,
        Parent = Button,
    })

    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Button,
        })
    )
    if not ExcludeScaling then
        table.insert(
            Library.Scales,
            New("UIScale", {
                Parent = Button,
            })
        )
    end
    Library:AddOutline(Button)

    local DragThreshold = if ExcludeDragging then 0.25 else math.huge
    Button.InputBegan:Connect(function(Input)
        if not IsClickInput(Input) then
            return
        end

        local Start = tick()

        local Changed
        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            local IsLikelyDragging = tick() - Start > DragThreshold
            if IsLikelyDragging then
                return
            end

            Library:SafeCallback(Func, DraggableImageButton)

            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    function DraggableImageButton:SetIcon(NewIcon)
        Icon = NewIcon or Icon

        local CustomIcon = Library:GetCustomIcon(Icon)
        assert(CustomIcon, "Icon must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        IconImage.Image = CustomIcon.Url
        IconImage.ImageRectOffset = CustomIcon.ImageRectOffset
        IconImage.ImageRectSize = CustomIcon.ImageRectSize
    end

    function DraggableImageButton:SetIconSize(NewSize)
        IconSize = NewSize
        IconImage.Size = UDim2.fromOffset(IconSize, IconSize)
        Button.Size = UDim2.fromOffset(IconSize + 12, IconSize + 12)
    end

    Library:MakeDraggable(Button, Button, true)
    DraggableImageButton:SetIcon(Icon)
    DraggableImageButton.Button = Button

    if not table.find(Library.DraggableElements, Button) then
        table.insert(Library.DraggableElements, Button)
    end

    PositionDraggable(Button, Button.Position)

    return DraggableImageButton
end

--// Watermark - Deprecated \\--
do
    local WatermarkLabel = Library:AddDraggableLabel("")
    WatermarkLabel:SetVisible(false)

    function Library:SetWatermark(Text)
        WatermarkLabel:SetText(Text)
    end

    function Library:SetWatermarkVisibility(Visible)
        WatermarkLabel:SetVisible(Visible)
    end
end

--// Context Menu \\--
local CurrentMenu
function Library:AddContextMenu(
    Holder,
    Size,
    Offset,
    List,
    ActiveCallback,
    IgnoreCornerRadius,
    SpecificCornersOnly, -- stupid way of doing this
    AnimationType
)
    local Menu
    local ParentGui = Holder:FindFirstAncestorOfClass("ScreenGui")
    local MenuZIndex = math.max(10, Holder.ZIndex + 1)
    if ParentGui ~= ScreenGui and (Library.ActiveLoading and ParentGui ~= Library.ActiveLoading.ScreenGui) then
        ParentGui = ScreenGui
    end

    if List then
        Menu = New("ScrollingFrame", {
            AutomaticCanvasSize = List == 2 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
            AutomaticSize = List == 1 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
            BackgroundColor3 = "BackgroundColor",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarImageColor3 = "OutlineColor",
            ScrollBarThickness = List == 2 and 2 or 0,
            Size = typeof(Size) == "function" and Size() or Size,
            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            Visible = false,
            ZIndex = MenuZIndex,
            Parent = ParentGui,
        })
    else
        Menu = New("Frame", {
            BackgroundColor3 = "BackgroundColor",
            Size = typeof(Size) == "function" and Size() or Size,
            Visible = false,
            ZIndex = MenuZIndex,
            Parent = ParentGui,
        })
    end
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = Menu,
        })
    )

    New("UIStroke", {
        Color = "OutlineColor",
        Parent = Menu,
    })

    local Corner;
    if IgnoreCornerRadius ~= true then
        if SpecificCornersOnly == "top" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, 0),
                BottomLeftRadius = UDim.new(0, 0),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "bottom" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, 0),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "no_left" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, 0),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "no_top_left" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        else
            Corner = New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.Corners, Corner)
        end
    end

    local Table = {
        Connections = {},
        Destroyed = false,

        Active = false,
        Holder = Holder,
        Menu = Menu,
        List = nil,
        Signal = nil,

        Size = Size,

        AutoSizeY = List == 1,
        OpenCloseTween = nil,
        Animated = function()
            if not AnimationType or AnimationType == "none" then
                return false
            end

            if not (Library.Animations and Library.Animations[AnimationType] == true) then
                return false
            end

            return true, Library[string.format("%sTransitionInfo", AnimationType)] or TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    }

    if List then
        Table.List = New("UIListLayout", {
            Parent = Menu,
        })
    end

    function Table:Open()
        if CurrentMenu == Table then
            return
        elseif CurrentMenu then
            CurrentMenu:Close()
        end

        CurrentMenu = Table
        Table.Active = true

        if typeof(Offset) == "function" then
            Menu.Position = UDim2.fromOffset(
                math.floor(Holder.AbsolutePosition.X + Offset()[1]),
                math.floor(Holder.AbsolutePosition.Y + Offset()[2])
            )
        else
            Menu.Position = UDim2.fromOffset(
                math.floor(Holder.AbsolutePosition.X + Offset[1]),
                math.floor(Holder.AbsolutePosition.Y + Offset[2])
            )
        end

        local TargetSize = typeof(Table.Size) == "function" and Table.Size() or Table.Size

        if typeof(ActiveCallback) == "function" then
            Library:SafeCallback(ActiveCallback, true)
        end

        if Table.OpenCloseTween then
            StopTween(Table.OpenCloseTween, true)
            Table.OpenCloseTween = nil
        end

        local IsAnimated, TweenInfo = Table.Animated()
        if IsAnimated == true then
            local OpenSize = TargetSize
            if Table.AutoSizeY then
                local FullHeight = Menu.AbsoluteSize.Y

                Menu.AutomaticSize = Enum.AutomaticSize.None
                OpenSize = UDim2.new(TargetSize.X.Scale, TargetSize.X.Offset, 0, FullHeight)
            end

            Menu.Size = UDim2.new(OpenSize.X.Scale, OpenSize.X.Offset, 0, 0)
            Menu.Visible = true

            local Tween = TweenService:Create(Menu, TweenInfo, { Size = OpenSize })
            Table.OpenCloseTween = Tween

            local Connection; Connection = Library:GiveSignal(Tween.Completed:Once(function()
                if Connection then
                    Connection:Disconnect()
                end

                if Table.OpenCloseTween == Tween then
                    StopTween(Table.OpenCloseTween, true)
                    Table.OpenCloseTween = nil

                    if Table.AutoSizeY then
                        Menu.AutomaticSize = Enum.AutomaticSize.Y
                    end
                end
            end))

            Tween:Play()
        else
            Menu.Size = TargetSize
            Menu.Visible = true
        end

        Table.Signal = Holder:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if typeof(Offset) == "function" then
                Menu.Position = UDim2.fromOffset(
                    math.floor(Holder.AbsolutePosition.X + Offset()[1]),
                    math.floor(Holder.AbsolutePosition.Y + Offset()[2])
                )
            else
                Menu.Position = UDim2.fromOffset(
                    math.floor(Holder.AbsolutePosition.X + Offset[1]),
                    math.floor(Holder.AbsolutePosition.Y + Offset[2])
                )
            end

            if not Library:IsInsideFrame(Library.WindowContainer, Holder) and Table.Active then
                Table:Close()
            end
        end)
    end

    function Table:Close()
        if CurrentMenu ~= Table then
            return
        end

        if Table.Signal then
            Table.Signal:Disconnect()
            Table.Signal = nil
        end

        Table.Active = false
        CurrentMenu = nil

        if typeof(ActiveCallback) == "function" then
            Library:SafeCallback(ActiveCallback, false)
        end

        if Table.OpenCloseTween then
            StopTween(Table.OpenCloseTween, true)
            Table.OpenCloseTween = nil
        end

        local IsAnimated, TweenInfo = Table.Animated()
        if IsAnimated == true then
            if Table.AutoSizeY then
                Menu.AutomaticSize = Enum.AutomaticSize.None
            end

            local CurrentSize = Menu.Size
            local CollapsedSize = UDim2.new(CurrentSize.X.Scale, CurrentSize.X.Offset, 0, 0)

            local Tween = TweenService:Create(Menu, TweenInfo, { Size = CollapsedSize })
            Table.OpenCloseTween = Tween

            local Connection; Connection = Library:GiveSignal(Tween.Completed:Once(function(PlaybackState)
                if Connection then
                    Connection:Disconnect()
                end

                if Table.OpenCloseTween == Tween then
                    StopTween(Table.OpenCloseTween, true)
                    Table.OpenCloseTween = nil

                    Menu.Visible = false
                    if Table.AutoSizeY then
                        Menu.AutomaticSize = Enum.AutomaticSize.Y
                    end
                end
            end))

            Tween:Play()
        else
            Menu.Visible = false
        end
    end

    function Table:Toggle()
        if Table.Active then
            Table:Close()
        else
            Table:Open()
        end
    end

    function Table:SetSize(Size)
        Table.Size = Size
        Menu.Size = typeof(Size) == "function" and Size() or Size
    end

    function Table:Destroy()
        Table.Destroyed = true

        if Table.Connections then
            for _, Connection in Table.Connections do
                Connection:Disconnect()
            end
        end

        if CurrentMenu == Table then
            Table:Close()
        end

        if Table.OpenCloseTween then
            StopTween(Table.OpenCloseTween, true)
            Table.OpenCloseTween = nil
        end

        if Menu then
            Menu:Destroy()
        end
    end

    return Table
end

Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
    if Library.Unloaded then
        return
    end

    if IsClickInput(Input, true) then
        local Location = Input.Position

        if
            CurrentMenu
            and not (
                Library:MouseIsOverFrame(CurrentMenu.Menu, Location)
                or Library:MouseIsOverFrame(CurrentMenu.Holder, Location)
            )
        then
            CurrentMenu:Close()
        end
    end
end))

--// Tooltip \\--
local TooltipLabel = New("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = "BackgroundColor",
    TextSize = 14,
    TextWrapped = true,
    Visible = false,
    ZIndex = 20,
    Parent = ScreenGui,
})
New("UIPadding", {
    PaddingBottom = UDim.new(0, 2),
    PaddingLeft = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 4),
    PaddingTop = UDim.new(0, 2),
    Parent = TooltipLabel,
})
table.insert(
    Library.Scales,
    New("UIScale", {
        Parent = TooltipLabel,
    })
)
New("UIStroke", {
    Color = "OutlineColor",
    Parent = TooltipLabel,
})
table.insert(
    Library.Corners,
    New("UICorner", {
        CornerRadius = UDim.new(0, Library.CornerRadius / 2),
        Parent = TooltipLabel,
    })
)
TooltipLabel:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
    if Library.Unloaded then
        return
    end

    local X, _ = Library:GetTextBounds(
        TooltipLabel.Text,
        TooltipLabel.FontFace,
        TooltipLabel.TextSize,
        (workspace.CurrentCamera.ViewportSize.X - TooltipLabel.AbsolutePosition.X - 8) / Library.DPIScale
    )

    TooltipLabel.Size = UDim2.fromOffset(X + 8, 0)
end)

local CurrentHoverInstance
function Library:AddTooltip(InfoStr, DisabledInfoStr, HoverInstance)
    local TooltipTable = {
        Disabled = false,
        Hovering = false,
        Signals = {},
    }

    local function DoHover()
        if
            CurrentHoverInstance == HoverInstance
            or Library.ActiveDialog
            or (CurrentMenu and Library:MouseIsOverFrame(CurrentMenu.Menu, GetPointerLocation()))
            or (TooltipTable.Disabled and typeof(DisabledInfoStr) ~= "string")
            or (not TooltipTable.Disabled and typeof(InfoStr) ~= "string")
        then
            return
        end
        CurrentHoverInstance = HoverInstance

        local ParentGui = HoverInstance:FindFirstAncestorOfClass("ScreenGui")
        if ParentGui ~= ScreenGui and (Library.ActiveLoading and ParentGui ~= Library.ActiveLoading.ScreenGui) then
            ParentGui = ScreenGui
        end
        TooltipLabel.Parent = ParentGui

        TooltipLabel.Text = TooltipTable.Disabled and DisabledInfoStr or InfoStr
        TooltipLabel.Visible = true

        while
            (Library.Toggled or Library.ActiveLoading)
            and not Library.ActiveDialog
            and Library:MouseIsOverFrame(HoverInstance, GetPointerLocation())
            and not (CurrentMenu and Library:MouseIsOverFrame(CurrentMenu.Menu, GetPointerLocation()))
        do
            TooltipLabel.Position = UDim2.fromOffset(
                GetPointerLocation().X + (Library.ShowCustomCursor and 8 or 14),
                GetPointerLocation().Y + (Library.ShowCustomCursor and 8 or 12)
            )

            RunService.RenderStepped:Wait()
        end

        TooltipLabel.Visible = false
        CurrentHoverInstance = nil
    end

    local function GiveSignal(Connection)
        local ConnectionType = typeof(Connection)
        if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
            table.insert(TooltipTable.Signals, Connection)
        end

        return Connection
    end

    GiveSignal(HoverInstance.MouseEnter:Connect(DoHover))
    GiveSignal(HoverInstance.MouseMoved:Connect(DoHover))
    GiveSignal(HoverInstance.MouseLeave:Connect(function()
        if CurrentHoverInstance ~= HoverInstance then
            return
        end

        TooltipLabel.Visible = false
        CurrentHoverInstance = nil
    end))

    function TooltipTable:Destroy()
        for Index = #TooltipTable.Signals, 1, -1 do
            local Connection = table.remove(TooltipTable.Signals, Index)
            if Connection and Connection.Connected then
                Connection:Disconnect()
            end
        end

        if CurrentHoverInstance == HoverInstance then
            if TooltipLabel then
                TooltipLabel.Visible = false
            end

            CurrentHoverInstance = nil
        end
    end

    table.insert(Tooltips, TooltipLabel)
    return TooltipTable
end

function Library:OnUnload(Callback)
    table.insert(Library.UnloadSignals, Callback)
end

local CheckIcon = Library:GetIcon("check")
local ArrowIcon = Library:GetIcon("chevron-up")
local ResizeIcon = Library:GetIcon("move-diagonal-2")
local KeyIcon = Library:GetIcon("key")
local MoveIcon = Library:GetIcon("move")

function Library:SetIconModule(module)
    FetchIcons = true
    Icons = module

    -- Top ten fixes 🚀
    CheckIcon = Library:GetIcon("check")
    ArrowIcon = Library:GetIcon("chevron-up")
    ResizeIcon = Library:GetIcon("move-diagonal-2")
    KeyIcon = Library:GetIcon("key")
    MoveIcon = Library:GetIcon("move")
end

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddKeyPicker(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.KeyPicker)

        local ParentObj = self
        local ToggleLabel = ParentObj.TextLabel

        if ParentObj.Type == "Button" or ParentObj.Type == "SubButton" then
            assert(Info.Mode == "Press", "KeyPicker on Buttons can only be applied with the 'Press' mode.")

            ToggleLabel = ParentObj.Base
        end

        local KeyPicker = {
            Connections = {},

            Text = Info.Text,
            Value = Info.Default, -- Key
            Modifiers = Info.DefaultModifiers, -- Modifiers
            DisplayValue = Info.Default, -- Picker Text

            Blacklisted = Info.Blacklisted,
            BlacklistedModifiers = Info.BlacklistedModifiers,
            Whitelisted = Info.Whitelisted,
            WhitelistedModifiers = Info.WhitelistedModifiers,

            Toggled = false,
            Mode = Info.Mode,
            SyncToggleState = Info.SyncToggleState,

            Callback = Info.Callback,
            ChangedCallback = Info.ChangedCallback,
            Changed = Info.Changed,
            Clicked = Info.Clicked,

            Type = "KeyPicker",
        }

        if KeyPicker.Mode == "Press" then
            assert(ParentObj.Type == "Label" or ParentObj.Type == "Button" or ParentObj.Type == "SubButton", "KeyPicker with the mode 'Press' can be only applied on Labels and Buttons.")

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
        local IsForButton = ParentObj.Type == "Button" or ParentObj.Type == "SubButton"

        -- Special Keys
        local SpecialKeys = {
            ["MB1"] = Enum.UserInputType.MouseButton1,
            ["MB2"] = Enum.UserInputType.MouseButton2,
            ["MB3"] = Enum.UserInputType.MouseButton3,
        }

        local SpecialKeysInput = {
            [Enum.UserInputType.MouseButton1] = "MB1",
            [Enum.UserInputType.MouseButton2] = "MB2",
            [Enum.UserInputType.MouseButton3] = "MB3",
        }

        -- Modifiers
        local Modifiers = {
            ["LAlt"] = Enum.KeyCode.LeftAlt,
            ["RAlt"] = Enum.KeyCode.RightAlt,

            ["LCtrl"] = Enum.KeyCode.LeftControl,
            ["RCtrl"] = Enum.KeyCode.RightControl,

            ["LShift"] = Enum.KeyCode.LeftShift,
            ["RShift"] = Enum.KeyCode.RightShift,

            ["Tab"] = Enum.KeyCode.Tab,
            ["CapsLock"] = Enum.KeyCode.CapsLock,
        }

        local ModifiersInput = {
            [Enum.KeyCode.LeftAlt] = "LAlt",
            [Enum.KeyCode.RightAlt] = "RAlt",

            [Enum.KeyCode.LeftControl] = "LCtrl",
            [Enum.KeyCode.RightControl] = "RCtrl",

            [Enum.KeyCode.LeftShift] = "LShift",
            [Enum.KeyCode.RightShift] = "RShift",

            [Enum.KeyCode.Tab] = "Tab",
            [Enum.KeyCode.CapsLock] = "CapsLock",
        }

        local IsModifierInput = function(Input)
            return Input.UserInputType == Enum.UserInputType.Keyboard and ModifiersInput[Input.KeyCode] ~= nil
        end

        local GetActiveModifiers = function()
            local ActiveModifiers = {}

            for Name, Input in Modifiers do
                if table.find(ActiveModifiers, Name) then
                    continue
                end
                if not UserInputService:IsKeyDown(Input) then
                    continue
                end

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
                if table.find(ActiveModifiers, Name) then
                    continue
                end

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
                return UserInputService:IsMouseButtonPressed(Input.UserInputType)
                    and not UserInputService:GetFocusedTextBox()
            elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                return UserInputService:IsKeyDown(Input.KeyCode) and not UserInputService:GetFocusedTextBox()
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
                if not Modifiers[name] then
                    continue
                end

                table.insert(ValidModifiers, name)
            end

            return ValidModifiers
        end

        KeyPicker.Modifiers = VerifyModifiers(KeyPicker.Modifiers)

        local SlideOverflow = true
        local MaxPickerWidth = 75
        local SlidingLabel

        local LastPickerWidth = 0
        local SlideForwardTween
        local SlideBackTween
        local HandleForwardTween = function(State)
            if State ~= Enum.PlaybackState.Completed then
                return
            end

            task.wait(1.5)
            if SlideBackTween then
                SlideBackTween:Play()
            end
        end

        local HandleBackTween = function(State)
            if State ~= Enum.PlaybackState.Completed then
                return
            end

            task.wait(1.5)
            if SlideForwardTween then
                SlideForwardTween:Play()
            end
        end

        local CancelSlidingTweens = function()
            if SlideForwardTween then
                StopTween(SlideForwardTween, true)
                SlideForwardTween = nil
            end

            if SlideBackTween then
                SlideForwardTween(SlideBackTween, true)
                SlideBackTween = nil
            end
        end

        local Picker = New("TextButton", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromOffset(18, 18),
            Text = (IsForButton and SlideOverflow) and "" or KeyPicker.Value,
            TextSize = 14,
            Parent = ToggleLabel,
        })

        if IsForButton and SlideOverflow then
            Picker.ClipsDescendants = true

            SlidingLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Text = KeyPicker.Value,
                TextSize = 14,
                FontFace = Picker.FontFace,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = Picker,
            })

            Library:AddToRegistry(SlidingLabel, {
                TextColor3 = "FontColor",
            })
        end

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = Picker,
        })

        local PickerCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = Picker,
        }); table.insert(Library.SpecificCorners, PickerCorner)

        if IsForButton then
            local Holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 21),
                Parent = ToggleLabel.Parent,
            })

            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalFlex = Enum.UIFlexAlignment.Fill,
                Padding = UDim.new(0, 9),
                Parent = Holder,
            })

            ToggleLabel.Parent = Holder
            Picker.Parent = Holder

            Picker.Size = UDim2.new(0, 18, 1, 0)
        end

        local KeybindsToggle = { Normal = KeyPicker.Mode ~= "Toggle" }
        do
            local Holder = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Text = "",
                Visible = not Info.NoUI,
                Parent = Library.KeybindContainer,
            })

            local Label = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(0, 1),
                Text = "",
                TextSize = 14,
                TextTransparency = 0.5,
                Parent = Holder,
            })

            local Checkbox = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "MainColor",
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(14, 14),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = Holder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Checkbox,
                })
            )
            New("UIStroke", {
                Color = "OutlineColor",
                Parent = Checkbox,
            })

            local CheckImage = New("ImageLabel", {
                Image = CheckIcon and CheckIcon.Url or "",
                ImageColor3 = "FontColor",
                ImageRectOffset = CheckIcon and CheckIcon.ImageRectOffset or Vector2.zero,
                ImageRectSize = CheckIcon and CheckIcon.ImageRectSize or Vector2.zero,
                ImageTransparency = 1,
                Position = UDim2.fromOffset(2, 2),
                Size = UDim2.new(1, -4, 1, -4),
                Parent = Checkbox,
            })

            function KeybindsToggle:Display(State)
                Label.TextTransparency = State and 0 or 0.5
                CheckImage.ImageTransparency = State and 0 or 1
            end

            function KeybindsToggle:SetText(Text)
                Label.Text = Text
            end

            function KeybindsToggle:SetVisibility(Visibility)
                Holder.Visible = Visibility
            end

            function KeybindsToggle:SetNormal(Normal)
                KeybindsToggle.Normal = Normal

                Holder.Active = not Normal
                Label.Position = Normal and UDim2.fromOffset(0, 0) or UDim2.fromOffset(22, 0)
                Checkbox.Visible = not Normal
            end

            KeyPicker.DoClick = function(...) end --// make luau lsp shut up
            Holder.MouseButton1Click:Connect(function()
                if KeybindsToggle.Normal then
                    return
                end

                KeyPicker.Toggled = not KeyPicker.Toggled
                KeyPicker:DoClick()
            end)

            KeybindsToggle.Holder = Holder
            KeybindsToggle.Label = Label
            KeybindsToggle.Checkbox = Checkbox
            KeybindsToggle.Loaded = true
            table.insert(Library.KeybindToggles, KeybindsToggle)
        end

        local ModeButtons = {}
        local TotalModeButtons = GetTableSize(Info.Modes)
        local MenuTable = Library:AddContextMenu(Picker, UDim2.fromOffset(62, 0), function()
            return { Picker.AbsoluteSize.X + 1.5, 0.5 }
        end, 1, function(Active)
            PickerCorner.TopRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            PickerCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
        end, false, if TotalModeButtons == 1 then "no_left" else "no_top_left", "KeyPicker")
        KeyPicker.Menu = MenuTable

        for Index, Mode in Info.Modes do
            local ModeButton = {}

            local Button = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, IsForButton and 21 or (TotalModeButtons == 1 and 18 or 19)),
                Text = Mode,
                TextSize = 14,
                TextTransparency = 0.5,
                Parent = MenuTable.Menu,
            })

            if Index == 1 and TotalModeButtons == 1 then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomLeftRadius = UDim.new(0, 0),
                    BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                }))
            elseif Index == 1 then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomLeftRadius = UDim.new(0, 0),
                    BottomRightRadius = UDim.new(0, 0),
                    Parent = Button,
                }))
            elseif Index == TotalModeButtons then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, 0),
                    BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                }))
            end

            function ModeButton:Select()
                for _, Button in ModeButtons do
                    Button:Deselect()
                end

                KeyPicker.Mode = Mode

                Button.BackgroundTransparency = 0
                Button.TextTransparency = 0

                MenuTable:Close()
            end

            function ModeButton:Deselect()
                KeyPicker.Mode = nil

                Button.BackgroundTransparency = 1
                Button.TextTransparency = 0.5
            end

            Button.MouseButton1Click:Connect(function()
                ModeButton:Select()
            end)

            if KeyPicker.Mode == Mode then
                ModeButton:Select()
            end

            ModeButtons[Mode] = ModeButton
        end

        function KeyPicker:Display(PickerText)
            if Library.Unloaded then
                return
            end

            local DisplayText = PickerText or KeyPicker.DisplayValue
            if IsForButton and SlideOverflow then
                if LastPickerWidth == Picker.AbsoluteSize.X then
                    return
                end

                local X, _Y = Library:GetTextBounds(
                    DisplayText,
                    Picker.FontFace,
                    Picker.TextSize,
                    10000
                )

                SlidingLabel.Text = DisplayText

                local OffsetScale = X + 9
                local PickerWidth = math.min(OffsetScale, MaxPickerWidth)
                Picker.Size = UDim2.new(0, PickerWidth, 1, 0)

                if OffsetScale > PickerWidth then
                    SlidingLabel.TextXAlignment = Enum.TextXAlignment.Left
                    SlidingLabel.Size = UDim2.new(0, OffsetScale, 1, 0)
                    SlidingLabel.Position = UDim2.fromOffset(4.5, 0)

                    RunService.RenderStepped:Wait()

                    local RealPickerWidth = Picker.AbsoluteSize.X
                    if RealPickerWidth <= 0 then RealPickerWidth = PickerWidth end

                    LastPickerWidth = RealPickerWidth

                    local OverflowDistance = OffsetScale - RealPickerWidth - 4.5
                    if OverflowDistance > 0 then
                        CancelSlidingTweens()

                        local Duration = OverflowDistance / 25
                        local TweenInfo = TweenInfo.new(
                            Duration,
                            Enum.EasingStyle.Linear, Enum.EasingDirection.InOut
                        )

                        SlideForwardTween = TweenService:Create(SlidingLabel, TweenInfo, {
                            Position = UDim2.fromOffset(-OverflowDistance, 0)
                        })

                        SlideBackTween = TweenService:Create(SlidingLabel, TweenInfo, {
                            Position = UDim2.fromOffset(4.5, 0)
                        })

                        SlideForwardTween:Play()

                        SlideForwardTween.Completed:Connect(HandleForwardTween)
                        SlideBackTween.Completed:Connect(HandleBackTween)
                    else
                        CancelSlidingTweens()

                        SlidingLabel.TextXAlignment = Enum.TextXAlignment.Center
                        SlidingLabel.Size = UDim2.new(1, 0, 1, 0)
                        SlidingLabel.Position = UDim2.new(0, 0, 0, 0)
                    end
                else
                    CancelSlidingTweens()

                    SlidingLabel.TextXAlignment = Enum.TextXAlignment.Center
                    SlidingLabel.Size = UDim2.new(1, 0, 1, 0)
                    SlidingLabel.Position = UDim2.new(0, 0, 0, 0)
                end
            else
                local X, Y = Library:GetTextBounds(
                    DisplayText,
                    Picker.FontFace,
                    Picker.TextSize,
                    ToggleLabel.AbsoluteSize.X
                )
                Picker.Text = DisplayText
                Picker.Size = IsForButton and UDim2.new(0, X + 9, 1, 0) or UDim2.fromOffset((X + 9), (Y + 4))
            end
        end

        function KeyPicker:Update()
            KeyPicker:Display()

            if Info.NoUI then
                return
            end

            if KeyPicker.Mode == "Toggle" and ParentObj.Type == "Toggle" and ParentObj.Disabled then
                KeybindsToggle:SetVisibility(false)
                return
            end

            local State = KeyPicker:GetState()
            local ShowToggle = Library.ShowToggleFrameInKeybinds and KeyPicker.Mode == "Toggle"

            if KeyPicker.SyncToggleState and ParentObj.Value ~= State then
                ParentObj:SetValue(State)
            end

            if KeybindsToggle.Loaded then
                if ShowToggle then
                    KeybindsToggle:SetNormal(false)
                else
                    KeybindsToggle:SetNormal(true)
                end

                KeybindsToggle:SetText(("[%s] %s (%s)"):format(KeyPicker.DisplayValue, KeyPicker.Text, KeyPicker.Mode))
                KeybindsToggle:SetVisibility(true)
                KeybindsToggle:Display(State)
            end
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

                if Picking then
                    return false
                end

                if SpecialKeys[Key] ~= nil then
                    if Library.Toggled then
                        return false
                    end

                    return UserInputService:IsMouseButtonPressed(SpecialKeys[Key])
                        and not UserInputService:GetFocusedTextBox()
                else
                    return UserInputService:IsKeyDown(Enum.KeyCode[Key]) and not UserInputService:GetFocusedTextBox()
                end
            else
                return KeyPicker.Toggled
            end
        end

        function KeyPicker:OnChanged(Func)
            KeyPicker.Changed = Func
        end

        function KeyPicker:OnClick(Func)
            KeyPicker.Clicked = Func
        end

        function KeyPicker:DoClick()
            if Picking then
                return
            end

            if KeyPicker.Mode == "Press" then
                if KeyPicker.Toggled and Info.WaitForCallback == true then
                    return
                end

				KeyPicker.Toggled = true
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)

            if IsForButton then
                Library:SafeCallback(ParentObj.Func, KeyPicker.Toggled)
			end

			if Library.ToggleKeybind == KeyPicker and Library.Toggle then
                Library:Toggle()
            end

			if KeyPicker.Mode == "Press" then
                KeyPicker.Toggled = false
            end
        end

        function KeyPicker:RunChanged(IsKeyValid, KeyCode)
            if IsKeyValid == nil or KeyCode == nil then
                IsKeyValid, KeyCode = pcall(function()
                    if KeyPicker.Value == "None" then
                        return nil
                    end

                    if SpecialKeys[KeyPicker.Value] == nil then
                        return Enum.KeyCode[KeyPicker.Value]
                    end

                    return SpecialKeys[KeyPicker.Value]
                end)
            end

            local NewModifiers = ConvertToInputModifiers(KeyPicker.Modifiers)
            Library:SafeCallback(KeyPicker.ChangedCallback, KeyCode, NewModifiers)
            Library:SafeCallback(KeyPicker.Changed, KeyCode, NewModifiers)
        end

        function KeyPicker:SetValue(Data)
            local Key, Mode, Modifiers = Data[1], Data[2], Data[3]

            local IsKeyValid, KeyCode = pcall(function()
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

            KeyPicker.Modifiers =
                VerifyModifiers(if typeof(Modifiers) == "table" then Modifiers else KeyPicker.Modifiers)
            KeyPicker.DisplayValue = if GetTableSize(KeyPicker.Modifiers) > 0
                then (table.concat(KeyPicker.Modifiers, " + ") .. " + " .. KeyPicker.Value)
                else KeyPicker.Value

            if ModeButtons[Mode] then
                ModeButtons[Mode]:Select()
            end

            KeyPicker:Update()
            KeyPicker:RunChanged(IsKeyValid, KeyCode)
        end

        function KeyPicker:SetText(Text)
            KeybindsToggle:SetText(Text)
            KeyPicker:Update()
        end

        local SetPickingState = function(State)
            Picking = State
            Library.IsPicking = State

            if ParentObj then
                ParentObj.AnyKeyPickerPicking = Picking
            end

            if IsForButton then
                ToggleLabel.Visible = not Picking
                RunService.RenderStepped:Wait()
            end

            KeyPicker:Update()
        end

        Picker.MouseButton1Click:Connect(function()
            if Picking or Library.IsPicking then
                return
            end

            SetPickingState(true)

            if IsForButton and SlideOverflow then
                KeyPicker:Display("...")
            else
                Picker.Text = "..."
                Picker.Size = IsForButton and UDim2.new(0, 29, 1, 0) or UDim2.fromOffset(29, 18)
            end

            -- Wait for any input --
            local ActiveModifiers = {}
            local CurrentInput = nil

            local IsValidInput = function(InputObj)
                if InputObj.KeyCode == Enum.KeyCode.Escape then
                    return true
                end

                local IsMod = IsModifierInput(InputObj)
                local KeyName
                if SpecialKeysInput[InputObj.UserInputType] ~= nil then
                    KeyName = SpecialKeysInput[InputObj.UserInputType]
                elseif InputObj.UserInputType == Enum.UserInputType.Keyboard then
                    if IsMod then
                        KeyName = ModifiersInput[InputObj.KeyCode]
                    else
                        KeyName = InputObj.KeyCode.Name
                    end
                end

                if KeyName then
                    if IsMod then
                        if KeyPicker.WhitelistedModifiers and #KeyPicker.WhitelistedModifiers > 0 and not table.find(KeyPicker.WhitelistedModifiers, KeyName) then
                            return false
                        end

                        if KeyPicker.BlacklistedModifiers and table.find(KeyPicker.BlacklistedModifiers, KeyName) then
                            return false
                        end
                    else
                        if KeyPicker.Whitelisted and #KeyPicker.Whitelisted > 0 and not table.find(KeyPicker.Whitelisted, KeyName) then
                            return false
                        end

                        if KeyPicker.Blacklisted and table.find(KeyPicker.Blacklisted, KeyName) then
                            return false
                        end
                    end
                end

                return true
            end

            -- Wait for the first valid InputBegan --
            while true do
                local InputObj = UserInputService.InputBegan:Wait()
                if UserInputService:GetFocusedTextBox() ~= nil then
                    SetPickingState(false)
                    return
                end

                if IsValidInput(InputObj) then
                    CurrentInput = InputObj
                    break
                end
            end

            -- If it's a modifier key, we wait for either its release or another input --
            while false and IsModifierInput(CurrentInput) do
                if CurrentInput.KeyCode == Enum.KeyCode.Escape then
                    break
                end

                -- Display the current state including the current modifier key --
                local ModName = ModifiersInput[CurrentInput.KeyCode]
                if ModName then
                    local text = if #ActiveModifiers > 0 then table.concat(ActiveModifiers, " + ") .. " + " .. ModName .. " + ..." else ModName .. " + ..."
                    KeyPicker:Display(text)
                end

                local NextInput = nil
                local Released = false

                local BeganConn
                local EndedConn

                BeganConn = UserInputService.InputBegan:Connect(function(InputObj)
                    if UserInputService:GetFocusedTextBox() ~= nil then
                        return
                    end
                    if IsValidInput(InputObj) then
                        NextInput = InputObj
                    end
                end)

                EndedConn = UserInputService.InputEnded:Connect(function(InputObj)
                    if InputObj.KeyCode == CurrentInput.KeyCode then
                        Released = true
                    end
                end)

                repeat
                    task.wait()
                until Released or NextInput or UserInputService:GetFocusedTextBox() ~= nil or Library.Unloaded

                if BeganConn then BeganConn:Disconnect() end
                if EndedConn then EndedConn:Disconnect() end

                if UserInputService:GetFocusedTextBox() ~= nil or Library.Unloaded then
                    SetPickingState(false)
                    return
                end

                if Released then
                    break -- Use modifier key as bind
                elseif NextInput then
                    -- Add another modifier or continue to normal key
                    local OldModName = ModifiersInput[CurrentInput.KeyCode]
                    if OldModName and not table.find(ActiveModifiers, OldModName) then
                        ActiveModifiers[#ActiveModifiers + 1] = OldModName
                    end

                    CurrentInput = NextInput
                    if CurrentInput.KeyCode == Enum.KeyCode.Escape then
                        break
                    end
                end
            end

            local Key = "Unknown"
            if SpecialKeysInput[CurrentInput.UserInputType] ~= nil then
                Key = SpecialKeysInput[CurrentInput.UserInputType]
            elseif CurrentInput.UserInputType == Enum.UserInputType.Keyboard then
                Key = CurrentInput.KeyCode == Enum.KeyCode.Escape and "None" or CurrentInput.KeyCode.Name
            end

            ActiveModifiers = if CurrentInput.KeyCode == Enum.KeyCode.Escape or Key == "Unknown" then {} else ActiveModifiers

            KeyPicker.Toggled = if ParentObj.Type == "Toggle" then ParentObj.Value else false
            KeyPicker:SetValue({ Key, KeyPicker.Mode, ActiveModifiers })

            repeat
                task.wait()
            until not IsInputDown(CurrentInput) or UserInputService:GetFocusedTextBox()

            SetPickingState(false)
        end)
        Picker.MouseButton2Click:Connect(MenuTable.Toggle)

        table.insert(KeyPicker.Connections, UserInputService.InputBegan:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            local IsMouse = IsMouseClickInput(Input)
            if
                KeyPicker.Mode == "Always"
                or KeyPicker.Value == "Unknown"
                or KeyPicker.Value == "None"
                or Picking
                or Library.IsPicking
                or UserInputService:GetFocusedTextBox()
                or (IsMouse and Library.Toggled)
            then
                return
            end

            local Key = KeyPicker.Value
            local HoldingModifiers = AreModifiersHeld(KeyPicker.Modifiers)
            local HoldingKey = false

            if
                Key
                and HoldingModifiers == true
                and (
                    SpecialKeysInput[Input.UserInputType] == Key
                    or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key)
                )
            then
                HoldingKey = true
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
        end))

        table.insert(KeyPicker.Connections, UserInputService.InputEnded:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            local IsMouse = IsMouseClickInput(Input)
            if
                KeyPicker.Value == "Unknown"
                or KeyPicker.Value == "None"
                or Picking
                or Library.IsPicking
                or UserInputService:GetFocusedTextBox()
                or (IsMouse and Library.Toggled)
            then
                return
            end

            KeyPicker:Update()
        end))

        KeyPicker:Update()

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        KeyPicker.Default = KeyPicker.Value
        KeyPicker.DefaultModifiers = table.clone(KeyPicker.Modifiers or {})

        function KeyPicker:Destroy()
            KeyPicker.Destroyed = true

            if KeyPicker.Connections then
                for _, Connection in KeyPicker.Connections do
                    Connection:Disconnect()
                end
            end

            if KeybindsToggle and KeybindsToggle.Loaded then
                if KeybindsToggle.Holder then
                    KeybindsToggle.Holder:Destroy()
                end
                local KTIdx = table.find(Library.KeybindToggles, KeybindsToggle)
                if KTIdx then
                    table.remove(Library.KeybindToggles, KTIdx)
                end
            end

            if MenuTable then
                MenuTable:Destroy()
            end

            if IsForButton and SlideOverflow then
                if SlideForwardTween then
                    SlideForwardTween:Destroy()
                end

                if SlideBackTween then
                    SlideBackTween:Destroy()
                end
            end

            if Picker then
                Picker:Destroy()
            end

            if ParentObj and ParentObj.Addons then
                local AddonIdx = table.find(ParentObj.Addons, KeyPicker)

                if AddonIdx then
                    table.remove(ParentObj.Addons, AddonIdx)
                end
            end

            Options[Idx] = nil
        end

        Options[Idx] = KeyPicker

        return self
    end

    local HueSequenceTable = {}
    for Hue = 0, 1, 0.1 do
        table.insert(HueSequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
    end
    function Funcs:AddColorPicker(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.ColorPicker)

        local ParentObj = self
        local ToggleLabel = ParentObj.TextLabel

        local ColorPicker = {
            Connections = {},
            Destroyed = false,

            Value = Info.Default,

            Transparency = Info.Transparency or 0,
            Title = Info.Title,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Type = "ColorPicker",
        }
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = ColorPicker.Value:ToHSV()

        local Holder = New("TextButton", {
            BackgroundColor3 = ColorPicker.Value,
            Size = UDim2.fromOffset(18, 18),
            Text = "",
            Parent = ToggleLabel,
        })

        local HolderStroke = New("UIStroke", {
            Color = Library:GetDarkerColor(ColorPicker.Value),
            Parent = Holder,
        })

        local ColorPickerCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = Holder,
        }); table.insert(Library.SpecificCorners, ColorPickerCorner)

        local HolderTransparency = New("ImageLabel", {
            Image = CustomImageManager.GetAsset("TransparencyTexture"),
            ImageTransparency = (1 - ColorPicker.Transparency),
            ScaleType = Enum.ScaleType.Tile,
            Position = UDim2.new(0, -1, 0, -1),
            Size = UDim2.new(1, 2, 1, 2),
            TileSize = UDim2.fromOffset(9, 9),
            Parent = Holder,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = HolderTransparency,
            })
        )

        --// Color Menu \\--
        local ColorMenu = Library:AddContextMenu(
            Holder,
            UDim2.fromOffset(Info.Transparency and 256 or 234, 0),
            function()
                return { 0.5, Holder.AbsoluteSize.Y + 1.5 }
            end,
            1, function(Active)
                ColorPickerCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
                ColorPickerCorner.BottomLeftRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            end, false, "no_top_left")
        ColorMenu.List.Padding = UDim.new(0, 8)
        ColorPicker.ColorMenu = ColorMenu

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 6),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 6),
            Parent = ColorMenu.Menu,
        })

        if typeof(ColorPicker.Title) == "string" then
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 8),
                Text = ColorPicker.Title,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = ColorMenu.Menu,
            })
        end

        local ColorHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 200),
            Parent = ColorMenu.Menu,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            Parent = ColorHolder,
        })

        --// Sat Map
        local SatVipMap = New("ImageButton", {
            BackgroundColor3 = ColorPicker.Value,
            Image = CustomImageManager.GetAsset("SaturationMap"),
            Size = UDim2.fromOffset(200, 200),
            Parent = ColorHolder,
        })

        local SatVibCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "WhiteColor",
            Size = UDim2.fromOffset(6, 6),
            Parent = SatVipMap,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = SatVibCursor,
        })
        New("UIStroke", {
            Color = "DarkColor",
            Parent = SatVibCursor,
        })

        --// Hue
        local HueSelector = New("TextButton", {
            Size = UDim2.fromOffset(16, 200),
            Text = "",
            Parent = ColorHolder,
        })
        New("UIGradient", {
            Color = ColorSequence.new(HueSequenceTable),
            Rotation = 90,
            Parent = HueSelector,
        })

        local HueCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "WhiteColor",
            BorderColor3 = "DarkColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0.5, ColorPicker.Hue),
            Size = UDim2.new(1, 2, 0, 1),
            Parent = HueSelector,
        })

        --// Alpha
        local TransparencySelector, TransparencyColor, TransparencyCursor
        if Info.Transparency then
            TransparencySelector = New("ImageButton", {
                Image = CustomImageManager.GetAsset("TransparencyTexture"),
                ScaleType = Enum.ScaleType.Tile,
                Size = UDim2.fromOffset(16, 200),
                TileSize = UDim2.fromOffset(8, 8),
                Parent = ColorHolder,
            })

            TransparencyColor = New("Frame", {
                BackgroundColor3 = ColorPicker.Value,
                Size = UDim2.fromScale(1, 1),
                Parent = TransparencySelector,
            })
            New("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = TransparencyColor,
            })

            TransparencyCursor = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = "WhiteColor",
                BorderColor3 = "DarkColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(0.5, ColorPicker.Transparency),
                Size = UDim2.new(1, 2, 0, 1),
                Parent = TransparencySelector,
            })
        end

        local InfoHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Parent = ColorMenu.Menu,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 8),
            Parent = InfoHolder,
        })

        local HueBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = false,
            Size = UDim2.fromScale(1, 1),
            Text = "#??????",
            TextSize = 14,
            Parent = InfoHolder,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = HueBox,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = HueBox,
            })
        )

        local RgbBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = false,
            Size = UDim2.fromScale(1, 1),
            Text = "?, ?, ?",
            TextSize = 14,
            Parent = InfoHolder,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = RgbBox,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = RgbBox,
            })
        )

        --// Context Menu \\--
        local ContextMenu = Library:AddContextMenu(Holder, UDim2.fromOffset(93, 0), function()
            return { Holder.AbsoluteSize.X + 1.5, 0.5 }
        end, 1, function(Active)
            ColorPickerCorner.TopRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            ColorPickerCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
        end, false, "no_top_left")
        ColorPicker.ContextMenu = ContextMenu
        ContextMenu.List.Padding = UDim.new(0, 6)
        do
            local function CreateButton(Text, Func)
                local Button = New("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 21),
                    Text = Text,
                    TextSize = 14,
                    Parent = ContextMenu.Menu,
                })

                Button.MouseButton1Click:Connect(function()
                    Library:SafeCallback(Func)
                    ContextMenu:Close()
                end)
            end

            CreateButton("Copy color", function()
                Library.CopiedColor = { ColorPicker.Value, ColorPicker.Transparency }
            end)

            ColorPicker.SetValueRGB = function(...) end --// make luau lsp shut up
            CreateButton("Paste color", function()
                ColorPicker:SetValueRGB(Library.CopiedColor[1], Library.CopiedColor[2])
            end)

            if setclipboard then
                CreateButton("Copy Hex", function()
                    setclipboard(tostring(ColorPicker.Value:ToHex()))
                end)

                CreateButton("Copy RGB", function()
                    setclipboard(table.concat({
                        math.floor(ColorPicker.Value.R * 255),
                        math.floor(ColorPicker.Value.G * 255),
                        math.floor(ColorPicker.Value.B * 255),
                    }, ", "))
                end)
            end
        end

        --// End \\--
        function ColorPicker:SetHSVFromRGB(Color)
            ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color:ToHSV()
        end

        function ColorPicker:Display()
            if Library.Unloaded then
                return
            end

            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)

            Holder.BackgroundColor3 = ColorPicker.Value
            HolderStroke.Color = Library:GetDarkerColor(ColorPicker.Value)
            HolderTransparency.ImageTransparency = (1 - ColorPicker.Transparency)

            SatVipMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
            if TransparencyColor then
                TransparencyColor.BackgroundColor3 = ColorPicker.Value
            end

            SatVibCursor.Position = UDim2.fromScale(ColorPicker.Sat, 1 - ColorPicker.Vib)
            HueCursor.Position = UDim2.fromScale(0.5, ColorPicker.Hue)
            if TransparencyCursor then
                TransparencyCursor.Position = UDim2.fromScale(0.5, ColorPicker.Transparency)
            end

            HueBox.Text = "#" .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255),
            }, ", ")
        end

        function ColorPicker:RunChanged()
            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value)
        end

        function ColorPicker:Update()
            ColorPicker:Display()
            ColorPicker:RunChanged()
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func
        end

        function ColorPicker:SetValue(HSV, Transparency)
            if typeof(HSV) == "Color3" then
                ColorPicker:SetValueRGB(HSV, Transparency)
                return
            end

            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
            ColorPicker.Transparency = Info.Transparency and Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Update()
        end

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Info.Transparency and Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Update()
        end

        table.insert(ColorPicker.Connections, Holder.MouseButton1Click:Connect(ColorMenu.Toggle))
        table.insert(ColorPicker.Connections, Holder.MouseButton2Click:Connect(ContextMenu.Toggle))

        table.insert(ColorPicker.Connections, SatVipMap.InputBegan:Connect(function(Input)
            while IsDragInput(Input) and not ColorPicker.Destroyed do
                local MinX = SatVipMap.AbsolutePosition.X
                local MaxX = MinX + SatVipMap.AbsoluteSize.X
                local LocationX = math.clamp(GetPointerLocation().X, MinX, MaxX)

                local MinY = SatVipMap.AbsolutePosition.Y
                local MaxY = MinY + SatVipMap.AbsoluteSize.Y
                local LocationY = math.clamp(GetPointerLocation().Y, MinY, MaxY)

                local OldSat = ColorPicker.Sat
                local OldVib = ColorPicker.Vib
                ColorPicker.Sat = (LocationX - MinX) / (MaxX - MinX)
                ColorPicker.Vib = 1 - ((LocationY - MinY) / (MaxY - MinY))

                if ColorPicker.Sat ~= OldSat or ColorPicker.Vib ~= OldVib then
                    ColorPicker:Update()
                end

                RunService.RenderStepped:Wait()
            end
        end))

        table.insert(ColorPicker.Connections, HueSelector.InputBegan:Connect(function(Input)
            while IsDragInput(Input) and not ColorPicker.Destroyed do
                local Min = HueSelector.AbsolutePosition.Y
                local Max = Min + HueSelector.AbsoluteSize.Y
                local Location = math.clamp(GetPointerLocation().Y, Min, Max)

                local OldHue = ColorPicker.Hue
                ColorPicker.Hue = (Location - Min) / (Max - Min)

                if ColorPicker.Hue ~= OldHue then
                    ColorPicker:Update()
                end

                RunService.RenderStepped:Wait()
            end
        end))

        if TransparencySelector then
            table.insert(ColorPicker.Connections, TransparencySelector.InputBegan:Connect(function(Input)
                while IsDragInput(Input) and not ColorPicker.Destroyed do
                    local Min = TransparencySelector.AbsolutePosition.Y
                    local Max = TransparencySelector.AbsolutePosition.Y + TransparencySelector.AbsoluteSize.Y
                    local Location = math.clamp(GetPointerLocation().Y, Min, Max)

                    local OldTransparency = ColorPicker.Transparency
                    ColorPicker.Transparency = (Location - Min) / (Max - Min)

                    if ColorPicker.Transparency ~= OldTransparency then
                        ColorPicker:Update()
                    end

                    RunService.RenderStepped:Wait()
                end
            end))
        end

        table.insert(ColorPicker.Connections, HueBox.FocusLost:Connect(function(Enter)
            if not Enter then
                return
            end

            local Success, Color = pcall(Color3.fromHex, HueBox.Text)
            if Success and typeof(Color) == "Color3" then
                ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color:ToHSV()
            end

            ColorPicker:Update()
        end))

        table.insert(ColorPicker.Connections, RgbBox.FocusLost:Connect(function(Enter)
            if not Enter then
                return
            end

            local R, G, B = RgbBox.Text:match("(%d+),%s*(%d+),%s*(%d+)")
            if R and G and B then
                ColorPicker:SetHSVFromRGB(Color3.fromRGB(R, G, B))
            end

            ColorPicker:Update()
        end))

        ColorPicker:Display()

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, ColorPicker)
        end

        ColorPicker.Default = ColorPicker.Value

        function ColorPicker:Destroy()
            ColorPicker.Destroyed = true

            if ColorPicker.Connections then
                for _, Connection in ColorPicker.Connections do
                    Connection:Disconnect()
                end
            end

            if ColorMenu then
                ColorMenu:Destroy()
            end

            if ContextMenu then
                ContextMenu:Destroy()
            end

            if Holder then
                Holder:Destroy()
            end

            if ParentObj and ParentObj.Addons then
                local AddonIdx = table.find(ParentObj.Addons, ColorPicker)

                if AddonIdx then
                    table.remove(ParentObj.Addons, AddonIdx)
                end
            end

            Options[Idx] = nil
        end

        Options[Idx] = ColorPicker

        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(_, Key, ...)
        return Funcs[Key](...)
    end
end

local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddDivider(...)
        if self.Destroyed then return nil end

        local Params = select(1, ...)
        local Text
        local MarginTop = 0
        local MarginBottom = 0

        if typeof(Params) == "table" then
            Text = Params.Text
            MarginTop = Params.MarginTop or Params.Margin or 0
            MarginBottom = Params.MarginBottom or Params.Margin or 0
        elseif typeof(Params) == "string" then
            Text = Params
        end

        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 6 + MarginTop + MarginBottom),
            Parent = Container,
        })

        local InnerHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingTop = UDim.new(0, MarginTop),
            PaddingBottom = UDim.new(0, MarginBottom),
            Parent = Holder,
        })

        if Text then
            local TextLabel = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Text = Text,
                TextSize = 14,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = InnerHolder,
            })

            local X, _ = Library:GetTextBounds(Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
            local SizeX = X // 2 + 10

            New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.new(0.5, -SizeX, 0, 2),
                Parent = InnerHolder,
            })
            New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.new(0.5, -SizeX, 0, 2),
                Parent = InnerHolder,
            })
        else
            New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.new(1, 0, 0, 2),
                Parent = InnerHolder,
            })
        end

        Groupbox:Resize()

        local Divider = {
            Connections = {},
            Destroyed = false,

            Holder = Holder,
            Text = Text,
            MarginTop = MarginTop,
            MarginBottom = MarginBottom,
            Type = "Divider",
        }

        function Divider:SetVisible(Value)
            Holder.Visible = Value == true
            Groupbox:Resize()
        end

        function Divider:Destroy()
            Divider.Destroyed = true

            if Divider.Connections then
                for _, Connection in Divider.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Divider)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
        end

        table.insert(Groupbox.Elements, Divider)
        return Divider
    end

    function Funcs:AddLabel(...)
        if self.Destroyed then return nil end

        local Data = {}
        local Addons = {}

        local First = select(1, ...)
        local Second = select(2, ...)

        if typeof(First) == "table" or typeof(Second) == "table" then
            local Params = typeof(First) == "table" and First or Second

            Data.Text = Params.Text or ""
            Data.DoesWrap = Params.DoesWrap or false
            Data.Size = Params.Size or 14
            Data.Visible = Params.Visible or true
            Data.Idx = typeof(Second) == "table" and First or nil
        else
            Data.Text = First or ""
            Data.DoesWrap = Second or false
            Data.Size = 14
            Data.Visible = true
            Data.Idx = select(3, ...) or nil
        end

        local Groupbox = self
        local Container = Groupbox.Container

        local Label = {
            Connections = {},
            Destroyed = false,

            Text = Data.Text,
            DoesWrap = Data.DoesWrap,

            Addons = Addons,

            Visible = Data.Visible,
            Type = "Label",
        }

        local TextLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = Label.Text,
            TextSize = Data.Size,
            TextWrapped = Label.DoesWrap,
            TextXAlignment = Groupbox.IsKeyTab and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            Parent = Container,
        })

        function Label:Display()
            if not Label.DoesWrap then
                return
            end

            local Width = TextLabel.AbsoluteSize.X
            if Width <= 0 then return end

            local _, Y = Library:GetTextBounds(Label.Text, TextLabel.FontFace, TextLabel.TextSize, Width)
            TextLabel.Size = UDim2.new(1, 0, 0, Y + 4)
        end

        function Label:SetVisible(Visible)
            Label.Visible = Visible

            TextLabel.Visible = Label.Visible
            Groupbox:Resize()
        end

        function Label:SetText(Text)
            Label.Text = Text
            TextLabel.Text = Text

            Label:Display()
            Groupbox:Resize()
        end

        if Label.DoesWrap then
            Label:Display()

            local Last = TextLabel.AbsoluteSize
            TextLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                if TextLabel.AbsoluteSize == Last then
                    return
                end

                Label:Display()
                Last = TextLabel.AbsoluteSize

                Groupbox:Resize()
            end)
        else
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                Padding = UDim.new(0, 6),
                Parent = TextLabel,
            })
        end

        Groupbox:Resize()

        Label.TextLabel = TextLabel
        Label.Container = Container
        if not Data.DoesWrap then
            setmetatable(Label, BaseAddons)
        end

        Label.Holder = TextLabel
        table.insert(Groupbox.Elements, Label)

        if Data.Idx then
            Labels[Data.Idx] = Label
        else
            table.insert(Labels, Label)
        end

        function Label:Destroy()
            Label.Destroyed = true

            if Label.Connections then
                for _, Connection in Label.Connections do
                    Connection:Disconnect()
                end
            end

            if Label.Addons then
                for Index = #Label.Addons, 1, -1 do
                    local Addon = table.remove(Label.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            if TextLabel then
                TextLabel:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Label)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()

            if Data.Idx then
                Labels[Data.Idx] = nil
            else
                local LblIdx = table.find(Labels, Label)

                if LblIdx then
                    table.remove(Labels, LblIdx)
                end
            end
        end

        return Label
    end

    function Funcs:AddButton(...)
        if self.Destroyed then return nil end

        local function GetInfo(...)
            local Info = {}

            local First = select(1, ...)
            local Second = select(2, ...)

            if typeof(First) == "table" or typeof(Second) == "table" then
                local Params = typeof(First) == "table" and First or Second

                Info.Text = Params.Text or ""
                Info.Func = Params.Func or Params.Callback or function() end
                Info.DoubleClick = Params.DoubleClick

                Info.Tooltip = Params.Tooltip
                Info.DisabledTooltip = Params.DisabledTooltip

                Info.Risky = Params.Risky or false
                Info.Disabled = Params.Disabled or false
                Info.Visible = Params.Visible or true
                Info.Idx = typeof(Second) == "table" and First or nil
            else
                Info.Text = First or ""
                Info.Func = Second or function() end
                Info.DoubleClick = false

                Info.Tooltip = nil
                Info.DisabledTooltip = nil

                Info.Risky = false
                Info.Disabled = false
                Info.Visible = true
                Info.Idx = select(3, ...) or nil
            end

            return Info
        end
        local Info = GetInfo(...)

        local Groupbox = self
        local Container = Groupbox.Container

        local Button = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Func = Info.Func,
            DoubleClick = Info.DoubleClick,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Tween = nil,
            Type = "Button",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 21),
            Parent = Container,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 9),
            Parent = Holder,
        })

        local function CreateButton(Button)
            local Base = New("TextButton", {
                Active = not Button.Disabled,
                BackgroundColor3 = Button.Disabled and "BackgroundColor" or "MainColor",
                Size = UDim2.fromScale(1, 1),
                Text = Button.Text,
                TextSize = 14,
                TextTransparency = 0.4,
                Visible = Button.Visible,
                Parent = Holder,
            })

            local Stroke = New("UIStroke", {
                Color = "OutlineColor",
                Transparency = Button.Disabled and 0.5 or 0,
                Parent = Base,
            })

            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Base,
                })
            )

            return Base, Stroke
        end

        local function InitEvents(Button)
            Button.Base.MouseEnter:Connect(function()
                if Button.Disabled then
                    return
                end

                Button.Tween = TweenService:Create(Button.Base, Library.TweenInfo, {
                    TextTransparency = 0,
                })
                Button.Tween:Play()
            end)
            Button.Base.MouseLeave:Connect(function()
                if Button.Disabled then
                    return
                end

                Button.Tween = TweenService:Create(Button.Base, Library.TweenInfo, {
                    TextTransparency = 0.4,
                })
                Button.Tween:Play()
            end)

            Button.Base.MouseButton1Click:Connect(function()
                if Button.Disabled or Button.Locked then
                    return
                end

                if Button.DoubleClick then
                    Button.Locked = true

                    Button.Base.Text = "Are you sure?"
                    Button.Base.TextColor3 = Library.Scheme.AccentColor
                    Library.Registry[Button.Base].TextColor3 = "AccentColor"

                    local Clicked = WaitForEvent(Button.Base.MouseButton1Click, 0.5)

                    Button.Base.Text = Button.Text
                    Button.Base.TextColor3 = Button.Risky and Library.Scheme.RedColor or Library.Scheme.FontColor
                    Library.Registry[Button.Base].TextColor3 = Button.Risky and "RedColor" or "FontColor"

                    if Clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    RunService.RenderStepped:Wait() --// Mouse Button fires without waiting (i hate roblox)
                    Button.Locked = false
                    return
                end

                Library:SafeCallback(Button.Func)
            end)
        end

        Button.Base, Button.Stroke = CreateButton(Button)
        InitEvents(Button)

        function Button:AddButton(...)
            local Info = GetInfo(...)

            local SubButton = {
                Connections = {},
                Destroyed = false,

                Text = Info.Text,
                Func = Info.Func,
                DoubleClick = Info.DoubleClick,

                Tooltip = Info.Tooltip,
                DisabledTooltip = Info.DisabledTooltip,
                TooltipTable = nil,

                Risky = Info.Risky,
                Disabled = Info.Disabled,
                Visible = Info.Visible,

                Tween = nil,
                Type = "SubButton",
            }

            Button.SubButton = SubButton
            SubButton.Base, SubButton.Stroke = CreateButton(SubButton)
            InitEvents(SubButton)

            function SubButton:UpdateColors()
                if Library.Unloaded then
                    return
                end

                StopTween(SubButton.Tween)

                SubButton.Base.BackgroundColor3 = SubButton.Disabled and Library.Scheme.BackgroundColor
                    or Library.Scheme.MainColor
                SubButton.Base.TextTransparency = SubButton.Disabled and 0.8 or 0.4
                SubButton.Stroke.Transparency = SubButton.Disabled and 0.5 or 0

                Library.Registry[SubButton.Base].BackgroundColor3 = SubButton.Disabled and "BackgroundColor"
                    or "MainColor"
            end

            function SubButton:SetDisabled(Disabled)
                SubButton.Disabled = Disabled

                if SubButton.TooltipTable then
                    SubButton.TooltipTable.Disabled = SubButton.Disabled
                end

                SubButton.Base.Active = not SubButton.Disabled
                SubButton:UpdateColors()
            end

            function SubButton:SetVisible(Visible)
                SubButton.Visible = Visible

                SubButton.Base.Visible = SubButton.Visible
                Groupbox:Resize()
            end

            function SubButton:SetText(Text)
                SubButton.Text = Text
                SubButton.Base.Text = Text
            end

            if typeof(SubButton.Tooltip) == "string" or typeof(SubButton.DisabledTooltip) == "string" then
                SubButton.TooltipTable =
                    Library:AddTooltip(SubButton.Tooltip, SubButton.DisabledTooltip, SubButton.Base)
                SubButton.TooltipTable.Disabled = SubButton.Disabled
            end

            if SubButton.Risky then
                SubButton.Base.TextColor3 = Library.Scheme.RedColor
                Library.Registry[SubButton.Base].TextColor3 = "RedColor"
            end

            SubButton:UpdateColors()

            if Info.Idx then
                Buttons[Info.Idx] = SubButton
            else
                table.insert(Buttons, SubButton)
            end

            SubButton.AddKeyPicker = BaseAddons.__index.AddKeyPicker

            function SubButton:Destroy()
                SubButton.Destroyed = true

                if SubButton.TooltipTable then
                    SubButton.TooltipTable:Destroy()
                end

                if SubButton.Tween then
                    SubButton.Tween:Destroy()
                end

                if SubButton.Base then
                    SubButton.Base:Destroy()
                end

                if Info.Idx then
                    Buttons[Info.Idx] = nil
                else
                    local BIdx = table.find(Buttons, SubButton)

                    if BIdx then
                        table.remove(Buttons, BIdx)
                    end
                end
            end

            return SubButton
        end

        function Button:UpdateColors()
            if Library.Unloaded then
                return
            end

            StopTween(Button.Tween)

            Button.Base.BackgroundColor3 = Button.Disabled and Library.Scheme.BackgroundColor
                or Library.Scheme.MainColor
            Button.Base.TextTransparency = Button.Disabled and 0.8 or 0.4
            Button.Stroke.Transparency = Button.Disabled and 0.5 or 0

            Library.Registry[Button.Base].BackgroundColor3 = Button.Disabled and "BackgroundColor" or "MainColor"
        end

        function Button:SetDisabled(Disabled)
            Button.Disabled = Disabled

            if Button.TooltipTable then
                Button.TooltipTable.Disabled = Button.Disabled
            end

            Button.Base.Active = not Button.Disabled
            Button:UpdateColors()
        end

        function Button:SetVisible(Visible)
            Button.Visible = Visible

            Holder.Visible = Button.Visible
            Groupbox:Resize()
        end

        function Button:SetText(Text)
            Button.Text = Text
            Button.Base.Text = Text
        end

        if typeof(Button.Tooltip) == "string" or typeof(Button.DisabledTooltip) == "string" then
            Button.TooltipTable = Library:AddTooltip(Button.Tooltip, Button.DisabledTooltip, Button.Base)
            Button.TooltipTable.Disabled = Button.Disabled
        end

        if Button.Risky then
            Button.Base.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Button.Base].TextColor3 = "RedColor"
        end

        Button:UpdateColors()
        Groupbox:Resize()

        Button.Holder = Holder
        table.insert(Groupbox.Elements, Button)

        if Info.Idx then
            Buttons[Info.Idx] = Button
        else
            table.insert(Buttons, Button)
        end

        Button.AddKeyPicker = BaseAddons.__index.AddKeyPicker

        function Button:Destroy()
            Button.Destroyed = true

            if Button.TooltipTable then
                Button.TooltipTable:Destroy()
            end

            if Button.Tween then
                Button.Tween:Destroy()
            end

            if Button.SubButton then
                Button.SubButton:Destroy()
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Button)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()

            if Info.Idx then
                Buttons[Info.Idx] = nil
            else
                local BIdx = table.find(Buttons, Button)

                if BIdx then
                    table.remove(Buttons, BIdx)
                end
            end
        end

        return Button
    end

    function Funcs:AddCheckbox(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Toggle)

        local Groupbox = self
        local Container = Groupbox.Container

        local Toggle = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Addons = {},
            AnyKeyPickerPicking = false,

            Variant = "Checkbox",
            Type = "Toggle",
        }

        local Button = New("TextButton", {
            Active = not Toggle.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = "",
            Visible = Toggle.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(26, 0),
            Size = UDim2.new(1, -26, 1, 0),
            Text = Toggle.Text,
            TextSize = 14,
            TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Button,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = Label,
        })

        local Checkbox = New("Frame", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromScale(1, 1),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            Parent = Button,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Checkbox,
            })
        )

        local CheckboxStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = Checkbox,
        })

        local CheckImage = New("ImageLabel", {
            Image = CheckIcon and CheckIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = CheckIcon and CheckIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = CheckIcon and CheckIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 1,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 1, -4),
            Parent = Checkbox,
        })

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        function Toggle:Display()
            if Library.Unloaded then
                return
            end

            CheckboxStroke.Transparency = Toggle.Disabled and 0.5 or 0

            if Toggle.Disabled then
                Label.TextTransparency = 0.8
                CheckImage.ImageTransparency = Toggle.Value and 0.8 or 1

                Checkbox.BackgroundColor3 = Library.Scheme.BackgroundColor
                Library.Registry[Checkbox].BackgroundColor3 = "BackgroundColor"

                return
            end

            TweenService:Create(Label, Library.TweenInfo, {
                TextTransparency = Toggle.Value and 0 or 0.4,
            }):Play()
            TweenService:Create(CheckImage, Library.TweenInfo, {
                ImageTransparency = Toggle.Value and 0 or 1,
            }):Play()

            Checkbox.BackgroundColor3 = Library.Scheme.MainColor
            Library.Registry[Checkbox].BackgroundColor3 = "MainColor"
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
        end

        function Toggle:RunChanged()
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
        end

        function Toggle:SetValue(Value)
            if Toggle.Disabled then
                return
            end

            Toggle.Value = Value
            Toggle:Display()

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon.Toggled = Toggle.Value
                    Addon:Update()
                end
            end

            Library:UpdateDependencyBoxes()

            if not Toggle.AnyKeyPickerPicking then
                Toggle:RunChanged()
            end
        end

        function Toggle:SetDisabled(Disabled)
            Toggle.Disabled = Disabled

            if Toggle.TooltipTable then
                Toggle.TooltipTable.Disabled = Toggle.Disabled
            end

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon:Update()
                end
            end

            Button.Active = not Toggle.Disabled
            Toggle:Display()
        end

        function Toggle:SetVisible(Visible)
            Toggle.Visible = Visible

            Button.Visible = Toggle.Visible
            Groupbox:Resize()
        end

        function Toggle:SetText(Text)
            Toggle.Text = Text
            Label.Text = Text
        end

        table.insert(Toggle.Connections, Button.MouseButton1Click:Connect(function()
            if Toggle.Disabled then
                return
            end

            Toggle:SetValue(not Toggle.Value)
        end))

        if typeof(Toggle.Tooltip) == "string" or typeof(Toggle.DisabledTooltip) == "string" then
            Toggle.TooltipTable = Library:AddTooltip(Toggle.Tooltip, Toggle.DisabledTooltip, Button)
            Toggle.TooltipTable.Disabled = Toggle.Disabled
        end

        if Toggle.Risky then
            Label.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Label].TextColor3 = "RedColor"
        end

        Toggle:Display()
        Groupbox:Resize()

        Toggle.TextLabel = Label
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Holder = Button
        table.insert(Groupbox.Elements, Toggle)

        Toggle.Default = Toggle.Value

        Toggles[Idx] = Toggle

        function Toggle:Destroy()
            Toggle.Destroyed = true

            if Toggle.Connections then
                for _, Connection in Toggle.Connections do
                    Connection:Disconnect()
                end
            end

            if Toggle.TooltipTable then
                Toggle.TooltipTable:Destroy()
            end

            if Button then
                Button:Destroy()
            end

            if Toggle.Addons then
                for Index = #Toggle.Addons, 1, -1 do
                    local Addon = table.remove(Toggle.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            local ElemIdx = table.find(Groupbox.Elements, Toggle)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Toggles[Idx] = nil
        end

        return Toggle
    end

    function Funcs:AddToggle(Idx, Info)
        if self.Destroyed then return nil end

        if Library.ForceCheckbox then
            return Funcs.AddCheckbox(self, Idx, Info)
        end

        Info = Library:Validate(Info, Templates.Toggle)

        local Groupbox = self
        local Container = Groupbox.Container

        local Toggle = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Addons = {},
            AnyKeyPickerPicking = false,

            Variant = "Switch",
            Type = "Toggle",
        }

        local Button = New("TextButton", {
            Active = not Toggle.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = "",
            Visible = Toggle.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -40, 1, 0),
            Text = Toggle.Text,
            TextSize = 14,
            TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Button,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = Label,
        })

        local Switch = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.fromOffset(32, 18),
            Parent = Button,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Switch,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 2),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 2),
            PaddingTop = UDim.new(0, 2),
            Parent = Switch,
        })
        local SwitchStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = Switch,
        })

        local Ball = New("Frame", {
            BackgroundColor3 = "FontColor",
            Size = UDim2.fromScale(1, 1),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            Parent = Switch,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Ball,
        })

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        function Toggle:Display()
            if Library.Unloaded then
                return
            end

            local Offset = Toggle.Value and 1 or 0

            Switch.BackgroundTransparency = Toggle.Disabled and 0.75 or 0
            SwitchStroke.Transparency = Toggle.Disabled and 0.75 or 0

            Switch.BackgroundColor3 = Toggle.Value and Library.Scheme.AccentColor or Library.Scheme.MainColor
            SwitchStroke.Color = Toggle.Value and Library.Scheme.AccentColor or Library.Scheme.OutlineColor

            Library.Registry[Switch].BackgroundColor3 = Toggle.Value and "AccentColor" or "MainColor"
            Library.Registry[SwitchStroke].Color = Toggle.Value and "AccentColor" or "OutlineColor"

            if Toggle.Disabled then
                Label.TextTransparency = 0.8
                Ball.AnchorPoint = Vector2.new(Offset, 0)
                Ball.Position = UDim2.fromScale(Offset, 0)

                Ball.BackgroundColor3 = Library:GetDarkerColor(Library.Scheme.FontColor)
                Library.Registry[Ball].BackgroundColor3 = function()
                    return Library:GetDarkerColor(Library.Scheme.FontColor)
                end

                return
            end

            TweenService:Create(Label, Library.TweenInfo, {
                TextTransparency = Toggle.Value and 0 or 0.4,
            }):Play()
            TweenService:Create(Ball, Library.TweenInfo, {
                AnchorPoint = Vector2.new(Offset, 0),
                Position = UDim2.fromScale(Offset, 0),
            }):Play()

            Ball.BackgroundColor3 = Library.Scheme.FontColor
            Library.Registry[Ball].BackgroundColor3 = "FontColor"
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
        end

        function Toggle:RunChanged()
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
        end

        function Toggle:SetValue(Value)
            if Toggle.Disabled then
                return
            end

            Toggle.Value = Value
            Toggle:Display()

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon.Toggled = Toggle.Value
                    Addon:Update()
                end
            end

            Library:UpdateDependencyBoxes()

            if not Toggle.AnyKeyPickerPicking then
                Toggle:RunChanged()
            end
        end

        function Toggle:SetDisabled(Disabled)
            Toggle.Disabled = Disabled

            if Toggle.TooltipTable then
                Toggle.TooltipTable.Disabled = Toggle.Disabled
            end

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon:Update()
                end
            end

            Button.Active = not Toggle.Disabled
            Toggle:Display()
        end

        function Toggle:SetVisible(Visible)
            Toggle.Visible = Visible

            Button.Visible = Toggle.Visible
            Groupbox:Resize()
        end

        function Toggle:SetText(Text)
            Toggle.Text = Text
            Label.Text = Text
        end

        table.insert(Toggle.Connections, Button.MouseButton1Click:Connect(function()
            if Toggle.Disabled then
                return
            end

            Toggle:SetValue(not Toggle.Value)
        end))

        if typeof(Toggle.Tooltip) == "string" or typeof(Toggle.DisabledTooltip) == "string" then
            Toggle.TooltipTable = Library:AddTooltip(Toggle.Tooltip, Toggle.DisabledTooltip, Button)
            Toggle.TooltipTable.Disabled = Toggle.Disabled
        end

        if Toggle.Risky then
            Label.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Label].TextColor3 = "RedColor"
        end

        Toggle:Display()
        Groupbox:Resize()

        Toggle.TextLabel = Label
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Holder = Button
        table.insert(Groupbox.Elements, Toggle)

        Toggle.Default = Toggle.Value

        Toggles[Idx] = Toggle

        function Toggle:Destroy()
            Toggle.Destroyed = true

            if Toggle.Connections then
                for _, Connection in Toggle.Connections do
                    Connection:Disconnect()
                end
            end

            if Toggle.TooltipTable then
                Toggle.TooltipTable:Destroy()
            end

            if Button then
                Button:Destroy()
            end

            if Toggle.Addons then
                for Index = #Toggle.Addons, 1, -1 do
                    local Addon = table.remove(Toggle.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            local ElemIdx = table.find(Groupbox.Elements, Toggle)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Toggles[Idx] = nil
        end

        return Toggle
    end

    function Funcs:AddInput(Idx, Info)
        if self.Destroyed then return nil end

        if typeof(Info) == "table" and (typeof(Info.VerifyValue) == "function" and Info.Finished ~= true) then
            Info.Finished = true
        end

        Info = Library:Validate(Info, Templates.Input)

        local Groupbox = self
        local Container = Groupbox.Container

        local Input = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Finished = Info.Finished,
            Numeric = Info.Numeric,
            ClearTextOnFocus = Info.ClearTextOnFocus,
            ClearTextOnBlur = Info.ClearTextOnBlur,
            Placeholder = Info.Placeholder,
            AllowEmpty = Info.AllowEmpty,
            EmptyReset = Info.EmptyReset,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,
            VerifyValue = Info.VerifyValue,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Type = "Input",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 39),
            Visible = Input.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Text = Input.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })

        local Box = New("TextBox", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = not Input.Disabled and Input.ClearTextOnFocus,
            PlaceholderText = Input.Placeholder,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 21),
            Text = Input.Value,
            TextEditable = not Input.Disabled,
            TextScaled = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = Box,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Box,
            })
        )

        function Input:UpdateColors()
            if Library.Unloaded then
                return
            end

            Label.TextTransparency = Input.Disabled and 0.8 or 0
            Box.TextTransparency = Input.Disabled and 0.8 or 0
        end

        function Input:OnChanged(Func)
            Input.Changed = Func
        end

        function Input:RunChanged()
            Library:SafeCallback(Input.Callback, Input.Value)
            Library:SafeCallback(Input.Changed, Input.Value)
        end

        function Input:SetValue(Text)
            if not Input.AllowEmpty and Trim(Text) == "" then
                Text = Input.EmptyReset
            end

            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength)
            end

            if Input.Numeric then
                if #tostring(Text) > 0 and not tonumber(Text) then
                    Text = Input.Value
                end
            end

            if typeof(Info.VerifyValue) == "function" and (Text ~= Input.EmptyReset and Info.VerifyValue(Text) ~= true) then
                Text = Input.EmptyReset
            end

            Input.Value = Text
            Box.Text = Text

            if not Input.Disabled then
                Input:RunChanged()
            end
        end

        function Input:SetDisabled(Disabled)
            Input.Disabled = Disabled

            if Input.TooltipTable then
                Input.TooltipTable.Disabled = Input.Disabled
            end

            Box.ClearTextOnFocus = not Input.Disabled and Input.ClearTextOnFocus
            Box.TextEditable = not Input.Disabled
            Input:UpdateColors()
        end

        function Input:SetVisible(Visible)
            Input.Visible = Visible

            Holder.Visible = Input.Visible
            Groupbox:Resize()
        end

        function Input:SetText(Text)
            Input.Text = Text
            Label.Text = Text
        end

        if Input.Finished then
            table.insert(Input.Connections, Box.FocusLost:Connect(function(Enter)
                if not Enter then
                    if Input.ClearTextOnBlur then
                        Box.Text = Input.Value
                    end

                    return
                end

                Input:SetValue(Box.Text)
            end))
        else
            table.insert(Input.Connections, Box:GetPropertyChangedSignal("Text"):Connect(function()
                if Box.Text == Input.Value then return end

                Input:SetValue(Box.Text)
            end))
        end

        if typeof(Input.Tooltip) == "string" or typeof(Input.DisabledTooltip) == "string" then
            Input.TooltipTable = Library:AddTooltip(Input.Tooltip, Input.DisabledTooltip, Box)
            Input.TooltipTable.Disabled = Input.Disabled
        end

        Groupbox:Resize()

        Input.Holder = Holder
        table.insert(Groupbox.Elements, Input)

        Input.Default = Input.Value
        if typeof(Info.VerifyValue) == "function" and (Input.Default ~= Input.EmptyReset and Info.VerifyValue(Input.Default) ~= true) then
            Input:SetValue(Input.EmptyReset)
            Input.Default = Input.EmptyReset
        end

        Options[Idx] = Input

        function Input:Destroy()
            Input.Destroyed = true

            if Input.Connections then
                for _, Connection in Input.Connections do
                    Connection:Disconnect()
                end
            end

            if Input.TooltipTable then
                Input.TooltipTable:Destroy()
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Input)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Input
    end

    function Funcs:AddSlider(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Slider)

        local Groupbox = self
        local Container = Groupbox.Container

        local Slider = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Min = Info.Min,
            Max = Info.Max,

            Prefix = Info.Prefix,
            Suffix = Info.Suffix,
            Compact = Info.Compact,
            Rounding = Info.Rounding,
            HideMax = Info.HideMax,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            AllowRightClickInput = Info.AllowRightClickInput,

            Type = "Slider",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Compact and 15 or 33),
            Visible = Slider.Visible,
            Parent = Container,
        })

        local SliderLabel
        if not Info.Compact then
            SliderLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                Text = Slider.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Holder,
            })
        end

        local Bar = New("TextButton", {
            Active = not Slider.Disabled,
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 15),
            Text = "",
            Parent = Holder,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = Bar,
        })

        local DisplayLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            TextSize = 14,
            ZIndex = Bar.ZIndex + 2,
            Parent = Bar,
        })
        New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
            Color = "DarkColor",
            LineJoinMode = Enum.LineJoinMode.Miter,
            Parent = DisplayLabel,
        })

        local InputTextBox
        if Info.AllowRightClickInput then
            InputTextBox = New("TextBox", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = "",
                TextSize = 14,
                ZIndex = Bar.ZIndex + 3,
                Visible = false,
                ClearTextOnFocus = false,
                Parent = Bar,
            })
            New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = "DarkColor",
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = InputTextBox,
            })
        end

        local Fill = New("Frame", {
            BackgroundColor3 = "AccentColor",
            Size = UDim2.fromScale(0.5, 1),
            ZIndex = Bar.ZIndex + 1,
            Parent = Bar,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Bar,
            })
        )

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Fill,
            })
        )

        function Slider:UpdateColors()
            if Library.Unloaded then
                return
            end

            if SliderLabel then
                SliderLabel.TextTransparency = Slider.Disabled and 0.8 or 0
            end
            DisplayLabel.TextTransparency = Slider.Disabled and 0.8 or 0

            if Info.AllowRightClickInput then
                InputTextBox.TextTransparency = Slider.Disabled and 0.8 or 0
            end

            Fill.BackgroundColor3 = Slider.Disabled and Library.Scheme.OutlineColor or Library.Scheme.AccentColor
            Library.Registry[Fill].BackgroundColor3 = Slider.Disabled and "OutlineColor" or "AccentColor"
        end

        function Slider:Display()
            if Library.Unloaded then
                return
            end

            local CustomDisplayText = nil
            if Info.FormatDisplayValue then
                CustomDisplayText = Info.FormatDisplayValue(Slider, Slider.Value)
            end

            if CustomDisplayText then
                DisplayLabel.Text = tostring(CustomDisplayText)
            else
                if Info.Compact then
                    DisplayLabel.Text =
                        string.format("%s: %s%s%s", Slider.Text, Slider.Prefix, Slider.Value, Slider.Suffix)
                elseif Info.HideMax then
                    DisplayLabel.Text = string.format("%s%s%s", Slider.Prefix, Slider.Value, Slider.Suffix)
                else
                    DisplayLabel.Text = string.format(
                        "%s%s%s/%s%s%s",
                        Slider.Prefix,
                        Slider.Value,
                        Slider.Suffix,
                        Slider.Prefix,
                        Slider.Max,
                        Slider.Suffix
                    )
                end
            end

            local X = (Slider.Value - Slider.Min) / (Slider.Max - Slider.Min)
            Fill.Size = UDim2.fromScale(X, 1)
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func
        end

        function Slider:SetMax(Value)
            assert(Value > Slider.Min, "Max value cannot be less than the current min value.")

            Slider:SetValue(math.clamp(Slider.Value, Slider.Min, Value))
            Slider.Max = Value
            Slider:Display()
        end

        function Slider:SetMin(Value)
            assert(Value < Slider.Max, "Min value cannot be greater than the current max value.")

            Slider:SetValue(math.clamp(Slider.Value, Value, Slider.Max))
            Slider.Min = Value
            Slider:Display()
        end

        function Slider:RunChanged()
            Library:SafeCallback(Slider.Callback, Slider.Value)
            Library:SafeCallback(Slider.Changed, Slider.Value)
        end

        function Slider:SetValue(Str)
            if Slider.Disabled then
                return
            end

            local Num = tonumber(Str)
            if not Num or Num == Slider.Value then
                return
            end

            Num = math.clamp(Num, Slider.Min, Slider.Max)

            Slider.Value = Num
            Slider:Display()

            Slider:RunChanged()
        end

        function Slider:SetDisabled(Disabled)
            Slider.Disabled = Disabled

            if Slider.TooltipTable then
                Slider.TooltipTable.Disabled = Slider.Disabled
            end

            Bar.Active = not Slider.Disabled
            Slider:UpdateColors()
        end

        function Slider:SetVisible(Visible)
            Slider.Visible = Visible

            Holder.Visible = Slider.Visible
            Groupbox:Resize()
        end

        function Slider:SetText(Text)
            Slider.Text = Text
            if SliderLabel then
                SliderLabel.Text = Text
                return
            end
            Slider:Display()
        end

        function Slider:SetPrefix(Prefix)
            Slider.Prefix = Prefix
            Slider:Display()
        end

        function Slider:SetSuffix(Suffix)
            Slider.Suffix = Suffix
            Slider:Display()
        end

        if Info.AllowRightClickInput then
            local LastValidText = ""
            table.insert(Slider.Connections, InputTextBox:GetPropertyChangedSignal("Text"):Connect(function()
                local Text = InputTextBox.Text
                local AsNum = tonumber(Text)

                if #tostring(Text) > 0 and not AsNum and Text ~= "-" then
                    InputTextBox.Text = LastValidText
                else
                    if Slider.Rounding == 0 and Text:find("%.") then
                        InputTextBox.Text = LastValidText
                        return
                    end

                    local DecimalPos = Text:find("%.")
                    if DecimalPos and Slider.Rounding > 0 then
                        local Decimals = #Text - DecimalPos
                        if Decimals > Slider.Rounding then
                            InputTextBox.Text = LastValidText
                            return
                        end
                    end

                    LastValidText = Text

                    if AsNum then
                        if AsNum > Slider.Max then
                            InputTextBox.Text = tostring(Slider.Max)
                        elseif AsNum < Slider.Min then
                            InputTextBox.Text = tostring(Slider.Min)
                        end
                    end
                end
            end))

            table.insert(Slider.Connections, InputTextBox.FocusLost:Connect(function()
                InputTextBox.Visible = false
                DisplayLabel.Visible = true

                local Num = tonumber(InputTextBox.Text)
                if not Num then
                    return
                end

                Num = Round(Num, Slider.Rounding)
                Slider:SetValue(Num)
            end))
        end

        local LastTap = 0
        table.insert(Slider.Connections, Bar.InputBegan:Connect(function(Input)
            local ValidInput = IsClickInput(Input) or Input.UserInputType == Enum.UserInputType.MouseButton2
            if not ValidInput or Slider.Disabled then
                return
            end

            if Info.AllowRightClickInput then
                local IsRightClick = Input.UserInputType == Enum.UserInputType.MouseButton2
                local IsDoubleTap = false

                if Library.IsMobile and Input.UserInputType == Enum.UserInputType.Touch then
                    if tick() - LastTap < 0.3 then
                        IsDoubleTap = true
                    end

                    LastTap = tick()
                end

                if IsRightClick or IsDoubleTap then
                    InputTextBox.Text = tostring(Slider.Value)
                    InputTextBox.Visible = true
                    DisplayLabel.Visible = false

                    task.spawn(InputTextBox.CaptureFocus, InputTextBox)
                    return
                end
            end

            if not IsClickInput(Input) then
                return
            end

            if Library.ActiveTab then
                for _, Side in Library.ActiveTab.Sides do
                    Side.ScrollingEnabled = false
                end
            end

            if Library.ActiveLoading and Library.ActiveLoading.Sidebar then
                Library.ActiveLoading.Sidebar.Container.ScrollingEnabled = false
            end

            while IsDragInput(Input) and not Slider.Destroyed do
                local Location = GetPointerLocation().X
                local Scale = math.clamp((Location - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)

                local OldValue = Slider.Value
                Slider.Value = Round(Slider.Min + ((Slider.Max - Slider.Min) * Scale), Slider.Rounding)

                Slider:Display()
                if Slider.Value ~= OldValue then
                    Slider:RunChanged()
                end

                RunService.RenderStepped:Wait()
            end

            if Library.ActiveTab then
                for _, Side in Library.ActiveTab.Sides do
                    Side.ScrollingEnabled = true
                end
            end

            if Library.ActiveLoading and Library.ActiveLoading.Sidebar then
                Library.ActiveLoading.Sidebar.Container.ScrollingEnabled = true
            end
        end))

        if typeof(Slider.Tooltip) == "string" or typeof(Slider.DisabledTooltip) == "string" then
            Slider.TooltipTable = Library:AddTooltip(Slider.Tooltip, Slider.DisabledTooltip, Bar)
            Slider.TooltipTable.Disabled = Slider.Disabled
        end

        Slider:UpdateColors()
        Slider:Display()
        Groupbox:Resize()

        Slider.Holder = Holder
        table.insert(Groupbox.Elements, Slider)

        Slider.Default = Slider.Value

        Options[Idx] = Slider

        function Slider:Destroy()
            Slider.Destroyed = true

            if Slider.Connections then
                for _, Connection in Slider.Connections do
                    Connection:Disconnect()
                end
            end

            if Slider.TooltipTable then
                Slider.TooltipTable:Destroy()
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Slider)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Dropdown)

        local Groupbox = self
        local Container = Groupbox.Container

        if Info.SpecialType == "Player" then
            Info.Values = GetPlayers(Info.ExcludeLocalPlayer)
            Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeams()
            Info.AllowNull = true
        end

        local Dropdown = {
            Connections = {},
            Destroyed = false,

            Text = typeof(Info.Text) == "string" and Info.Text or nil,

            Value = Info.Multi and {} or nil,
            Values = Info.Values,
            DisabledValues = Info.DisabledValues,
            ValueImages = Info.ValueImages,

            Multi = Info.Multi,
            DragSelect = Info.Multi and not Library.IsMobile and Info.DragSelect == true,

            SpecialType = Info.SpecialType,
            ExcludeLocalPlayer = Info.ExcludeLocalPlayer,
            EnablePlayerImages = Info.EnablePlayerImages,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Type = "Dropdown",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Dropdown.Text and 39 or 21),
            Visible = Dropdown.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Text = Dropdown.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not not Info.Text,
            ZIndex = 3,
            Parent = Holder,
        })

        local DisplayContainer = New("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 21),
            Text = "",
            TextTransparency = 1,
            ZIndex = 2,
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 4),
            Parent = DisplayContainer,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = DisplayContainer,
        })

        local DropdownCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = DisplayContainer,
        }); table.insert(Library.SpecificCorners, DropdownCorner)

        local DisplayImage = New("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(-4, 3),
            Size = UDim2.fromOffset(16, 16),
            Image = "",
            ImageTransparency = 1,
            ZIndex = 2,
            Parent = DisplayContainer,
        })

        local DisplayButton = New("TextButton", {
            Active = not Dropdown.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 21),
            Text = "---",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
            Parent = DisplayContainer,
        })

        local ArrowImage = New("ImageLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Image = ArrowIcon and ArrowIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = ArrowIcon and ArrowIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = ArrowIcon and ArrowIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 0.5,
            Position = UDim2.fromScale(1, 0.5),
            Size = UDim2.fromOffset(16, 16),
            Parent = DisplayContainer,
        })

        local SearchBox
        if Info.Searchable then
            SearchBox = New("TextBox", {
                BackgroundTransparency = 1,
                PlaceholderText = "Search...",
                Position = UDim2.fromOffset(-8, 0),
                Size = UDim2.new(1, -12, 1, 0),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = false,
                Parent = DisplayButton,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                Parent = SearchBox,
            })
        end

        local GetValueImage = function(Value)
            if not Value then
                return nil
            end

            local ValueImage = nil
            if Dropdown.SpecialType == "Player" and Dropdown.EnablePlayerImages == true then
                if typeof(Value) == "Instance" and Value:IsA("Player") then
                    ValueImage = { Url = string.format("rbxthumb://type=AvatarHeadShot&id=%s&w=48&h=48", tostring(Value.UserId)) }
                end
            else
                if Info.ValueImages and Info.ValueImages[Value] then
                    ValueImage = Library:GetCustomIcon(Info.ValueImages[Value])
                end
            end

            return ValueImage
        end

        local MenuTable = Library:AddContextMenu(
            DisplayContainer,
            function()
                return UDim2.fromOffset((DisplayContainer.AbsoluteSize.X / Library.DPIScale), 0)
            end,
            function()
                return { 0.5, DisplayContainer.AbsoluteSize.Y + 1.5 }
            end,
            2,
            function(Active)
                DisplayButton.TextTransparency = (Active and SearchBox) and 1 or 0

                ArrowImage.ImageTransparency = Active and 0 or 0.5
                ArrowImage.Rotation = Active and 180 or 0

                if SearchBox then
                    SearchBox.Text = ""
                    SearchBox.Visible = Active
                end

                DropdownCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
                DropdownCorner.BottomLeftRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            end,
            false,
            "bottom",
            "Dropdown"
        )
        Dropdown.Menu = MenuTable

        function Dropdown:RecalculateListSize(Count)
            local Y = math.clamp((Count or GetTableSize(Dropdown.Values)) * 21, 0, Info.MaxVisibleDropdownItems * 21)

            MenuTable:SetSize(function()
                return UDim2.fromOffset((DisplayContainer.AbsoluteSize.X / Library.DPIScale), Y)
            end)
        end

        function Dropdown:UpdateColors()
            if Library.Unloaded then
                return
            end

            Label.TextTransparency = Dropdown.Disabled and 0.8 or 0
            DisplayButton.TextTransparency = Dropdown.Disabled and 0.8 or 0
            DisplayImage.ImageTransparency = Dropdown.Disabled and 0.8 or 0
            ArrowImage.ImageTransparency = Dropdown.Disabled and 0.8 or MenuTable.Active and 0 or 0.5
        end

        function Dropdown:Display()
            if Library.Unloaded then
                return
            end

            local Str = ""
            local ValueImage = nil

            if Info.Multi then
                for _, Value in Dropdown.Values do
                    if Dropdown.Value[Value] then
                        if not ValueImage then
                            ValueImage = GetValueImage(Value)
                        end

                        Str = Str
                            .. (Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(Value)) or tostring(Value))
                            .. ", "
                    end
                end

                Str = Str:sub(1, #Str - 2)
            else
                ValueImage = GetValueImage(Dropdown.Value)
                Str = Dropdown.Value and tostring(Dropdown.Value) or ""

                if Str ~= "" and Info.FormatDisplayValue then
                    Str = tostring(Info.FormatDisplayValue(Str))
                end
            end

            if #Str > 25 then
                Str = Str:sub(1, 22) .. "..."
            end

            DisplayButton.Text = (Str == "" and "---" or Str)

            if ValueImage then
                DisplayImage.Image = ValueImage.Url
                DisplayImage.ImageRectOffset = ValueImage.ImageRectOffset or Vector2.zero
                DisplayImage.ImageRectSize = ValueImage.ImageRectSize or Vector2.zero
                DisplayImage.ImageTransparency = 0
            else
                DisplayImage.Image = ""
                DisplayImage.ImageTransparency = 1
            end

            DisplayButton.Size = ValueImage and UDim2.new(1, -8, 0, 21) or UDim2.new(1, 0, 0, 21)
            DisplayButton.Position = ValueImage and UDim2.fromOffset(14, 0) or UDim2.fromOffset(0, 0)
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func
        end

        function Dropdown:GetActiveValues(ReturnCount)
            local Table = {}

            if Info.Multi then
                for Value, _ in Dropdown.Value do
                    table.insert(Table, Value)
                end
            else
                if Dropdown.Value then
                    table.insert(Table, Dropdown.Value)
                end
            end

            return ReturnCount == true and GetTableSize(Table) or Table
        end

        local Buttons = {}
        local DragSelecting = false
        local DragStartIndex = nil
        local DragInitialValues = {}
        local DragInputEndedConn = nil
        local DragInputChangedConn = nil

        local function StopDragSelect()
            DragSelecting = false
            DragStartIndex = nil
            table.clear(DragInitialValues)

            if DragInputEndedConn then
                DragInputEndedConn:Disconnect()
                DragInputEndedConn = nil
            end

            if DragInputChangedConn then
                DragInputChangedConn:Disconnect()
                DragInputChangedConn = nil
            end
        end

        local function UpdateDrag(CurrentIndex)
            local Min = math.min(DragStartIndex, CurrentIndex)
            local Max = math.max(DragStartIndex, CurrentIndex)

            for OtherButton, OtherTable in Buttons do
                local InRange = OtherTable.Index >= Min and OtherTable.Index <= Max
                local Try = DragInitialValues[OtherTable.Value]
                if InRange then
                    Try = not Try
                end

                if not (Dropdown:GetActiveValues(true) == 1 and not Try and not Info.AllowNull) then
                    Dropdown.Value[OtherTable.Value] = Try and true or nil
                end

                OtherTable:UpdateButton()
            end

            Dropdown:Display()
        end

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local DisabledValues = Dropdown.DisabledValues

            StopDragSelect()

            for Button, _ in Buttons do
                if not (Button and Button.Parent) then
                    continue
                end

                Button.Parent:Destroy()
            end
            table.clear(Buttons)

            local Count = 0
            local ProcessedCount = 0
            local TotalLen = GetTableSize(Values) + GetTableSize(DisabledValues)

            for _, Value in Values do
                ProcessedCount += 1

                local FormattedValue = tostring(Info.FormatListValue and Info.FormatListValue(Value) or Value)
                if SearchBox and not FormattedValue:lower():match(SearchBox.Text:lower()) then
                    continue
                end

                Count += 1

                local IsDisabled = table.find(DisabledValues, Value)
                local Table = {}
                local ValueImage = GetValueImage(Value)

                local Container = New("Frame", {
                    BackgroundColor3 = "MainColor",
                    BackgroundTransparency = 1,
                    LayoutOrder = IsDisabled and 1 or 0,
                    Size = UDim2.new(1, 0, 0, 21),
                    Parent = MenuTable.Menu,
                })

                if ProcessedCount == TotalLen then
                    local Corner = New("UICorner", {
                        TopLeftRadius = UDim.new(0, 0),
                        TopRightRadius = UDim.new(0, 0),
                        BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                        BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                        Parent = Container,
                    }); table.insert(Library.SpecificCorners, Corner)
                end

                local Image = ValueImage and New("ImageLabel", {
                    BackgroundTransparency = 1,
                    Image = ValueImage.Url,
                    ImageRectOffset = ValueImage.ImageRectOffset,
                    ImageRectSize = ValueImage.ImageRectSize,
                    ImageTransparency = 0.5,
                    Size = UDim2.fromOffset(16, 16),
                    Position = UDim2.fromOffset(4, 3),
                    Parent = Container,
                })

                local Button = New("TextButton", {
                    BackgroundTransparency = 1,
                    Size = ValueImage and UDim2.new(1, -18, 0, 21) or UDim2.new(1, 0, 0, 21),
                    Position = ValueImage and UDim2.fromOffset(18, 0) or UDim2.fromOffset(0, 0),
                    Text = FormattedValue,
                    TextSize = 14,
                    TextTransparency = 0.5,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Container,
                })
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    Parent = Button,
                })

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

                    Container.BackgroundTransparency = Selected and 0 or 1
                    Button.TextTransparency = IsDisabled and 0.8 or Selected and 0 or 0.5

                    if Image then
                        Image.ImageTransparency = IsDisabled and 0.8 or Selected and 0 or 0.5
                    end
                end

                Table.Index = Count
                Table.Value = Value

                if not IsDisabled then
                    Button.MouseButton1Click:Connect(function()
                        if DragSelecting then return end

                        local Try = not Selected
                        if not (Dropdown:GetActiveValues(true) == 1 and not Try and not Info.AllowNull) then
                            Selected = Try
                            if Info.Multi then
                                Dropdown.Value[Value] = Selected and true or nil
                            else
                                Dropdown.Value = Selected and Value or nil
                            end

                            for _, OtherButton in Buttons do
                                OtherButton:UpdateButton()
                            end
                        end

                        Table:UpdateButton()
                        Dropdown:Display()

                        Library:UpdateDependencyBoxes()
                        Dropdown:RunChanged()
                    end)

                    if Info.Multi and Dropdown.DragSelect and not Library.IsMobile then
                        Button.InputBegan:Connect(function(StartInput)
                            if not IsMouseInput(StartInput) then return end

                            DragSelecting = true
                            DragStartIndex = Table.Index
                            table.clear(DragInitialValues)

                            for OtherButton, OtherTable in Buttons do
                                DragInitialValues[OtherTable.Value] = Dropdown.Value[OtherTable.Value]
                            end

                            UpdateDrag(Table.Index)

                            if DragInputEndedConn then DragInputEndedConn:Disconnect() end
                            if DragInputChangedConn then DragInputChangedConn:Disconnect() end

                            DragInputChangedConn = Library:GiveSignal(UserInputService.InputChanged:Connect(function(ChangeInput)
                                if not IsMovementInput(ChangeInput) and ChangeInput ~= StartInput then
                                    return
                                end

                                local Pos = ChangeInput.Position
                                for OtherButton, OtherTable in Buttons do
                                    if Library:MouseIsOverFrame(OtherButton, Pos) then
                                        UpdateDrag(OtherTable.Index)
                                        break
                                    end
                                end
                            end))

                            DragInputEndedConn = Library:GiveSignal(UserInputService.InputEnded:Connect(function(EndInput)
                                if EndInput ~= StartInput and not (IsMouseInput(EndInput) and EndInput.UserInputType == StartInput.UserInputType) then
                                    return
                                end

                                Library:UpdateDependencyBoxes()
                                Dropdown:RunChanged()

                                StopDragSelect()
                            end))

                            table.insert(Dropdown.Connections, DragInputEndedConn)
                            table.insert(Dropdown.Connections, DragInputChangedConn)
                        end)
                    end
                end

                Table:UpdateButton()
                Dropdown:Display()

                Buttons[Button] = Table
            end

            Dropdown:RecalculateListSize(Count)
        end

        function Dropdown:RunChanged()
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
        end

        function Dropdown:SetValue(Value)
            if Info.Multi then
                local Table = {}

                for Val, Active in Value or {} do
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

            Dropdown:Display()
            for _, Button in Buttons do
                Button:UpdateButton()
            end

            if not Dropdown.Disabled then
                Library:UpdateDependencyBoxes()
                Dropdown:RunChanged()
            end
        end

        function Dropdown:SetValues(Values)
            Dropdown.Values = Values
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValues(Values)
            if typeof(Values) == "table" then
                for _, val in Values do
                    table.insert(Dropdown.Values, val)
                end
            elseif typeof(Values) == "string" then
                table.insert(Dropdown.Values, Values)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabledValues(DisabledValues)
            Dropdown.DisabledValues = DisabledValues
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddDisabledValues(DisabledValues)
            if typeof(DisabledValues) == "table" then
                for _, val in DisabledValues do
                    table.insert(Dropdown.DisabledValues, val)
                end
            elseif typeof(DisabledValues) == "string" then
                table.insert(Dropdown.DisabledValues, DisabledValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetValueImages(ValueImages)
            if typeof(ValueImages) ~= "table" then
                return
            end

            Dropdown.ValueImages = ValueImages
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValueImages(ValueImages)
            if typeof(ValueImages) ~= "table" then
                return
            end

            for key, val in ValueImages do
                Dropdown.ValueImages[key] = val
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabled(Disabled)
            Dropdown.Disabled = Disabled

            if Dropdown.TooltipTable then
                Dropdown.TooltipTable.Disabled = Dropdown.Disabled
            end

            MenuTable:Close()
            DisplayButton.Active = not Dropdown.Disabled
            Dropdown:UpdateColors()
        end

        function Dropdown:SetVisible(Visible)
            Dropdown.Visible = Visible

            Holder.Visible = Dropdown.Visible
            Groupbox:Resize()
        end

        function Dropdown:SetText(Text)
            Dropdown.Text = Text
            Holder.Size = UDim2.new(1, 0, 0, Text and 39 or 21)

            Label.Text = Text and Text or ""
            Label.Visible = not not Text
        end

        function Dropdown:SetDragSelect(Value)
            if not Info.Multi or Library.IsMobile then
                Value = false
            end

            Dropdown.DragSelect = Value == true
            Dropdown:BuildDropdownList()
        end

        local ToggleDropdown = function()
            if Dropdown.Disabled then
                return
            end

            MenuTable:Toggle()
        end

        table.insert(Dropdown.Connections, DisplayContainer.MouseButton1Click:Connect(ToggleDropdown))
        table.insert(Dropdown.Connections, DisplayButton.MouseButton1Click:Connect(ToggleDropdown))

        if SearchBox then
            table.insert(Dropdown.Connections, SearchBox:GetPropertyChangedSignal("Text"):Connect(Dropdown.BuildDropdownList))
        end

        local Defaults = {}
        if typeof(Info.Default) == "string" then
            local Index = table.find(Dropdown.Values, Info.Default)
            if Index then
                table.insert(Defaults, Index)
            end
        elseif typeof(Info.Default) == "table" then
            for _, Value in next, Info.Default do
                local Index = table.find(Dropdown.Values, Value)
                if Index then
                    table.insert(Defaults, Index)
                end
            end
        elseif Dropdown.Values[Info.Default] ~= nil then
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

                if not Info.Multi then
                    break
                end
            end
        end

        if typeof(Dropdown.Tooltip) == "string" or typeof(Dropdown.DisabledTooltip) == "string" then
            Dropdown.TooltipTable = Library:AddTooltip(Dropdown.Tooltip, Dropdown.DisabledTooltip, DisplayContainer)
            Dropdown.TooltipTable.Disabled = Dropdown.Disabled
        end

        Dropdown:UpdateColors()
        Dropdown:Display()
        Dropdown:BuildDropdownList()
        Groupbox:Resize()

        Dropdown.Holder = Holder
        table.insert(Groupbox.Elements, Dropdown)

        Dropdown.Default = Defaults
        Dropdown.DefaultValues = Dropdown.Values

        Options[Idx] = Dropdown

        function Dropdown:Destroy()
            Dropdown.Destroyed = true

            StopDragSelect()

            if Dropdown.Connections then
                for _, Connection in Dropdown.Connections do
                    Connection:Disconnect()
                end
            end

            if Dropdown.TooltipTable then
                Dropdown.TooltipTable:Destroy()
            end

            if MenuTable then
                MenuTable:Destroy()
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Dropdown)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Dropdown
    end

    function Funcs:AddViewport(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Viewport)

        local Groupbox = self
        local Container = Groupbox.Container

        local Dragging, Pinching = false, false
        local LastMousePos, LastPinchDist = nil, 0

        local ViewportObject = Info.Object
        if Info.Clone and typeof(Info.Object) == "Instance" then
            if Info.Object.Archivable then
                ViewportObject = ViewportObject:Clone()
            else
                Info.Object.Archivable = true
                ViewportObject = ViewportObject:Clone()
                Info.Object.Archivable = false
            end
        end

        local Viewport = {
            Connections = {},
            Destroyed = false,

            Object = ViewportObject,
            Camera = if not Info.Camera then Instance.new("Camera") else Info.Camera,
            Interactive = Info.Interactive,
            AutoFocus = Info.AutoFocus,
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
            local ModelPosition = (Viewport.Object):GetPivot().Position

            Viewport.Camera.CFrame = CFrame.new(ModelPosition + Vector3.new(0, MaxExtent / 2, CameraDistance), ModelPosition)
        end

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Viewport.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ViewportFrame = New("ViewportFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = Box,
            CurrentCamera = Viewport.Camera,
            Active = Viewport.Interactive,
        })

        table.insert(Viewport.Connections, ViewportFrame.MouseEnter:Connect(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in Groupbox.Tab.Sides do
                Side.ScrollingEnabled = false
            end
        end))

        table.insert(Viewport.Connections, ViewportFrame.MouseLeave:Connect(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in Groupbox.Tab.Sides do
                Side.ScrollingEnabled = true
            end
        end))

        table.insert(Viewport.Connections, ViewportFrame.InputBegan:Connect(function(input)
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
        end))

        table.insert(Viewport.Connections, UserInputService.InputEnded:Connect(function(input)
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

        table.insert(Viewport.Connections, UserInputService.InputChanged:Connect(function(input)
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

                local Position = (Viewport.Object):GetPivot().Position
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

        table.insert(Viewport.Connections, ViewportFrame.InputChanged:Connect(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseWheel then
                local ZoomAmount = input.Position.Z * 2
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * ZoomAmount
            end
        end))

        table.insert(Viewport.Connections, UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state)
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

        ;(Viewport.Object).Parent = ViewportFrame
        if Viewport.AutoFocus then
            FocusCamera()
        end

        function Viewport:SetObject(Object, Clone)
            assert(Object, "Object cannot be nil.")

            if Clone then
                Object = Object:Clone()
            end

            if Viewport.Object then
                Viewport.Object:Destroy()
            end

            Viewport.Object = Object
            ;(Viewport.Object).Parent = ViewportFrame

            Groupbox:Resize()
        end

        function Viewport:SetHeight(Height)
            assert(Height > 0, "Height must be greater than 0.")

            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Viewport:Focus()
            if not Viewport.Object then
                return
            end

            FocusCamera()
        end

        function Viewport:SetCamera(Camera)
            assert(
                Camera and typeof(Camera) == "Instance" and Camera:IsA("Camera"),
                "Camera must be a valid Camera instance."
            )

            Viewport.Camera = Camera
            ViewportFrame.CurrentCamera = Camera
        end

        function Viewport:SetInteractive(Interactive)
            Viewport.Interactive = Interactive
            ViewportFrame.Active = Interactive
        end

        function Viewport:SetVisible(Visible)
            Viewport.Visible = Visible

            Holder.Visible = Viewport.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Viewport.Holder = Holder
        table.insert(Groupbox.Elements, Viewport)

        Options[Idx] = Viewport

        function Viewport:Destroy()
            Viewport.Destroyed = true

            if Viewport.Connections then
                for _, Connection in Viewport.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Viewport)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Viewport
    end

    function Funcs:AddImage(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Image)

        local Groupbox = self
        local Container = Groupbox.Container

        local Image = {
            Connections = {},
            Destroyed = false,

            Image = Info.Image,
            Color = Info.Color,
            RectOffset = Info.RectOffset,
            RectSize = Info.RectSize,
            Height = Info.Height,
            ScaleType = Info.ScaleType,
            Transparency = Info.Transparency,
            BackgroundTransparency = Info.BackgroundTransparency,

            Visible = Info.Visible,
            Type = "Image",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Image.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            BackgroundTransparency = Image.BackgroundTransparency,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
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
            Parent = Box,
        }

        local Icon = Library:GetCustomIcon(ImageProperties.Image)
        assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        ImageProperties.Image = Icon.Url
        ImageProperties.ImageRectOffset = Icon.ImageRectOffset
        ImageProperties.ImageRectSize = Icon.ImageRectSize

        local ImageLabel = New("ImageLabel", ImageProperties)

        function Image:SetHeight(Height)
            assert(Height > 0, "Height must be greater than 0.")

            Image.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Image:SetImage(NewImage)
            assert(typeof(NewImage) == "string", "Image must be a string.")

            local Icon = Library:GetCustomIcon(NewImage)
            assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            NewImage = Icon.Url
            Image.RectOffset = Icon.ImageRectOffset
            Image.RectSize = Icon.ImageRectSize

            ImageLabel.Image = NewImage
            Image.Image = NewImage
        end

        function Image:SetColor(Color)
            assert(typeof(Color) == "Color3", "Color must be a Color3 value.")

            ImageLabel.ImageColor3 = Color
            Image.Color = Color
        end

        function Image:SetRectOffset(RectOffset)
            assert(typeof(RectOffset) == "Vector2", "RectOffset must be a Vector2 value.")

            ImageLabel.ImageRectOffset = RectOffset
            Image.RectOffset = RectOffset
        end

        function Image:SetRectSize(RectSize)
            assert(typeof(RectSize) == "Vector2", "RectSize must be a Vector2 value.")

            ImageLabel.ImageRectSize = RectSize
            Image.RectSize = RectSize
        end

        function Image:SetScaleType(ScaleType)
            assert(
                typeof(ScaleType) == "EnumItem" and ScaleType:IsA("ScaleType"),
                "ScaleType must be a valid Enum.ScaleType."
            )

            ImageLabel.ScaleType = ScaleType
            Image.ScaleType = ScaleType
        end

        function Image:SetTransparency(Transparency)
            assert(typeof(Transparency) == "number", "Transparency must be a number between 0 and 1.")
            assert(Transparency >= 0 and Transparency <= 1, "Transparency must be between 0 and 1.")

            ImageLabel.ImageTransparency = Transparency
            Image.Transparency = Transparency
        end

        function Image:SetVisible(Visible)
            Image.Visible = Visible

            Holder.Visible = Image.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Image.Holder = Holder
        table.insert(Groupbox.Elements, Image)

        Options[Idx] = Image

        function Image:Destroy()
            Image.Destroyed = true

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Image)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Image
    end

    function Funcs:AddVideo(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Video)

        local Groupbox = self
        local Container = Groupbox.Container

        local Video = {
            Connections = {},
            Destroyed = false,

            Video = Info.Video,
            Looped = Info.Looped,
            Playing = Info.Playing,
            Volume = Info.Volume,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "Video",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Video.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local VideoFrameInstance = New("VideoFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Video = Video.Video,
            Looped = Video.Looped,
            Volume = Video.Volume,
            Parent = Box,
        })

        VideoFrameInstance.Playing = Video.Playing

        function Video:SetHeight(Height)
            assert(Height > 0, "Height must be greater than 0.")

            Video.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Video:SetVideo(NewVideo)
            assert(typeof(NewVideo) == "string", "Video must be a string.")

            VideoFrameInstance.Video = NewVideo
            Video.Video = NewVideo
        end

        function Video:SetLooped(Looped)
            assert(typeof(Looped) == "boolean", "Looped must be a boolean.")

            VideoFrameInstance.Looped = Looped
            Video.Looped = Looped
        end

        function Video:SetVolume(Volume)
            assert(typeof(Volume) == "number", "Volume must be a number between 0 and 10.")

            VideoFrameInstance.Volume = Volume
            Video.Volume = Volume
        end

        function Video:SetPlaying(Playing)
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

        function Video:SetVisible(Visible)
            Video.Visible = Visible

            Holder.Visible = Video.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Video.Holder = Holder
        Video.VideoFrame = VideoFrameInstance
        table.insert(Groupbox.Elements, Video)

        Options[Idx] = Video

        function Video:Destroy()
            Video.Destroyed = true

            if Video.Connections then
                for _, Connection in Video.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Video)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Video
    end

    function Funcs:AddUIPassthrough(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.UIPassthrough)

        local Groupbox = self
        local Container = Groupbox.Container

        assert(Info.Instance, "Instance must be provided.")
        assert(
            typeof(Info.Instance) == "Instance" and Info.Instance:IsA("GuiBase2d"),
            "Instance must inherit from GuiBase2d."
        )
        assert(typeof(Info.Height) == "number" and Info.Height > 0, "Height must be a number greater than 0.")

        local Passthrough = {
            Connections = {},
            Destroyed = false,

            Instance = Info.Instance,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "UIPassthrough",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Passthrough.Visible,
            Parent = Container,
        })

        Passthrough.Instance.Parent = Holder

        Groupbox:Resize()

        function Passthrough:SetHeight(Height)
            assert(typeof(Height) == "number" and Height > 0, "Height must be a number greater than 0.")

            Passthrough.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Passthrough:SetInstance(Instance)
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
        end

        function Passthrough:SetVisible(Visible)
            Passthrough.Visible = Visible

            Holder.Visible = Passthrough.Visible
            Groupbox:Resize()
        end

        Passthrough.Holder = Holder
        table.insert(Groupbox.Elements, Passthrough)

        Options[Idx] = Passthrough

        function Passthrough:Destroy()
            Passthrough.Destroyed = true

            if Passthrough.Connections then
                for _, Connection in Passthrough.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then
                Holder:Destroy()
            end

            local ElemIdx = table.find(Groupbox.Elements, Passthrough)
            if ElemIdx then
                table.remove(Groupbox.Elements, ElemIdx)
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Passthrough
    end

    function Funcs:AddDependencyBox()
        if self.Destroyed then return nil end

        local Groupbox = self
        local Container = Groupbox.Container

        local DepboxContainer
        local DepboxList

        do
            DepboxContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })

            DepboxList = New("UIListLayout", {
                Padding = UDim.new(0, 8),
                Parent = DepboxContainer,
            })
        end

        local Depbox = {
            Connections = {},
            Destroyed = false,

            Visible = false,
            Dependencies = {},

            Holder = DepboxContainer,
            Container = DepboxContainer,

            Elements = {},
            DependencyBoxes = {}
        }

        function Depbox:Resize()
            DepboxContainer.Size = UDim2.new(1, 0, 0, DepboxList.AbsoluteContentSize.Y / Library.DPIScale)
            Groupbox:Resize()
        end

        function Depbox:Update(CancelSearch)
            for _, Dependency in Depbox.Dependencies do
                local Element = Dependency[1]
                local Value = Dependency[2]

                if Element.Type == "Toggle" and Element.Value ~= Value then
                    DepboxContainer.Visible = false
                    Depbox.Visible = false
                    return
                elseif Element.Type == "Dropdown" then
                    if typeof(Element.Value) == "table" then
                        if not Element.Value[Value] then
                            DepboxContainer.Visible = false
                            Depbox.Visible = false
                            return
                        end
                    else
                        if Element.Value ~= Value then
                            DepboxContainer.Visible = false
                            Depbox.Visible = false
                            return
                        end
                    end
                end
            end

            Depbox.Visible = true
            DepboxContainer.Visible = true
            if not Library.Searching then
                task.defer(function()
                    Depbox:Resize()
                end)
            elseif not CancelSearch then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        DepboxList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if not Depbox.Visible then
                return
            end

            Depbox:Resize()
        end)

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in Dependencies do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            Depbox.Dependencies = Dependencies
            Depbox:Update()
        end

        DepboxContainer:GetPropertyChangedSignal("Visible"):Connect(function()
            Depbox:Resize()
        end)

        setmetatable(Depbox, BaseGroupbox)

        table.insert(Groupbox.DependencyBoxes, Depbox)
        table.insert(Library.DependencyBoxes, Depbox)

        function Depbox:Destroy()
            Depbox.Destroyed = true

            if Depbox.Connections then
                for _, Connection in Depbox.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Element in Depbox.Elements do
                if Element.Destroy then
                    Element:Destroy()
                end
            end

            for _, SubDepbox in Depbox.DependencyBoxes do
                if SubDepbox.Destroy then
                    SubDepbox:Destroy()
                end
            end

            if DepboxContainer then
                DepboxContainer:Destroy()
            end

            local ElemIdx = table.find(Groupbox.DependencyBoxes, Depbox)
            if ElemIdx then
                table.remove(Groupbox.DependencyBoxes, ElemIdx)
            end

            local LibIdx = table.find(Library.DependencyBoxes, Depbox)
            if LibIdx then
                table.remove(Library.DependencyBoxes, LibIdx)
            end
        end

        return Depbox
    end

    function Funcs:AddDependencyGroupbox()
        if self.Destroyed then return nil end

        local Groupbox = self
        local Tab = Groupbox.Tab
        local BoxHolder = Groupbox.BoxHolder

        local DepGroupboxContainer
        local DepGroupboxList

        do
            DepGroupboxContainer = New("Frame", {
                BackgroundColor3 = "BackgroundColor",
                Size = UDim2.fromScale(1, 0),
                Visible = false,
                Parent = BoxHolder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius),
                    Parent = DepGroupboxContainer,
                })
            )
            Library:AddOutline(DepGroupboxContainer)

            DepGroupboxList = New("UIListLayout", {
                Padding = UDim.new(0, 8),
                Parent = DepGroupboxContainer,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 7),
                PaddingLeft = UDim.new(0, 7),
                PaddingRight = UDim.new(0, 7),
                PaddingTop = UDim.new(0, 7),
                Parent = DepGroupboxContainer,
            })
        end

        local DepGroupbox = {
            Connections = {},
            Destroyed = false,

            Visible = false,
            Dependencies = {},

            BoxHolder = BoxHolder,
            Holder = DepGroupboxContainer,
            Container = DepGroupboxContainer,

            Tab = Tab,
            Elements = {},
            DependencyBoxes = {},
        }

        function DepGroupbox:Resize()
            DepGroupboxContainer.Size = UDim2.new(1, 0, 0, (DepGroupboxList.AbsoluteContentSize.Y / Library.DPIScale) + 18)
        end

        function DepGroupbox:Update(CancelSearch)
            for _, Dependency in DepGroupbox.Dependencies do
                local Element = Dependency[1]
                local Value = Dependency[2]

                if Element.Type == "Toggle" and Element.Value ~= Value then
                    DepGroupboxContainer.Visible = false
                    DepGroupbox.Visible = false
                    return
                elseif Element.Type == "Dropdown" then
                    if typeof(Element.Value) == "table" then
                        if not Element.Value[Value] then
                            DepGroupboxContainer.Visible = false
                            DepGroupbox.Visible = false
                            return
                        end
                    else
                        if Element.Value ~= Value then
                            DepGroupboxContainer.Visible = false
                            DepGroupbox.Visible = false
                            return
                        end
                    end
                end
            end

            DepGroupbox.Visible = true
            if not Library.Searching then
                DepGroupboxContainer.Visible = true
                DepGroupbox:Resize()
            elseif not CancelSearch then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function DepGroupbox:SetupDependencies(Dependencies)
            for _, Dependency in Dependencies do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            DepGroupbox.Dependencies = Dependencies
            DepGroupbox:Update()
        end

        setmetatable(DepGroupbox, BaseGroupbox)

        table.insert(Tab.DependencyGroupboxes, DepGroupbox)
        table.insert(Library.DependencyBoxes, DepGroupbox)

        function DepGroupbox:Destroy()
            DepGroupbox.Destroyed = true

            if DepGroupbox.Connections then
                for _, Connection in DepGroupbox.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Element in DepGroupbox.Elements do
                if Element.Destroy then
                    Element:Destroy()
                end
            end

            for _, SubDepbox in DepGroupbox.DependencyBoxes do
                if SubDepbox.Destroy then
                    SubDepbox:Destroy()
                end
            end

            if DepGroupboxContainer then
                DepGroupboxContainer:Destroy()
            end

            local ElemIdx = table.find(Tab.DependencyGroupboxes, DepGroupbox)
            if ElemIdx then
                table.remove(Tab.DependencyGroupboxes, ElemIdx)
            end

            local LibIdx = table.find(Library.DependencyBoxes, DepGroupbox)
            if LibIdx then
                table.remove(Library.DependencyBoxes, LibIdx)
            end
        end

        return DepGroupbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(_, Key, ...)
        return Funcs[Key](...)
    end
end

function Library:SetFont(FontFace)
    if typeof(FontFace) == "EnumItem" then
        FontFace = Font.fromEnum(FontFace)
    end

    Library.Scheme.Font = FontFace
    Library:UpdateColorsUsingRegistry()
end

function Library:SetBackgroundImage(Image)
    assert(typeof(Image) == "string" or typeof(Image) == "number", "Expected string/number got " .. typeof(Image))

    Library.Scheme.BackgroundImage = Image
    if Library.Window then
        Library.Window:SetBackgroundImage(Image)
    end

    Library:UpdateColorsUsingRegistry()
end

function Library:UpdateNotificationPositions(Snap)
    local IsLeft = Library.NotifySide:lower() == "left"
    local XScale = IsLeft and 0 or 1
    local RunningY = 0

    for _, FakeBackground in NotifyOrder do
        local Data = Library.Notifications[FakeBackground]
        if not (Data and FakeBackground.Parent) then continue end

        local Target = UDim2.new(XScale, 0, 0, RunningY)
        if Snap or not Data.PositionInitialized then
            FakeBackground.Position = Target
            Data.PositionInitialized = true

        elseif FakeBackground.Position ~= Target then
            TweenService:Create(FakeBackground, Library.NotifyTweenInfo, {
                Position = Target,
            }):Play()
        end

        RunningY = RunningY + FakeBackground.AbsoluteSize.Y + 8
    end
end

function Library:SetNotifySide(Side)
    Library.NotifySide = Side

    local IsLeft = Side:lower() == "left"
    if IsLeft then
        NotificationArea.AnchorPoint = Vector2.new(0, 0)
        NotificationArea.Position = UDim2.fromOffset(6, 6)
    else
        NotificationArea.AnchorPoint = Vector2.new(1, 0)
        NotificationArea.Position = UDim2.new(1, -6, 0, 6)
    end

    for FakeBackground in Library.Notifications do
        if not (FakeBackground and FakeBackground.Parent) then continue end
        FakeBackground.AnchorPoint = if IsLeft then Vector2.new(0, 0) else Vector2.new(1, 0)
    end

    Library:UpdateNotificationPositions(true)
end

function Library:Notify(...)
    local Data = {}
    local Info = select(1, ...)

    if typeof(Info) == "table" then
        Data.Title = tostring(Info.Title)
        Data.TitleColor = Info.TitleColor

        Data.Description = tostring(Info.Description)
        Data.DescriptionColor = Info.DescriptionColor

        Data.Time = Info.Time or 5
        Data.SoundId = Info.SoundId
        Data.Steps = Info.Steps
        Data.Persist = Info.Persist

        Data.Icon = Info.Icon
        Data.BigIcon = Info.BigIcon
        Data.IconColor = Info.IconColor

        Data.Volume = tonumber(Info.Volume) or 3
    else
        Data.Description = tostring(Info)
        Data.Time = select(2, ...) or 5
        Data.SoundId = select(3, ...)
        Data.Volume = select(4, ...) or 3
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

    local FakeBackground = New("Frame", {
        AnchorPoint = Library.NotifySide:lower() == "left" and Vector2.new(0, 0) or Vector2.new(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        Visible = false,
        Parent = NotificationArea,
    })

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        Position = Library.NotifySide:lower() == "left" and UDim2.new(-1, -8, 0, -2) or UDim2.new(1, 8, 0, -2),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
        Parent = FakeBackground,
    })
    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Holder,
        })
    )
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = Holder,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 8),
        Parent = Holder,
    })
    Library:AddOutline(Holder)

    local ContentContainer = New("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromScale(1, 0),
        Parent = Holder,
    })

    if Data.BigIcon then
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = ContentContainer,
        })
    end

    local BigIconLabel
    if Data.BigIcon then
        local ParsedIcon = Library:GetCustomIcon(Data.BigIcon)
        if ParsedIcon then
            BigIconLabel = New("ImageLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(24, 24),
                Image = ParsedIcon.Url,
                ImageColor3 = Data.IconColor or "AccentColor",
                ImageRectOffset = ParsedIcon.ImageRectOffset,
                ImageRectSize = ParsedIcon.ImageRectSize,
                Parent = ContentContainer,
            })
        end
    end

    local TextContainer = New("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromScale(0, 0),
        Parent = ContentContainer,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = TextContainer,
    })

    local TitleContainer
    if Data.Title then
        TitleContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(0, 0),
            Parent = TextContainer,
        })
    end

    local IconLabel
    if Data.Icon and TitleContainer then
        local ParsedIcon = Library:GetCustomIcon(Data.Icon)
        if ParsedIcon then
            IconLabel = New("ImageLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 1),
                Size = UDim2.fromOffset(15, 15),
                Image = ParsedIcon.Url,
                ImageColor3 = Data.IconColor or "FontColor",
                ImageRectOffset = ParsedIcon.ImageRectOffset,
                ImageRectSize = ParsedIcon.ImageRectSize,
                Parent = TitleContainer,
            })
        end
    end

    local Title
    local Desc
    local TitleX = 0
    local DescX = 0

    local TimerFill

    if Data.Title then
        Title = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.None,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, (Data.Icon and 21 or 0), 0.5, 0),
            Size = UDim2.fromScale(0, 0),
            Text = Data.Title,
            TextColor3 = Data.TitleColor or "FontColor",
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true,
            Parent = TitleContainer,
        })
    end

    if Data.Description then
        Desc = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.None,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(0, 0),
            Text = Data.Description,
            TextColor3 = Data.DescriptionColor or "FontColor",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Parent = TextContainer,
        })
    end

    function Data:Resize()
        local ExtraWidth = BigIconLabel and 32 or 0
        local IconWidth = IconLabel and 21 or 0

        if Title then
            local X, Y =
                Library:GetTextBounds(Title.Text, Title.FontFace, Title.TextSize, (NotificationArea.AbsoluteSize.X / Library.DPIScale) - 24 - ExtraWidth - IconWidth)
            Title.Size = UDim2.fromOffset(X, Y)
            TitleX = X + IconWidth
            TitleContainer.Size = UDim2.fromOffset(TitleX, math.max(Y, IconLabel and 16 or 0))
        end

        if Desc then
            local X, Y =
                Library:GetTextBounds(Desc.Text, Desc.FontFace, Desc.TextSize, (NotificationArea.AbsoluteSize.X / Library.DPIScale) - 24 - ExtraWidth)
            Desc.Size = UDim2.fromOffset(X, Y)
            DescX = X
        end

        FakeBackground.Size = UDim2.fromOffset(math.max(TitleX, DescX) + 24 + ExtraWidth, 0)

        if Library.Notifications[FakeBackground] then
            Library:UpdateNotificationPositions()
        end
    end

    function Data:ChangeTitle(Text)
        if Title then
            Data.Title = tostring(Text)
            Title.Text = Data.Title
            Data:Resize()
        end
    end

    function Data:ChangeDescription(Text)
        if Desc then
            Data.Description = tostring(Text)
            Desc.Text = Data.Description
            Data:Resize()
        end
    end

    function Data:ChangeStep(NewStep)
        if TimerFill and Data.Steps then
            NewStep = math.clamp(NewStep or 0, 0, Data.Steps)
            TimerFill.Size = UDim2.fromScale(NewStep / Data.Steps, 1)
        end
    end

    function Data:Destroy()
        Data.Destroyed = true

        if typeof(Data.Time) == "Instance" then
            pcall(Data.Time.Destroy, Data.Time)
        end

        if DeleteConnection then
            DeleteConnection:Disconnect()
        end

        if FakeBackground then
            local Idx = table.find(NotifyOrder, FakeBackground)
            if Idx then
                table.remove(NotifyOrder, Idx)
            end
        end

        Library:UpdateNotificationPositions()

        TweenService
            :Create(Holder, Library.NotifyTweenInfo, {
                Position = Library.NotifySide:lower() == "left" and UDim2.new(-1, -8, 0, -2) or UDim2.new(1, 8, 0, -2),
            })
            :Play()

        task.delay(Library.NotifyTweenInfo.Time, function()
            Library.Notifications[FakeBackground] = nil
            FakeBackground:Destroy()
        end)
    end

    Data:Resize()

    local TimerHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 7),
        Visible = (Data.Persist ~= true and typeof(Data.Time) ~= "Instance") or typeof(Data.Steps) == "number",
        Parent = Holder,
    })
    local TimerBar = New("Frame", {
        BackgroundColor3 = "BackgroundColor",
        BorderColor3 = "OutlineColor",
        BorderSizePixel = 1,
        Position = UDim2.fromOffset(0, 3),
        Size = UDim2.new(1, 0, 0, 2),
        Parent = TimerHolder,
    })
    TimerFill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        Size = UDim2.fromScale(1, 1),
        Parent = TimerBar,
    })

    if typeof(Data.Time) == "Instance" then
        TimerFill.Size = UDim2.fromScale(0, 1)
    end
    if Data.SoundId then
        local SoundId = Data.SoundId
        if typeof(SoundId) == "number" then
            SoundId = string.format("rbxassetid://%d", SoundId)
        end

        New("Sound", {
            SoundId = SoundId,
            Volume = tonumber(Data.Volume) or 3,
            PlayOnRemove = true,
            Parent = SoundService,
        }):Destroy()
    end

    Data.Holder = Holder

    table.insert(NotifyOrder, FakeBackground)
    Library.Notifications[FakeBackground] = Data

    Library:UpdateNotificationPositions()

    FakeBackground.Visible = true
    TweenService:Create(Holder, Library.NotifyTweenInfo, {
        Position = UDim2.fromOffset(0, 0),
    }):Play()

    task.delay(Library.NotifyTweenInfo.Time, function()
        if Data.Persist then
            return
        elseif typeof(Data.Time) == "Instance" then
            repeat
                task.wait()
            until DeletedInstance or Data.Destroyed
        else
            TweenService
                :Create(TimerFill, TweenInfo.new(Data.Time, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
                    Size = UDim2.fromScale(0, 1),
                })
                :Play()
            task.wait(Data.Time)
        end

        if not Data.Destroyed then
            Data:Destroy()
        end
    end)

    return Data
end

function Library:CreateWindow(WindowInfo)
    WindowInfo = Library:Validate(WindowInfo, Templates.Window)
    local ViewportSize = workspace.CurrentCamera.ViewportSize
    if RunService:IsStudio() and ViewportSize.X <= 5 and ViewportSize.Y <= 5 then
        repeat
            ViewportSize = workspace.CurrentCamera.ViewportSize
            task.wait()
        until ViewportSize.X > 5 and ViewportSize.Y > 5
    end

    local MaxX = ViewportSize.X - 64
    local MaxY = ViewportSize.Y - 64

    Library.OriginalMinSize =
        Vector2.new(math.min(Library.OriginalMinSize.X, MaxX), math.min(Library.OriginalMinSize.Y, MaxY))
    Library.MinSize = Library.OriginalMinSize

    WindowInfo.Size = UDim2.fromOffset(
        math.clamp(WindowInfo.Size.X.Offset, Library.MinSize.X, MaxX),
        math.clamp(WindowInfo.Size.Y.Offset, Library.MinSize.Y, MaxY)
    )
    if typeof(WindowInfo.Font) == "EnumItem" then
        WindowInfo.Font = Font.fromEnum(WindowInfo.Font)
    end
    WindowInfo.CornerRadius = math.min(WindowInfo.CornerRadius, 20)

    --// Old Naming \\--
    if WindowInfo.Compact ~= nil then
        WindowInfo.SidebarCompacted = WindowInfo.Compact
    end
    if WindowInfo.SidebarMinWidth ~= nil then
        WindowInfo.MinSidebarWidth = WindowInfo.SidebarMinWidth
    end
    WindowInfo.MinSidebarWidth = math.max(64, WindowInfo.MinSidebarWidth)
    WindowInfo.SidebarCompactWidth = math.max(48, WindowInfo.SidebarCompactWidth)
    WindowInfo.SidebarCollapseThreshold = math.clamp(WindowInfo.SidebarCollapseThreshold, 0.1, 0.9)
    WindowInfo.CompactWidthActivation = math.max(48, WindowInfo.CompactWidthActivation)

    Library.CornerRadius = WindowInfo.CornerRadius
    Library:SetNotifySide(WindowInfo.NotifySide)
    Library.ShowCustomCursor = WindowInfo.ShowCustomCursor
    Library.Scheme.Font = WindowInfo.Font
    Library.ToggleKeybind = WindowInfo.ToggleKeybind
    Library.GlobalSearch = WindowInfo.GlobalSearch

    Library.Animations = WindowInfo.Animations
    Library.TabTransitionInfo = TweenInfo.new(
        math.max(0, WindowInfo.TabTransitionTime or 0.22),
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    Library.TabSwipeOffset = math.max(1, WindowInfo.TabSwipeOffset or 26)
    Library.TabSwipeFrom = WindowInfo.TabSwipeFrom or "right"

    local IsDefaultSearchbarSize = WindowInfo.SearchbarSize == UDim2.fromScale(1, 1)
    local MainFrame
    local DividerLine
    local TitleHolder
    local WindowTitle
    local WindowIcon
    local RightWrapper
    local SearchBox
    local CurrentTabInfo
    local CurrentTabLabel
    local CurrentTabDescription
    local ResizeButton
    local Tabs
    local Container
    local BackgroundImage
    local BottomBackground
    local FooterLabel
    local TopBar

    local InitialLeftWidth = math.ceil(WindowInfo.Size.X.Offset * 0.3)
    local IsCompact = WindowInfo.SidebarCompacted
    local LastExpandedWidth = InitialLeftWidth

    do
        Library.KeybindFrame, Library.KeybindContainer = Library:AddDraggableMenu("Keybinds")
        Library.KeybindFrame.AnchorPoint = Vector2.new(0, 0.5)
        Library.KeybindFrame.Position = UDim2.new(0, 6, 0.5, 0)
        Library.KeybindFrame.Visible = false

        MainFrame = New("TextButton", {
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, -1)
            end,
            Name = "Main",
            Text = "",
            Position = WindowInfo.Position,
            Size = WindowInfo.Size,
            Visible = false,
            Parent = ScreenGui,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = MainFrame,
            })
        )
        table.insert(
            Library.Scales,
            New("UIScale", {
                Parent = MainFrame,
            })
        )
        Library:AddOutline(MainFrame)
        Library:MakeLine(MainFrame, {
            Position = UDim2.fromOffset(0, 48),
            Size = UDim2.new(1, 0, 0, 1),
        })

        DividerLine = New("Frame", {
            BackgroundColor3 = "OutlineColor",
            Position = UDim2.fromOffset(InitialLeftWidth, 0),
            Size = UDim2.new(0, 1, 1, -21),
            Parent = MainFrame,
            ZIndex = 2
        })

        local BackgroundIcon = Library:GetCustomIcon(WindowInfo.BackgroundImage)
        BackgroundImage = New("ImageLabel", {
            Image = BackgroundIcon and BackgroundIcon.Url or "",
            ImageRectOffset = BackgroundIcon and BackgroundIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = BackgroundIcon and BackgroundIcon.ImageRectSize or Vector2.zero,
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Stretch,
            ZIndex = 999,
            BackgroundTransparency = 1,
            ImageTransparency = 0.75,
            Visible = BackgroundIcon ~= nil,
            Parent = MainFrame,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = BackgroundImage,
            })
        )

        if WindowInfo.Center then
            MainFrame.Position = UDim2.new(0.5, -MainFrame.Size.X.Offset / 2, 0.5, -MainFrame.Size.Y.Offset / 2)
        end

        --// Top Bar \\-
        TopBar = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 48),
            Parent = MainFrame,
        })
        Library:MakeDraggable(MainFrame, TopBar, false, true)

        --// Title \\--
        TitleHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, InitialLeftWidth, 1, 0),
            Parent = TopBar,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            Parent = TitleHolder,
        })

        if WindowInfo.Icon then
            local Icon = Library:GetCustomIcon(WindowInfo.Icon)
            WindowIcon = New("ImageLabel", {
                Image = Icon and Icon.Url or "",
                ImageRectOffset = Icon and Icon.ImageRectOffset or Vector2.zero,
                ImageRectSize = Icon and Icon.ImageRectSize or Vector2.zero,
                Size = WindowInfo.IconSize,
                Parent = TitleHolder,
            })
        else
            WindowIcon = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = WindowInfo.IconSize,
                Text = WindowInfo.Title:sub(1, 1),
                TextScaled = true,
                Visible = false,
                Parent = TitleHolder,
            })
        end

        local X = Library:GetTextBounds(
            WindowInfo.Title,
            Library.Scheme.Font,
            20,
            TitleHolder.AbsoluteSize.X - (WindowInfo.Icon and WindowInfo.IconSize.X.Offset + 6 or 0) - 12
        )
        WindowTitle = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, X, 1, 0),
            Text = WindowInfo.Title,
            TextSize = 20,
            Parent = TitleHolder,
        })

        --// Top Right Bar \\--
        RightWrapper = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -49, 0.5, 0),
            Size = UDim2.new(1, -InitialLeftWidth - 57 - 1, 1, -16),
            Parent = TopBar,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
            Parent = RightWrapper,
        })

        CurrentTabInfo = New("Frame", {
            Size = UDim2.fromScale(WindowInfo.DisableSearch and 1 or 0.5, 1),
            Visible = false,
            BackgroundTransparency = 1,
            Parent = RightWrapper,
        })

        New("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Grow,
            Parent = CurrentTabInfo,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = CurrentTabInfo,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8),
            Parent = CurrentTabInfo,
        })

        CurrentTabLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = CurrentTabInfo,
        })

        CurrentTabDescription = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            TextWrapped = true,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 0.5,
            Parent = CurrentTabInfo,
        })

        SearchBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            PlaceholderText = "Search",
            Size = WindowInfo.SearchbarSize,
            TextScaled = true,
            Visible = not (WindowInfo.DisableSearch or false),
            Parent = RightWrapper,
        })
        New("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Shrink,
            Parent = SearchBox,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = SearchBox,
            })
        )
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8),
            Parent = SearchBox,
        })
        New("UIStroke", {
            Color = "OutlineColor",
            Parent = SearchBox,
        })

        local SearchIcon = Library:GetIcon("search")
        if SearchIcon then
            New("ImageLabel", {
                Image = SearchIcon.Url,
                ImageColor3 = "FontColor",
                ImageRectOffset = SearchIcon.ImageRectOffset,
                ImageRectSize = SearchIcon.ImageRectSize,
                ImageTransparency = 0.5,
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = SearchBox,
            })
        end

        if MoveIcon then
            New("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Image = MoveIcon.Url,
                ImageColor3 = "OutlineColor",
                ImageRectOffset = MoveIcon.ImageRectOffset,
                ImageRectSize = MoveIcon.ImageRectSize,
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(28, 28),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = TopBar,
            })
        end

        --// Bottom Bar \\--
        BottomBackground = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, 4)
            end,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 20 + WindowInfo.CornerRadius),
            Parent = MainFrame
        })
        Library:MakeLine(MainFrame, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -20),
            Size = UDim2.new(1, 0, 0, 1),
        })

        local BottomBar = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 20),
            Parent = MainFrame,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = BottomBackground,
            })
        )

        --// Footer \\-
        FooterLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = WindowInfo.Footer,
            TextSize = 14,
            TextTransparency = 0.5,
            Parent = BottomBar,
        })

        --// Resize Button \\--
        if WindowInfo.Resizable then
            ResizeButton = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -WindowInfo.CornerRadius / 4, 0, 0),
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Text = "",
                Parent = BottomBar,
            })

            Library:MakeResizable(MainFrame, ResizeButton, function()
                for _, Tab in Library.Tabs do
                    Tab:Resize(true)
                end
            end)
        end

        New("ImageLabel", {
            Image = ResizeIcon and ResizeIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = ResizeIcon and ResizeIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = ResizeIcon and ResizeIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 0.5,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 1, -4),
            Parent = ResizeButton,
        })

        --// Tabs \\--
        Tabs = New("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = "BackgroundColor",
            CanvasSize = UDim2.fromScale(0, 0),
            Position = UDim2.fromOffset(0, 49),
            ScrollBarThickness = 0,
            Size = UDim2.new(0, InitialLeftWidth, 1, -70),
            Parent = MainFrame,
        })
        New("UIListLayout", {
            Parent = Tabs,
        })

        --// Container \\--
        Container = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, 1)
            end,
            ClipsDescendants = true,
            Name = "Container",
            Position = UDim2.new(1, 0, 0, 49),
            Size = UDim2.new(1, -InitialLeftWidth - 1, 1, -70),
            Parent = MainFrame,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 0),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 0),
            Parent = Container,
        })

        Library.WindowContainer = Container
    end

    --// Window Table \\--
    local Window = {}
    local Fading = false

    local function SetUICorner(UICorner, Corner, HalfCurrent, HalfValue, Value)
        local Current = UICorner[Corner]
        if Current.Offset == 0 and Current.Scale == 0 then
            return
        end

        UICorner[Corner] = Current.Offset == HalfCurrent and HalfValue or Value
    end

    function Window:ChangeTitle(title)
        assert(typeof(title) == "string", "Expected string for title got: " .. typeof(title))

        WindowTitle.Text = title
        WindowInfo.Title = title
    end

    function Window:SetBackgroundImage(Image)
        local ValidIcon = false

        if typeof(Image) == "string" then
            local BackgroundIcon = Library:GetCustomIcon(Image)

            if BackgroundIcon then
                ValidIcon = true

                BackgroundImage.Image = BackgroundIcon.Url
                BackgroundImage.ImageRectOffset = BackgroundIcon.ImageRectOffset
                BackgroundImage.ImageRectSize = BackgroundIcon.ImageRectSize
                BackgroundImage.Visible = true
            elseif Image:match("http://") or Image:match("https://") then
                local RawFileName = Image:match("(.+)%..+$")
                local _, Domain = Image:match("^(https?://)([^/]+)");

                if RawFileName and Domain then
                    local Extention = string.sub(Image, #RawFileName + 1, #Image)
                    local FileNamePos = RawFileName:gsub("\\", "/"):find("/[^/]*$")
                    local FileName = FileNamePos and Image:sub(FileNamePos + 1) or nil

                    if FileName then
                        ValidIcon = true

                        local AssetName = Domain .. FileName
                        if #AssetName > 255 then
                            local NewLength = 255 - #Domain - #Extention
                            if NewLength < 0 then
                                AssetName = Domain .. Extention
                            else
                                AssetName = Domain .. string.sub(FileName:sub(1, #FileName - #Extention), 1, NewLength) .. Extention
                            end
                        end

                        if CustomImageManagerAssets[FileName] == nil then
                            CustomImageManager.AddAsset(FileName, 0, Image)
                        else
                            CustomImageManager.DownloadAsset(FileName, true)
                        end

                        BackgroundImage.Image = CustomImageManager.GetAsset(FileName)
                        BackgroundImage.ImageRectOffset = Vector2.zero
                        BackgroundImage.ImageRectSize = Vector2.zero
                        BackgroundImage.Visible = true
                    end
                end
            end
        end

        if not ValidIcon then
            BackgroundImage.Image = ""
            BackgroundImage.ImageRectOffset = Vector2.zero
            BackgroundImage.ImageRectSize = Vector2.zero
            BackgroundImage.Visible = false
        end

        WindowInfo.BackgroundImage = Image
    end

    function Window:SetFooter(Footer)
        assert(typeof(Footer) == "string", "Expected string for footer got: " .. typeof(Footer))

        FooterLabel.Text = Footer
        WindowInfo.Footer = Footer
    end

    function Window:SetCornerRadius(Radius)
        assert(typeof(Radius) == "number", "Expected number for Radius got: " .. typeof(Radius))
        Radius = math.min(Radius, 20)

        local RadiusHalf = UDim.new(0, Radius / 2)
        local RadiusUDim = UDim.new(0, Radius)
        local HalfCurrent = Library.CornerRadius / 2

        for _, UICorner in Library.Corners do
            if UICorner.CornerRadius.Offset == HalfCurrent then
                UICorner.CornerRadius = RadiusHalf
            else
                UICorner.CornerRadius = RadiusUDim
            end
        end

        for _, UICorner in Library.SpecificCorners do
            SetUICorner(UICorner, "TopRightRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "TopLeftRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "BottomRightRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "BottomLeftRadius", HalfCurrent, RadiusHalf, RadiusUDim)
        end

        Library.CornerRadius = Radius
        WindowInfo.CornerRadius = Radius

        ResizeButton.Position = UDim2.new(1, -Radius / 4, 0, 0)
        BottomBackground.Size = UDim2.new(1, 0, 0, 20 + Radius)

        for _, Tab in Library.Tabs do
            if Tab.IsKeyTab then
                continue
            end

            for _, Tabbox in Tab.Tabboxes do
                Tabbox:UpdateCorners()
            end
        end
    end

    function Window:SetAnimations(Animations, TabTransitionTime, TabSwipeOffset, TabSwipeFrom)
        if typeof(Animations) == "table" then
            WindowInfo.Animations = Animations
            Library.Animations = Animations
        end

        if typeof(TabTransitionTime) == "number" then
            local TweenInfo = TweenInfo.new(
                math.max(0, TabTransitionTime or 0.22),
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )

            WindowInfo.TabTransitionInfo = TweenInfo
            Library.TabTransitionInfo = TweenInfo
        end

        if typeof(TabSwipeOffset) == "number" then
            TabSwipeOffset = math.max(1, TabSwipeOffset)

            WindowInfo.TabSwipeOffset = TabSwipeOffset
            Library.TabSwipeOffset = TabSwipeOffset
        end

        if typeof(TabSwipeFrom) == "string" then
            TabSwipeFrom = string.lower(TabSwipeFrom)

            WindowInfo.TabSwipeFrom = TabSwipeFrom
            Library.TabSwipeFrom = TabSwipeFrom
        end
    end

    local function ApplyCompact()
        IsCompact = Window:GetSidebarWidth() == WindowInfo.SidebarCompactWidth
        if WindowInfo.DisableCompactingSnap then
            IsCompact = Window:GetSidebarWidth() <= WindowInfo.CompactWidthActivation
        end

        WindowTitle.Visible = not IsCompact
        if not WindowInfo.Icon then
            WindowIcon.Visible = IsCompact
        end

        for _, Button in Library.TabButtons do
            if not Button.Icon then
                continue
            end

            Button.Label.Visible = not IsCompact
            Button.Padding.PaddingBottom = UDim.new(0, IsCompact and 6 or 11)
            Button.Padding.PaddingLeft = UDim.new(0, IsCompact and 6 or 12)
            Button.Padding.PaddingRight = UDim.new(0, IsCompact and 6 or 12)
            Button.Padding.PaddingTop = UDim.new(0, IsCompact and 6 or 11)
            Button.Icon.SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY
        end
    end

    function Window:IsSidebarCompacted()
        return IsCompact
    end

    function Window:SetCompact(State)
        Window:SetSidebarWidth(State and WindowInfo.SidebarCompactWidth or LastExpandedWidth)
    end

    function Window:GetSidebarWidth()
        return Tabs.Size.X.Offset
    end

    function Window:SetSidebarWidth(Width)
        Width = math.clamp(Width, 48, MainFrame.Size.X.Offset - WindowInfo.MinContainerWidth - 1)

        DividerLine.Position = UDim2.fromOffset(Width, 0)

        TitleHolder.Size = UDim2.new(0, Width, 1, 0)
        RightWrapper.Size = UDim2.new(1, -Width - 57 - 1, 1, -16)
        Tabs.Size = UDim2.new(0, Width, 1, -70)
        Container.Size = UDim2.new(1, -Width - 1, 1, -70)

        if WindowInfo.EnableCompacting then
            ApplyCompact()
        end
        if not IsCompact then
            LastExpandedWidth = Width
        end
    end

    function Window:ShowTabInfo(Name, Description)
        CurrentTabLabel.Text = Name
        CurrentTabDescription.Text = Description

        if IsDefaultSearchbarSize then
            SearchBox.Size = UDim2.fromScale(0.5, 1)
        end
        CurrentTabInfo.Visible = true
    end

    function Window:HideTabInfo()
        CurrentTabInfo.Visible = false
        if IsDefaultSearchbarSize then
            SearchBox.Size = UDim2.fromScale(1, 1)
        end
    end

    function Window:AddTab(...)
        local Name = nil
        local Icon = nil
        local Description = nil
        local Order = nil

        if select("#", ...) == 1 and typeof(...) == "table" then
            local Info = select(1, ...)
            Name = Info.Name or "Tab"
            Icon = Info.Icon
            Description = Info.Description
            Order = Info.Order
        else
            Name = select(1, ...)
            Icon = select(2, ...)
            Description = select(3, ...)
            Order = select(4, ...)
        end

        local TabButton
        local TabLabel
        local TabIcon

        local TabContainer
        local TabCanvas
        local TabLeft
        local TabRight

        Icon = Library:GetCustomIcon(Icon)
        do
            TabButton = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                Text = "",
                LayoutOrder = Order,
                Parent = Tabs,
            })
            local ButtonPadding = New("UIPadding", {
                PaddingBottom = UDim.new(0, IsCompact and 6 or 11),
                PaddingLeft = UDim.new(0, IsCompact and 6 or 12),
                PaddingRight = UDim.new(0, IsCompact and 6 or 12),
                PaddingTop = UDim.new(0, IsCompact and 6 or 11),
                Parent = TabButton,
            })

            TabLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = Name,
                TextSize = 16,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not IsCompact,
                Parent = TabButton,
            })

            if Icon then
                TabIcon = New("ImageLabel", {
                    Image = Icon.Url,
                    ImageColor3 = Icon.Custom and "WhiteColor" or "AccentColor",
                    ImageRectOffset = Icon.ImageRectOffset,
                    ImageRectSize = Icon.ImageRectSize,
                    ImageTransparency = 0.5,
                    ScaleType = Enum.ScaleType.Fit,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY,
                    Parent = TabButton,
                })
            end

            table.insert(Library.TabButtons, {
                Label = TabLabel,
                Padding = ButtonPadding,
                Icon = TabIcon,
            })

            --// Tab Canvas \\--
            TabCanvas = New("CanvasGroup", {
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                GroupTransparency = 0,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })

            --// Tab Container \\--
            TabContainer = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0, 0),
                Size = UDim2.fromScale(1, 1),
                Visible = true,
                Parent = TabCanvas,
            })

            TabLeft = New("ScrollingFrame", {
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                ScrollBarImageTransparency = 1,
                ScrollBarThickness = 0,
                Size = UDim2.new(0.5, -3, 1, 0),
                Parent = TabContainer,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 2),
                Parent = TabLeft,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = TabLeft,
            })
            do
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    Parent = TabLeft,
                })
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Parent = TabLeft,
                })
            end

            TabRight = New("ScrollingFrame", {
                AnchorPoint = Vector2.new(1, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                Position = UDim2.fromScale(1, 0),
                ScrollBarImageTransparency = 1,
                ScrollBarThickness = 0,
                Size = UDim2.new(0.5, -3, 1, 0),
                Parent = TabContainer,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 2),
                Parent = TabRight,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = TabRight,
            })
            do
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    Parent = TabRight,
                })
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Parent = TabRight,
                })
            end
        end

        --// Warning Box \\--
        local WarningBoxHolder = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 7),
            Size = UDim2.fromScale(1, 0),
            Visible = false,
            Parent = TabContainer,
        })

        local WarningBox
        local WarningBoxOutline
        local WarningBoxShadowOutline
        local WarningBoxScrollingFrame
        local WarningTitle
        local WarningStroke
        local WarningText
        do
            WarningBox = New("Frame", {
                BackgroundColor3 = "BackgroundColor",
                Position = UDim2.fromOffset(2, 0),
                Size = UDim2.new(1, -5, 0, 0),
                Parent = WarningBoxHolder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                    Parent = WarningBox,
                })
            )
            WarningBoxOutline, WarningBoxShadowOutline = Library:AddOutline(WarningBox)

            WarningBoxScrollingFrame = New("ScrollingFrame", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 3,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Parent = WarningBox,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6),
                PaddingTop = UDim.new(0, 4),
                Parent = WarningBoxScrollingFrame,
            })

            WarningTitle = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -4, 0, 14),
                Text = "",
                TextColor3 = Color3.fromRGB(255, 50, 50),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = WarningBoxScrollingFrame,
            })

            WarningStroke = New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = Color3.fromRGB(169, 0, 0),
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = WarningTitle,
            })

            WarningText = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 16),
                Size = UDim2.new(1, -4, 0, 0),
                Text = "",
                TextSize = 14,
                TextWrapped = true,
                Parent = WarningBoxScrollingFrame,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
            })

            New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = "DarkColor",
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = WarningText,
            })
        end

        --// Tab Table \\--
        local Tab = {
            Description = Description,

            Connections = {},
            Destroyed = false,

            Window = Window,
            Canvas = TabCanvas,
            Sides = {
                TabLeft,
                TabRight,
            },
            WarningBox = {
                IsNormal = false,
                LockSize = false,
                Visible = false,
                Title = "WARNING",
                Text = "",
            },

            Groupboxes = {},
            Tabboxes = {},
            DependencyGroupboxes = {},
        }

        function Tab:UpdateWarningBox(Info)
            if typeof(Info.IsNormal) == "boolean" then
                Tab.WarningBox.IsNormal = Info.IsNormal
            end
            if typeof(Info.LockSize) == "boolean" then
                Tab.WarningBox.LockSize = Info.LockSize
            end
            if typeof(Info.Visible) == "boolean" then
                Tab.WarningBox.Visible = Info.Visible
            end
            if typeof(Info.Title) == "string" then
                Tab.WarningBox.Title = Info.Title
            end
            if typeof(Info.Text) == "string" then
                Tab.WarningBox.Text = Info.Text
            end

            WarningBoxHolder.Visible = Tab.WarningBox.Visible
            WarningTitle.Text = Tab.WarningBox.Title
            WarningText.Text = Tab.WarningBox.Text
            Tab:Resize(true)

            WarningBox.BackgroundColor3 = Tab.WarningBox.IsNormal == true and Library.Scheme.BackgroundColor
                or Color3.fromRGB(127, 0, 0)

            WarningBoxShadowOutline.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.DarkColor
                or Color3.fromRGB(85, 0, 0)
            WarningBoxOutline.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor
                or Color3.fromRGB(255, 50, 50)

            WarningTitle.TextColor3 = Tab.WarningBox.IsNormal == true and Library.Scheme.FontColor
                or Color3.fromRGB(255, 50, 50)
            WarningStroke.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor
                or Color3.fromRGB(169, 0, 0)

            if not Library.Registry[WarningBox] then
                Library:AddToRegistry(WarningBox, {})
            end
            if not Library.Registry[WarningBoxShadowOutline] then
                Library:AddToRegistry(WarningBoxShadowOutline, {})
            end
            if not Library.Registry[WarningBoxOutline] then
                Library:AddToRegistry(WarningBoxOutline, {})
            end
            if not Library.Registry[WarningTitle] then
                Library:AddToRegistry(WarningTitle, {})
            end
            if not Library.Registry[WarningStroke] then
                Library:AddToRegistry(WarningStroke, {})
            end

            Library.Registry[WarningBox].BackgroundColor3 = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.BackgroundColor or Color3.fromRGB(127, 0, 0)
            end

            Library.Registry[WarningBoxShadowOutline].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.DarkColor or Color3.fromRGB(85, 0, 0)
            end

            Library.Registry[WarningBoxOutline].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor or Color3.fromRGB(255, 50, 50)
            end

            Library.Registry[WarningTitle].TextColor3 = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.FontColor or Color3.fromRGB(255, 50, 50)
            end

            Library.Registry[WarningStroke].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor or Color3.fromRGB(169, 0, 0)
            end
        end

        function Tab:RefreshSides()
            local Offset = WarningBoxHolder.Visible and WarningBox.Size.Y.Offset + 8 or 0
            for _, Side in Tab.Sides do
                Side.Position = UDim2.new(Side.Position.X.Scale, 0, 0, Offset)
                Side.Size = UDim2.new(0.5, -3, 1, -Offset)
            end
        end

        function Tab:Resize(ResizeWarningBox)
            if ResizeWarningBox then
                local MaximumSize = math.floor(TabContainer.AbsoluteSize.Y / 3.25)
                local _, YText = Library:GetTextBounds(
                    WarningText.Text,
                    Library.Scheme.Font,
                    WarningText.TextSize,
                    WarningText.AbsoluteSize.X
                )

                local YBox = 24 + YText
                if Tab.WarningBox.LockSize == true and YBox >= MaximumSize then
                    WarningBoxScrollingFrame.CanvasSize = UDim2.fromOffset(0, YBox)
                    YBox = MaximumSize
                else
                    WarningBoxScrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
                end

                WarningText.Size = UDim2.new(1, -4, 0, YText)
                WarningBox.Size = UDim2.new(1, -5, 0, YBox + 4)
            end

            Tab:RefreshSides()
        end

        local function AddTabbox(self, Info)
            local ParentObj = self

            local BoxHolder = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Parent = if ParentObj.Type == "Groupbox" then ParentObj.Container else (Info.Side == 1 and TabLeft or TabRight),
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 6),
                Parent = BoxHolder,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                Parent = BoxHolder,
            })

            local TabboxHolder
            local TabboxButtons

            do
                TabboxHolder = New("Frame", {
                    BackgroundColor3 = "BackgroundColor",
                    Size = UDim2.fromScale(1, 0),
                    Parent = BoxHolder,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", {
                        CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                        Parent = TabboxHolder,
                    })
                )
                Library:AddOutline(TabboxHolder)

                TabboxButtons = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                    Parent = TabboxHolder,
                })
                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalFlex = Enum.UIFlexAlignment.Fill,
                    Parent = TabboxButtons,
                })
            end

            local TotalTabs = 0
            local FirstTab
            local LastTab

            local Tabbox = {
                Connections = {},
                Destroyed = false,

                ActiveTab = nil,

                BoxHolder = BoxHolder,
                Holder = TabboxHolder,
                Tabs = {}
            }

            function Tabbox:UpdateCorners()
                for _, Tab in Tabbox.Tabs do
                    Tab:UpdateCorners()
                end
            end

            function Tabbox:AddTab(Name, IconName)
                TotalTabs = TotalTabs + 1
                local TabIndex = TotalTabs

                LastTab = TabIndex
                if not FirstTab then
                    FirstTab = TabIndex
                end

                local IsNameEmpty = Name == nil or Trim(tostring(Name)) == ""
                local TabStoringIndex = IsNameEmpty and tostring(TabIndex) or Name

                local Button = New("TextButton", {
                    BackgroundColor3 = "MainColor",
                    BackgroundTransparency = 0,
                    Size = UDim2.fromOffset(0, 34),
                    Text = "",
                    Parent = TabboxButtons,
                })

                local ButtonCorner = New("UICorner", {
                    TopLeftRadius = UDim.new(0, WindowInfo.CornerRadius),
                    TopRightRadius = UDim.new(0, WindowInfo.CornerRadius),
                    BottomRightRadius = UDim.new(0, 0),
                    BottomLeftRadius = UDim.new(0, 0),
                    Parent = Button,
                }); table.insert(Library.SpecificCorners, ButtonCorner)

                local ButtonContent = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromOffset(0, 16),
                    Parent = Button,
                })
                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 8),
                    Parent = ButtonContent,
                })

                local ButtonIcon
                local BoxIcon = Library:GetCustomIcon(IconName)
                if BoxIcon then
                    ButtonIcon = New("ImageLabel", {
                        Image = BoxIcon.Url,
                        ImageColor3 = BoxIcon.Custom and "WhiteColor" or "AccentColor",
                        ImageRectOffset = BoxIcon.ImageRectOffset,
                        ImageRectSize = BoxIcon.ImageRectSize,
                        ImageTransparency = 0.5,
                        Size = IsNameEmpty and UDim2.fromOffset(16, 16) or UDim2.fromOffset(18, 18),
                        Parent = ButtonContent,
                    })
                end

                local ButtonLabel
                if not IsNameEmpty then
                    ButtonLabel = New("TextLabel", {
                        AutomaticSize = Enum.AutomaticSize.X,
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(0, 16),
                        Text = Name,
                        TextSize = 15,
                        TextTransparency = 0.5,
                        Parent = ButtonContent,
                    })
                end

                local Line = Library:MakeLine(Button, {
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.new(0, 0, 1, 1),
                    Size = UDim2.new(1, 0, 0, 1),
                })

                local Container = New("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 35),
                    Size = UDim2.new(1, 0, 1, -35),
                    Visible = false,
                    Parent = TabboxHolder,
                })
                local List = New("UIListLayout", {
                    Padding = UDim.new(0, 8),
                    Parent = Container,
                })
                New("UIPadding", {
                    PaddingBottom = UDim.new(0, 7),
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    PaddingTop = UDim.new(0, 7),
                    Parent = Container,
                })

                local Tab = {
                    Connections = {},
                    Destroyed = false,

                    ButtonHolder = Button,
                    Container = Container,
                    ButtonCorner = ButtonCorner,

                    Tab = Tab,
                    Elements = {},
                    DependencyBoxes = {},
                }

                function Tab:Show()
                    if Tabbox.ActiveTab then
                        Tabbox.ActiveTab:Hide()
                    end

                    Button.BackgroundTransparency = 1

                    if ButtonLabel then
                        ButtonLabel.TextTransparency = 0
                    end
                    if ButtonIcon then
                        ButtonIcon.ImageTransparency = 0
                    end

                    Line.Visible = false

                    Container.Visible = true

                    Tabbox.ActiveTab = Tab
                    Tab:Resize()
                end

                function Tab:Hide()
                    Button.BackgroundTransparency = 0

                    if ButtonLabel then
                        ButtonLabel.TextTransparency = 0.5
                    end
                    if ButtonIcon then
                        ButtonIcon.ImageTransparency = 0.5
                    end
                    Line.Visible = true
                    Container.Visible = false

                    Tabbox.ActiveTab = nil
                end

                function Tab:Resize()
                    if Tabbox.ActiveTab ~= Tab then
                        return
                    end

                    TabboxHolder.Size = UDim2.new(1, 0, 0, (List.AbsoluteContentSize.Y / Library.DPIScale) + 49)
                    if ParentObj.Type == "Groupbox" then
                        ParentObj:Resize()
                    end
                end

                function Tab:UpdateCorners()
                    local Radius = WindowInfo.CornerRadius

                    ButtonCorner.TopLeftRadius = UDim.new(0, TabIndex == FirstTab and Radius or 0)
                    ButtonCorner.TopRightRadius = UDim.new(0, TabIndex == LastTab and Radius or 0)
                end

                function Tab:Destroy()
                    Tab.Destroyed = true

                    if Tab.Connections then
                        for _, Connection in Tab.Connections do
                            Connection:Disconnect()
                        end
                    end

                    for _, Element in Tab.Elements do
                        if Element.Destroy then
                            Element:Destroy()
                        end
                    end

                    for _, SubDepbox in Tab.DependencyBoxes do
                        if SubDepbox.Destroy then
                            SubDepbox:Destroy()
                        end
                    end

                    if Container then
                        Container:Destroy()
                    end

                    if Button then
                        Button:Destroy()
                    end
                end

                --// Execution \\--
                if not Tabbox.ActiveTab then
                    Tab:Show()
                end

                Button.MouseButton1Click:Connect(Tab.Show)

                setmetatable(Tab, BaseGroupbox)

                Tabbox.Tabs[TabStoringIndex] = Tab
                Tabbox:UpdateCorners()

                return Tab, TabStoringIndex
            end

            function Tabbox:Destroy()
                Tabbox.Destroyed = true

                if Tabbox.Connections then
                    for _, Connection in Tabbox.Connections do
                        Connection:Disconnect()
                    end
                end

                for _, Tab in Tabbox.Tabs do
                    if Tab.Destroy then
                        Tab:Destroy()
                    end
                end

                if TabboxHolder then
                    TabboxHolder:Destroy()
                end

                if BoxHolder then
                    BoxHolder:Destroy()
                end
            end

            if Info.Name then
                Tab.Tabboxes[Info.Name] = Tabbox
            else
                table.insert(Tab.Tabboxes, Tabbox)
            end

            return Tabbox
        end

        Tab.AddTabbox = AddTabbox

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Side = 1, Name = Name })
        end

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Side = 2, Name = Name })
        end

        function Tab:AddGroupbox(Info)
            local BoxHolder = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Parent = Info.Side == 1 and TabLeft or TabRight,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 6),
                Parent = BoxHolder,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                Parent = BoxHolder,
            })

            local GroupboxHolder
            local GroupboxLabel

            local GroupboxContainer
            local GroupboxList

            local GroupboxCollapseArrow
            local GroupboxLine

            do
                GroupboxHolder = New("Frame", {
                    BackgroundColor3 = "BackgroundColor",
                    Size = UDim2.fromScale(1, 0),
                    Parent = BoxHolder,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", {
                        CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                        Parent = GroupboxHolder,
                    })
                )
                Library:AddOutline(GroupboxHolder)

                GroupboxLine = Library:MakeLine(GroupboxHolder, {
                    Position = UDim2.fromOffset(0, 34),
                    Size = UDim2.new(1, 0, 0, 1),
                })

                local BoxIcon = Library:GetCustomIcon(Info.IconName)
                if BoxIcon then
                    New("ImageLabel", {
                        Image = BoxIcon.Url,
                        ImageColor3 = BoxIcon.Custom and "WhiteColor" or "AccentColor",
                        ImageRectOffset = BoxIcon.ImageRectOffset,
                        ImageRectSize = BoxIcon.ImageRectSize,
                        Position = UDim2.fromOffset(6, 6),
                        Size = UDim2.fromOffset(22, 22),
                        Parent = GroupboxHolder,
                    })
                end

                GroupboxLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(BoxIcon and 24 or 0, 0),
                    Size = UDim2.new(1, 0, 0, 34),
                    Text = Info.Name,
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = GroupboxHolder,
                })
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 12),
                    Parent = GroupboxLabel,
                })

                if Info.DisableCollapsing ~= true then
                    GroupboxCollapseArrow = New("ImageButton", {
                        Image = ArrowIcon and ArrowIcon.Url or "",
                        ImageColor3 = "WhiteColor",
                        ImageRectOffset = ArrowIcon and ArrowIcon.ImageRectOffset or Vector2.zero,
                        ImageRectSize = ArrowIcon and ArrowIcon.ImageRectSize or Vector2.zero,
                        BackgroundTransparency = 1,
                        Rotation = 180,
                        Position = UDim2.new(1, -(22 + 6), 0, 6),
                        Size = UDim2.fromOffset(22, 22),
                        Parent = GroupboxHolder,
                    })
                end

                GroupboxContainer = New("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 35),
                    Size = UDim2.new(1, 0, 1, -35),
                    Parent = GroupboxHolder,
                })

                GroupboxList = New("UIListLayout", {
                    Padding = UDim.new(0, 8),
                    Parent = GroupboxContainer,
                })
                New("UIPadding", {
                    PaddingBottom = UDim.new(0, 7),
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    PaddingTop = UDim.new(0, 7),
                    Parent = GroupboxContainer,
                })
            end

            local Groupbox = {
                Type = "Groupbox",

                Connections = {},
                Destroyed = false,

                Visible = true,
                Collapsed = false,

                BoxHolder = BoxHolder,
                Holder = GroupboxHolder,
                Container = GroupboxContainer,

                Tab = Tab,
                DependencyBoxes = {},
                Elements = {}
            }

            local ResizeTween
            local CollapseArrowTween

            function Groupbox:Resize()
                if ResizeTween then
                    StopTween(ResizeTween, true)
                    ResizeTween = nil
                end

                local TargetSize = UDim2.new(1, 0, 0, if Groupbox.Collapsed then 34 else (GroupboxList.AbsoluteContentSize.Y / Library.DPIScale) + 49)

                GroupboxLine.Visible = not Groupbox.Collapsed
                if Library.Animations and Library.Animations.Groupbox then
                    local TweenInfo = Library.GroupboxTweenInfo or TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    local Tween = TweenService:Create(GroupboxHolder, TweenInfo, { Size = TargetSize })
                    ResizeTween = Tween

                    local Connection; Connection = Library:GiveSignal(Tween.Completed:Once(function()
                        if Connection then
                            Connection:Disconnect()
                        end

                        if ResizeTween == Tween then
                            StopTween(ResizeTween, true)
                            ResizeTween = nil
                        end
                    end))

                    Tween:Play()
                else
                    GroupboxHolder.Size = TargetSize
                end
            end

            function Groupbox:SetCollapsed(Collapsed)
                if Info.DisableCollapsing == true then return end
                Groupbox.Collapsed = Collapsed

                if CollapseArrowTween then
                    StopTween(CollapseArrowTween, true)
                    CollapseArrowTween = nil
                end

                local TargetRotation = if Collapsed then 0 else 180

                GroupboxContainer.Visible = not Collapsed
                if Library.Animations and Library.Animations.Groupbox then
                    local TweenInfo = Library.GroupboxTweenInfo or TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    local Tween = TweenService:Create(GroupboxCollapseArrow, TweenInfo, { Rotation = TargetRotation })
                    CollapseArrowTween = Tween

                    local Connection; Connection = Library:GiveSignal(Tween.Completed:Connect(function()
                        if Connection then
                            Connection:Disconnect()
                        end

                        if CollapseArrowTween == Tween then
                            StopTween(CollapseArrowTween, true)
                            CollapseArrowTween = nil
                        end
                    end))

                    Tween:Play()
                else
                    GroupboxCollapseArrow.Rotation = TargetRotation
                end

                Groupbox:Resize()
            end

            function Groupbox:ToggleCollapsed()
                if Info.DisableCollapsing == true then return end
                Groupbox:SetCollapsed(not Groupbox.Collapsed)
            end

            function Groupbox:Destroy()
                Groupbox.Destroyed = true

                if ResizeTween then
                    StopTween(ResizeTween, true)
                    ResizeTween = nil
                end

                if CollapseArrowTween then
                    StopTween(CollapseArrowTween, true)
                    CollapseArrowTween = nil
                end

                if Groupbox.Connections then
                    for _, Connection in Groupbox.Connections do
                        Connection:Disconnect()
                    end
                end

                for _, Element in Groupbox.Elements do
                    if Element.Destroy then
                        Element:Destroy()
                    end
                end
                table.clear(Groupbox.Elements)

                for _, SubDepbox in Groupbox.DependencyBoxes do
                    if SubDepbox.Destroy then
                        SubDepbox:Destroy()
                    end
                end
                table.clear(Groupbox.DependencyBoxes)

                if GroupboxHolder then
                    GroupboxHolder:Destroy()
                end

                if BoxHolder then
                    BoxHolder:Destroy()
                end
            end

            function Groupbox:SetVisible(Visible)
                Groupbox.Visible = Visible
                BoxHolder.Visible = Visible

                if Visible == true and Library.Searching then
                    Library:UpdateSearch(Library.SearchText)
                end
            end

            function Groupbox:Show()
                Groupbox:SetVisible(true)
            end

            function Groupbox:Hide()
                Groupbox:SetVisible(false)
            end

            if Info.DisableCollapsing ~= true then
                GroupboxCollapseArrow.MouseButton1Click:Connect(function()
                    Groupbox:ToggleCollapsed()
                end)
            end

            Groupbox.AddTabbox = AddTabbox
            setmetatable(Groupbox, BaseGroupbox)

            Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox

            if Info.Visible == false then
                Groupbox:Hide()
            end

            if Info.DisableCollapsing ~= true and Info.Collapsed == true then
                Groupbox:SetCollapsed(true)
            end

            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name, IconName, Visible, Collapsed, DisableCollapsing)
            return Tab:AddGroupbox({ Side = 1, Name = Name, IconName = IconName, Visible = Visible, Collapsed = Collapsed, DisableCollapsing = DisableCollapsing })
        end

        function Tab:AddRightGroupbox(Name, IconName, Visible, Collapsed, DisableCollapsing)
            return Tab:AddGroupbox({ Side = 2, Name = Name, IconName = IconName, Visible = Visible, Collapsed = Collapsed, DisableCollapsing = DisableCollapsing })
        end

        function Tab:Hover(Hovering)
            if Library.ActiveTab == Tab then
                return
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = Hovering and 0.25 or 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = Hovering and 0.25 or 0.5,
                }):Play()
            end
        end

        function Tab:Show()
            if Library.ActiveTab == Tab then
                return
            end

            if Library.ActiveTab then
                Library.ActiveTab:Hide()
            end

            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 0,
            }):Play()
            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0,
                }):Play()
            end

            if Description then
                Window:ShowTabInfo(Name, Description)
            end

            Library:PlayTabAnimation(TabCanvas, true)
            Tab:RefreshSides()

            Library.ActiveTab = Tab

            if Library.Searching then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function Tab:Hide()
            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 1,
            }):Play()

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0.5,
            }):Play()

            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0.5,
                }):Play()
            end

            Library:PlayTabAnimation(TabCanvas, false)
            Window:HideTabInfo()

            Library.ActiveTab = nil
        end

        function Tab:SetVisible(Visible)
            TabButton.Visible = Visible

            if not Visible and Library.ActiveTab == Tab then
                Tab:Hide()
            end
        end

        function Tab:SetOrder(Order)
            TabButton.LayoutOrder = Order
        end

        function Tab:Destroy()
            Tab.Destroyed = true

            if Tab.Connections then
                for _, Connection in Tab.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Groupbox in Tab.Groupboxes do
                if Groupbox.Destroy then
                    Groupbox:Destroy()
                end
            end
            table.clear(Tab.Groupboxes)

            for _, Tabbox in Tab.Tabboxes do
                if Tabbox.Destroy then
                    Tabbox:Destroy()
                end
            end
            table.clear(Tab.Tabboxes)

            for _, DepGroupbox in Tab.DependencyGroupboxes do
                if DepGroupbox.Destroy then
                    DepGroupbox:Destroy()
                end
            end

            if TabCanvas then
                TabCanvas:Destroy()
            elseif TabContainer then
                TabContainer:Destroy()
            end

            if TabButton then
                for Index, Entry in Library.TabButtons do
                    if typeof(Entry) == "table" and Entry.Button == TabButton then
                        table.remove(Library.TabButtons, Index)
                        break
                    end
                end

                TabButton:Destroy()
            end

            Library.Tabs[Name] = nil
        end

        --// Execution \\--
        if not Library.ActiveTab then
            Tab:Show()
        end

        TabButton.MouseEnter:Connect(function()
            Tab:Hover(true)
        end)
        TabButton.MouseLeave:Connect(function()
            Tab:Hover(false)
        end)
        TabButton.MouseButton1Click:Connect(Tab.Show)

        Library.Tabs[Name] = Tab

        return Tab
    end

    function Window:AddKeyTab(...)
        local Name = nil
        local Icon = nil
        local Description = nil

        if select("#", ...) == 1 and typeof(...) == "table" then
            local Info = select(1, ...)
            Name = Info.Name or "Tab"
            Icon = Info.Icon
            Description = Info.Description
        else
            Name = select(1, ...) or "Tab"
            Icon = select(2, ...)
            Description = select(3, ...)
        end

        Icon = Icon or "key"

        local TabButton
        local TabLabel
        local TabIcon

        local TabCanvas
        local TabContainer

        Icon = if Icon == "key" then KeyIcon else Library:GetCustomIcon(Icon)
        do
            TabButton = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                Text = "",
                Parent = Tabs,
            })
            local ButtonPadding = New("UIPadding", {
                PaddingBottom = UDim.new(0, IsCompact and 6 or 11),
                PaddingLeft = UDim.new(0, IsCompact and 6 or 12),
                PaddingRight = UDim.new(0, IsCompact and 6 or 12),
                PaddingTop = UDim.new(0, IsCompact and 6 or 11),
                Parent = TabButton,
            })

            TabLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = Name,
                TextSize = 16,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not IsCompact,
                Parent = TabButton,
            })

            if Icon then
                TabIcon = New("ImageLabel", {
                    Image = Icon.Url,
                    ImageColor3 = Icon.Custom and "WhiteColor" or "AccentColor",
                    ImageRectOffset = Icon.ImageRectOffset,
                    ImageRectSize = Icon.ImageRectSize,
                    ImageTransparency = 0.5,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY,
                    Parent = TabButton,
                })
            end

            table.insert(Library.TabButtons, {
                Label = TabLabel,
                Padding = ButtonPadding,
                Icon = TabIcon,
            })

            --// Tab Canvas \\--
            TabCanvas = New("CanvasGroup", {
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                GroupTransparency = 0,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })

            --// Tab Container \\--
            TabContainer = New("ScrollingFrame", {
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                ScrollBarThickness = 0,
                Position = UDim2.fromScale(0, 0),
                Size = UDim2.fromScale(1, 1),
                Visible = true,
                Parent = TabCanvas,
            })
            New("UIListLayout", {
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Padding = UDim.new(0, 8),
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Parent = TabContainer,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 1),
                PaddingRight = UDim.new(0, 1),
                Parent = TabContainer,
            })
        end

        --// Tab Table \\--
        local Tab = {
            Description = Description,
            IsKeyTab = true,

            Elements = {},

            Window = Window,
            Canvas = TabCanvas
        }

        function Tab:AddKeyBox(Callback)
            assert(typeof(Callback) == "function", "Callback must be a function")

            local Holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0.75, 0, 0, 21),
                Parent = TabContainer,
            })

            local Box = New("TextBox", {
                BackgroundColor3 = "MainColor",
                PlaceholderText = "Key",
                Size = UDim2.new(1, -71, 1, 0),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Holder,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                Parent = Box,
            })
            New("UIStroke", {
                Color = "OutlineColor",
                Parent = Box,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Box,
                })
            )

            local Button = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = "MainColor",
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 63, 1, 0),
                Text = "Execute",
                TextSize = 14,
                Parent = Holder,
            })
            New("UIStroke", {
                Color = "OutlineColor",
                Parent = Button,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                })
            )

            Button.InputBegan:Connect(function(Input)
                if not IsClickInput(Input) then
                    return
                end

                if not Library:MouseIsOverFrame(Button, Input.Position) then
                    return
                end

                Callback(Box.Text)
            end)
        end

        function Tab:Destroy()
            if TabCanvas then
                TabCanvas:Destroy()
            elseif TabContainer then
                TabContainer:Destroy()
            end

            if TabButton then
                for Index, Entry in Library.TabButtons do
                    if typeof(Entry) == "table" and Entry.Button == TabButton then
                        table.remove(Library.TabButtons, Index)
                        break
                    end
                end

                TabButton:Destroy()
            end

            Library.Tabs[Name] = nil
        end

        function Tab:RefreshSides() end
        function Tab:Resize() end
        function Tab:UpdateCorners() end

        function Tab:Hover(Hovering)
            if Library.ActiveTab == Tab then
                return
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = Hovering and 0.25 or 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = Hovering and 0.25 or 0.5,
                }):Play()
            end
        end

        function Tab:Show()
            if Library.ActiveTab == Tab then
                return
            end

            if Library.ActiveTab then
                Library.ActiveTab:Hide()
            end

            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 0,
            }):Play()

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0,
            }):Play()

            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0,
                }):Play()
            end

            Library:PlayTabAnimation(TabCanvas, true)

            if Description then
                Window:ShowTabInfo(Name, Description)
            end

            Tab:RefreshSides()

            Library.ActiveTab = Tab

            if Library.Searching then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function Tab:Hide()
            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 1,
            }):Play()

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0.5,
            }):Play()

            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0.5,
                }):Play()
            end

            Library:PlayTabAnimation(TabCanvas, false)
            Window:HideTabInfo()

            Library.ActiveTab = nil
        end

        function Tab:SetVisible(Visible)
            TabButton.Visible = Visible

            if not Visible and Library.ActiveTab == Tab then
                Tab:Hide()
            end
        end

        --// Execution \\--
        if not Library.ActiveTab then
            Tab:Show()
        end

        TabButton.MouseEnter:Connect(function()
            Tab:Hover(true)
        end)
        TabButton.MouseLeave:Connect(function()
            Tab:Hover(false)
        end)
        TabButton.MouseButton1Click:Connect(Tab.Show)

        Tab.Container = TabContainer
        setmetatable(Tab, BaseGroupbox)

        Library.Tabs[Name] = Tab

        return Tab
    end

    function Window:AddDialog(Idx, Info)
        Info = Library:Validate(Info, Templates.Dialog)

        local DialogFrame
        local DialogOverlay
        local DialogContainer
        local ButtonsHolder
        local FooterButtonsList = {}

        DialogOverlay = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = "DarkColor",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            Active = false,
            ZIndex = 9000,
            Visible = true,
            Parent = MainFrame,
        })
        TweenService:Create(DialogOverlay, Library.TweenInfo, {
            BackgroundTransparency = 0.5,
        }):Play()

        DialogFrame = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "BackgroundColor",
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(300, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 9001,
            Parent = DialogOverlay,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = DialogFrame,
            })
        )
        Library:AddOutline(DialogFrame)

        local InnerContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 9002,
            Parent = DialogFrame,
        })
        local DialogScale = New("UIScale", {
            Scale = 0.95,
            Parent = DialogFrame,
        })
        TweenService:Create(DialogScale, Library.TweenInfo, {
            Scale = 1
        }):Play()
        local _InnerPadding = New("UIPadding", {
            PaddingBottom = UDim.new(0, 15),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
            PaddingTop = UDim.new(0, 15),
            Parent = InnerContainer,
        })
        local _InnerLayout = New("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = InnerContainer,
        })

        local HeaderContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = HeaderContainer,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = HeaderContainer,
        })

        local TitleRow = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9002,
            Parent = HeaderContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = TitleRow,
        })

        if Info.Icon then
            local ParsedIcon = Library:GetCustomIcon(Info.Icon)
            if ParsedIcon then
                local _IconImg = New("ImageLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(16, 16),
                    Image = ParsedIcon.Url,
                    ImageColor3 = Info.TitleColor or "FontColor",
                    ImageRectOffset = ParsedIcon.ImageRectOffset,
                    ImageRectSize = ParsedIcon.ImageRectSize,
                    LayoutOrder = 1,
                    ZIndex = 9002,
                    Parent = TitleRow,
                })
            end
        end

        local TitleLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Title,
            TextSize = 18,
            TextColor3 = Info.TitleColor or "FontColor",
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            ZIndex = 9002,
            Parent = TitleRow,
        })

        local DescriptionLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Description,
            TextSize = 14,
            TextTransparency = Info.DescriptionColor and 0 or 0.2,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Info.DescriptionColor or "FontColor",
            TextWrapped = true,
            LayoutOrder = 2,
            ZIndex = 9002,
            Parent = HeaderContainer,
        })

        DialogContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        local _DialogContainerLayout = New("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = DialogContainer,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = DialogContainer,
        })

        local _Sep2 = New("Frame", {
            BackgroundColor3 = "OutlineColor",
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 1),
            LayoutOrder = 5,
            ZIndex = 9002,
            Parent = InnerContainer,
        })

        ButtonsHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 6,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Wraps = true,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ButtonsHolder,
        })
        New("UIPadding", {
            PaddingTop = UDim.new(0, 5),
            Parent = ButtonsHolder,
        })

        local Dialog = {
            Destroyed = false,
            Elements = {},
            Container = DialogContainer,
        }

        function Dialog:Resize()
            local MaxWidth = MainFrame.AbsoluteSize.X * 0.75
            local MinWidth = 400

            local TotalButtonWidth = 0
            local ButtonCount = 0
            local HasButtons = false

            for _, BtnWrap in FooterButtonsList do
                HasButtons = true
                ButtonCount = ButtonCount + 1
                TotalButtonWidth = TotalButtonWidth + BtnWrap.Container.Size.X.Offset
            end

            local TargetWidth = MinWidth
            if HasButtons then
                local RequiredWidth = TotalButtonWidth + ((ButtonCount - 1) * 8) + 30
                TargetWidth = math.max(MinWidth, math.min(RequiredWidth, MaxWidth))
            end

            DialogFrame.Size = UDim2.fromOffset(TargetWidth, 0)

            local _DescX, DescY = Library:GetTextBounds(DescriptionLabel.Text, Library.Scheme.Font, 14, TargetWidth - 30)
            DescriptionLabel.Size = UDim2.new(1, 0, 0, DescY)

            local HasElements = false
            for _, v in DialogContainer:GetChildren() do
                if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
                    HasElements = true
                    break
                end
            end
            DialogContainer.Visible = HasElements

            ButtonsHolder.Visible = HasButtons
            _Sep2.Visible = HasButtons
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
            if Dialog.Destroyed then
                return
            end

            Dialog.Destroyed = true

            if Library.ActiveDialog == Dialog then
                Library.ActiveDialog = nil
            end

            for Index = #Dialog.Elements, 1, -1 do
                local Element = Dialog.Elements[Index]
                if Element and Element.Destroy then
                    Element:Destroy()
                end
            end
            table.clear(Dialog.Elements)

            local CloseTween = TweenService:Create(DialogScale, Library.TweenInfo, { Scale = 0.95 })
            TweenService:Create(DialogOverlay, Library.TweenInfo, { BackgroundTransparency = 1 }):Play()
            CloseTween:Play()

            task.delay(Library.TweenInfo.Time, function()
                DialogOverlay:Destroy()
            end)
            Library.Dialogues[Idx] = nil
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

            local ButtonContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 26),
                LayoutOrder = ButtonInfo.Order or 0,
                ZIndex = 9002,
                Parent = ButtonsHolder,
            })

            local BtnColor = "MainColor"
            local BtnOutline = "OutlineColor"
            local Variant = ButtonInfo.Variant or "Primary"

            if Variant == "Primary" then
                BtnColor = "FontColor"
                BtnOutline = "FontColor"
            elseif Variant == "Secondary" then
                BtnColor = "MainColor"
                BtnOutline = "OutlineColor"
            elseif Variant == "Destructive" then
                BtnColor = "DestructiveColor"
                BtnOutline = "DestructiveColor"
            elseif Variant == "Ghost" then
                BtnColor = "BackgroundColor"
                BtnOutline = "BackgroundColor"
            end

            local TextBtn = New("TextButton", {
                BackgroundColor3 = BtnColor,
                BorderColor3 = BtnOutline,
                BackgroundTransparency = WaitTime > 0 and 0.5 or 0,
                Size = UDim2.fromOffset(0, 26),
                Text = "",
                AutoButtonColor = false,
                ZIndex = 9002,
                Parent = ButtonContainer,
            })
            Library:AddOutline(TextBtn)
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius),
                    Parent = TextBtn
                })
            )

            local _BtnPadding = New("UIPadding", {
                PaddingLeft = UDim.new(0, 15),
                PaddingRight = UDim.new(0, 15),
                Parent = TextBtn,
            })

            local TextColor = Library.Scheme.FontColor
            if Variant == "Primary" then
                TextColor = Library.Scheme.BackgroundColor
            elseif Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end

            local BtnLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or ButtonIdx,
                TextColor3 = TextColor,
                TextTransparency = WaitTime > 0 and 0.5 or 0,
                TextSize = 14,
                ZIndex = 9002,
                Parent = TextBtn,
            })

            local LabelX, _ = Library:GetTextBounds(BtnLabel.Text, Library.Scheme.Font, 14, 250)
            ButtonContainer.Size = UDim2.fromOffset(LabelX + 30, 26)
            TextBtn.Size = UDim2.fromOffset(LabelX + 30, 26)

            local ProgressBar
            if WaitTime > 0 then
                ProgressBar = New("Frame", {
                    BackgroundColor3 = "AccentColor",
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, -2),
                    Size = UDim2.new(0, 0, 0, 2),
                    ZIndex = 2,
                    Parent = TextBtn,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", {
                        CornerRadius = UDim.new(0, Library.CornerRadius),
                        Parent = ProgressBar
                    })
                )
            end

            local IsActive = WaitTime <= 0

            local ButtonWrap = {
                Container = ButtonContainer,
                SetDisabled = function(self, Disabled)
                    IsActive = not Disabled
                    if Disabled then
                        TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundTransparency = 0.5 }):Play()
                        TweenService:Create(BtnLabel, Library.TweenInfo, { TextTransparency = 0.5 }):Play()
                    else
                        TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundTransparency = 0 }):Play()
                        TweenService:Create(BtnLabel, Library.TweenInfo, { TextTransparency = 0 }):Play()
                    end
                end
            }

            local ActiveColor = typeof(BtnColor) == "Color3" and BtnColor or Library.Scheme[BtnColor]
            local HoverColor = Variant == "Ghost" and Library.Scheme.MainColor or Library:GetBetterColor(ActiveColor, 10)

            TextBtn.MouseEnter:Connect(function()
                if not IsActive then return end
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = HoverColor
                }):Play()
            end)
            TextBtn.MouseLeave:Connect(function()
                if not IsActive then return end
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = ActiveColor
                }):Play()
            end)

            TextBtn.MouseButton1Click:Connect(function()
                if not IsActive then return end
                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Dialog)
                end
                if Info.AutoDismiss then
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
                        TweenService:Create(ProgressBar, Library.TweenInfo, {
                            BackgroundTransparency = 1
                        }):Play()
                    end
                end)
            end

            FooterButtonsList[ButtonIdx] = ButtonWrap
        end

        for BIdx, BInfo in Info.FooterButtons do
            if type(BIdx) == "number" and BInfo.Id then BIdx = BInfo.Id end
            Dialog:AddFooterButton(BIdx, BInfo)
        end

        setmetatable(Dialog, BaseGroupbox)
        Library.Dialogues[Idx] = Dialog

        Dialog:Resize()

        Library.ActiveDialog = Dialog
        return Dialog
    end

    local GuiProperties = { "BackgroundTransparency" }
    local ImageProperties = { "BackgroundTransparency", "ImageTransparency" }
    local TextProperties = { "BackgroundTransparency", "TextTransparency" }
    local StrokeProperties = { "Transparency" }

    local function FadeInstance(Desc, Properties)
        local Cache = TransparencyCache[Desc]
        if not Cache then
            Cache = {}
            TransparencyCache[Desc] = Cache
        end

        for _, Prop in Properties do
            if not Library.Toggled then
                Cache[Prop] = Desc[Prop]
            end

            if Cache[Prop] ~= nil and Cache[Prop] ~= 1 then
                TweenService:Create(Desc, Library.WindowAnimationInfo, {
                    [Prop] = Library.Toggled and Cache[Prop] or 1,
                }):Play()
            end
        end
    end

    function Window:Toggle(Value)
        if Fading then
            return
        end

        if Library.ActiveLoading then
            if Value == true then
                return
            end

            if not Library.Toggled then
                return
            end
        end

        if typeof(Value) == "boolean" then
            Library.Toggled = Value
        else
            Library.Toggled = not Library.Toggled
        end

        if Library.Animations and Library.Animations.ToggleWindow == true then
            local FadeTime = Library.WindowAnimationInfo.Time
            Fading = true

            if Library.Toggled then
                MainFrame.Visible = true
            end

            if Library.Toggled then
				FadeInstance(MainFrame, { "BackgroundTransparency" })
				task.wait(FadeTime / 2)
			else
				task.delay(FadeTime / 2, FadeInstance, MainFrame, { "BackgroundTransparency" })
			end

            for _, Instance in MainFrame:GetDescendants() do
                if Instance == TopBar then
                    continue
                end

                if Instance:IsA("GuiObject") then
                    local ClassName = Instance.ClassName
                    if ClassName == "ImageLabel" or ClassName == "ImageButton" then
                        FadeInstance(Instance, ImageProperties)
                    elseif ClassName == "TextLabel" or ClassName == "TextBox" or ClassName == "TextButton" then
                        FadeInstance(Instance, TextProperties)
                    else
                        FadeInstance(Instance, GuiProperties)
                    end
                elseif Instance.ClassName == "UIStroke" then
                    FadeInstance(Instance, StrokeProperties)
                end
            end

            task.delay(FadeTime, function()
                MainFrame.Visible = Library.Toggled
                Fading = false
            end)
        else
            MainFrame.Visible = Library.Toggled
        end

        if WindowInfo.UnlockMouseWhileOpen then
            ModalElement.Modal = Library.Toggled
        end

        if Library.Toggled and not Library.IsMobile then
            local OldMouseIconEnabled = UserInputService.MouseIconEnabled
            local ShowCursorBinding = Library.ShowCursorBinding
            pcall(function()
                RunService:UnbindFromRenderStep(ShowCursorBinding)
            end)
            RunService:BindToRenderStep(ShowCursorBinding, Enum.RenderPriority.Last.Value, function()
                UserInputService.MouseIconEnabled = not Library.ShowCustomCursor

                Cursor.Position = UDim2.fromOffset(GetPointerLocation().X, GetPointerLocation().Y)
                Cursor.Visible = Library.ShowCustomCursor

                if not (Library.Toggled and ScreenGui and ScreenGui.Parent) then
                    UserInputService.MouseIconEnabled = OldMouseIconEnabled
                    Cursor.Visible = false
                    RunService:UnbindFromRenderStep(ShowCursorBinding)
                end
            end)
        elseif not Library.Toggled then
            TooltipLabel.Visible = false

            for _, Option in Library.Options do
                if Option.Type == "ColorPicker" then
                    Option.ColorMenu:Close()
                    Option.ContextMenu:Close()
                elseif Option.Type == "Dropdown" or Option.Type == "KeyPicker" then
                    Option.Menu:Close()
                end
            end
        end
    end

    function Library:Toggle(Value)
        return Window:Toggle(Value)
    end

    if WindowInfo.EnableSidebarResize then
        local Threshold = (WindowInfo.MinSidebarWidth + WindowInfo.SidebarCompactWidth) * WindowInfo.SidebarCollapseThreshold
        local StartPos, StartWidth
        local Dragging = false
        local Changed

        local SidebarGrabber = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.new(0, 8, 1, 0),
            Text = "",
            Parent = DividerLine,
        })
        SidebarGrabber.MouseEnter:Connect(function()
            TweenService:Create(DividerLine, Library.TweenInfo, {
                BackgroundColor3 = Library:GetLighterColor(Library.Scheme.OutlineColor),
            }):Play()
        end)
        SidebarGrabber.MouseLeave:Connect(function()
            if Dragging then
                return
            end
            TweenService:Create(DividerLine, Library.TweenInfo, {
                BackgroundColor3 = Library.Scheme.OutlineColor,
            }):Play()
        end)

        SidebarGrabber.InputBegan:Connect(function(Input)
            if not IsClickInput(Input) then
                return
            end

            Library.CantDragForced = true

            StartPos = Input.Position
            StartWidth = Window:GetSidebarWidth()
            Dragging = true

            Changed = Input.Changed:Connect(function()
                if Input.UserInputState ~= Enum.UserInputState.End then
                    return
                end

                Library.CantDragForced = false
                TweenService:Create(DividerLine, Library.TweenInfo, {
                    BackgroundColor3 = Library.Scheme.OutlineColor,
                }):Play()

                Dragging = false
                if Changed and Changed.Connected then
                    Changed:Disconnect()
                    Changed = nil
                end
            end)
        end)

        Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
            if not Library.Toggled or not (ScreenGui and ScreenGui.Parent) then
                Dragging = false
                if Changed and Changed.Connected then
                    Changed:Disconnect()
                    Changed = nil
                end

                return
            end

            if Dragging and IsHoverInput(Input) then
                local Delta = Input.Position - StartPos
                local Width = StartWidth + Delta.X

                if WindowInfo.DisableCompactingSnap then
                    Window:SetSidebarWidth(Width)
                    return
                end

                if Width > Threshold then
                    Window:SetSidebarWidth(math.max(Width, WindowInfo.MinSidebarWidth))
                else
                    Window:SetSidebarWidth(WindowInfo.SidebarCompactWidth)
                end
            end
        end))
    end
    if WindowInfo.EnableCompacting and WindowInfo.SidebarCompacted then
        Window:SetSidebarWidth(WindowInfo.SidebarCompactWidth)
    end
    if WindowInfo.AutoShow and not Library.ActiveLoading then
        task.spawn(Library.Toggle)
    end

    if Library.IsMobile then
        local ToggleButton = Library:AddDraggableButton("Toggle", function()
            Library:Toggle()
        end, true, true)

        local LockButton = Library:AddDraggableButton("Lock", function(self)
            Library.CantDragForced = not Library.CantDragForced
            self:SetText(Library.CantDragForced and "Unlock" or "Lock")
        end, true, true)

        if WindowInfo.MobileButtonsSide == "Right" then
            ToggleButton.Button.AnchorPoint = Vector2.new(1, 0)
            ToggleButton.Button.Position = UDim2.new(1, -6, 0, 6)

            LockButton.Button.AnchorPoint = Vector2.new(1, 0)
            LockButton.Button.Position = UDim2.new(1, -(ToggleButton.Button.Size.X.Offset + 12), 0, 6)
        else
            ToggleButton.Button.AnchorPoint = Vector2.new(0, 0)
            ToggleButton.Button.Position = UDim2.fromOffset(6, 6)

            LockButton.Button.AnchorPoint = Vector2.new(0, 0)
            LockButton.Button.Position = UDim2.fromOffset(ToggleButton.Button.Size.X.Offset + 12, 6)
        end

        if WindowInfo.ShowMobileButtons == false then
            ToggleButton.Button.Visible = false
            LockButton.Button.Visible = false
        end
    end

    --// Execution \\--
    Library:GiveSignal(SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        Library:UpdateSearch(SearchBox.Text)
    end))

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
        if Library.Unloaded then
            return
        end

        if UserInputService:GetFocusedTextBox() then
            return
        end

        if Input.KeyCode == Library.ToggleKeybind then
            Library:Toggle()
        end
    end))

    Library:GiveSignal(UserInputService.WindowFocused:Connect(function()
        Library.IsRobloxFocused = true
    end))
    Library:GiveSignal(UserInputService.WindowFocusReleased:Connect(function()
        Library.IsRobloxFocused = false
    end))

    Library.Window = Window
    return Window
end

function Library:CreateLoading(LoadingInfo)
    if Library.ActiveLoading then
        return Library.ActiveLoading
    end

    LoadingInfo = Library:Validate(LoadingInfo, Templates.Loading)

    local Loading = {
        CurrentStep = LoadingInfo.CurrentStep,
        TotalSteps = LoadingInfo.TotalSteps,

        ShowSidebar = LoadingInfo.ShowSidebar,
        AutoResizeHeight = LoadingInfo.AutoResizeHeight,
        IsError = false,
        Destroyed = false,

        WindowWidth = LoadingInfo.WindowWidth,
        WindowHeight = LoadingInfo.WindowHeight,
        BaseWindowHeight = LoadingInfo.WindowHeight,
        WindowErrorHeight = LoadingInfo.WindowHeight,

        ContentWidth = LoadingInfo.ContentWidth,
        SidebarWidth = LoadingInfo.SidebarWidth,
    }

    --// ScreenGui \\--
    local ScreenGui = New("ScreenGui", {
        Name = "ObsidianLoading",
        DisplayOrder = 999,
        ResetOnSpawn = false
    })
    ParentUI(ScreenGui)
    Loading.ScreenGui = ScreenGui

    ScreenGui.DescendantRemoving:Connect(function(Instance)
        Library:RemoveFromRegistry(Instance)
    end)

    --// Main Frame \\--
    local MainFrame = New("TextButton", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = function()
            return Library:GetBetterColor(Library.Scheme.BackgroundColor, -1)
        end,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Loading.ShowSidebar and (Loading.ContentWidth + Loading.SidebarWidth) or Loading.WindowWidth, Loading.WindowHeight),
        ClipsDescendants = true,
        Text = "",
        AutoButtonColor = false,
        Parent = ScreenGui,
    })
    Library:AddOutline(MainFrame)
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius), Parent = MainFrame }))

	local MainScale = New("UIScale", {
		Scale = Library.IsMobile and 0.8 or 1,
		Parent = MainFrame
	})
	table.insert(Library.Scales, MainScale)
	Library.ScalesOffset[MainScale] = Library.IsMobile and 0.2 or 0

    --// Layout Containers \\--
    local Container = New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, Loading.ContentWidth, 1, 0),
        Parent = MainFrame,
    })

    local SideBar = New("Frame", {
        Name = "SideBar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(Loading.ContentWidth, 0),
        Size = UDim2.new(0, Loading.ShowSidebar and Loading.SidebarWidth or 0, 1, 0),
        ClipsDescendants = true,
        Visible = Loading.ShowSidebar,
        Parent = MainFrame,
    })
    local SidebarCorner = New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius), Parent = SideBar })
    table.insert(Library.Corners, SidebarCorner)

    Library:AddOutline(SideBar)

    local SidebarDivider = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        Visible = Loading.ShowSidebar,
        Parent = SideBar,
    })

    --// Top Bar \\--
    local TopBar = New("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        ZIndex = 2,
        Parent = Container,
    })
    Library:MakeDraggable(MainFrame, TopBar, true, true)

    local TitleHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = TopBar,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = TitleHolder,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        Parent = TitleHolder,
    })

    if LoadingInfo.Icon then
        local Icon = Library:GetCustomIcon(LoadingInfo.Icon)
        local _WindowIcon = New("ImageLabel", {
            Image = Icon and Icon.Url or "",
            ImageRectOffset = Icon and Icon.ImageRectOffset or Vector2.zero,
            ImageRectSize = Icon and Icon.ImageRectSize or Vector2.zero,
            Size = LoadingInfo.IconSize,
            Parent = TitleHolder,
        })
    else
        local _WindowIcon = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = LoadingInfo.IconSize,
            Text = LoadingInfo.Title:sub(1, 1),
            TextScaled = true,
            Visible = false,
            Parent = TitleHolder,
        })
    end

    local TitleX = Library:GetTextBounds(
        LoadingInfo.Title,
        Library.Scheme.Font,
        20,
        TitleHolder.AbsoluteSize.X - (LoadingInfo.Icon and (LoadingInfo.IconSize.X.Offset + 6) or 0) - 12
    )
    local _WindowTitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, TitleX, 1, 0),
        Text = LoadingInfo.Title,
        TextSize = 20,
        Parent = TitleHolder,
    })

    Library:MakeLine(Container, {
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(1, 0, 0, 1),
    })

    --// Loading Content Elements \\--
    local InnerContent = New("Frame", {
        Name = "InnerContent",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        Parent = Container,
    })

    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12),
        Parent = InnerContent,
    })

    local IconHolder = New("Frame", {
        Name = "IconHolder",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(64, 64),
        Parent = InnerContent,
    })

    local LoaderIcon = Library:GetCustomIcon(LoadingInfo.LoadingIcon)
    local LoadingIcon = New("ImageLabel", {
        Name = "LoaderIcon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        Image = LoaderIcon and LoaderIcon.Url or "",
        ImageRectOffset = LoaderIcon and LoaderIcon.ImageRectOffset or Vector2.zero,
        ImageRectSize = LoaderIcon and LoaderIcon.ImageRectSize or Vector2.zero,
        ImageColor3 = LoadingInfo.LoadingIconColor or ((LoadingInfo.LoadingIcon == Templates.Loading.LoadingIcon) and "AccentColor" or "WhiteColor"),
        Parent = IconHolder,
    })

    local RotationTween
    if LoadingInfo.LoadingIconTweenTime > 0 then
        RotationTween = TweenService:Create(
            LoadingIcon,
            TweenInfo.new(LoadingInfo.LoadingIconTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
            { Rotation = 360 }
        )
        RotationTween:Play()
    end

    local MessageLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
        Size = Loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
        Text = "",
        TextSize = 18,
        TextWrapped = Loading.AutoResizeHeight,
        Parent = InnerContent,
    })

    local DescriptionLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
        Size = Loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
        Text = "",
        TextSize = 14,
        TextTransparency = 0.5,
        TextWrapped = Loading.AutoResizeHeight,
        Parent = InnerContent,
    })

    --// Progress Bar \\--
    local SliderBar = New("Frame", {
        BackgroundColor3 = "MainColor",
        Size = UDim2.new(0.7, 0, 0, 15),
        Parent = InnerContent,
    })
    Library:AddOutline(SliderBar)
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius / 2), Parent = SliderBar }))

    local SliderFill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
        Parent = SliderBar,
    })
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius / 2), Parent = SliderFill }))

    local ProgressLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextSize = 14,
        ZIndex = 2,
        Parent = SliderBar,
    })
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        Color = "DarkColor",
        LineJoinMode = Enum.LineJoinMode.Miter,
        Parent = ProgressLabel,
    })

    --// Sidebar Object \\--
    local SidebarScrolling = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = "OutlineColor",
        Parent = SideBar,
    })
    local SidebarList = New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = SidebarScrolling,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12),
        Parent = SidebarScrolling,
    })

    local SidebarObject = {
        Elements = {},
        DependencyBoxes = {},
        Tabboxes = {},

        BoxHolder = SidebarScrolling,
        Container = SidebarScrolling,

        Resize = function(self)
            SidebarScrolling.CanvasSize = UDim2.fromOffset(0, SidebarList.AbsoluteContentSize.Y + 24)
        end,
        Tab = {
            Elements = {},
            DependencyBoxes = {},
            DependencyGroupboxes = {},
            Tabboxes = {},
        },
    }

    SidebarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SidebarObject:Resize()
    end)

    setmetatable(SidebarObject, BaseGroupbox)
    Loading.Sidebar = SidebarObject

    --// Error Frame \\--
    local ErrorFrame = New("Frame", {
        Name = "Error",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        ClipsDescendants = true,
        Visible = false,
        Parent = Container,
    })

    local _ErrorTitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 15),
        Size = UDim2.new(1, -30, 0, 18),
        Text = "Error",
        TextColor3 = "RedColor",
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ErrorFrame,
    })

    local ErrorLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 39),
        Size = UDim2.new(1, -30, 1, -90),
        Text = "Error Message",
        TextSize = 14,
        TextTransparency = 0.2,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = ErrorFrame,
    })

    local ErrorButtonsDivider = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, -48),
        Size = UDim2.new(1, -30, 0, 1),
        Visible = false,
        Parent = ErrorFrame,
    })

    local ErrorButtonsHolder = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 42),
        Visible = false,
        Parent = ErrorFrame,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = ErrorButtonsHolder,
    })
    New("UIPadding", {
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),
        Parent = ErrorButtonsHolder,
    })

    function Loading:UpdateLayout()
        if Loading.IsError then
            Loading:RecalculateErrorHeight()
        end

        local ShowSidebar = Loading.ShowSidebar
        local FinalWidth = ShowSidebar and (Loading.ContentWidth + Loading.SidebarWidth) or Loading.WindowWidth
        local FinalHeight = Loading.IsError and Loading.WindowErrorHeight or Loading.WindowHeight

        if ShowSidebar then
            SideBar.Visible = true
            SidebarDivider.Visible = true
        end

        TweenService:Create(MainFrame, Library.TweenInfo, { Size = UDim2.fromOffset(FinalWidth, FinalHeight) }):Play()
        TweenService:Create(SideBar, Library.TweenInfo, { Position = UDim2.fromOffset(Loading.ContentWidth, 0), Size = UDim2.new(0, ShowSidebar and Loading.SidebarWidth or 0, 1, 0) }):Play()
        TweenService:Create(Container, Library.TweenInfo, { Size = UDim2.new(0, ShowSidebar and Loading.ContentWidth or Loading.WindowWidth, 1, 0) }):Play()

        if not ShowSidebar then
            task.delay(Library.TweenInfo.Time, function()
                if not Loading.ShowSidebar then
                    SideBar.Visible = false
                    SidebarDivider.Visible = false
                end
            end)
        end
    end

    --// Content Page \\--
    function Loading:RecalculateLoadingHeight()
        if not Loading.AutoResizeHeight then
            return
        end

        local RequiredHeight =
              49 -- TopBar
            + 48 -- Padding
            + InnerContent.UIListLayout.AbsoluteContentSize.Y

        Loading.WindowHeight = math.max(Loading.BaseWindowHeight, RequiredHeight)
    end

    function Loading:SetMessage(Text)
        MessageLabel.Text = Text

        if Loading.AutoResizeHeight then
            Loading:RecalculateLoadingHeight()
            Loading:UpdateLayout()
        end
    end

    function Loading:SetDescription(Text)
        DescriptionLabel.Text = Text

        if Loading.AutoResizeHeight then
            Loading:RecalculateLoadingHeight()
            Loading:UpdateLayout()
        end
    end

    function Loading:SetLoadingIcon(Icon)
        local IconData = Library:GetCustomIcon(Icon)
        assert(IconData, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        LoadingIcon.Image = IconData.Url
        LoadingIcon.ImageRectOffset = IconData.ImageRectOffset
        LoadingIcon.ImageRectSize = IconData.ImageRectSize
    end

    function Loading:SetLoadingIconTweenTime(TweenTime)
        if RotationTween then
            StopTween(RotationTween, true)
            RotationTween = nil
        end

        if TweenTime > 0 then
            RotationTween = TweenService:Create(
                LoadingIcon,
                TweenInfo.new(TweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
                { Rotation = 360 }
            )
            RotationTween:Play()
        else
            LoadingIcon.Rotation = 0
        end
    end

    function Loading:SetLoadingIconColor(Color)
        LoadingIcon.ImageColor3 = Color
    end

    function Loading:SetCurrentStep(Step)
        Loading.CurrentStep = math.clamp(Step, 0, Loading.TotalSteps)

        local Progress = Loading.CurrentStep / Loading.TotalSteps
        TweenService:Create(SliderFill, Library.TweenInfo, { Size = UDim2.fromScale(Progress, 1) }):Play()

        ProgressLabel.Text = string.format("%d/%d", Loading.CurrentStep, Loading.TotalSteps)
    end

    function Loading:SetTotalSteps(Steps)
        Loading.TotalSteps = Steps
        Loading:SetCurrentStep(Loading.CurrentStep)
    end

    --// Size \\--
    function Loading:SetWindowHeight(Height)
        Loading.WindowHeight = Height
        Loading:UpdateLayout()
    end

    function Loading:SetWindowWidth(Width)
        Loading.WindowWidth = Width
        Loading:UpdateLayout()
    end

    function Loading:SetContentWidth(Width)
        Loading.ContentWidth = Width
        Loading:UpdateLayout()
    end

    function Loading:SetSidebarWidth(Width)
        Loading.SidebarWidth = Width
        Loading:UpdateLayout()
    end

    --// Sidebar \\--
    function Loading:ShowSidebarPage(Bool)
        Loading.ShowSidebar = Bool
        Loading:UpdateLayout()
    end

    --// Error Page \\--
    function Loading:ShowErrorPage(Enabled)
        Loading.IsError = Enabled
        InnerContent.Visible = not Enabled
        ErrorFrame.Visible = Enabled

        if Loading.ShowSidebar then
            Loading:ShowSidebarPage(not Enabled)
        else
            Loading:UpdateLayout()
        end
    end

    function Loading:RecalculateErrorHeight()
        local TargetWidth = (Loading.ShowSidebar and Loading.ContentWidth or Loading.WindowWidth) - 30
        local _, ErrorY = Library:GetTextBounds(ErrorLabel.Text, Library.Scheme.Font, 14, TargetWidth)

        ErrorLabel.Size = UDim2.new(1, -30, 0, ErrorY)

        local HasButtons = ErrorButtonsHolder.Visible
        local RequiredHeight =
              49                        -- TopBar
            + 15                        -- Padding Top
            + 18                        -- Title Height
            + 6                         -- Padding between Title and Label
            + ErrorY                    -- Label Height
            + 15                        -- Padding between Label and Buttons
            + (HasButtons and 48 or 0)  -- Buttons Area

        Loading.WindowErrorHeight = RequiredHeight -- math.max(Loading.WindowHeight, RequiredHeight)
    end

    function Loading:SetErrorMessage(Text)
        ErrorLabel.Text = Text
        Loading:UpdateLayout()
    end

    function Loading:SetErrorButtons(Buttons)
        assert(typeof(Buttons) == "table", "Buttons must be a table")

        for _, button in ErrorButtonsHolder:GetChildren() do
            if button:IsA("Frame") then
                button:Destroy()
            end
        end

        local HasButtons = GetTableSize(Buttons) > 0
        ErrorButtonsHolder.Visible = HasButtons
        ErrorButtonsDivider.Visible = HasButtons

        for Idx, ButtonInfo in Buttons do
            local ButtonContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 26),
                Parent = ErrorButtonsHolder,
            })

            local BtnColor = "MainColor"
            local BtnOutline = "OutlineColor"
            local Variant = ButtonInfo.Variant or "Primary"

            if Variant == "Primary" then
                BtnColor = "FontColor"
                BtnOutline = "FontColor"
            elseif Variant == "Secondary" then
                BtnColor = "MainColor"
                BtnOutline = "OutlineColor"
            elseif Variant == "Destructive" then
                BtnColor = "DestructiveColor"
                BtnOutline = "DestructiveColor"
            elseif Variant == "Ghost" then
                BtnColor = "BackgroundColor"
                BtnOutline = "BackgroundColor"
            end

            local TextBtn = New("TextButton", {
                BackgroundColor3 = BtnColor,
                BorderColor3 = BtnOutline,
                Size = UDim2.fromOffset(0, 26),
                Text = "",
                AutoButtonColor = false,
                Parent = ButtonContainer,
            })
            Library:AddOutline(TextBtn)
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius),
                    Parent = TextBtn
                })
            )

            New("UIPadding", {
                PaddingLeft = UDim.new(0, 15),
                PaddingRight = UDim.new(0, 15),
                Parent = TextBtn,
            })

            local TextColor = Library.Scheme.FontColor
            if Variant == "Primary" then
                TextColor = Library.Scheme.BackgroundColor
            elseif Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end

            local BtnLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or Idx,
                TextColor3 = TextColor,
                TextSize = 14,
                Parent = TextBtn,
            })

            local LabelX, _ = Library:GetTextBounds(BtnLabel.Text, Library.Scheme.Font, 14, 250)
            ButtonContainer.Size = UDim2.fromOffset(LabelX + 30, 26)
            TextBtn.Size = UDim2.fromOffset(LabelX + 30, 26)

            local ActiveColor = typeof(BtnColor) == "Color3" and BtnColor or Library.Scheme[BtnColor]
            local HoverColor = Variant == "Ghost" and Library.Scheme.MainColor or Library:GetBetterColor(ActiveColor, 10)

            TextBtn.MouseEnter:Connect(function()
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = HoverColor
                }):Play()
            end)
            TextBtn.MouseLeave:Connect(function()
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = ActiveColor
                }):Play()
            end)

            TextBtn.MouseButton1Click:Connect(function()
                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Loading)
                end
            end)
        end

        Loading:UpdateLayout()
    end

    --// Destroy/Continue \\--
    function Loading:Destroy()
        if RotationTween then
            StopTween(RotationTween, true)
            RotationTween = nil
        end

        ScreenGui:Destroy()
        Loading.Destroyed = true
        Library.ActiveLoading = nil

        if Library.Toggle and Library.Toggled == false and Library.Unloaded ~= true then
            Library:Toggle(true)
        end
    end

    Loading.Continue = Loading.Destroy;

    if Library.Toggle and Library.Toggled and Library.Unloaded ~= true then
        Library:Toggle(false)
    end

    Loading:SetCurrentStep(Loading.CurrentStep)

    Library.ActiveLoading = Loading
    return Loading
end

local function OnPlayerChange()
    if Library.Unloaded then
        return
    end

    local PlayerList, ExcludedPlayerList = GetPlayers(), GetPlayers(true)
    for _, Dropdown in Options do
        if Dropdown.Type == "Dropdown" and Dropdown.SpecialType == "Player" then
            Dropdown:SetValues(Dropdown.ExcludeLocalPlayer and ExcludedPlayerList or PlayerList)
        end
    end
end

local function OnTeamChange()
    if Library.Unloaded then
        return
    end

    local TeamList = GetTeams()
    for _, Dropdown in Options do
        if Dropdown.Type == "Dropdown" and Dropdown.SpecialType == "Team" then
            Dropdown:SetValues(TeamList)
        end
    end
end

Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange))
Library:GiveSignal(Players.PlayerRemoving:Connect(OnPlayerChange))

Library:GiveSignal(Teams.ChildAdded:Connect(OnTeamChange))
Library:GiveSignal(Teams.ChildRemoved:Connect(OnTeamChange))

function Library:Unload()
    Library.Unloaded = true

    --// Disconnect connections
    for Index = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Index)

        if Connection and Connection.Connected then
            Connection:Disconnect()
        end
    end

    --// Run Unload Callbacks
    for _ = 1, #Library.UnloadSignals do
        local Callback = table.remove(Library.UnloadSignals, 1)

        if Callback then
            Library:SafeCallback(Callback)
        end
    end

    --// Destroy elements
    for Index = #Library.Tabs, 1, -1 do
        local Tab = table.remove(Library.Tabs, Index)

        if Tab and Tab.Destroy then
            Library:SafeCallback(Tab.Destroy, Tab)
        end
    end

    for Index = #Tooltips, 1, -1 do
        local Tooltip = table.remove(Tooltips, Index)

        if Tooltip and Tooltip.Destroy then
            Library:SafeCallback(Tooltip.Destroy, Tooltip)
        end
    end

    if Library.ActiveLoading then
        Library.ActiveLoading:Destroy()
    end

    if ScreenGui then
        ScreenGui:Destroy()
    end

    --// Clear tables
    table.clear(Library.Registry)

    table.clear(Options)
    table.clear(Toggles)
    table.clear(Buttons)
    table.clear(Labels)
    table.clear(Tooltips)

    table.clear(Library.Tabs)
    table.clear(Library.TabButtons)

    table.clear(Library.Scales)
    table.clear(Library.ScalesOffset)

    table.clear(Library.Corners)
    table.clear(Library.SpecificCorners)

    table.clear(Library.Notifications)
    table.clear(Library.Dialogues)
    table.clear(Library.DraggableElements)
    table.clear(Library.KeybindToggles)
    table.clear(Library.DependencyBoxes)

    table.clear(TransparencyCache)
    table.clear(ActiveTabTweens)

    Library.Toggle = function(...) end
    Library.ScreenGui = nil
    Library.WindowContainer = nil
    Library.KeybindFrame = nil
    Library.KeybindContainer = nil

    getgenv().Library = nil
end

getgenv().Library = Library
return Library
end

__kicia_hook_shared.obsidian_save_manager = function()
-- Vendored from Obsidian b4523805727561499b5b8206e14590371923f343; inline type annotations removed.
local cloneref = (cloneref or clonereference or function(instance)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func)
    return func
end)

local HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles

if typeof(clonefunction) == "function" then
    -- Fix is_____ functions for shitsploits, those functions should never error, only return a boolean.

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
            return (if success then data else false)
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            return (if success then data else false)
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            return (if success then data else {})
        end
    end
end

local SaveManager = {
    Library = nil,

    Folder = "ObsidianLibSettings",
    SubFolder = "",

    Ignore = {},
    LoadingOrder = {},
    UseLoadingOrder = false,

    AutoloadConfig = nil
}

function SaveManager:SetLibrary(Library)
    SaveManager.Library = Library
end

--// Element Parser \\--
local SpecialValueParser = {
    UDim2 = {
        Encode = function(Value)
            return {
                X = { Scale = Value.X.Scale, Offset = Value.X.Offset },
                Y = { Scale = Value.Y.Scale, Offset = Value.Y.Offset }
            }
        end,

        Decode = function(Data)
            local DataType = typeof(Data)
            if DataType == "table" then
                return UDim2.new(Data.X.Scale, Data.X.Offset, Data.Y.Scale, Data.Y.Offset)
            elseif DataType == "UDim2" then
                return Data
            end

            return nil
        end
    }
}

local ElementParser = {}; do
    local function CreateParser(
        ElementType,
        LibaryIndex,

        Save,
        Load,
        CustomElementFetcher
    )
        ElementParser[ElementType] = {
            Save = function(Index, Element, ...)
                local Data = Save(Index, Element, ...)
                Data.type = ElementType
                Data.idx = Index

                return Data
            end,

            Load = function(Index, Data)
                if CustomElementFetcher == true then
                    return Load(nil, Data)
                end

                local Elements = SaveManager.Library and SaveManager.Library[LibaryIndex]
                local Element = Elements and Elements[Index]
                return Load(Element, Data)
            end
        }
    end

    CreateParser(
        "Toggle", "Toggles",
        function(Index, Toggle)
            return { value = Toggle.Value }
        end,
        function(Element, Data)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end

            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "Slider", "Options",
        function(Index, Slider)
            return { value = tostring(Slider.Value) }
        end,
        function(Element, Data)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end

            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "Dropdown", "Options",
        function(Index, Dropdown)
            return { value = Dropdown.Value, multi = Dropdown.Multi }
        end,
        function(Element, Data)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end

            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "ColorPicker", "Options",
        function(Index, ColorPicker)
            return { value = ColorPicker.Value:ToHex(), transparency = ColorPicker.Transparency }
        end,
        function(Element, Data)
            if not Element then return end

            Element:SetValueRGB(Color3.fromHex(Data.value), Data.transparency)
        end
    )

    CreateParser(
        "KeyPicker", "Options",
        function(Index, KeyPicker)
            return { mode = KeyPicker.Mode, key = KeyPicker.Value, modifiers = KeyPicker.Modifiers, toggled = KeyPicker.Toggled }
        end,
        function(Element, Data)
            if not Element then return end

            Element:SetValue({ Data.key, Data.mode, Data.modifiers })
            if Data.mode == "Toggle" and Data.toggled ~= nil then
                Element.Toggled = Data.toggled
                Element:Update()
            end
        end
    )

    CreateParser(
        "Input", "Options",
        function(Index, Input)
            return { text = Input.Value }
        end,
        function(Element, Data)
            if not Element then return end
            if typeof(Data.text) ~= "string" then return end

            if Element.Value == Data.text then
                Element:RunChanged()
                return
            end

            Element:SetValue(Data.text)
        end
    )

    CreateParser(
        "Groupbox", "Tabs",
        function(Index, Groupbox, TabIndex)
            return { collapsed = Groupbox.Collapsed, tabIdx = TabIndex }
        end,
        function(_, Data)
            local TabIndex, Index = Data.tabIdx, Data.idx
            if typeof(TabIndex) ~= "string" or typeof(Index) ~= "string" then return end

            local Tabs = SaveManager.Library and SaveManager.Library.Tabs
            local Tab = Tabs and Tabs[TabIndex]
            if not Tab then return end

            local Groupbox = Tab.Groupboxes[Index]
            if not Groupbox or Groupbox.Collapsed == Data.collapsed then return end

            Groupbox:SetCollapsed(Data.collapsed == true)
        end,
        true
    )
end

--// Helpers \\--
local function Trim(Text)
    return Text:match("^%s*(.-)%s*$")
end

local function IsStringEmpty(String)
    return if typeof(String) == "string" then Trim(String) == "" else true
end

local function IsValidFolderPath(Name)
    return typeof(Name) == "string" and (
        Trim(Name) ~= "" and
        not Name:match("^%s*$") and
        not Name:find('[<>:"|%?%*%z]')
    )
end

--// Folder helper \\--
local function SplitPath(Path)
	local Result = {}
	local Current = ""

	for Part in string.gmatch(Path, "[^/]+") do
		Current = if Current == "" then Part else (Current .. "/" .. Part)
		table.insert(Result, Current)
	end

	return Result
end

local function GetFolderPath()
    if IsStringEmpty(SaveManager.Folder) then
        return false
    end

    return string.format("%s/settings", SaveManager.Folder)
end

local function GetSubFolderPath()
    if IsStringEmpty(SaveManager.Folder) or IsStringEmpty(SaveManager.SubFolder) then
        return false
    end

    return string.format("%s/settings/%s", SaveManager.Folder, SaveManager.SubFolder)
end

local function GetCurrentSettingsPath()
    local SubFolderPath = GetSubFolderPath()
    return if SubFolderPath == false then GetFolderPath() else SubFolderPath
end

--// Files helper \\--
local function GetConfigPath(ConfigName)
    local CurrentSettingsPath = GetCurrentSettingsPath()
    return if CurrentSettingsPath == false then false else string.format("%s/%s.json", CurrentSettingsPath, ConfigName)
end

local function DoesConfigExist(ConfigName)
    local ConfigPath = GetConfigPath(ConfigName)
    return if ConfigPath == false then false else isfile(ConfigPath)
end

local function GetAutoloadPath()
    local CurrentSettingsPath = GetCurrentSettingsPath()
    return if CurrentSettingsPath == false then false else string.format("%s/autoload.txt", CurrentSettingsPath)
end

--// Indexes \\--
function SaveManager:SetLoadingOrder(Enabled, Order)
    SaveManager.UseLoadingOrder = Enabled == true
    SaveManager.LoadingOrder = typeof(Order) == "table" and Order or SaveManager.LoadingOrder
end

function SaveManager:SetIgnoreIndexes(Indexes)
    assert(typeof(Indexes) == "table", "Expected table, got " .. typeof(Indexes))

    for _, Index in Indexes do
        SaveManager.Ignore[Index] = true
    end
end

function SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({
        "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", "FontFace", "BackgroundImage",
        "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName"
    })
end

--// Folders \\--
function SaveManager:GetPaths()
    local SubFolderPath = GetSubFolderPath()
    if SubFolderPath == false then
        local FolderPath = GetFolderPath()
        return if FolderPath == false then {} else SplitPath(FolderPath)
    end

    return SplitPath(SubFolderPath)
end

function SaveManager:BuildFolderTree(SkipWhenCreated)
    local Paths = SaveManager:GetPaths()
    if #Paths == 0 then
        return false
    end

    if SkipWhenCreated == true then
        if isfolder(Paths[1]) then
            return true
        end
    end

    for _, Path in Paths do
        if isfolder(Path) then continue end

        makefolder(Path)
    end

    return true
end

function SaveManager:CheckFolderTree()
    return SaveManager:BuildFolderTree(true)
end

function SaveManager:CheckSubFolder(CreateFolder)
    local SubFolderPath = GetSubFolderPath()
    if SubFolderPath == false then
        return false
    end

    local FolderExists = isfolder(SubFolderPath)
    if not CreateFolder then
        return FolderExists
    end

    makefolder(SubFolderPath)
    return true
end

function SaveManager:SetFolder(Folder)
    assert(IsValidFolderPath(Folder), "Invalid path provided")

    SaveManager.Folder = Folder
    SaveManager:BuildFolderTree()
end

function SaveManager:SetSubFolder(SubFolder)
    assert(IsValidFolderPath(SubFolder), "Invalid path provided")

    SaveManager.SubFolder = SubFolder
    SaveManager:BuildFolderTree()
end

--// Config Management \\--
function SaveManager:RefreshConfigList()
    local SettingsPath = GetCurrentSettingsPath()
    if SettingsPath == false then
        return {}
    end

    local SuccessList, Files = pcall(listfiles, SettingsPath)
    if not (SuccessList and typeof(Files) == "table") then
        SaveManager.Library:Notify(string.format("Failed to load config list: %s", tostring(Files)))
        return {}
    end

    local FileNames = {}
    for _, FilePath in Files do
        local RawFileName = FilePath:match("(.+)%..+$")
        if not RawFileName then continue end

        local Position = RawFileName:gsub("\\", "/"):find("/[^/]*$")
        local FileName = Position and RawFileName:sub(Position + 1) or RawFileName
        if not FileName or FileName == "autoload" then continue end

        table.insert(FileNames, FileName)
    end

    return FileNames
end

function SaveManager:Save(ConfigName)
    if IsStringEmpty(ConfigName) then
        return false, "Invalid config name provided"
    end

    if string.lower(ConfigName) == "autoload" then
        return false, "Invalid config name provided"
    end

    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false then
        return false, "Invalid config name provided"
    end

    SaveManager:CheckFolderTree()

    local Library = SaveManager.Library
    local IgnoreIndexes = SaveManager.Ignore
    local CurrentData = {
        timestamp = os.date("%d.%m.%Y %H:%M:%S"),
        name = ConfigName,

        objects = {},
        keybindMenu = if Library.KeybindFrame then {
            visible = Library.KeybindFrame.Visible,
            position = SpecialValueParser.UDim2.Encode(Library.KeybindFrame.Position)
        } else nil
    }

    --// Toggles
    for Index, Toggle in Library.Toggles do
        if not Toggle.Type then continue end
        if IgnoreIndexes[Index] then continue end

        local Parser = ElementParser[Toggle.Type]
        if not Parser then continue end

        table.insert(CurrentData.objects, Parser.Save(Index, Toggle))
    end

    --// Options
    for Index, Option in Library.Options do
        if not Option.Type then continue end
        if IgnoreIndexes[Index] then continue end

        local Parser = ElementParser[Option.Type]
        if not Parser then continue end

        table.insert(CurrentData.objects, Parser.Save(Index, Option))
    end

    --// Groupboxes
    for TabIndex, Tab in Library.Tabs do
        if not Tab.Groupboxes then continue end

        for Index, Groupbox in Tab.Groupboxes do
            if IgnoreIndexes[Index] then continue end

            local Parser = ElementParser.Groupbox
            if not Parser then continue end

            table.insert(CurrentData.objects, Parser.Save(Index, Groupbox, TabIndex))
        end
    end

    local SuccessEncode, EncodedData = pcall(HttpService.JSONEncode, HttpService, CurrentData)
    if not SuccessEncode then
        return false, "Failed to encode data"
    end

    local SuccessWrite, ErrorMessage = pcall(writefile, ConfigPath, EncodedData)
    if not SuccessWrite then
        return false, "Failed to write config file: " .. tostring(ErrorMessage)
    end

    return true
end

function SaveManager:Load(ConfigName)
    if IsStringEmpty(ConfigName) then
        return false, "No config is selected"
    end

    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then
        return false, "Config file does not exist"
    end

    local SuccessRead, Content = pcall(readfile, ConfigPath)
    if not SuccessRead then
        return false, "Failed to read config file"
    end

    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or typeof(Decoded) ~= "table" or typeof(Decoded.objects) ~= "table" then
        return false, "Failed to decode config data"
    end

    local Library = SaveManager.Library
    local LoadingOrder = SaveManager.LoadingOrder
    local IgnoreIndexes = SaveManager.Ignore

    if SaveManager.UseLoadingOrder == true and typeof(LoadingOrder) == "table" then
        table.sort(Decoded.objects, function(a, b)
            local aIndex = table.find(LoadingOrder, a.type) or math.huge
            local bIndex = table.find(LoadingOrder, b.type) or math.huge
            return aIndex < bIndex
        end)
    end

    --// Keybind Menu
    if Library.KeybindFrame and typeof(Decoded.keybindMenu) == "table" then
        local KeybindFrameData = Decoded.keybindMenu
        local IsVisible = KeybindFrameData.visible == true
        local Position = SpecialValueParser.UDim2.Decode(KeybindFrameData.position)

        Library.KeybindFrame.Visible = IsVisible
        Library.KeybindFrame.Position = Position or Library.KeybindFrame.Position

        local KeybindMenuToggle = Library.Options and Library.Options.KeybindMenuOpen
        if KeybindMenuToggle then
            KeybindMenuToggle:SetValue(IsVisible)
        end
    end

    --// Elements
    for _, Option in Decoded.objects do
        if not Option.type then continue end
        if IgnoreIndexes[Option.idx] then continue end

        local Parser = ElementParser[Option.type]
        if not Parser then continue end

        task.defer(Parser.Load, Option.idx, Option)
    end

    return true
end

function SaveManager:Delete(ConfigName)
    if IsStringEmpty(ConfigName) then
        return false, "No config is selected"
    end

    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then
        return false, "Config file does not exist"
    end

    local SuccessDelete, ErrorMessage = pcall(delfile, ConfigPath)
    if not SuccessDelete then
        return false, "Failed to delete config file: " .. tostring(ErrorMessage)
    end

    if ConfigName == SaveManager.AutoloadConfig then
        SaveManager:DeleteAutoLoadConfig()
    end

    return true
end

--// Auto Load Config \\--
function SaveManager:GetAutoloadConfig()
    SaveManager:CheckFolderTree()

    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then
        return "none", false, "Invalid path provided"
    end

    if not isfile(AutoloadPath) then
        return "none", false, "Autoload config is not set"
    end

    local SuccessRead, AutoloadConfigName = pcall(readfile, AutoloadPath)
    if not (SuccessRead and typeof(AutoloadConfigName) == "string") then
        return "none", false, AutoloadConfigName
    end

    local ConfigExists = DoesConfigExist(AutoloadConfigName)
    if not ConfigExists then
        return "none", false, "Config file not found"
    end

    SaveManager.AutoloadConfig = AutoloadConfigName
    return AutoloadConfigName, true
end

function SaveManager:SaveAutoloadConfig(ConfigName)
    if IsStringEmpty(ConfigName) then
        return false, "No config is selected"
    end

    SaveManager:CheckFolderTree()

    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then
        return false, "Invalid path provided"
    end

    if not DoesConfigExist(ConfigName) then
        return false, "Config does not exist"
    end

    local SuccessWrite, ErrorMessage = pcall(writefile, AutoloadPath, ConfigName)
    if not SuccessWrite then
        return false, ErrorMessage
    end

    SaveManager.AutoloadConfig = ConfigName
    return true
end

function SaveManager:LoadAutoloadConfig()
    local ConfigName, Success, FetchErrorMessage = SaveManager:GetAutoloadConfig()
    if not Success or FetchErrorMessage then
        if FetchErrorMessage ~= "Autoload config is not set" then
            SaveManager.Library:Notify(string.format("Failed to load autoload config: %s", FetchErrorMessage))
        end

        return
    end

    local SuccessLoad, LoadErrorMessage = SaveManager:Load(ConfigName)
    if not SuccessLoad then
        SaveManager.Library:Notify(string.format("Failed to load autoload config: %s", LoadErrorMessage))
        return
    end

    SaveManager.Library:Notify(string.format("Successfully loaded autoload config %q", ConfigName))
end

function SaveManager:DeleteAutoLoadConfig()
    SaveManager:CheckFolderTree()

    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then
        return false, "Invalid path provided"
    end

    if not isfile(AutoloadPath) then
        return false, "Autoload config is not set"
    end

    local SuccessDelete, ErrorMessage = pcall(delfile, AutoloadPath)
    if not SuccessDelete then
        return false, ErrorMessage
    end

    SaveManager.AutoloadConfig = nil
    return true
end

--// GUI \\--
local function ShowDialog(
    Condition,

    Index,
    Title,
    Description,

    DestructiveText,
    DestructiveAction
)
    if Condition() == false then
        return DestructiveAction()
    end

    return SaveManager.Library.Window:AddDialog(Index, {
        Title = Title,
        Description = Description,
        AutoDismiss = false,

        FooterButtons = {
            Cancel = {
                Title = "Cancel",
                Variant = "Ghost",
                Order = 1,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                end
            },

            DestructiveAction = {
                Title = DestructiveText,
                Variant = "Destructive",
                Order = 2,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                    DestructiveAction()
                end
            }
        }
    })
end

function SaveManager:BuildConfigSection(Tab, IconName)
    assert(SaveManager.Library, "Library is not set, call SaveManager:SetLibrary(Library) first.")
    local ConfigurationBox = Tab:AddRightGroupbox("Configuration", IconName or "folder-cog")

    local ConfigNameInput, ConfigList, AutoloadConfigLabel
    local function RefreshList()
        ConfigList:SetValues(SaveManager:RefreshConfigList())
        ConfigList:SetValue(nil)
    end

    local function RefreshAutoloadConfigLabel()
        local AutoloadConfigName, _Success, _ErrorMessage = SaveManager:GetAutoloadConfig()

        AutoloadConfigLabel:SetText(string.format("Current autoload config: %s", AutoloadConfigName))
        if ConfigList then RefreshList() end
    end

    --// Create
    ConfigurationBox:AddInput("SaveManager_ConfigName", {
        Text = "Config name"
    })

    ConfigurationBox:AddButton("Create config", function()
        local ConfigName = ConfigNameInput.Value
        if IsStringEmpty(ConfigName) then
            SaveManager.Library:Notify("Configuration name cannot be empty.")
            return
        end

        if string.lower(ConfigName) == "autoload" then
            SaveManager.Library:Notify("Invalid config name provided.")
            return
        end

        ShowDialog(
            function()
                return DoesConfigExist(ConfigName)
            end,

            "SaveManager_CreateConfig",
            "Config already exists",
            string.format("A config named %q already exists. Overwriting will replace it with your current settings.", ConfigName),

            "Overwrite",
            function()
                local Success, ErrorMessage = SaveManager:Save(ConfigName)
                if not Success then
                    SaveManager.Library:Notify(string.format("Failed to create config %q: %s", ConfigName, ErrorMessage))
                    return
                end

                SaveManager.Library:Notify(string.format("Successfully created config %q", ConfigName))
                RefreshList()
            end
        )
    end)

    ConfigurationBox:AddDivider()

    --// Manage
    ConfigurationBox:AddDropdown("SaveManager_ConfigList", {
        Text = "Config list",

        Values = SaveManager:RefreshConfigList(),
        AllowNull = true,
        Multi = false,

        FormatDisplayValue = function(Value)
            if Value == SaveManager.AutoloadConfig then
                return string.format("%s (autoload)", Value)
            end

            return Value
        end,
        FormatListValue = function(Value)
            if Value == SaveManager.AutoloadConfig then
                return string.format("%s (autoload)", Value)
            end

            return Value
        end
    })

    ConfigurationBox:AddButton({
        Text = "Load config",
        DoubleClick = false,

        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                SaveManager.Library:Notify("Please select a config first.")
                return
            end

            local Success, ErrorMessage = SaveManager:Load(ConfigName)
            if not Success then
                SaveManager.Library:Notify(string.format("Failed to load config %q: %s", ConfigName, ErrorMessage))
                return
            end

            SaveManager.Library:Notify(string.format("Successfully loaded config %q", ConfigName))
        end
    })

    ConfigurationBox:AddButton({
        Text = "Overwrite config",
        DoubleClick = false,

        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                SaveManager.Library:Notify("Please select a config first.")
                return
            end

            ShowDialog(
                function()
                    return true --// Always show
                end,

                "SaveManager_OverwriteConfig",
                "Overwrite config",
                string.format("Are you sure you want to overwrite %q with your current settings? This cannot be undone.", ConfigName),

                "Overwrite",
                function()
                    local Success, ErrorMessage = SaveManager:Save(ConfigName)
                    if not Success then
                        SaveManager.Library:Notify(string.format("Failed to overwrite config %q: %s", ConfigName, ErrorMessage))
                        return
                    end

                    SaveManager.Library:Notify(string.format("Successfully overwrote config %q", ConfigName))
                end
            )
        end
    })

    ConfigurationBox:AddButton({
        Text = "Delete config",
        DoubleClick = false,

        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                SaveManager.Library:Notify("Please select a config first.")
                return
            end

            ShowDialog(
                function()
                    return true --// Always show
                end,

                "SaveManager_DeleteConfig",
                "Delete config",
                string.format("Are you sure you want to delete %q? This cannot be undone.", ConfigName),

                "Delete",
                function()
                    local Success, ErrorMessage = SaveManager:Delete(ConfigName)
                    if not Success then
                        SaveManager.Library:Notify(string.format("Failed to delete config %q: %s", ConfigName, ErrorMessage))
                        return
                    end

                    SaveManager.Library:Notify(string.format("Successfully deleted config %q", ConfigName))
                    RefreshAutoloadConfigLabel()
                end
            )
        end
    })

    ConfigurationBox:AddButton("Refresh list", RefreshList)

    --// Autoload Config
    ConfigurationBox:AddButton({
        Text = "Set as autoload",
        DoubleClick = false,

        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                SaveManager.Library:Notify("Please select a config first.")
                return
            end

            local Success, ErrorMessage = SaveManager:SaveAutoloadConfig(ConfigName)
            if not Success then
                SaveManager.Library:Notify(string.format("Failed to set autoload config %q: %s", ConfigName, ErrorMessage))
                return
            end

            SaveManager.Library:Notify(string.format("Successfully set autoload config to %q", ConfigName))
            RefreshAutoloadConfigLabel()
        end
    })

    ConfigurationBox:AddButton({
        Text = "Reset autoload",
        DoubleClick = false,

        Func = function()
            ShowDialog(
                function()
                    return true --// Always show
                end,

                "SaveManager_ResetAutoload",
                "Reset autoload config",
                "Are you sure you want to clear the autoload config? No config will be loaded automatically on next launch.",

                "Reset",
                function()
                    local Success, ErrorMessage = SaveManager:DeleteAutoLoadConfig()
                    if not Success then
                        SaveManager.Library:Notify(string.format("Failed to reset autoload config: %s", ErrorMessage))
                        return
                    end

                    SaveManager.Library:Notify("Successfully reset autoload config.")
                    RefreshAutoloadConfigLabel()
                end
            )
        end
    })

    AutoloadConfigLabel = ConfigurationBox:AddLabel("Current autoload config: ...", true);

    --// Set variables
    ConfigNameInput, ConfigList =
        SaveManager.Library.Options.SaveManager_ConfigName,
        SaveManager.Library.Options.SaveManager_ConfigList;

    --// Refresh
    RefreshAutoloadConfigLabel()
    SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })

    return ConfigurationBox
end

SaveManager:BuildFolderTree()
return SaveManager
end

__kicia_hook_shared.obsidian_theme_manager = function()
-- Vendored from Obsidian b4523805727561499b5b8206e14590371923f343; inline type annotations removed.
local cloneref = (cloneref or clonereference or function(instance)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func)
    return func
end)

local HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles

if typeof(clonefunction) == "function" then
    -- Fix is_____ functions for shitsploits, those functions should never error, only return a boolean.

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
            return (if success then data else false)
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            return (if success then data else false)
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            return (if success then data else {})
        end
    end
end

local SchemeIndexes = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }
local ThemeManager = {
    Library = nil,

    Folder = "ObsidianLibSettings",

    AppliedToTab = false,
    DefaultThemeName = nil,

    BuiltInThemes = {
        ["Default"] = {
            1,
            { FontColor = "ffffff", MainColor = "191919", AccentColor = "7d55ff", BackgroundColor = "0f0f0f", OutlineColor = "282828", BackgroundImage = "" },
        },
        ["BBot"] = {
            2,
            { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414", BackgroundImage = "" },
        },
        ["Fatality"] = {
            3,
            { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d", BackgroundImage = "" },
        },
        ["Jester"] = {
            4,
            { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737", BackgroundImage = "" },
        },
        ["Mint"] = {
            5,
            { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737", BackgroundImage = "" },
        },
        ["Tokyo Night"] = {
            6,
            { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232", BackgroundImage = "" },
        },
        ["Ubuntu"] = {
            7,
            { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919", BackgroundImage = "" },
        },
        ["Quartz"] = {
            8,
            { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f", BackgroundImage = "" },
        },
        ["Nord"] = {
            9,
            { FontColor = "eceff4", MainColor = "3b4252", AccentColor = "88c0d0", BackgroundColor = "2e3440", OutlineColor = "4c566a", BackgroundImage = "" },
        },
        ["Dracula"] = {
            10,
            { FontColor = "f8f8f2", MainColor = "44475a", AccentColor = "ff79c6", BackgroundColor = "282a36", OutlineColor = "6272a4", BackgroundImage = "" },
        },
        ["Monokai"] = {
            11,
            { FontColor = "f8f8f2", MainColor = "272822", AccentColor = "f92672", BackgroundColor = "1e1f1c", OutlineColor = "49483e", BackgroundImage = "" },
        },
        ["Gruvbox"] = {
            12,
            { FontColor = "ebdbb2", MainColor = "3c3836", AccentColor = "fb4934", BackgroundColor = "282828", OutlineColor = "504945", BackgroundImage = "" },
        },
        ["Solarized"] = {
            13,
            { FontColor = "839496", MainColor = "073642", AccentColor = "cb4b16", BackgroundColor = "002b36", OutlineColor = "586e75", BackgroundImage = "" },
        },
        ["Catppuccin"] = {
            14,
            { FontColor = "d9e0ee", MainColor = "302d41", AccentColor = "f5c2e7", BackgroundColor = "1e1e2e", OutlineColor = "575268", BackgroundImage = "" },
        },
        ["One Dark"] = {
            15,
            { FontColor = "abb2bf", MainColor = "282c34", AccentColor = "c678dd", BackgroundColor = "21252b", OutlineColor = "5c6370", BackgroundImage = "" },
        },
        ["Cyberpunk"] = {
            16,
            { FontColor = "f9f9f9", MainColor = "262335", AccentColor = "00ff9f", BackgroundColor = "1a1a2e", OutlineColor = "413c5e", BackgroundImage = "" },
        },
        ["Oceanic Next"] = {
            17,
            { FontColor = "d8dee9", MainColor = "1b2b34", AccentColor = "6699cc", BackgroundColor = "16232a", OutlineColor = "343d46", BackgroundImage = "" },
        },
        ["Material"] = {
            18,
            { FontColor = "eeffff", MainColor = "212121", AccentColor = "82aaff", BackgroundColor = "151515", OutlineColor = "424242", BackgroundImage = "" },
        }
    }
}

function ThemeManager:SetLibrary(Library)
    ThemeManager.Library = Library
end

--// Helpers \\--
local function Trim(Text)
    return Text:match("^%s*(.-)%s*$")
end

local function IsStringEmpty(String)
    return if typeof(String) == "string" then Trim(String) == "" else true
end

local function IsValidFolderPath(Name)
    return typeof(Name) == "string" and (
        Trim(Name) ~= "" and
        not Name:match("^%s*$") and
        not Name:find('[<>:"|%?%*%z]')
    )
end

--// Folder helper \\--
local function SplitPath(Path)
	local Result = {}
	local Current = ""

	for Part in string.gmatch(Path, "[^/]+") do
		Current = if Current == "" then Part else (Current .. "/" .. Part)
		table.insert(Result, Current)
	end

	return Result
end

local function GetFolderPath()
    if IsStringEmpty(ThemeManager.Folder) then
        return false
    end

    return string.format("%s/themes", ThemeManager.Folder)
end

local GetCurrentThemesPath = GetFolderPath

--// Files helper \\--
local function GetThemePath(ThemeName)
    local CurrentThemesPath = GetCurrentThemesPath()
    return if CurrentThemesPath == false then false else string.format("%s/%s.json", CurrentThemesPath, ThemeName)
end

local function DoesThemeExist(ThemeName, IncludeBuiltIn)
    if ThemeManager.BuiltInThemes[ThemeName] then
        return true
    end

    local ThemePath = GetThemePath(ThemeName)
    return if ThemePath == false then false else isfile(ThemePath)
end

local function GetDefaultThemePath()
    local CurrentThemesPath = GetCurrentThemesPath()
    return if CurrentThemesPath == false then false else string.format("%s/default.txt", CurrentThemesPath)
end

--// Folders \\--
function ThemeManager:GetPaths()
    local FolderPath = GetFolderPath()
    return if FolderPath == false then {} else SplitPath(FolderPath)
end

function ThemeManager:BuildFolderTree(SkipWhenCreated)
    local Paths = ThemeManager:GetPaths()
    if #Paths == 0 then
        return false
    end

    if SkipWhenCreated == true then
        if isfolder(Paths[1]) then
            return true
        end
    end

    for _, Path in Paths do
        if isfolder(Path) then continue end

        makefolder(Path)
    end

    return true
end

function ThemeManager:CheckFolderTree()
    return ThemeManager:BuildFolderTree(true)
end

function ThemeManager:SetFolder(Folder)
    assert(IsValidFolderPath(Folder), "Invalid path provided")

    ThemeManager.Folder = Folder
    ThemeManager:BuildFolderTree()
end

--// Theme Management \\--
function ThemeManager:ReloadCustomThemes()
    local SettingsPath = GetCurrentThemesPath()
    if SettingsPath == false then
        return {}
    end

    local SuccessList, Files = pcall(listfiles, SettingsPath)
    if not (SuccessList and typeof(Files) == "table") then
        ThemeManager.Library:Notify(string.format("Failed to load theme list: %s", tostring(Files)))
        return {}
    end

    local FileNames = {}
    for _, FilePath in Files do
        local RawFileName = FilePath:match("(.+)%..+$")
        if not RawFileName then continue end

        local Position = RawFileName:gsub("\\", "/"):find("/[^/]*$")
        local FileName = Position and RawFileName:sub(Position + 1) or RawFileName
        if not FileName or FileName == "default" then continue end

        table.insert(FileNames, FileName)
    end

    return FileNames
end

function ThemeManager:GetCustomTheme(ThemeName)
    if IsStringEmpty(ThemeName) then
        return nil
    end

    local ThemePath = GetThemePath(ThemeName)
    if ThemePath == false or not isfile(ThemePath) then
        return nil
    end

    local SuccessRead, Content = pcall(readfile, ThemePath)
    if not SuccessRead then
        return nil
    end

    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or typeof(Decoded) ~= "table" then
        return nil
    end

    return Decoded
end

function ThemeManager:SaveCustomTheme(ThemeName)
    if IsStringEmpty(ThemeName) then
        return false, "Invalid theme name provided"
    end

    if string.lower(ThemeName) == "default" then
        return false, "Invalid theme name provided"
    end

    local ThemePath = GetThemePath(ThemeName)
    if ThemePath == false then
        return false, "Invalid theme name provided"
    end

    ThemeManager:CheckFolderTree()

    local Library = ThemeManager.Library
    local ThemeData = {
        FontFace = Library.Options.FontFace.Value,
        BackgroundImage = Library.Options.BackgroundImage.Value
    }

    for _, SchemeIndex in SchemeIndexes do
        ThemeData[SchemeIndex] = Library.Options[SchemeIndex].Value:ToHex()
    end

    local SuccessEncode, EncodedData = pcall(HttpService.JSONEncode, HttpService, ThemeData)
    if not SuccessEncode then
        return false, "Failed to encode data"
    end

    local SuccessWrite, ErrorMessage = pcall(writefile, ThemePath, EncodedData)
    if not SuccessWrite then
        return false, "Failed to write theme file: " .. tostring(ErrorMessage)
    end

    return true
end

function ThemeManager:Delete(ThemeName)
    if IsStringEmpty(ThemeName) then
        return false, "No theme is selected"
    end

    local ThemePath = GetThemePath(ThemeName)
    if ThemePath == false or not isfile(ThemePath) then
        return false, "Theme file does not exist"
    end

    local SuccessDelete, ErrorMessage = pcall(delfile, ThemePath)
    if not SuccessDelete then
        return false, "Failed to delete theme file: " .. tostring(ErrorMessage)
    end

    if ThemeName == ThemeManager.DefaultThemeName then
        ThemeManager:DeleteDefaultTheme()
    end

    return true
end

--// Default Theme \\--
function ThemeManager:GetDefaultTheme()
    ThemeManager:CheckFolderTree()

    local DefaultThemePath = GetDefaultThemePath()
    if DefaultThemePath == false then
        return "none", false, "Invalid path provided"
    end

    if not isfile(DefaultThemePath) then
        return "none", false, "Default theme is not set"
    end

    local SuccessRead, DefaultThemeName = pcall(readfile, DefaultThemePath)
    if not (SuccessRead and typeof(DefaultThemeName) == "string") then
        return "none", false, DefaultThemeName
    end

    local ConfigExists = DoesThemeExist(DefaultThemeName, true)
    if not ConfigExists then
        return "none", false, "Theme file not found"
    end

    ThemeManager.DefaultThemeName = DefaultThemeName
    return DefaultThemeName, true
end

function ThemeManager:SetDefaultTheme(Theme)
    assert(ThemeManager.Library, "Library is not set, call ThemeManager:SetLibrary(Library) first.")
    assert(not ThemeManager.AppliedToTab, "Cannot set default theme after applying ThemeManager to a tab!")

    local Library = ThemeManager.Library
    local DefaultThemeData = ThemeManager.BuiltInThemes["Default"][2]

    local LibraryScheme = {}
    local FinalTheme = {}

    for _, SchemeIndex in SchemeIndexes do
        local IndexData = Theme[SchemeIndex]
        local IndexType = typeof(IndexData)

        if IndexType == "Color3" then
            LibraryScheme[SchemeIndex] = IndexData
            FinalTheme[SchemeIndex] = string.format("#%s", IndexData:ToHex())

        elseif IndexType == "string" then
            LibraryScheme[SchemeIndex] = Color3.fromHex(IndexData)
            FinalTheme[SchemeIndex] = if IndexData:sub(1, 1) == "#" then IndexData else string.format("#%s", IndexData)

        else
            local Value = DefaultThemeData[SchemeIndex]
            LibraryScheme[SchemeIndex] = Color3.fromHex(Value)
            FinalTheme[SchemeIndex] = Value
        end
    end

    --// Font
    local FontFace = Theme["FontFace"]
    local FontFaceType = typeof(FontFace)

    if FontFaceType == "EnumItem" then
        LibraryScheme.Font = Font.fromEnum(FontFace)
        FinalTheme.FontFace = FontFace.Name

    elseif FontFaceType == "string" then
        LibraryScheme.Font = Font.fromEnum(Enum.Font[FontFace])
        FinalTheme.FontFace = FontFace

    else
        LibraryScheme.Font = Font.fromEnum(Enum.Font.Code)
        FinalTheme.FontFace = "Code"
    end

    --// Default Scheme Colors
    for _, DefaultSchemeColor in { "RedColor", "DestructiveColor", "DarkColor", "WhiteColor" } do
        LibraryScheme[DefaultSchemeColor] = Library.Scheme[DefaultSchemeColor]
    end

    --// Apply
    Library.Scheme = LibraryScheme
    ThemeManager.BuiltInThemes["Default"] = { 1, FinalTheme }

    Library:UpdateColorsUsingRegistry()
end

function ThemeManager:SaveDefault(ThemeName)
    if IsStringEmpty(ThemeName) then
        return false, "No theme is selected"
    end

    ThemeManager:CheckFolderTree()

    local DefaultThemePath = GetDefaultThemePath()
    if DefaultThemePath == false then
        return false, "Invalid path provided"
    end

    if not DoesThemeExist(ThemeName, true) then
        return false, "Theme does not exist"
    end

    local SuccessWrite, ErrorMessage = pcall(writefile, DefaultThemePath, ThemeName)
    if not SuccessWrite then
        return false, ErrorMessage
    end

    ThemeManager.DefaultThemeName = ThemeName
    return true
end

function ThemeManager:LoadDefault()
    local ThemeName, Success, FetchErrorMessage = ThemeManager:GetDefaultTheme()
    if not Success or FetchErrorMessage then
        if FetchErrorMessage ~= "Default theme is not set" then
            ThemeManager.Library:Notify(string.format("Failed to apply default theme: %s", FetchErrorMessage))
        end

        return
    end

    if not ThemeManager:GetCustomTheme(ThemeName) then
        ThemeManager.Library.Options.ThemeManager_ThemeList:SetValue(ThemeName)
        return
    end

    local SuccessLoad, LoadErrorMessage = ThemeManager:ApplyTheme(ThemeName)
    if not SuccessLoad then
        ThemeManager.Library:Notify(string.format("Failed to apply default theme: %s", LoadErrorMessage))
        return
    end

    ThemeManager.Library:Notify(string.format("Successfully applied default theme %q", ThemeName))
end

function ThemeManager:DeleteDefaultTheme()
    ThemeManager:CheckFolderTree()

    local DefaultThemePath = GetDefaultThemePath()
    if DefaultThemePath == false then
        return false, "Invalid path provided"
    end

    if not isfile(DefaultThemePath) then
        return false, "Default theme is not set"
    end

    local SuccessDelete, ErrorMessage = pcall(delfile, DefaultThemePath)
    if not SuccessDelete then
        return false, ErrorMessage
    end

    ThemeManager.DefaultThemeName = nil
    return true
end

--// Apply Theme \\--
function ThemeManager:ThemeUpdate()
    local Library = ThemeManager.Library

    for _, SchemeIndex in SchemeIndexes do
        local Element = Library.Options[SchemeIndex]
        if not Element then continue end

        Library.Scheme[SchemeIndex] = Element.Value
    end

    Library:UpdateColorsUsingRegistry()
end

function ThemeManager:ApplyTheme(ThemeName)
    if IsStringEmpty(ThemeName) then
        return false, "No theme is selected"
    end

    local CustomThemeData = ThemeManager:GetCustomTheme(ThemeName)
    local Data = CustomThemeData or ThemeManager.BuiltInThemes[ThemeName]

    if not Data then
        return false, "Theme not found"
    end

    local Library = ThemeManager.Library
    local SchemeData = Data[2]
    local ThemeData = CustomThemeData or SchemeData

    for Index, Value in ThemeData do
        if Index == "VideoLink" then
            continue
        end

        local Element = Library.Options[Index]
        local FinalValue = Value

        if Index == "FontFace" then
            ThemeManager.Library:SetFont(Enum.Font[FinalValue])

        elseif Index == "BackgroundImage" then
            ThemeManager.Library:SetBackgroundImage(FinalValue)

        else
            FinalValue = Color3.fromHex(Value)
            Library.Scheme[Index] = FinalValue
        end

        if Element then
            Element:SetValue(FinalValue)
        end
    end

    ThemeManager:ThemeUpdate()
    return true
end

--// GUI \\--
local function ShowDialog(
    Condition,

    Index,
    Title,
    Description,

    DestructiveText,
    DestructiveAction
)
    if Condition() == false then
        return DestructiveAction()
    end

    return ThemeManager.Library.Window:AddDialog(Index, {
        Title = Title,
        Description = Description,
        AutoDismiss = false,

        FooterButtons = {
            Cancel = {
                Title = "Cancel",
                Variant = "Ghost",
                Order = 1,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                end
            },

            DestructiveAction = {
                Title = DestructiveText,
                Variant = "Destructive",
                Order = 2,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                    DestructiveAction()
                end
            }
        }
    })
end

function ThemeManager:CreateThemeManager(Themesbox)
    assert(ThemeManager.Library, "Library is not set, call ThemeManager:SetLibrary(Library) first.")

    local BuiltInThemesNames = {}
    for Name, _ThemeData in ThemeManager.BuiltInThemes do
        table.insert(BuiltInThemesNames, Name)
    end

    local CustomThemeList, CustomThemeName, ThemeList, FontFace, BackgroundImage, DefaultThemeLabel
    local function RefreshList()
        CustomThemeList:SetValues(ThemeManager:ReloadCustomThemes())
        CustomThemeList:SetValue(nil)

        ThemeList:SetValues(BuiltInThemesNames)
    end

    local function RefreshDefaultThemeLabel()
        local DefaultThemeName, _Success, _ErrorMessage = ThemeManager:GetDefaultTheme()

        DefaultThemeLabel:SetText(string.format("Current default theme: %s", DefaultThemeName))
        if CustomThemeList then RefreshList() end
    end

    table.sort(BuiltInThemesNames, function(IndexA, IndexB)
        return ThemeManager.BuiltInThemes[IndexA][1] < ThemeManager.BuiltInThemes[IndexB][1]
    end)

    local function CreateColorOption(Text, SchemeIndex)
        Themesbox:AddLabel(Text):AddColorPicker(SchemeIndex, {
            Default = ThemeManager.Library.Scheme[SchemeIndex]
        })

        return ThemeManager.Library.Options[SchemeIndex]
    end

    local BackgroundColor = CreateColorOption("Background color", "BackgroundColor")
    local MainColor = CreateColorOption("Main color", "MainColor")
    local AccentColor = CreateColorOption("Accent color", "AccentColor")
    local OutlineColor = CreateColorOption("Outline color", "OutlineColor")
    local FontColor = CreateColorOption("Font color", "FontColor")

    Themesbox:AddDropdown("FontFace", {
        Text = "Font Face",
        Default = "Code",

        Values = { "BuilderSans", "Code", "Fantasy", "Gotham", "Jura", "Roboto", "RobotoMono", "SourceSans" },
        AllowNull = false,
        Multi = false
    })

    Themesbox:AddInput("BackgroundImage", {
        Text = "Background Image",

        Default = "",
        Finished = true,
        ClearTextOnFocus = false,
        ClearTextOnBlur = false
    })

    Themesbox:AddDivider()

    Themesbox:AddDropdown("ThemeManager_ThemeList", {
        Text = "Theme list",

        Values = BuiltInThemesNames,
        AllowNull = true,
        Multi = false,

        FormatDisplayValue = function(Value)
            if Value ~= "Default" and Value == ThemeManager.DefaultThemeName then
                return string.format("%s (default)", Value)
            end

            return Value
        end,
        FormatListValue = function(Value)
            if Value ~= "Default" and Value == ThemeManager.DefaultThemeName then
                return string.format("%s (default)", Value)
            end

            return Value
        end
    })

    Themesbox:AddButton("Set as default", function()
        local ThemeName = ThemeList.Value
        ThemeManager:SaveDefault(ThemeName)

        ThemeManager.Library:Notify(string.format("Successfully set default theme to %q", ThemeName))
        RefreshDefaultThemeLabel()
    end)

    Themesbox:AddDivider()

    CustomThemeName = Themesbox:AddInput("ThemeManager_CustomThemeName", {
        Text = "Custom theme name"
    })

    Themesbox:AddButton("Create theme", function()
        local Name = CustomThemeName.Value
        if IsStringEmpty(Name) then
            ThemeManager.Library:Notify("Theme name cannot be empty.")
            return
        end

        if string.lower(Name) == "default" then
            ThemeManager.Library:Notify("Invalid theme name provided.")
            return
        end

        ShowDialog(
            function()
                return ThemeManager:GetCustomTheme(Name) ~= nil
            end,

            "ThemeManager_CreateTheme",
            "Theme already exists",
            string.format("A custom theme named %q already exists. Overwriting it will replace it with your current colors.", Name),

            "Overwrite",
            function()
                local Success, ErrorMessage = ThemeManager:SaveCustomTheme(Name)
                if not Success then
                    ThemeManager.Library:Notify(string.format("Failed to create theme %q: %s", Name, ErrorMessage))
                    return
                end

                ThemeManager.Library:Notify(string.format("Successfully created theme %q", Name))
                RefreshList()
            end
        )
    end)

    Themesbox:AddDivider()

    CustomThemeList = Themesbox:AddDropdown("ThemeManager_CustomThemeList", {
        Text = "Custom themes",

        Values = ThemeManager:ReloadCustomThemes(),
        AllowNull = true,
        Multi = false,

        FormatDisplayValue = function(Value)
            if Value == ThemeManager.DefaultThemeName then
                return string.format("%s (default)", Value)
            end

            return Value
        end,
        FormatListValue = function(Value)
            if Value == ThemeManager.DefaultThemeName then
                return string.format("%s (default)", Value)
            end

            return Value
        end
    })

    Themesbox:AddButton("Load theme", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then
            ThemeManager.Library:Notify("Please select a theme first.")
            return
        end

        ThemeManager:ApplyTheme(Name)
        ThemeManager.Library:Notify(string.format("Successfully loaded theme %q", Name))
    end)

    Themesbox:AddButton("Overwrite theme", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then
            ThemeManager.Library:Notify("Please select a theme first.")
            return
        end

        ShowDialog(
            function()
                return true
            end,

            "ThemeManager_OverwriteTheme",
            "Overwrite theme",
            string.format("Are you sure you want to overwrite %q with your current colors? This cannot be undone.", Name),

            "Overwrite",
            function()
                ThemeManager:SaveCustomTheme(Name)
                ThemeManager.Library:Notify(string.format("Successfully overwrote theme %q", Name))
            end
        )
    end)

    Themesbox:AddButton("Delete theme", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then
            ThemeManager.Library:Notify("Please select a theme first.")
            return
        end

        ShowDialog(
            function()
                return true
            end,

            "ThemeManager_DeleteTheme",
            "Delete theme",
            string.format("Are you sure you want to delete %q? This cannot be undone.", Name),

            "Delete",
            function()
                local Success, ErrorMessage = ThemeManager:Delete(Name)
                if not Success then
                    ThemeManager.Library:Notify(string.format("Failed to delete theme: %s", ErrorMessage))
                    return
                end

                ThemeManager.Library:Notify(string.format("Successfully deleted theme %q", Name))
                RefreshDefaultThemeLabel()
            end
        )
    end)

    Themesbox:AddButton("Refresh list", RefreshList)

    Themesbox:AddButton("Set as default", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then
            ThemeManager.Library:Notify("Please select a theme first.")
            return
        end

        ThemeManager:SaveDefault(Name)
        ThemeManager.Library:Notify(string.format("Successfully set default theme to %q", Name))
        RefreshDefaultThemeLabel()
    end)

    Themesbox:AddButton("Reset default", function()
        ShowDialog(
            function()
                return true
            end,

            "ThemeManager_ResetDefault",
            "Reset default theme",
            "Are you sure you want to clear the default theme? The library will revert to its built-in default on next load.",

            "Reset",
            function()
                local Success, ErrorMessage = ThemeManager:DeleteDefaultTheme()
                if not Success then
                    ThemeManager.Library:Notify(string.format("Failed to reset default theme: %s", ErrorMessage))
                    return
                end

                ThemeManager.Library:Notify("Successfully reset default theme.")
                RefreshDefaultThemeLabel()
            end
        )
    end)

    DefaultThemeLabel = Themesbox:AddLabel("Current default theme: ...", true);

    --// Set Variables
    CustomThemeList, CustomThemeName, ThemeList, FontFace, BackgroundImage =
        ThemeManager.Library.Options.ThemeManager_CustomThemeList,
        ThemeManager.Library.Options.ThemeManager_CustomThemeName,
        ThemeManager.Library.Options.ThemeManager_ThemeList,
        ThemeManager.Library.Options.FontFace,
        ThemeManager.Library.Options.BackgroundImage;

    --// Handlers
    ThemeList:OnChanged(function()
        ThemeManager:ApplyTheme(ThemeList.Value)
    end)

    local function UpdateTheme()
        ThemeManager:ThemeUpdate()
    end

    BackgroundColor:OnChanged(UpdateTheme)
    MainColor:OnChanged(UpdateTheme)
    AccentColor:OnChanged(UpdateTheme)
    OutlineColor:OnChanged(UpdateTheme)
    FontColor:OnChanged(UpdateTheme)
    FontFace:OnChanged(function(Value) ThemeManager.Library:SetFont(Enum.Font[Value]) end)
    BackgroundImage:OnChanged(function(Value) ThemeManager.Library:SetBackgroundImage(Value) end)

    --// Load default
    ThemeManager:LoadDefault()
    ThemeManager.AppliedToTab = true
    RefreshDefaultThemeLabel()

    return Themesbox
end

function ThemeManager:CreateGroupBox(Tab, IconName)
    return Tab:AddLeftGroupbox("Themes", IconName or "paintbrush")
end

function ThemeManager:ApplyToTab(Tab, IconName)
    local Groupbox = ThemeManager:CreateGroupBox(Tab, IconName)
    return ThemeManager:CreateThemeManager(Groupbox)
end

function ThemeManager:ApplyToGroupbox(Groupbox)
    return ThemeManager:CreateThemeManager(Groupbox)
end

getgenv().ObsidianThemeManager = ThemeManager
return ThemeManager
end

__kicia_hook_shared.script_paths = function()
-- =============================================================================
--  Paths - on-disk storage and UI preferences
-- =============================================================================
--  Owns every file this script touches on your machine. All of it lives under a
--  single folder in your executor's workspace directory:
--
--      <executor workspace>/KiciaHook/
--          UISettings.json                  general menu preferences
--          AutoShow.txt                     mirror of the "auto show" preference
--          settings/<config>.json           saved feature configs
--          RIVALS Skyboxes.json             custom skybox list (World tab)
--          RIVALS Custom Sounds.json        custom sound list (Client Effects)
--          RIVALS Movement Recordings.json  saved movement recordings
--          RIVALS Sounds/                   cached downloaded sounds
-- =============================================================================

-- Change these two to rename the script. DisplayName is what the menu title bar
-- shows; StorageRoot is the folder name on disk (renaming it orphans any configs
-- already saved under the old name).
local DisplayName = 'KiciaHook'
local StorageRoot = 'KiciaHook'

-- Where queue_on_teleport should re-read the script from when "Auto Execute on
-- Teleport" is enabled. Save the built script to this path (relative to your
-- executor's workspace folder) for that option to work. If you load the script
-- from a URL instead, replace the body of queue_on_teleport_script() below with
-- your own loadstring line.
local LocalScriptPath = StorageRoot .. '/KiciaHook_Source_Runnable.lua'

local AutoShowPath = StorageRoot .. '/AutoShow.txt'
local UiSettingsPath = StorageRoot .. '/UISettings.json'
local HttpService = game:GetService('HttpService')

local DefaultUiSettings = {
    auto_show = false,
    show_notification = true,
    show_keybind_states = false,
    auto_execute_on_teleport = false,
    auto_load_config = true,
    auto_save_config = true,
    load_config_name = 'Legit',
    menu_keybind = 'LeftControl',
}

local module = {}

-- pcall'd because a handful of executors ship no filesystem API at all. Losing
-- persistence is survivable; erroring out of the bootstrap is not.
pcall(function()
    if not isfolder(StorageRoot) then
        makefolder(StorageRoot)
    end
end)

local function clone_table(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function apply_ui_setting_overrides(defaults, overrides)
    if type(overrides) ~= 'table' then
        return defaults
    end

    for key, value in pairs(overrides) do
        if DefaultUiSettings[key] ~= nil and value ~= nil then
            defaults[key] = value
        end
    end

    return defaults
end

-- Never trusts the file on disk: every key is type-checked against the default
-- it replaces, so a hand-edited or corrupted JSON degrades to defaults instead
-- of feeding a wrong-typed value into the UI library.
local function sanitize_ui_settings(settings, defaults)
    local data = clone_table(defaults)
    if type(settings) ~= 'table' then
        return data
    end

    for key, fallback in pairs(defaults) do
        local value = settings[key]
        if type(fallback) == 'boolean' then
            if type(value) == 'boolean' then
                data[key] = value
            end
        elseif type(fallback) == 'string' then
            if type(value) == 'string' and value ~= '' then
                data[key] = value
            end
        end
    end

    return data
end

local function read_legacy_auto_show(default_value)
    local path = module.auto_show_path()
    if not isfile(path) then
        return default_value
    end

    local success, value = pcall(readfile, path)
    if not success then
        return default_value
    end

    value = string.lower(tostring(value))
    if value == 'true' then
        return true
    end
    if value == 'false' then
        return false
    end

    return default_value
end

function module.storage_root()
    return StorageRoot
end

function module.auto_show_path()
    return AutoShowPath
end

function module.ui_settings_path()
    return UiSettingsPath
end

function module.default_ui_settings(overrides)
    return apply_ui_setting_overrides(clone_table(DefaultUiSettings), overrides)
end

function module.config_path(config_name)
    return StorageRoot .. '/settings/' .. config_name .. '.json'
end

function module.load_ui_settings(overrides)
    local defaults = module.default_ui_settings(overrides)

    if isfile(UiSettingsPath) then
        local read_ok, raw = pcall(readfile, UiSettingsPath)
        if read_ok then
            local decode_ok, decoded = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            if decode_ok then
                return sanitize_ui_settings(decoded, defaults)
            end
        end
    end

    defaults.auto_show = read_legacy_auto_show(defaults.auto_show)
    return defaults
end

function module.save_ui_settings(settings, overrides)
    local data = sanitize_ui_settings(settings, module.default_ui_settings(overrides))
    writefile(UiSettingsPath, HttpService:JSONEncode(data))
    writefile(module.auto_show_path(), data.auto_show and 'true' or 'false')
    return data
end

-- AutoShow is mirrored into its own plain-text file so the menu can decide
-- whether to open itself before the JSON settings have been parsed.
function module.ensure_auto_show_file()
    local path = module.auto_show_path()
    local ui_settings = module.load_ui_settings()
    writefile(path, ui_settings.auto_show and 'true' or 'false')
    return path
end

-- Handed to queue_on_teleport so the script re-runs automatically after a
-- teleport between RIVALS places. Reads the copy you saved locally -- swap in
-- your own loadstring(game:HttpGet("...")) line if you load from a URL.
function module.queue_on_teleport_script()
    return 'loadstring(readfile("' .. LocalScriptPath .. '"))()'
end

function module.format_title()
    return DisplayName
end

return module
end

__kicia_hook_shared.connection_registry = function()
local module = {}

local function disconnect_handle(handle)
    if handle == nil then
        return
    end

    if type(handle) == 'function' then
        pcall(handle)
        return
    end

    if type(handle) == 'table' then
        local disconnect_method = handle.Disconnect
        if type(disconnect_method) == 'function' then
            pcall(disconnect_method, handle)
        end
        return
    end

    pcall(function()
        handle:Disconnect()
    end)
end

function module.new()
    local handles = {}
    local registry = {}

    function registry:register(name, handle)
        if handles[name] ~= nil then
            disconnect_handle(handles[name])
        end

        handles[name] = handle
        return handle
    end

    function registry:get(name)
        return handles[name]
    end

    function registry:disconnect(names)
        for _, name in ipairs(names) do
            if handles[name] ~= nil then
                disconnect_handle(handles[name])
                handles[name] = nil
            end
        end
    end

    function registry:disconnect_all()
        for name, handle in pairs(handles) do
            disconnect_handle(handle)
            handles[name] = nil
        end
    end

    setmetatable(registry, {
        __newindex = function(_, name, handle)
            registry:register(name, handle)
        end,
        __index = function(_, name)
            return handles[name]
        end,
    })

    return registry
end

return module
end

__kicia_hook_shared.ui_settings = function()
local module = {}

local DEFAULT_CONFIG_NAMES = { 'Legit', 'Rage' }
local AUTO_SAVE_DEBOUNCE_SECONDS = 0.35
local AUTO_SAVE_SUPPORTED_TYPES = {
    Toggle = true,
    Slider = true,
    Dropdown = true,
    ColorPicker = true,
    KeyPicker = true,
    Input = true,
}

function module.new(args)
    local window = args.window
    local library = args.library
    local theme_manager = args.theme_manager
    local script_paths = args.script_paths
    local toggles = args.toggles
    local options = args.options
    local local_player = args.local_player
    local queue_loader = args.queue_loader
    local on_load_default = args.on_load_default
    local on_save = args.on_save
    local is_queue_on_teleport_forced = args.is_queue_on_teleport_forced
    local save_manager = args.save_manager
    local current_config_name = args.current_config_name

    local function AppendConfigName(list, seen, config_name)
        if type(config_name) ~= 'string' or config_name == '' or string.lower(config_name) == 'none' or seen[config_name] then
            return
        end

        seen[config_name] = true
        table.insert(list, config_name)
    end

    local function BuildConfigNames()
        local list = {}
        local seen = {}

        local source_config_names = type(args.config_names) == 'table' and args.config_names or DEFAULT_CONFIG_NAMES
        for _, config_name in ipairs(source_config_names) do
            AppendConfigName(list, seen, config_name)
        end

        if #list == 0 then
            AppendConfigName(list, seen, current_config_name)
        end

        return list
    end

    local config_names = BuildConfigNames()
    local default_config_selection = config_names[1] or current_config_name
    local config_dropdown_values = {}
    for _, config_name in ipairs(config_names) do
        table.insert(config_dropdown_values, config_name)
    end

    local function ResolveConfigFileName(config_name)
        if type(args.resolve_config_name) == 'function' then
            local resolved = args.resolve_config_name(config_name)
            if type(resolved) == 'string' and resolved ~= '' then
                return resolved
            end
        end

        if args.use_global_config_names == true then
            return config_name
        end

        if config_name == current_config_name then
            return config_name
        end

        if type(current_config_name) == 'string' and current_config_name ~= '' then
            return current_config_name .. ' ' .. config_name
        end

        return config_name
    end

    local ids = args.ids or {
        auto_show = 'P3S1T1',
        show_notification = 'P3S1T2',
        show_keybind_states = 'P3S1T3',
        auto_execute_on_teleport = 'P3S1T4',
        auto_load_config = 'P3S1T5',
        auto_save_config = 'UIAutoSaveConfig',
        load_config_name = 'UILoadConfigName',
    }

    local defaults = args.defaults or {}
    local persisted_defaults = script_paths.load_ui_settings(defaults)
    local persist_menu_keybind = args.persist_menu_keybind ~= false
    local settings = {}
    local queue_on_teleport_connection = nil
    local shutting_down = false
    local config_load_suppression_count = 0
    local auto_save_token = 0
    local auto_save_wrappers = setmetatable({}, { __mode = 'k' })
    local auto_save_binding_loop_started = false
    local preserved_ids = {}
    preserved_ids[ids.auto_show] = true
    preserved_ids[ids.show_notification] = true
    preserved_ids[ids.show_keybind_states] = true
    preserved_ids[ids.auto_execute_on_teleport] = true
    preserved_ids[ids.auto_load_config] = true
    preserved_ids[ids.auto_save_config] = true

    local function IsConfigSelectionValue(value)
        if type(value) ~= 'string' then
            return false
        end

        for _, config_name in ipairs(config_dropdown_values) do
            if value == config_name then
                return true
            end
        end

        return false
    end

    local function NormalizeConfigSelectionValue(value, fallback)
        if IsConfigSelectionValue(value) then
            return value
        end
        if IsConfigSelectionValue(fallback) then
            return fallback
        end
        return default_config_selection
    end

    local function ResolveConfigSelectionValue(option_id, fallback)
        local option = options[option_id]
        if option and IsConfigSelectionValue(option.Value) then
            return option.Value
        end

        return NormalizeConfigSelectionValue(fallback, default_config_selection)
    end

    if save_manager and type(save_manager.SetIgnoreIndexes) == 'function' then
        local ignore_list = {
            ids.auto_show,
            ids.show_notification,
            ids.show_keybind_states,
            ids.auto_execute_on_teleport,
            ids.auto_load_config,
            ids.auto_save_config,
            ids.load_config_name,
            'MenuKeybind',
        }
        if type(args.extra_ignore_ids) == 'table' then
            for _, extra_id in ipairs(args.extra_ignore_ids) do
                if type(extra_id) == 'string' and extra_id ~= '' then
                    table.insert(ignore_list, extra_id)
                end
            end
        end
        save_manager:SetIgnoreIndexes(ignore_list)
    end

    local function disconnect_queue_on_teleport()
        if queue_on_teleport_connection then
            queue_on_teleport_connection:Disconnect()
            queue_on_teleport_connection = nil
        end
    end

    local tab = window:AddTab('UI Settings', 'settings')
    local group = tab:AddLeftGroupbox(args.groupbox_title or 'Menu Options')
    local load_config_name_default = NormalizeConfigSelectionValue(
        persisted_defaults.load_config_name,
        defaults.load_config_name or default_config_selection
    )

    group:AddToggle(ids.auto_show, {
        Text = 'Silent Execute',
        Default = not persisted_defaults.auto_show,
        Tooltip = 'Keeps the UI hidden on execute. Use your menu keybind to open it.'
    })

    group:AddToggle(ids.show_notification, {
        Text = 'Load Notification',
        Default = persisted_defaults.show_notification,
        Tooltip = 'Will show "Successfully loaded" notification on execute'
    })

    group:AddToggle(ids.show_keybind_states, {
        Text = 'Show keybind states',
        Default = persisted_defaults.show_keybind_states,
        Tooltip = 'Shows a menu of your active keybind toggles. On mobile, tap a keybind to toggle it.'
    })

    group:AddToggle(ids.auto_execute_on_teleport, {
        Text = 'Auto Execute',
        Default = persisted_defaults.auto_execute_on_teleport,
        Tooltip = 'Will execute your script automatically when teleporting to a new area'
    })

    group:AddToggle(ids.auto_save_config, {
        Text = 'Auto Save Config',
        Default = persisted_defaults.auto_save_config,
        Tooltip = 'Automatically saves changed toggles, sliders, dropdowns, colors, keybinds, and inputs to the selected config.'
    })

    group:AddToggle(ids.auto_load_config, {
        Text = 'Auto Load Config',
        Default = persisted_defaults.auto_load_config,
        Tooltip = 'Automatically loads your saved config on execute'
    })

    group:AddDropdown(ids.load_config_name, {
        Text = 'Selected Config',
        Values = config_dropdown_values,
        Default = load_config_name_default,
        Tooltip = 'Selected config used by Auto Load Config, Auto Save Config, Save Config, and Load Selected Config.'
    })

    group:AddButton('Save Config', function()
        if on_save then
            local ok, err = on_save(settings:resolve_save_config_name())
            if ok == false then
                library:Notify({ Title = 'Config', Description = 'Failed to save config: ' .. tostring(err), Time = 3 })
                return
            end
        end
        library:Notify({ Title = 'Config', Description = 'Config saved', Time = 3 })
    end)

    group:AddButton('Load Selected Config', function()
        if args.on_load_saved then
            args.on_load_saved()
            library:Notify({ Title = 'Config', Description = 'Selected config loaded', Time = 3 })
        end
    end)

    group:AddButton('Reset To Default', function()
        on_load_default()
    end)


    group:AddButton({
        Text = 'Unload',
        Func = function()
            -- __kicia_hook_genv is the Header-resolved env (in scope because
            -- shared modules are injected inside Header's function). Clearing
            -- getgenv() here instead would miss the guard on executors whose
            -- getgenv is broken, permanently blocking re-execution.
            settings:shutdown_for_unload()
            __kicia_hook_genv.Executed = nil
            pcall(function() _G.__KiciaHookExecuted = nil end)
            library:Unload()
        end,
        DoubleClick = true,
    })

    group:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
        Default = persist_menu_keybind and persisted_defaults.menu_keybind or defaults.menu_keybind or 'LeftControl',
        NoUI = true,
        Text = 'Menu keybind'
    })

    library.ToggleKeybind = options.MenuKeybind

    local theme_group = tab:AddRightGroupbox('Themes')

    theme_group:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = library.Scheme.BackgroundColor })
    theme_group:AddLabel('Main color'):AddColorPicker('MainColor', { Default = library.Scheme.MainColor })
    theme_group:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = library.Scheme.AccentColor })
    theme_group:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = library.Scheme.OutlineColor })

    local ThemesArray = {}
    for Name in pairs(theme_manager.BuiltInThemes) do
        table.insert(ThemesArray, Name)
    end
    table.sort(ThemesArray, function(a, b)
        return theme_manager.BuiltInThemes[a][1] < theme_manager.BuiltInThemes[b][1]
    end)

    theme_group:AddDivider()
    theme_group:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })
    theme_group:AddButton('Set as default', function()
        theme_manager:SaveDefault(options.ThemeManager_ThemeList.Value)
        library:Notify({ Title = 'Theme', Description = string.format('Set default theme to %q', options.ThemeManager_ThemeList.Value), Time = 3 })
    end)

    options.ThemeManager_ThemeList:OnChanged(function()
        theme_manager:ApplyTheme(options.ThemeManager_ThemeList.Value)
    end)

    local function UpdateTheme()
        theme_manager:ThemeUpdate()
    end
    options.BackgroundColor:OnChanged(UpdateTheme)
    options.MainColor:OnChanged(UpdateTheme)
    options.AccentColor:OnChanged(UpdateTheme)
    options.OutlineColor:OnChanged(UpdateTheme)

    theme_manager:LoadDefault()
    theme_manager.AppliedToTab = true

    if type(args.after_build) == 'function' then
        args.after_build(tab, group)
    end

    local function ResolveMenuKeybindValue()
        local option = options.MenuKeybind
        if option then
            local value = option.Value
            if type(value) == 'string' and value ~= '' then
                return value
            end
        end

        return persisted_defaults.menu_keybind or defaults.menu_keybind or 'LeftControl'
    end

    local function persist_ui_settings()
        script_paths.save_ui_settings({
            auto_show = not toggles[ids.auto_show].Value,
            show_notification = toggles[ids.show_notification].Value,
            show_keybind_states = toggles[ids.show_keybind_states].Value,
            auto_execute_on_teleport = toggles[ids.auto_execute_on_teleport].Value,
            auto_load_config = toggles[ids.auto_load_config].Value,
            auto_save_config = toggles[ids.auto_save_config].Value,
            load_config_name = ResolveConfigSelectionValue(ids.load_config_name, persisted_defaults.load_config_name),
            menu_keybind = persist_menu_keybind and ResolveMenuKeybindValue() or defaults.menu_keybind or 'LeftControl',
        }, defaults)
    end

    local function sync_keybind_visibility()
        library.KeybindFrame.Visible = toggles[ids.show_keybind_states].Value
    end

    local function should_queue_on_teleport()
        if toggles[ids.auto_execute_on_teleport].Value then
            return true
        end

        if type(is_queue_on_teleport_forced) == 'function' then
            local ok, forced = pcall(is_queue_on_teleport_forced)
            if ok and forced then
                return true
            end
        end

        return false
    end

    local function sync_queue_on_teleport()
        if should_queue_on_teleport() then
            -- notify at wire-up time (not teleport time) so the user learns
            -- immediately that Auto Execute cannot work on this executor
            if not __kicia_hook_genv.KiciaHookCaps.gate('Auto Execute', 'queue_on_teleport') then
                return
            end
            if queue_on_teleport_connection then return end
            queue_on_teleport_connection = local_player.OnTeleport:Connect(function(state)
                if state == Enum.TeleportState.InProgress then
                    queue_loader()
                end
            end)
        else
            disconnect_queue_on_teleport()
        end
    end

    local function BindAutoSaveObject(id, object)
        if type(object) ~= 'table' or not AUTO_SAVE_SUPPORTED_TYPES[object.Type] then
            return
        end
        if save_manager and save_manager.Ignore and save_manager.Ignore[id] then
            return
        end

        if auto_save_wrappers[object] == object.Changed then
            return
        end

        local previous_changed = object.Changed
        object.Changed = function(...)
            if type(previous_changed) == 'function' then
                previous_changed(...)
            end

            settings:schedule_auto_save(id)
        end
        auto_save_wrappers[object] = object.Changed
    end

    function settings:get_config_names()
        local copy = {}
        for _, config_name in ipairs(config_names) do
            table.insert(copy, ResolveConfigFileName(config_name))
        end
        return copy
    end

    function settings:resolve_save_config_name()
        return ResolveConfigFileName(ResolveConfigSelectionValue(ids.load_config_name, persisted_defaults.load_config_name))
    end

    function settings:resolve_load_config_name()
        return settings:resolve_save_config_name()
    end

    function settings:should_auto_save_config()
        return toggles[ids.auto_save_config].Value and settings:resolve_save_config_name() ~= nil
    end

    function settings:schedule_auto_save(id)
        if shutting_down or config_load_suppression_count > 0 or not settings:should_auto_save_config() then
            return
        end

        auto_save_token = auto_save_token + 1
        local token = auto_save_token
        task.delay(AUTO_SAVE_DEBOUNCE_SECONDS, function()
            if shutting_down or token ~= auto_save_token or config_load_suppression_count > 0 or not settings:should_auto_save_config() then
                return
            end

            if on_save then
                on_save(settings:resolve_save_config_name())
            end
        end)
    end

    function settings:refresh_auto_save_bindings()
        for id, toggle in pairs(toggles) do
            BindAutoSaveObject(id, toggle)
        end
        for id, option in pairs(options) do
            BindAutoSaveObject(id, option)
        end
    end

    function settings:with_config_load_suspended(callback)
        config_load_suppression_count = config_load_suppression_count + 1
        local ok, result, err = pcall(callback)
        task.delay(1, function()
            config_load_suppression_count = math.max(0, config_load_suppression_count - 1)
        end)

        if not ok then
            error(result, 2)
        end

        return result, err
    end

    function settings:register_callbacks()
        toggles[ids.auto_show]:OnChanged(persist_ui_settings)
        toggles[ids.show_notification]:OnChanged(persist_ui_settings)
        toggles[ids.show_keybind_states]:OnChanged(function()
            persist_ui_settings()
            sync_keybind_visibility()
        end)
        toggles[ids.auto_execute_on_teleport]:OnChanged(function()
            persist_ui_settings()
            sync_queue_on_teleport()
        end)
        toggles[ids.auto_load_config]:OnChanged(persist_ui_settings)
        toggles[ids.auto_save_config]:OnChanged(persist_ui_settings)
        options[ids.load_config_name]:OnChanged(persist_ui_settings)
        if persist_menu_keybind then
            options.MenuKeybind:OnChanged(persist_ui_settings)
        end
        settings:refresh_auto_save_bindings()
        if not auto_save_binding_loop_started then
            auto_save_binding_loop_started = true
            task.spawn(function()
                while not shutting_down do
                    task.wait(1)
                    settings:refresh_auto_save_bindings()
                end
            end)
        end
    end

    function settings:sync_queue_on_teleport()
        sync_queue_on_teleport()
    end

    function settings:should_auto_load_config()
        return toggles[ids.auto_load_config].Value and settings:resolve_load_config_name() ~= nil
    end

    function settings:shutdown_for_unload()
        if shutting_down then
            return
        end

        shutting_down = true

        for toggle_id, toggle in pairs(toggles) do
            if not preserved_ids[toggle_id]
                and type(toggle) == 'table'
                and type(toggle.SetValue) == 'function'
                and type(toggle.Value) == 'boolean'
                and toggle.Value == true
            then
                pcall(toggle.SetValue, toggle, false)
            end
        end

        disconnect_queue_on_teleport()
    end

    function settings:reconcile_loaded_ui_settings()
        persist_ui_settings()
        sync_keybind_visibility()
        sync_queue_on_teleport()
        settings:refresh_auto_save_bindings()
        theme_manager:LoadDefault()
    end

    function settings:notify_loaded(duration)
        if toggles[ids.show_notification].Value then
            local menuKeybindValue = ResolveMenuKeybindValue()
            library:Notify({ Title = 'Loaded', Description = 'Loaded - ' .. menuKeybindValue .. ' to toggle menu', Time = duration or 5 })
        end
    end

    return settings
end

return module
end

__kicia_hook_shared.game_bootstrap = function()
local module = {}

local function elevate_ui_identity()
    if type(__KiciaHookElevateIdentity) == 'function' then
        __KiciaHookElevateIdentity()
    elseif type(setthreadidentity) == 'function' then
        pcall(setthreadidentity, 8)
    end
end

function module.create_window(args)
    elevate_ui_identity()
    local ui_settings = args.script_paths.load_ui_settings(args.ui_settings_defaults)

    elevate_ui_identity()
    return args.library:CreateWindow({
        Position = args.position,
        Title = args.title,
        Center = args.center,
        AutoShow = ui_settings.auto_show == true,
        DisableSearch = true,
        Footer = args.footer or 'open source',
        Icon = args.icon,
        IconSize = args.icon_size,
    })
end

function module.create_standard_shared_ui(args)
    elevate_ui_identity()
    local shared_ui
    local defaults = args.defaults or {
        auto_show = false,
        show_notification = true,
        show_keybind_states = false,
        auto_execute_on_teleport = false,
        auto_load_config = true,
        auto_save_config = true,
        load_config_name = 'Legit',
    }

    local function reconcile_loaded_state()
        if args.reconcile_loaded_state then
            args.reconcile_loaded_state()
        end
    end

    elevate_ui_identity()
    shared_ui = args.ui_settings.new({
        window = args.window,
        library = args.library,
        theme_manager = args.theme_manager,
        script_paths = args.script_paths,
        save_manager = args.save_manager,
        current_config_name = args.current_config_name,
        config_names = args.config_names,
        use_global_config_names = args.use_global_config_names,
        resolve_config_name = args.resolve_config_name,
        toggles = args.toggles,
        options = args.options,
        local_player = args.local_player,
        defaults = defaults,
        persist_menu_keybind = args.persist_menu_keybind,
        extra_ignore_ids = args.extra_ignore_ids,
        queue_loader = function()
            -- args.queue_on_teleport is Header's safe no-op capture when the
            -- executor lacks the real function; gate so the reload silently
            -- not happening comes with an explanation
            if __kicia_hook_genv.KiciaHookCaps.gate('Auto Execute', 'queue_on_teleport') then
                args.queue_on_teleport(args.script_paths.queue_on_teleport_script())
            end
        end,
        on_save = function(config_name)
            local save_name = shared_ui and shared_ui.resolve_save_config_name and shared_ui:resolve_save_config_name() or args.current_config_name
            if config_name then
                save_name = config_name
            end
            if args.before_save then
                args.before_save(shared_ui, save_name)
            end
            local ok, err = args.save_manager:Save(save_name)
            if args.on_save then
                args.on_save(shared_ui, save_name)
            end
            return ok, err
        end,
        on_load_saved = function()
            local load_name = shared_ui and shared_ui.resolve_load_config_name and shared_ui:resolve_load_config_name() or args.current_config_name
            if shared_ui and shared_ui.with_config_load_suspended then
                shared_ui:with_config_load_suspended(function()
                    args.save_manager:Load(load_name)
                end)
            else
                args.save_manager:Load(load_name)
            end
            shared_ui:reconcile_loaded_ui_settings()
            reconcile_loaded_state()
            if args.on_load_saved then
                args.on_load_saved(shared_ui, load_name)
            end
        end,
        on_load_default = function()
            local save_name = shared_ui and shared_ui.resolve_save_config_name and shared_ui:resolve_save_config_name() or args.current_config_name
            if shared_ui and shared_ui.with_config_load_suspended then
                shared_ui:with_config_load_suspended(function()
                    if type(args.reset_config_to_default) == 'function' then
                        args.save_manager:Load(args.default_config_name)
                        args.reset_config_to_default(shared_ui, save_name)
                        args.save_manager:Load(save_name)
                    else
                        args.save_manager:Load(args.default_config_name)
                        args.save_manager:Save(save_name)
                    end
                end)
            else
                if type(args.reset_config_to_default) == 'function' then
                    args.save_manager:Load(args.default_config_name)
                    args.reset_config_to_default(shared_ui, save_name)
                    args.save_manager:Load(save_name)
                else
                    args.save_manager:Load(args.default_config_name)
                    args.save_manager:Save(save_name)
                end
            end
            shared_ui:reconcile_loaded_ui_settings()
            reconcile_loaded_state()
            if args.on_load_default then
                args.on_load_default(shared_ui, save_name)
            end
        end,
    })

    return shared_ui
end

function module.prepare_setup(args)
    elevate_ui_identity()
    local sm = args.save_manager
    local default_name = args.default_config_name

    if not isfile(args.script_paths.config_path(default_name)) then
        sm:Save(default_name)
    end
    if args.shared_ui and args.shared_ui.get_config_names then
        for _, config_name in ipairs(args.shared_ui:get_config_names()) do
            if not isfile(args.script_paths.config_path(config_name)) then
                local ok = nil
                if type(args.reset_config_to_default) == 'function' then
                    ok = args.reset_config_to_default(args.shared_ui, config_name)
                end
                if ok == false or ok == nil then
                    sm:Save(config_name)
                end
            end
        end
    end

    if not args.defer_load then
        module.load_config(args)
    end

    args.shared_ui:register_callbacks()
    args.shared_ui:reconcile_loaded_ui_settings()
end

function module.load_config(args)
    elevate_ui_identity()
    local sm = args.save_manager
    local current = args.current_config_name
    local default_name = args.default_config_name
    local shared_ui = args.shared_ui

    local function load_config_name(config_name)
        if shared_ui and shared_ui.with_config_load_suspended then
            return shared_ui:with_config_load_suspended(function()
                return sm:Load(config_name)
            end)
        end

        return sm:Load(config_name)
    end

    if shared_ui and shared_ui.should_auto_load_config and shared_ui:should_auto_load_config() then
        local load_name = shared_ui and shared_ui.resolve_load_config_name and shared_ui:resolve_load_config_name() or current
        local ok = load_config_name(load_name)
        if not ok then
            load_config_name(default_name)
        end
    else
        load_config_name(default_name)
    end
end

return module
end

__kicia_hook_shared.rivals_ragebot_kernel = function()
-- RivalsRagebotKernel.lua
-- The ragebot, lifted verbatim out of the RIVALS feature module into its own
-- shared module so it can be read (and lifted out) on its own. It runs as plain
-- client Lua on a per-frame loop.
--
-- init(ctx) is called once from the RIVALS module, at the point the old IIFE
-- ran. It is handed the seven names the block reads from outer scope: four
-- stable tables by reference (RivalsRuntimeBridge / Options / Toggles /
-- FighterDataCache), two respawn-reassigned handles via live getters (GetChar /
-- GetRoot), and the global environment (Genv). Genv stays an explicit ctx field
-- so the kernel works wherever it is emitted.
--
-- It fires the fighter combat remote directly and uses metatable / getgc / debug
-- surfaces. That is Kicia's original method, reproduced rather than softened.
return {
    init = function(ctx)
        local RivalsRuntimeBridge = ctx.RivalsRuntimeBridge
        local Options = ctx.Options
        local Toggles = ctx.Toggles
        local FighterDataCache = ctx.FighterDataCache
        local GetChar = ctx.GetChar
        local GetRoot = ctx.GetRoot
        local __kicia_hook_genv = ctx.Genv
        -- __KICIA_RAGEBOT_BEGIN__
            local KiciaRagebot = {}
            RivalsRuntimeBridge.KiciaRagebot = KiciaRagebot

            local RunService = game:GetService('RunService')
            local HttpServiceRB = cloneref(game:GetService('HttpService'))
            local CollectionServiceRB = cloneref(game:GetService('CollectionService'))
            local PlayersRB = cloneref(game:GetService('Players'))
            local ReplicatedStorageRB = cloneref(game:GetService('ReplicatedStorage'))
            local WorkspaceRB = workspace
            local LPRB = PlayersRB.LocalPlayer
            local rbRandom = Random.new()

            -- Executor capability shims (all feature-detected live on build 17625359962).
            local rbSetHidden = sethiddenproperty
            local rbSetFFlag = (type(setfflag) == 'function') and setfflag or sfflag
            local rbSetThreadIdentity = setthreadidentity
            local rbGetThreadIdentity = getthreadidentity

            -- Clean FireServer stolen off a throwaway RemoteEvent (matches the script's No Spread
            -- calling convention: positional call, never :FireServer()).
            local rbCleanFireEvent = Instance.new('RemoteEvent')
            local rbFireServerNative = clonefunction(rbCleanFireEvent.FireServer)

            local function rbRawWrite(obj, key, value)
                if typeof(obj) == 'Instance' then
                    if not pcall(rbSetHidden, obj, key, value) then
                        pcall(function() obj[key] = value end)
                    end
                else
                    pcall(rawset, obj, key, value)
                end
            end

            -- ---- settings (read live from the Obsidian controls; Kicia defaults as fallback) ----
            local function optValue(id, default)
                local o = Options and Options[id]
                if o and o.Value ~= nil then
                    return o.Value
                end
                return default
            end
            local function togValue(id, default)
                local t = Toggles and Toggles[id]
                if t and t.Value ~= nil then
                    return t.Value == true
                end
                return default
            end
            local Setting = {
                Stability = function() return optValue('P8S4S1', 0.15) end,
                ShootFrames = function() return optValue('P8S4S2', 1) end,
                PrioritizeHackers = function() return togValue('P8S4T4', false) end,
                WeaponPrimary = function() return togValue('P8S4T5', true) end,
                WeaponSecondary = function() return togValue('P8S4T6', true) end,
                WeaponMelee = function() return togValue('P8S4T7', true) end,
                OnEmpty = function() return optValue('P8S4D1', 'SwapOrReload') end,
                EvasionMode = function() return optValue('P8S4D2', 'Random') end,
                TranslocateOffset = function() return optValue('P8S4S3', -5) end,
                RandomBaseRadius = function() return optValue('P8S4S4', 100) end,
                RandomRadiusFactor = function() return optValue('P8S4S5', 0.5) end,
                RandomAnchorFromCharacter = function() return togValue('P8S4T8', false) end,
                -- ProjectileBreaker has no Kicia UI; RepositionInterval keeps Kicia's default.
                RepositionInterval = function() return 0.3 end,
            }
            -- Kicia's ProjectileBreaker depth constants (config present in Kicia; no UI slider).
            local PB_DEPTH_FORWARD = { Min = 0, Max = 4 }
            local PB_DEPTH_FORWARD_FREQ = 5
            local PB_DEPTH_UP = { Min = 0, Max = 5.5 }
            local PB_DEPTH_UP_FREQ = 5
            local PB_FALLBACK_BASE_RADIUS = 100
            local PB_FALLBACK_RADIUS_FACTOR = 0.5
            local PB_FALLBACK_ANCHOR_FROM_CHARACTER = false

            -- ---- self-contained game-handle resolution -----------------------------------
            local function findChild(root, ...)
                local node = root
                for _, name in ipairs({ ... }) do
                    if not node then
                        return nil
                    end
                    node = node:FindFirstChild(name)
                end
                return node
            end

            local cachedEnumLibrary = nil
            local function resolveEnumLibrary()
                if cachedEnumLibrary then
                    return cachedEnumLibrary
                end
                local mod = findChild(ReplicatedStorageRB, 'Modules', 'EnumLibrary')
                if not mod then
                    return nil
                end
                local ok, lib = pcall(require, mod)
                if ok and type(lib) == 'table' then
                    cachedEnumLibrary = lib
                    return lib
                end
                return nil
            end
            local function enc(name)
                local lib = resolveEnumLibrary()
                if not lib then
                    return nil
                end
                local ok, token = pcall(lib.ToEnum, lib, name)
                if ok then
                    return token
                end
                return nil
            end

            local cachedUseItemRemote = nil
            local function resolveUseItemRemote()
                if cachedUseItemRemote and cachedUseItemRemote.Parent then
                    return cachedUseItemRemote
                end
                local remote = findChild(ReplicatedStorageRB, 'Remotes', 'Replication', 'Fighter', 'UseItem')
                if remote and remote:IsA('RemoteEvent') then
                    cachedUseItemRemote = cloneref(remote)
                    return cachedUseItemRemote
                end
                return nil
            end
            local cachedUpdateStateRemote = nil
            local function resolveUpdateStateRemote()
                if cachedUpdateStateRemote and cachedUpdateStateRemote.Parent then
                    return cachedUpdateStateRemote
                end
                local remote = findChild(ReplicatedStorageRB, 'Remotes', 'Replication', 'Fighter', 'UpdateState')
                if remote and remote:IsA('RemoteEvent') then
                    cachedUpdateStateRemote = cloneref(remote)
                    return cachedUpdateStateRemote
                end
                return nil
            end
            local cachedCameraRotationRemote = nil
            local function resolveCameraRotationRemote()
                if cachedCameraRotationRemote and cachedCameraRotationRemote.Parent then
                    return cachedCameraRotationRemote
                end
                local remote = findChild(ReplicatedStorageRB, 'Remotes', 'Replication', 'Fighter', 'UpdateCameraRotation')
                if remote and remote:IsA('RemoteEvent') then
                    cachedCameraRotationRemote = cloneref(remote)
                    return cachedCameraRotationRemote
                end
                return nil
            end
            local function requireModuleRB(name)
                local mod = findChild(ReplicatedStorageRB, 'Modules', name)
                if not mod then
                    return nil
                end
                local ok, result = pcall(require, mod)
                if ok then
                    return result
                end
                return nil
            end

            -- FighterController singleton (carries LocalFighter + Objects) + its prototype
            -- (carries _CameraReplicationLoop).  Cached with cheap revalidation.
            local cachedFighterController = nil
            local function resolveFighterController()
                local cc = cachedFighterController
                if type(cc) == 'table' and rawget(cc, 'LocalFighter') ~= nil then
                    return cc
                end
                for _, m in ipairs(getgc(true)) do
                    if type(m) == 'table' and rawget(m, 'LocalFighter') ~= nil and rawget(m, 'Objects') ~= nil then
                        cachedFighterController = m
                        return m
                    end
                end
                return nil
            end
            local function resolveLocalFighter()
                local controller = resolveFighterController()
                return controller and rawget(controller, 'LocalFighter') or nil
            end
            local cachedFCPrototype = nil
            local function resolveFighterControllerPrototype()
                if type(cachedFCPrototype) == 'table' and rawget(cachedFCPrototype, '_CameraReplicationLoop') ~= nil then
                    return cachedFCPrototype
                end
                local controller = resolveFighterController()
                if controller then
                    local mt = getmetatable(controller)
                    local proto = mt and rawget(mt, '__index') or nil
                    if type(proto) == 'table' and rawget(proto, '_CameraReplicationLoop') ~= nil then
                        cachedFCPrototype = proto
                        return proto
                    end
                end
                for _, m in ipairs(getgc(true)) do
                    if type(m) == 'table' then
                        local idx = rawget(m, '__index')
                        if type(idx) == 'table' and rawget(idx, '_CameraReplicationLoop') ~= nil then
                            cachedFCPrototype = idx
                            return idx
                        end
                    end
                end
                return nil
            end

            -- ---- firing transport (Kicia t157/t16, lines 73511 / 88523 / 88535) ----------
            local function fireGun(objectId, isRaycast, aim1, aim2, hitboxHead, extra)
                local remote = resolveUseItemRemote()
                local token = enc('StartShooting')
                if not remote or not token or not objectId then
                    return
                end
                local inner = { ['\0'] = aim1, ['\1'] = aim2, ['\2'] = hitboxHead, ['\3'] = extra }
                local payload
                if isRaycast then
                    payload = { ['\1'] = inner, ['\2'] = true }
                else
                    payload = { ['\1'] = inner }
                end
                rbFireServerNative(remote, objectId, token, payload, nil)
            end
            local function fireMeleeAttack(objectId, a, b, c, d)
                local remote = resolveUseItemRemote()
                local token = enc('StartShooting')
                local anim = enc('AttackAnimation1')
                if not remote or not token or not anim or not objectId then
                    return
                end
                rbFireServerNative(remote, objectId, token, { ['\1'] = { ['\0'] = a, ['\1'] = b, ['\2'] = c, ['\3'] = d }, ['\2'] = anim }, nil)
            end
            local function fireMeleeHeavy(objectId, a, b, c, d)
                local remote = resolveUseItemRemote()
                local token = enc('StartAiming') -- Kicia HeavyAttackEncoded uses StartAiming
                local anim = enc('HeavyAttackAnimation1')
                if not remote or not token or not anim or not objectId then
                    return
                end
                rbFireServerNative(remote, objectId, token, { ['\1'] = { ['\0'] = a, ['\1'] = b, ['\2'] = c, ['\3'] = d }, ['\2'] = anim }, nil)
            end
            local function fireReload(objectId)
                local remote = resolveUseItemRemote()
                local start = enc('StartReloading')
                local reload = enc('Reload')
                if not remote or not start or not reload or not objectId then
                    return
                end
                rbFireServerNative(remote, objectId, start, { ['\1'] = reload, ['\2'] = reload }, nil)
            end

            -- ---- raw ClientItem helpers --------------------------------------------------
            local function itemObjectId(item)
                local data = rawget(item, 'Data')
                return data and rawget(data, 'ObjectID') or nil
            end
            local function itemInfo(item)
                return rawget(item, 'Info')
            end
            local function itemType(item)
                local info = itemInfo(item)
                return info and rawget(info, 'Type') or nil
            end
            local function itemIsRaycast(item)
                local info = itemInfo(item)
                return info and rawget(info, 'IsRaycast') == true
            end
            local function itemName(item)
                return rawget(item, 'Name') or rawget(item, 'ItemName')
            end
            local function itemAmmo(item)
                local data = rawget(item, 'Data')
                local ammo = data and rawget(data, 'Ammo')
                return type(ammo) == 'number' and ammo or 0
            end
            local function itemAmmoReserve(item)
                local data = rawget(item, 'Data')
                local reserve = data and rawget(data, 'AmmoReserve')
                if type(reserve) ~= 'number' then
                    return math.huge
                end
                return reserve
            end
            -- Kicia t157:IsReloading (lines 73560-73573): _reload_cooldown OR _shoot_cooldown_no_ammo.
            local function itemIsReloading(item)
                local now = tick()
                local cooldown = rawget(item, '_reload_cooldown')
                if type(cooldown) == 'number' and now < cooldown then
                    return true
                end
                local noAmmoCooldown = rawget(item, '_shoot_cooldown_no_ammo')
                return type(noAmmoCooldown) == 'number' and now < noAmmoCooldown
            end
            -- Kicia t157:IsMagFull (line 73575): Info.MaxAmmo <= current ammo.
            local function itemIsMagFull(item)
                local info = itemInfo(item)
                local maxAmmo = info and rawget(info, 'MaxAmmo')
                return type(maxAmmo) == 'number' and maxAmmo <= itemAmmo(item)
            end
            -- Kicia t157:IsEquipped (line 73501): the item's own IsEquipped field - the same
            -- read the game's Items modules (Minigun, Riot Shield) use. The fighter-side
            -- Data.EquippedItemID compare it replaced never matched Kicia and is gone.
            local function itemIsEquipped(item)
                return rawget(item, 'IsEquipped')
            end
            -- Kicia t157:Equip (lines 73493-73499): no-op when equipped, then
            -- item.ClientFighter:EquipItem(index). ClientFighter lives on the ITEM (the
            -- LocalFighter IS a ClientFighter and has no such field; live-verified),
            -- and index is the fighter's Items-table key - the exact value the game's
            -- QuickAttackSystem passes (EquipItem(table.find(ClientFighter.Items, item))).
            local function equipItem(item, index)
                if itemIsEquipped(item) then
                    return
                end
                local clientFighter = rawget(item, 'ClientFighter')
                if clientFighter and index and type(clientFighter.EquipItem) == 'function' then
                    pcall(function() clientFighter:EquipItem(index) end)
                end
            end
            -- Kicia t157:Reload guard (lines 73539-73546).
            local function reloadItem(item)
                if itemIsReloading(item) or itemAmmoReserve(item) <= 0 or itemIsMagFull(item) then
                    return
                end
                fireReload(itemObjectId(item))
            end

            -- ---- spoofed aim payload tables (hitscan strategy, lines 40519-40551) ---------
            local NEG_HUGE = -9e37
            local function buildAim(base, pitch, oy, oz)
                return {
                    ['\0'] = base['\0'], ['\1'] = base['\1'], ['\2'] = base['\2'],
                    ['\3'] = pitch, ['\4'] = oy, ['\5'] = oz,
                }
            end
            local AIM_ABOVE_ORIGIN = { ['\0'] = NEG_HUGE, ['\1'] = 0, ['\2'] = 0 }         -- t91
            local AIM_ABOVE_END = { ['\0'] = 0, ['\1'] = -90000000, ['\2'] = 0 }           -- t92
            local AIM_BELOW_ORIGIN = { ['\0'] = NEG_HUGE, ['\1'] = 0, ['\2'] = 0 }         -- t93
            local AIM_BELOW_END = { ['\0'] = 0, ['\1'] = 90000000, ['\2'] = 0 }            -- t94
            local AIM_EXTRA = { ['\0'] = 0, ['\1'] = 1, ['\2'] = 0, ['\3'] = 0, ['\4'] = 0, ['\5'] = 0 } -- t95
            local OFFSET_ABOVE = Vector3.new(0, -0.7, 0.05)                                -- v230/v138
            local OFFSET_BELOW = Vector3.new(0, -3.85, 0.05)                               -- v231/v139
            local PITCH_ABOVE = -math.pi / 2                                               -- v140
            local PITCH_BELOW = math.pi / 2                                                -- v141

            -- Riot-Shield-aware above/below classifier (Kicia ia(), lines 151550-151570).
            -- "None" for shield-less targets (common case) folds to Above.  Enemy
            -- itemObserver/camera are best-effort on this build; shield-less path is exact.
            local function classifyAboveBelow(target)
                local obs = target and target.itemObserver
                if obs then
                    local ok, result = pcall(function()
                        local equipped = obs:GetEquippedItem()
                        if equipped ~= nil and equipped.name == 'Riot Shield' then
                            local pitch = math.deg(target:GetCameraRotation().X)
                            if 22 < pitch and pitch < 91 then
                                return 'Below'
                            end
                            return 'Above'
                        end
                        for _, it in obs:GetItems() do
                            if it.name == 'Riot Shield' then
                                local pitch = math.deg(target:GetCameraRotation().X)
                                if 315 < pitch and pitch < 360 or 0 < pitch and pitch < 91 then
                                    return 'Above'
                                end
                                return 'Below'
                            end
                        end
                        return 'None'
                    end)
                    if ok and result then
                        return result
                    end
                end
                return 'None'
            end
            local function isAbove(target)
                return classifyAboveBelow(target) ~= 'Below'
            end

            -- ---- root virtualization (Kicia t201, lines 145034-145080) -------------------
            local RootDesync = {}
            RootDesync.__index = RootDesync
            function RootDesync.new(rootPart)
                local self = setmetatable({
                    _rootPart = rootPart,
                    _boundId = HttpServiceRB:GenerateGUID(false),
                    _oldCFrame = rootPart.CFrame,
                    _cframe = nil,
                }, RootDesync)
                RunService:BindToRenderStep(self._boundId, Enum.RenderPriority.First.Value, function()
                    self:_RenderStepUpdate()
                end)
                return self
            end
            function RootDesync:_RenderStepUpdate()
                local old = self._oldCFrame
                if old ~= nil then
                    self._rootPart.CFrame = old
                    self._oldCFrame = nil
                end
            end
            function RootDesync:SetServerCFrame(cf)
                self._cframe = cf
            end
            function RootDesync:GetServerCFrame()
                return self._cframe or self._rootPart.CFrame
            end
            function RootDesync:GetClientCFrame()
                return self._oldCFrame or self._rootPart.CFrame
            end
            function RootDesync:HeartbeatUpdate()
                local cf = self._cframe
                if cf ~= nil then
                    self._oldCFrame = self._rootPart.CFrame
                    self._rootPart.CFrame = cf
                end
            end
            function RootDesync:Destroy()
                pcall(function() RunService:UnbindFromRenderStep(self._boundId) end)
            end

            -- ---- view-angle driver (Kicia t1141, lines 196889-197137) --------------------
            -- Hooks ClientFighterCharacterJoints.Update + FighterController._CameraReplicationLoop
            -- to inject a spoofed CameraRotationRaw so the replicated camera does not stare at the
            -- void.  Two deobfuscator artifacts are reconstructed to their unambiguous intent
            -- (recorded as anomalies A/B/C while recovering this function):
            --   * encodeCameraRotation (Vector2->2 bytes) and encodeSingle (scalar->1 byte) were
            --     collapsed onto one key in the dump; both restored from their recovered bodies.
            --   * _Resolve's priority loop was erased (junk filler); reconstructed as "winner =
            --     the highest numeric-priority live slot" (the ragebot uses one slot, priority 20).
            local function encodeSingle(n)
                if n == n then
                    return utf8.char(math.clamp(math.floor(n % (2 * math.pi) / math.pi / 2 * 256 + 0.5), 0, 255))
                end
                return utf8.char(0)
            end
            local function encodeCameraRotation(v)
                if v == v then
                    return utf8.char(math.clamp(math.floor(v.X % (2 * math.pi) / math.pi / 2 * 256 + 0.5), 0, 255))
                        .. utf8.char(math.clamp(math.floor(v.Y % (2 * math.pi) / math.pi / 2 * 256 + 0.5), 0, 255))
                end
                return utf8.char(0) .. utf8.char(0)
            end
            local function decodeSingle(s)
                return utf8.codepoint(s) * math.pi * 2 / 256
            end
            local function anglesToRaw(a)
                if a.kind == 'Unnormalized' then
                    return Vector2.new(a.pitch, 0) * math.pi * 2 / 256
                end
                return Vector2.new(decodeSingle(encodeSingle(math.rad(a.pitch))), decodeSingle(encodeSingle(math.rad(a.yaw))))
            end
            local function anglesToEncoded(a)
                if a.kind == 'Unnormalized' then
                    return utf8.char(math.clamp(a.pitch, 0, 255)) .. utf8.char(math.clamp(a.yaw, 0, 255))
                end
                return encodeSingle(math.rad(a.pitch)) .. encodeSingle(math.rad(a.yaw))
            end

            local ViewAngleDriver = {}
            ViewAngleDriver.__index = ViewAngleDriver
            function ViewAngleDriver.new()
                return setmetatable({
                    _slots = {},
                    _winning = nil,
                    _fullySuppressed = false,
                    _dirty = false,
                }, ViewAngleDriver)
            end
            function ViewAngleDriver:_Resolve()
                local best, winner = nil, nil
                for priority, value in pairs(self._slots) do
                    if value ~= nil and (best == nil or priority > best) then
                        best = priority
                        winner = value
                    end
                end
                self._winning = winner
            end
            function ViewAngleDriver:_LoadJointsHook()
                if self._jointsRestore ~= nil then
                    return true
                end
                local joints = requireModuleRB('ClientFighterCharacterJoints')
                local original = joints and rawget(joints, 'Update') or nil
                if not joints or original == nil then
                    return false
                end
                local driver = self
                local function hooked(jointsSelf, a, b)
                    local cfc = rawget(jointsSelf, 'ClientFighterCharacter')
                    local cf = cfc and rawget(cfc, 'ClientFighter') or nil
                    if cf == nil then
                        return original(jointsSelf, a, b)
                    end
                    if rawget(cf, 'IsLocalPlayer') == true then
                        local winning = driver._winning
                        if winning ~= nil then
                            rbRawWrite(b, 'CameraRotationRaw', anglesToRaw(winning))
                        end
                    end
                    return original(jointsSelf, a, b)
                end
                rawset(joints, 'Update', hooked)
                self._jointsRestore = { joints = joints, original = original }
                return true
            end
            function ViewAngleDriver:_LoadReplicationHook()
                if self._replicationRestore ~= nil then
                    return true
                end
                local proto = resolveFighterControllerPrototype()
                local instance = resolveFighterController()
                local loop = proto and rawget(proto, '_CameraReplicationLoop') or nil
                if not proto or not instance or loop == nil then
                    return false
                end
                local utilIndex, util
                local ok, upvalues = pcall(debug.getupvalues, loop)
                if ok and type(upvalues) == 'table' then
                    for index, value in pairs(upvalues) do
                        if type(value) == 'table' then
                            local vmt = getmetatable(value)
                            local vidx = vmt and rawget(vmt, '__index') or nil
                            if vidx ~= nil and rawget(vidx, 'EncodeCameraRotation') ~= nil then
                                util = value
                                utilIndex = index
                                break
                            end
                        end
                    end
                end
                if utilIndex == nil or util == nil then
                    return false
                end
                local driver = self
                local replacement = {}
                function replacement.EncodeCameraRotation(_, raw)
                    if next(driver._slots) == nil and not driver._fullySuppressed then
                        return encodeCameraRotation(raw)
                    end
                    rbRawWrite(instance, '_replication_stopped', false)
                    local last = rawget(instance, '_last_encoded_camera_rotation')
                    if not last then
                        last = encodeCameraRotation(raw)
                    end
                    return last
                end
                if not pcall(debug.setupvalue, loop, utilIndex, replacement) then
                    return false
                end
                self._replicationRestore = { loop = loop, utilityIndex = utilIndex, utility = util }
                return true
            end
            function ViewAngleDriver:SendViewAngles(priority, value)
                if self._slots[priority] == value then
                    return
                end
                self._slots[priority] = value
                self._dirty = true
                self:_Resolve()
                if self._winning == nil then
                    return
                end
                if self:_LoadJointsHook() then
                    self:_LoadReplicationHook()
                end
            end
            function ViewAngleDriver:Flush()
                if not self._dirty or self._fullySuppressed then
                    return
                end
                local winning = self._winning
                if winning == nil then
                    self._dirty = false
                    return
                end
                self._dirty = false
                local remote = resolveCameraRotationRemote()
                if remote then
                    rbFireServerNative(remote, anglesToEncoded(winning), nil)
                end
            end
            function ViewAngleDriver:ClearAll()
                table.clear(self._slots)
                self._winning = nil
                self._dirty = false
            end
            function ViewAngleDriver:Destroy()
                local jointsRestore = self._jointsRestore
                if jointsRestore ~= nil then
                    self._jointsRestore = nil
                    pcall(rawset, jointsRestore.joints, 'Update', jointsRestore.original)
                end
                local replicationRestore = self._replicationRestore
                if replicationRestore ~= nil then
                    self._replicationRestore = nil
                    pcall(debug.setupvalue, replicationRestore.loop, replicationRestore.utilityIndex, replicationRestore.utility)
                end
            end

            -- ---- character controller wrapper (Kicia t4, lines 25419-25541) --------------
            local CharacterController = {}
            CharacterController.__index = CharacterController
            function CharacterController.new(rootPart)
                return setmetatable({
                    _rootDesync = RootDesync.new(rootPart),
                    _viewAngleDriver = ViewAngleDriver.new(),
                }, CharacterController)
            end
            function CharacterController:SetServerCFrame(cf)
                if self._rootDesync then
                    self._rootDesync:SetServerCFrame(cf)
                end
            end
            function CharacterController:GetClientCFrame()
                return self._rootDesync and self._rootDesync:GetClientCFrame() or nil
            end
            function CharacterController:SendViewAngles(priority, value)
                self._viewAngleDriver:SendViewAngles(priority, value)
            end
            function CharacterController:HeartbeatUpdate()
                if self._rootDesync then
                    self._rootDesync:HeartbeatUpdate()
                end
                self._viewAngleDriver:Flush()
            end
            function CharacterController:Destroy()
                self._viewAngleDriver:ClearAll()
                self._viewAngleDriver:Destroy()
                if self._rootDesync then
                    self._rootDesync:Destroy()
                    self._rootDesync = nil
                end
            end

            -- ---- forced-crouch state hook (Kicia t192, lines 12022-12081, simplified) -----
            -- Kicia additionally installs a dummy _UpdateServerState to suppress the game's
            -- own conflicting sends; the essential forcing is firing UpdateState directly.
            local StateHook = {}
            StateHook.__index = StateHook
            function StateHook.new()
                return setmetatable({ _forced = {} }, StateHook)
            end
            function StateHook:SetForced(name, value)
                local token = enc(name)
                if token == nil or self._forced[token] == value then
                    return
                end
                local remote = resolveUpdateStateRemote()
                if not remote then
                    return
                end
                self._forced[token] = value
                rbFireServerNative(remote, token, value, nil)
            end
            function StateHook:ClearForced(name, offValue)
                local token = enc(name)
                if token == nil or self._forced[token] == nil then
                    return
                end
                self._forced[token] = nil
                local remote = resolveUpdateStateRemote()
                if remote then
                    rbFireServerNative(remote, token, offValue, nil)
                end
            end

            -- ---- part glue (Kicia t116, lines 150715-150820) -----------------------------
            local VOID_CFRAME = CFrame.new(
                math.random(-100000, -10000),
                100000,
                math.random(-100000, 10000)
            )
            local PartGlue = {}
            PartGlue.__index = PartGlue
            function PartGlue.new()
                return setmetatable({ _gluedParts = {}, _bindings = {} }, PartGlue)
            end
            function PartGlue:_SetupGlue(part)
                local entry = self._gluedParts[part]
                if entry ~= nil then
                    entry.refCount = entry.refCount + 1
                    return
                end
                local weld = part:FindFirstChildOfClass('WeldConstraint')
                local originalPart1 = nil
                if weld ~= nil then
                    originalPart1 = weld.Part1
                    if originalPart1 ~= nil then
                        weld.Part1 = nil
                    end
                    part.Anchored = true
                end
                self._gluedParts[part] = { refCount = 1, weld = weld, originalPart1 = originalPart1 }
            end
            function PartGlue:_ReleaseGlue(part)
                local entry = self._gluedParts[part]
                if entry == nil then
                    return
                end
                entry.refCount = entry.refCount - 1
                if 0 < entry.refCount then
                    return
                end
                local weld = entry.weld
                if weld ~= nil and entry.originalPart1 ~= nil then
                    weld.Part1 = entry.originalPart1
                    entry.originalPart1.Anchored = false
                end
                self._gluedParts[part] = nil
            end
            function PartGlue:Acquire(ourPart, hitboxPart, useRotation)
                local prev = rbGetThreadIdentity()
                rbSetThreadIdentity(8)
                pcall(rbSetHidden, ourPart, 'PhysicsRepRootPart', hitboxPart)
                rbSetThreadIdentity(prev)
                local bound = self._bindings[ourPart]
                if bound ~= hitboxPart then
                    if bound ~= nil then
                        self:_ReleaseGlue(bound)
                    end
                    self:_SetupGlue(hitboxPart)
                    self._bindings[ourPart] = hitboxPart
                end
                local cf = CFrame.new(VOID_CFRAME.Position)
                if useRotation then
                    cf = cf * hitboxPart.CFrame.Rotation
                end
                hitboxPart.CFrame = cf
                return VOID_CFRAME
            end
            function PartGlue:Free(ourPart)
                local bound = self._bindings[ourPart]
                if bound == nil then
                    return
                end
                self._bindings[ourPart] = nil
                self:_ReleaseGlue(bound)
                local prev = rbGetThreadIdentity()
                rbSetThreadIdentity(8)
                pcall(rbSetHidden, ourPart, 'PhysicsRepRootPart', nil)
                rbSetThreadIdentity(prev)
            end
            function PartGlue:Destroy()
                for _, entry in pairs(self._gluedParts) do
                    local weld = entry.weld
                    if weld ~= nil and entry.originalPart1 ~= nil then
                        pcall(function()
                            weld.Part1 = entry.originalPart1
                            entry.originalPart1.Anchored = false
                        end)
                    end
                end
                table.clear(self._gluedParts)
                table.clear(self._bindings)
            end

            -- ---- enemy target list + validity (Kicia t190, lines 92617-92664) ------------
            local function isEnemyPlayer(player)
                if player == nil or player == LPRB then
                    return false
                end
                local localTeamId = LPRB:GetAttribute('TeamID')
                local theirTeamId = player:GetAttribute('TeamID')
                if localTeamId ~= nil and theirTeamId ~= nil then
                    return localTeamId ~= theirTeamId
                end
                if LPRB.Team ~= nil and player.Team ~= nil then
                    return LPRB.Team ~= player.Team
                end
                return true
            end
            local function isTargetInvincible(entity)
                local data = entity and rawget(entity, 'Data')
                return data ~= nil and rawget(data, 'IsInvincible') == true
            end
            local function collectEnemies()
                local out = {}
                local controller = resolveFighterController()
                local objects = controller and rawget(controller, 'Objects') or nil
                if type(objects) ~= 'table' then
                    return out
                end
                for _, fighter in ipairs(objects) do
                    local ok, entry = pcall(function()
                        local player = rawget(fighter, 'Player')
                        local entity = rawget(fighter, 'Entity')
                        local model = entity and rawget(entity, 'Model') or nil
                        if not model then
                            return nil
                        end
                        if player ~= nil and not isEnemyPlayer(player) then
                            return nil
                        end
                        local hitboxHead = model:FindFirstChild('HitboxHead')
                        local hitboxBody = model:FindFirstChild('HitboxBody')
                        local rootPart = model:FindFirstChild('HumanoidRootPart') or hitboxBody
                        if not (hitboxHead and rootPart) then
                            return nil
                        end
                        local humanoid = model:FindFirstChildOfClass('Humanoid')
                        return {
                            fighter = fighter,
                            player = player,
                            entity = entity,
                            model = model,
                            hitboxHead = hitboxHead,
                            hitboxBody = hitboxBody,
                            rootPart = rootPart,
                            itemObserver = rawget(fighter, 'itemObserver') or rawget(fighter, 'ItemObserver'),
                            alive = humanoid == nil or humanoid.Health > 0,
                            invincible = isTargetInvincible(entity),
                            hacker = false,
                            equippedGunProjectile = false,
                        }
                    end)
                    if ok and entry then
                        out[#out + 1] = entry
                    end
                end
                return out
            end
            local function isValidTarget(entry)
                return entry ~= nil and entry.alive and not entry.invincible and not entry.deflecting
            end
            local function selectTarget()
                local enemies = collectEnemies()
                local prioritizeHackers = Setting.PrioritizeHackers()
                if prioritizeHackers then
                    for _, entry in ipairs(enemies) do
                        if entry.hacker and isValidTarget(entry) then
                            return entry
                        end
                    end
                end
                for _, entry in ipairs(enemies) do
                    if not (prioritizeHackers and entry.hacker) and isValidTarget(entry) then
                        return entry
                    end
                end
                return nil
            end
            local function hasTargets()
                for _, entry in ipairs(collectEnemies()) do
                    if isValidTarget(entry) then
                        return true
                    end
                end
                return false
            end

            -- ---- weapon selection (Kicia t34.getAction, lines 122419-122490) -------------
            local function itemCategory(slotIndex)
                if slotIndex == 1 then
                    return 'Primary'
                elseif slotIndex == 2 then
                    return 'Secondary'
                elseif slotIndex == 3 then
                    return 'Melee'
                end
                return nil
            end
            local function isCategoryEnabled(category)
                if category == 'Primary' then
                    return Setting.WeaponPrimary()
                elseif category == 'Secondary' then
                    return Setting.WeaponSecondary()
                elseif category == 'Melee' then
                    return Setting.WeaponMelee()
                end
                return false
            end
            local function getAction(fighter)
                if not fighter then
                    return nil
                end
                local items = rawget(fighter, 'Items')
                if type(items) ~= 'table' then
                    return nil
                end
                local onEmpty = Setting.OnEmpty()
                local priorityList = {} -- Kicia default Priority = {} (all equal; first-found wins)
                -- The slot is the Items-table key (1=Primary, 2=Secondary, 3=Melee - the game's
                -- own EquipPrimary input is EquipItem(1)). Kicia's registry passes the same key
                -- into its wrapper as .index; ClientItems carry no index field of their own.
                local bestAttack, bestAttackPri, bestAttackIndex = nil, math.huge, nil
                local bestSwap, bestSwapPri, bestSwapIndex = nil, math.huge, nil
                local anyEnabled = false
                for slotKey, item in next, items do
                    if type(item) == 'table' then
                        local category = itemCategory(slotKey)
                        if category ~= nil and isCategoryEnabled(category) then
                            anyEnabled = true
                            local priority = table.find(priorityList, category) or math.huge
                            if itemType(item) == 'Gun' and itemAmmo(item) == 0 then
                                if itemAmmoReserve(item) > 0 and priority < bestSwapPri then
                                    if onEmpty == 'Reload' then
                                        bestAttackPri = priority
                                        bestAttack = item
                                        bestAttackIndex = slotKey
                                    else
                                        bestSwap = item
                                        bestSwapPri = priority
                                        bestSwapIndex = slotKey
                                    end
                                end
                            elseif bestAttack == nil or priority < bestAttackPri then
                                bestAttackPri = priority
                                bestAttack = item
                                bestAttackIndex = slotKey
                            end
                        end
                    end
                end
                if not anyEnabled then
                    return nil
                end
                if bestAttack == nil then
                    if onEmpty == 'Swap' or bestSwap == nil then
                        return nil
                    end
                    if itemIsEquipped(bestSwap) then
                        return { type = 'Reload', item = bestSwap, itemType = itemType(bestSwap), index = bestSwapIndex }
                    end
                    return { type = 'Swap', item = bestSwap, itemType = itemType(bestSwap), index = bestSwapIndex }
                end
                local emptyGun = itemType(bestAttack) == 'Gun' and itemAmmo(bestAttack) == 0
                if not itemIsEquipped(bestAttack) then
                    return { type = 'Swap', item = bestAttack, itemType = itemType(bestAttack), index = bestAttackIndex }
                end
                if emptyGun then
                    return { type = 'Reload', item = bestAttack, itemType = itemType(bestAttack), index = bestAttackIndex }
                end
                return { type = 'Attack', item = bestAttack, itemType = itemType(bestAttack), index = bestAttackIndex }
            end

            -- ---- shoot lock (Kicia t93, lines 65724-65750) -------------------------------
            local ShootLock = {}
            ShootLock.__index = ShootLock
            function ShootLock.new()
                return setmetatable({ _lockedUntil = nil }, ShootLock)
            end
            function ShootLock:ShouldFire(canFire, lockDuration)
                local now = os.clock()
                local locked = self._lockedUntil ~= nil and now < self._lockedUntil
                if canFire then
                    self._lockedUntil = now + lockDuration
                end
                if not locked then
                    locked = canFire
                end
                return locked
            end
            function ShootLock:Reset()
                self._lockedUntil = nil
            end

            -- ---- spatial limit gate (Kicia t98, lines 142617-142668) ---------------------
            local SPATIAL_BOUND = 4194304
            local function outOfSpatialBound(pos)
                return SPATIAL_BOUND <= math.abs(pos.X) or SPATIAL_BOUND <= math.abs(pos.Y) or SPATIAL_BOUND <= math.abs(pos.Z)
            end
            local SpatialLimitGate = {}
            SpatialLimitGate.__index = SpatialLimitGate
            function SpatialLimitGate.new()
                return setmetatable({ _measurements = {} }, SpatialLimitGate)
            end
            function SpatialLimitGate:Tick(target)
                local key = target.fighter or target
                local m = self._measurements[key]
                if m == nil then
                    m = { expectedDuration = 1 }
                    self._measurements[key] = m
                end
                local now = os.clock()
                local entry = m.limitEntryTime
                local hasAmmo = target.equippedAmmoState ~= false
                if not outOfSpatialBound(target.rootPart.Position) then
                    if entry ~= nil then
                        if hasAmmo then
                            m.expectedDuration = now - entry
                        end
                        m.limitEntryTime = nil
                    end
                    return false
                end
                if entry == nil then
                    m.limitEntryTime = now
                    entry = now
                end
                if hasAmmo and (m.expectedDuration - Setting.Stability()) <= (now - entry) then
                    return false
                end
                return true
            end

            -- ---- defensive module (Kicia t156, lines 151628-151664) ----------------------
            local function localShieldStance(fighter)
                local items = fighter and rawget(fighter, 'Items') or nil
                if type(items) ~= 'table' then
                    return 'None'
                end
                for _, item in next, items do
                    if type(item) == 'table' and itemName(item) == 'Riot Shield' then
                        if itemIsEquipped(item) then
                            return 'Equipped'
                        end
                        return 'Unequipped'
                    end
                end
                return 'None'
            end
            local function getDefensiveCFrame(cframe, stance, targetRootPart)
                if stance == 'Equipped' then
                    return CFrame.new(cframe.Position, targetRootPart.Position)
                end
                if stance == 'Unequipped' then
                    return CFrame.new(cframe.Position, cframe.Position + (cframe.Position - targetRootPart.Position))
                end
                return cframe
            end
            local function getDefensiveViewAngles(stance)
                if stance == 'None' then
                    return nil
                end
                local pitch = (stance == 'Equipped') and 90 or -90
                return { kind = 'Normalized', pitch = pitch, yaw = rbRandom:NextNumber(0, 360) }
            end

            -- ---- evasion (Kicia f573 / f4230 / t167 / t103) ------------------------------
            local FAR_AXIS = 1073741824
            local function ringPoint(anchor, minR, maxR)
                local angle = rbRandom:NextNumber(0, 2 * math.pi)
                local radius = rbRandom:NextNumber(minR, maxR)
                return CFrame.new(anchor + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
                    * CFrame.fromOrientation(
                        rbRandom:NextNumber(0, 2 * math.pi),
                        rbRandom:NextNumber(0, 2 * math.pi),
                        rbRandom:NextNumber(0, 2 * math.pi)
                    )
            end
            local function scatterFar(pos, anchorFromCharacter, baseRadius, radiusFactor)
                local extra = baseRadius * radiusFactor
                local anchor = anchorFromCharacter and pos or Vector3.new(0, pos.Y, 0)
                local ring = ringPoint(anchor, baseRadius, baseRadius + extra)
                local ringPos = ring.Position
                local x, y, z = ringPos.X, ringPos.Y, ringPos.Z
                local pick = rbRandom:NextInteger(1, 3)
                if pick == 1 then
                    x = FAR_AXIS
                elseif pick == 2 then
                    y = FAR_AXIS
                else
                    z = FAR_AXIS
                end
                return ring - ringPos + Vector3.new(x, y, z)
            end
            local function randomEvade(clientCF)
                return scatterFar(clientCF.Position, Setting.RandomAnchorFromCharacter(), Setting.RandomBaseRadius(), Setting.RandomRadiusFactor())
            end
            local function translocateEvade(clientCF, hasTargetsNow)
                -- Kicia fallback (t103.compute): a far ring-scatter (v107(pos, 10000, 1e9)).
                if not hasTargetsNow then
                    return ringPoint(clientCF.Position, 10000, 1000000000)
                end
                local chosen = nil
                for _, part in ipairs(CollectionServiceRB:GetTagged('OutOfBoundsPart')) do
                    if part:GetAttribute('KillDelay') == 0 then
                        chosen = part
                        break
                    end
                end
                if chosen == nil then
                    return ringPoint(clientCF.Position, 10000, 1000000000)
                end
                return chosen.CFrame * CFrame.new(0, -chosen.Size.Y / 2 + Setting.TranslocateOffset(), 0)
            end
            local function depthOsc(range, freq)
                return range.Min + (range.Max - range.Min) * ((math.sin(os.clock() * (2 * math.pi * freq)) + 1) * 0.5)
            end
            local function surfaceCFrame(surface, up, forward)
                return CFrame.fromMatrix(
                    surface.surfacePosition - surface.up * 0.01 - surface.up * up + surface.forward * forward,
                    surface.right,
                    surface.up,
                    -surface.forward
                )
            end
            local PB_OVERLAP = OverlapParams.new()
            PB_OVERLAP.FilterType = Enum.RaycastFilterType.Exclude
            PB_OVERLAP.FilterDescendantsInstances = {}
            PB_OVERLAP.BruteForceAllSlow = true
            local PB_PROBE_SIZE = Vector3.new(5, 5, 5)
            local function isBoundaryPart(part)
                return part.Name == 'Barriers' or part:HasTag('OutOfBoundsPart') or part:HasTag('KillBrick')
            end
            local function hasBoundaryNear(pos)
                for _, part in ipairs(WorkspaceRB:GetPartBoundsInBox(CFrame.new(pos), PB_PROBE_SIZE, PB_OVERLAP)) do
                    if isBoundaryPart(part) then
                        return true
                    end
                end
                return false
            end
            -- Kicia's f6204 (surface descriptor from a part face) is erased; reconstructed as the
            -- part's top-face frame - the only shape consistent with surfaceCFrame's fields.
            local function describeSurface(part)
                local cf = part.CFrame
                return {
                    surfacePosition = (cf * CFrame.new(0, part.Size.Y / 2, 0)).Position,
                    up = cf.UpVector,
                    right = cf.RightVector,
                    forward = cf.LookVector,
                }
            end
            local ProjectileBreaker = {}
            ProjectileBreaker.__index = ProjectileBreaker
            function ProjectileBreaker.new()
                return setmetatable({
                    _nextPositionCooldown = -1,
                    _poolEnvironmentID = nil,
                    _pool = {},
                    _processedParts = {},
                    _lastBreakSurface = nil,
                }, ProjectileBreaker)
            end
            function ProjectileBreaker:BindEnvironment(envId)
                self._poolEnvironmentID = envId
                self._pool = {}
                self._processedParts = {}
            end
            function ProjectileBreaker:_HasProjectileThreat()
                for _, entry in ipairs(collectEnemies()) do
                    if entry.equippedGunProjectile then
                        return true
                    end
                end
                return false
            end
            function ProjectileBreaker:_ScanBatch(envId)
                local depthForwardMax = PB_DEPTH_FORWARD.Min + PB_DEPTH_FORWARD.Max
                local upMid = (PB_DEPTH_UP.Min + PB_DEPTH_UP.Max) * 0.5
                local forwardMid = depthForwardMax * 0.5
                local scanned = 0
                local function consider(part)
                    if not (part:IsA('BasePart') and not self._processedParts[part]) then
                        return
                    end
                    self._processedParts[part] = true
                    scanned = scanned + 1
                    local surface = describeSurface(part)
                    if hasBoundaryNear(surfaceCFrame(surface, upMid, forwardMid).Position) then
                        return
                    end
                    self._pool[#self._pool + 1] = surface
                end
                for _, tagged in ipairs(CollectionServiceRB:GetTagged('RaycastWhitelist' .. tostring(envId))) do
                    if not isBoundaryPart(tagged) then
                        consider(tagged)
                        if 64 <= scanned or 30 <= #self._pool then
                            return
                        end
                        for _, descendant in ipairs(tagged:GetDescendants()) do
                            if not isBoundaryPart(descendant) then
                                consider(descendant)
                                if 64 <= scanned or 30 <= #self._pool then
                                    return
                                end
                            end
                        end
                    end
                end
            end
            function ProjectileBreaker:_BreakLine()
                local envId = self._poolEnvironmentID
                if envId == nil then
                    return nil
                end
                if #self._pool < 30 then
                    self:_ScanBatch(envId)
                end
                if #self._pool < 30 then
                    return nil
                end
                self._nextPositionCooldown = os.clock() + Setting.RepositionInterval()
                return self._pool[rbRandom:NextInteger(1, #self._pool)]
            end
            function ProjectileBreaker:Compute(clientCF)
                if os.clock() < self._nextPositionCooldown then
                    local last = self._lastBreakSurface
                    if last ~= nil then
                        return surfaceCFrame(last, depthOsc(PB_DEPTH_UP, PB_DEPTH_UP_FREQ), depthOsc(PB_DEPTH_FORWARD, PB_DEPTH_FORWARD_FREQ))
                    end
                end
                if not self:_HasProjectileThreat() then
                    self._lastBreakSurface = nil
                    return scatterFar(clientCF.Position, PB_FALLBACK_ANCHOR_FROM_CHARACTER, PB_FALLBACK_BASE_RADIUS, PB_FALLBACK_RADIUS_FACTOR)
                end
                local breakLine = self:_BreakLine()
                if breakLine == nil then
                    return scatterFar(clientCF.Position, PB_FALLBACK_ANCHOR_FROM_CHARACTER, PB_FALLBACK_BASE_RADIUS, PB_FALLBACK_RADIUS_FACTOR)
                end
                self._lastBreakSurface = breakLine
                return surfaceCFrame(breakLine, depthOsc(PB_DEPTH_UP, PB_DEPTH_UP_FREQ), depthOsc(PB_DEPTH_FORWARD, PB_DEPTH_FORWARD_FREQ))
            end
            function ProjectileBreaker:ResetState()
                self._nextPositionCooldown = -1
                self._lastBreakSurface = nil
            end

            -- ---- firing strategies (Kicia t96 hitscan / t98 melee) -----------------------
            local function farMiss()
                return CFrame.new(
                    math.random(-1000000, 1000000),
                    math.random(5000, 10000),
                    math.random(-1000000, 1000000)
                )
            end
            local HitscanStrategy = {}
            HitscanStrategy.__index = HitscanStrategy
            function HitscanStrategy.new(partGlue)
                return setmetatable({ _partGlue = partGlue, _shootLock = ShootLock.new() }, HitscanStrategy)
            end
            function HitscanStrategy:Plan(dt, target, item, ourRootPart, canFire)
                local hitboxHead = target.hitboxHead
                local above = isAbove(target)
                local offset = above and OFFSET_ABOVE or OFFSET_BELOW
                local void = self._partGlue:Acquire(ourRootPart, hitboxHead)
                self._gluedOurPart = ourRootPart
                local cframe
                if above then
                    cframe = void + offset
                else
                    cframe = CFrame.new(void.Position + offset, hitboxHead.Position)
                end
                if not self._shootLock:ShouldFire(canFire, dt * Setting.ShootFrames()) then
                    return farMiss(), nil
                end
                local _, oy, oz = target.rootPart.CFrame:ToOrientation()
                local pitch = above and PITCH_ABOVE or PITCH_BELOW
                local aim1 = buildAim(above and AIM_ABOVE_ORIGIN or AIM_BELOW_ORIGIN, pitch, oy, oz)
                local aim2 = buildAim(above and AIM_ABOVE_END or AIM_BELOW_END, pitch, oy, oz)
                local objectId = itemObjectId(item)
                local isRaycast = itemIsRaycast(item)
                local function weaponAction()
                    fireGun(objectId, isRaycast, aim1, aim2, hitboxHead, AIM_EXTRA)
                end
                return cframe, weaponAction
            end
            function HitscanStrategy:ResetState()
                self._shootLock:Reset()
                local glued = self._gluedOurPart
                if glued ~= nil then
                    self._partGlue:Free(glued)
                    self._gluedOurPart = nil
                end
            end

            local BACKSTAB_WINDOW = 0.625
            local BACKSTAB_COOLDOWN = 1.25
            local MeleeStrategy = {}
            MeleeStrategy.__index = MeleeStrategy
            function MeleeStrategy.new(partGlue)
                return setmetatable({
                    _partGlue = partGlue,
                    _shootLock = ShootLock.new(),
                    _hitboxWindowUntil = -1,
                    _attackCooldown = -1,
                }, MeleeStrategy)
            end
            local function meleeViewAngles(px, oy)
                return { kind = 'Normalized', pitch = math.deg(px), yaw = math.deg(oy) }
            end
            function MeleeStrategy:_RecordBackstab()
                local now = os.clock()
                self._hitboxWindowUntil = now + BACKSTAB_WINDOW
                self._attackCooldown = now + BACKSTAB_COOLDOWN
            end
            function MeleeStrategy:Plan(dt, target, item, ourRootPart, canFire)
                local hitboxHead = target.hitboxHead
                local above = isAbove(target)
                local offset = above and OFFSET_ABOVE or OFFSET_BELOW
                local void = self._partGlue:Acquire(ourRootPart, hitboxHead)
                self._gluedOurPart = ourRootPart
                local cframe
                if above then
                    cframe = void + offset
                else
                    cframe = CFrame.new(void.Position + offset, hitboxHead.Position)
                end
                local px, oy, oz = target.rootPart.CFrame:ToOrientation()
                local pitch = above and PITCH_ABOVE or PITCH_BELOW
                local aim1 = buildAim(above and AIM_ABOVE_ORIGIN or AIM_BELOW_ORIGIN, pitch, oy, oz)
                local aim2 = buildAim(above and AIM_ABOVE_END or AIM_BELOW_END, pitch, oy, oz)
                local objectId = itemObjectId(item)
                local now = os.clock()
                if now < self._hitboxWindowUntil then
                    return cframe, meleeViewAngles(px, oy), function()
                        fireMeleeHeavy(objectId, aim1, aim2, hitboxHead, AIM_EXTRA)
                    end
                end
                if not self._shootLock:ShouldFire(canFire, dt * Setting.ShootFrames()) then
                    return farMiss(), nil, nil
                end
                if now < self._attackCooldown then
                    return farMiss(), nil, nil
                end
                if itemName(item) ~= 'Knife' then
                    return cframe, nil, function()
                        fireMeleeAttack(objectId, aim1, aim2, hitboxHead, AIM_EXTRA)
                    end
                end
                self:_RecordBackstab()
                return cframe, meleeViewAngles(px, oy), function()
                    fireMeleeHeavy(objectId, aim1, aim2, hitboxHead, AIM_EXTRA)
                end
            end
            function MeleeStrategy:ResetState()
                self._hitboxWindowUntil = -1
                self._attackCooldown = -1
                self._shootLock:Reset()
                local glued = self._gluedOurPart
                if glued ~= nil then
                    self._partGlue:Free(glued)
                    self._gluedOurPart = nil
                end
            end

            -- ---- FFlag environment toggles (Kicia SetEnabled, lines 63538-63571) ----------
            local ORIGINAL_FALLEN_PARTS_HEIGHT = nil
            local function applyEnabledFFlags(enabled)
                if enabled and ORIGINAL_FALLEN_PARTS_HEIGHT == nil then
                    ORIGINAL_FALLEN_PARTS_HEIGHT = WorkspaceRB.FallenPartsDestroyHeight
                end
                pcall(function()
                    WorkspaceRB.FallenPartsDestroyHeight = enabled and (0 / 0) or (ORIGINAL_FALLEN_PARTS_HEIGHT or -500)
                end)
                if rbSetFFlag then
                    pcall(rbSetFFlag, 'DFIntS2PhysicsSenderRate', enabled and '120' or '15')
                    pcall(rbSetFFlag, 'DFIntAssemblyHistoryBufferSize', enabled and '2147483648' or '15')
                    pcall(rbSetFFlag, 'DFIntAssemblyHistorySkipSize', enabled and '0' or '8')
                end
            end

            -- ---- controller (Kicia t1, lines 63573-63758) --------------------------------
            local Controller = {}
            Controller.__index = Controller
            function Controller.new()
                local partGlue = PartGlue.new()
                return setmetatable({
                    _enabled = false,
                    _partGlue = partGlue,
                    _hitscanStrategy = HitscanStrategy.new(partGlue),
                    _meleeStrategy = MeleeStrategy.new(partGlue),
                    _projectileBreaker = ProjectileBreaker.new(),
                    _spatialLimitGate = SpatialLimitGate.new(),
                    _stateHook = StateHook.new(),
                    _characterController = nil,
                    _boundRootPart = nil,
                    _lastTargetWorld = nil,
                    _lastDefensiveViewAngles = nil,
                }, Controller)
            end
            function Controller:SetEnabled(enabled)
                if self._enabled == enabled then
                    return
                end
                self._enabled = enabled
                applyEnabledFFlags(enabled)
                self:_Reset()
            end
            function Controller:_ApplyForcedCrouch(on)
                if on then
                    self._stateHook:SetForced('IsCrouching', true)
                else
                    self._stateHook:ClearForced('IsCrouching', false)
                end
            end
            function Controller:_EnsureCharacterController()
                local Char, HumanoidRootPart = GetChar(), GetRoot()
                if not HumanoidRootPart or HumanoidRootPart.Parent ~= Char then
                    if self._characterController then
                        self._characterController:Destroy()
                        self._characterController = nil
                        self._boundRootPart = nil
                    end
                    return nil
                end
                if self._characterController == nil or self._boundRootPart ~= HumanoidRootPart then
                    if self._characterController then
                        self._characterController:Destroy()
                    end
                    self._characterController = CharacterController.new(HumanoidRootPart)
                    self._boundRootPart = HumanoidRootPart
                end
                return self._characterController
            end
            function Controller:_EvadePlan(clientCF, mode)
                if mode == 'Off' then
                    return {}
                end
                if mode ~= 'ProjectileBreaker' then
                    return { cframe = randomEvade(clientCF) }
                end
                return { cframe = self._projectileBreaker:Compute(clientCF), shouldSkipDefense = true }
            end
            function Controller:_Plan(dt, action, target, ourRootPart, clientCF, mode)
                local canFire = true
                if target ~= nil then
                    canFire = not self._spatialLimitGate:Tick(target)
                end
                if action == nil then
                    return self:_EvadePlan(clientCF, mode)
                end
                if action.type == 'Swap' then
                    local plan = self:_EvadePlan(clientCF, mode)
                    local item = action.item
                    local index = action.index
                    plan.weaponAction = function() equipItem(item, index) end
                    return plan
                end
                if action.type == 'Reload' then
                    local plan = self:_EvadePlan(clientCF, mode)
                    local item = action.item
                    plan.weaponAction = function() reloadItem(item) end
                    return plan
                end
                if target == nil then
                    return self:_EvadePlan(clientCF, mode)
                end
                if action.itemType == 'Melee' then
                    local cframe, viewAngles, weaponAction = self._meleeStrategy:Plan(dt, target, action.item, ourRootPart, canFire)
                    return { cframe = cframe, viewAngles = viewAngles, weaponAction = weaponAction, shouldSkipDefense = true, shouldForceCrouch = true }
                end
                if action.itemType ~= 'Gun' then
                    return {}
                end
                if itemIsReloading(action.item) then
                    return self:_EvadePlan(clientCF, mode)
                end
                local cframe, weaponAction = self._hitscanStrategy:Plan(dt, target, action.item, ourRootPart, canFire)
                return { cframe = cframe, weaponAction = weaponAction, shouldForceCrouch = true, isAimPose = weaponAction ~= nil }
            end
            function Controller:_ApplyPlan(plan, target, characterController, fighter)
                local cframe = plan.cframe
                if cframe == nil or target == nil or plan.shouldSkipDefense then
                    characterController:SetServerCFrame(cframe)
                    characterController:SendViewAngles(20, plan.viewAngles)
                    return
                end
                local stance = localShieldStance(fighter)
                characterController:SetServerCFrame(getDefensiveCFrame(cframe, stance, target.rootPart))
                if plan.isAimPose or plan.shouldDefendInPlace then
                    self._lastDefensiveViewAngles = getDefensiveViewAngles(stance)
                end
                characterController:SendViewAngles(20, plan.viewAngles or self._lastDefensiveViewAngles)
            end
            function Controller:Update(dt)
                local fighter = resolveLocalFighter()
                local characterController = self:_EnsureCharacterController()
                if fighter == nil or characterController == nil or not self._enabled then
                    self:_Reset()
                    return
                end
                if RivalsRuntimeBridge.IsReadyToFight and not RivalsRuntimeBridge.IsReadyToFight() then
                    self:_Reset()
                    return
                end
                local ourRootPart = self._boundRootPart
                local clientCF = characterController:GetClientCFrame()
                local mode = Setting.EvasionMode()
                if mode == 'Translocate' then
                    self:_ApplyForcedCrouch(false)
                    characterController:SetServerCFrame(translocateEvade(clientCF, hasTargets()))
                    characterController:HeartbeatUpdate()
                    return
                end
                local target = selectTarget()
                local action = getAction(fighter)
                self._lastTargetWorld = target ~= nil and target.rootPart.Position or nil
                local plan = self:_Plan(dt, action, target, ourRootPart, clientCF, mode)
                self:_ApplyPlan(plan, target, characterController, fighter)
                self:_ApplyForcedCrouch(plan.shouldForceCrouch == true)
                if plan.weaponAction ~= nil then
                    plan.weaponAction()
                end
                characterController:HeartbeatUpdate()
            end
            function Controller:GetLastTargetWorld()
                return self._lastTargetWorld
            end
            function Controller:_Reset()
                self._lastTargetWorld = nil
                self._lastDefensiveViewAngles = nil
                self:_ApplyForcedCrouch(false)
                self._meleeStrategy:ResetState()
                self._hitscanStrategy:ResetState()
                self._projectileBreaker:ResetState()
                if self._characterController then
                    self._characterController:SetServerCFrame(nil)
                    self._characterController:SendViewAngles(20, nil)
                    self._characterController:HeartbeatUpdate()
                end
            end
            function Controller:Destroy()
                self:SetEnabled(false)
                self:_Reset()
                if self._characterController then
                    self._characterController:Destroy()
                    self._characterController = nil
                    self._boundRootPart = nil
                end
                self._partGlue:Destroy()
                applyEnabledFFlags(false)
            end

            -- ---- lifecycle / bridge ------------------------------------------------------
            local controllerInstance = nil
            local function ensureController()
                if controllerInstance == nil then
                    controllerInstance = Controller.new()
                end
                return controllerInstance
            end
            function KiciaRagebot.IsEnabled()
                if not togValue('P8S4T1', false) then
                    return false
                end
                -- Executor support: FighterController discovery walks the GC and the
                -- void redirect writes the hidden PhysicsRepRootPart property. Without
                -- either the bot cannot function, so decline (one-time notice via the
                -- gate) instead of running the loop's side effects for nothing.
                -- Checked after the toggle so the notice fires at enable, not at load;
                -- cached because this runs per-frame.
                if KiciaRagebot.CapsOk == nil then
                    KiciaRagebot.CapsOk = __kicia_hook_genv.KiciaHookCaps.gate('Ragebot', 'getgc', 'sethiddenproperty')
                end
                if not KiciaRagebot.CapsOk then
                    return false
                end
                -- Practice / shooting range: the ragebot must never act here (target dummies, no real
                -- match). Live-verified: the local fighter carries IsInShootingRange=true in
                -- the practice range and IsInDuel=true in real 1v1s. Returning false makes the controller
                -- settle to disabled (release part-glue, restore FFlags) via the normal Update path. The
                -- Seeded guard means we only gate once the duel state has actually been read.
                local localDuel = FighterDataCache and FighterDataCache.LocalDuel
                if localDuel and localDuel.Seeded and localDuel.IsInShootingRange == true then
                    return false
                end
                -- Enabled AND keybind-active (Kicia ObserveEnabledKeybind); Mode 'Always' -> always true.
                local keypicker = Options and Options.P8S4T1K
                if keypicker and type(keypicker.GetState) == 'function' then
                    return keypicker:GetState() == true
                end
                return true
            end
            function KiciaRagebot.Update(dt)
                local controller = ensureController()
                local enabled = KiciaRagebot.IsEnabled()
                if controller._enabled ~= enabled then
                    controller:SetEnabled(enabled)
                end
                controller:Update(dt or 0)
            end
            function KiciaRagebot.Reset()
                if controllerInstance then
                    controllerInstance:_Reset()
                end
            end
            function KiciaRagebot.Destroy()
                if controllerInstance then
                    controllerInstance:Destroy()
                    controllerInstance = nil
                end
            end
            RivalsRuntimeBridge.UpdateKiciaRagebot = KiciaRagebot.Update
            RivalsRuntimeBridge.ResetKiciaRagebot = KiciaRagebot.Reset
            RivalsRuntimeBridge.DestroyKiciaRagebot = KiciaRagebot.Destroy
        -- __KICIA_RAGEBOT_END__
    end,
}
end

__kicia_hook_shared.error_reporter = function()
-- =============================================================================
--  ErrorReporter - local error surfacing
-- =============================================================================
--  A runtime error becomes an on-screen notification plus a `warn()` line in
--  the executor console, with the full traceback.
--
--  Interface:
--      module.set_game(name)                     label shown on reports
--      module.report(err_msg, traceback, feature) surface one error
-- =============================================================================

-- Identical messages are collapsed for this many seconds. A feature that throws
-- inside a RenderStepped binding can fault 60 times a second; without this the
-- notification queue would bury the menu.
local DUPLICATE_COOLDOWN_SECONDS = 30
-- Hard ceiling on notifications per minute across all errors, so a storm of
-- *different* errors cannot do the same thing.
local MAX_NOTIFICATIONS_PER_MINUTE = 6

local module = {}

local game_context = 'Unknown'
local last_seen_at = {}
local recent_notifications = {}

function module.set_game(name)
    game_context = name or 'Unknown'
end

local function is_rate_limited()
    local now = os.clock()
    local cutoff = now - 60
    local recent = {}
    for _, t in ipairs(recent_notifications) do
        if t > cutoff then
            table.insert(recent, t)
        end
    end
    recent_notifications = recent
    return #recent_notifications >= MAX_NOTIFICATIONS_PER_MINUTE
end

local function truncate(str, max)
    if #str <= max then return str end
    return str:sub(1, max - 3) .. '...'
end

-- err_msg   the error text
-- traceback optional debug.traceback() string
-- feature   optional label for which feature faulted, e.g. 'rivals_aimbot'
function module.report(err_msg, traceback, feature)
    local message = tostring(err_msg)
    local key = (feature or '?') .. '|' .. message

    local now = os.clock()
    local last = last_seen_at[key]
    if last and (now - last) < DUPLICATE_COOLDOWN_SECONDS then
        return
    end
    last_seen_at[key] = now

    -- Console first, and always: it carries the full traceback and is never
    -- rate limited, so the complete picture is available even when the on-screen
    -- notification is suppressed.
    local label = '[' .. game_context .. ']'
    if feature then
        label = label .. '[' .. tostring(feature) .. ']'
    end
    warn(label .. ' ' .. message)
    if traceback then
        warn(tostring(traceback))
    end

    if is_rate_limited() then
        return
    end
    table.insert(recent_notifications, now)

    -- Library is an upvalue from the header, assigned before any shared module
    -- is required. Guarded anyway: an error thrown while the UI library itself
    -- is still loading would otherwise turn into a second, more confusing error.
    if Library and type(Library.Notify) == 'function' then
        pcall(function()
            Library:Notify({
                Title = feature and ('Error: ' .. tostring(feature)) or 'Error',
                Description = truncate(message, 200) .. ' (see console for traceback)',
                Time = 8,
            })
        end)
    end
end

return module
end


-- -----------------------------------------------------------------------------
-- Anti-detection safe_* wrappers
-- -----------------------------------------------------------------------------
-- cloneref() returns a proxy that is not reference-equal to the raw Instance, so
-- the game cannot detect that we hold or act on a specific Instance by identity.
-- These live here as upvalues (not per-feature locals) so the RIVALS module does
-- not spend one of Luau's 200 local registers on each. The globals they call
-- were stubbed with fallbacks above, so they degrade to plain calls on executors
-- that lack the real primitive.
local function safe_get_gc(callback)
    local gc = setmetatable(getgc(true), { __mode = 'v' })
    for _, value in pairs(gc) do
        local ok, result = pcall(callback, value)
        if ok and result then
            break
        end
    end
end
local function safe_require(module)
    return require(cloneref(module))
end
local function safe_fire_server(remote, ...)
    cloneref(remote):FireServer(...)
end
local function safe_invoke_server(remote, ...)
    return cloneref(remote):InvokeServer(...)
end
local function safe_fire_signal(signal, ...)
    firesignal(cloneref(signal), ...)
end
local function safe_get_attribute(instance, attr)
    return cloneref(instance):GetAttribute(attr)
end
local function safe_set_attribute(instance, attr, value)
    cloneref(instance):SetAttribute(attr, value)
end
local function safe_find(parent, name)
    return cloneref(parent):FindFirstChild(name)
end
local function safe_is_a(instance, class)
    return cloneref(instance):IsA(class)
end

local __game_ok, __game_err = xpcall(function()

local SaveManager, ThemeManager
Library = RequireSharedModule('obsidian_library')
SaveManager = RequireSharedModule('obsidian_save_manager')
ThemeManager = RequireSharedModule('obsidian_theme_manager')

Library.NotifyOnError = false
Library.ShowCustomCursor = false

-- Re-elevate identity per Notify call. Identity does not propagate across
-- task.spawn / task.delay / coroutine.wrap, so callers fired from event
-- connections (most Library:Notify calls in the feature module) can land on a
-- thread whose identity lost Plugin capability between script start and the
-- Notify invocation. Wrap so each call elevates first and absorbs residual
-- capability errors instead of crashing the caller's xpcall.
do
    local OriginalNotify = rawget(Library, 'Notify')
    if type(OriginalNotify) == 'function' then
        Library.Notify = function(self, ...)
            __KiciaHookElevateIdentity()
            local args = table.pack(...)
            local ok, result = pcall(function()
                return OriginalNotify(self, table.unpack(args, 1, args.n))
            end)
            if ok then
                return result
            end
            return nil
        end
    end
end

-- -----------------------------------------------------------------------------
-- Executor support gate
-- -----------------------------------------------------------------------------
-- gate('Feature', 'fn1', 'fn2') returns true when every listed function is
-- genuinely supported; otherwise it notifies once per feature label and returns
-- false. Feature code reaches this via __kicia_hook_genv.KiciaHookCaps. Notices
-- fire only here, when an unsupported feature is actually enabled -- there is
-- deliberately no startup dump of everything the executor is missing.
do
    local Caps = __kicia_hook_genv.KiciaHookCaps
    if type(Caps) == 'table' then
        local NotifiedFeatures = {}
        Caps.gate = function(feature, ...)
            local missing = nil
            for _, name in ipairs({ ... }) do
                if not Caps.has(name) then
                    missing = missing and (missing .. ', ' .. name) or name
                end
            end
            if not missing then
                return true
            end
            if not NotifiedFeatures[feature] then
                NotifiedFeatures[feature] = true
                pcall(function()
                    Library:Notify({ Title = 'Executor Support', Description = feature .. ' won\'t work on this executor -- it doesn\'t have ' .. missing .. '.', Time = 8 })
                end)
            end
            return false
        end
    end
end

local Toggles = Library.Toggles
local Options = Library.Options

local ScriptPaths = RequireSharedModule('script_paths')

SaveManager:SetLibrary(Library)
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder(ScriptPaths.storage_root())

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder(ScriptPaths.storage_root())

ErrorReporter = RequireSharedModule('error_reporter')

-- Wraps every UI callback so one broken feature cannot take down the menu.
-- Errors surface as an on-screen notification (see ErrorReporter) instead of
-- being silently swallowed.
function Library:SafeCallback(Func, ...)
    if not (Func and typeof(Func) == "function") then
        return
    end

    local args = table.pack(...)
    local Result = table.pack(xpcall(function()
        return Func(table.unpack(args, 1, args.n))
    end, function(err)
        local traceback = debug.traceback(tostring(err), 2)
        if ErrorReporter and type(ErrorReporter.report) == 'function' then
            ErrorReporter.report(tostring(err), traceback, 'library_callback')
        end
        return err
    end))

    if not Result[1] then
        return nil
    end

    return table.unpack(Result, 2, Result.n)
end

-- Obsidian's stock Unload does not clear our re-execution guard, so without this
-- wrapper unloading the menu would leave the script permanently unable to start
-- again in the same session.
local function InstallUnloadWrapper()
    function Library:Unload()
        if Library.Unloaded then
            return
        end

        local previousIdentity = nil
        pcall(function()
            if type(getthreadidentity) == 'function' then
                previousIdentity = getthreadidentity()
            end
        end)

        if type(setthreadidentity) == 'function' then
            pcall(setthreadidentity, 7)
        end

        for Index = #Library.Signals, 1, -1 do
            local Connection = table.remove(Library.Signals, Index)
            pcall(function()
                if Connection and Connection.Connected then
                    Connection:Disconnect()
                end
            end)
        end

        for _, Callback in ipairs(Library.UnloadSignals or {}) do
            Library:SafeCallback(Callback)
        end

        Library.Unloaded = true

        if Library.ActiveLoading then
            pcall(function()
                Library.ActiveLoading:Destroy()
            end)
            Library.ActiveLoading = nil
        end

        if Library.ScreenGui then
            pcall(function()
                Library.ScreenGui:Destroy()
            end)
            Library.ScreenGui = nil
        end

        pcall(function()
            __kicia_hook_genv.Library = nil
        end)

        if previousIdentity ~= nil and type(setthreadidentity) == 'function' then
            pcall(setthreadidentity, previousIdentity)
        end
    end
end

InstallUnloadWrapper()

-- -----------------------------------------------------------------------------
-- Anti-AFK
-- -----------------------------------------------------------------------------
-- Two prongs, because answering Idled alone has been observed to fail:
--   * answer every Idled fire with a synthetic keypress (the classic reset),
--   * proactively tap F15 every 5 minutes regardless -- real input as far as the
--     idle tracker is concerned, and bound to nothing in RIVALS, so it can never
--     disturb play.
-- Deliberately NOT registered in the Library signal registry: unloading the menu
-- must not also disable the keepalive. The environment slot keeps reloads from
-- stacking handlers -- each install owns a token, and every loop or connection
-- self-retires once that token moves.
do
    local Players = game:GetService('Players')
    local LocalPlayer = Players.LocalPlayer
    local Token = {}
    local Slot = __kicia_hook_genv.__KiciaHookAntiAfk
    if type(Slot) == 'table' and Slot.Connection then
        pcall(function()
            Slot.Connection:Disconnect()
        end)
    end

    local function Nudge()
        pcall(function()
            local Vim = Instance.new('VirtualInputManager')
            Vim:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
            Vim:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
        end)
    end

    if LocalPlayer then
        local Connection = LocalPlayer.Idled:Connect(Nudge)
        __kicia_hook_genv.__KiciaHookAntiAfk = {
            Token = Token,
            Connection = Connection,
        }
        task.spawn(function()
            while true do
                task.wait(300)
                local Live = __kicia_hook_genv.__KiciaHookAntiAfk
                if type(Live) ~= 'table' or Live.Token ~= Token then
                    return
                end
                Nudge()
            end
        end)
    end
end

-- queue_on_teleport gets no stub above (call sites handle nil), so this local
-- capture is where absence becomes a safe no-op: the auto-execute-on-teleport
-- option must never nil-call on executors that lack it.
local queue_on_teleport = type(queue_on_teleport) == 'function' and queue_on_teleport or function() end
local GameId = game.GameId

local GameName = "Unknown"
for i, v in pairs(Games) do
    if GameId == v.ID then
        GameName = i
        break
    end
end

local TitleTemplate = ScriptPaths.format_title(GameName)

local AutoShowConfig = ScriptPaths.ensure_auto_show_file()

ErrorReporter.set_game(GameName)

    if GameId == Games['RIVALS'].ID and Games['RIVALS'].State then

            local ConnectionRegistry = RequireSharedModule('connection_registry')
            local UISettings = RequireSharedModule('ui_settings')
            local GameBootstrap = RequireSharedModule('game_bootstrap')

            -- Services
            local Players = game:GetService('Players')
            local ReplicatedStorage = game:GetService('ReplicatedStorage')
            local RunService = game:GetService('RunService')
            local UserInputService = game:GetService('UserInputService')
            local Workspace = game:GetService('Workspace')
            local Lighting = game:GetService('Lighting')

            -- Player refs
            local LP = Players.LocalPlayer
            local CurrentRivalsPlace = game['Place' .. 'Id']
            local RIVALS_SHARED_MATCH_PLACE = 129604661913557
            local AimbotInputState = {
                LeftMouse = false,
                RightMouse = false,
                TouchCount = 0,
            }

            -- Suppress synthetic input while the script UI or the Roblox Esc menu
            -- is open (or a textbox is focused) so VIM presses can't hit UI
            -- elements. Never gate mouse/key *releases* on this - a blocked
            -- release leaves the button stuck held. Field on AimbotInputState,
            -- not a local: this scope sits at Luau's 200-local register limit.
            AimbotInputState.SyntheticInputBlocked = function()
                if Library and Library.Toggled then return true end
                if game:GetService('GuiService').MenuIsOpen then return true end
                if UserInputService:GetFocusedTextBox() ~= nil then return true end
                return false
            end
            local AimbotTriggerbotLastShotAt = 0
            local MeleeFastFire = { Enabled = true, IntervalSec = 0, LastShotAt = 0, RagebotStuds = 10, AttackMaxStuds = 15 }
            local AimbotVisibilityCache = setmetatable({}, { __mode = 'k' })
            local AIMBOT_VISIBLE_CACHE_WINDOW = 1 / 30
            local ESP_HIDDEN_CACHE_WINDOW = 1 / 30
            local AIMBOT_HIDDEN_CACHE_WINDOW = 1 / 60
            local TRIGGERBOT_HIDDEN_CACHE_WINDOW = 0
            -- Off-screen targets (Ignore FOV only) must always rank behind every
            -- on-screen target; screen distances are pixels (<1e4), so 1e6 keeps
            -- the two bands disjoint while worldDistance still breaks ties.
            local AIMBOT_OFFSCREEN_SELECTION_PENALTY = 1e6
            local ESP_VISIBILITY_CACHE_PROFILE = {
                Id = 'ESP',
                HiddenWindow = ESP_HIDDEN_CACHE_WINDOW,
                VisibleWindow = AIMBOT_VISIBLE_CACHE_WINDOW,
            }
            -- VisibleWindow stays 0 on aim/trigger profiles: a shot must never fire
            -- from a stale-visible verdict (ce2b135, 19e16b2). The AIMBOT hidden
            -- window is back at its pre-ce2b135 value (1/60, from the peek-reacquire
            -- tuning): caching a hidden verdict for one frame cannot cause a stale
            -- shot, it just stops camera aim / continuous aim / the silent hook from
            -- re-raycasting every occluded player (~13 rays each) several times per
            -- frame. TRIGGERBOT keeps hidden=0 by original design (instant peek fire).
            local AIMBOT_VISIBILITY_CACHE_PROFILE = {
                Id = 'AIMBOT',
                HiddenWindow = AIMBOT_HIDDEN_CACHE_WINDOW,
                VisibleWindow = 0,
            }
            local TRIGGERBOT_VISIBILITY_CACHE_PROFILE = {
                Id = 'TRIGGERBOT',
                HiddenWindow = TRIGGERBOT_HIDDEN_CACHE_WINDOW,
                VisibleWindow = 0,
            }
            local AimbotSilentState = {
                Item = nil,
                LastShot = nil,
                LastShotChangedAt = 0,
                ShotSignalAt = 0,
                ProjectileShotAt = 0,
                HookTarget = nil,
                HookTargetCapturedAt = 0,
                ShotPrimeDepth = 0,
            }
            local AimbotSilentConnections = {
                Shot = nil,
                ProjectileShot = nil,
                HookedItem = nil,
                OriginalStartShooting = nil,
                WrappedStartShooting = nil,
                TriggerbotHoldingMouse = false,
                TriggerbotHoldX = nil,
                TriggerbotHoldY = nil,
                TriggerbotTarget = nil,
                TriggerbotTargetAcquiredAt = 0,
                CameraAimRandomTarget = nil,
                CameraAimRandomPart = nil,
            }
            local AimbotStatusNotification = nil
            local AimbotStatusKey = nil
            local AimbotStatusDescription = nil
            local RuntimeIssueNotification = nil
            local RuntimeIssueDescription = nil
            local RuntimeIssueReportedAt = {}
            local RuntimeIssueNotificationUnavailable = false
            local RIVALS_RUNTIME_ERROR_DEDUPE_WINDOW = 2
            local UpdateRivalsPickupFeatures

            local function DestroyRuntimeIssueNotification()
                if RuntimeIssueNotification and type(RuntimeIssueNotification.Destroy) == 'function' then
                    pcall(function()
                        RuntimeIssueNotification:Destroy()
                    end)
                elseif RuntimeIssueNotification and type(RuntimeIssueNotification.Remove) == 'function' then
                    pcall(function()
                        RuntimeIssueNotification:Remove()
                    end)
                end

                RuntimeIssueNotification = nil
                RuntimeIssueDescription = nil
                RuntimeIssueNotificationUnavailable = false
            end

            local function TryShowRivalsRuntimeIssueNotification(description)
                if RuntimeIssueNotificationUnavailable or not Library or type(Library.Notify) ~= 'function' then
                    return
                end

                if RuntimeIssueNotification then
                    if RuntimeIssueDescription ~= description then
                        local ok = pcall(function()
                            RuntimeIssueNotification:ChangeDescription(description)
                        end)
                        if not ok then
                            RuntimeIssueNotification = nil
                            RuntimeIssueNotificationUnavailable = true
                        end
                    end
                    return
                end

                local ok, notification = pcall(function()
                    return Library:Notify({
                        Title = 'RIVALS',
                        Description = description,
                        Persist = true,
                    })
                end)
                if ok then
                    RuntimeIssueNotification = notification
                else
                    RuntimeIssueNotification = nil
                    RuntimeIssueNotificationUnavailable = true
                end
            end

            local function ReportRivalsRuntimeIssue(feature, tracebackMessage)
                local tracebackText = tostring(tracebackMessage or 'Unknown error')
                local errorMessage = tracebackText:match('([^\n]+)') or tracebackText
                local description = string.format('%s: %s', tostring(feature or 'runtime'), errorMessage)
                local now = tick()
                local lastReportedAt = RuntimeIssueReportedAt[description]
                if lastReportedAt and (now - lastReportedAt) < RIVALS_RUNTIME_ERROR_DEDUPE_WINDOW then
                    return
                end
                RuntimeIssueReportedAt[description] = now

                TryShowRivalsRuntimeIssueNotification(description)
                RuntimeIssueDescription = description

                if ErrorReporter and type(ErrorReporter.report) == 'function' then
                    pcall(function()
                        ErrorReporter.report(errorMessage, tracebackText, string.format('rivals_%s', tostring(feature or 'runtime')))
                    end)
                end
            end

            local function GuardRivalsCallback(feature, callback)
                return function(...)
                    local args = table.pack(...)
                    local ok, result = xpcall(function()
                        return callback(table.unpack(args, 1, args.n))
                    end, function(err)
                        return debug.traceback(string.format('[%s] %s', tostring(feature), tostring(err)), 2)
                    end)
                    if not ok then
                        ReportRivalsRuntimeIssue(feature, result)
                        return nil
                    end
                    return result
                end
            end

            local Char, Humanoid, HumanoidRootPart
            local function InitCharacter()
                Char = LP.Character
                if not Char then
                    Humanoid = nil
                    HumanoidRootPart = nil
                    return false
                end
                Humanoid = Char:FindFirstChildOfClass('Humanoid')
                HumanoidRootPart = Char:FindFirstChild('HumanoidRootPart')
                return Humanoid ~= nil and HumanoidRootPart ~= nil
            end

            local function IsAimbotCameraBoundToLocalCharacter(camera)
                if not camera or not Char or LP.Character ~= Char then
                    return false
                end

                local subject = camera.CameraSubject
                if not subject then
                    return false
                end

                return subject == Char or subject:IsDescendantOf(Char)
            end

            local function IsAimbotCameraReady()
                local camera = Workspace.CurrentCamera
                if not camera then
                    return false
                end

                if not InitCharacter() or LP.Character ~= Char then
                    return false
                end

                if not Humanoid or Humanoid.Health <= 0 then
                    return false
                end

                if HumanoidRootPart and HumanoidRootPart.Anchored then
                    return false
                end

                if not IsAimbotCameraBoundToLocalCharacter(camera) then
                    return false
                end

                return true
            end

            -- =============================================
            -- Weapon Info (Replicated Client State)
            -- =============================================

            local PlayerDataController = nil
            local EnumLibrary = nil
            local FighterController = nil
            local EnemyController = nil
            local ReplicatedStateReady = false
            local ReplicatedStateBootStarted = false
            local WeaponInfoCache = {}
            local WeaponInfoConnections = {}
            local WeaponInfoTrackingConnected = false
            local WeaponInfoTrackingRetryPending = false
            local TrackedFightersByPlayer = {}
            local FighterDataCache = {
                Cache = {},
                Connections = {},
                LocalDuel = {
                    IsInDuel = false,
                    IsInShootingRange = false,
                    AttachedFighter = nil,
                    DuelConn = nil,
                    ShootingConn = nil,
                    Seeded = false,
                },
                OnLocalDuelChanged = nil,
                LocalLoadout = {
                    EquippedItem = nil,
                    Seeded = false,
                },
            }
            local TrackedRangeTargets = {}
            local TrackedPracticeDummies = {}
            local TrackedEnemies = setmetatable({}, { __mode = 'k' })
            local AimbotPlayerTrackingConnected = false
            local AimbotEnemyTrackingConnected = false
            local LocalFighterController = nil
            local Connections = nil
            local DEFAULT_ESP_MAX_DISTANCE = 1000
            local DEFAULT_ESP_TEXT_SIZE = 16
            local PLAYER_CARD_THEME = {
                HorizontalBarWidth = 48,
                HorizontalBarOffsetY = 0,
                HorizontalBarTextPadding = 0,
                HorizontalBarTextPaddingY = 0,
                NameOffsetY = -2,
                BarTopGap = 2,
                BarHeight = 17,
                BarRadius = 11,
                VerticalBarTextGap = 4,
                MinLift = 20,
                MaxLift = 50,
                FrameColor = Color3.fromRGB(4, 5, 7),
                NameColor = Color3.fromRGB(252, 252, 252),
                MetaColor = Color3.fromRGB(196, 203, 212),
                BarTextColor = Color3.fromRGB(248, 250, 252),
                ShadowColor = Color3.fromRGB(8, 10, 14),
                BarBackgroundColor = Color3.fromRGB(20, 24, 31),
                BarLowColor = Color3.fromRGB(233, 86, 74),
                BarMidColor = Color3.fromRGB(244, 210, 72),
                BarHighColor = Color3.fromRGB(100, 255, 50),
                BarBackgroundTransparency = 0.85,
                BarInset = 1,
                BarTextInset = 8,
                ArrowTransparency = 0.9,
                ArrowThickness = 2,
                ArrowLength = 18,
                ArrowWidth = 8,
                ArrowEdgeScale = 0.35,
                LookLineTransparency = 0.42,
                ThrowableTextTransparency = 0.95,
            }
            PLAYER_CARD_THEME.Classic = {
                BoxOutlineColor = Color3.fromRGB(4, 5, 7),
                BoxOutlineTransparency = 0.82,
                BoxOutlineThickness = 3,
                BoxThickness = 1,
                BarWidth = 4,
                BarHeight = 4,
                BarGap = 3,
                BarInset = 1,
                SmoothSpeed = 24,
                ReactiveLowColor = Color3.new(1, 1, 1),
            }
            local AimbotFovCircle = Drawing.new('Circle')
            AimbotFovCircle.Filled = false
            AimbotFovCircle.NumSides = 48
            AimbotFovCircle.Thickness = 1.5
            AimbotFovCircle.Transparency = 0.72
            AimbotFovCircle.Color = Color3.fromRGB(255, 70, 70)
            AimbotFovCircle.Visible = false
            local MODEL_BOUNDS_SIGNS = {-1, 1}
            -- Declared before RivalsModsState so its functions (RefreshViewmodelEffects,
            -- RestoreClientModifiers) capture this local, not a nil global. Populated below.
            local RivalsRuntimeBridge = {}
            RivalsRuntimeBridge.PlayerStatusInfoCache = {}
            RivalsRuntimeBridge.EspRankProfileCache = nil
            RivalsRuntimeBridge.ESPClassic = {}
            RivalsRuntimeBridge.EspPreviewState = nil
            local RivalsModsState = {
                GunModule = nil,
                MeleeModule = nil,
                GunbladeModule = nil,
                CameraController = nil,
                CameraShakeOriginalEnabled = nil,
                CameraThirdPersonCaptured = false,
                CameraThirdPersonOriginal = nil,
                CameraViewModelOriginal = nil,
                MotionSpringValues = {
                    _sliding_spring = 0,
                    _sprinting_spring = 0,
                    _bobbing_speed_spring = 0,
                    _bobbing_value_spring = Vector2.zero,
                    _landing_spring = 0,
                    _jump_spring = 0,
                    _tilt_spring = Vector2.zero,
                    _impulse_position_spring = Vector3.zero,
                    _recoil_spring = Vector3.zero,
                    _unrecoil_spring = Vector3.zero,
                },
                InfoModifierFighter = nil,
                InfoModifierItemAdded = nil,
                InfoModifierItemRemoved = nil,
                OriginalItemInfo = setmetatable({}, { __mode = 'k' }),
                PendingEnsureHooks = false,
                NoSpreadClientItem = nil,
                NoSpreadRemote = nil,
                KiciaInputHookPrototype = nil,
                KiciaInputHook = nil,
                NoSpreadController = nil,
                NoSpreadPlayerContext = nil,
                GrenadeFuseController = nil,
                OriginalGunStartShooting = nil,
                OriginalMeleeStartShooting = nil,
                OriginalGunbladeStartShooting = nil,
                OriginalGunStartReloading = nil,
                OriginalGunRecoil = nil,
                OriginalGunGetAimSpeed = nil,
                OriginalGunEquip = nil,
            }

            local function BlendColor(color, target, alpha)
                return Color3.new(
                    color.R + ((target.R - color.R) * alpha),
                    color.G + ((target.G - color.G) * alpha),
                    color.B + ((target.B - color.B) * alpha)
                )
            end

            local function CreateRoundedRect()
                local rect = {
                    horizontal = Drawing.new('Square'),
                    vertical = Drawing.new('Square'),
                    tl = Drawing.new('Circle'),
                    tr = Drawing.new('Circle'),
                    bl = Drawing.new('Circle'),
                    br = Drawing.new('Circle'),
                }

                rect.horizontal.Filled = true
                rect.horizontal.Visible = false
                rect.vertical.Filled = true
                rect.vertical.Visible = false

                for _, key in ipairs({'tl', 'tr', 'bl', 'br'}) do
                    local corner = rect[key]
                    corner.Filled = true
                    corner.NumSides = 18
                    corner.Visible = false
                end

                return rect
            end

            local function HideRoundedRect(rect)
                rect.horizontal.Visible = false
                rect.vertical.Visible = false
                rect.tl.Visible = false
                rect.tr.Visible = false
                rect.bl.Visible = false
                rect.br.Visible = false
            end

            local function RemoveRoundedRect(rect)
                pcall(function() rect.horizontal:Remove() end)
                pcall(function() rect.vertical:Remove() end)
                pcall(function() rect.tl:Remove() end)
                pcall(function() rect.tr:Remove() end)
                pcall(function() rect.bl:Remove() end)
                pcall(function() rect.br:Remove() end)
            end

            local function CreateArrowIndicator()
                local arrow = {
                    left = Drawing.new('Line'),
                    right = Drawing.new('Line'),
                    base = Drawing.new('Line'),
                }

                for _, key in ipairs({'left', 'right', 'base'}) do
                    local segment = arrow[key]
                    segment.Thickness = PLAYER_CARD_THEME.ArrowThickness
                    segment.Transparency = PLAYER_CARD_THEME.ArrowTransparency
                    segment.Visible = false
                end

                return arrow
            end

            local function HideArrowIndicator(arrow)
                arrow.left.Visible = false
                arrow.right.Visible = false
                arrow.base.Visible = false
            end

            local function RemoveArrowIndicator(arrow)
                pcall(function() arrow.left:Remove() end)
                pcall(function() arrow.right:Remove() end)
                pcall(function() arrow.base:Remove() end)
            end

            local function DrawArrowIndicator(arrow, center, direction, color, scale)
                local magnitude = direction.Magnitude
                if magnitude <= 0 then
                    HideArrowIndicator(arrow)
                    return
                end

                scale = scale or 1
                local arrowLength = PLAYER_CARD_THEME.ArrowLength * scale
                local arrowWidth = PLAYER_CARD_THEME.ArrowWidth * scale
                local arrowThickness = math.max(PLAYER_CARD_THEME.ArrowThickness * scale, 1)

                local forward = direction / magnitude
                local right = Vector2.new(-forward.Y, forward.X)
                local tip = center + (forward * arrowLength * 0.5)
                local baseCenter = center - (forward * arrowLength * 0.5)
                local leftPoint = baseCenter - (right * arrowWidth)
                local rightPoint = baseCenter + (right * arrowWidth)

                arrow.left.From = leftPoint
                arrow.left.To = tip
                arrow.right.From = tip
                arrow.right.To = rightPoint
                arrow.base.From = rightPoint
                arrow.base.To = leftPoint

                for _, key in ipairs({'left', 'right', 'base'}) do
                    local segment = arrow[key]
                    segment.Color = color
                    segment.Thickness = arrowThickness
                    segment.Visible = true
                end
            end

            local function SetDrawingVisible(drawable, visible)
                if drawable.Visible ~= visible then
                    drawable.Visible = visible
                end
            end

            local function SetDrawingTextState(drawable, visible, textValue, textSize, centered, color, font)
                SetDrawingVisible(drawable, visible)
                if not visible then
                    return
                end

                if drawable.Text ~= textValue then
                    drawable.Text = textValue
                end
                local roundedSize = math.round(textSize)
                if drawable.Size ~= roundedSize then
                    drawable.Size = roundedSize
                end
                if drawable.Center ~= centered then
                    drawable.Center = centered
                end
                if drawable.Color ~= color then
                    drawable.Color = color
                end
                if font ~= nil and drawable.Font ~= font then
                    drawable.Font = font
                end
            end

            local function SetRoundedRect(rect, x, y, width, height, radius, color, transparency)
                if width <= 0 or height <= 0 then
                    HideRoundedRect(rect)
                    return
                end

                local r = math.floor(math.max(0, math.min(radius, width * 0.5, height * 0.5)))
                if r == 0 then
                    rect.horizontal.Color = color
                    rect.horizontal.Transparency = transparency
                    rect.horizontal.Position = Vector2.new(x, y)
                    rect.horizontal.Size = Vector2.new(width, height)
                    rect.horizontal.Visible = true
                    rect.vertical.Visible = false
                    rect.tl.Visible = false
                    rect.tr.Visible = false
                    rect.bl.Visible = false
                    rect.br.Visible = false
                    return
                end

                local innerWidth = math.max(width - (r * 2), 0)
                local innerHeight = math.max(height - (r * 2), 0)

                rect.horizontal.Color = color
                rect.horizontal.Transparency = transparency
                rect.horizontal.Visible = innerWidth > 0
                if innerWidth > 0 then
                    rect.horizontal.Position = Vector2.new(x + r, y)
                    rect.horizontal.Size = Vector2.new(innerWidth, height)
                end

                rect.vertical.Color = color
                rect.vertical.Transparency = transparency
                rect.vertical.Visible = innerHeight > 0
                if innerHeight > 0 then
                    rect.vertical.Position = Vector2.new(x, y + r)
                    rect.vertical.Size = Vector2.new(width, innerHeight)
                end

                local showCorners = r > 0
                for _, key in ipairs({'tl', 'tr', 'bl', 'br'}) do
                    local corner = rect[key]
                    corner.Color = color
                    corner.Transparency = transparency
                    corner.Visible = showCorners
                    if showCorners then
                        corner.Radius = r
                    end
                end

                if showCorners then
                    rect.tl.Position = Vector2.new(x + r, y + r)
                    rect.tr.Position = Vector2.new(x + width - r, y + r)
                    rect.bl.Position = Vector2.new(x + r, y + height - r)
                    rect.br.Position = Vector2.new(x + width - r, y + height - r)
                end
            end

            local function ResolvePlayerDataController()
                if PlayerDataController then
                    return PlayerDataController
                end

                local playerScripts = LP:WaitForChild('PlayerScripts')
                local controllers = playerScripts:WaitForChild('Controllers')
                local playerDataControllerModule = controllers:WaitForChild('PlayerDataController')

                local ok, controller = pcall(require, playerDataControllerModule)
                if not ok then
                    return nil
                end

                PlayerDataController = controller
                return PlayerDataController
            end

            local function IsPlayerDataControllerReady()
                local playerDataController = ResolvePlayerDataController()
                return playerDataController ~= nil and playerDataController.CurrentData ~= nil
            end

            local function ResolveEnumLibrary()
                if EnumLibrary then
                    return EnumLibrary
                end

                local replicatedStorage = game:GetService('ReplicatedStorage')
                local modules = replicatedStorage:WaitForChild('Modules')
                local enumLibraryModule = modules:WaitForChild('EnumLibrary')

                local ok, library = pcall(require, enumLibraryModule)
                if not ok then
                    return nil
                end

                EnumLibrary = library
                return EnumLibrary
            end

            local function BeginReplicatedStateBoot()
                if ReplicatedStateBootStarted then
                    return
                end

                ReplicatedStateBootStarted = true

                task.spawn(GuardRivalsCallback('ReplicatedStateBoot', function()
                    -- EnumLibrary is populated by the game's external enum builder.
                    -- Requiring any PlayerScripts controller before that builder has
                    -- finished starts ReplicatedController with an incomplete
                    -- _from_enum table and makes FromEnum assert on valid tokens.
                    local enumLibrary = ResolveEnumLibrary()
                    if not enumLibrary then
                        return
                    end

                    if type(enumLibrary.WaitForEnumBuilder) == 'function' then
                        enumLibrary:WaitForEnumBuilder()
                    elseif enumLibrary._enum_builder_complete ~= true then
                        return
                    end

                    local playerDataController = ResolvePlayerDataController()
                    if not playerDataController then
                        return
                    end

                    if type(playerDataController.WaitUntilLoaded) == 'function' then
                        playerDataController:WaitUntilLoaded()
                    elseif not IsPlayerDataControllerReady() then
                        return
                    end

                    task.wait(2)
                    ReplicatedStateReady = true

                    local state = RivalsModsState
                    if state.PendingEnsureHooks and type(RivalsModsState.EnsureHooks) == 'function' then
                        task.defer(RivalsModsState.EnsureHooks)
                    end
                end))
            end

            local function IsReplicatedStateReady()
                BeginReplicatedStateBoot()
                return ReplicatedStateReady
            end

            local function ResolveFighterController()
                if FighterController then
                    return FighterController
                end

                if not ReplicatedStateReady then
                    BeginReplicatedStateBoot()
                    return nil
                end

                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local controllers = playerScripts and playerScripts:FindFirstChild('Controllers')
                local fighterControllerModule = controllers and controllers:FindFirstChild('FighterController')
                if not fighterControllerModule then
                    return nil
                end

                local ok, controller = pcall(require, fighterControllerModule)
                if not ok then
                    return nil
                end

                FighterController = controller
                return FighterController
            end

            local function ResolveEnemyController()
                if EnemyController then
                    return EnemyController
                end

                if not ReplicatedStateReady then
                    BeginReplicatedStateBoot()
                    return nil
                end

                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local controllers = playerScripts and playerScripts:FindFirstChild('Controllers')
                local enemyControllerModule = controllers and controllers:FindFirstChild('EnemyController')
                if not enemyControllerModule then
                    return nil
                end

                local ok, controller = pcall(require, enemyControllerModule)
                if not ok then
                    return nil
                end

                EnemyController = controller
                return EnemyController
            end

            local function ReadItemValue(item, key)
                if not item or type(item.Get) ~= 'function' then
                    return nil
                end

                local ok, value = pcall(item.Get, item, key)
                if not ok then
                    return nil
                end

                return value
            end

            local function ResolveLocalFighter()
                local fighterController = ResolveFighterController()
                if not fighterController then
                    return nil
                end

                if fighterController.LocalFighter then
                    return fighterController.LocalFighter
                end

                if type(fighterController.GetFighter) ~= 'function' then
                    return nil
                end

                local fighter = fighterController:GetFighter(LP)
                if fighter then
                    return fighter
                end

                if LP.Character then
                    fighter = fighterController:GetFighter(LP.Character)
                    if fighter then
                        return fighter
                    end
                end

                return nil
            end

            local function ReadFighterValue(fighter, key)
                if not fighter or type(fighter.Get) ~= 'function' then
                    return nil
                end

                local ok, value = pcall(fighter.Get, fighter, key)
                if not ok then
                    return nil
                end

                return value
            end

            local AIMBOT_RIOT_SHIELD_ITEM_NAMES = {
                ['Riot Shield'] = true,
            }

            local AIMBOT_RIOT_SHIELD_FRONT_DOT_THRESHOLD = 0.0
            local AIMBOT_RIOT_SHIELD_BACK_DOT_THRESHOLD = 0.0

            local function ResolveRivalsInventoryItemName(item)
                local itemType = typeof(item)
                if itemType == 'string' then
                    return item ~= '' and item or nil
                end

                if itemType == 'Instance' then
                    return item.Name ~= '' and item.Name or nil
                end

                if itemType ~= 'table' then
                    return nil
                end

                if type(item.Name) == 'string' and item.Name ~= '' then
                    return item.Name
                end

                local info = item.Info
                if type(info) == 'table' and type(info.Name) == 'string' and info.Name ~= '' then
                    return info.Name
                end

                if type(item.ItemName) == 'string' and item.ItemName ~= '' then
                    return item.ItemName
                end

                if type(item.Type) == 'string' and item.Type ~= '' then
                    return item.Type
                end

                return nil
            end

            local function ReadRivalsFighterInventory(fighter)
                if not fighter then
                    return nil
                end

                return fighter.Loadout or fighter.Slots or fighter.Items or fighter.EquippedItems
            end

            local function ResolveRivalsFighterLoadoutNames(fighter)
                local loadoutNames = {}
                local function addName(name)
                    if type(name) == 'string' and name ~= '' then
                        loadoutNames[name] = true
                    end
                end

                local inventory = ReadRivalsFighterInventory(fighter)
                if type(inventory) == 'table' then
                    for _, item in pairs(inventory) do
                        addName(ResolveRivalsInventoryItemName(item))
                    end
                end

                local lastPickedWeapons = fighter and fighter.Data and fighter.Data.LastPickedWeapons
                if type(lastPickedWeapons) == 'table' then
                    for _, itemName in ipairs(lastPickedWeapons) do
                        addName(itemName)
                    end
                end

                return loadoutNames
            end

            local function ResolveRivalsFighterEquippedItemName(fighter)
                local equippedName = ResolveRivalsInventoryItemName(fighter and fighter.EquippedItem)
                if equippedName then
                    return equippedName
                end

                local equippedItemId = fighter and fighter.Data and fighter.Data.EquippedItemID
                if type(equippedItemId) ~= 'string' or equippedItemId == '' then
                    return nil
                end

                local inventory = ReadRivalsFighterInventory(fighter)
                if type(inventory) ~= 'table' then
                    return nil
                end

                for _, item in pairs(inventory) do
                    if type(item) == 'table' then
                        local itemId = ReadItemValue(item, 'ObjectID')
                        if itemId == nil and type(item.Data) == 'table' then
                            itemId = item.Data.ObjectID
                        end

                        if itemId == equippedItemId then
                            return ResolveRivalsInventoryItemName(item)
                        end
                    end
                end

                return nil
            end

            local function EvaluateRivalsRiotShieldChecker(player, character, observerPosition)
                observerPosition = typeof(observerPosition) == 'Vector3' and observerPosition or (HumanoidRootPart and HumanoidRootPart.Position)
                if not player or typeof(observerPosition) ~= 'Vector3' then
                    return nil
                end

                character = character or player.Character
                local rootPart = character and character:FindFirstChild('HumanoidRootPart')
                if not character or not rootPart or not rootPart.Parent then
                    return nil
                end

                local fighter = TrackedFightersByPlayer[player]
                if not fighter then
                    local fighterController = ResolveFighterController()
                    if fighterController and type(fighterController.GetFighter) == 'function' then
                        fighter = fighterController:GetFighter(player)
                        if not fighter then
                            fighter = fighterController:GetFighter(character)
                        end
                    end
                end

                if not fighter then
                    return nil
                end

                local loadoutNames = ResolveRivalsFighterLoadoutNames(fighter)
                local hasShieldInLoadout = loadoutNames['Riot Shield'] == true
                local equippedName = ResolveRivalsFighterEquippedItemName(fighter)
                local isShieldEquipped = nil
                if equippedName then
                    isShieldEquipped = AIMBOT_RIOT_SHIELD_ITEM_NAMES[equippedName] == true
                end

                local directionToLocal = observerPosition - rootPart.Position
                if directionToLocal.Magnitude > 0.001 then
                    directionToLocal = directionToLocal.Unit
                else
                    directionToLocal = rootPart.CFrame.LookVector
                end

                local facingDot = rootPart.CFrame.LookVector:Dot(directionToLocal)
                local blocksFromFront = false
                if isShieldEquipped == true and facingDot >= AIMBOT_RIOT_SHIELD_FRONT_DOT_THRESHOLD then
                    blocksFromFront = true
                end

                local blocksFromBack = false
                if hasShieldInLoadout and isShieldEquipped == false and facingDot <= AIMBOT_RIOT_SHIELD_BACK_DOT_THRESHOLD then
                    blocksFromBack = true
                end

                return {
                    Fighter = fighter,
                    Character = character,
                    EquippedItemName = equippedName,
                    HasShieldInLoadout = hasShieldInLoadout,
                    IsShieldEquipped = isShieldEquipped,
                    IsShieldEquippedKnown = isShieldEquipped ~= nil,
                    FacingDot = facingDot,
                    BlocksFromFront = blocksFromFront,
                    BlocksFromBack = blocksFromBack,
                    IgnoreTarget = blocksFromFront or blocksFromBack,
                }
            end

            local function ShouldIgnoreRivalsRiotShieldTarget(player, character, localItem, observerPosition)
                if not player or not (Toggles.P2S1T9 and Toggles.P2S1T9.Value == true) then
                    return false
                end

                local localItemName = localItem and localItem.Name
                if localItemName == 'Flamethrower'
                    or localItemName == 'Exogun'
                    or localItemName == 'Spray'
                    or localItemName == 'Chainsaw'
                    or localItemName == 'Grenade Launcher' then
                    return false
                end

                local shieldState = EvaluateRivalsRiotShieldChecker(player, character, observerPosition)
                return shieldState and shieldState.IgnoreTarget == true
            end

            function FighterDataCache.ReadEntity(entity)
                if not entity then
                    return false
                end
                local data = entity.Data
                if type(data) == 'table' then
                    return data.IsInvincible == true
                end
                return false
            end

            function FighterDataCache.Attach(fighter, entity)
                local conns = FighterDataCache.Connections[fighter]
                if conns and conns.entityChanged and type(conns.entityChanged.Disconnect) == 'function' then
                    pcall(function() conns.entityChanged:Disconnect() end)
                    conns.entityChanged = nil
                end

                if not entity then
                    FighterDataCache.Cache[fighter] = false
                    return
                end

                FighterDataCache.Cache[fighter] = FighterDataCache.ReadEntity(entity)

                if type(entity.GetDataChangedSignal) ~= 'function' then
                    return
                end

                local ok, signal = pcall(entity.GetDataChangedSignal, entity, 'IsInvincible')
                if not ok or type(signal) ~= 'table' or type(signal.Connect) ~= 'function' then
                    return
                end

                conns = FighterDataCache.Connections[fighter] or {}
                conns.entityChanged = signal:Connect(function(newValue)
                    FighterDataCache.Cache[fighter] = newValue == true
                end)
                FighterDataCache.Connections[fighter] = conns
            end

            function FighterDataCache.Track(fighter)
                if not fighter then
                    return
                end

                local conns = FighterDataCache.Connections[fighter] or {}
                FighterDataCache.Connections[fighter] = conns

                FighterDataCache.Attach(fighter, fighter.Entity)

                if not conns.entityAdded and type(fighter.EntityAdded) == 'table' and type(fighter.EntityAdded.Connect) == 'function' then
                    conns.entityAdded = fighter.EntityAdded:Connect(function(newEntity)
                        FighterDataCache.Attach(fighter, newEntity)
                    end)
                end

                if not conns.entityRemoved and type(fighter.EntityRemoved) == 'table' and type(fighter.EntityRemoved.Connect) == 'function' then
                    conns.entityRemoved = fighter.EntityRemoved:Connect(function()
                        FighterDataCache.Cache[fighter] = false
                        local existing = FighterDataCache.Connections[fighter]
                        if existing and existing.entityChanged and type(existing.entityChanged.Disconnect) == 'function' then
                            pcall(function() existing.entityChanged:Disconnect() end)
                            existing.entityChanged = nil
                        end
                    end)
                end
            end

            function FighterDataCache.Untrack(fighter)
                if not fighter then
                    return
                end

                local conns = FighterDataCache.Connections[fighter]
                if conns then
                    for key, conn in pairs(conns) do
                        if conn and type(conn.Disconnect) == 'function' then
                            pcall(function() conn:Disconnect() end)
                        end
                        conns[key] = nil
                    end
                end
                FighterDataCache.Connections[fighter] = nil
                FighterDataCache.Cache[fighter] = nil
            end

            function FighterDataCache.AttachLocalDuelWatchers(fighter)
                if not fighter then
                    return
                end

                local state = FighterDataCache.LocalDuel
                if state.AttachedFighter == fighter then
                    return
                end

                if state.DuelConn and type(state.DuelConn.Disconnect) == 'function' then
                    pcall(function() state.DuelConn:Disconnect() end)
                end
                if state.ShootingConn and type(state.ShootingConn.Disconnect) == 'function' then
                    pcall(function() state.ShootingConn:Disconnect() end)
                end
                state.DuelConn = nil
                state.ShootingConn = nil
                state.AttachedFighter = fighter

                local data = fighter.Data
                if type(data) == 'table' then
                    state.IsInDuel = data.IsInDuel == true
                    state.IsInShootingRange = data.IsInShootingRange == true
                else
                    state.IsInDuel = false
                    state.IsInShootingRange = false
                end

                if type(fighter.GetDataChangedSignal) ~= 'function' then
                    state.Seeded = true
                    return
                end

                local okDuel, sigDuel = pcall(fighter.GetDataChangedSignal, fighter, 'IsInDuel')
                if okDuel and type(sigDuel) == 'table' and type(sigDuel.Connect) == 'function' then
                    state.DuelConn = sigDuel:Connect(function(newValue)
                        local previousIsInDuel = FighterDataCache.LocalDuel.IsInDuel
                        FighterDataCache.LocalDuel.IsInDuel = newValue == true
                        local onDuelChanged = FighterDataCache.OnLocalDuelChanged
                        if type(onDuelChanged) == 'function' then
                            pcall(onDuelChanged, newValue == true, previousIsInDuel == true)
                        end
                    end)
                end

                local okShooting, sigShooting = pcall(fighter.GetDataChangedSignal, fighter, 'IsInShootingRange')
                if okShooting and type(sigShooting) == 'table' and type(sigShooting.Connect) == 'function' then
                    state.ShootingConn = sigShooting:Connect(function(newValue)
                        FighterDataCache.LocalDuel.IsInShootingRange = newValue == true
                    end)
                end

                state.Seeded = true
            end

            local function RegisterAimbotFighter(fighter)
                local player = fighter and fighter.Player
                if not player or player == LP then
                    return
                end

                TrackedFightersByPlayer[player] = fighter
                FighterDataCache.Track(fighter)
            end

            local function UnregisterAimbotFighter(fighter)
                local player = fighter and fighter.Player
                if not player then
                    return
                end

                if TrackedFightersByPlayer[player] == fighter then
                    FighterDataCache.Untrack(fighter)
                    TrackedFightersByPlayer[player] = nil
                end
            end

            local function ResolveAimbotEnemyTargetType(enemy)
                local model = enemy and enemy.Model
                if not model then
                    return nil, nil
                end

                if model.Name == 'Target' then
                    return model, 'Range Targets'
                end

                if model.Name == 'Dummy' or model.Name == 'DPS Dummy' then
                    return model, 'Practice Dummies'
                end

                return nil, nil
            end

            local function RegisterAimbotEnemy(enemy)
                local model, targetType = ResolveAimbotEnemyTargetType(enemy)
                if not model or not targetType then
                    return
                end

                TrackedEnemies[enemy] = {
                    model = model,
                    targetType = targetType,
                }

                if targetType == 'Range Targets' then
                    TrackedRangeTargets[model] = true
                    TrackedPracticeDummies[model] = nil
                else
                    TrackedPracticeDummies[model] = true
                    TrackedRangeTargets[model] = nil
                end
            end

            local function UnregisterAimbotEnemy(enemy)
                local tracked = TrackedEnemies[enemy]
                if tracked then
                    if tracked.targetType == 'Range Targets' then
                        TrackedRangeTargets[tracked.model] = nil
                    else
                        TrackedPracticeDummies[tracked.model] = nil
                    end
                    TrackedEnemies[enemy] = nil
                    return
                end

                local model, targetType = ResolveAimbotEnemyTargetType(enemy)
                if not model or not targetType then
                    return
                end

                if targetType == 'Range Targets' then
                    TrackedRangeTargets[model] = nil
                else
                    TrackedPracticeDummies[model] = nil
                end
            end

            local function EnsureAimbotTargetTracking()
                if not Connections then
                    return
                end

                if not AimbotPlayerTrackingConnected then
                    local fighterController = ResolveFighterController()
                    if fighterController then
                        LocalFighterController = fighterController
                        for _, fighter in ipairs(fighterController.Objects or {}) do
                            RegisterAimbotFighter(fighter)
                        end

                        if fighterController.ObjectAdded and type(fighterController.ObjectAdded.Connect) == 'function' then
                            Connections:register('Aimbot_FighterObjectAdded', fighterController.ObjectAdded:Connect(GuardRivalsCallback('Aimbot_FighterObjectAdded', RegisterAimbotFighter)))
                        end

                        if fighterController.ObjectRemoved and type(fighterController.ObjectRemoved.Connect) == 'function' then
                            Connections:register('Aimbot_FighterObjectRemoved', fighterController.ObjectRemoved:Connect(GuardRivalsCallback('Aimbot_FighterObjectRemoved', UnregisterAimbotFighter)))
                        end

                        AimbotPlayerTrackingConnected = true
                    end
                end

                if not AimbotEnemyTrackingConnected then
                    local enemyController = ResolveEnemyController()
                    if enemyController then
                        for _, enemy in ipairs(enemyController.Objects or {}) do
                            RegisterAimbotEnemy(enemy)
                        end

                        if enemyController.ObjectAdded and type(enemyController.ObjectAdded.Connect) == 'function' then
                            Connections:register('Aimbot_EnemyObjectAdded', enemyController.ObjectAdded:Connect(GuardRivalsCallback('Aimbot_EnemyObjectAdded', RegisterAimbotEnemy)))
                        end

                        if enemyController.ObjectRemoved and type(enemyController.ObjectRemoved.Connect) == 'function' then
                            Connections:register('Aimbot_EnemyObjectRemoved', enemyController.ObjectRemoved:Connect(GuardRivalsCallback('Aimbot_EnemyObjectRemoved', UnregisterAimbotEnemy)))
                        end

                        AimbotEnemyTrackingConnected = true
                    end
                end
            end

            local function IsAimbotGameReady()
                local fighter = ResolveLocalFighter()
                if not fighter then
                    return false
                end

                local entity = fighter.Entity
                local model = entity and entity.Model
                if not model or model ~= LP.Character then
                    return false
                end

                local duelState = FighterDataCache.LocalDuel
                if duelState.Seeded then
                    if not duelState.IsInDuel and not duelState.IsInShootingRange then
                        return false
                    end
                else
                    if ReadFighterValue(fighter, 'IsInDuel') ~= true and ReadFighterValue(fighter, 'IsInShootingRange') ~= true then
                        return false
                    end
                end

                return true
            end

            local function FormatAmmoValue(value)
                if type(value) ~= 'number' then
                    return nil
                end

                if value == math.huge then
                    return 'INF'
                end

                return tostring(math.max(0, math.floor(value + 0.5)))
            end

            local function BuildWeaponInfoText(weaponInfo)
                if not weaponInfo then
                    return nil
                end

                local segments = {}
                if weaponInfo.label and weaponInfo.label ~= '' then
                    segments[#segments + 1] = weaponInfo.label
                end
                if weaponInfo.ammoText and weaponInfo.ammoText ~= '' then
                    segments[#segments + 1] = weaponInfo.ammoText
                end

                if #segments == 0 then
                    return nil
                end

                return table.concat(segments, ' | ')
            end

            local function ReadWeaponInfo(player)
                local observer = WeaponInfoConnections[player]
                local item = observer and observer.Item
                if not item then
                    return nil
                end

                local ammo = observer.Ammo
                local ammoText = FormatAmmoValue(observer.Ammo)
                local reserveText = FormatAmmoValue(observer.AmmoReserve)
                local formattedAmmoText
                local maxAmmo = nil
                pcall(function()
                    maxAmmo = item.Info and item.Info.MaxAmmo or nil
                end)

                if ammoText and reserveText then
                    formattedAmmoText = string.format('%s/%s', ammoText, reserveText)
                else
                    formattedAmmoText = ammoText or reserveText
                end

                local reloadCooldown = rawget(item, '_reload_cooldown')
                local reloadRemaining = type(reloadCooldown) == 'number' and (reloadCooldown - tick()) or -1
                local isReloading = reloadRemaining > 0
                    and item.Info ~= nil
                    and item.Info.ReloadType ~= nil
                local label = isReloading and '*Reloading*' or item.Name
                local displayText = BuildWeaponInfoText({
                    label = label,
                    ammoText = formattedAmmoText,
                })

                if displayText and displayText ~= '' then
                    return {
                        label = label,
                        ammoText = formattedAmmoText,
                        displayText = displayText,
                        isReloading = isReloading,
                        ammo = ammo,
                        maxAmmo = maxAmmo,
                    }
                end

                return nil
            end

            local function InvalidateWeaponInfo(player)
                WeaponInfoCache[player] = nil
            end

            local function DisconnectWeaponInfoConnection(observer, key)
                if not observer then
                    return
                end

                local connection = observer[key]
                if connection then
                    pcall(function()
                        connection:Disconnect()
                    end)
                    observer[key] = nil
                end
            end

            local function DisconnectWeaponInfoConnections(player)
                local observer = WeaponInfoConnections[player]
                if not observer then
                    return
                end

                DisconnectWeaponInfoConnection(observer, 'EquippedItemChanged')
                DisconnectWeaponInfoConnection(observer, 'EquippedChanged')
                DisconnectWeaponInfoConnection(observer, 'AmmoChanged')
                DisconnectWeaponInfoConnection(observer, 'AmmoReserveChanged')
                WeaponInfoConnections[player] = nil
            end

            local function ConnectWeaponInfoSignal(signal, observer, key, callback)
                DisconnectWeaponInfoConnection(observer, key)

                if not signal or type(signal.Connect) ~= 'function' then
                    return
                end

                local guardedCallback = GuardRivalsCallback(string.format('WeaponInfo_%s', tostring(key)), callback)
                local ok, connection = pcall(signal.Connect, signal, guardedCallback)
                if ok and connection then
                    observer[key] = connection
                end
            end

            local function AttachWeaponInfoItemObservers(player, observer, item)
                DisconnectWeaponInfoConnection(observer, 'EquippedChanged')
                DisconnectWeaponInfoConnection(observer, 'AmmoChanged')
                DisconnectWeaponInfoConnection(observer, 'AmmoReserveChanged')

                observer.Item = item
                observer.Ammo = item and ReadItemValue(item, 'Ammo') or nil
                observer.AmmoReserve = item and ReadItemValue(item, 'AmmoReserve') or nil

                if not item then
                    return
                end

                ConnectWeaponInfoSignal(item.EquippedChanged, observer, 'EquippedChanged', function()
                    InvalidateWeaponInfo(player)
                    if player == LP and UpdateRivalsPickupFeatures then
                        UpdateRivalsPickupFeatures()
                    end
                end)

                local valueChangedEvents = rawget(item, '_value_changed_events')
                if type(valueChangedEvents) ~= 'table' then
                    return
                end

                ConnectWeaponInfoSignal(valueChangedEvents.Ammo, observer, 'AmmoChanged', function(newAmmo)
                    observer.Ammo = type(newAmmo) == 'number' and newAmmo or ReadItemValue(item, 'Ammo')
                    InvalidateWeaponInfo(player)
                    local ammo = observer.Ammo
                    if player == LP and UpdateRivalsPickupFeatures and type(ammo) == 'number' and ammo <= 0 then
                        UpdateRivalsPickupFeatures()
                    end
                end)
                ConnectWeaponInfoSignal(valueChangedEvents.AmmoReserve, observer, 'AmmoReserveChanged', function(newReserve)
                    observer.AmmoReserve = type(newReserve) == 'number' and newReserve or ReadItemValue(item, 'AmmoReserve')
                    InvalidateWeaponInfo(player)
                end)
            end

            local function AttachWeaponInfoObservers(player, fighter)
                if not player then
                    return
                end

                if player == LP then
                    fighter = fighter or ResolveLocalFighter()
                else
                    local fighterController = ResolveFighterController()
                    if not fighter and fighterController and type(fighterController.GetFighter) == 'function' then
                        fighter = fighterController:GetFighter(player)
                    end
                end

                if not fighter then
                    DisconnectWeaponInfoConnections(player)
                    return
                end

                local observer = WeaponInfoConnections[player]
                if observer and observer.Fighter == fighter then
                    return
                end

                DisconnectWeaponInfoConnections(player)

                observer = {
                    Fighter = fighter,
                    Item = nil,
                }
                WeaponInfoConnections[player] = observer

                local function refreshItemObservers()
                    local item = fighter.EquippedItem
                    if observer.Item ~= item then
                        AttachWeaponInfoItemObservers(player, observer, item)
                    end
                    InvalidateWeaponInfo(player)
                    if player == LP then
                        FighterDataCache.LocalLoadout.EquippedItem = item
                        FighterDataCache.LocalLoadout.Seeded = true
                        if UpdateRivalsPickupFeatures then
                            UpdateRivalsPickupFeatures()
                        end
                    end
                end

                ConnectWeaponInfoSignal(fighter.EquippedItemChanged, observer, 'EquippedItemChanged', refreshItemObservers)
                refreshItemObservers()
            end

            local function RegisterWeaponInfoFighter(fighter)
                local player = fighter and fighter.Player
                if not player or player == LP then
                    return
                end

                AttachWeaponInfoObservers(player, fighter)
            end

            local function UnregisterWeaponInfoFighter(fighter)
                local player = fighter and fighter.Player
                if not player or player == LP then
                    return
                end

                local observer = WeaponInfoConnections[player]
                if observer and observer.Fighter ~= fighter then
                    return
                end

                DisconnectWeaponInfoConnections(player)
                InvalidateWeaponInfo(player)
            end

            local function EnsureWeaponInfoTracking()
                if not Connections or WeaponInfoTrackingConnected then
                    return
                end

                if not IsReplicatedStateReady() then
                    if not WeaponInfoTrackingRetryPending then
                        WeaponInfoTrackingRetryPending = true
                        task.spawn(GuardRivalsCallback('WeaponInfo_WaitForReplicatedState', function()
                            while not WeaponInfoTrackingConnected and not ReplicatedStateReady do
                                task.wait(0.25)
                            end

                            WeaponInfoTrackingRetryPending = false
                            if not WeaponInfoTrackingConnected then
                                EnsureWeaponInfoTracking()
                            end
                        end))
                    end
                    return
                end

                local fighterController = ResolveFighterController()
                if not fighterController then
                    return
                end

                for _, fighter in ipairs(fighterController.Objects or {}) do
                    RegisterWeaponInfoFighter(fighter)
                end

                if fighterController.ObjectAdded and type(fighterController.ObjectAdded.Connect) == 'function' then
                    Connections:register('WeaponInfo_FighterObjectAdded', fighterController.ObjectAdded:Connect(GuardRivalsCallback('WeaponInfo_FighterObjectAdded', RegisterWeaponInfoFighter)))
                end

                if fighterController.ObjectRemoved and type(fighterController.ObjectRemoved.Connect) == 'function' then
                    Connections:register('WeaponInfo_FighterObjectRemoved', fighterController.ObjectRemoved:Connect(GuardRivalsCallback('WeaponInfo_FighterObjectRemoved', UnregisterWeaponInfoFighter)))
                end

                WeaponInfoTrackingConnected = true
            end

            local function GetCachedWeaponInfo(player)
                local observer = WeaponInfoConnections[player]
                local item = observer and observer.Item or nil
                local reloadCooldown = item and rawget(item, '_reload_cooldown') or nil
                local isReloading = type(reloadCooldown) == 'number'
                    and reloadCooldown > tick()
                    and item.Info ~= nil
                    and item.Info.ReloadType ~= nil
                local cached = WeaponInfoCache[player]
                if cached
                    and cached.item == item
                    and cached.reloadCooldown == reloadCooldown
                    and cached.isReloading == isReloading then
                    return cached.weaponInfo
                end

                local weaponInfo = ReadWeaponInfo(player)
                WeaponInfoCache[player] = {
                    item = item,
                    reloadCooldown = reloadCooldown,
                    isReloading = isReloading,
                    weaponInfo = weaponInfo,
                }
                return weaponInfo
            end

            local function BuildPlayerWeaponText(weaponInfoText, showWeapon)
                if showWeapon and weaponInfoText and weaponInfoText ~= '' then
                    return weaponInfoText
                end

                return ''
            end

            local function BuildPlayerDistanceText(dist, showDistance)
                if showDistance then
                    return string.format('%dm', math.floor(dist))
                end

                return ''
            end

            local function BuildHealthText(humanoid, showHealthNum)
                if showHealthNum and humanoid then
                    return tostring(math.floor(humanoid.Health + 0.5))
                end
                return ''
            end

            local function BuildVerticalHealthText(humanoid)
                if not humanoid then
                    return ''
                end

                local currentHealth = math.max(0, math.floor(humanoid.Health + 0.5))
                return tostring(currentHealth)
            end

            local function GetHealthBarColor(healthRatio)
                local ratio = math.clamp(healthRatio or 0, 0, 1)
                if ratio <= 0.5 then
                    return BlendColor(PLAYER_CARD_THEME.BarLowColor, PLAYER_CARD_THEME.BarMidColor, ratio / 0.5)
                end
                return BlendColor(PLAYER_CARD_THEME.BarMidColor, PLAYER_CARD_THEME.BarHighColor, (ratio - 0.5) / 0.5)
            end

            do
            local EspClassic = RivalsRuntimeBridge.ESPClassic
            local PlayerStatusInfoCache = RivalsRuntimeBridge.PlayerStatusInfoCache

            local function GetReactiveBarColor(ratio)
                return BlendColor(
                    PLAYER_CARD_THEME.Classic.ReactiveLowColor,
                    PLAYER_CARD_THEME.BarHighColor,
                    math.clamp(ratio or 0, 0, 1)
                )
            end

            local function ResolveEspRankProfile()
                if RivalsRuntimeBridge.EspRankProfileCache then
                    return RivalsRuntimeBridge.EspRankProfileCache
                end

                local modules = ReplicatedStorage:FindFirstChild('Modules')
                local seasonLibraryModule = modules and modules:FindFirstChild('SeasonLibrary')
                if not seasonLibraryModule then
                    return nil
                end

                local ok, seasonLibrary = pcall(require, seasonLibraryModule)
                if not ok or type(seasonLibrary) ~= 'table' then
                    return nil
                end

                local currentSeason = seasonLibrary.CurrentSeason
                local rankProfile = type(currentSeason) == 'table' and currentSeason.RankProfile or nil
                local rankProfileName = type(rankProfile) == 'table' and rankProfile.Name or nil
                local rankProfiles = seasonLibrary.RankProfiles
                if type(rankProfiles) == 'table' and rankProfileName ~= nil then
                    rankProfile = rankProfiles[rankProfileName] or rankProfile
                end

                local ranksOrder = type(rankProfile) == 'table' and rankProfile.RanksOrder or nil
                local ranks = type(rankProfile) == 'table' and rankProfile.Ranks or nil
                if type(ranksOrder) ~= 'table' or type(ranks) ~= 'table' then
                    return nil
                end

                RivalsRuntimeBridge.EspRankProfileCache = {
                    RanksOrder = ranksOrder,
                    Ranks = ranks,
                }
                return RivalsRuntimeBridge.EspRankProfileCache
            end

            local function ResolveEspRankName(displayElo)
                local elo = tonumber(displayElo)
                if elo == nil then
                    return 'Unranked'
                end

                local rankProfile = ResolveEspRankProfile()
                if not rankProfile then
                    return 'Unranked'
                end

                local ranksOrder = rankProfile.RanksOrder
                local ranks = rankProfile.Ranks
                local rankCount = #ranksOrder
                for rankIndex, rankName in ipairs(ranksOrder) do
                    local rankData = ranks[rankName]
                    if type(rankData) == 'table'
                        and type(rankData.RequiredELO) == 'number'
                        and elo < rankData.RequiredELO
                        and rankData.RequiredELOLeaderboardRanking == nil then
                        return ranksOrder[math.clamp(rankIndex - 1, 1, rankCount)] or 'Unranked'
                    end
                end

                for rankIndex = rankCount, 1, -1 do
                    local rankName = ranksOrder[rankIndex]
                    local rankData = ranks[rankName]
                    if type(rankData) == 'table' and rankData.RequiredELOLeaderboardRanking == nil then
                        return rankName
                    end
                end

                return 'Unranked'
            end

            local function InvalidatePlayerStatusInfo(player)
                RivalsRuntimeBridge.PlayerStatusInfoCache[player] = nil
            end

            local function GetCachedPlayerStatusInfo(player)
                local cached = PlayerStatusInfoCache[player]
                if cached then
                    return cached
                end

                local winStreak = tonumber(player:GetAttribute('StatisticDuelsWinStreak')) or 0
                cached = {
                    Rank = ResolveEspRankName(player:GetAttribute('DisplayELO')),
                    WinStreak = math.max(0, math.floor(winStreak)),
                }
                PlayerStatusInfoCache[player] = cached
                return cached
            end

            local function DisconnectEspStatusObservers(entry)
                for _, connection in pairs(entry.statusConnections or {}) do
                    pcall(function()
                        connection:Disconnect()
                    end)
                end
                entry.statusConnections = nil
            end

            local function AttachEspStatusObservers(player, entry)
                DisconnectEspStatusObservers(entry)
                entry.statusConnections = {
                    displayElo = player:GetAttributeChangedSignal('DisplayELO'):Connect(GuardRivalsCallback('ESP_DisplayELOChanged', function()
                        InvalidatePlayerStatusInfo(player)
                    end)),
                    winStreak = player:GetAttributeChangedSignal('StatisticDuelsWinStreak'):Connect(GuardRivalsCallback('ESP_WinStreakChanged', function()
                        InvalidatePlayerStatusInfo(player)
                    end)),
                }
                InvalidatePlayerStatusInfo(player)
            end

            local function BuildEspStatusText(player, settings, entry)
                local deflectCheck = RivalsRuntimeBridge.IsRivalsKatanaDeflectActiveItem
                local isDeflecting = false
                if settings.ShowDeflecting and deflectCheck then
                    local observer = WeaponInfoConnections[player]
                    local fighter = TrackedFightersByPlayer[player] or (observer and observer.Fighter)
                    if deflectCheck(fighter and fighter.EquippedItem or nil) then
                        isDeflecting = true
                    end
                end

                local rank = nil
                local winStreak = nil
                if settings.ShowRank or settings.ShowWinStreak then
                    local statusInfo = GetCachedPlayerStatusInfo(player)
                    if settings.ShowRank then
                        rank = statusInfo.Rank
                    end
                    if settings.ShowWinStreak then
                        winStreak = statusInfo.WinStreak
                    end
                end

                if entry.statusCacheDeflecting == isDeflecting
                    and entry.statusCacheRank == rank
                    and entry.statusCacheWinStreak == winStreak then
                    return entry.statusCacheValue or ''
                end

                local labels = {}
                if isDeflecting then
                    labels[#labels + 1] = 'DEFLECTING'
                end
                if rank then
                    labels[#labels + 1] = string.upper(rank)
                end
                if winStreak then
                    labels[#labels + 1] = string.format('%d WS', winStreak)
                end

                local value = table.concat(labels, '\n')
                entry.statusCacheDeflecting = isDeflecting
                entry.statusCacheRank = rank
                entry.statusCacheWinStreak = winStreak
                entry.statusCacheValue = value
                return value
            end

            local function SmoothEspRatio(currentRatio, targetRatio, deltaTime)
                targetRatio = math.clamp(targetRatio or 0, 0, 1)
                if type(currentRatio) ~= 'number' then
                    return targetRatio
                end

                local alpha = 1 - math.exp(-PLAYER_CARD_THEME.Classic.SmoothSpeed * math.max(deltaTime or 0, 0))
                local nextRatio = currentRatio + ((targetRatio - currentRatio) * alpha)
                if math.abs(nextRatio - targetRatio) < 0.001 then
                    return targetRatio
                end
                return nextRatio
            end

            EspClassic.GetReactiveBarColor = GetReactiveBarColor
            EspClassic.DisconnectStatusObservers = DisconnectEspStatusObservers
            EspClassic.AttachStatusObservers = AttachEspStatusObservers
            EspClassic.BuildStatusText = BuildEspStatusText
            EspClassic.SmoothRatio = SmoothEspRatio
            end

            local function GetPartScreenBounds(part, camera, boundsCache)
                if not part or not part:IsA('BasePart') or not camera then
                    return nil
                end

                boundsCache = boundsCache or {}
                local partSize = part.Size
                if boundsCache.Part ~= part or boundsCache.Size ~= partSize then
                    local halfX = partSize.X * 0.5
                    local halfY = partSize.Y * 0.5
                    local halfZ = partSize.Z * 0.5
                    local localCorners = table.create(8)
                    local cornerIndex = 0
                    for _, xSign in ipairs(MODEL_BOUNDS_SIGNS) do
                        for _, ySign in ipairs(MODEL_BOUNDS_SIGNS) do
                            for _, zSign in ipairs(MODEL_BOUNDS_SIGNS) do
                                cornerIndex = cornerIndex + 1
                                localCorners[cornerIndex] = Vector3.new(
                                    halfX * xSign,
                                    halfY * ySign,
                                    halfZ * zSign
                                )
                            end
                        end
                    end
                    boundsCache.Part = part
                    boundsCache.Size = partSize
                    boundsCache.LocalCorners = localCorners
                end

                local minX, maxX, minY, maxY
                local projectedCorners = 0

                for _, localCorner in ipairs(boundsCache.LocalCorners) do
                    local worldCorner = part.CFrame:PointToWorldSpace(localCorner)
                    local corner = camera:WorldToViewportPoint(worldCorner)
                    if corner.Z > 0 then
                        projectedCorners = projectedCorners + 1
                        minX = minX and math.min(minX, corner.X) or corner.X
                        maxX = maxX and math.max(maxX, corner.X) or corner.X
                        minY = minY and math.min(minY, corner.Y) or corner.Y
                        maxY = maxY and math.max(maxY, corner.Y) or corner.Y
                    end
                end

                if projectedCorners < 2 or not minX or not maxX or not minY or not maxY then
                    return nil
                end

                return {
                    MinX = minX,
                    MaxX = maxX,
                    MinY = minY,
                    MaxY = maxY,
                    Width = maxX - minX,
                    Height = maxY - minY,
                    CenterX = minX + ((maxX - minX) * 0.5),
                    CenterY = minY + ((maxY - minY) * 0.5),
                }
            end

            local function ReadCharacterEspParts(character, cache)
                if not character then
                    return nil
                end

                if not cache or cache.Character ~= character then
                    cache = {Character = character}
                end

                if cache.HumanoidRootPart == nil or cache.HumanoidRootPart.Parent ~= character then
                    cache.HumanoidRootPart = character:FindFirstChild('HumanoidRootPart')
                end
                if cache.Humanoid == nil or cache.Humanoid.Parent ~= character then
                    cache.Humanoid = character:FindFirstChild('Humanoid')
                end
                if cache.HitboxBody == nil or cache.HitboxBody.Parent ~= character then
                    local bodyHitbox = character:FindFirstChild('HitboxBody')
                    if cache.HitboxBody ~= bodyHitbox then
                        cache.HitboxBody = bodyHitbox
                        cache.HitboxBodyBoundsCache = {}
                    end
                end
                if cache.HitboxHead == nil or cache.HitboxHead.Parent ~= character then
                    local headHitbox = character:FindFirstChild('HitboxHead')
                    if cache.HitboxHead ~= headHitbox then
                        cache.HitboxHead = headHitbox
                        cache.HitboxHeadBoundsCache = {}
                    end
                end

                cache.HitboxBodyBoundsCache = cache.HitboxBodyBoundsCache or {}
                cache.HitboxHeadBoundsCache = cache.HitboxHeadBoundsCache or {}

                return cache
            end

            local function GetHitboxScreenBounds(characterParts, character, camera)
                if not characterParts or not character or not camera then
                    return nil
                end

                local bodyHitbox = characterParts.HitboxBody
                local headHitbox = characterParts.HitboxHead

                local bodyBounds = GetPartScreenBounds(bodyHitbox, camera, characterParts.HitboxBodyBoundsCache)
                local headBounds = GetPartScreenBounds(headHitbox, camera, characterParts.HitboxHeadBoundsCache)
                characterParts.LastBodyScreenBounds = bodyBounds

                if bodyBounds and headBounds then
                    local minX = math.min(bodyBounds.MinX, headBounds.MinX)
                    local maxX = math.max(bodyBounds.MaxX, headBounds.MaxX)
                    local minY = math.min(bodyBounds.MinY, headBounds.MinY)
                    local maxY = math.max(bodyBounds.MaxY, headBounds.MaxY)
                    local width = maxX - minX
                    local height = maxY - minY

                    return {
                        MinX = minX,
                        MaxX = maxX,
                        MinY = minY,
                        MaxY = maxY,
                        Width = width,
                        Height = height,
                        CenterX = minX + (width * 0.5),
                        CenterY = minY + (height * 0.5),
                    }
                end

                if bodyBounds then
                    return bodyBounds
                end

                if headBounds then
                    return headBounds
                end

                return nil
            end

            local EspRenderSettings = {}
            local EspRenderSettingWatchersConnected = false

            local function ReadEspToggleValue(toggleId, fallback)
                local toggle = Toggles[toggleId]
                if toggle ~= nil then
                    return toggle.Value == true
                end

                return fallback
            end

            local function ReadEspOptionValue(optionId, fallback)
                local option = Options[optionId]
                if option ~= nil and option.Value ~= nil then
                    return option.Value
                end

                return fallback
            end

            local function RefreshEspRenderSettings()
                EspRenderSettings = {
                    Enabled = ReadEspToggleValue('P1S1T1', true),
                    ShowHighlight = ReadEspToggleValue('P1S1T2', true),
                    ShowName = ReadEspToggleValue('P1S1T3', true),
                    ShowHealth = ReadEspToggleValue('P1S1T4', true),
                    ShowArrows = ReadEspToggleValue('P1S1T5', true),
                    ShowDistance = ReadEspToggleValue('P1S1T6', true),
                    UseVerticalHealth = ReadEspToggleValue('P1S1T7', false),
                    ShowLookDir = ReadEspToggleValue('P1S1T8', true),
                    ShowWeapon = ReadEspToggleValue('P1S1T9', true),
                    ShowTeammates = ReadEspToggleValue('P1S1T10', true),
                    ShowThrowable = ReadEspToggleValue('P1S1T11', true),
                    ShowBox = ReadEspToggleValue('P1S2T1', true),
                    ShowAmmoText = ReadEspToggleValue('P1S2T2', true),
                    ShowRank = ReadEspToggleValue('P1S2T4', true),
                    ShowWinStreak = ReadEspToggleValue('P1S2T5', true),
                    ShowDeflecting = ReadEspToggleValue('P1S2T6', true),
                    VisibleColor = ReadEspOptionValue('P1S1C1', Color3.fromRGB(0, 255, 0)),
                    HiddenColor = ReadEspOptionValue('P1S1C2', Color3.fromRGB(255, 0, 0)),
                    LookDirColor = ReadEspOptionValue('P1S1C4', Color3.fromRGB(255, 255, 0)),
                    FillAlpha = ReadEspOptionValue('P1S1S3', 1),
                    OutlineAlpha = ReadEspOptionValue('P1S1S4', 0),
                }

                if RivalsRuntimeBridge.UpdateEspPreview then
                    pcall(RivalsRuntimeBridge.UpdateEspPreview)
                end

                return EspRenderSettings
            end

            local function RegisterEspRenderSettingWatcher(setting)
                if setting and type(setting.OnChanged) == 'function' then
                    setting:OnChanged(RefreshEspRenderSettings)
                end
            end

            local function EnsureEspRenderSettingsTracking()
                if EspRenderSettingWatchersConnected then
                    return
                end

                for _, toggleId in ipairs({
                    'P1S1T1',
                    'P1S1T2',
                    'P1S1T3',
                    'P1S1T4',
                    'P1S1T5',
                    'P1S1T6',
                    'P1S1T7',
                    'P1S1T8',
                    'P1S1T9',
                    'P1S1T10',
                    'P1S1T11',
                    'P1S2T1',
                    'P1S2T2',
                    'P1S2T4',
                    'P1S2T5',
                    'P1S2T6',
                }) do
                    RegisterEspRenderSettingWatcher(Toggles[toggleId])
                end

                for _, optionId in ipairs({
                    'P1S1C1',
                    'P1S1C2',
                    'P1S1C4',
                    'P1S1S3',
                    'P1S1S4',
                }) do
                    RegisterEspRenderSettingWatcher(Options[optionId])
                end

                EspRenderSettingWatchersConnected = true
                RefreshEspRenderSettings()
            end

            RefreshEspRenderSettings()

            -- =============================================
            -- Highlight + Drawing Hybrid ESP
            -- =============================================

            local HighlightContainer = Workspace
            local HazardAdornmentContainer = Workspace

            local ESPObjects = {}
            local DedicatedAimbotHitboxPartNames = {
                HitboxHead = true,
                HitboxBody = true,
            }

            local ResolveAimbotVisibilityRaycastParams
            do
                local AimbotVisibilityRaycastState = {
                    Filter = {},
                    Params = RaycastParams.new(),
                }
                AimbotVisibilityRaycastState.Params.FilterType = Enum.RaycastFilterType.Exclude
                AimbotVisibilityRaycastState.Params.FilterDescendantsInstances = AimbotVisibilityRaycastState.Filter

                ResolveAimbotVisibilityRaycastParams = function(character)
                    local filter = AimbotVisibilityRaycastState.Filter
                    filter[1] = Char
                    filter[2] = character
                    filter[3] = nil
                    AimbotVisibilityRaycastState.Params.FilterDescendantsInstances = filter
                    return AimbotVisibilityRaycastState.Params
                end
            end

            local function IsPointVisible(character, worldPoint)
                local cam = Workspace.CurrentCamera
                if not cam or typeof(worldPoint) ~= 'Vector3' or not Char then return false end
                local origin = cam.CFrame.Position
                local direction = worldPoint - origin
                if direction.Magnitude <= 0 then return false end
                local rayParams = ResolveAimbotVisibilityRaycastParams(character)
                local result = Workspace:Raycast(origin, direction, rayParams)
                return result == nil
            end

            local function IsVisible(character, targetPart, targetPoint)
                if not targetPart then
                    return false
                end

                local point = targetPoint or targetPart.Position
                return IsPointVisible(character, point)
            end

            do
            local EspClassic = RivalsRuntimeBridge.ESPClassic

            local function CreateEspLine()
                local line = Drawing.new('Line')
                line.Visible = false
                return line
            end

            local function EnsureEspCornerBox(entry)
                if entry.cornerBox then
                    return entry.cornerBox
                end

                local cornerBox = table.create(8)
                for segmentIndex = 1, 8 do
                    cornerBox[segmentIndex] = {
                        outline = CreateEspLine(),
                        color = CreateEspLine(),
                    }
                end
                entry.cornerBox = cornerBox
                return cornerBox
            end

            local function HideEspBox(entry)
                for _, segment in ipairs(entry.cornerBox or {}) do
                    SetDrawingVisible(segment.outline, false)
                    SetDrawingVisible(segment.color, false)
                end
            end

            local function RemoveEspBox(entry)
                for _, segment in ipairs(entry.cornerBox or {}) do
                    pcall(function() segment.outline:Remove() end)
                    pcall(function() segment.color:Remove() end)
                end
                entry.cornerBox = nil
            end

            local function SetEspCornerSegment(segment, fromPoint, toPoint, color, scale)
                local outline = segment.outline
                outline.From = fromPoint
                outline.To = toPoint
                outline.Color = PLAYER_CARD_THEME.Classic.BoxOutlineColor
                outline.Transparency = PLAYER_CARD_THEME.Classic.BoxOutlineTransparency
                outline.Thickness = math.max(PLAYER_CARD_THEME.Classic.BoxOutlineThickness * scale, 2)
                SetDrawingVisible(outline, true)

                local colorLine = segment.color
                colorLine.From = fromPoint
                colorLine.To = toPoint
                colorLine.Color = color
                colorLine.Transparency = 1
                colorLine.Thickness = math.max(PLAYER_CARD_THEME.Classic.BoxThickness * scale, 1)
                SetDrawingVisible(colorLine, true)
            end

            local function DrawEspBox(entry, bounds, color, scale)
                local minX, minY = bounds.MinX, bounds.MinY
                local maxX, maxY = bounds.MaxX, bounds.MaxY
                local width = math.max(maxX - minX, 1)
                local height = math.max(maxY - minY, 1)

                local cornerBox = EnsureEspCornerBox(entry)
                local segmentLength = math.max(math.min(width, height) * 0.24, 5 * scale)
                segmentLength = math.min(segmentLength, width * 0.5, height * 0.5)

                SetEspCornerSegment(cornerBox[1], Vector2.new(minX, minY), Vector2.new(minX + segmentLength, minY), color, scale)
                SetEspCornerSegment(cornerBox[2], Vector2.new(maxX - segmentLength, minY), Vector2.new(maxX, minY), color, scale)
                SetEspCornerSegment(cornerBox[3], Vector2.new(minX, maxY), Vector2.new(minX + segmentLength, maxY), color, scale)
                SetEspCornerSegment(cornerBox[4], Vector2.new(maxX - segmentLength, maxY), Vector2.new(maxX, maxY), color, scale)
                SetEspCornerSegment(cornerBox[5], Vector2.new(minX, minY), Vector2.new(minX, minY + segmentLength), color, scale)
                SetEspCornerSegment(cornerBox[6], Vector2.new(minX, maxY - segmentLength), Vector2.new(minX, maxY), color, scale)
                SetEspCornerSegment(cornerBox[7], Vector2.new(maxX, minY), Vector2.new(maxX, minY + segmentLength), color, scale)
                SetEspCornerSegment(cornerBox[8], Vector2.new(maxX, maxY - segmentLength), Vector2.new(maxX, maxY), color, scale)
            end

            local function EnsureEspStatusText(entry)
                if entry.statusText then
                    return entry.statusText
                end

                local statusText = Drawing.new('Text')
                statusText.Center = false
                statusText.Outline = true
                statusText.Font = 3
                statusText.Color = PLAYER_CARD_THEME.BarTextColor
                statusText.Visible = false
                entry.statusText = statusText
                return statusText
            end

            EspClassic.HideBox = HideEspBox
            EspClassic.RemoveBox = RemoveEspBox
            EspClassic.DrawBox = DrawEspBox
            EspClassic.EnsureStatusText = EnsureEspStatusText
            end

            local function CreateESP(player)
                if ESPObjects[player] then return end

                local highlight = Instance.new('Highlight')
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillTransparency = 1
                highlight.OutlineTransparency = 0
                highlight.Enabled = false
                highlight.Parent = HighlightContainer

                local nameText = Drawing.new('Text')
                nameText.Center = false
                nameText.Outline = true
                nameText.Font = 3
                nameText.Color = PLAYER_CARD_THEME.BarTextColor
                nameText.Visible = false

                local healthBarBg = CreateRoundedRect()
                local healthBarFill = CreateRoundedRect()

                local healthText = Drawing.new('Text')
                healthText.Center = true
                healthText.Outline = true
                healthText.Font = 3
                healthText.Color = PLAYER_CARD_THEME.BarTextColor
                healthText.Visible = false

                local healthSuffixText = Drawing.new('Text')
                healthSuffixText.Center = false
                healthSuffixText.Outline = true
                healthSuffixText.Font = 3
                healthSuffixText.Color = PLAYER_CARD_THEME.BarTextColor
                healthSuffixText.Visible = false

                local arrow = CreateArrowIndicator()

                local metaText = Drawing.new('Text')
                metaText.Center = false
                metaText.Outline = true
                metaText.Font = 3
                metaText.Color = PLAYER_CARD_THEME.BarTextColor
                metaText.Visible = false

                local ammoText = Drawing.new('Text')
                ammoText.Center = true
                ammoText.Outline = true
                ammoText.Font = 3
                ammoText.Color = PLAYER_CARD_THEME.BarTextColor
                ammoText.Visible = false

                local distanceText = Drawing.new('Text')
                distanceText.Center = false
                distanceText.Outline = true
                distanceText.Font = 3
                distanceText.Color = PLAYER_CARD_THEME.BarTextColor
                distanceText.Visible = false

                local lookLine = Drawing.new('Line')
                lookLine.Thickness = 1
                lookLine.Transparency = PLAYER_CARD_THEME.LookLineTransparency
                lookLine.Visible = false

                ESPObjects[player] = {
                    highlight = highlight,
                    characterParts = nil,
                    nameText = nameText,
                    healthBarBg = healthBarBg,
                    healthBarFill = healthBarFill,
                    healthText = healthText,
                    healthSuffixText = healthSuffixText,
                    arrow = arrow,
                    metaText = metaText,
                    ammoText = ammoText,
                    distanceText = distanceText,
                    lookLine = lookLine,
                }
                AttachWeaponInfoObservers(player)
                RivalsRuntimeBridge.ESPClassic.AttachStatusObservers(player, ESPObjects[player])
            end

            local function DestroyESP(player)
                local entry = ESPObjects[player]
                if not entry then return end
                pcall(function() entry.highlight:Destroy() end)
                pcall(function() entry.nameText:Remove() end)
                RemoveRoundedRect(entry.healthBarBg)
                RemoveRoundedRect(entry.healthBarFill)
                pcall(function() entry.healthText:Remove() end)
                pcall(function() entry.healthSuffixText:Remove() end)
                RemoveArrowIndicator(entry.arrow)
                pcall(function() entry.metaText:Remove() end)
                pcall(function() entry.ammoText:Remove() end)
                pcall(function() entry.distanceText:Remove() end)
                pcall(function() entry.lookLine:Remove() end)
                if entry.statusText then
                    pcall(function() entry.statusText:Remove() end)
                end
                RivalsRuntimeBridge.ESPClassic.RemoveBox(entry)
                RivalsRuntimeBridge.ESPClassic.DisconnectStatusObservers(entry)
                DisconnectWeaponInfoConnections(player)
                WeaponInfoCache[player] = nil
                RivalsRuntimeBridge.PlayerStatusInfoCache[player] = nil
                ESPObjects[player] = nil
            end

            local function DestroyAllESP()
                for player in pairs(ESPObjects) do
                    DestroyESP(player)
                end
            end

            local function HideESP(entry)
                entry.highlight.Enabled = false
                SetDrawingVisible(entry.nameText, false)
                HideRoundedRect(entry.healthBarBg)
                HideRoundedRect(entry.healthBarFill)
                SetDrawingVisible(entry.healthText, false)
                SetDrawingVisible(entry.healthSuffixText, false)
                HideArrowIndicator(entry.arrow)
                SetDrawingVisible(entry.metaText, false)
                SetDrawingVisible(entry.ammoText, false)
                SetDrawingVisible(entry.distanceText, false)
                SetDrawingVisible(entry.lookLine, false)
                if entry.statusText then
                    SetDrawingVisible(entry.statusText, false)
                end
                RivalsRuntimeBridge.ESPClassic.HideBox(entry)
            end

            local function ShouldShow(player, showTeammates)
                if player == LP then return false end
                if showTeammates then return true end
                -- RIVALS uses TeamID attribute, not Roblox Teams service
                local myTeam = LP:GetAttribute('TeamID')
                local theirTeam = player:GetAttribute('TeamID')
                if myTeam and theirTeam then
                    return myTeam ~= theirTeam
                end
                -- Fallback to standard Teams if attributes missing
                if player.Team == nil or LP.Team == nil then return true end
                return player.Team ~= LP.Team
            end

            local function IsPlayerInLocalEnvironment(player)
                if not player or player == LP or player.Parent ~= Players then
                    return false
                end

                local localCharacter = LP.Character
                local localEnvironmentId = localCharacter and localCharacter:GetAttribute('EnvironmentID') or nil
                if localEnvironmentId == nil then
                    return false
                end

                local character = player.Character
                return character ~= nil
                    and character.Parent ~= nil
                    and character:GetAttribute('EnvironmentID') == localEnvironmentId
            end

            local function ReconcileESPPlayers()
                local showTeammates = EspRenderSettings.ShowTeammates
                for player in pairs(ESPObjects) do
                    if not IsPlayerInLocalEnvironment(player)
                        or not ShouldShow(player, showTeammates) then
                        DestroyESP(player)
                    end
                end

                for _, player in ipairs(Players:GetPlayers()) do
                    if IsPlayerInLocalEnvironment(player)
                        and ShouldShow(player, showTeammates) then
                        CreateESP(player)
                    end
                end
            end

            local function IsRivalsPickupPlace()
                return type(CurrentRivalsPlace) == 'number' and (
                    CurrentRivalsPlace == RIVALS_SHARED_MATCH_PLACE
                    or CurrentRivalsPlace == 71874690745115
                    or CurrentRivalsPlace == 133215910299950
                )
            end

            local function ResolveRivalsDataRemote(remoteName, expectedClass)
                expectedClass = expectedClass or 'RemoteEvent'
                local remotesFolder = ReplicatedStorage:FindFirstChild('Remotes')
                local dataFolder = remotesFolder and remotesFolder:FindFirstChild('Data')
                local remote = dataFolder and dataFolder:FindFirstChild(remoteName)
                if remote and remote:IsA(expectedClass) then
                    return remote
                end

                return nil
            end

            local function GetRivalsPickupTouchPart()
                if not InitCharacter() or not Char or not HumanoidRootPart then
                    return nil
                end

                return Char:FindFirstChild('HitboxBody')
                    or HumanoidRootPart
                    or Char:FindFirstChildWhichIsA('BasePart')
            end

            local function GetRivalsPickupKind(drop)
                if not drop or not drop:IsA('BasePart') or drop.Name ~= '_drop' then
                    return nil
                end

                if drop:FindFirstChild('Health') then
                    return 'Health'
                end

                if drop:FindFirstChild('AmmoBalanced') or drop:FindFirstChild('Ammo') then
                    return 'Ammo'
                end

                return nil
            end

            local function IsRivalsSpawnShieldActive(character)
                if not character or not character.Parent then
                    return false
                end

                local player = Players:GetPlayerFromCharacter(character)
                local fighter = player and TrackedFightersByPlayer[player]
                -- Diagnostic: bypassing FighterDataCache.Cache invincibility cache (bf314e0)
                -- to test whether stale-cache reads are causing visible-player misses.
                -- Revert this hunk if the cache turns out not to be the culprit.

                if not fighter then
                    local fighterController = ResolveFighterController()
                    if fighterController and type(fighterController.GetFighter) == 'function' then
                        fighter = player and fighterController:GetFighter(player) or nil
                        if not fighter then
                            fighter = fighterController:GetFighter(character)
                        end
                    end
                end

                if not fighter then
                    return false
                end

                return FighterDataCache.ReadEntity(fighter.Entity)
            end

            local function TouchRivalsPickupDrop(drop, touchPart)
                if not drop or not drop.Parent or not touchPart or not touchPart.Parent then
                    return false
                end

                firetouchinterest(touchPart, drop, 0)
                task.defer(function()
                    if drop.Parent and touchPart.Parent then
                        firetouchinterest(touchPart, drop, 1)
                    end
                end)
                return true
            end

            local LocalPickupObserver = {
                RetryActive = false,
                RetryDelay = 0.05,
                RetryNonce = 0,
            }

            do
                local pickupDropsByKind = {
                    Health = {},
                    Ammo = {},
                }
                local pickupDropObservers = {}

                local function ClearPickupDropKinds(drop)
                    if not drop then
                        return
                    end

                    pickupDropsByKind.Health[drop] = nil
                    pickupDropsByKind.Ammo[drop] = nil
                end

                local function DisconnectPickupDropObserver(drop)
                    local observer = pickupDropObservers[drop]
                    if not observer then
                        return
                    end

                    local childAddedConnection = observer.ChildAddedConnection
                    if childAddedConnection then
                        pcall(function()
                            childAddedConnection:Disconnect()
                        end)
                    end

                    local childRemovedConnection = observer.ChildRemovedConnection
                    if childRemovedConnection then
                        pcall(function()
                            childRemovedConnection:Disconnect()
                        end)
                    end

                    pickupDropObservers[drop] = nil
                end

                local function RefreshPickupDrop(drop)
                    ClearPickupDropKinds(drop)

                    if not drop or drop.Parent ~= Workspace or not drop:IsA('BasePart') or drop.Name ~= '_drop' then
                        return
                    end

                    local dropKind = GetRivalsPickupKind(drop)
                    local hasTouchInterest = drop:FindFirstChildOfClass('TouchTransmitter') ~= nil
                    if dropKind and hasTouchInterest then
                        pickupDropsByKind[dropKind][drop] = true
                        if UpdateRivalsPickupFeatures then
                            UpdateRivalsPickupFeatures()
                        end
                    end
                end

                function LocalPickupObserver.ObserveDrop(drop)
                    if not drop or not drop:IsA('BasePart') or drop.Name ~= '_drop' then
                        return
                    end

                    if pickupDropObservers[drop] then
                        RefreshPickupDrop(drop)
                        return
                    end

                    local observer = {}
                    pickupDropObservers[drop] = observer

                    observer.ChildAddedConnection = drop.ChildAdded:Connect(GuardRivalsCallback('PickupDrop_ChildAdded', function()
                        RefreshPickupDrop(drop)
                    end))
                    observer.ChildRemovedConnection = drop.ChildRemoved:Connect(GuardRivalsCallback('PickupDrop_ChildRemoved', function()
                        RefreshPickupDrop(drop)
                    end))

                    RefreshPickupDrop(drop)
                end

                function LocalPickupObserver.UnobserveDrop(drop)
                    ClearPickupDropKinds(drop)
                    DisconnectPickupDropObserver(drop)
                end

                function LocalPickupObserver.ResetDropTracking()
                    for drop in pairs(pickupDropObservers) do
                        DisconnectPickupDropObserver(drop)
                    end

                    for drop in pairs(pickupDropsByKind.Health) do
                        pickupDropsByKind.Health[drop] = nil
                    end

                    for drop in pairs(pickupDropsByKind.Ammo) do
                        pickupDropsByKind.Ammo[drop] = nil
                    end
                end

                function LocalPickupObserver.FindNearestDrop(pickupKind, touchPart)
                    if not IsRivalsPickupPlace() or not touchPart or not touchPart.Parent then
                        return nil
                    end

                    if pickupKind == 'Health' and (not Humanoid or Humanoid.Health >= Humanoid.MaxHealth) then
                        return nil
                    end

                    local nearestDrop = nil
                    local nearestDistance = nil
                    local candidateDrops = pickupDropsByKind[pickupKind]

                    if not candidateDrops then
                        return nil
                    end

                    for drop in pairs(candidateDrops) do
                        if drop.Parent ~= Workspace then
                            ClearPickupDropKinds(drop)
                            DisconnectPickupDropObserver(drop)
                        else
                            local dropKind = GetRivalsPickupKind(drop)
                            local hasTouchInterest = drop:FindFirstChildOfClass('TouchTransmitter') ~= nil
                            if dropKind == pickupKind and drop.CanTouch == true and hasTouchInterest then
                                local distance = (drop.Position - touchPart.Position).Magnitude
                                if not nearestDistance or distance < nearestDistance then
                                    nearestDrop = drop
                                    nearestDistance = distance
                                end
                            end
                        end
                    end

                    return nearestDrop
                end
            end

            function LocalPickupObserver.CancelRetry()
                LocalPickupObserver.RetryActive = false
                LocalPickupObserver.RetryNonce = LocalPickupObserver.RetryNonce + 1
            end

            function LocalPickupObserver.SyncRetry(shouldRetry)
                if not shouldRetry then
                    LocalPickupObserver.CancelRetry()
                    return
                end

                if LocalPickupObserver.RetryActive then
                    return
                end

                LocalPickupObserver.RetryActive = true
                LocalPickupObserver.RetryNonce = LocalPickupObserver.RetryNonce + 1
                local retryNonce = LocalPickupObserver.RetryNonce

                task.spawn(GuardRivalsCallback('Pickup_Retry', function()
                    while LocalPickupObserver.RetryActive and LocalPickupObserver.RetryNonce == retryNonce do
                        task.wait(LocalPickupObserver.RetryDelay)
                        if LocalPickupObserver.RetryNonce ~= retryNonce or not LocalPickupObserver.RetryActive then
                            return
                        end

                        if not UpdateRivalsPickupFeatures or not UpdateRivalsPickupFeatures() then
                            LocalPickupObserver.RetryActive = false
                            return
                        end
                    end
                end))
            end

            UpdateRivalsPickupFeatures = function()
                if not __kicia_hook_genv.KiciaHookCaps.gate('Auto Pickup', 'firetouchinterest') then
                    LocalPickupObserver.CancelRetry()
                    return false
                end
                if not IsRivalsPickupPlace() or not InitCharacter() or not Humanoid or Humanoid.Health <= 0 then
                    LocalPickupObserver.CancelRetry()
                    return false
                end

                local touchPart = GetRivalsPickupTouchPart()
                if not touchPart then
                    LocalPickupObserver.CancelRetry()
                    return false
                end

                local touchedDrop = false
                local shouldRetry = false
                local missingHealth = math.max(Humanoid.MaxHealth - Humanoid.Health, 0)

                if Toggles.P8S1T1 and Toggles.P8S1T1.Value and missingHealth >= 25 then
                    shouldRetry = true
                    local healthDrop = LocalPickupObserver.FindNearestDrop('Health', touchPart)
                    if healthDrop then
                        touchedDrop = TouchRivalsPickupDrop(healthDrop, touchPart)
                    end
                end

                local fighter = ResolveLocalFighter()
                local item = fighter and fighter.EquippedItem or nil
                local ammo = ReadItemValue(item, 'Ammo')
                if not touchedDrop and Toggles.P8S1T2 and Toggles.P8S1T2.Value and type(ammo) == 'number' and ammo <= 0 then
                    shouldRetry = true
                    local ammoDrop = LocalPickupObserver.FindNearestDrop('Ammo', touchPart)
                    if ammoDrop then
                        TouchRivalsPickupDrop(ammoDrop, touchPart)
                    end
                end

                LocalPickupObserver.SyncRetry(shouldRetry)
                return shouldRetry
            end

            local function RefreshLocalPickupHealthObserver()
                if not IsRivalsPickupPlace() or not InitCharacter() or not Humanoid then
                    DisconnectWeaponInfoConnection(LocalPickupObserver, 'HealthChanged')
                    return
                end

                ConnectWeaponInfoSignal(Humanoid.HealthChanged, LocalPickupObserver, 'HealthChanged', function()
                    local missingHealth = math.max(Humanoid.MaxHealth - Humanoid.Health, 0)
                    if missingHealth >= 25 then
                        UpdateRivalsPickupFeatures()
                    end
                end)
            end

            do
            local function IsRivalsModToggleEnabled(toggleId)
                local toggle = Toggles[toggleId]
                return toggle ~= nil and toggle.Value == true
            end

            local function ReadRivalsModNumber(optionId, fallback)
                local option = Options[optionId]
                if option ~= nil and type(option.Value) == 'number' then
                    return option.Value
                end

                return fallback
            end

            -- __KICIA_NOSPREAD_INPUT_HOOK_BEGIN__
            -- Exact Kicia chain: InputBinding -> shared InputHook dispatch packet -> NoSpread.
            RivalsModsState.KiciaInputBinding = {}
            RivalsModsState.KiciaInputBinding.__index = RivalsModsState.KiciaInputBinding

            function RivalsModsState.KiciaInputBinding.new(handleSetEnabled, handleDestroy)
                return setmetatable({
                    _handleSetEnabled = handleSetEnabled,
                    _handleDestroy = handleDestroy,
                    enabled = false,
                }, RivalsModsState.KiciaInputBinding)
            end

            function RivalsModsState.KiciaInputBinding:SetHandler(handler)
                self.handler = handler
            end

            function RivalsModsState.KiciaInputBinding:SetEnabled(enabled)
                self.enabled = enabled
                self._handleSetEnabled(enabled)
            end

            function RivalsModsState.KiciaInputBinding:Destroy()
                self._handleDestroy()
            end

            RivalsModsState.KiciaInputHookErrorReporter = {}
            RivalsModsState.KiciaInputHookErrorReporter.__index = RivalsModsState.KiciaInputHookErrorReporter

            function RivalsModsState.KiciaInputHookErrorReporter.new()
                return setmetatable({
                    _errors = {},
                }, RivalsModsState.KiciaInputHookErrorReporter)
            end

            function RivalsModsState.KiciaInputHookErrorReporter:ReportResult(result)
                if not result.ok then
                    table.insert(self._errors, result.error)
                    ReportRivalsRuntimeIssue('mods_no_spread_input_hook', result.error)
                end
                return result
            end

            function RivalsModsState.KiciaInputHookErrorReporter:Destroy()
                table.clear(self._errors)
            end

            function RivalsModsState.CreateKiciaInputHookPrototype(clientItem, useItemRemote, decodeInput)
                local cleanRemote = Instance.new('RemoteEvent')
                local fireServerNative = clonefunction(cleanRemote.FireServer)
                local voidOk = {
                    ok = true,
                }

                local function inputHookError(stage, message)
                    return {
                        ok = false,
                        error = 'InputHook/' .. stage .. ': ' .. message,
                    }
                end

                local inputHookPrototype = {}
                inputHookPrototype.__index = inputHookPrototype

                function inputHookPrototype.new()
                    local inputHook = setmetatable({
                        _errorReporter = RivalsModsState.KiciaInputHookErrorReporter.new(),
                        _inputBindings = {},
                        _dummy = Color3.new(),
                    }, inputHookPrototype)
                    inputHook:_Initialize()
                    return inputHook
                end

                function inputHookPrototype:_Initialize()
                    local function fireServer(_, objectId, encodedType, args)
                        local packet = {
                            block = false,
                            objectId = objectId,
                            type = decodeInput(encodedType),
                            args = args,
                        }
                        self:_Dispatch(packet)
                        if packet.block then
                            return
                        end
                        return fireServerNative(useItemRemote, objectId, encodedType, args, nil)
                    end

                    local remoteTree = {
                        Replication = {
                            Fighter = {
                                UseItem = {
                                    FireServer = fireServer,
                                },
                            },
                        },
                    }
                    setrawmetatable(self._dummy, {
                        __index = function()
                            return remoteTree
                        end,
                    })
                end

                function inputHookPrototype:Reserve()
                    local binding
                    binding = RivalsModsState.KiciaInputBinding.new(
                        function(enabled)
                            if enabled then
                                self._errorReporter:ReportResult(self:_Load())
                            end
                        end,
                        function()
                            for index, candidate in ipairs(self._inputBindings) do
                                if candidate == binding then
                                    table.remove(self._inputBindings, index)
                                    break
                                end
                            end
                        end
                    )
                    table.insert(self._inputBindings, binding)
                    return binding
                end

                function inputHookPrototype:_Dispatch(packet)
                    for _, binding in ipairs(self._inputBindings) do
                        if binding.enabled and binding.handler ~= nil then
                            binding.handler(packet)
                            if packet.block then
                                break
                            end
                        end
                    end
                end

                function inputHookPrototype:_Load()
                    if self._restore ~= nil then
                        return voidOk
                    end

                    local inputMethod = rawget(clientItem, 'Input')
                    if inputMethod == nil then
                        return inputHookError('function_lookup', 'Failed to find Input in prototype')
                    end

                    for index, value in pairs(debug.getupvalues(inputMethod)) do
                        if typeof(value) == 'Instance' then
                            local matches = false
                            if compareinstances ~= nil then
                                matches = compareinstances(value, ReplicatedStorage)
                            end
                            if not matches then
                                matches = value == ReplicatedStorage
                            end
                            if matches then
                                debug.setupvalue(inputMethod, index, self._dummy)
                                self._restore = {
                                    method = inputMethod,
                                    index = index,
                                    original = value,
                                }
                            end
                        end
                    end

                    -- Current RIVALS virtualizes this same dependency inside a
                    -- table upvalue. Kicia's QuickAttackHook installs/restores
                    -- this VM shape through an exact bundle/key/original record.
                    if self._restore == nil then
                        for _, bundle in pairs(debug.getupvalues(inputMethod)) do
                            if type(bundle) == 'table' then
                                for key, value in pairs(bundle) do
                                    local matches = false
                                    if typeof(value) == 'Instance' then
                                        if compareinstances ~= nil then
                                            matches = compareinstances(value, ReplicatedStorage)
                                        end
                                        if not matches then
                                            matches = value == ReplicatedStorage
                                        end
                                    end
                                    if matches then
                                        self._restore = {
                                            bundle = bundle,
                                            key = key,
                                            original = value,
                                        }
                                        bundle[key] = self._dummy
                                        break
                                    end
                                end
                                if self._restore ~= nil then
                                    break
                                end
                            end
                        end
                    end

                    if self._restore ~= nil then
                        return voidOk
                    end
                    return inputHookError('upvalue_scan', 'Failed to find ReplicatedStorage upvalue')
                end

                function inputHookPrototype:_Revert()
                    local restore = self._restore
                    if restore == nil then
                        return
                    end
                    self._restore = nil
                    if restore.bundle ~= nil then
                        restore.bundle[restore.key] = restore.original
                    else
                        debug.setupvalue(restore.method, restore.index, restore.original)
                    end
                end

                function inputHookPrototype:Destroy()
                    self:_Revert()
                    self._errorReporter:Destroy()
                end

                return inputHookPrototype
            end

            RivalsModsState.KiciaNoSpreadPrototype = {}
            RivalsModsState.KiciaNoSpreadPrototype.__index = RivalsModsState.KiciaNoSpreadPrototype

            function RivalsModsState.KiciaNoSpreadPrototype.new(inputBinding, playerContext)
                local noSpread = setmetatable({
                    _inputBinding = inputBinding,
                    _playerContext = playerContext,
                }, RivalsModsState.KiciaNoSpreadPrototype)
                inputBinding:SetHandler(function(packet)
                    noSpread:_HandleInput(packet)
                end)
                return noSpread
            end

            function RivalsModsState.KiciaNoSpreadPrototype:SetEnabled(enabled)
                self._inputBinding:SetEnabled(enabled)
            end

            function RivalsModsState.KiciaNoSpreadPrototype:_HandleInput(packet)
                if packet.type ~= 'StartShooting' then
                    return
                end
                local inner = self._playerContext.inner
                if inner == nil then
                    return
                end
                local item = inner.fighterState:GetItemById(packet.objectId)
                if item == nil then
                    return
                end
                if rawget(rawget(item, 'Info'), 'Type') == 'Gun' then
                    packet.args["\2"] = true
                end
            end

            function RivalsModsState.KiciaNoSpreadPrototype:Destroy()
                self._inputBinding:Destroy()
            end

            -- Grenade Fuse: 1:1 port of Kicia's throwable fuse controller [118096]. Rides its own
            -- binding on the shared input hook. Cooks only (Info.CanCook). On the start input it
            -- caches the trajectory visual and, for Remove Fuse, nils the item's
            -- _cook_detonate_delay; on the finish input it rewrites the byte-3 fuse-time argument.
            -- Remove Fuse also installs a replacer (Kicia's SetRemoveFuse does the same): the start-input
            -- nil fires after the game already armed the cook timer, so _EnsureStartThrowReplacer nils
            -- the same field one call earlier -- inside Throwable._StartThrow, before its task.delay check.
            RivalsModsState.KiciaGrenadeFusePrototype = {}
            RivalsModsState.KiciaGrenadeFusePrototype.__index = RivalsModsState.KiciaGrenadeFusePrototype

            function RivalsModsState.KiciaGrenadeFusePrototype.new(inputBinding, playerContext)
                local grenadeFuse = setmetatable({
                    _inputBinding = inputBinding,
                    _playerContext = playerContext,
                    _explodeOn = 'Impact',
                    _removeFuse = false,
                    _trajectoryVisual = nil,
                    _startThrowReplacerInstalled = false,
                    _throwablePrototype = nil,
                    _originalStartThrow = nil,
                }, RivalsModsState.KiciaGrenadeFusePrototype)
                inputBinding:SetHandler(function(packet)
                    grenadeFuse:_HandleInput(packet)
                end)
                return grenadeFuse
            end

            function RivalsModsState.KiciaGrenadeFusePrototype:SetEnabled(enabled)
                self._inputBinding:SetEnabled(enabled)
            end

            function RivalsModsState.KiciaGrenadeFusePrototype:SetExplodeOn(explodeOn)
                self._explodeOn = explodeOn
            end

            function RivalsModsState.KiciaGrenadeFusePrototype:SetRemoveFuse(removeFuse)
                self._removeFuse = removeFuse
                if removeFuse then
                    self:_EnsureStartThrowReplacer()
                else
                    self:_RestoreStartThrowReplacer()
                end
            end

            -- Kicia's SetRemoveFuse installs/destroys a replacer (its VM-obfuscated eU) alongside the
            -- start-input _cook_detonate_delay nil. On this build that nil is one throw too late: the game
            -- arms the cook timer inside Throwable._StartThrow (task.delay(_cook_detonate_delay, ...)),
            -- which runs before our input hook (it intercepts UseItem, i.e. replication) sees
            -- the throw. So our replacer wraps Throwable._StartThrow and nils the same field for that call,
            -- so the timer branch is skipped for every cook including a fresh grenade's first. Restored
            -- when Remove Fuse turns off. Field writes only -- no prints/logging on the prototype.
            function RivalsModsState.KiciaGrenadeFusePrototype:_EnsureStartThrowReplacer()
                if self._startThrowReplacerInstalled then
                    return
                end
                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local modules = playerScripts and playerScripts:FindFirstChild('Modules')
                local itemTypes = modules and modules:FindFirstChild('ItemTypes')
                local throwableModule = itemTypes and itemTypes:FindFirstChild('Throwable')
                if not throwableModule then
                    return
                end
                local ok, throwable = pcall(require, throwableModule)
                if not ok or type(throwable) ~= 'table' then
                    return
                end
                local original = rawget(throwable, '_StartThrow')
                if type(original) ~= 'function' then
                    return
                end
                self._throwablePrototype = throwable
                self._originalStartThrow = original
                local controller = self
                rawset(throwable, '_StartThrow', function(item, ...)
                    if controller._removeFuse then
                        rawset(item, '_cook_detonate_delay', nil)
                    end
                    return original(item, ...)
                end)
                self._startThrowReplacerInstalled = true
            end

            function RivalsModsState.KiciaGrenadeFusePrototype:_RestoreStartThrowReplacer()
                if not self._startThrowReplacerInstalled then
                    return
                end
                if self._throwablePrototype and self._originalStartThrow then
                    rawset(self._throwablePrototype, '_StartThrow', self._originalStartThrow)
                end
                self._startThrowReplacerInstalled = false
                self._throwablePrototype = nil
                self._originalStartThrow = nil
            end

            -- Kicia f7799 [118070]: walk the trajectory segments to the impact sphere and return
            -- min(cap, (index - 2) * step) using the recovered _last_args slots 4 (step, default
            -- 0.05) and 6 (cap, default math.huge). Live-verified: the game's
            -- TrajectoryVisual._segments is a plain array of parts (the game iterates it with
            -- pairs), NOT a callable iterator -- so we walk it with next(), not segments(nil, key).
            function RivalsModsState.KiciaGrenadeFusePrototype:_ComputeImpactTime(trajectoryVisual)
                local lastArgs = rawget(trajectoryVisual, '_last_args')
                local step = lastArgs[4]
                if not step then
                    step = 0.05
                end
                local cap = lastArgs[6]
                if not cap then
                    cap = math.huge
                end
                local impactCFrame = rawget(trajectoryVisual, '_impact_sphere').CFrame
                local segments = rawget(trajectoryVisual, '_segments')
                local key
                while true do
                    local segment
                    key, segment = next(segments, key)
                    if key == nil then
                        break
                    end
                    if segment.CFrame == impactCFrame then
                        return math.min(cap, (key - 2) * step)
                    end
                end
                return nil
            end

            function RivalsModsState.KiciaGrenadeFusePrototype:_HandleInput(packet)
                local packetType = packet.type
                local isStart = packetType == 'StartShooting' or packetType == 'StartAiming'
                local isFinish = packetType == 'FinishShooting' or packetType == 'FinishAiming'
                if not (isStart or isFinish) then
                    return
                end
                local inner = self._playerContext.inner
                if inner == nil then
                    return
                end
                local item = inner.fighterState:GetItemById(packet.objectId)
                if item == nil then
                    return
                end
                if not rawget(rawget(item, 'Info'), 'CanCook') then
                    return
                end
                if isStart then
                    self._trajectoryVisual = rawget(item, '_trajectory_visual')
                    if self._removeFuse then
                        rawset(item, '_cook_detonate_delay', nil)
                    end
                    return
                end
                if self._explodeOn == 'Throw' then
                    packet.args['\3'] = 0
                else
                    local trajectoryVisual = self._trajectoryVisual
                    if trajectoryVisual then
                        trajectoryVisual = self:_ComputeImpactTime(trajectoryVisual)
                    end
                    packet.args['\3'] = trajectoryVisual
                end
                self._trajectoryVisual = nil
            end

            function RivalsModsState.KiciaGrenadeFusePrototype:Destroy()
                self:_RestoreStartThrowReplacer()
                self._inputBinding:Destroy()
            end

            RivalsModsState.KiciaLocalFighterState = {}
            RivalsModsState.KiciaLocalFighterState.__index = RivalsModsState.KiciaLocalFighterState

            function RivalsModsState.KiciaLocalFighterState.new()
                return setmetatable({}, RivalsModsState.KiciaLocalFighterState)
            end

            function RivalsModsState.KiciaLocalFighterState:GetItems()
                local fighter = ResolveLocalFighter()
                local items = type(fighter) == 'table' and rawget(fighter, 'Items') or nil
                if type(items) == 'table' then
                    return items
                end
                return {}
            end

            function RivalsModsState.KiciaLocalFighterState:GetItemById(objectId)
                for _, item in next, self:GetItems() do
                    if objectId == rawget(rawget(item, 'Data'), 'ObjectID') then
                        return item
                    end
                end
                return nil
            end

            function RivalsModsState.ResolveNoSpreadClientItem()
                local state = RivalsModsState
                if state.NoSpreadClientItem then
                    return state.NoSpreadClientItem
                end

                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local modules = playerScripts and playerScripts:FindFirstChild('Modules')
                local replicated = modules and modules:FindFirstChild('ClientReplicatedClasses')
                local fighter = replicated and replicated:FindFirstChild('ClientFighter')
                local clientItemModule = fighter and fighter:FindFirstChild('ClientItem')
                if not clientItemModule then
                    return nil
                end

                local ok, clientItem = pcall(require, clientItemModule)
                if not ok or type(clientItem) ~= 'table' then
                    return nil
                end

                state.NoSpreadClientItem = clientItem
                return clientItem
            end

            function RivalsModsState.ResolveNoSpreadRemote()
                local state = RivalsModsState
                if state.NoSpreadRemote then
                    return state.NoSpreadRemote
                end

                local remotes = ReplicatedStorage:FindFirstChild('Remotes')
                local replication = remotes and remotes:FindFirstChild('Replication')
                local fighter = replication and replication:FindFirstChild('Fighter')
                local remote = fighter and fighter:FindFirstChild('UseItem')
                if not remote or not remote:IsA('RemoteEvent') then
                    return nil
                end

                state.NoSpreadRemote = cloneref(remote)
                return state.NoSpreadRemote
            end

            function RivalsModsState.EnsureKiciaInputHook()
                local state = RivalsModsState
                if state.KiciaInputHook and state.NoSpreadController and state.GrenadeFuseController then
                    return true
                end
                if type(setrawmetatable) ~= 'function'
                    or type(clonefunction) ~= 'function'
                    or type(debug.getupvalues) ~= 'function'
                    or type(debug.setupvalue) ~= 'function' then
                    return false
                end

                local clientItem = RivalsModsState.ResolveNoSpreadClientItem()
                local remote = RivalsModsState.ResolveNoSpreadRemote()
                local enumLibrary = ResolveEnumLibrary()
                local fromEnum = type(enumLibrary) == 'table' and rawget(enumLibrary, '_from_enum') or nil
                if type(clientItem) ~= 'table' or not remote or type(fromEnum) ~= 'table' then
                    return false
                end

                local playerContext = {
                    inner = {
                        fighterState = RivalsModsState.KiciaLocalFighterState.new(),
                    },
                }

                local ok, inputHookOrError = pcall(function()
                    local inputHookPrototype = state.KiciaInputHookPrototype
                    if inputHookPrototype == nil then
                        inputHookPrototype = RivalsModsState.CreateKiciaInputHookPrototype(
                            clientItem,
                            remote,
                            function(encodedType)
                                return rawget(fromEnum, encodedType)
                            end
                        )
                        state.KiciaInputHookPrototype = inputHookPrototype
                    end
                    local inputHook = inputHookPrototype.new()
                    state.KiciaInputHook = inputHook
                    state.NoSpreadPlayerContext = playerContext
                    state.NoSpreadController = RivalsModsState.KiciaNoSpreadPrototype.new(
                        inputHook:Reserve(),
                        playerContext
                    )
                    state.GrenadeFuseController = RivalsModsState.KiciaGrenadeFusePrototype.new(
                        inputHook:Reserve(),
                        playerContext
                    )
                    return inputHook
                end)
                if not ok then
                    ReportRivalsRuntimeIssue('mods_no_spread_input_hook_initialize', inputHookOrError)
                    return false
                end
                return inputHookOrError ~= nil
            end

            function RivalsModsState.SyncNoSpreadEnabled()
                local state = RivalsModsState
                local controller = state.NoSpreadController
                if not controller then
                    return false
                end
                local enabled = IsRivalsModToggleEnabled('P4S1T3')
                if controller._inputBinding.enabled ~= enabled then
                    controller:SetEnabled(enabled)
                end
                return true
            end

            function RivalsModsState.SyncGrenadeFuse()
                local state = RivalsModsState
                local controller = state.GrenadeFuseController
                if not controller then
                    return false
                end
                local enabled = IsRivalsModToggleEnabled('P4S1T6')
                local explodeOn = Options and Options.P4S1D1 and Options.P4S1D1.Value
                controller:SetExplodeOn(type(explodeOn) == 'string' and explodeOn or 'Impact')
                controller:SetRemoveFuse(IsRivalsModToggleEnabled('P4S1T7'))
                if controller._inputBinding.enabled ~= enabled then
                    controller:SetEnabled(enabled)
                end
                return true
            end

            function RivalsModsState.RestoreKiciaInputHook()
                local state = RivalsModsState
                if state.NoSpreadController then
                    state.NoSpreadController:Destroy()
                end
                if state.GrenadeFuseController then
                    state.GrenadeFuseController:Destroy()
                end
                if state.KiciaInputHook then
                    state.KiciaInputHook:Destroy()
                end
                state.NoSpreadController = nil
                state.GrenadeFuseController = nil
                state.NoSpreadPlayerContext = nil
                state.KiciaInputHook = nil
                state.NoSpreadClientItem = nil
                state.NoSpreadRemote = nil
            end
            -- __KICIA_NOSPREAD_INPUT_HOOK_END__

            function RivalsModsState.StoreOriginalItemInfo(item)
                local state = RivalsModsState
                if type(item) ~= 'table' or state.OriginalItemInfo[item] ~= nil then
                    return
                end

                local info = item.Info
                if type(info) ~= 'table' then
                    return
                end

                local inputSpammingEnabled = rawget(info, 'InputSpammingEnabled')
                state.OriginalItemInfo[item] = {
                    Info = info,
                    HasDashCooldown = rawget(info, 'DashCooldown') ~= nil,
                    DashCooldown = rawget(info, 'DashCooldown'),
                    HasMaxDoubleJumps = rawget(info, 'MaxDoubleJumps') ~= nil,
                    MaxDoubleJumps = rawget(info, 'MaxDoubleJumps'),
                    HasInputSpammingEnabled = inputSpammingEnabled ~= nil,
                    InputSpammingEnabled = type(inputSpammingEnabled) == 'table'
                        and table.clone(inputSpammingEnabled)
                        or inputSpammingEnabled,
                }
            end

            function RivalsModsState.ApplyPersistentItemModifiers(item)
                RivalsModsState.StoreOriginalItemInfo(item)

                local original = RivalsModsState.OriginalItemInfo[item]
                local info = original and original.Info or nil
                if type(info) ~= 'table' then
                    return
                end

                if IsRivalsModToggleEnabled('P4S2T4') then
                    local inputSpammingEnabled = original.InputSpammingEnabled
                    if type(inputSpammingEnabled) == 'table' then
                        local automaticInputSpamming = table.clone(inputSpammingEnabled)
                        automaticInputSpamming.StartShooting = 0
                        automaticInputSpamming.StartReloading = 0
                        rawset(info, 'InputSpammingEnabled', automaticInputSpamming)
                    end
                elseif original.HasInputSpammingEnabled then
                    rawset(info, 'InputSpammingEnabled', type(original.InputSpammingEnabled) == 'table'
                        and table.clone(original.InputSpammingEnabled)
                        or original.InputSpammingEnabled)
                else
                    rawset(info, 'InputSpammingEnabled', nil)
                end

                if IsRivalsModToggleEnabled('P4S2T5') then
                    rawset(info, 'MaxDoubleJumps', 676767)
                elseif original.HasMaxDoubleJumps then
                    rawset(info, 'MaxDoubleJumps', original.MaxDoubleJumps)
                else
                    rawset(info, 'MaxDoubleJumps', nil)
                end

                if IsRivalsModToggleEnabled('P4S1T5') and type(original.DashCooldown) == 'number' then
                    local reduction = math.clamp(ReadRivalsModNumber('P4S1S5', 75), 0, 100) / 100
                    rawset(info, 'DashCooldown', original.DashCooldown * (1 - reduction))
                elseif original.HasDashCooldown then
                    rawset(info, 'DashCooldown', original.DashCooldown)
                else
                    rawset(info, 'DashCooldown', nil)
                end
            end

            function RivalsModsState.RestorePersistentItem(item)
                local state = RivalsModsState
                local original = state.OriginalItemInfo[item]
                local info = original and original.Info or nil
                if type(info) == 'table' then
                    if original.HasInputSpammingEnabled then
                        rawset(info, 'InputSpammingEnabled', type(original.InputSpammingEnabled) == 'table'
                            and table.clone(original.InputSpammingEnabled)
                            or original.InputSpammingEnabled)
                    else
                        rawset(info, 'InputSpammingEnabled', nil)
                    end

                    if original.HasMaxDoubleJumps then
                        rawset(info, 'MaxDoubleJumps', original.MaxDoubleJumps)
                    else
                        rawset(info, 'MaxDoubleJumps', nil)
                    end

                    if original.HasDashCooldown then
                        rawset(info, 'DashCooldown', original.DashCooldown)
                    else
                        rawset(info, 'DashCooldown', nil)
                    end
                end

                state.OriginalItemInfo[item] = nil
            end

            function RivalsModsState.DisconnectPersistentItemSignals()
                local state = RivalsModsState
                for _, connectionName in ipairs({ 'InfoModifierItemAdded', 'InfoModifierItemRemoved' }) do
                    local connection = state[connectionName]
                    if connection then
                        pcall(function()
                            connection:Disconnect()
                        end)
                    end
                    state[connectionName] = nil
                end
                state.InfoModifierFighter = nil
            end

            function RivalsModsState.RestorePersistentItemModifiers(disconnectSignals)
                local state = RivalsModsState
                local trackedItems = {}
                for item in pairs(state.OriginalItemInfo) do
                    trackedItems[#trackedItems + 1] = item
                end
                for _, item in ipairs(trackedItems) do
                    RivalsModsState.RestorePersistentItem(item)
                end

                if disconnectSignals then
                    RivalsModsState.DisconnectPersistentItemSignals()
                end
            end

            function RivalsModsState.RefreshPersistentItemModifiers()
                local state = RivalsModsState
                local fighter = ResolveLocalFighter()
                if fighter ~= state.InfoModifierFighter then
                    RivalsModsState.RestorePersistentItemModifiers(true)
                    state.InfoModifierFighter = fighter
                    if fighter then
                        if fighter.ItemAdded and type(fighter.ItemAdded.Connect) == 'function' then
                            state.InfoModifierItemAdded = fighter.ItemAdded:Connect(GuardRivalsCallback('Mods_ItemAdded', function(item)
                                RivalsModsState.ApplyPersistentItemModifiers(item)
                            end))
                        end
                        if fighter.ItemRemoved and type(fighter.ItemRemoved.Connect) == 'function' then
                            state.InfoModifierItemRemoved = fighter.ItemRemoved:Connect(GuardRivalsCallback('Mods_ItemRemoved', function(item)
                                RivalsModsState.RestorePersistentItem(item)
                            end))
                        end
                    end
                end

                if not fighter or type(fighter.Items) ~= 'table' then
                    return false
                end

                for _, item in pairs(fighter.Items) do
                    RivalsModsState.ApplyPersistentItemModifiers(item)
                end
                return true
            end

            function RivalsModsState.ResolveCameraController()
                local state = RivalsModsState
                if state.CameraController then
                    return state.CameraController
                end

                if not IsReplicatedStateReady() then
                    return nil
                end

                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local controllers = playerScripts and playerScripts:FindFirstChild('Controllers')
                local cameraControllerModule = controllers and controllers:FindFirstChild('CameraController')
                if not cameraControllerModule then
                    return nil
                end

                local ok, cameraController = pcall(require, cameraControllerModule)
                if not ok or type(cameraController) ~= 'table' then
                    return nil
                end

                state.CameraController = cameraController
                return cameraController
            end

            function RivalsModsState.UpdateCameraModifiers()
                local state = RivalsModsState
                local cameraController = RivalsModsState.ResolveCameraController()
                if cameraController then
                    if IsRivalsModToggleEnabled('P4S2T6') then
                        if state.CameraShakeOriginalEnabled == nil then
                            state.CameraShakeOriginalEnabled = cameraController._shake_enabled
                        end
                        cameraController._shake_enabled = false
                    elseif state.CameraShakeOriginalEnabled ~= nil then
                        cameraController._shake_enabled = state.CameraShakeOriginalEnabled
                        state.CameraShakeOriginalEnabled = nil
                    end

                    if IsRivalsModToggleEnabled('P4S2T8') then
                        if not state.CameraThirdPersonCaptured then
                            state.CameraThirdPersonCaptured = true
                            state.CameraThirdPersonOriginal = cameraController._third_person_override
                        end
                        if cameraController._third_person_override ~= true
                            and type(cameraController.SetThirdPersonOverride) == 'function' then
                            cameraController:SetThirdPersonOverride(true)
                        end
                    elseif state.CameraThirdPersonCaptured then
                        if type(cameraController.SetThirdPersonOverride) == 'function' then
                            cameraController:SetThirdPersonOverride(state.CameraThirdPersonOriginal)
                        end
                        state.CameraThirdPersonCaptured = false
                        state.CameraThirdPersonOriginal = nil
                    end

                    if type(cameraController.SetExternalFOVOffset) == 'function' then
                        local targetFov = ReadRivalsModNumber('P4S2S4', 80)
                        local baseFov = type(cameraController._base_fov) == 'number' and cameraController._base_fov or 80
                        local fovOffset = IsRivalsModToggleEnabled('P4S2T9') and (targetFov - baseFov) or 0
                        cameraController:SetExternalFOVOffset('KiciaHook', fovOffset)
                    end

                    if IsRivalsModToggleEnabled('P4S2T10') then
                        if state.CameraViewModelOriginal == nil then
                            state.CameraViewModelOriginal = cameraController.ViewModelOffsetCFrame
                        end
                        local viewModelOffset = CFrame.new(
                            ReadRivalsModNumber('P4S2S5', 0),
                            ReadRivalsModNumber('P4S2S6', 0),
                            ReadRivalsModNumber('P4S2S7', 0)
                        )
                        cameraController.ViewModelOffsetCFrame = (state.CameraViewModelOriginal or CFrame.identity) * viewModelOffset
                    elseif state.CameraViewModelOriginal ~= nil then
                        cameraController.ViewModelOffsetCFrame = state.CameraViewModelOriginal
                        state.CameraViewModelOriginal = nil
                    end
                end
                if type(RivalsModsState.RefreshViewmodelEffects) == 'function' then
                    RivalsModsState.RefreshViewmodelEffects()
                end
            end

            function RivalsModsState.ShouldSuppressViewmodelAnimation(animator, animationKey)
                if type(animationKey) ~= 'string' then
                    return false
                end
                if IsRivalsModToggleEnabled('P1S31T2')
                    and (string.find(animationKey, 'Shoot', 1, true) ~= nil or animationKey == 'QuickShot') then
                    return true
                end
                if IsRivalsModToggleEnabled('P1S31T3')
                    and animationKey == rawget(animator, '_sprint_animation') then
                    return true
                end
                if IsRivalsModToggleEnabled('P1S31T4')
                    and animationKey == rawget(animator, '_equip_animation') then
                    return true
                end
                if IsRivalsModToggleEnabled('P1S31T5')
                    and string.find(animationKey, 'Reload', 1, true) ~= nil then
                    return true
                end
                return false
            end

            function RivalsModsState.ApplyViewmodelMotionSuppression(items)
                if not IsRivalsModToggleEnabled('P1S31T1') then
                    return
                end
                for _, item in pairs(items) do
                    local viewModel = type(item) == 'table' and rawget(item, 'ViewModel') or nil
                    if type(viewModel) == 'table' then
                        for springName, value in pairs(RivalsModsState.MotionSpringValues) do
                            local spring = rawget(viewModel, springName)
                            if type(spring) == 'table' then
                                pcall(function()
                                    spring.Value = value
                                end)
                            end
                        end
                    end
                end
            end

            function RivalsModsState.RefreshViewmodelEffects()
                local state = RivalsModsState
                local fighter = ResolveLocalFighter()
                local items = fighter and type(fighter.Items) == 'table' and fighter.Items or {}
                state.ApplyViewmodelMotionSuppression(items)
                -- Kicia parity: the animation filters stop the track from ever starting,
                -- through the ViewModelAnimator.PlayAnimation replacement, instead of
                -- reacting to AnimationPlayed and stopping a track the game already began.
                RivalsRuntimeBridge.NativeRemovals.SyncAnimationHook()
            end

            function RivalsModsState.RestoreClientModifiers()
                local state = RivalsModsState
                if state.CameraController and state.CameraShakeOriginalEnabled ~= nil then
                    state.CameraController._shake_enabled = state.CameraShakeOriginalEnabled
                end
                if state.CameraController and state.CameraThirdPersonCaptured
                    and type(state.CameraController.SetThirdPersonOverride) == 'function' then
                    state.CameraController:SetThirdPersonOverride(state.CameraThirdPersonOriginal)
                end
                if state.CameraController and type(state.CameraController.SetExternalFOVOffset) == 'function' then
                    state.CameraController:SetExternalFOVOffset('KiciaHook', 0)
                end
                if state.CameraController and state.CameraViewModelOriginal ~= nil then
                    state.CameraController.ViewModelOffsetCFrame = state.CameraViewModelOriginal
                end
                state.CameraShakeOriginalEnabled = nil
                state.CameraThirdPersonCaptured = false
                state.CameraThirdPersonOriginal = nil
                state.CameraViewModelOriginal = nil
                state.CameraController = nil
                RivalsRuntimeBridge.NativeRemovals.RevertAnimationHook()
                RivalsModsState.RestorePersistentItemModifiers(true)
            end

            function RivalsModsState.ResolveGunModule()
                local state = RivalsModsState
                if state.GunModule then
                    return state.GunModule
                end

                if not IsReplicatedStateReady() then
                    return nil
                end

                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local modules = playerScripts and playerScripts:FindFirstChild('Modules')
                local itemTypes = modules and modules:FindFirstChild('ItemTypes')
                local gunModuleScript = itemTypes and itemTypes:FindFirstChild('Gun')
                if not gunModuleScript then
                    return nil
                end

                local ok, gunModule = pcall(require, gunModuleScript)
                if not ok then
                    return nil
                end

                state.GunModule = gunModule
                return gunModule
            end

            function RivalsModsState.ResolveMeleeModule()
                local state = RivalsModsState
                if state.MeleeModule then
                    return state.MeleeModule
                end

                if not IsReplicatedStateReady() then
                    return nil
                end

                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local modules = playerScripts and playerScripts:FindFirstChild('Modules')
                local itemTypes = modules and modules:FindFirstChild('ItemTypes')
                local meleeModuleScript = itemTypes and itemTypes:FindFirstChild('Melee')
                if not meleeModuleScript then
                    return nil
                end

                local ok, meleeModule = pcall(require, meleeModuleScript)
                if not ok then
                    return nil
                end

                state.MeleeModule = meleeModule
                return meleeModule
            end

            function RivalsModsState.ResolveGunbladeModule()
                local state = RivalsModsState
                if state.GunbladeModule then
                    return state.GunbladeModule
                end

                if not IsReplicatedStateReady() then
                    return nil
                end

                local playerScripts = LP:FindFirstChild('PlayerScripts')
                local modules = playerScripts and playerScripts:FindFirstChild('Modules')
                local items = modules and modules:FindFirstChild('Items')
                local gunbladeModuleScript = items and items:FindFirstChild('Gunblade')
                if not gunbladeModuleScript then
                    return nil
                end

                local ok, gunbladeModule = pcall(require, gunbladeModuleScript)
                if not ok then
                    return nil
                end

                state.GunbladeModule = gunbladeModule
                return gunbladeModule
            end

            function RivalsModsState.ResolveGunStartShootingBase(fallback)
                local gunModule = RivalsModsState.ResolveGunModule()
                if gunModule and type(gunModule.StartShooting) == 'function' then
                    local originalGunStartShooting = RivalsModsState.OriginalGunStartShooting
                    if fallback == originalGunStartShooting or fallback == gunModule.StartShooting then
                        return gunModule.StartShooting
                    end
                end

                local meleeModule = RivalsModsState.ResolveMeleeModule()
                if meleeModule and type(meleeModule.StartShooting) == 'function' then
                    local originalMeleeStartShooting = RivalsModsState.OriginalMeleeStartShooting
                    if fallback == originalMeleeStartShooting or fallback == meleeModule.StartShooting then
                        return meleeModule.StartShooting
                    end
                end

                local gunbladeModule = RivalsModsState.ResolveGunbladeModule()
                if gunbladeModule and type(gunbladeModule.StartShooting) == 'function' then
                    local originalGunbladeStartShooting = RivalsModsState.OriginalGunbladeStartShooting
                    if fallback == originalGunbladeStartShooting or fallback == gunbladeModule.StartShooting then
                        return gunbladeModule.StartShooting
                    end
                end

                return fallback
            end

            local function ResolveRivalsModsStartShootingItem(item)
                if type(item) == 'table' and type(item.Name) == 'string' and item.Name ~= '' then
                    return item
                end

                local fighter = ResolveLocalFighter()
                local equippedItem = fighter and fighter.EquippedItem or nil
                if type(equippedItem) == 'table' and type(equippedItem.Name) == 'string' and equippedItem.Name ~= '' then
                    return equippedItem
                end

                return nil
            end

            function ResolveRivalsWeaponSpeedScale()
                if not IsRivalsModToggleEnabled('P4S1T1') then
                    return 1
                end

                local weaponSpeedBoost = math.clamp(ReadRivalsModNumber('P4S1S4', 85), 0, 85)
                return 1 / (1 + (weaponSpeedBoost / 100))
            end

            local function ResolveRivalsReloadKey(item, reloadEnum)
                local info = item and item.Info or nil
                if not info then
                    return nil
                end

                if reloadEnum ~= nil and type(item.FromEnum) == 'function' then
                    local ok, resolvedReloadKey = pcall(function()
                        return item:FromEnum(reloadEnum)
                    end)
                    if ok and type(resolvedReloadKey) == 'string' then
                        return resolvedReloadKey
                    end
                end

                local currentAmmo = ReadItemValue(item, 'Ammo')
                if type(currentAmmo) == 'number' and currentAmmo <= 0 and info.HasEmptyReload then
                    return 'EmptyReload'
                end

                return 'Reload'
            end

            local function WithScaledRivalsReloadTimings(info, reloadKey, reloadDurationScale, callback)
                if type(callback) ~= 'function' then
                    return nil
                end

                if not info or type(reloadKey) ~= 'string' or type(reloadDurationScale) ~= 'number' or reloadDurationScale >= 0.999 then
                    return callback()
                end

                local timingFields = nil
                if info.ReloadType == 'Regular' then
                    timingFields = {
                        reloadKey .. 'Length',
                        reloadKey .. 'ActionTimestamp',
                    }
                elseif info.ReloadType == 'Segmented' then
                    timingFields = {
                        reloadKey .. 'StartLength',
                        reloadKey .. 'StartActionTimestamp',
                        reloadKey .. 'SegmentLength',
                        reloadKey .. 'SegmentActionTimestamp',
                        reloadKey .. 'FinishLength',
                        reloadKey .. 'FinishActionTimestamp',
                    }
                else
                    return callback()
                end

                local originalTimings = {}
                for _, fieldName in ipairs(timingFields) do
                    local fieldValue = info[fieldName]
                    if type(fieldValue) == 'number' then
                        originalTimings[fieldName] = fieldValue
                        info[fieldName] = math.max(0.05, fieldValue * reloadDurationScale)
                    end
                end

                local results = table.pack(pcall(callback))
                for fieldName, fieldValue in pairs(originalTimings) do
                    info[fieldName] = fieldValue
                end

                if not results[1] then
                    ReportRivalsRuntimeIssue('mods_reload_timings', results[2])
                    return nil
                end

                return table.unpack(results, 2, results.n)
            end

            local function StopRivalsEquipAnimations(item)
                local viewModel = item and item.ViewModel
                if not viewModel then
                    return
                end

                if type(viewModel.StopAnimation) == 'function' then
                    pcall(function()
                        viewModel:StopAnimation('Equip')
                    end)
                    pcall(function()
                        viewModel:StopAnimation('EquipEmpty')
                    end)
                    return
                end

                local animator = viewModel.Animator
                if animator and type(animator.StopAnimation) == 'function' then
                    pcall(function()
                        animator:StopAnimation('Equip')
                    end)
                    pcall(function()
                        animator:StopAnimation('EquipEmpty')
                    end)
                end
            end

            function RivalsModsState.EnsureGunHooks()
                local gunModule = RivalsModsState.ResolveGunModule()
                if not gunModule then
                    return false
                end

                local state = RivalsModsState

                if type(gunModule.StartShooting) == 'function' and not state.OriginalGunStartShooting then
                    local originalStartShooting = gunModule.StartShooting
                    state.OriginalGunStartShooting = originalStartShooting
                    gunModule.StartShooting = function(self, ...)
                        local item = ResolveRivalsModsStartShootingItem(self)
                        if not item then
                            return nil
                        end
                        local info = item.Info
                        local originalShootCooldown = nil
                        local originalBurstCooldown = nil
                        local originalQuickShotCooldown = nil
                        if IsRivalsModToggleEnabled('P4S1T1') and info then
                            local weaponSpeedScale = ResolveRivalsWeaponSpeedScale()
                            if type(info.ShootCooldown) == 'number' then
                                originalShootCooldown = info.ShootCooldown
                                info.ShootCooldown = math.max(0.001, originalShootCooldown * weaponSpeedScale)
                            end
                            if type(info.ShootBurstCooldown) == 'number' then
                                originalBurstCooldown = info.ShootBurstCooldown
                                info.ShootBurstCooldown = math.max(0.001, originalBurstCooldown * weaponSpeedScale)
                            end
                            if type(info.QuickShotCooldown) == 'number' then
                                originalQuickShotCooldown = info.QuickShotCooldown
                                info.QuickShotCooldown = math.max(0.001, originalQuickShotCooldown * weaponSpeedScale)
                            end
                        end

                        local didPrimeSilent, silentCamera, silentOriginalCFrame = false, nil, nil
                        if type(state.BeginAimbotSilentShot) == 'function' then
                            didPrimeSilent, silentCamera, silentOriginalCFrame = state.BeginAimbotSilentShot(item)
                        end

                        local results = table.pack(pcall(originalStartShooting, item, ...))

                        if type(state.FinishAimbotSilentShot) == 'function' then
                            state.FinishAimbotSilentShot(didPrimeSilent, silentCamera, silentOriginalCFrame)
                        end

                        if originalShootCooldown ~= nil then
                            info.ShootCooldown = originalShootCooldown
                        end
                        if originalBurstCooldown ~= nil then
                            info.ShootBurstCooldown = originalBurstCooldown
                        end
                        if originalQuickShotCooldown ~= nil then
                            info.QuickShotCooldown = originalQuickShotCooldown
                        end

                        if not results[1] then
                            ReportRivalsRuntimeIssue('mods_start_shooting', results[2])
                            return nil
                        end

                        return table.unpack(results, 2, results.n)
                    end
                end

                if type(gunModule.StartReloading) == 'function' and not state.OriginalGunStartReloading then
                    local originalStartReloading = gunModule.StartReloading
                    state.OriginalGunStartReloading = originalStartReloading
                    gunModule.StartReloading = function(self, forceReload, reloadEnum, animationEnum, segmentedCount)
                        if not IsRivalsModToggleEnabled('P4S1T2') then
                            return originalStartReloading(self, forceReload, reloadEnum, animationEnum, segmentedCount)
                        end

                        local reloadSpeedBoost = math.clamp(ReadRivalsModNumber('P4S1S3', 10), 0, 20)
                        if reloadSpeedBoost <= 0 then
                            return originalStartReloading(self, forceReload, reloadEnum, animationEnum, segmentedCount)
                        end

                        local reloadDurationScale = 1 - (reloadSpeedBoost / 100)
                        local resolvedReloadKey = ResolveRivalsReloadKey(self, reloadEnum)
                        return WithScaledRivalsReloadTimings(self and self.Info or nil, resolvedReloadKey, reloadDurationScale, function()
                            return originalStartReloading(self, forceReload, reloadEnum, animationEnum, segmentedCount)
                        end)
                    end
                end

                if type(gunModule._Recoil) == 'function' and not state.OriginalGunRecoil then
                    local originalRecoil = gunModule._Recoil
                    state.OriginalGunRecoil = originalRecoil
                    gunModule._Recoil = function(self, multiplier)
                        if IsRivalsModToggleEnabled('P4S1T4') and type(multiplier) == 'number' then
                            local reduction = math.clamp(ReadRivalsModNumber('P4S1S2', 100), 0, 100)
                            local reducedMultiplier = multiplier * (1 - (reduction / 100))
                            if reducedMultiplier <= 0.001 then
                                return
                            end
                            return originalRecoil(self, reducedMultiplier)
                        end

                        return originalRecoil(self, multiplier)
                    end
                end

                if type(gunModule.GetAimSpeed) == 'function' and not state.OriginalGunGetAimSpeed then
                    local originalGetAimSpeed = gunModule.GetAimSpeed
                    state.OriginalGunGetAimSpeed = originalGetAimSpeed
                    gunModule.GetAimSpeed = function(self)
                        local originalAimSpeed = originalGetAimSpeed(self)
                        if IsRivalsModToggleEnabled('P4S2T2') and type(originalAimSpeed) == 'number' then
                            local adsSpeedBoost = math.clamp(ReadRivalsModNumber('P4S2S2', 85), 0, 85)
                            return math.max(1, originalAimSpeed * (1 + (adsSpeedBoost / 100)))
                        end

                        return originalAimSpeed
                    end
                end

                if type(gunModule.Equip) == 'function' and not state.OriginalGunEquip then
                    local originalEquip = gunModule.Equip
                    state.OriginalGunEquip = originalEquip
                    gunModule.Equip = function(self, ...)
                        local results = table.pack(originalEquip(self, ...))
                        if IsRivalsModToggleEnabled('P4S2T3') then
                            local equipSpeedBoost = math.clamp(ReadRivalsModNumber('P4S2S3', 100), 0, 80)
                            local equipSpeedScale = 1 / (1 + (equipSpeedBoost / 100))
                            local now = tick()
                            local remainingEquipCooldown = type(self._equip_cooldown) == 'number' and math.max(self._equip_cooldown - now, 0) or 0
                            self._equip_cooldown = now + (remainingEquipCooldown * equipSpeedScale)

                            local equipHash = self._equip_hash
                            local scaledEquipDuration = remainingEquipCooldown * equipSpeedScale
                            task.delay(scaledEquipDuration, function()
                                if self and self._equip_hash == equipHash then
                                    StopRivalsEquipAnimations(self)
                                end
                            end)
                        end

                        return table.unpack(results, 1, results.n)
                    end
                end

                return true
            end

            function RivalsModsState.EnsureMeleeHooks()
                local meleeModule = RivalsModsState.ResolveMeleeModule()
                if not meleeModule then
                    return false
                end

                local state = RivalsModsState

                if type(meleeModule.StartShooting) == 'function' and not state.OriginalMeleeStartShooting then
                    local originalStartShooting = meleeModule.StartShooting
                    state.OriginalMeleeStartShooting = originalStartShooting
                    meleeModule.StartShooting = function(self, ...)
                        local item = ResolveRivalsModsStartShootingItem(self)
                        if not item then
                            return nil
                        end
                        local info = item.Info
                        local originalAttackCooldown = nil
                        if IsRivalsModToggleEnabled('P4S1T1') and info then
                            local weaponSpeedScale = ResolveRivalsWeaponSpeedScale()
                            if type(info.AttackCooldown) == 'number' then
                                originalAttackCooldown = info.AttackCooldown
                                info.AttackCooldown = math.max(0.001, originalAttackCooldown * weaponSpeedScale)
                            end
                        end

                        local results = table.pack(pcall(originalStartShooting, item, ...))
                        if originalAttackCooldown ~= nil then
                            info.AttackCooldown = originalAttackCooldown
                        end

                        if not results[1] then
                            ReportRivalsRuntimeIssue('mods_melee_start_shooting', results[2])
                            return nil
                        end

                        return table.unpack(results, 2, results.n)
                    end
                end

                return true
            end

            function RivalsModsState.EnsureGunbladeHooks()
                local gunbladeModule = RivalsModsState.ResolveGunbladeModule()
                if not gunbladeModule then
                    return false
                end

                local state = RivalsModsState

                if type(gunbladeModule.StartShooting) == 'function' and not state.OriginalGunbladeStartShooting then
                    local originalStartShooting = gunbladeModule.StartShooting
                    state.OriginalGunbladeStartShooting = originalStartShooting
                    gunbladeModule.StartShooting = function(self, ...)
                        local item = ResolveRivalsModsStartShootingItem(self)
                        if not item then
                            return nil
                        end
                        local info = item.Info
                        local originalBladeCooldown = nil
                        if IsRivalsModToggleEnabled('P4S1T1') and info and type(item and item.Get) == 'function' and item:Get('Mode') == 'Blade' then
                            local weaponSpeedScale = ResolveRivalsWeaponSpeedScale()
                            if type(info.BladeCooldown) == 'number' then
                                originalBladeCooldown = info.BladeCooldown
                                info.BladeCooldown = math.max(0.001, originalBladeCooldown * weaponSpeedScale)
                            end
                        end

                        local results = table.pack(pcall(originalStartShooting, item, ...))
                        if originalBladeCooldown ~= nil then
                            info.BladeCooldown = originalBladeCooldown
                        end

                        if not results[1] then
                            ReportRivalsRuntimeIssue('mods_gunblade_start_shooting', results[2])
                            return nil
                        end

                        return table.unpack(results, 2, results.n)
                    end
                end

                return true
            end

            function RivalsModsState.EnsureHooks()
                local state = RivalsModsState
                RivalsModsState.RefreshPersistentItemModifiers()
                RivalsModsState.UpdateCameraModifiers()
                if state.NoSpreadController then
                    RivalsModsState.SyncNoSpreadEnabled()
                end
                if state.GrenadeFuseController then
                    RivalsModsState.SyncGrenadeFuse()
                end

                if not (
                    IsRivalsModToggleEnabled('P4S1T1')
                    or IsRivalsModToggleEnabled('P4S1T2')
                    or IsRivalsModToggleEnabled('P4S1T3')
                    or IsRivalsModToggleEnabled('P4S1T4')
                    or IsRivalsModToggleEnabled('P4S1T5')
                    or IsRivalsModToggleEnabled('P4S1T6')
                    or IsRivalsModToggleEnabled('P4S1T7')
                    or IsRivalsModToggleEnabled('P4S2T2')
                    or IsRivalsModToggleEnabled('P4S2T3')
                    or IsRivalsModToggleEnabled('P4S2T4')
                    or IsRivalsModToggleEnabled('P4S2T5')
                    or IsRivalsModToggleEnabled('P4S2T6')
                    or IsRivalsModToggleEnabled('P4S2T8')
                    or IsRivalsModToggleEnabled('P4S2T9')
                    or IsRivalsModToggleEnabled('P4S2T10')
                ) then
                    state.PendingEnsureHooks = false
                    return false
                end

                if not IsReplicatedStateReady() then
                    state.PendingEnsureHooks = true
                    return false
                end

                state.PendingEnsureHooks = false
                -- Support notice only -- EnsureKiciaInputHook already declines cleanly
                -- when the debug surface is missing (Solara/Xeno tier).
                if IsRivalsModToggleEnabled('P4S1T3')
                    or IsRivalsModToggleEnabled('P4S1T6')
                    or IsRivalsModToggleEnabled('P4S1T7') then
                    __kicia_hook_genv.KiciaHookCaps.gate('No Spread / Grenade Fuse', 'debug.getupvalues', 'debug.setupvalue')
                end
                if RivalsModsState.EnsureKiciaInputHook() then
                    RivalsModsState.SyncNoSpreadEnabled()
                    RivalsModsState.SyncGrenadeFuse()
                end
                RivalsModsState.EnsureGunHooks()
                RivalsModsState.EnsureMeleeHooks()
                RivalsModsState.EnsureGunbladeHooks()
                return true
            end

            function RivalsModsState.RestoreHooks()
                local state = RivalsModsState
                RivalsModsState.RestoreClientModifiers()
                RivalsModsState.RestoreKiciaInputHook()
                local gunModule = state.GunModule
                if gunModule then
                    if state.OriginalGunStartShooting then
                        gunModule.StartShooting = state.OriginalGunStartShooting
                    end
                    if state.OriginalGunStartReloading then
                        gunModule.StartReloading = state.OriginalGunStartReloading
                    end
                    if state.OriginalGunRecoil then
                        gunModule._Recoil = state.OriginalGunRecoil
                    end
                    if state.OriginalGunGetAimSpeed then
                        gunModule.GetAimSpeed = state.OriginalGunGetAimSpeed
                    end
                    if state.OriginalGunEquip then
                        gunModule.Equip = state.OriginalGunEquip
                    end
                end

                local meleeModule = state.MeleeModule
                if meleeModule then
                    if state.OriginalMeleeStartShooting then
                        meleeModule.StartShooting = state.OriginalMeleeStartShooting
                    end
                end

                local gunbladeModule = state.GunbladeModule
                if gunbladeModule then
                    if state.OriginalGunbladeStartShooting then
                        gunbladeM