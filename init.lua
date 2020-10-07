
-- pos of meseconometer for open formspec per playername
local open_formspecs = {}
-- names A-D for ports 1-4
local abcd = {"A", "B", "C", "D", A = 1, B = 2, C = 3, D = 4}

-- returns the port (1-4) for the given rule
local function get_port_from_rule(rule)
	-- trust me, this works
	return rule.x + 2 - rule.z + math.abs(rule.z)
end

-- count in which globalstep we are
local steptimer = 0
 -- count modulo 2^32, to prevent the timer becoming unprecise over time
local steptimer_max = 2^32
-- tells whether we are currently in the process of calling globalsteps
local currently_in_globalstep = false
minetest.after(0, function()
	-- increment the steptimer before all other globalsteps have run
	table.insert(minetest.registered_globalsteps, 1, function(dtime)
		steptimer = (steptimer + 1) % steptimer_max
		currently_in_globalstep = true
	end)
	table.insert(minetest.registered_globalsteps, function(dtime)
		currently_in_globalstep = false
	end)
end)

-- meta in meseconometer node:
-- "version": always 1
-- "activate_port": activation port (1-4)
-- "steptimer_start": value of steptimer for step 0
-- "event_index": number of stored events = index of last event
-- "event_nr"..i: a stored event; i is in [1;event_index]
--
-- events are stored each as json of this table: {step, port_abcd, event}
-- step: the step of the event relative to steptimer_start
--       has prefix "a" if not in a globalstep (abrev. for "after")
-- port_abcd: the port (A-D) of the event
-- event: name of the event

-- removes all stored events and sets the timer 0 to now
local function reset_meseconometer(pos, meta)
	local event_count = meta:get_int("event_index")
	for i = 1, event_count do
		meta:set_string("event_nr"..i, "")
	end
	meta:set_int("event_index", 0)
	meta:set_int("steptimer_start", steptimer)
end

-- stores a new event in a meseconometer
-- @param meta: meta of the meseconometer
-- @param port_abcd: port (A-D) of the event
-- @param event: name of the event
local function save_event(meta, port_abcd, event)
	-- get the index and increment it
	local index = meta:get_int("event_index") or 0
	index = index + 1
	meta:set_int("event_index", index)
	-- save the event
	local step = (steptimer + steptimer_max - meta:get_int("steptimer_start")) % steptimer_max
	if not currently_in_globalstep then
		step = "a"..step
	end
	meta:set_string("event_nr"..index, minetest.write_json({
		step, port_abcd, event
	}))
end

-- show the main formspec, eg. when rightclicked
-- @param pos: pos of meseconometer
-- @param playername: player to show the formspec to
local function show_formspec_main(pos, playername)
	local meta = minetest.get_meta(pos)

	local act_port = meta:get_int("activate_port")
	if not act_port or not (act_port >= 1 and act_port <= 4) then
		act_port = 1
		meta:set_int("activate_port", 1)
	end

	local event_count = meta:get_int("event_index")
	if not event_count or not (event_count >= 1) then
		event_count = 0
	end

	-- get all events and concat to table_cells
	-- if no events, 2nd row will be - - -
	local table_cells = {"-,-,-"}

	if meta:get_int("version") == 1 then
		for i = 1, event_count do
			local cell = minetest.parse_json(meta:get_string("event_nr"..i))
			if type(cell) == "table" then
				table_cells[(i - 1) * 3 + 1] = minetest.formspec_escape(cell[1])
				table_cells[(i - 1) * 3 + 2] = minetest.formspec_escape(cell[2])
				table_cells[(i - 1) * 3 + 3] = minetest.formspec_escape(cell[3])
			else
				table_cells[(i - 1) * 3 + 1] = "error"
				table_cells[(i - 1) * 3 + 2] = "error"
				table_cells[(i - 1) * 3 + 3] = "error"
			end
		end
	else
		table_cells = {"<can not show data from other version>"}
	end

	table_cells = table.concat(table_cells, ",")

	minetest.show_formspec(playername, "meseconometer:fs",
		"formspec_version[3]"..
		"size[10,10]"..
		"button[7.5,7.75;2,0.75;btn_raw;Get Raw Data]".. -- todo
		"button[7.5,6.75;2,0.75;btn_info;?]".. -- todo
		"button_exit[7.5,8.75;2,0.75;btn_close;Close]"..
		"label[7.5,1.25;Activation Port:]"..
		"dropdown[7.5,1.5;2,0.5;activate_port;A,B,C,D;"..act_port.."]"..
		"label[0.5,0.75;Meassured Events:]"..
		"tablecolumns[text,align=right,tooltip=\"a<number>\" means that the "..
			"event happened AFTER the step;text,align=center;text]"..
		"table[0.5,1;6.5,8.5;table;Step,Port,Event,"..table_cells..";]"
	)
	open_formspecs[playername] = vector.new(pos)
end

-- show the info formspec
local function show_formspec_info(pos, playername)
	minetest.show_formspec(playername, "meseconometer:fs_info",
		"formspec_version[3]"..
		"size[10,10]"..
		"button[7.5,7.75;2,0.75;btn_back;Back]"..
		"button_exit[7.5,8.75;2,0.75;btn_close;Close]"..
		"label[0.5,0.75;Information:]"..
		"table[0.5,1;6.5,8.5;table;"..
			"Events will only be saved if the activation port is,activated via mesecons.,"..
			"Times are in globalsteps."..
		";]"
	)

	open_formspecs[playername] = vector.new(pos)
