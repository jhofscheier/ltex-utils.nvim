local RuleUI = {}
RuleUI.__index = RuleUI

local Config = require("ltex-utils.config")
local ltex_lsp = require("ltex-utils.ltex_lsp")
local rule_cache = require("ltex-utils.rule_cache")
local rule_utils = require("ltex-utils.rule_utils")
-- Telescope
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local telescope_actions = require('telescope.actions')
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
-- Plenary
local popup = require("plenary.popup")

-- Constructor
function RuleUI.new()
	local self = setmetatable(
		{
			---rules list for telescope window
			---@type string[]
			rules = nil,
			update_rules = false,
			setting_cfg = nil,
			cache = rule_cache.new(),
		},
		RuleUI
	)
	return self
end

--- Transforms a selected text into language and rule pair.
--
-- @param selection The selected text which is in the format
--                  "lang, rule: sentence".
--
-- @return string, string The extracted language and the corresponding rule in JSON format.
local function selection_to_lang_rule(selection)
	-- Get selection text; varies based on diagnostic usage.
	local text = selection.text or selection.value.text
	local lang, rule, sentence
	lang, rule, sentence = text:match("^(.-)%s*,%s*(.-)%s*:%s*(.*)$")
	return lang, string.format(
		'{"rule":"%s","sentence":"%s"}',
		rule,
		sentence:gsub("\\", "\\\\")
	)
end

--- Modifies a rule in the LTeX LSP server settings and updates the LSP server.
--
-- @param source_bufnr The buffer number tied to the LSP server.
-- @param setting_cfg The settings configuration to modify (options:
--                    'hiddenFalsePositives', 'disabledRules', 'dictionary').
-- @param lang The language identifier (e.g., 'en-GB').
-- @param old_rule The rule to be replaced.
-- @return bool, string False and an error message if LSP client or language
--                      rules not found. No returns on success.
--
local function process_input(self, setting_cfg, use_diags, lang, selection)
	-- get bufnr of current active buffer
	local bufnr = vim.api.nvim_get_current_buf()
	local new_rule = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]

	self.rules[selection.index].text = rule_utils.lang_rule_to_str(
		lang,
		new_rule
	)
	self.rules[selection.index].type = vim.diagnostic.severity[4]

	-- don't update rules now
	self.update_rules = false

	-- close popup window; buffer will be automatically wiped
	local win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_close(win_id, true)

	-- open Telescope window again
	self:new_pick_rule_win(
		setting_cfg,
		use_diags,
		Config.rule_ui.telescope_opts
	)

	-- set flag to update rules at the next possibility
	self.update_rules = true
end

--- Creates a popup window with the rule selected from the active Telescope
--  window and sets a callback for modification.
--
-- @param bufnrs A table with 'source_bufnr' and 'prompt_bufnr', buffer numbers
--               for LSP server connection and Telescope window.
-- @param setting_cfg The settings configuration to modify the rule (e.g.,
--                    'hiddenFalsePositives', 'disabledRules', 'dictionary').
--
local function new_modify_rule_win(self, prompt_bufnr, setting_cfg, use_diags)
	local selection = action_state.get_selected_entry()
	local update_rules = self.update_rules

	-- don't update rules now as we need to close Telescope window
	-- and therefore we might jump into the source buffer for a moment
	self.update_rules = false
	telescope_actions.close(prompt_bufnr)

	local win_id = popup.create('', {
		border = true,
		line = math.floor(vim.o.lines / 2) - 2,
		col = math.floor(vim.o.columns / 2) - 40,
		width= 80,
		minheight = 6,
		maxheight = 20,
		enter = true,
	})

	local bufnr = vim.api.nvim_win_get_buf(win_id)

	vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
	-- Enable line wrapping
	vim.api.nvim_win_set_option(win_id, 'wrap', true)

	local lang, rule = selection_to_lang_rule(selection)

	-- Populate the buffer with the text of the rule
	vim.api.nvim_buf_set_lines(
		bufnr,
		0,
		-1,
		false,
		{ rule }
	)

	vim.keymap.set(
		{'i', 'n'},
		'<CR>',
		function()
			process_input(self, setting_cfg, use_diags, lang, selection)
		end,
		{ buffer = bufnr, noremap = false, silent = true }
	)

	-- set `update_rules` flag to previous value
	self.update_rules = update_rules
