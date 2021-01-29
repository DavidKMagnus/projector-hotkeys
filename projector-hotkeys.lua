-- Add hotkeys to open fullscreen projectors
-- David Magnus <davidkmagnus@gmail.com>
-- https://github.com/DavidKMagnus

PROJECTOR_TYPE_SCENE = "Scene"
PROJECTOR_TYPE_SOURCE = "Source"
PROJECTOR_TYPE_PROGRAM = "StudioProgram"
PROJECTOR_TYPE_MULTIVIEW = "Multiview"

DEFAULT_MONITOR = 1

PROGRAM = "Program Output"

monitors = {}
hotkey_ids = {}

function script_description()
    local description = [[
        <center><h2>Fullscreen Projector Hotkeys</h2></center>
        <p>Hotkeys will be added for the Program, Multiview, and each currently existing scene.
        Choose the monitor to which each output will be projected when the hotkey is pressed.</p>]]
    
    return description
end

function script_properties()
	local p = obslua.obs_properties_create()
    
    obslua.obs_properties_add_int(p, PROGRAM, "Project the Program to monitor:", 1, 10, 1)

    -- loop through each scene and create a control for choosing the monitor
    local scenes = obslua.obs_frontend_get_scene_names()
    if scenes ~= nil then
        for _, scene in ipairs(scenes) do
            obslua.obs_properties_add_int(p, scene, "Project '" .. scene .. "' to monitor:", 1, 10, 1)
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
        -- register a callback to register the hotkeys once scenes are available
        obslua.obs_frontend_add_event_callback(
            function(e)
                if e == obslua.OBS_FRONTEND_EVENT_FINISHED_LOADING then
                    update_monitor_preferences(settings)
                    register_hotkeys(settings)
                    obslua.remove_current_callback()
                end
            end
        )
    else
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
    table.insert(outputs, PROGRAM)
    
    for _, output in ipairs(outputs) do
        local monitor = obslua.obs_data_get_int(settings, output)
        if monitor == nil or monitor == 0 then
            monitor = DEFAULT_MONITOR
        end
        
        -- monitors are 0 indexed here, but 1-indexed in the OBS menus
        monitors[output] = monitor-1
    end
    obslua.bfree(output)
end

-- register a hotkey to open a projector for each output
function register_hotkeys(settings)
    local outputs = obslua.obs_frontend_get_scene_names()
    table.insert(outputs, PROGRAM)
    
    for _, output in ipairs(outputs) do
        hotkey_ids[output] = obslua.obs_hotkey_register_frontend(
            output_to_function_name(output),
            "Open Fullscreen Projector for '" .. output .. "'",
            function(pressed)
                if not pressed then
                    return
                end
                
                -- set the default monitor if one was never set
                if monitors[output] == nil then
                    monitors[output] = DEFAULT_MONITOR
                end
                
                -- set the projector type if this is not a normal scene
                local projector_type = PROJECTOR_TYPE_SCENE
                if output == PROGRAM then
                    projector_type = PROJECTOR_TYPE_PROGRAM
                end
                
                -- call the frontend API to open the projector
                obslua.obs_frontend_open_projector(projector_type, monitors[output], "", output)
            end
        )
        
        local hotkey_save_array = obslua.obs_data_get_array(settings, output_to_function_name(output))
        obslua.obs_hotkey_load(hotkey_ids[output], hotkey_save_array)
        obslua.obs_data_array_release(hotkey_save_array)
    end
    obslua.bfree(output)
end

-- remove special characters from scene names to make them useable as function names
function output_to_function_name(name)
    return "ofsp_" .. name:gsub('[%p%c%s]', '_')
end
