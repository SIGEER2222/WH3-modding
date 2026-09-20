-- zzz_nanu_loc_fix.lua
-- nanu_dynamic_rors_localization_script() crashes on Chinese clients:
-- it parses lines 2/3 of random_localisation_strings_string_tooltip_kills
-- expecting "Label: %d" with an ASCII colon; the Chinese localized string
-- uses a different colon, so the label comes back nil and the log concat dies.
-- The zzz_ prefix makes this file execute after the original script, so the
-- global function override below wins; the engine's init call by name then
-- invokes this tolerant version instead.

if type(nanu_dynamic_rors_localization_script) == "function" then
    nanu_dynamic_rors_localization_script = function()
        local tooltip_key = common.get_localised_string("random_localisation_strings_string_tooltip_kills")
        local stat_block = tooltip_key and (string.match(tooltip_key, "^(.-)||") or tooltip_key)
        local line_num = 0
        local dealt_label, gold_label
        for line in string.gmatch(stat_block or "", "[^\n]+") do
            line_num = line_num + 1
            if line_num == 2 then
                dealt_label = string.match(line, "^(.-)[:：]%s*%%d")
            elseif line_num == 3 then
                gold_label = string.match(line, "^(.-)[:：]%s*%%d")
                break
            end
        end
        local function esc(s)
            return s and (s:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"))
        end
        localized_damage_dealt_pattern = dealt_label and (esc(dealt_label) .. "[:：]%s*(%d+)")
        localized_damage_gold_pattern = gold_label and (esc(gold_label) .. "[:：]%s*(%d+)")
        Dynamc_RoR_Script_Data = Dynamc_RoR_Script_Data or {}
        Dynamc_RoR_Script_Data["localized_damage_dealt_pattern"] = localized_damage_dealt_pattern
        Dynamc_RoR_Script_Data["localized_damage_gold_pattern"] = localized_damage_gold_pattern
        ModLog("[czx_nanu] loc patterns dealt=" .. tostring(localized_damage_dealt_pattern)
            .. " gold=" .. tostring(localized_damage_gold_pattern))
    end
end
