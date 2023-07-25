local cache = require("ltex-utils.cache")
local Config = require("ltex-utils.config")
local ltex_lsp = require("ltex-utils.ltex_lsp")
local settings_io = require("ltex-utils.settings_io")
local table_utils = require("ltex-utils.table_utils")

---@class LTeXUtils.words_cache : LTeXUtils.cache
---@field langs string[]
local M = cache:new()

---@type table<integer|string, integer|string>
local severities = vim.diagnostic.severity

---Updates LTeX LSP server with modified dictionaries. Saves modified
---dictionaries to respective files.
---@param bufnr integer
---@return boolean
---@return string|nil # Error string if problem occured
function M:apply_cache(bufnr)
	if not self.update_flag then
		return false, "Update flag set to false"
	end

	---@type table|nil
	local client = ltex_lsp.get_ltex(bufnr)
	if not client then
		return false, "No active LTeX LSP server"
	end

	-- initialise dictionaries
	---@type table<string, string[]>
	local dicts = {}
	for _, lang in ipairs(self.langs) do
		dicts[lang] = {}
	end

	-- we can't use `pairs(...)` because it doesn't guarantee the order
	---@type integer
	local n = table_utils.max_index(self.data)
	for i = 1, n do
		---@type Telescope.entry
		local entry = self.data[i]
		if entry then
			---@type string, string
			local lang, word = self.selection_to_lang_rule(entry)
			table.insert(dicts[lang], word)
		end
	end
	client.config.settings.ltex[self.setting_cfg] = dicts

	-- send updated settings to LSP server
	client.notify("workspace/didChangeConfiguration", client.config.settings)

	for lang, dict in pairs(dicts) do
		---@type string
		local filename = Config.dictionary.path ..
											Config.dictionary.filename(lang)
		settings_io.write(filename, table.concat(dict, "\n"))
		if Config.dictionary.use_vim_dict then
			vim.api.nvim_cmd({
				cmd = "mkspell",
				bang = true,
				args = { filename },
			}, { false })
		end
	end

	-- clean up cache for later reuse
	self.data = nil
	self.update_flag = false
	self.setting_cfg = nil
	self.langs = nil

	return true
end

---Reads saved dictionary files and adds them to the cache
---@param self LTeXUtils.words_cache
---@param bufnr integer
---@param settings table<string, string[]>
local function add_saved_dicts(self, bufnr, settings)
	self.langs = vim.tbl_keys(settings)
	---@type string
	local filename = vim.api.nvim_buf_get_name(bufnr)
	---@type table<string, string[]>
	local saved_dicts = {}
	saved_dicts = settings_io.load_dictionaries(self.langs)

	for lang, dict in pairs(saved_dicts) do
		for _, word in ipairs(dict) do
			---@type string
			local text = self.lang_rule_to_str(lang, word)
			---@type Telescope.entry
			local entry = self.data[text]
			if entry then
				if entry.type == severities[1] then
					---@cast severities table<integer, string>
					entry.type = severities[3]
				end
			else
				self.data[text] = {
					bufnr = bufnr,
					filename = filename,
					lnum = 1,
					col = 1,
					text = text,
					type = severities[2],
				}
			end
		end
	end
end

---Initialises the cache by loading server dictionaries and saved dictionaries
---from disk.
---@param telescope_cb function() Callback function to open Telescope window
---@param _ any This parameter is used for the other caches, but ignored here
---@return boolean # Success?
---@return string|nil # Error string
function M:initialise_rules(telescope_cb, _)
	---@type integer
	local bufnr = vim.api.nvim_get_current_buf()
	---@type table|nil
	local client = ltex_lsp.get_ltex(bufnr)
	if not client then return false, "No active LTeX LSP server" end
	-- use local variable to safe lookup costs
	---@type string
	local setting_cfg = self.setting_cfg

	-- get server settings
	---@type table|nil, string|nil
	local settings, stgs_err = ltex_lsp.get_settings(client, setting_cfg)
	if not settings then
		return false, stgs_err or ("Server has no settings: " .. setting_cfg)
	end

	-- initialise words table with server settings
	self.data = {}; self:extract_rules(settings, bufnr)

	add_saved_dicts(self, bufnr, settings)

	-- finalise list and show Telescope window
	self:sorted_rules_list(); telescope_cb()

	return true
end

return M
