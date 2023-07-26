local M = {}

local builtin = require("ltex-utils.builtin")
local Config = require("ltex-utils.config")
local ltex = require("ltex-utils.actions")
local rule_ui = require("ltex-utils.rule_ui")

-- Writes current LTeX LSP server settings to file
---@return string|nil  # error message if writing to file fails
local function on_exit()
	---@type integer
	local bufnr = vim.api.nvim_get_current_buf()

	-- delete current buffer from windows list
	builtin.wins[bufnr] = nil

	---@type boolean, string|nil
	local ok, err = pcall(ltex.write_ltex_to_file)

	if not ok then
		vim.notify("Error on exit: " .. vim.inspect(err), vim.log.levels.ERROR)
		return err
	end
end

---Set up autocommands in respective augroups (e.g., 'LTeXUtils')
local function autocmd_ltex()
	---@type integer
	local augroup_id = vim.api.nvim_create_augroup(
		"LTeXUtils",
		{ clear = true }
	)

	vim.api.nvim_create_autocmd(
		{ "BufUnload" },
		{
			pattern = { "*.tex", "*.md" },
			callback = on_exit,
			group = augroup_id,
			desc = "save ltex settings to files",
		}
	)

	vim.api.nvim_create_autocmd(
		{ "BufEnter"},
		{
			pattern = { "*.tex", "*.md" },
			callback = function ()
				---@type integer
				local bufnr = vim.api.nvim_get_current_buf()
				---@type LTeXUtils.UI|nil
				local wins = builtin.wins[bufnr]
				if wins ~= nil and wins.cache ~= nil then
					wins.cache:apply_cache(bufnr)
				end
				vim.diagnostic.show()
			end,
			group = augroup_id,
			desc = "apply cached rule changes",
		}
	)

	vim.api.nvim_create_autocmd("User", {
		pattern = "TelescopePreviewerLoaded",
		callback = function(args)
			---@type string
			local extension = args.data.bufname:match("%.(%w+)$")
			if extension == "md" or extension == "tex" then
				vim.wo.number = Config.rule_ui.previewer_line_number
				vim.wo.wrap = Config.rule_ui.previewer_wrap
			end
		end,
	})
end

---Called when an LTeX LSP server is attached. Adds custom LSP commands.
---Creates auto commands. Loads saved server settings.
---@param bufnr integer
---@return string|nil # error message if file exists but can't be loaded
function M.on_attach(bufnr)
	-- Use local variables to reduce table lookup cost
	---@type table
	local cmds = vim.lsp.commands

	---@type function(table)
	local dict_handler = ltex.new_handler("words", "dictionary")
	-- Add custom LSP commands for the ltex language server
	cmds["_ltex.addToDictionary"] = Config.dictionary.use_vim_dict and
	function(command)
		dict_handler(command)
		-- save previously used spelllang for current buffer
--		local spelllang = vim.api.nvim_buf_get_option(0, "spelllang")
		local spellfile = vim.api.nvim_buf_get_option(0, "spellfile")
		for lang, words in pairs(command.arguments[1]["words"]) do
			vim.api.nvim_buf_set_option(0, "spellfile", Config.dictionary.path
										.. Config.dictionary.filename(lang))
--			vim.api.nvim_buf_set_option(0, "spelllang",
--												string.match(lang, "^(%a+)-"))
			for _, word in ipairs(words) do
				vim.api.nvim_cmd({
					cmd = "spellgood",
					args = { word, },
				}, { output = Config.dictionary.no_vim_output, })
			end
		end
		-- restore spellfile and spelllang
		vim.api.nvim_buf_set_option(0, "spellfile", spellfile)
--		vim.api.nvim_buf_set_option(0, "spelllang", spelllang)
	end or dict_handler

	cmds["_ltex.hideFalsePositives"] = ltex.new_handler(
		"falsePositives",
		"hiddenFalsePositives"
	)
	cmds["_ltex.disableRules"] = ltex.new_handler(
		"ruleIds",
		"disabledRules"
	)

	-- create autocommands
	autocmd_ltex()

	-- create ui instance for modifying rules; guarantees that
	-- managing rules in different buffers work as expected
	builtin.wins[bufnr] = rule_ui.new()

	-- load server settings if they exist
	---@type boolean, string|nil
	local ok, err = ltex.load_ltex_from_file()
	if not ok and err then
		-- if settings file does not exist yet, inform user and
		-- continue with emtpy settings
		if string.sub(err, 1, 6) == 'ENOENT' then
			vim.notify(
				"No existing settings file yet. " ..
				"Will be generated automatically when file closed.",
				vim.log.levels.INFO
			)
		else
			vim.notify(
				"Error on attach: " .. vim.inspect(err),
				vim.log.levels.ERROR
			)
			return err
		end
	end
end

-- Sets up the module with user-defined options.
---@param opts? LTeXUtils.Config A table containing user-defined options.
function M.setup(opts)
	-- use custom options if provided
	Config.setup(opts)
end

return setmetatable(M, {
	__index = function(_, k)
		return require("ltex-utils.builtin")[k]
	end,
})
