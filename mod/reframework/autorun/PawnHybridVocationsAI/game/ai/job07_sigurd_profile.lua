local job07_sigurd_profile = {}

local DEFAULT_ENGAGE_PACK_PATH = "AppSystem/AI/ActionInterface/ActInterPackData/Common/MoveToPosition_Walk_Target.user"
local DEFAULT_RUN_BLADE4_PACK_PATH = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_Run_Blade4.user"
local DEFAULT_SPIRAL_SLASH_PACK_PATH = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SpiralSlash.user"
local DEFAULT_SKY_DIVE_PACK_PATH = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SkyDive.user"
local DEFAULT_IDLE_RELEASE_PACK_PATH = "AppSystem/AI/ActionInterface/ActInterPackData/Common/Idle.user"

local DEFAULT_PHASES = {
    {
        key = "engage_far",
        mode = "engage",
        pack_path = DEFAULT_ENGAGE_PACK_PATH,
        min_distance = 7.50,
        max_distance = nil,
    },
    {
        key = "attack_far",
        mode = "attack",
        pack_path = DEFAULT_SKY_DIVE_PACK_PATH,
        min_distance = 5.25,
        max_distance = 7.50,
    },
    {
        key = "engage_mid",
        mode = "engage",
        pack_path = DEFAULT_RUN_BLADE4_PACK_PATH,
        min_distance = 3.00,
        max_distance = 5.25,
    },
    {
        key = "attack_mid",
        mode = "attack",
        pack_path = DEFAULT_SPIRAL_SLASH_PACK_PATH,
        min_distance = 1.75,
        max_distance = 3.00,
    },
    {
        key = "attack_near",
        mode = "attack",
        pack_path = DEFAULT_SPIRAL_SLASH_PACK_PATH,
        min_distance = 0.00,
        max_distance = 1.75,
    },
    {
        key = "release",
        mode = "release",
        pack_path = DEFAULT_ENGAGE_PACK_PATH,
        idle_pack_path = DEFAULT_IDLE_RELEASE_PACK_PATH,
    },
}

function job07_sigurd_profile.key()
    return "job07_sigurd_phased"
end

function job07_sigurd_profile.default_attack_pack_path()
    return DEFAULT_SPIRAL_SLASH_PACK_PATH
end

function job07_sigurd_profile.default_engage_pack_path()
    return DEFAULT_ENGAGE_PACK_PATH
end

function job07_sigurd_profile.default_idle_release_pack_path()
    return DEFAULT_IDLE_RELEASE_PACK_PATH
end

function job07_sigurd_profile.phase_entries(adapter)
    local configured = adapter and adapter.profile_phases or nil
    if type(configured) == "table" and #configured > 0 then
        return configured
    end

    return DEFAULT_PHASES
end

function job07_sigurd_profile.release_phase(adapter, reason)
    local configured = adapter and adapter.release_phase or nil
    if type(configured) == "table" then
        configured.key = tostring(configured.key or "release")
        configured.mode = "release"
        configured.release_reason = tostring(reason or "released")
        return configured
    end

    local release_phase = DEFAULT_PHASES[#DEFAULT_PHASES]
    return {
        key = tostring(release_phase.key),
        mode = "release",
        pack_path = tostring(release_phase.pack_path),
        idle_pack_path = tostring(release_phase.idle_pack_path),
        release_reason = tostring(reason or "released"),
    }
end

return job07_sigurd_profile
