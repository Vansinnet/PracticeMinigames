local MinigameBalanceView = require("scripts/ui/views/scanner_display_view/minigame_balance_view")
local MinigameDecodeSearchView = require("scripts/ui/views/scanner_display_view/minigame_decode_search_view")
local MinigameDecodeSymbolsView = require("scripts/ui/views/scanner_display_view/minigame_decode_symbols_view")
local MinigameDrillView = require("scripts/ui/views/scanner_display_view/minigame_drill_view")
local MinigameNoneView = require("scripts/ui/views/scanner_display_view/minigame_none_view")
local MinigameSettings = require("scripts/settings/minigame/minigame_settings")
local ScannerDefinitions = require("scripts/ui/views/scanner_display_view/scanner_display_view_definitions")
local ScannerFrequencySettings = require("scripts/ui/views/scanner_display_view/scanner_display_view_frequency_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local RENDER_SIZE = 1024
local DISPLAY_SCALE = 0.62
local NEUTRAL_COLOR = { 255, 255, 165, 0 }
local HIDDEN_COLOR = { 0, 255, 165, 0 }
local FREQUENCY_TARGET_COLOR = { 255, 0, 128, 0 }
local FREQUENCY_CURRENT_COLOR = { 255, 255, 165, 0 }
local FREQUENCY_WIDGET_SIZE = {}

local function set_neutral_color(color)
    color[1] = NEUTRAL_COLOR[1]
    color[2] = NEUTRAL_COLOR[2]
    color[3] = NEUTRAL_COLOR[3]
    color[4] = NEUTRAL_COLOR[4]
end

local function without_success_state(minigame, method_name, func, ...)
    local original = minigame[method_name]
    minigame[method_name] = function()
        return false
    end
    func(...)
    minigame[method_name] = original
end

local PracticeFrequencyView = {}
PracticeFrequencyView.__index = PracticeFrequencyView

function PracticeFrequencyView:new(context)
    return setmetatable({
        _minigame_extension = context.minigame_extension,
        _frequency_widgets = {},
        _stage_widgets = {},
    }, PracticeFrequencyView)
end

function PracticeFrequencyView:update(dt, t, widgets_by_name)
    local minigame = self._minigame_extension:minigame(MinigameSettings.types.frequency)

    if not minigame:is_completed() then
        if #self._stage_widgets == 0 then
            self:_create_stage_widgets()
        end

        if #self._frequency_widgets == 0 and minigame:frequency() then
            self:_create_frequency_widgets()
        end
    end
end

function PracticeFrequencyView:draw_widgets(dt, t, input_service, ui_renderer)
    local minigame = self._minigame_extension:minigame(MinigameSettings.types.frequency)
    local current_stage = minigame:current_stage()

    if not current_stage then
        return
    end

    self:_draw_frequency(minigame:target_frequency(), FREQUENCY_TARGET_COLOR, t, ui_renderer)
    self:_draw_frequency(minigame:frequency(), FREQUENCY_CURRENT_COLOR, t, ui_renderer)

    for i = 1, #self._stage_widgets do
        local widget = self._stage_widgets[i]
        local alpha = i == current_stage and 255 or i < current_stage and 128 or 64

        widget.style.highlight.color[1] = alpha
        UIWidget.draw(widget, ui_renderer)
    end
end

function PracticeFrequencyView:_draw_frequency(frequency, color, t, ui_renderer)
    local widgets = self._frequency_widgets

    if not frequency or #widgets == 0 then
        return
    end

    local base_size = ScannerFrequencySettings.frequency_widget_size
    local widget_width = base_size[1] * frequency.x
    local widget_height = base_size[2] * frequency.y
    local visible_width = ScannerFrequencySettings.frequency_width
    local left_edge = -visible_width * 0.5
    local right_edge = visible_width * 0.5
    local scroll = t * MinigameSettings.frequency_speed % 1

    FREQUENCY_WIDGET_SIZE[1] = widget_width
    FREQUENCY_WIDGET_SIZE[2] = widget_height

    for i = 1, #widgets do
        local widget = widgets[i]
        local offset_x = left_edge + widget_width * (i - 1 - scroll)
        local visible = offset_x >= left_edge and offset_x + widget_width <= right_edge

        widget.content.size = FREQUENCY_WIDGET_SIZE
        widget.style.style_id_1.color = visible and color or HIDDEN_COLOR
        widget.offset[1] = offset_x
        widget.offset[2] = ScannerFrequencySettings.frequency_starting_offset_y - widget_height * 0.5
        widget.offset[3] = 1
        UIWidget.draw(widget, ui_renderer)
    end
end

function PracticeFrequencyView:_create_stage_widgets()
    local size = ScannerFrequencySettings.stage_widget_size
    local spacing = ScannerFrequencySettings.stage_spacing
    local start_x = ScannerFrequencySettings.stages_starting_offset_x
    local start_y = ScannerFrequencySettings.stages_starting_offset_y
    local definition = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "highlight",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 255, 0, 255, 0 } },
        },
    }, "center_pivot", nil, size)

    for i = 1, MinigameSettings.frequency_search_stage_amount do
        local widget = UIWidget.init("practice_frequency_stage_" .. i, definition)
        widget.offset[1] = start_x + (size[1] + spacing) * (i - 1)
        widget.offset[2] = start_y
        widget.offset[3] = 3
        self._stage_widgets[i] = widget
    end
