local mod = get_mod("PracticeMinigames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local PANEL_WIDTH = 760
local PANEL_HEIGHT = 430
local CARD_WIDTH = 136
local CARD_HEIGHT = 220

local PROGRAMS = {
    { type = "decode_symbols", color = { 255, 75, 225, 175 } },
    { type = "decode_search", color = { 255, 235, 185, 70 } },
    { type = "drill", color = { 255, 100, 195, 245 } },
    { type = "frequency", color = { 255, 210, 95, 235 } },
    { type = "balance", color = { 255, 130, 235, 105 } },
}

local COLORS = {
    background = { 245, 2, 12, 10 },
    card = { 225, 4, 18, 15 },
    card_selected = { 250, 8, 34, 27 },
    frame = { 100, 30, 110, 85 },
    text = { 255, 195, 255, 225 },
    text_dim = { 175, 80, 150, 130 },
}

local scenegraph = {
    screen = table.clone(UIWorkspaceSettings.screen),
    panel = {
        horizontal_alignment = "center",
        parent = "screen",
        vertical_alignment = "center",
        size = { PANEL_WIDTH, PANEL_HEIGHT },
        position = { 0, 0, 20 },
    },
    title = {
        horizontal_alignment = "center",
        parent = "panel",
        vertical_alignment = "top",
        size = { 700, 34 },
        position = { 0, 28, 5 },
    },
    subtitle = {
        horizontal_alignment = "center",
        parent = "panel",
        vertical_alignment = "top",
        size = { 700, 24 },
        position = { 0, 68, 5 },
    },
    controls = {
        horizontal_alignment = "center",
        parent = "panel",
        vertical_alignment = "bottom",
        size = { 730, 24 },
        position = { 0, -30, 5 },
    },
}

for i = 1, #PROGRAMS do
    scenegraph["card_" .. i] = {
        horizontal_alignment = "center",
        parent = "panel",
        vertical_alignment = "center",
        size = { CARD_WIDTH, CARD_HEIGHT },
        position = { (i - 3) * 146, 10, 5 },
    }
end

local function card_definition(scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "background",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.card, offset = { 0, 0, 0 } },
        },
        {
            pass_type = "texture",
            style_id = "frame",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = { hdr = true, color = COLORS.frame, scale_to_material = true, offset = { 0, 0, 3 } },
        },
        {
            pass_type = "texture",
            style_id = "accent",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.frame, size = { CARD_WIDTH - 16, 3 }, offset = { 8, 8, 4 } },
        },
        {
            pass_type = "text",
            style_id = "title",
            value = "",
            value_id = "title",
            style = {
                font_size = 16,
                font_type = "machine_medium",
                size = { CARD_WIDTH - 10, 62 },
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text,
                offset = { 5, 30, 5 },
            },
        },
        {
            pass_type = "text",
            style_id = "description",
            value = "",
            value_id = "description",
            style = {
                font_size = 12,
                font_type = "machine_medium",
                size = { CARD_WIDTH - 12, 58 },
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text_dim,
                offset = { 6, 92, 5 },
            },
        },
        {
            pass_type = "text",
            style_id = "stats",
            value = "",
            value_id = "stats",
            style = {
                font_size = 12,
                font_type = "machine_medium",
                size = { CARD_WIDTH - 12, 62 },
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text_dim,
                offset = { 6, 148, 5 },
            },
        },
    }, scenegraph_id, nil, { CARD_WIDTH, CARD_HEIGHT })
end

local widget_definitions = {
    overlay = UIWidget.create_definition({
        { pass_type = "rect", style = { color = { 150, 0, 0, 0 } } },
    }, "screen"),
    background = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.background },
        },
        {
            pass_type = "texture",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = { hdr = true, color = { 190, 45, 185, 135 }, scale_to_material = true, offset = { 0, 0, 3 } },
        },
    }, "panel", nil, { PANEL_WIDTH, PANEL_HEIGHT }),
    title_text = UIWidget.create_definition({
        {
            pass_type = "text",
            value = mod:localize("practice_selector_title"),
            style = {
                font_size = 24,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text,
            },
        },
    }, "title"),
    subtitle_text = UIWidget.create_definition({
        {
            pass_type = "text",
            value = mod:localize("practice_selector_subtitle"),
            style = {
                font_size = 14,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text_dim,
            },
        },
    }, "subtitle"),
    controls_text = UIWidget.create_definition({
        {
            pass_type = "text",
            value = mod:localize("practice_selector_controls"),
            style = {
                font_size = 13,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text_dim,
            },
        },
    }, "controls"),
}

for i = 1, #PROGRAMS do
    widget_definitions["program_card_" .. i] = card_definition("card_" .. i)
end

local definitions = {
    scenegraph_definition = scenegraph,
    widget_definitions = widget_definitions,
}

local PracticeMinigamesSelectorView = class("PracticeMinigamesSelectorView", "BaseView")

local function set_color(destination, source, alpha)
    destination[1] = alpha or source[1]
    destination[2] = source[2]
    destination[3] = source[3]
    destination[4] = source[4]
end

function PracticeMinigamesSelectorView:init(settings, context)
    PracticeMinigamesSelectorView.super.init(self, definitions, settings, context)
    self._state = context.state
    self._stats = context.stats
    self._latest_results = context.latest_results
    self._no_cursor = true
    self._time = 0
end

function PracticeMinigamesSelectorView:dialogue_system()
    return nil
end

function PracticeMinigamesSelectorView:is_using_input()
    return false
end

function PracticeMinigamesSelectorView:update(dt, t, input_service)
    self._time = self._time + (dt or 0)
    return PracticeMinigamesSelectorView.super.update(self, dt, t, input_service)
end

function PracticeMinigamesSelectorView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local selected_index = self._state and self._state.selected or 1

    for i = 1, #PROGRAMS do
        local program = PROGRAMS[i]
        local widget = self._widgets_by_name["program_card_" .. i]

        if widget then
            local selected = i == selected_index
            local pulse = selected and 205 + math.floor((math.sin(self._time * 4) + 1) * 25) or 70
            local stat = self._stats and self._stats[program.type]
            local latest = self._latest_results and self._latest_results[program.type]

            widget.content.title = mod:localize("practice_type_" .. program.type)
            widget.content.description = mod:localize("practice_selector_desc_" .. program.type)
            widget.content.stats = stat and stat.count > 0
                and string.format("%s\nBEST %.2fs\n%d RUNS",
                    latest and string.format("LAST %.2fs", latest) or "LAST --", stat.best, stat.count)
                or "LAST --\nBEST --\n0 RUNS"
            set_color(widget.style.background.color, selected and COLORS.card_selected or COLORS.card)
            set_color(widget.style.frame.color, selected and program.color or COLORS.frame, pulse)
            set_color(widget.style.accent.color, selected and program.color or COLORS.frame, selected and 255 or 65)
            set_color(widget.style.title.text_color, selected and COLORS.text or COLORS.text_dim, selected and 255 or 175)
            set_color(widget.style.description.text_color, selected and COLORS.text or COLORS.text_dim, selected and 205 or 120)
            set_color(widget.style.stats.text_color, selected and program.color or COLORS.text_dim, selected and 230 or 135)
        end
    end

    PracticeMinigamesSelectorView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return PracticeMinigamesSelectorView
