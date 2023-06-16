local M = {}
local ltex = require("ltex-utils.actions")
local modify_rule = require("ltex-utils.modify_rule")

--- Writes current LTeX LSP server settings to a file on buffer unload.
--
-- @return string Returns an error message if writing to a file fails.
--                No return value on success.
--
local function on_exit()
	local ok, err = pcall(ltex.write_ltex_to_file)

	if not ok then
		print("Error on exit: ", err)
		return err
	end
end

--- Sets up autocommands for the LTeX plugin.
--
-- This function creates an augroup named 'LTeXUtils' and sets up two
-- autocommands:
-- 1. 'BufUnload': Triggers the `on_exit()` function whenever a `.tex` file is
--    unloaded. This saves the LTeX settings to a file.
-- 2. 'FileType': When a buffer of type 'tex' or 'plaintex' is opened, it sets
--    up two user commands:
--    - 'WriteLtexToFile': Saves the LTeX settings to a file.
--    - 'LoadLtexFromFile': Loads the LTeX settings from a file.
local function autocmd_ltex()
	local augroup_id = vim.api.nvim_create_augroup('LTeXUtils',
												   { clear = true })
	vim.api.nvim_create_autocmd(
		{ 'BufUnload' },
		{
			pattern = { '*.tex', '*.md' },
			callback = on_exit,
			group = augroup_id,
			desc = 'save ltex settings to files',
		}
	)
end

--- Called when an LTeX LSP server is attached.
-- 
-- This function does the following:
-- 1. Adds custom LSP commands for the ltex language server.
-- 2. Creates auto commands using the 'autocmd_ltex' function.
-- 3. Loads saved server settings from a file. If no settings file exists,
--    it informs the user and continues with empty settings.
-- 
-- @return If there is an error loading the settings file and the error is not
--         due to the file not existing, it returns the error message.
--
-- @usage This function is typically called automatically when an LTeX LSP
--        server is attached.
function M.on_attach()
	-- Use local variables to reduce table lookup cost
	local cmds = vim.lsp.commands
	-- Add custom LSP commands for the ltex language server
	cmds["_ltex.addToDictionary"] = ltex.new_handler(
		"words",
		"dictionary"
	)
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

	-- load server settings if they exist
	local ok, err = ltex.load_ltex_from_file()
	if not ok and err then
		-- if settings file does not exist yet, inform user and
		-- continue with emtpy settings
		if string.sub(err, 1, 6) == 'ENOENT' then
			print(
				"No existing settings file yet. " ..
				"Will be generated automatically when file closed.")
		else
			print("Error on attach: ", err)
			return err
		end
	end
end

--- Sets up the module with user-defined options.
-- 
-- @param opts A table containing user-defined options. Currently, only
--             'dict_path' is supported.
-- @usage
--     local ltex = require('ltex')
--     ltex.setup({dict_path = "/custom/dictionary/path"})
function M.setup(opts)
	-- use custom options if provided
	if opts then
		if opts.dict_path then
			ltex.dict_path = opts.dict_path
		end
		if opts.modify_rule_key then
			modify_rule.modify_rule_key = opts.modify_rule_key
		end
		if opts.delete_rule_key then
			modify_rule.delete_rule_key = opts.delete_rule_key
		end
		if opts.win_opts then
			modify_rule.opts = opts.win_opts
		end
	end

end

return M
