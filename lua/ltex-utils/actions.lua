local M = {}

local Config = require("ltex-utils.config")
local ltex_lsp = require("ltex-utils.ltex_lsp")
local settings_io = require("ltex-utils.settings_io")
local table_utils = require("ltex-utils.table_utils")

---Generates a code action handler updating LSP server settings with 'cmd_cfg'
---and 'setting_cfg' fields.
---@param cmd_cfg string The key for the code action command
---@param setting_cfg string The key of the server settings
---@return function () # The code action handler
function M.new_handler(cmd_cfg, setting_cfg)
	return function (command)
		local client = ltex_lsp.get_ltex()
		-- if no active ltex client abort
		if not client then return end

		local settings = ltex_lsp.get_settings_or_init(client, setting_cfg)

		for lang, rules in pairs(command.arguments[1][cmd_cfg]) do
			table_utils.extend_or_init(settings[setting_cfg], lang, rules)
		end

		client.notify(
			"workspace/didChangeConfiguration",
			client.config.settings
		)
	end
end

--[[ 
	Writes the current LTeX (LaTeX) Language Server Protocol (LSP)
	settings to a JSON file.

	This function retrieves the active LTeX LSP client and its settings,
	ensuring an active client is found. It saves the current dictionaries
	and their languages, hidden false positives, and disabled rules. The final
	settings are written to a JSON file, named based on the current file and
	located in its parent directory.

	No return value.

	Usage example:
		M.write_ltex_to_file()
--]]
---comment
---@param cached_dict_changes any
function M.write_ltex_to_file(cached_dict_changes)
	local client = ltex_lsp.get_ltex()
	-- if no active ltex client abort
	if not client then
		vim.notify("No active ltex client found", vim.log.levels.ERROR)
		return
	end

	-- Use local variables to reduce table lookup cost
	local settings = client.config.settings.ltex
	if not settings then return end

	local langs
	-- save dictionaries; update them if necessary
	if settings.dictionary then
		settings_io.ensure_folder_exists(Config.dict_path)
		langs = settings_io.update_dictionary_files(
			Config.dict_path,
			settings.dictionary,
			cached_dict_changes
		)
	end

	local settings_to_save = {}

	for _, settings_cfg in ipairs({ "hiddenFalsePositives", "disabledRules" }) do
		if settings[settings_cfg] then
			settings_to_save[settings_cfg] = settings[settings_cfg]
			langs = table_utils.merge_lists_unique(
				langs,
				vim.tbl_keys(settings[settings_cfg])
			)
		end
	end

	settings_to_save.langs = langs or nil

	if settings_to_save then
		local head = vim.fn.expand("%:p:h") .. "/" .. vim.fn.expand("%:t:r")
											.. "_" .. vim.fn.expand("%:e")
		settings_io.write_settings(head .. "_ltex.json", settings_to_save)
	end
end

--[[ 
	Loads LTeX (LaTeX) Language Server Protocol (LSP) settings from a JSON file

	The function retrieves the active LTeX LSP client and reads the settings
	(hidden false positives, disabled rules, and specific language
	dictionaries) file associated with the current buffer. If a settings file
	doesn't exist for the current file, an error is returned. After loading
	the settings, the function notifies the workspace
	about the change in configuration.

	@return true if successful, false otherwise.
	@return nil if successful, error message otherwise.

	Usage example:
		local success, err = M.load_ltex_from_file()
		if not success then
			print("Error loading settings: ", err)
		end
--]]
function M.load_ltex_from_file()
	local client = ltex_lsp.get_ltex()
	-- if no active ltex client abort
	if not client then
		return false, "No active ltex client found"
	end

	local head = vim.fn.expand("%:p:h") .. "/" .. vim.fn.expand("%:t:r")
										.. "_" .. vim.fn.expand("%:e")

	local saved_settings, err = settings_io.read_settings(head .. "_ltex.json")
	-- return error; we get here when opening a fresh tex-file
	-- without an existing config.
	if not saved_settings then
		return false, err
	end

	local client_settings = client.config.settings.ltex
	client_settings.hiddenFalsePositives = saved_settings.hiddenFalsePositives or nil
	client_settings.disabledRules = saved_settings.disabledRules or nil

	if saved_settings.langs then
		if not client_settings.dictionary and #saved_settings.langs > 0 then
			client_settings.dictionary = {}
		end
		-- read the required dictionaries
		settings_io.load_dictionaries(
			Config.dict_path,
			saved_settings.langs,
			client_settings.dictionary
		)
	end

	client.notify(
		"workspace/didChangeConfiguration",
		client.config.settings
	)
	return true, nil
end

return M
