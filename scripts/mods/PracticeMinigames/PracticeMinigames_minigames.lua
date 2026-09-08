local mod = get_mod("PracticeMinigames")
local MinigameSettings = require("scripts/settings/minigame/minigame_settings")

local abs = math.abs
local atan2 = math.atan2
local clamp = math.clamp
local cos = math.cos
local max = math.max
local pi = math.pi
local random = math.random
local sin = math.sin
local sqrt = math.sqrt
local BALANCE_DURATION = 10

local SOUND_EVENTS = {
    sfx_minigame_success = "wwise/events/player/play_device_auspex_scanner_minigame_progress",
    sfx_minigame_success_last = "wwise/events/player/play_device_auspex_scanner_minigame_progress_last",
    sfx_minigame_fail = "wwise/events/player/play_device_auspex_scanner_minigame_fail",
    sfx_minigame_bio_selection = "wwise/events/player/play_device_auspex_bio_minigame_selection",
    sfx_minigame_bio_selection_right = "wwise/events/player/play_device_auspex_bio_minigame_selection_right",
    sfx_minigame_bio_selection_wrong = "wwise/events/player/play_device_auspex_bio_minigame_selection_wrong",
    sfx_minigame_bio_progress = "wwise/events/player/play_device_auspex_bio_minigame_progress",
    sfx_minigame_bio_progress_last = "wwise/events/player/play_device_auspex_bio_minigame_progress_last",
    sfx_minigame_bio_fail = "wwise/events/player/play_device_auspex_bio_minigame_fail",
    sfx_minigame_sinus_adjust_x = "wwise/events/player/play_device_auspex_scanner_minigame_sinus_adjust_x",
    sfx_minigame_sinus_adjust_y = "wwise/events/player/play_device_auspex_scanner_minigame_sinus_adjust_y",
    sfx_minigame_sinus_success_last = "wwise/events/player/play_device_auspex_scanner_minigame_sinus_aligned",
}

local function gameplay_time()
    return mod._time("gameplay") or 0
end

local function play_sound(alias)
    local world = Managers.world and Managers.world:world("level_world")
    local wwise_world = world and World.get_data(world, "wwise_world")
    local event = SOUND_EVENTS[alias]

    if wwise_world and event then
        WwiseWorld.trigger_resource_event(wwise_world, event)
    end
end

local Base = {}
Base.__index = Base

function Base:_init(stage_amount)
    self._action_held = false
    self._completed = false
    self._current_stage = 1
    self._current_state = MinigameSettings.game_states.gameplay
    self._stage_amount = stage_amount or 1
    self._should_exit = false
end

function Base:start(player)
    self._player = player
    self._practice_start = gameplay_time()
end

function Base:setup_game()
end

function Base:is_completed()
    return self._completed
end

function Base:complete()
    self._completed = true
    self._current_stage = self._stage_amount + 1
end

function Base:current_stage()
    return self._current_stage
end

function Base:state()
    return self._current_state
end

function Base:set_state(state)
    self._current_state = state
    self._state_start_time = gameplay_time()
end

function Base:action(held, t)
    if held ~= self._action_held then
        self._action_held = held

        if held then
            self:on_action_pressed(t)
        end
    end
end

function Base:on_action_pressed(t)
end

function Base:on_axis_set(t, x, y)
end

function Base:update(dt, t)
end

function Base:uses_action()
    return true
end

function Base:uses_joystick()
    return false
end

function Base:escape_action(pressed)
    self._should_exit = pressed == true
end

function Base:should_exit()
    return self._should_exit
end

function Base:play_sound(alias)
    play_sound(alias)
end

local DecodeSymbols = setmetatable({}, { __index = Base })
DecodeSymbols.__index = DecodeSymbols

