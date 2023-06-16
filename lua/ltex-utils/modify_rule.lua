local M = {}

local ltex_lsp = require("ltex-utils.ltex_lsp")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require('telescope.actions')
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local popup = require("plenary.popup")

--- Configuration for the plugin.
-- @module ltex-utils.modify_rule

-- @field modify_rule_key Key binding to trigger the rule modification action.
-- Defaults to the Enter key.
M.modify_rule_key = '<CR>'

-- @field delete_rule_key Key binding to trigger the rule deletion action.
-- Defaults to 'd'.
M.delete_rule_key = 'd'

M.opts = {}

M.modify_rule_callback = function () end


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
local function process_input(source_bufnr, setting_cfg, lang, old_rule)
	local client = ltex_lsp.get_ltex(source_bufnr)
	if not client then
		return false, "No active LTeX LSP server"
	end

	local lang_rules, err = ltex_lsp.get_settings_for_lang(
		client,
		setting_cfg,
		lang
	)
	if not lang_rules then
		return false, err
	end

	-- get bufnr of current active buffer
	local bufnr = vim.api.nvim_get_current_buf()
	local new_rule = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]

	for i, rule in ipairs(lang_rules) do
		if rule == old_rule then
			lang_rules[i] = new_rule
			break
		end
	end

	-- send updated settings to LSP server
	client.notify("workspace/didChangeConfiguration", client.config.settings)

	-- close popup window; buffer will be automatically wiped
	local win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_close(win_id, true)

	-- open Telescope window again
	M.new_pick_rule_win({}, setting_cfg)
end

--- Sets a keymap for a list of modes using `vim.api.nvim_buf_set_keymap`.
--
-- @param bufnr The buffer number to which the keymap will be set.
-- @param modes A list of modes (e.g., 'i', 'n') for which the keymap will
--              be set.
-- @param lhs The left-hand-side sequence of keys (e.g., '<CR>').
-- @param rhs The right-hand-side command that will be executed when `lhs`
--            is pressed.
-- @param opts Keymap options (e.g., {noremap = false, silent = true}).
--
local function set_keymap(bufnr, modes, lhs, rhs, opts)
  for _, mode in ipairs(modes) do
    vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
  end
end

--- Creates a popup window with the rule selected from the active Telescope
--  window and sets a callback for modification.
--
-- @param bufnrs A table with 'source_bufnr' and 'prompt_bufnr', buffer numbers
--               for LSP server connection and Telescope window.
-- @param setting_cfg The settings configuration to modify the rule (e.g.,
--                    'hiddenFalsePositives', 'disabledRules', 'dictionary').
--
local function new_modify_rule_win(bufnrs, setting_cfg)
	local selection = action_state.get_selected_entry()
	actions.close(bufnrs.prompt_bufnr)
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

	local lang, rule = string.match(
			selection[1],
			"^(.-): (.*)$"
		)

	M.modify_rule_callback = function ()
		process_input(bufnrs.source_bufnr, setting_cfg, lang, rule)
	end

	-- Populate the buffer with the text of the rule
	vim.api.nvim_buf_set_lines(
		bufnr,
		0,
		-1,
		false,
		{ rule }
	)

	set_keymap(
		bufnr,
		{'i', 'n'},
		'<CR>',
		":lua require('ltex-utils.modify_rule').modify_rule_callback()<CR>",
		{noremap = false, silent = true}
	)
end

--- Deletes a rule from the specified LSP server's settings configuration.
--
-- @param source_bufnr The buffer number to which the LSP server is connected.
-- @param setting_cfg The settings configuration from which the rule will
--                    be deleted.
-- @param selection The current rule and language selection in format:
--                  'language: rule'.
-- @return bool, string Returns false and an error message if an LSP client is
--                      not found, if language rules cannot be retrieved, or if
--                      rule deletion was successful.
--
local function delete_rule(source_bufnr, setting_cfg, selection)
	local client = ltex_lsp.get_ltex(source_bufnr)
	if not client then
		return false, "No active LTeX LSP sever"
	end

	local lang, rule_to_delete = selection.value:match('^(.-): (.*)$')

	local lang_rules, err = ltex_lsp.get_settings_for_lang(
		client,
		setting_cfg,
		lang
	)
	if not lang_rules then
		return false, err
	end

	for i, rule in ipairs(lang_rules) do
		if rule == rule_to_delete then
			table.remove(lang_rules, i)
			break
		end
	end

	-- send updated settings to LSP server
	client.notify("workspace/didChangeConfiguration", client.config.settings)

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
function M.new_pick_rule_win(opts, setting_cfg)
	opts = opts or {}
	local source_bufnr = vim.api.nvim_get_current_buf()

	local client = ltex_lsp.get_ltex()
	-- if no active ltex client abort
	if not client then
		return false, "No active LTeX server."
	end

	local settings, err = ltex_lsp.get_settings(client, setting_cfg)
	if not settings then
		return false, err
	end

	local lang_rules = {}
	for lang, rules in pairs(settings) do
		for _, rule in ipairs(rules) do
			table.insert(lang_rules, string.format("%s: %s", lang, rule))
		end
	end

	pickers.new(opts, {
		prompt_title = setting_cfg,
		default_text = "",
		finder = finders.new_table {
			results = lang_rules,
		},
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(_, map)
			local function map_both_modes(key, func)
				map('i', key, func)
				map('n', key, func)
			end

			-- set modify key
			map_both_modes(M.modify_rule_key, function (prompt_bufnr)
				new_modify_rule_win(
					{
						prompt_bufnr = prompt_bufnr,
						source_bufnr = source_bufnr,
					},
					setting_cfg
				)
			end)
			-- set delete key
			map_both_modes(M.delete_rule_key, function(prompt_bufnr)
				local current_picker = action_state.get_current_picker(
					prompt_bufnr
				)
				local delete_cb = function(selection)
					return delete_rule(source_bufnr, setting_cfg, selection)
				end
				current_picker:delete_selection(delete_cb)
			end)

			return true
		end
	}):find()

	return true
end

return M
