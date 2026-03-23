local log = require("PawnHybridVocationsAI/core/log")

local module_system = {}

local function get_registry(runtime)
    -- Registry state lives in runtime so install/update status survives across module calls.
    runtime.module_registry = runtime.module_registry or {
        entries = {},
        install_order = {},
    }
    return runtime.module_registry
end

local function get_entry(runtime, key)
    local registry = get_registry(runtime)
    registry.entries[key] = registry.entries[key] or {
        key = key,
        installed = false,
        install_attempted = false,
        install_count = 0,
        update_count = 0,
        last_error = nil,
        dependencies = {},
    }
    return registry.entries[key]
end

local function dependencies_ready(runtime, dependencies)
    for _, dependency in ipairs(dependencies or {}) do
        local entry = get_entry(runtime, dependency)
        if not entry.installed then
            return false, dependency
        end
    end

    return true, nil
end

function module_system.install(runtime, spec)
    local key = tostring(spec.key or spec.name or "unknown_module")
    local entry = get_entry(runtime, key)
    if entry.installed then
        return true
    end

    local dependencies = spec.dependencies or {}
    entry.dependencies = dependencies
    entry.install_attempted = true

    local ready, missing = dependencies_ready(runtime, dependencies)
    if not ready then
        entry.last_error = "dependency_not_ready:" .. tostring(missing)
        log.warn(string.format("Module install deferred: %s (missing %s)", key, tostring(missing)))
        return false
    end

    local install_fn = spec.install
    if type(install_fn) ~= "function" then
        entry.installed = true
        entry.install_count = entry.install_count + 1
        table.insert(get_registry(runtime).install_order, key)
        log.debug(string.format("Module registered without install hook: %s", key))
        return true
    end

    local ok, err = pcall(install_fn, runtime)
    if not ok then
        entry.last_error = tostring(err)
        log.error(string.format("Module install failed: %s (%s)", key, tostring(err)))
        log.session_marker(runtime, "system", "module_install_failed", {
            module = key,
            error = tostring(err),
        }, string.format("module=%s install_failed", key))
        return false
    end

    entry.installed = true
    entry.last_error = nil
    entry.install_count = entry.install_count + 1
    table.insert(get_registry(runtime).install_order, key)
    log.info(string.format("Module installed: %s", key))
    log.session_marker(runtime, "system", "module_installed", {
        module = key,
        dependencies = dependencies,
    }, string.format("module=%s installed", key))
    return true
end

function module_system.run_update(runtime, spec)
    local key = tostring(spec.key or spec.name or "unknown_module")
    local entry = get_entry(runtime, key)
    local dependencies = spec.dependencies or {}
    entry.dependencies = dependencies

    local ready, missing = dependencies_ready(runtime, dependencies)
    if not ready then
        entry.last_error = "dependency_not_ready:" .. tostring(missing)
        return nil
    end

    local update_fn = spec.update
    if type(update_fn) ~= "function" then
        return nil
    end

    local ok, result = pcall(update_fn, runtime)
    if not ok then
        entry.last_error = tostring(result)
        log.error(string.format("Module update failed: %s (%s)", key, tostring(result)))
        log.session_marker(runtime, "system", "module_update_failed", {
            module = key,
            error = tostring(result),
        }, string.format("module=%s update_failed", key))
        return nil
    end

    entry.last_error = nil
    entry.update_count = entry.update_count + 1
    return result
end

function module_system.get_status(runtime)
    return get_registry(runtime)
end

return module_system
