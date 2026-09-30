-- zz_czx_bon_effects_restore.lua
-- wh3_confid_get 遮蔽了原版 script/campaign/wh2_dlc09_books_of_nagash_effects.lua，
-- 其重写版不定义 bon_effects 全局表。wh_start.lua:212 的 bon_effects:add_listeners()
-- 在 first-tick shared 回调内对 nil 解引用直接抛错 -> call_each 中断 -> 其后所有
-- mod 的 first-tick 回调（wyc_choujiang 抽奖按钮、wyccc_starting_characters 开局英雄、
-- czummon_lord_pool 领主池、psw_guard 等）全部静默跳过，且引擎不把该错误写进
-- script_log（无任何 SCRIPT ERROR）。此前旧播放集靠 pj_formations 的
-- pj_error_wrapping 逐回调 xpcall 兜住才没暴露。
-- 本文件在 mod 加载期（NewSession, ~7.5s，远早于 first-tick）补回 bon_effects。

if bon_effects == nil then
    bon_effects = {
        volkmar_faction_key = "wh3_main_emp_cult_of_sigmar",
        book_effect_bundles = {
            [3] = {
                "wh2_dlc09_books_of_nagash_reward_3",
                "wh3_main_books_of_nagash_mannfred_studied_reward_3",
                "wh3_main_books_of_nagash_mannfred_reward_3",
                "wh3_dlc29_books_of_nagash_nagash_reward_3"
            }
        },
        sandstorm_duration = 5,
        volkmar_book_resource_key = "wh3_main_emp_volkmar_books_destroyed",
    };

    function bon_effects:trigger_book_3_effects(context)
        local faction = context:character():faction();
        local character = context:character();
        local mf = character:military_force();

        if nagash_book_participant_factions[faction:name()] or nagash_book_participant_cultures[faction:culture()] then
            for _, effect_bundle in dpairs(bon_effects.book_effect_bundles[3]) do
                if (mf:has_effect_bundle(effect_bundle)) then
                    local region_key = character:region():name();
                    cm:create_storm_for_region(region_key, 1, self.sandstorm_duration, "land_storm");
                    return true;
                end;
            end;
        end;
    end;

    function bon_effects:add_listeners()
        -- 监听器名带 czx_ 前缀：confid 的同名监听器（VolkmarBooksOfNagashZeal 等）
        -- 已在脚本加载期注册，不能顶替它们。
        core:add_listener(
            "czx_garrison_occupied_tmb_storm",
            "GarrisonOccupiedEvent",
            true,
            function(context)
                bon_effects:trigger_book_3_effects(context);
            end,
            true
        );

        core:add_listener(
            "czx_sacked_settlement_tmb_storm",
            "CharacterSackedSettlement",
            true,
            function(context)
                bon_effects:trigger_book_3_effects(context);
            end,
            true
        );

        core:add_listener(
            "czx_volkmar_books_zeal",
            "ScriptEventBookOfNagashUpdated",
            true,
            function(context)
                local faction_interface = context:faction();
                if faction_interface:name() ~= bon_effects.volkmar_faction_key then
                    return;
                end;

                local new_book_count = context.number;
                local resource = faction_interface:pooled_resource_manager():resource(bon_effects.volkmar_book_resource_key);
                local book_amount_delta = new_book_count - resource:value();
                if book_amount_delta == 0 then
                    return;
                end;

                cm:faction_add_pooled_resource(bon_effects.volkmar_faction_key, bon_effects.volkmar_book_resource_key, "wh3_main_emp_volkmar_books_destroyed", book_amount_delta);
            end,
            true
        );
    end;

    out("[czx_bon_fix] restored missing bon_effects global (wh3_confid_get shadowed wh2_dlc09_books_of_nagash_effects.lua)");
else
    out("[czx_bon_fix] bon_effects already present, no action");
end;
