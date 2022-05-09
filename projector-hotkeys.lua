-- Add hotkeys to open fullscreen projectors
-- David Magnus <davidkmagnus@gmail.com>
-- https://github.com/DavidKMagnus

PROJECTOR_TYPE_SCENE = "Scene"
PROJECTOR_TYPE_SOURCE = "Source"
PROJECTOR_TYPE_PROGRAM = "StudioProgram"
PROJECTOR_TYPE_MULTIVIEW = "Multiview"

DEFAULT_MONITOR = 1

PROGRAM = "Program Output"
MULTIVIEW = "Multiview Output"
GROUP = "gp"
STARTUP = "su"
DOUBLE = "db"

monitors = {}
startup_projectors = {}
double_startup = {}
hotkey_ids = {}

function script_description()
    local description = [[
        <center><h2>Fullscreen Projector Hotkeys</h2></center>
        <p>Hotkeys will be added for the Program output, Multiview, and each currently existing scene.
        Choose the monitor to which each output will be projected when the hotkey is pressed.</p>
        <p>You can also choose to open a projector to a specific monitor on startup. If you use
        this option, you may need to disable the "Save projectors on exit" preference or there
        will be duplicate projectors.</p>
        <p>Some OBS users report that projectors opened on startup can be blank grey screens.
        Using the option "Open Again on Startup" will open a duplicate projector that seems
        to have the expected content. This option may solve grey screen problem, but will leave
        the original empty projector open behind the working projector.</p>
        <p><b>If new scenes are added, or if scene names change, this script will need to be
        reloaded.</b></p>]]

    return description
end

function script_properties()
    local p = obslua.obs_properties_create()

    -- set up the controls for the Program Output
    local gp = obslua.obs_properties_create()
    obslua.obs_properties_add_group(p, PROGRAM .. GROUP, "Program Output", obslua.OBS_GROUP_NORMAL, gp)
    obslua.obs_properties_add_int(gp, PROGRAM, "Project to monitor:", 1, 10, 1)
    obslua.obs_properties_add_bool(gp, PROGRAM .. STARTUP, "Open on Startup")
    obslua.obs_properties_add_bool(gp, PROGRAM .. DOUBLE, "Open Again on Startup")

    -- set up the controls for the Multiview
    local gp = obslua.obs_properties_create()
    obslua.obs_properties_add_group(p, MULTIVIEW .. GROUP, "Multiview", obslua.OBS_GROUP_NORMAL, gp)
    obslua.obs_properties_add_int(gp, MULTIVIEW, "Project to monitor:", 1, 10, 1)
    obslua.obs_properties_add_bool(gp, MULTIVIEW .. STARTUP, "Open on Startup")
    obslua.obs_properties_add_bool(gp, MULTIVIEW .. DOUBLE, "Open Again on Startup")

    -- loop through each scene and create a property group and control for choosing the monitor and startup settings
    local scenes = obslua.obs_frontend_get_scene_names()
    if scenes ~= nil then
        for _, scene in ipairs(scenes) do
            local gp = obslua.obs_properties_create()
            obslua.obs_properties_add_group(p, scene .. GROUP, scene, obslua.OBS_GROUP_NORMAL, gp)
            obslua.obs_properties_add_int(gp, scene, "Project to monitor:", 1, 10, 1)
            obslua.obs_properties_add_bool(gp, scene .. STARTUP, "Open on Startup")
            obslua.obs_properties_add_bool(gp, scene .. DOUBLE, "Open Again on Startup")
        end
        obslua.bfree(scene)
    end

	return p
end

function script_update(settings)
    update_monitor_preferences(settings)
end

function script_load(settings)   
    local scenes = obslua.obs_frontend_get_scene_names()
    if scenes == nil or #scenes == 0 then
        -- on obs startup, scripts are loaded before scenes are finished loading
        -- register a callback to register the hotkeys and open startup projectors after scenes are available
        obslua.obs_frontend_add_event_callback(
            function(e)
                if e == obslua.OBS_FRONTEND_EVENT_FINISHED_LOADING then
                    update_monitor_preferences(settings)
                    register_hotkeys(settings)
                    open_startup_projectors()
                    obslua.remove_current_callback()
                end
            end
        )
    else
        -- this runs when the script is loaded or reloaded from the settings window
        update_monitor_preferences(settings)
        register_hotkeys(settings)
    end    
end

function script_save(settings)
    for output, hotkey_id in pairs(hotkey_ids) do
        local hotkey_save_array = obslua.obs_hotkey_save(hotkey_id)
        obslua.obs_data_set_array(settings, output_to_function_name(output), hotkey_save_array)
        obslua.obs_data_array_release(hotkey_save_array)
    end
end

-- find the monitor preferences for each projector and store them
function update_monitor_preferences(settings)
    local outputs = obslua.obs_frontend_get_scene_names()
    table.insert(outputs, MULTIVIEW)
    table.insert(outputs, PROGRAM)

    for _, output in ipairs(outputs) do
        local monitor = obslua.obs_data_get_int(settings, output)
        if monitor == nil or monitor == 0 then
            monitor = DEFAULT_MONITOR
        end

        -- monitors are 0 indexed here, but 1-indexed in the OBS menus
        monitors[output] = monitor-1

        -- set which projectors should open on start up
        startup_projectors[output] = obslua.obs_data_get_bool(settings, output .. STARTUP)

        -- set which projectors should open duplicates on start up
        double_startup[output] = obslua.obs_data_get_bool(settings, output .. DOUBLE)
    end
    obslua.bfree(output)
end

-- register a hotkey to open a projector for each output
function register_hotkeys(settings)
    local outputs = obslua.obs_frontend_get_scene_names()
    table.insert(outputs, MULTIVIEW)
    table.insert(outputs, PROGRAM)

    for _, output in ipairs(outputs) do
        hotkey_ids[output] = obslua.obs_hotkey_register_frontend(
            output_to_function_name(output),
            "Open Fullscreen Projector for '" .. output .. "'",
            function(pressed)
                if not pressed then
                    return
                end
                open_fullscreen_projector(output)
            end
        )

        local hotkey_save_array = obslua.obs_data_get_array(settings, output_to_function_name(output))
        obslua.obs_hotkey_load(hotkey_ids[output], hotkey_save_array)
        obslua.obs_data_array_release(hotkey_save_array)
    end
    obslua.bfree(output)
end

-- open a full screen projector
function open_fullscreen_projector(output)
     -- set the default monitor if one was never set
    if monitors[output] == nil then
        monitors[output] = DEFAULT_MONITOR
    end

    -- set the projector type if this is not a normal scene
    local projector_type = PROJECTOR_TYPE_SCENE
    if output == PROGRAM then
        projector_type = PROJECTOR_TYPE_PROGRAM
    elseif output == MULTIVIEW then
        projector_type = PROJECTOR_TYPE_MULTIVIEW
    end

    -- call the front end API to open the projector
    obslua.obs_frontend_open_projector(projector_type, monitors[output], "", output)
end

-- open startup projectors
function open_startup_projectors()
    for output, open_on_startup in pairs(startup_projectors) do
        if open_on_startup then
            open_fullscreen_projector(output)
        end
    end
    -- check again for any that should be opened twice
    for output, open_twice in pairs(double_startup) do
        if open_twice then
            open_fullscreen_projector(output)
        end
    end
end

-- remove special characters from scene names to make them usable as function names
function output_to_function_name(name)
    return "ofsp_" .. name:gsub('[%p%c%s]', '_')
end
