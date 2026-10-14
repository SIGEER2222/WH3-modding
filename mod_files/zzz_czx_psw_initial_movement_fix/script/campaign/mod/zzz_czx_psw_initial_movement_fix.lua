local MODULE_KEY = "czx_psw_initial_movement_fix"
local NO_MOVEMENT_BUNDLE = "wh3_main_bundle_military_upkeep_free_force_no_movement"

local INITIAL_MAIN_SUBTYPES = {
    yx_lmyx = true,
    yx_hero_sllh = true,
    yx_hero_edu = true,
    yx_hero_niao = true,
    yx_hero_fuxuan = true,
    yx_hero_feibi = true,
    yx_hero_xueli = true,
    yx_hero_mika = true,
}

local INITIAL_AGENT_SUBTYPES = {
    psw_hero_feibi_1 = true,
    psw_hero_xueli_1 = true,
    psw_hero_mika_1 = true,
}

local repaired = {}
local pending = {}

local function log(message)
    out("[" .. MODULE_KEY .. "] " .. tostring(message))
end

local function valid_character(character)
    return character ~= nil
        and character ~= false
        and not character:is_null_interface()
end

local function get_subtype(character)
    local ok, subtype = pcall(function()
        return character:character_subtype_key()
    end)
    if ok then
        return subtype
    end
    return nil
end

local function is_initial_character(character)
    local subtype = get_subtype(character)
    return INITIAL_MAIN_SUBTYPES[subtype] == true
        or INITIAL_AGENT_SUBTYPES[subtype] == true
end

local function is_main_character(character)
    return INITIAL_MAIN_SUBTYPES[get_subtype(character)] == true
end

local function has_military_force(character)
    local ok, result = pcall(function()
        return character:has_military_force()
    end)
    return ok and result == true
end

local function repair_character(character, reason, attempt)
    if not valid_character(character) or not is_initial_character(character) then
        return
    end

    local cqi = character:command_queue_index()
    if repaired[cqi] then
        return
    end

    -- A general created with create_force_with_general can fire CharacterCreated
    -- before its military force is attached.  Let the engine finish that queue.
    if is_main_character(character)
        and not has_military_force(character)
        and attempt < 12
    then
        pending[cqi] = true
        cm:callback(function()
            pending[cqi] = nil
            local current = cm:get_character_by_cqi(cqi)
            repair_character(current, reason, attempt + 1)
        end, 0.25)
        return
    end

    local lookup = cm:char_lookup_str(character)
    local removed_bundle = false
    if has_military_force(character) then
        local bundle_present = false
        pcall(function()
            bundle_present = character:military_force():has_effect_bundle(
                NO_MOVEMENT_BUNDLE
            )
        end)
        if bundle_present then
            local remove_ok = pcall(function()
                cm:remove_effect_bundle_from_characters_force(NO_MOVEMENT_BUNDLE, cqi)
            end)
            removed_bundle = remove_ok
        end
    end

    local enable_ok = pcall(function()
        cm:enable_movement_for_character(lookup)
    end)
    local replenish_ok = pcall(function()
        cm:replenish_action_points(lookup)
    end)

    repaired[cqi] = true
    log(
        "repaired subtype=" .. tostring(get_subtype(character))
        .. " cqi=" .. tostring(cqi)
        .. " reason=" .. tostring(reason)
        .. " removed_bundle=" .. tostring(removed_bundle)
        .. " enable_ok=" .. tostring(enable_ok)
        .. " replenish_ok=" .. tostring(replenish_ok)
    )
end

local function queue_repair(character, reason)
    if not valid_character(character) or not is_initial_character(character) then
        return
    end

    local cqi = character:command_queue_index()
    if repaired[cqi] or pending[cqi] then
        return
    end

    pending[cqi] = true
    cm:callback(function()
        pending[cqi] = nil
        local current = cm:get_character_by_cqi(cqi)
        repair_character(current, reason, 1)
    end, 0.2)
end

local function scan_existing_characters()
    local faction_list = cm:model():world():faction_list()
    for faction_index = 0, faction_list:num_items() - 1 do
        local faction = faction_list:item_at(faction_index)
        local characters = faction:character_list()
        for character_index = 0, characters:num_items() - 1 do
            queue_repair(characters:item_at(character_index), "existing_save")
        end
    end
end

cm:add_first_tick_callback(function()
    core:remove_listener(MODULE_KEY .. "_character_created")
    core:add_listener(
        MODULE_KEY .. "_character_created",
        "CharacterCreated",
        true,
        function(context)
            local ok, character = pcall(function()
                return context:character()
            end)
            if ok then
                queue_repair(character, "character_created")
            end
        end,
        true
    )

    scan_existing_characters()
    log("installed")
end)
