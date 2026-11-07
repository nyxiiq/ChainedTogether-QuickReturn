-- QuickReturnHighestPoint v0.1.5 candidate, UE4SS v3.0.1 / game BuildID 26273336 (direct-chain revalidated).
-- Calls the native GS_Game.RescueEvent; never calculates/writes a transform.
-- This candidate still needs the documented in-game acceptance tests.
local VERSION = "0.1.5"
local GS_CLASS = "/Game/Blueprint/Gameplay/GS_Game.GS_Game_C"
local PC_CLASS = "/Game/Blueprint/Gameplay/PC_Game.PC_Game_C"
local RESCUE_CLASS = "/Game/Blueprint/BP_RescuePoint.BP_RescuePoint_C"
local LIBRARY = "/Game/Blueprint/Functions/BFL_CustomFunctions.Default__BFL_CustomFunctions_C"
local TEXT_CLASSES = {"EditableText", "EditableTextBox", "MultiLineEditableText", "MultiLineEditableTextBox"}
local pending, serial, generation, loading, disabled = nil, 0, 0, false, false
local cooldown_world, next_allowed, metadata_logged = nil, 0, false

local function log(message) print("[QuickReturnHighestPoint] " .. message .. "\n") end
local function reject(reason) log("SKIP " .. reason) end
local function valid(object) return object ~= nil and object:IsValid() end
local function boolean(value, label)
    if type(value) ~= "boolean" then error("Unverified boolean result: " .. label) end
    return value
end
local function count(value, label)
    if type(value) ~= "number" or value < 0 or value > 1024 or value ~= math.floor(value) then
        error("Unverified player count: " .. label)
    end
    return value
end
local function object(path)
    local result = StaticFindObject(path)
    if not valid(result) then error("Required loaded object missing: " .. path) end
    return result
end
local function native_null()
    -- v3.0.1's ObjectProperty setter does NOT consume Lua nil. A nil at input
    -- four shifts the following bool/object arguments. A nullptr UObject wrapper
    -- takes the consumed-userdata branch and preserves native EX_NoObject values.
    -- StaticFindObject is a read-only lookup, not object creation or asset loading.
    local result = StaticFindObject("/Script/Engine.__QuickReturnHighestPoint_Null_Sentinel")
    if type(result) ~= "userdata" or result:IsValid() or result:GetAddress() ~= 0 then
        error("Could not obtain a verified nullptr UObject wrapper")
    end
    return result
end
local function describe_failure(problem)
    local message = "error_type=" .. type(problem) .. " value=" .. tostring(problem)
    if debug and type(debug.traceback) == "function" then return debug.traceback(message, 2) end
    return message
end
local function function_metadata(path, flags)
    local result = object(path)
    if result:GetFullName() ~= "Function " .. path then error("Unexpected function identity: " .. path) end
    if flags and result:GetFunctionFlags() ~= flags then error("Function flags differ from evidence: " .. path) end
    return result
end
local function same_world(a, b)
    local first, second = a:GetWorld(), b:GetWorld()
    return valid(first) and valid(second) and first:GetAddress() == second:GetAddress()
end
local function text_focused()
    for _, class_name in ipairs(TEXT_CLASSES) do
        -- Four text-entry classes only; no global UObject/function iteration.
        object("/Script/UMG." .. class_name)
        for _, widget in ipairs(FindAllOf(class_name) or {}) do
            if valid(widget) then
                if boolean(widget:HasAnyUserFocus(), "HasAnyUserFocus")
                    or boolean(widget:HasFocusedDescendants(), "HasFocusedDescendants") then return true end
            end
        end
    end
    return false
