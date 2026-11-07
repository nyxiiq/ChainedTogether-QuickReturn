-- QuickReturnTrace v0.2: four directly evidenced Blueprint functions, observation only.
-- No game function invocation, parameter writes, hotkeys or global event hook.
local TARGETS = {
    {
        label = "HighestButton",
        path = "/V_Settings/Widgets/W_SettingsMain.W_SettingsMain_C:BndEvt__W_SettingsMain_HighestUnlockedPoint_Button_K2Node_ComponentBoundEvent_30_OnClicked__DelegateSignature",
        flags = 0x08000000,
    },
    {
        label = "HighestQuery",
        path = "/Game/Blueprint/Gameplay/GS_Game.GS_Game_C:GetHighestRescuePoint",
        flags = 0x0C420000,
    },
    {
        label = "NativeRescueRequest",
        path = "/Game/Blueprint/Gameplay/GS_Game.GS_Game_C:RescueEvent",
        flags = 0x0C000000,
    },
    {
        label = "NativeRescueBody",
        path = "/Game/Blueprint/Gameplay/GS_Game.GS_Game_C:Rescue",
        flags = 0x0C820000,
    },
}
local installed, attempts, pending, stopped, sequence = {}, 0, false, false, 0
local function log(text)
    print("[QuickReturnTrace] " .. text .. "\n")
end
local function callback(target)
    local hits = 0
    return function(context, ...)
        -- These Blueprint hooks are post callbacks. No return override.
        if hits >= 16 then return end
        hits = hits + 1
        sequence = sequence + 1
        local name = "<context unavailable>"
        local ok, result = pcall(function()
            local object = context:get()
            if object and object:IsValid() then return object:GetFullName() end
        end)
        if ok and result then name = result end
        log(string.format("HIT seq=%d target=%s hit=%d context=%s wrapper_args=%d phase=POST",
            sequence, target.label, hits, name, select("#", ...)))
        if target.label == "NativeRescueRequest" then
            -- Six statically verified inputs only. Opaque/invalid wrappers are logged,
            -- never used to invoke a function or alter a parameter.
            local values = {}
            for index = 1, math.min(select("#", ...), 6) do
                local wrapper = select(index, ...)
                local read, value = pcall(function()
                    local v = wrapper:get()
                    if v == nil then return "nil" end
                    if type(v) == "boolean" then return tostring(v) end
                    if v:IsValid() then return v:GetFullName() end
                    return "null-object"
                end)
                values[index] = read and value or "<unreadable>"
            end
            log("REQUEST_ARGS " .. table.concat(values, " | "))
        end
        if hits == 16 then log("LOG_LIMIT target=" .. target.label .. "; further hits suppressed") end
        -- Do not read/write opaque arguments or return a replacement value.
    end
end
local function install_loaded_targets()
    for _, target in ipairs(TARGETS) do
        if not installed[target.path] then
            local func = StaticFindObject(target.path)
            if func and func:IsValid() then
                local full = func:GetFullName()
                if full ~= "Function " .. target.path then error("Unexpected function identity: " .. full) end
                -- Direct metadata call, no ForEachFunction/ForEachProperty.
                local flags = func:GetFunctionFlags()
                log(string.format("CANDIDATE %s flags=0x%X params=NOT_ENUMERATED", full, flags))
                if flags ~= target.flags then error("Function flags changed: " .. target.label) end
                local pre_id, post_id = RegisterHook(target.path, callback(target))
                if type(pre_id) ~= "number" or type(post_id) ~= "number" then
                    error("Hook registration did not return numeric IDs: " .. target.label)
                end
                installed[target.path] = { pre = pre_id, post = post_id }
                log(string.format("HOOK_READY target=%s pre=%d post=%d", target.label, pre_id, post_id))
            end
        end
    end
    for _, target in ipairs(TARGETS) do
        if not installed[target.path] then return false end
    end
    return true
end
local function rollback_hooks()
    for path, ids in pairs(installed) do
        local ok, problem = pcall(function() UnregisterHook(path, ids.pre, ids.post) end)
        if not ok then log("UNREGISTER_ERROR " .. tostring(problem)) end
    end
end
log("START v0.2; four exact candidates; logging only; no teleport calls")
if type(RegisterHook) ~= "function" or type(UnregisterHook) ~= "function"
    or type(StaticFindObject) ~= "function" or type(LoopAsync) ~= "function"
    or type(ExecuteInGameThread) ~= "function" then
    log("STOP unsupported UE4SS API")
else
    LoopAsync(5000, function()
        if stopped then return true end
        attempts = attempts + 1
        if not pending then
            pending = true
            local last = attempts >= 24
            local queued, problem = pcall(function()
                ExecuteInGameThread(function()
                    if stopped then pending = false; return end
                    local ok, ready = pcall(install_loaded_targets)
                    pending = false
                    if not ok then
                        stopped = true
                        log("STOP API_ERROR " .. tostring(ready))
                        rollback_hooks()
                    elseif ready then
                        stopped = true
                        log("READY four candidates installed; waiting for manual action; callbacks stay until game exit")
                    elseif last or attempts >= 24 then
                        stopped = true
                        log("STOP candidate load timeout; do not click for tracing")
                        rollback_hooks()
                    end
                end)
            end)
            if not queued then
                stopped = true
                log("STOP QUEUE_ERROR " .. tostring(problem))
                -- Do not access UObjects on this worker thread.
            end
        end
        if attempts >= 24 then
            if pending then log("TIMER_STOP no more installation tasks will be queued") end
            return true
        end
        return stopped
    end)
end
