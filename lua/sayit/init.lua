local M = {}

local defaults = {
	voice = nil,
	rate = nil,
	exit_visual = true,
	notify = false,
	mappings = {
		normal = "<leader>v",
		visual = "<leader>v",
		stop = false,
		operator = false,
	},
}

local config = vim.deepcopy(defaults)
local state = {
	handle = nil,
	job_id = nil,
	backend = nil,
	generation = 0,
}
local configured_mappings = {}

local function notify(message, level)
	if config.notify or level >= vim.log.levels.WARN then
		vim.notify("sayit.nvim: " .. message, level)
	end
end

local function executable(command)
	return vim.fn.executable(command) == 1
end

local function clear(generation)
	if generation ~= state.generation then
		return false
	end
	state.handle = nil
	state.job_id = nil
	state.backend = nil
	return true
end

local function normalize_text(text)
	if type(text) ~= "string" then
		return nil
	end
	if text:match("^%s*$") then
		return nil
	end
	return text
end

local function build_command(text)
	if executable("say") then
		local command = { "say" }
		if config.voice and config.voice ~= "" then
			vim.list_extend(command, { "-v", config.voice })
		end
		if config.rate then
			vim.list_extend(command, { "-r", tostring(config.rate) })
		end
		table.insert(command, text)
		return command
	end

	if executable("osascript") then
		local script = "on run argv\nsay item 1 of argv"
		local args = { text }
		if config.voice and config.voice ~= "" then
			script = script .. " using item 2 of argv"
			table.insert(args, config.voice)
		end
		if config.rate then
			script = script .. " speaking rate (item " .. (#args + 1) .. " of argv as integer)"
			table.insert(args, tostring(config.rate))
		end
		script = script .. "\nend run"
		local command = { "osascript", "-e", script, "--" }
		vim.list_extend(command, args)
		return command
	end

	return nil
end

function M.is_speaking()
	return state.handle ~= nil or state.job_id ~= nil
end

function M.stop()
	if not M.is_speaking() then
		return false
	end

	state.generation = state.generation + 1
	local stopped = false
	if state.backend == "system" and state.handle then
		stopped = pcall(state.handle.kill, state.handle, 15)
	elseif state.backend == "jobstart" and state.job_id then
		stopped = vim.fn.jobstop(state.job_id) == 1
	end
	clear(state.generation)
	return stopped
end

function M.start(text)
	text = normalize_text(text)
	if not text then
		notify("no text to speak", vim.log.levels.WARN)
		return false
	end

	if M.is_speaking() then
		M.stop()
	end

	local command = build_command(text)
	if not command then
		notify("macOS `say` or `osascript` is required", vim.log.levels.ERROR)
		return false
	end

	state.generation = state.generation + 1
	local generation = state.generation

	if vim.system then
		local handle
		handle = vim.system(command, {}, function(result)
			vim.schedule(function()
				local current = clear(generation)
				if current and result.code ~= 0 and result.code ~= 15 then
					notify("speech process failed with exit code " .. result.code, vim.log.levels.ERROR)
				end
			end)
		end)
		state.handle = handle
		state.backend = "system"
	else
		local job_id = vim.fn.jobstart(command, {
			on_exit = function(_, code)
				vim.schedule(function()
					local current = clear(generation)
					if current and code ~= 0 and code ~= 143 then
						notify("speech process failed with exit code " .. code, vim.log.levels.ERROR)
					end
				end)
			end,
		})
		if job_id <= 0 then
			notify("could not start the speech process", vim.log.levels.ERROR)
			return false
		end
		state.job_id = job_id
		state.backend = "jobstart"
	end

	notify("speaking", vim.log.levels.INFO)
	return true
end

function M.toggle(text)
	if M.is_speaking() then
		M.stop()
		notify("stopped", vim.log.levels.INFO)
		return false
	end
	return M.start(text)
end

M.toggle_say = M.toggle

local function get_region_text(bufnr, start_pos, end_pos, regtype)
	local exclusive = vim.o.selection == "exclusive"
	if vim.fn.exists("*getregion") == 1 then
		return table.concat(
			vim.fn.getregion(start_pos, end_pos, {
				type = regtype,
				exclusive = exclusive,
			}),
			"\n"
		)
	end

	local start_zero = { start_pos[2] - 1, start_pos[3] - 1 }
	local end_zero = { end_pos[2] - 1, end_pos[3] - 1 }
	if regtype:byte() == 22 and #regtype == 1 then
		local width = math.abs(vim.fn.virtcol(start_pos) - vim.fn.virtcol(end_pos))
		if not exclusive then
			width = width + 1
		end
		regtype = regtype .. width
	end

	local region = vim.region(bufnr, start_zero, end_zero, regtype, not exclusive)
	local result = {}
	for row = math.min(start_zero[1], end_zero[1]), math.max(start_zero[1], end_zero[1]) do
		local columns = region[row]
		if columns then
			local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
			local finish = columns[2] == -1 and #line or math.min(columns[2], #line)
			table.insert(result, string.sub(line, columns[1] + 1, finish))
		end
	end
	return table.concat(result, "\n")
end

function M.get_visual_selection()
	return get_region_text(0, vim.fn.getpos("v"), vim.fn.getpos("."), vim.fn.mode())
end

function M.say(text)
	return M.start(text)
end

function M.say_word()
	return M.toggle(vim.fn.expand("<cword>"))
end

function M.say_line()
	return M.toggle(vim.api.nvim_get_current_line())
end

function M.say_buffer()
	return M.toggle(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"))
end

function M.say_paragraph()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local first, last = row, row
	while first > 1 and not lines[first - 1]:match("^%s*$") do
		first = first - 1
	end
	while last < #lines and not lines[last + 1]:match("^%s*$") do
		last = last + 1
	end
	local paragraph = {}
	for index = first, last do
		table.insert(paragraph, lines[index])
	end
	return M.toggle(table.concat(paragraph, "\n"))
end

function M.say_visual(exit_visual)
	local text = M.get_visual_selection()
	if exit_visual == nil then
		exit_visual = config.exit_visual
	end
	if exit_visual then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	end
	return M.toggle(text)
end

function M.operator(type)
	if not type then
		vim.go.operatorfunc = "v:lua.require'sayit'.operator"
		return "g@"
	end
	local regtype = type == "line" and "V" or type == "block" and "\022" or "v"
	return M.toggle(get_region_text(0, vim.fn.getpos("'["), vim.fn.getpos("']"), regtype))
end

local function create_commands()
	local command_opts = { force = true }
	vim.api.nvim_create_user_command("SayWord", M.say_word, command_opts)
	vim.api.nvim_create_user_command("SayLine", M.say_line, command_opts)
	vim.api.nvim_create_user_command("SayParagraph", M.say_paragraph, command_opts)
	vim.api.nvim_create_user_command("SayBuffer", M.say_buffer, command_opts)
	vim.api.nvim_create_user_command("SaySelection", function(opts)
		if opts.range > 0 then
			local text = table.concat(vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false), "\n")
			M.toggle(text)
		else
			M.say_visual()
		end
	end, { range = true, force = true })
	vim.api.nvim_create_user_command("SayStart", function(opts)
		M.start(opts.args)
	end, { nargs = "+", force = true })
	vim.api.nvim_create_user_command("SayStop", M.stop, command_opts)
	vim.api.nvim_create_user_command("SayToggle", function(opts)
		M.toggle(opts.args ~= "" and opts.args or vim.fn.expand("<cword>"))
	end, { nargs = "*", force = true })
	vim.api.nvim_create_user_command("SayVoices", function()
		if not executable("say") then
			notify("`say` is required to list voices", vim.log.levels.ERROR)
			return
		end
		vim.cmd.new()
		vim.bo.buftype = "nofile"
		vim.bo.bufhidden = "wipe"
		vim.bo.swapfile = false
		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.systemlist({ "say", "-v", "?" }))
		vim.bo.modifiable = false
	end, { force = true })