end

-- handle foemspec events
local function handle_formspec_main(pos, playername, fields)
	local act_port = abcd[fields.activate_port]
	if act_port then
		local meta = minetest.get_meta(pos)
		meta:set_int("activate_port", act_port)
	end

	if fields.btn_info then
		show_formspec_info(pos, playername)
	end
end

local function handle_formspec_info(pos, playername, fields)
	if fields.btn_back then
		show_formspec_main(pos, playername)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if type(formname) ~= "string" or formname:sub(1, 16) ~= "meseconometer:fs" then
		return
	end

	if not player or not player:is_player() then
		return true
	end
	local playername = player:get_player_name()

	local pos = open_formspecs[playername]
	if not pos then
		return true
	elseif fields.quit then
		open_formspecs[playername] = nil
	end

	if formname == "meseconometer:fs" then
		handle_formspec_main(pos, playername, fields)
	elseif formname == "meseconometer:fs_info" then
		handle_formspec_info(pos, playername, fields)
	end

	return true
end)

minetest.register_on_leaveplayer(function(player)
	if player and player:is_player() then
		open_formspecs[player:get_player_name()] = nil
	end
end)

mesecon.register_node("meseconometer:meseconometer", {
	description = "Meseconometer",
	inventory_image = "meseconometer_meseconometer_top.png",
	drawtype = "nodebox",
	paramtype = "light",
	is_ground_content = false,
	node_box = {type = "fixed", fixed = {
		-- (created with nodebox creator mod)
		{-0.5, -0.5, -0.5, 0.5, -7/16, 0.5},     -- bottom plate
		{-1/4, -7/16, -3/16, 1/4, -3/8, 3/16},   -- middle cross
		{-3/16, -7/16, -1/4, 3/16, -3/8, 1/4},
		{-7/16, -7/16, -7/16, -1/4, -3/8, -1/4}, -- other decorations
		{-7/16, -7/16, 1/4, -1/4, -3/8, 7/16},
		{1/4, -7/16, -7/16, 7/16, -3/8, -1/4},
		{1/4, -7/16, 1/4, 7/16, -3/8, 7/16},
	}},
	selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -3/8, 0.5}},
	collision_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -3/8, 0.5}},
	sounds = default.node_sound_stone_defaults(),

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		-- open the formspec
		if not clicker or not clicker:is_player() then
			return
		end
		local playername = clicker:get_player_name()

		show_formspec_main(pos, playername)

		return itemstack
	end,

	on_blast = function()
		-- node shall be tnt resistant
	end,
}, {
	tiles = {
		"meseconometer_meseconometer_top.png",
		"jeija_microcontroller_bottom.png",
		"meseconometer_meseconometer_sides.png",
		"meseconometer_meseconometer_sides.png",
		"meseconometer_meseconometer_sides.png",
		"meseconometer_meseconometer_sides.png",
	},
	groups = {dig_immediate = 2, mesecon = 3},
	mesecons = {
		effector = {
			rules = mesecon.rules.flat,
			action_on = function(pos, node, rule)
				local port = get_port_from_rule(rule)
				local meta = minetest.get_meta(pos)
				if port ~= meta:get_int("activate_port") then
					return
				end

				-- activate the meseconometer
				reset_meseconometer(pos, meta)
				node.name = "meseconometer:meseconometer_on"
				minetest.swap_node(pos, node)

				-- save the activation event
				save_event(meta, abcd[port], "on")
			end
		}
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("version", 1)
		meta:set_int("activate_port", 1)
	end,
}, {
	tiles = {
		{name = "meseconometer_meseconometer_top_animated.png", animation = {
			type = "vertical_frames", aspect_w = 32, aspect_h = 32, length = 1.0,
		}},
		"jeija_microcontroller_bottom.png",
		"meseconometer_meseconometer_sides.png",
		"meseconometer_meseconometer_sides.png",
		"meseconometer_meseconometer_sides.png",
		"meseconometer_meseconometer_sides.png",
	},
	groups = {dig_immediate = 2, mesecon = 3, not_in_creative_inventory = 1},
	mesecons = {
		effector = {
			rules = mesecon.rules.flat,
			action_change = function(pos, node, rule, newstate)
				-- get and check the port
				local port = get_port_from_rule(rule)
				local port_abcd = abcd[port]
				if not port_abcd then
					return
				end
				-- save the event in meta
				local meta = minetest.get_meta(pos)
				save_event(meta, port_abcd, newstate)

				-- maybe deactivate the meseconometer
				if newstate ~= "off" or port ~= meta:get_int("activate_port") then
					return
				end
				-- yes
				-- replace the node
				node.name = "meseconometer:meseconometer_off"
				minetest.swap_node(pos, node)
			end,
		}
	},
	on_punch = function(pos, node, puncher, pointed_thing)
		-- save punch event in meta
		save_event(minetest.get_meta(pos), "-", "punch")
	end,
	on_construct = function(pos)
		minetest.log("warning", "Warning: meseconometer:meseconometer_on was constructed")
	end,
})