end
local function perform()
    -- Resolve fresh objects on the game thread on each press; retain no actors across maps.
    local candidates = {}
    local controllers = FindAllOf("PC_Game_C") or {}
    for _, controller in ipairs(controllers) do
        if valid(controller) and not controller:HasAnyFlags(0x10) and controller:IsA(PC_CLASS)
            and boolean(controller:IsLocalController(), "IsLocalController") then
            candidates[#candidates + 1] = controller
        end
    end
    if #candidates ~= 1 then return reject("expected one local PC_Game") end
    local pc = candidates[1]
    -- RegisterKeyBind already delivered a key event. PlayerController's later
    -- held-state sample can be false for both a short press and a held press.
    -- Do not require that second input system to re-prove the received event.
    -- All menu/text/world/authority/native restrictions below remain in force.
    local statics = object("/Script/Engine.Default__GameplayStatics")
    local system = object("/Script/Engine.Default__KismetSystemLibrary")
    local gs = statics:GetGameState(pc)
    if not valid(gs) or not gs:IsA(GS_CLASS) or not same_world(pc, gs) then return reject("game world unavailable") end
    -- The user's one-player room returned IsStandalone=false. Networking mode
    -- alone does not identify another human player. Check the actual local host
    -- and current player/controller counts instead, using documented UE 5.3 APIs.
    function_metadata("/Script/Engine.GameplayStatics:GetNumPlayerControllers")
    function_metadata("/Script/Engine.GameplayStatics:GetNumLocalPlayerControllers")
    function_metadata("/Script/Engine.KismetSystemLibrary:IsDedicatedServer")
    local standalone = boolean(system:IsStandalone(pc), "IsStandalone")
    local server = boolean(system:IsServer(pc), "IsServer")
    local dedicated = boolean(system:IsDedicatedServer(pc), "IsDedicatedServer")
    local authority = boolean(gs:HasAuthority(), "HasAuthority")
    local players = count(gs.PlayerArray:GetArrayNum(), "PlayerArray")
    local total_controllers = count(statics:GetNumPlayerControllers(pc), "GetNumPlayerControllers")
    local local_controllers = count(statics:GetNumLocalPlayerControllers(pc), "GetNumLocalPlayerControllers")
    log(string.format("SESSION standalone=%s server=%s dedicated=%s authority=%s players=%d controllers=%d local=%d",
        tostring(standalone), tostring(server), tostring(dedicated), tostring(authority), players, total_controllers, local_controllers))
    if not server or dedicated or not authority then return reject("local authoritative host only") end
    if players ~= 1 or total_controllers ~= 1 or local_controllers ~= 1 then return reject("single local player only") end
    for _, controller in ipairs(controllers) do
        if valid(controller) and not controller:HasAnyFlags(0x10) and same_world(pc, controller)
            and controller:GetAddress() ~= pc:GetAddress() then return reject("another controller in current world") end
    end
    if not boolean(gs.GameBegun, "GameBegun") then return reject("native GameBegun gate") end
    -- W_SettingsMain.UpdateLoadCheckpointVisibility permits this button only for enum value 1.
    if gs["Selected Game Mode"] ~= 1 then return reject("native highest-point mode restriction") end
    if boolean(statics:IsGamePaused(pc), "IsGamePaused") then return reject("paused") end
    if boolean(pc.bShowMouseCursor, "bShowMouseCursor")
        or boolean(pc:IsMoveInputIgnored(), "IsMoveInputIgnored")
        or boolean(pc:IsLookInputIgnored(), "IsLookInputIgnored") then return reject("menu or input blocked") end
    if text_focused() then return reject("text input focused") end
    local pawn = pc:K2_GetPawn()
    if not valid(pawn) or not same_world(pc, pawn) then return reject("controlled pawn unavailable") end
    local now = statics:GetRealTimeSeconds(pc)
    if type(now) ~= "number" or now ~= now or now < 0 or now == math.huge then error("Invalid world clock") end
    if now < 5 then return reject("map startup grace period") end
    local world = gs:GetWorld():GetFullName()
    if cooldown_world == world and now < next_allowed then return reject("cooldown") end
    function_metadata(GS_CLASS .. ":GetHighestRescuePoint", 0x0C420000)
    function_metadata(GS_CLASS .. ":RescueEvent", 0x0C000000)
    if not metadata_logged then
        log("METADATA_OK GetHighestRescuePoint(out BP_RescuePoint, out bool); RescueEvent(point,false,false,nullptr,false,nullptr)")
        metadata_logged = true
    end
    local null_object = native_null()
    -- Reuse exactly the native button's car check (WorldContext, out car; bool return).
    local library = object(LIBRARY)
    local car_out = {}
    if boolean(library["Is Someone Driving Car(Server)"](library, pc, car_out), "native car check") then
        return reject("native car restriction")
    end
    -- UE4SS v3.0.1 does not advance the Lua stack for a non-struct out argument.
    -- Both outputs intentionally share ONE container, avoiding differing-table ambiguity.
    -- Runtime FName spelling is 'Return'; the cooked package spells it 'return'.
    local result = {}
    gs:GetHighestRescuePoint(result, result)
    if not boolean(result.Found, "GetHighestRescuePoint.Found") then return reject("no native highest rescue point") end
    local point = result.Return or result["return"]
    if not valid(point) or not point:IsA(RESCUE_CLASS) or not same_world(gs, point) then
        return reject("native rescue point invalid or from another world")
    end
    cooldown_world, next_allowed = world, now + 3
    log("REQUEST native RescueEvent context=" .. gs:GetFullName() .. " point=" .. point:GetFullName())
    -- Exact positional contract and literals from the native highest button's Kismet.
    -- The native event retains authority/GameBegun checks, effect, delay, spawning and possession.
    gs:RescueEvent(point, false, false, null_object, false, null_object)
    log("REQUEST_SUBMITTED; native completion must be checked in game")
end
local function key_pressed()
    log("INPUT_CALLBACK F6; event received, gameplay gates pending")
    if disabled then return reject("disabled after API error; restart required") end
    if loading then return reject("map loading") end
    if pending then return reject("request already queued") end
    serial = serial + 1
    local ticket, epoch = serial, generation
    pending = ticket
    local queued, problem = pcall(function()
        ExecuteInGameThread(function()
            if pending ~= ticket or generation ~= epoch or loading then
                if pending == ticket then pending = nil end
                return reject("cancelled by map transition")
            end
            local ok, failure = xpcall(perform, describe_failure)
            if pending == ticket then pending = nil end
            if not ok then disabled = true; log("ERROR disabled: " .. tostring(failure)) end
        end)
    end)
    if not queued then
        if pending == ticket then pending = nil end
        disabled = true
        log("ERROR queue failed; disabled: " .. tostring(problem))
    end
end

local ok, problem = pcall(function()
    if not UE4SS or type(UE4SS.GetVersion) ~= "function" then error("Missing framework version API") end
    local major, minor, patch = UE4SS.GetVersion()
    if major ~= 3 or minor ~= 0 or patch ~= 1 then error("This candidate requires verified UE4SS v3.0.1 input semantics") end
    for _, api in ipairs({"StaticFindObject", "FindAllOf", "ExecuteInGameThread", "RegisterKeyBind",
        "IsKeyBindRegistered", "RegisterInitGameStatePreHook", "RegisterLoadMapPostHook"}) do
        if type(_G[api]) ~= "function" then error("Missing API: " .. api) end
    end
    -- v3.0.1 installs FName as callable userdata, not as a Lua function.
    if type(FName) ~= "userdata" and type(FName) ~= "function" then error("Missing FName constructor") end
    if not Key or not Key.F6 then error("Missing Key.F6") end
    if IsKeyBindRegistered(Key.F6, {}) then error("F6 already registered; preserving existing binding") end
    -- v3.0.1's LoadMapPre C++ bridge has an argument-count mismatch; never register it.
    -- Reset before native GameState initialization. LoadMapPost also invalidates
    -- queued work, including travel that does not initialize a local GameMode.
    RegisterInitGameStatePreHook(function()
        generation = generation + 1
        loading, pending, cooldown_world, next_allowed = true, nil, nil, 0
        log("MAP_STATE_RESET; waiting for LoadMapPost")
    end)
    RegisterLoadMapPostHook(function(_, _, _, _, map_error)
        generation = generation + 1
        pending = nil
        if type(map_error) ~= "string" or map_error ~= "" then
            loading = true
            log("MAP_NOT_READY; post-load error or unexpected callback argument")
            return
        end
        loading = false
        log("MAP_READY; queued input invalidated")
    end)
    -- The pinned framework dispatches a key-down edge once, and rearms on release
    -- (Input/src/Handler.cpp). Cooldown and queue coalescing add separate protection.
    RegisterKeyBind(Key.F6, key_pressed)
    log("REGISTERED F6 v" .. VERSION .. "; single local host candidate; in-game validation pending")
end)
if not ok then disabled = true; log("STOP " .. tostring(problem)) end

