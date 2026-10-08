---@class PracticeMinigamesMod
local mod = get_mod("PracticeMinigames")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "practice_toggle_key",
                type = "keybind",
                default_value = { "f9" },
                keybind_trigger = "pressed",
                keybind_type = "function_call",
                function_name = "toggle_practice",
                tooltip = "practice_toggle_key_tooltip",
            },
        },
    },
}
