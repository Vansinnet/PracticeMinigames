local mod = get_mod("PracticeMinigames")

local PRACTICE_VIEW = "practice_minigames_view"
local SELECTOR_VIEW = "practice_minigames_selector_view"
local PRACTICE_TYPES = { "decode_symbols", "decode_search", "drill", "frequency", "balance" }
local STATS_SETTING = "historical_stats_v1"

local practice_session
local selector_open = false
local selector_state = { selected = 1 }
local selector_previous_input = {}
local selector_next_move_at = 0
local latest_results = {}
local practice_action_held = false
local practice_action_name
local frame_axis_x = 0
local frame_axis_y = 0

local function empty_stats()
    local stats = {}

    for i = 1, #PRACTICE_TYPES do
        stats[PRACTICE_TYPES[i]] = { count = 0, total = 0, best = 0 }
    end

    return stats
end

local function load_stats()
    local stored = mod:get(STATS_SETTING)
    local stats = empty_stats()

    if type(stored) == "table" then
        for i = 1, #PRACTICE_TYPES do
            local minigame_type = PRACTICE_TYPES[i]
            local source = stored[minigame_type]

            if type(source) == "table" and type(source.count) == "number" and type(source.total) == "number" then
                stats[minigame_type].count = math.max(math.floor(source.count), 0)
                stats[minigame_type].total = math.max(source.total, 0)
                stats[minigame_type].best = type(source.best) == "number" and math.max(source.best, 0) or 0
            end
        end
    end

    return stats
end


local historical_stats = load_stats()

local function record_result(minigame_type, elapsed)
    local stat = historical_stats[minigame_type]

    if not stat or elapsed <= 0 then
        return
    end

    stat.count = stat.count + 1
    stat.total = stat.total + elapsed
    stat.best = stat.best == 0 and elapsed or math.min(stat.best, elapsed)
    latest_results[minigame_type] = elapsed
    mod:set(STATS_SETTING, historical_stats)
    mod:echo(mod:localize("practice_result",
        mod:localize("practice_type_" .. minigame_type), elapsed))
end

local function reset_input()
    practice_action_held = false
    practice_action_name = nil
    frame_axis_x = 0
    frame_axis_y = 0
    selector_next_move_at = 0
    table.clear(selector_previous_input)
end

local function register_view(view_name, class_name, path)
    mod:add_require_path(path)
    mod:register_view({
        view_name = view_name,
        view_settings = {
            allow_hud = true,
            class = class_name,
            close_on_hotkey_pressed = false,
            disable_game_world = false,
            init_view_function = function()
                return true
            end,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/scanner_display_view/scanner_display_view",
            path = path,
            state_bound = false,
            use_transition_ui = false,
        },
        view_transitions = {},
        view_options = {
            close_all = false,
            close_previous = false,
        },
    })
    mod:io_dofile(path)
end

local function practice_allowed()
    local game_mode = Managers.state and Managers.state.game_mode
    local name = game_mode and game_mode:game_mode_name()

    return name == "hub" or name == "prologue_hub" or name == "training_grounds" or name == "shooting_range"
end

local function close_view(view_name)
    local ui = Managers.ui

    if ui and (ui:view_active(view_name) or ui:is_view_closing(view_name)) then
        ui:close_view(view_name, true)
    end
end

local function close_practice()
    reset_input()
    close_view(PRACTICE_VIEW)
    practice_session = nil
end

local function close_selector()
    reset_input()
    close_view(SELECTOR_VIEW)
    selector_open = false
end