function DecodeSymbols:new()
    local stage_amount = MinigameSettings.decode_symbols_stage_amount
    local items_per_stage = MinigameSettings.decode_symbols_items_per_stage
    local symbols = {}
    local targets = {}
    local previous

    for i = 1, MinigameSettings.decode_symbols_total_items do
        symbols[i] = i
    end

    for i = #symbols, 2, -1 do
        local swap = random(1, i)
        symbols[i], symbols[swap] = symbols[swap], symbols[i]
    end

    for stage = 1, stage_amount do
        local target = random(1, items_per_stage)

        while target == previous do
            target = random(1, items_per_stage)
        end

        targets[stage] = target
        previous = target
    end

    local game = setmetatable({
        _decode_symbols_items_per_stage = items_per_stage,
        _decode_symbols_sweep_duration = MinigameSettings.decode_symbols_sweep_duration,
        _decode_targets = targets,
        _symbols = symbols,
    }, DecodeSymbols)
    game:_init(stage_amount)

    return game
end

function DecodeSymbols:start(player)
    Base.start(self, player)
    self._decode_start_time = gameplay_time()
end

function DecodeSymbols:start_time()
    return self._decode_start_time
end

function DecodeSymbols:sweep_duration()
    return self._decode_symbols_sweep_duration
end

function DecodeSymbols:symbols()
    return self._symbols
end

function DecodeSymbols:current_decode_target()
    return self._decode_targets[self._current_stage]
end

function DecodeSymbols:_calculate_cursor_time(t)
    local duration = self._decode_symbols_sweep_duration
    local cursor_time = (t - self._decode_start_time) % (duration * 2)

    return duration < cursor_time and duration * 2 - cursor_time or cursor_time
end

function DecodeSymbols:is_on_target(t)
    local target = self:current_decode_target()

    if not target then
        return false
    end

    local duration = self._decode_symbols_sweep_duration
    local margin = duration / (self._decode_symbols_items_per_stage - 1)
    local cursor_time = self:_calculate_cursor_time(t)

    return (target - 1.5) * margin < cursor_time and cursor_time < (target - 0.5) * margin
end

function DecodeSymbols:on_action_pressed(t)
    if self:is_on_target(t) then
        self._current_stage = self._current_stage + 1

        if self._current_stage > self._stage_amount then
            self:complete()
            self:play_sound("sfx_minigame_success_last")
        else
            self:play_sound("sfx_minigame_success")
        end
    else
        self._current_stage = max(self._current_stage - 1, 1)
        self:play_sound("sfx_minigame_fail")
    end
end

local DecodeSearch = setmetatable({}, { __index = Base })
DecodeSearch.__index = DecodeSearch

local SEARCH_WIDTH = MinigameSettings.decode_search_board_width
local SEARCH_HEIGHT = MinigameSettings.decode_search_board_height
local CURSOR_WIDTH = MinigameSettings.decode_search_cursor_width
local CURSOR_HEIGHT = MinigameSettings.decode_search_cursor_height

