local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local module_system = require("PawnHybridVocationsAI/core/module_system")
local discovery = require("PawnHybridVocationsAI/game/discovery")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local module_specs = require("PawnHybridVocationsAI/app/module_specs")
local runtime_driver = require("PawnHybridVocationsAI/app/runtime_driver")
local builtin_sections = require("PawnHybridVocationsAI/ui/builtin_sections")
local debug_window = require("PawnHybridVocationsAI/ui/debug_window")
local section_registry = require("PawnHybridVocationsAI/ui/section_registry")
local adapter_registry = require("PawnHybridVocationsAI/game/ai/adapter_registry")
local builtin_adapters = require("PawnHybridVocationsAI/game/ai/builtin_adapters")

local bootstrap = {}
local install_specs = module_specs.get_install_specs()
local update_specs = module_specs.get_update_specs()
local log_specs = module_specs.get_log_specs()

local function install_modules(runtime)
    for _, spec in ipairs(install_specs) do
        module_system.install(runtime, spec)
    end
end

local function install_extension_points()
    builtin_sections.install(section_registry)
    builtin_adapters.install(adapter_registry)
end

local function on_late_update()
    local data = main_pawn_properties.update()
    runtime_driver.run(
        state.runtime,
        data,
        update_specs,
        log_specs,
        state.discovery
    )
end

local function on_draw_ui()
    debug_window.draw_menu()
    debug_window.draw()
end

local function on_script_reset()
    log.info("Script reset")
    log.session_shutdown(state.runtime, "script_reset", {
        version = config.version,
    })
    log.session_marker(state.runtime, "system", "script_reset", {
        version = config.version,
    }, "script_reset")
end

if state.initialized then
    return bootstrap
end

state.initialized = true

install_extension_points()
discovery.refresh(true)
log.info("Bootstrapping " .. config.mod_name .. " " .. config.version)
log.bootstrap_probe()
log.session_bootstrap(state.runtime)
install_modules(state.runtime)

re.on_application_entry("LateUpdateBehavior", on_late_update)
re.on_draw_ui(on_draw_ui)
re.on_script_reset(on_script_reset)

return bootstrap
