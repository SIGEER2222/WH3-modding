bm:out("ZZTEST: battle control script loaded");

local function collect_side(aidx)
	local list = {};
	local alliances = bm:alliances();
	local al = alliances:item(aidx);
	if not al then return list end;
	local armies = al:armies();
	for i = 1, armies:count() do
		local army = armies:item(i);
		local units = army:units();
		for u = 1, units:count() do
			local su = script_unit:new_by_reference(army, u);
			list[#list + 1] = su;
		end;
	end;
	return list;
end;

-- one-shot: order ENEMY (side2) to march to our units; our units hold
local issued = false;
local function issue_orders()
	if issued then return end;
	local ok, err = pcall(function()
		local side1 = collect_side(1);
		local side2 = collect_side(2);
		if #side1 == 0 or #side2 == 0 then return end;
		local anchor = side1[1].unit:position();
		bm:out("ZZTEST anchor @" .. anchor:get_x() .. "," .. anchor:get_z());
		for i, su in ipairs(side2) do
			su:take_control();
			su.uc:goto_location_angle_width(v(anchor:get_x(), anchor:get_z()), 180, su.unit:ordered_width(), true);
		end;
		issued = true;
		bm:out("ZZTEST: enemy march order issued");
	end);
	if not ok then bm:out("ZZTEST ERR: " .. tostring(err)) end;
end;

-- camera continuously tracks our first unit's live position
local function aim_cam()
	local ok, err = pcall(function()
		local side1 = collect_side(1);
		if #side1 == 0 then return end;
		local p = side1[1].unit:position();
		local cam = bm:camera();
		cam:move_to(v(p:get_x(), 12, p:get_z() - 10), v(p:get_x(), 0, p:get_z()), 0, false, 0);
	end);
	if not ok then bm:out("ZZTEST CAM ERR: " .. tostring(err)) end;
end;

bm:callback(issue_orders, 8000);
for t = 10000, 150000, 1500 do
	bm:callback(aim_cam, t);
end;
