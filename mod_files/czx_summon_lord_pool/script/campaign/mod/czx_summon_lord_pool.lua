-- czx_summon_lord_pool：Lin_Summon_Servant 领主招募池补丁
-- 2026-09-30 工坊更新把英灵召唤从 spawn_character_to_pool("general") 重写为
-- create_agent（dignitary/wizard/champion），10 个从者全部变成事务官。
-- 本补丁恢复旧行为：把 lin_all_* 从者作为领主放入人类派系领主招募池。
-- 每战役只执行一次（saved_value 标记）；旧档首次读档也会补放，与新开战役一致。

local LORDS = {
    { subtype = "lin_all_artoria_lancer",       forename = "names_name_789930001" },
    { subtype = "lin_all_artoria_alter_lancer", forename = "names_name_789930002" },
    { subtype = "lin_all_kerrigan_zerg",        forename = "names_name_789930003" },
    { subtype = "lin_all_hydaelyn_venat",       forename = "names_name_789930004" },
    { subtype = "lin_all_nael_deus_darnus",     forename = "names_name_789930005" },
    { subtype = "lin_all_surtr_arts_fighter",   forename = "names_name_789930006" },
    { subtype = "lin_all_queen_marika",         forename = "names_name_789930007" },
    { subtype = "lin_all_jeanne_ruler",         forename = "names_name_789930008" },
    { subtype = "lin_all_jeanne_alter_avenger", forename = "names_name_789930009" },
    { subtype = "lin_all_scathach_lancer",      forename = "names_name_789930010" },
};

local FLAG = "czx_summon_lord_pool_done";

local function grant_lords_to_pool(faction)
    for _, entry in ipairs(LORDS) do
        local ok, err = pcall(function()
            cm:spawn_character_to_pool(
                faction:name(),
                entry.forename, "", "", "",
                50, true, "general", entry.subtype, true, "");
        end);
        if ok then
            out("[czx_summon_lord_pool] 领主已入招募池: " .. entry.subtype .. " -> " .. faction:name());
        else
            out("[czx_summon_lord_pool] 领主入池失败: " .. entry.subtype .. " -> " .. faction:name() .. ": " .. tostring(err));
        end;
    end;
end;

local function grant_lords_once()
    if cm:get_saved_value(FLAG) then
        return;
    end;
    local human_factions = cm:get_human_factions();
    if not human_factions or #human_factions == 0 then
        return;
    end;
    for i = 1, #human_factions do
        local faction = cm:get_faction(human_factions[i]);
        if faction
            and not faction:is_null_interface()
            and faction:is_human()
            and not faction:is_dead()
        then
            grant_lords_to_pool(faction);
        end;
    end;
    cm:set_saved_value(FLAG, true);
end;

cm:add_first_tick_callback(function()
    pcall(grant_lords_once);
end);