local function open_selector()
    if not practice_allowed() then
        mod:echo(mod:localize("practice_not_allowed"))
        return
    end

    local ui = Managers.ui

    if not ui then
        return
    end

    selector_state.selected = math.clamp(selector_state.selected or 1, 1, #PRACTICE_TYPES)
    selector_open = true
    reset_input()

    if not ui:view_active(SELECTOR_VIEW) and not ui:is_view_closing(SELECTOR_VIEW) then
        ui:open_view(SELECTOR_VIEW, nil, false, false, nil, {
            state = selector_state,
            stats = historical_stats,
            latest_results = latest_results,
        })
    end
end

local function start_practice(minigame_type)
    local create = mod._practice_create
    local player = Managers.player and Managers.player:local_player_safe(1)
    local ui = Managers.ui

    if not create or not player or not ui then
        return
    end

    local extension, minigame = create(minigame_type)

    if not extension or not minigame then
        return
    end

    minigame:setup_game()
    minigame:start(player)

    local context = {
        minigame_extension = extension,
        minigame_type = minigame_type,
    }
    practice_session = {
        context = context,
        minigame = minigame,
        minigame_type = minigame_type,
    }
    ui:open_view(PRACTICE_VIEW, nil, false, false, nil, context)
end

local function launch_selected()
    local minigame_type = PRACTICE_TYPES[selector_state.selected]

    if minigame_type then
        close_selector()
        start_practice(minigame_type)
    end
end

function mod.toggle_practice()
    if selector_open then
        close_selector()
    elseif practice_session then
        close_practice()
        open_selector()
    else
        open_selector()
    end
end

local function active_value(value)
    return value == true or type(value) == "number" and value > 0
end

local function vector_elements(value)
    if Script.type_name(value) == "Vector3" then
        return Vector3.to_elements(value)
    end
end

local function selector_just_pressed(action, value)
    local active = active_value(value)
    local previous = selector_previous_input[action]
    selector_previous_input[action] = active

    return active and not previous
end

local function move_selection(direction)
    local now = mod._time("main") or 0

    if now < selector_next_move_at then
        return
    end

    selector_next_move_at = now + 0.2
    selector_state.selected = (selector_state.selected - 1 + direction) % #PRACTICE_TYPES + 1
end

local function route_selector(action, result)
    if action == "move_left" or action == "navigate_left_pressed" or action == "navigate_up_pressed" then
        if active_value(result) then
            move_selection(-1)
        end

        return false
    elseif action == "move_right" or action == "navigate_right_pressed" or action == "navigate_down_pressed" then
        if active_value(result) then
            move_selection(1)
        end

        return false
    elseif (action == "move" or action == "move_controller") and result then
        local x, y = vector_elements(result)

        if x and y and math.abs(x) >= math.abs(y) then
            if x < -0.5 then move_selection(-1) elseif x > 0.5 then move_selection(1) end
        elseif y then
            if y > 0.5 then move_selection(-1) elseif y < -0.5 then move_selection(1) end
        end

        return Vector3(0, 0, 0)
    elseif action == "jump" or action == "action_one_pressed" or action == "interact_pressed"
            or action == "confirm_pressed" or action == "left_pressed" then
        if selector_just_pressed(action, result) then
            launch_selected()
        end

        return false
    elseif action == "back" or action == "action_two_pressed" or action == "menu" then
        if selector_just_pressed(action, result) then
            close_selector()
        end

        return false
    end

    return result
end

local function route_practice(action, result)
    local minigame = practice_session and practice_session.minigame

    if not minigame then
        return result
    end

    if minigame:uses_action()
            and (action == "interact_hold" or action == "action_one_hold" or action == "jump_held") then
        if result and not practice_action_held then
            practice_action_held = true
            practice_action_name = action
            minigame:action(true, mod._time("gameplay") or 0)
        elseif not result and practice_action_held and action == practice_action_name then
            practice_action_held = false
            practice_action_name = nil
            minigame:action(false, mod._time("gameplay") or 0)
        end

        return false
    elseif minigame:uses_joystick() and (action == "move" or action == "move_controller") and result then
        local x, y = vector_elements(result)

        if x and y and (x ~= 0 or y ~= 0) then
            frame_axis_x, frame_axis_y = x, y
        end

        return Vector3(0, 0, 0)
    elseif (action == "action_two_pressed" or action == "back" or action == "menu") and result then
        minigame:escape_action(true)
        return false
    end

    if action == "sprint" or action == "crouch" or action == "jump"
            or action == "weapon_reload" or action == "wield_scroll" or action == "wield_switch"
            or action == "action_one_pressed" or action == "action_one_released"
            or action == "weapon_extra" or action == "companion_attack" then
        return false
    elseif action == "move_right" or action == "move_left"
            or action == "move_forward" or action == "move_backward" then
        return 0
    end

    return result
end

local function route_input(action, result, source)
    if not mod:is_enabled() or not selector_open and not practice_session then
        return result
    end

    if source ~= "input_service" then
        if action == "move" or action == "move_controller" then
            return Vector3(0, 0, 0)
        elseif action == "move_right" or action == "move_left"
                or action == "move_forward" or action == "move_backward" then
            return 0
        elseif action == "sprint" or action == "crouch" or action == "jump"
                or action == "weapon_reload" or action == "wield_scroll" or action == "wield_switch"
                or action == "action_one_pressed" or action == "action_one_released"
                or action == "action_two_pressed" or action == "weapon_extra"
                or action == "companion_attack" or action == "interact_hold"
                or action == "action_one_hold" or action == "jump_held" then
            return false
        end

        return result
    end

    return selector_open and route_selector(action, result) or route_practice(action, result)
end

local function input_hook(func, self, action)
    local result = func(self, action)
    local source = self and self.type == "Ingame" and "input_service" or "input_service_other"

    return route_input(action, result, source)
end

mod:hook(CLASS.InputService, "_get", input_hook)

if rawget(CLASS.InputService, "_get_simulate") then
    mod:hook(CLASS.InputService, "_get_simulate", input_hook)
end

mod:hook_require("scripts/extension_systems/input/player_unit_input_extension", function(PlayerUnitInputExtension)
    mod:hook(PlayerUnitInputExtension, "get", function(func, self, action)
        return route_input(action, func(self, action), "player_unit_input")
    end)
end)

function mod.update(dt)
    local ui = Managers.ui

    if selector_open and (not ui or not ui:view_active(SELECTOR_VIEW)) then
        close_selector()
    end

    local session = practice_session

    if not session then
        return
    end

    if not ui or not ui:view_active(PRACTICE_VIEW) then
        close_practice()
        return
    end

    local minigame = session.minigame
    local t = mod._time("gameplay") or 0

    if minigame:is_completed() then
        local elapsed = t - minigame._practice_start
        local minigame_type = session.minigame_type
        record_result(minigame_type, elapsed)
        close_practice()
        open_selector()
        return
    elseif minigame:should_exit() then
        close_practice()
        open_selector()
        return
    end

    if minigame:uses_joystick() then
        -- Hub gameplay does not poll movement while this custom view owns the screen.
        local input_service = Managers.input and Managers.input:get_input_service("Ingame")

        if input_service then
            input_service:get("move")
        end

        if frame_axis_x ~= 0 or frame_axis_y ~= 0 then
            minigame:on_axis_set(t, frame_axis_x, frame_axis_y)
            frame_axis_x, frame_axis_y = 0, 0
        end
    end

    minigame:update(dt, t)
end

function mod.on_disabled()
    close_practice()
    close_selector()
end

function mod.on_game_state_changed(status, state_name)
    if status == "exit" then
        close_practice()
        close_selector()
    end
end

local root = "PracticeMinigames/scripts/mods/PracticeMinigames/"
register_view(SELECTOR_VIEW, "PracticeMinigamesSelectorView", root .. "PracticeMinigames_selector_view")
register_view(PRACTICE_VIEW, "PracticeMinigamesView", root .. "PracticeMinigames_view")

return true