end

local function set_mappings()
	for _, mapping in ipairs(configured_mappings) do
		pcall(vim.keymap.del, mapping.mode, mapping.lhs)
	end
	configured_mappings = {}

	vim.keymap.set("n", "<Plug>(SayItWord)", M.say_word, { desc = "Speak word (toggle)" })
	vim.keymap.set("x", "<Plug>(SayItSelection)", M.say_visual, { desc = "Speak selection (toggle)" })
	vim.keymap.set("n", "<Plug>(SayItStop)", M.stop, { desc = "Stop speaking" })
	vim.keymap.set("n", "<Plug>(SayItOperator)", M.operator, { expr = true, desc = "Speak motion" })

	if config.mappings.normal then
		vim.keymap.set("n", config.mappings.normal, M.say_word, { desc = "Speak word (toggle)", silent = true })
		table.insert(configured_mappings, { mode = "n", lhs = config.mappings.normal })
	end
	if config.mappings.visual then
		vim.keymap.set("x", config.mappings.visual, M.say_visual, { desc = "Speak selection (toggle)", silent = true })
		table.insert(configured_mappings, { mode = "x", lhs = config.mappings.visual })
	end
	if config.mappings.stop then
		vim.keymap.set({ "n", "x" }, config.mappings.stop, M.stop, { desc = "Stop speaking", silent = true })
		table.insert(configured_mappings, { mode = "n", lhs = config.mappings.stop })
		table.insert(configured_mappings, { mode = "x", lhs = config.mappings.stop })
	end
	if config.mappings.operator then
		vim.keymap.set("n", config.mappings.operator, M.operator, { expr = true, desc = "Speak motion", silent = true })
		table.insert(configured_mappings, { mode = "n", lhs = config.mappings.operator })
	end
end

function M.setup(opts)
	local new_config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	if new_config.rate ~= nil and (type(new_config.rate) ~= "number" or new_config.rate <= 0) then
		error("sayit.nvim: `rate` must be a positive number")
	end
	if new_config.voice ~= nil and type(new_config.voice) ~= "string" then
		error("sayit.nvim: `voice` must be a string")
	end
	config = new_config
	create_commands()
	set_mappings()
	return M
end

M._build_command = build_command
M._get_region_text = get_region_text
M._state = state

return M
