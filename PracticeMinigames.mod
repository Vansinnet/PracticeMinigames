return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`PracticeMinigames` encountered an error loading the Darktide Mod Framework.")

        new_mod("PracticeMinigames", {
            mod_script = "PracticeMinigames/scripts/mods/PracticeMinigames/PracticeMinigames",
            mod_data = "PracticeMinigames/scripts/mods/PracticeMinigames/PracticeMinigames_data",
            mod_localization = "PracticeMinigames/scripts/mods/PracticeMinigames/PracticeMinigames_localization",
        })
    end,
    packages = {},
}
