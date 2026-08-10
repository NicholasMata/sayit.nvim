local failures = 0

local function test(name, callback)
	local ok, error_message = pcall(callback)
	if ok then
		io.stdout:write("ok - " .. name .. "\n")
	else
		failures = failures + 1
		io.stderr:write("not ok - " .. name .. "\n  " .. error_message .. "\n")
	end
end

local function equal(actual, expected)
	assert(vim.deep_equal(actual, expected), "expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

package.loaded.sayit = nil
local sayit = require("sayit")
sayit.setup({ mappings = { normal = false, visual = false, stop = false, operator = false } })

test("builds a say command with voice and rate", function()
	sayit.setup({
		voice = "Samantha",
		rate = 210,
		mappings = { normal = false, visual = false },
	})
	equal(sayit._build_command([[Hello "world"]]), { "say", "-v", "Samantha", "-r", "210", [[Hello "world"]] })
end)

test("toggle stops without restarting", function()
	local starts = 0
	local kills = 0
	local original_system = vim.system
	vim.system = function(_, _, _)
		starts = starts + 1
		return {
			pid = 42,
			kill = function()
				kills = kills + 1
			end,
		}
	end

	assert(sayit.toggle("first"))
	assert(not sayit.toggle("second"))
	equal(starts, 1)
	equal(kills, 1)
	vim.system = original_system
end)

test("completion clears only its own process", function()
	local callbacks = {}
	local original_system = vim.system
	vim.system = function(_, _, callback)
		table.insert(callbacks, callback)
		return { pid = #callbacks, kill = function() end }
	end

	assert(sayit.start("first"))
	assert(sayit.start("second"))
	callbacks[1]({ code = 0 })
	vim.wait(50)
	assert(sayit.is_speaking(), "a stale callback cleared the current process")
	callbacks[2]({ code = 0 })
	vim.wait(50)
	assert(not sayit.is_speaking(), "current process was not cleared")
	vim.system = original_system
end)

test("extracts single-line character selections", function()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abcdefghij" })
	local text = sayit._get_region_text(0, { 0, 1, 5, 0 }, { 0, 1, 7, 0 }, "v")
	equal(text, "efg")
end)

test("extracts backward multiline selections", function()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one two", "three", "four five" })
	local text = sayit._get_region_text(0, { 0, 3, 5, 0 }, { 0, 1, 5, 0 }, "v")
	equal(text, "two\nthree\nfour ")
end)

test("preserves unicode character boundaries", function()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "aé😊z" })
	local text = sayit._get_region_text(0, { 0, 1, 2, 0 }, { 0, 1, 2, 0 }, "v")
	equal(text, "é")
end)

test("extracts linewise selections", function()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
	local text = sayit._get_region_text(0, { 0, 1, 1, 0 }, { 0, 2, 1, 0 }, "V")
	equal(text, "one\ntwo")
end)

test("extracts blockwise selections", function()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abcdef", "uvwxyz" })
	local text = sayit._get_region_text(0, { 0, 1, 2, 0 }, { 0, 2, 4, 0 }, "\022")
	equal(text, "bcd\nvwx")
end)

test("validates rate", function()
	local ok = pcall(sayit.setup, { rate = 0 })
	assert(not ok)
end)

if failures > 0 then
	error(string.format("%d test(s) failed", failures))
end