end

local function delete_entries(list, to_delete, iterator)
	to_delete = to_delete or {}
	iterator = iterator or ipairs

	local j = 1
	for i, entry in iterator(list) do
		if to_delete[i] then
			list[i] = nil
		else
			if i ~= j then
				list[j] = entry
				list[i] = nil
			end
			j = j + 1
		end
	end
end

local function cleanup_rules(self, prompt_bufnr, setting_cfg)
	local severities = vim.diagnostic.severity
	local made_changes = false
	local update_rules = self.update_rules

	-- don't update rules now; closing Telescope window
	-- might lead to jump into the source buffer
	self.update_rules = false
	telescope_actions.close(prompt_bufnr)

	local entries_to_delete = {}

	for i, entry in ipairs(self.rules) do
		if entry.type == severities[1] then
			entries_to_delete[i] = true
		else
			if i > 1 then
				delete_entries(self.rules, entries_to_delete)
				made_changes = true
			end
			break
		end
	end

	-- open Telescope window again
	self:new_pick_rule_win(setting_cfg, true, Config.rule_ui.telescope_opts)

	-- set `update_rules` flag to previous value
	self.update_rules = update_rules or made_changes
end

local function make_simple_entries(opts)
	opts = opts or {}

	return function(entry)
		local bufnr = entry.bufnr or vim.fn.bufnr()

		return {
			valid = true,
			value = entry,
			ordinal = entry.text or "",
			display = entry.text or "",
			bufnr = bufnr,
			lnum = entry.lnum or 0,
			col = entry.col or 0,
			type = entry.type or 1,
			filename = entry.filename or vim.api.nvim_buf_get_name(bufnr),
		}
	end
end

