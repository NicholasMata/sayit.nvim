local M = {}

function M.check()
	local health = vim.health
	if not health then
		local legacy = require("health")
		health = {
			start = legacy.report_start,
			ok = legacy.report_ok,
			warn = legacy.report_warn,
			error = legacy.report_error,
		}
	end
	health.start("sayit.nvim")

	if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
		health.ok("running on macOS")
	else
		health.error("sayit.nvim requires macOS")
	end

	if vim.fn.executable("say") == 1 then
		health.ok("`say` is executable")
	elseif vim.fn.executable("osascript") == 1 then
		health.warn("`say` was not found; using the osascript fallback")
	else
		health.error("neither `say` nor `osascript` is executable")
	end

	if vim.fn.has("nvim-0.9") == 1 then
		health.ok("Neovim 0.9 or newer")
	else
		health.error("Neovim 0.9 or newer is required")
	end
end

return M