end

function PracticeFrequencyView:_create_frequency_widgets()
    local base_size = ScannerFrequencySettings.frequency_widget_size
    local count = math.ceil(ScannerFrequencySettings.frequency_width
        / (MinigameSettings.frequency_width_min_scale * base_size[1])) + 2
    local definition = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/scanner/scanner_sine_wave_01",
            style = { hdr = true, color = { 255, 0, 255, 0 } },
        },
    }, "center_pivot", nil, table.clone(base_size))

    for i = 1, count do
        self._frequency_widgets[i] = UIWidget.init("practice_frequency_wave_" .. i, definition)
    end
end


local VIEWS = {
    [MinigameSettings.types.balance] = MinigameBalanceView,
    [MinigameSettings.types.decode_search] = MinigameDecodeSearchView,
    [MinigameSettings.types.decode_symbols] = MinigameDecodeSymbolsView,
    [MinigameSettings.types.drill] = MinigameDrillView,
    [MinigameSettings.types.frequency] = PracticeFrequencyView,
    [MinigameSettings.types.none] = MinigameNoneView,
}

local function remove_success_highlights(minigame_type, minigame_view, minigame)
    if minigame_type == MinigameSettings.types.decode_symbols then
        local update = minigame_view.update

        minigame_view.update = function(self, ...)
            without_success_state(minigame, "is_on_target", update, self, ...)

            local current_stage = minigame:current_stage()
            local items_per_stage = MinigameSettings.decode_symbols_items_per_stage

            for i = 1, #self._grid_widgets do
                local color = self._grid_widgets[i].style.style_id_1.color
                local stage = math.ceil(i / items_per_stage)

                color[1] = stage == current_stage and 255 or 80
                color[2] = 0
                color[3] = 255
                color[4] = 0
            end
        end

        minigame_view.draw_widgets = function(self, dt, t, input_service, ui_renderer)
            for i = 1, #self._grid_widgets do
                UIWidget.draw(self._grid_widgets[i], ui_renderer)
            end
        end
    elseif minigame_type == MinigameSettings.types.decode_search then
        local update = minigame_view.update

        minigame_view.update = function(self, ...)
            without_success_state(minigame, "is_on_target", update, self, ...)
        end

        minigame_view.draw_widgets = function(self, dt, t, input_service, ui_renderer)
            for i = 1, #self._grid_widgets do
                UIWidget.draw(self._grid_widgets[i], ui_renderer)
            end

            local current_stage = minigame:current_stage()

            if not current_stage then
                return
            end

            local targets = self._target_widgets[current_stage]

            if targets then
                for i = 1, #targets do
                    UIWidget.draw(targets[i], ui_renderer)
                end
            end

            for i = 1, #self._stage_widgets do
                local widget = self._stage_widgets[i]
                local alpha = i == current_stage and 255 or i < current_stage and 128 or 64

                widget.style.highlight.color[1] = alpha
                UIWidget.draw(widget, ui_renderer)
            end
        end
    elseif minigame_type == MinigameSettings.types.drill then
        local update_background = minigame_view._update_background
        local update_target = minigame_view._update_target

        minigame_view._update_background = function(self, widgets_by_name, game)
            update_background(self, widgets_by_name, game)

            local widgets = self._background_widgets
            local outer_widget = widgets[#widgets]

            if not outer_widget then
                return
            end

            local half_size = RENDER_SIZE * 0.5
            local outer_size = outer_widget.content.size
            local center_x = outer_widget.offset[1] + outer_size[1] * 0.5
            local center_y = outer_widget.offset[2] + outer_size[2] * 0.5
            local maximum_size = math.max(2 * math.min(
                half_size - math.abs(center_x),
                half_size - math.abs(center_y)
            ), 0)
            local scale = outer_size[1] > 0 and math.min(maximum_size / outer_size[1], 1) or 1

            for i = 1, #widgets do
                local widget = widgets[i]
                local size = widget.content.size
                local scaled_size = size[1] * scale

                size[1] = scaled_size
                size[2] = scaled_size
                widget.offset[1] = center_x - scaled_size * 0.5
                widget.offset[2] = center_y - scaled_size * 0.5
            end
        end

        minigame_view._update_target = function(self, widgets_by_name, game, t)
            update_target(self, widgets_by_name, game, t)

            local stage = game:current_stage()
            local widgets = stage and self._target_widgets[stage]

            if widgets then
                for i = 1, #widgets do
                    set_neutral_color(widgets[i].style.highlight.color)
                end
            end
        end
    elseif minigame_type == MinigameSettings.types.balance then
        local update = minigame_view.update

        minigame_view.update = function(self, dt, t, widgets_by_name)
            update(self, dt, t, widgets_by_name)
            set_neutral_color(widgets_by_name.balance_progress.style.progress_texture.color)
            set_neutral_color(widgets_by_name.cursor.style.frame.color)
        end
    end
end

local built_definitions = {}

local function definitions_for(minigame_type)
    if built_definitions[minigame_type] then
        return built_definitions[minigame_type]
    end

    local stock = ScannerDefinitions[minigame_type] or ScannerDefinitions[MinigameSettings.types.none]
    local definitions = {
        scenegraph_definition = {
            screen = table.clone(UIWorkspaceSettings.screen),
            scanner_base = {
                horizontal_alignment = "center",
                parent = "screen",
                vertical_alignment = "center",
                size = { RENDER_SIZE, RENDER_SIZE },
                position = { 0, 0, 20 },
            },
            center_pivot = {
                horizontal_alignment = "center",
                parent = "scanner_base",
                vertical_alignment = "center",
                size = { 0, 0 },
                position = { 0, 0, 1 },
            },
        },
        widget_definitions = table.clone(stock.widget_definitions),
    }

    if minigame_type == MinigameSettings.types.frequency then
        definitions.widget_definitions.decoration_left_mark = nil
        definitions.widget_definitions.decoration_right_mark = nil
    end

    built_definitions[minigame_type] = definitions

    return definitions
end

local PracticeMinigamesView = class("PracticeMinigamesView", "BaseView")

function PracticeMinigamesView:init(settings, context)
    local minigame_type = context.minigame_type or MinigameSettings.types.none
    PracticeMinigamesView.super.init(self, definitions_for(minigame_type), settings, context)

    self._base_render_scale = nil
    self._no_cursor = true
    self._minigame_view = (VIEWS[minigame_type] or MinigameNoneView):new(context)
    remove_success_highlights(minigame_type, self._minigame_view, context.minigame_extension:minigame())
end

function PracticeMinigamesView:on_enter()
    self._base_render_scale = Managers.ui and Managers.ui:view_render_scale() or 1
    self:set_render_scale(self._base_render_scale * DISPLAY_SCALE)
    PracticeMinigamesView.super.on_enter(self)
end

function PracticeMinigamesView:dialogue_system()
    return nil
end

function PracticeMinigamesView:is_using_input()
    return false
end

function PracticeMinigamesView:update(dt, t, input_service)
    if self._minigame_view and self._minigame_view.update then
        self._minigame_view:update(dt, t, self._widgets_by_name)
    end

    return PracticeMinigamesView.super.update(self, dt, t, input_service)
end

function PracticeMinigamesView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    PracticeMinigamesView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if self._minigame_view and self._minigame_view.draw_widgets then
        self._minigame_view:draw_widgets(dt, t, input_service, ui_renderer)
    end
end

function PracticeMinigamesView:destroy()
    if self._minigame_view and self._minigame_view.delete then
        self._minigame_view:delete()
    end

    self._minigame_view = nil
    PracticeMinigamesView.super.destroy(self)
end

return PracticeMinigamesView
