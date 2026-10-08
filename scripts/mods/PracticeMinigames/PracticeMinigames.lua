---@class PracticeMinigamesMod: DMFMod
local mod = get_mod("PracticeMinigames")

local mod_dir = "PracticeMinigames/scripts/mods/PracticeMinigames/"

mod._time = function(clock)
    local time_manager = Managers.time
    if not time_manager then
        return nil
    end

    local ok, value = pcall(time_manager.time, time_manager, clock or "gameplay")
    return ok and value or nil
end

mod:io_dofile(mod_dir .. "PracticeMinigames_minigames")
mod:io_dofile(mod_dir .. "PracticeMinigames_practice")

return mod