function RuleUI:new_telescope_win(opts, setting_cfg, use_diags)
	local pic = pickers.new(opts, {
		prompt_title = setting_cfg,
		default_text = "",
		finder = finders.new_table {
			results = self.rules,
			entry_maker = not use_diags and make_simple_entries(opts)
				or opts.entry_maker
				or make_entry.gen_from_diagnostics(opts),
		},
		previewer = use_diags and conf.qflist_previewer(opts) or nil,
		sorter = conf.prefilter_sorter {
			tag = "type",
			sorter = conf.generic_sorter(opts),
		},
		attach_mappings = function(_, map)
			local function map_modes_keys(modes_keys, func)
				for mode, keys in pairs(modes_keys) do
					for _, key in ipairs(keys) do
						map(mode, key, func)
					end
				end
			end

			-- set modify key (both modes)
			map_modes_keys({
				n = { Config.rule_ui.modify_rule_key },
				i = { Config.rule_ui.modify_rule_key },
			}, function (prompt_bufnr)
				new_modify_rule_win(self, prompt_bufnr, setting_cfg, use_diags)
			end)
			-- set delete key (normal mode only)
			map('n', Config.rule_ui.delete_rule_key, function(prompt_bufnr)
				local current_picker = action_state.get_current_picker(
					prompt_bufnr
				)
				current_picker:delete_selection(function(selection)
					self.rules[selection.index] = nil
					--table.remove(self.rules, selection.index)
					self.update_rules = true
					return true
				end)
			end)

			if use_diags then
				map('n',
					Config.rule_ui.cleanup_rules_key,
					function(prompt_bufnr)
						cleanup_rules(self, prompt_bufnr, setting_cfg)
				end)

				map('n', Config.rule_ui.goto_key, function(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					telescope_actions.close(prompt_bufnr)
					vim.diagnostic.show()

					local win = vim.api.nvim_get_current_win()

					vim.api.nvim_win_set_cursor(win, {
						selection.lnum,
						selection.col
					})
				end)
			end

			-- Ensure diagnostics are displayed after closing window
			map_modes_keys({
				n = { '<Esc>', 'q' },
			}, function(prompt_bufnr)
				telescope_actions.close(prompt_bufnr)
				vim.diagnostic.show()
			end)
			return true
		end
	}):find()
end

function RuleUI:update(bufnr)
	if not self.update_rules then
		return false, "Flag for update rules set to false"
	end

	local client = ltex_lsp.get_ltex(bufnr)
	if not client then
		return false, "No active LTeX LSP server"
	end

	local res = {}

	for _, selection in ipairs(self.rules) do
		if selection.type == "WARN" then
			break
		end
		local lang, rule = selection_to_lang_rule(selection )
		if not res[lang] then
			res[lang] = { rule }
		else
			table.insert(res[lang], rule)
		end
	end
	client.config.settings.ltex[self.setting_cfg] = res

	-- send updated settings to LSP server
	client.notify("workspace/didChangeConfiguration", client.config.settings)

	self.rules = nil
	self.update_rules = false
	self.setting_cfg = nil

	return true
end

--- Creates a Telescope window populated with rules from the LTeX LSP server's
--  specified settings configuration.
-- 
-- The function also assigns key mappings for modifying and deleting these
-- rules.
--
-- @param opts Optional parameters for pickers.new.
-- @param setting_cfg The settings configuration for retrieving and modifying
--                    rules.
-- @return bool, string Returns false and an error message if an LTeX LSP
--                      client is not found or if settings cannot be retrieved.
--                      Returns true on success.
--
function RuleUI:new_pick_rule_win(setting_cfg, use_diags, opts)
	opts = opts or {}

	-- do we have to collect rules first?
	if self.rules then
		self:new_telescope_win(opts, setting_cfg, use_diags)
		return
	end

	self.setting_cfg = setting_cfg

	local bufnr = vim.api.nvim_get_current_buf()
	local client = ltex_lsp.get_ltex(bufnr)
	if not client then return false, "No active LTeX LSP server" end

	-- get server settings
	local settings, setting_err = ltex_lsp.get_settings(client, setting_cfg)
	if not settings then
		return false, setting_err
			or ("Server has no settings: " .. setting_cfg)
	end

	self.rules = rule_utils.get_settings_rules(
		self.cache[setting_cfg],
		settings,
		bufnr
	)

	-- if no diags need to be included return table
	if not use_diags then
		self.rules = rule_utils.sorted_rules_list(self.rules)
		RuleUI:new_telescope_win(opts, setting_cfg, use_diags)
		return true
	end

	local process_action = function(err, actions)
		rule_utils.get_actions_callback(
			self.rules,
			bufnr,
			setting_cfg,
			err,
			actions
		)
	end

	local final_actions_callback = function()
		self.rules = rule_utils.sorted_rules_list(self.rules)
		self:new_telescope_win(opts, setting_cfg, true)
	end

	local old_handler = client.handlers["textDocument/publishDiagnostics"]

	-- Initialise empty diagnostics table and nil timer
	local accumulated_diagnostics = {}

	local final_diags_callback = function()
		-- restor handler again
		client.handlers["textDocument/publishDiagnostics"] = old_handler
		-- restore server settings
		client.config.settings.ltex[setting_cfg] = settings
		ltex_lsp.collect_diagnostics_actions(
			client,
			bufnr,
			accumulated_diagnostics,
			process_action,
			final_actions_callback
		)
	end

	-- Overwrite the diagnostics handler
	client.handlers["textDocument/publishDiagnostics"] =
		ltex_lsp.on_publish_diags(
			accumulated_diagnostics,
			final_diags_callback
		)

	-- reset hiddenFalsePositives to get all possible code actions
	client.config.settings.ltex[setting_cfg] = nil
	client.notify("workspace/didChangeConfiguration", client.config.settings)

	return true
end

return RuleUI