local function search_symbols()
    local categories = MinigameSettings.decode_search_symbols
    local board_symbols = {}
    local symbols = {}

    for i = 1, #categories do
        board_symbols[i] = categories[i][random(1, #categories[i])]
    end

    for i = 1, SEARCH_WIDTH * SEARCH_HEIGHT do
        symbols[i] = board_symbols[random(1, #board_symbols)]
    end

    return symbols
end

local function symbols_at(symbols, target_x, target_y)
    local result = {}

    for y = 1, CURSOR_HEIGHT do
        for x = 1, CURSOR_WIDTH do
            result[#result + 1] = symbols[target_x + x - 1 + (target_y + y - 2) * SEARCH_WIDTH]
        end
    end

    return result
end

function DecodeSearch:new()
    local symbols = search_symbols()
    local targets = {}
    local last_x = math.floor(SEARCH_WIDTH / 2)
    local last_y = math.floor(SEARCH_HEIGHT / 2)

    for stage = 1, MinigameSettings.decode_search_stage_amount do
        local x, y = last_x, last_y

        while x == last_x and y == last_y do
            x = random(1, SEARCH_WIDTH - CURSOR_WIDTH + 1)
            y = random(1, SEARCH_HEIGHT - CURSOR_HEIGHT + 1)
        end

        targets[stage] = symbols_at(symbols, x, y)
        last_x, last_y = x, y
    end

    local game = setmetatable({
        _cursor_position = { x = math.floor(SEARCH_WIDTH / 2), y = math.floor(SEARCH_HEIGHT / 2) },
        _decode_targets = targets,
        _last_move = 0,
        _moved_time = nil,
        _symbols = symbols,
    }, DecodeSearch)
    game:_init(MinigameSettings.decode_search_stage_amount)

    return game
end


function DecodeSearch:symbols()
    return self._symbols
end

function DecodeSearch:decode_targets()
    return self._decode_targets
end

function DecodeSearch:current_decode_target()
    return self._decode_targets[self._current_stage]
end

function DecodeSearch:cursor_position()
    return self._cursor_position
end

function DecodeSearch:time_since_move()
    return self._moved_time and gameplay_time() - self._moved_time or 0
end

function DecodeSearch:is_on_target()
    local selected = symbols_at(self._symbols, self._cursor_position.x, self._cursor_position.y)
    local target = self:current_decode_target()

    if not target then
        return false
    end

    for i = 1, #target do
        if target[i] ~= selected[i] then
            return false
        end
    end

    return true
end


function DecodeSearch:on_axis_set(t, x, y)
    if self._current_state ~= MinigameSettings.game_states.gameplay then
        return
    end

    y = -y
    local deadzone = MinigameSettings.decode_move_deadzone

    if abs(x) < deadzone and abs(y) < deadzone then
        self._last_move = 0
    elseif t > self._last_move + MinigameSettings.decode_move_delay then
        self._last_move = t
        local position = self._cursor_position
        local previous_x, previous_y = position.x, position.y

        if deadzone <= abs(x) then
            position.x = clamp(position.x + (x < 0 and -1 or 1), 1, SEARCH_WIDTH - CURSOR_WIDTH + 1)
        end

        if deadzone <= abs(y) then
            position.y = clamp(position.y + (y < 0 and -1 or 1), 1, SEARCH_HEIGHT - CURSOR_HEIGHT + 1)
        end

        if position.x ~= previous_x or position.y ~= previous_y then
            self._moved_time = t
        end
    end
end

function DecodeSearch:on_action_pressed()
    if self._current_state ~= MinigameSettings.game_states.gameplay then
        return
    end

    if self:is_on_target() then
        self._current_stage = self._current_stage + 1

        if self._current_stage > self._stage_amount then
            self:set_state(MinigameSettings.game_states.outro)
            self:play_sound("sfx_minigame_success_last")
        else
            self:set_state(MinigameSettings.game_states.transition)
            self:play_sound("sfx_minigame_success")
        end
    else
        self._current_stage = max(self._current_stage - 1, 1)
        self:play_sound("sfx_minigame_fail")
    end
end

function DecodeSearch:update(dt, t)
    if self._current_state == MinigameSettings.game_states.outro
            and t - self._state_start_time > MinigameSettings.decode_transition_time then
        self:complete()
    elseif self._current_state == MinigameSettings.game_states.transition
            and t - self._state_start_time > MinigameSettings.decode_transition_time then
        self:set_state(MinigameSettings.game_states.gameplay)
    end
end

function DecodeSearch:uses_joystick()
    return true
end

local Drill = setmetatable({}, { __index = Base })
Drill.__index = Drill

local function target_overlap(x, y, targets)
    for i = 1, #targets do
        local target = targets[i]

        if sqrt((x - target.x) ^ 2 + (y - target.y) ^ 2) < 0.35 then
            return true
        end
    end

    return false
end


local function aligned_neighbor(x, y, targets)
    for i = 1, #targets do
        local target = targets[i]

        if abs(target.x - x) < 0.1 or abs(target.y - y) < 0.1 then
            return true
        end
    end

    return false
end

local function drill_targets()
    local targets = {}
    local correct = {}

    for stage = 1, MinigameSettings.drill_stage_amount do
        local stage_targets = {}
        targets[stage] = stage_targets
        correct[stage] = random(1, MinigameSettings.drill_stage_targets)

        for target = 1, MinigameSettings.drill_stage_targets do
            local x, y
            local tries = 100

            repeat
                tries = tries - 1
                x = -0.8 + random(1, 100) / 100 * 1.6
                y = -0.5 + random(1, 100) / 100
            until (not target_overlap(x, y, stage_targets) and not aligned_neighbor(x, y, stage_targets)) or tries <= 0

            stage_targets[target] = { x = x, y = y }
        end
    end

    return targets, correct
end

function Drill:new()
    local targets, correct = drill_targets()
    local game = setmetatable({
        _correct_targets = correct,
        _cursor_position = { x = 0, y = 0 },
        _last_move = 0,
        _search_result_played = false,
        _search_time = false,
        _selected_index = nil,
        _targets = targets,
        _transition_start_time = nil,
    }, Drill)
    game:_init(MinigameSettings.drill_stage_amount)

    return game
end


function Drill:targets()
    return self._targets
end

function Drill:correct_targets()
    return self._correct_targets
end

function Drill:cursor_position()
    return self._cursor_position
end

function Drill:selected_index()
    return self._selected_index
end

function Drill:is_searching()
    return self._search_time ~= false
end

function Drill:is_on_target()
    return self._selected_index == self._correct_targets[self._current_stage]
end

function Drill:search_percentage(t)
    return self._search_time and clamp((t - self._search_time) / MinigameSettings.drill_search_time, 0, 1) or 0
end

function Drill:transition_percentage(t)
    return self._transition_start_time
        and clamp((t - self._transition_start_time) / MinigameSettings.drill_transition_time, 0, 1) or 0
end

function Drill:on_axis_set(t, x, y)
    if self._current_state ~= MinigameSettings.game_states.gameplay
            or not self._current_stage or x == 0 and y == 0
            or t <= self._last_move + MinigameSettings.drill_move_delay then
        return
    end

    self._last_move = t
    local aim = atan2(-y, x)
    local targets = self._targets[self._current_stage]
    local cursor = self._cursor_position
    local closest
    local lowest = math.huge

    for i = 1, #targets do
        if i ~= self._selected_index then
            local target = targets[i]
            local angle = abs(atan2(target.y - cursor.y, target.x - cursor.x) - aim)

            if angle > pi then
                angle = 2 * pi - angle
            end

            local distance = sqrt((cursor.x - target.x) ^ 2 + (cursor.y - target.y) ^ 2)
            local points = distance + angle * MinigameSettings.drill_move_distance_power

            if points < lowest and angle < pi / 3 then
                closest, lowest = i, points
            end
        end
    end

    if closest then
        local target = targets[closest]
        self._selected_index = closest
        self._cursor_position.x = target.x
        self._cursor_position.y = target.y
        self._search_time = t
        self._search_result_played = false
        self:play_sound("sfx_minigame_bio_selection")
    end
end

function Drill:on_action_pressed(t)
    if self._current_state ~= MinigameSettings.game_states.gameplay
            or not self._search_time or self:search_percentage(t) < 1 then
        return
    end

    if self:is_on_target() then
        self._search_time = false
        self._selected_index = nil
        self._cursor_position.x, self._cursor_position.y = 0, 0
        self._current_stage = self._current_stage + 1

        if self._current_stage > self._stage_amount then
            self:set_state(MinigameSettings.game_states.outro)
            self._transition_start_time = t
            self:play_sound("sfx_minigame_bio_progress_last")
        else
            self:set_state(MinigameSettings.game_states.transition)
            self._transition_start_time = t
            self:play_sound("sfx_minigame_bio_progress")
        end
    else
        self:play_sound("sfx_minigame_bio_fail")
    end
end

function Drill:update(dt, t)
    if self._current_state == MinigameSettings.game_states.outro
            and t - self._transition_start_time > MinigameSettings.drill_transition_time then
        self:complete()
    elseif self._current_state == MinigameSettings.game_states.transition
            and t - self._transition_start_time > MinigameSettings.drill_transition_time then
        self:set_state(MinigameSettings.game_states.gameplay)
    elseif self._search_time and not self._search_result_played and self:search_percentage(t) >= 1 then
        self._search_result_played = true
        self:play_sound(self:is_on_target() and "sfx_minigame_bio_selection_right" or "sfx_minigame_bio_selection_wrong")
    end
end

function Drill:uses_joystick()
    return true
end

local Frequency = setmetatable({}, { __index = Base })
Frequency.__index = Frequency

local function random_frequency()
    return {
        x = random(MinigameSettings.frequency_width_min_scale * 100, MinigameSettings.frequency_width_max_scale * 100) / 100,
        y = random(MinigameSettings.frequency_height_min_scale * 100, MinigameSettings.frequency_height_max_scale * 100) / 100,
    }
end

local function frequency_pair()
    local frequency = random_frequency()
    local target = random_frequency()
    local margin = MinigameSettings.frequency_success_margin

    while abs(frequency.x - target.x) < margin or abs(frequency.y - target.y) < margin do
        target = random_frequency()
    end

    return frequency, target
end

function Frequency:new()
    local frequency, target = frequency_pair()
    local game = setmetatable({
        _frequency = frequency,
        _last_axis_set = nil,
        _target_frequency = target,
    }, Frequency)
    game:_init(MinigameSettings.frequency_search_stage_amount)

    return game
end


function Frequency:frequency()
    return self._frequency
end

function Frequency:target_frequency()
    return self._target_frequency
end

function Frequency:uses_joystick()
    return true
end

function Frequency:is_visually_on_target()
    return abs(self._frequency.x - self._target_frequency.x) < MinigameSettings.frequency_success_margin
        and abs(self._frequency.y - self._target_frequency.y) < MinigameSettings.frequency_success_margin
end

function Frequency:_adjust(current, target, ratio, dt, minimum, maximum, input)
    local new_value = clamp(current + input * ratio * dt, minimum, maximum)
    local distance = abs(new_value - target)

    if MinigameSettings.frequency_help_enabled and distance < MinigameSettings.frequency_help_margin then
        local adjustment = (1 - distance / MinigameSettings.frequency_help_margin)
            * MinigameSettings.frequency_help_power * dt

        if distance < adjustment then
            return target
        end

        new_value = new_value + (new_value > target and -adjustment or adjustment)
    end

    return new_value
end

function Frequency:on_axis_set(t, x, y)
    if not self._last_axis_set then
        self._last_axis_set = t
        return
    end

    local dt = math.min(t - self._last_axis_set, 0.2)
    self._last_axis_set = t

    if x ~= 0 then
        self._frequency.x = self:_adjust(self._frequency.x, self._target_frequency.x,
            MinigameSettings.frequency_change_ratio_x, dt, MinigameSettings.frequency_width_min_scale,
            MinigameSettings.frequency_width_max_scale, x)
        self:play_sound("sfx_minigame_sinus_adjust_x")
    end

    if y ~= 0 then
        self._frequency.y = self:_adjust(self._frequency.y, self._target_frequency.y,
            MinigameSettings.frequency_change_ratio_y, dt, MinigameSettings.frequency_height_min_scale,
            MinigameSettings.frequency_height_max_scale, y)
        self:play_sound("sfx_minigame_sinus_adjust_y")
    end
end

function Frequency:on_action_pressed()
    if self:is_visually_on_target() then
        self._current_stage = self._current_stage + 1

        if self._current_stage > self._stage_amount then
            self:complete()
            self:play_sound("sfx_minigame_sinus_success_last")
        else
            self._frequency, self._target_frequency = frequency_pair()
            self:play_sound("sfx_minigame_success")
        end
    else
        if self._current_stage > 1 then
            self._frequency, self._target_frequency = frequency_pair()
        end

        self._current_stage = max(self._current_stage - 1, 1)
        self:play_sound("sfx_minigame_bio_fail")
    end
end

local Balance = setmetatable({}, { __index = Base })
Balance.__index = Balance

function Balance:new()
    local game = setmetatable({
        _disrupt_timer = 0,
        _is_stuck_indication = false,
        _position = { x = 0, y = 0 },
        _progression = 0,
        _sound_alert_time = 0,
        _speed = { x = 0, y = 0 },
    }, Balance)
    game:_init(1)

    return game
end

function Balance:start(player)
    Base.start(self, player)
    self._last_axis_set = gameplay_time()
end

function Balance:position()
    return self._position
end

function Balance:distance()
    return sqrt(self._position.x ^ 2 + self._position.y ^ 2)
end

function Balance:progressing()
    return self:distance() < 1
end

function Balance:progression()
    return self._progression
end

function Balance:uses_action()
    return false
end

function Balance:uses_joystick()
    return true
end

function Balance:on_axis_set(t, x, y)
    local dt = max(t - self._last_axis_set, 0)
    self._last_axis_set = t
    y = -y
    self._speed.x = self._speed.x + clamp(x, -1, 1) * MinigameSettings.balance_move_ratio * dt
    self._speed.y = self._speed.y + clamp(y, -1, 1) * MinigameSettings.balance_move_ratio * dt
end

function Balance:update(dt, t)
    local position = self._position
    local speed = self._speed
    position.x = position.x + speed.x * dt
    position.y = position.y + speed.y * dt

    local aim_away = atan2(-position.y, position.x)
    local distance = self:distance()

    if distance > 1.02 then
        position.x = cos(aim_away) * 1.01
        position.y = -sin(aim_away) * 1.01
        speed.x, speed.y = 0, 0
    elseif distance < 1 then
        local power = (1 - distance) * MinigameSettings.balance_push_ratio * dt
        speed.x = speed.x + cos(aim_away) * power
        speed.y = speed.y - sin(aim_away) * power
    end

    self._disrupt_timer = self._disrupt_timer - dt

    if distance >= 1 then
        self._disrupt_timer = MinigameSettings.balance_disrupt_interval
    elseif self._disrupt_timer <= 0 then
        self._disrupt_timer = self._disrupt_timer + MinigameSettings.balance_disrupt_interval
        local angle = random(0, 6)
        speed.x = speed.x + cos(angle) * MinigameSettings.balance_disrupt_power
        speed.y = speed.y - sin(angle) * MinigameSettings.balance_disrupt_power
    end

    local maximum = MinigameSettings.balance_max_speed
    speed.x = clamp(speed.x, -maximum, maximum)
    speed.y = clamp(speed.y, -maximum, maximum)

    if self._sound_alert_time > 0 then
        self._sound_alert_time = self._sound_alert_time - dt
    else
        local is_stuck = distance >= 1

        if is_stuck ~= self._is_stuck_indication then
            if is_stuck then
                self:play_sound("sfx_minigame_fail")
            end

            self._is_stuck_indication = is_stuck
            self._sound_alert_time = MinigameSettings.balance_sound_block
        end
    end

    if distance < 1 then
        self._progression = clamp(self._progression + dt / BALANCE_DURATION, 0, 1)

        if self._progression >= 1 then
            self:complete()
        end
    end

    self._last_axis_set = t
end

local Extension = {}
Extension.__index = Extension

function Extension:new(minigame_type, minigame)
    return setmetatable({ _minigame_type = minigame_type, _minigame = minigame }, Extension)
end

function Extension:minigame()
    return self._minigame
end

function Extension:minigame_type()
    return self._minigame_type
end

local FACTORIES = {
    balance = function() return Balance:new() end,
    decode_search = function() return DecodeSearch:new() end,
    decode_symbols = function() return DecodeSymbols:new() end,
    drill = function() return Drill:new() end,
    frequency = function() return Frequency:new() end,
}

function mod._practice_create(minigame_type)
    local factory = FACTORIES[minigame_type]

    if not factory then
        return nil
    end

    local minigame = factory()
    return Extension:new(minigame_type, minigame), minigame
end

return true
