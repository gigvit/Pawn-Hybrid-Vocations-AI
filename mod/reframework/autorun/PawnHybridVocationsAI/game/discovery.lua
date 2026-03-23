local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")

local discovery = {}

local manager_names = {
    CharacterManager = {"managed", "app.CharacterManager"},
    PawnManager = {"managed", "app.PawnManager"},
    BattleManager = {"managed", "app.BattleManager"},
    BattleRelationshipHolder = {"managed", "app.BattleRelationshipHolder"},
    GuiManager = {"managed", "app.GuiManager"},
    ItemManager = {"managed", "app.ItemManager"},
    NPCManager = {"managed", "app.NPCManager"},
    CharacterListHolder = {"managed", "app.CharacterListHolder"},
    GenerateManager = {"managed", "app.GenerateManager"},
    ShellManager = {"managed", "app.ShellManager"},
    SceneManager = {"native", "via.SceneManager"},
    PhysicsSystem = {"native", "via.physics.System"},
}

local type_names = {
    "app.CharacterManager",
    "app.PawnManager",
    "app.Character",
    "app.Human",
    "app.ActionManager",
    "app.GenerateManager",
    "app.NPCManager",
    "app.CharacterListHolder",
    "app.ShellManager",
    "app.ActInterPackData",
    "app.HitController",
    "app.StaminaManager",
    "via.motion.Motion",
    "via.SceneManager",
    "via.physics.System",
}

local function refresh_managers()
    for label, info in pairs(manager_names) do
        state.discovery.managers[label] = util.safe_singleton(info[1], info[2])
    end
end

local function refresh_type_defs()
    for _, type_name in ipairs(type_names) do
        state.discovery.type_defs[type_name] = util.safe_sdk_typedef(type_name)
    end
end

function discovery.refresh(force)
    local now = os.clock()
    if not force and now - state.last_discovery_refresh < config.discovery.refresh_interval_seconds then
        return state.discovery
    end

    state.last_discovery_refresh = now
    refresh_managers()
    refresh_type_defs()

    return state.discovery
end

function discovery.get_manager(label)
    return state.discovery.managers[label]
end

return discovery
