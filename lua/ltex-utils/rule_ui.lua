local Config = require("ltex-utils.config")
local cache = require("ltex-utils.cache")
local hfp_cache = require("ltex-utils.hfp_cache")
local words_cache = require("ltex-utils.words_cache")
-- Telescope
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local telescope_actions = require('telescope.actions')
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
-- Plenary
local popup = require("plenary.popup")
local table_utils = require("ltex-utils.table_utils")

---@class Telescope.picker
---@field set_selection function(integer)
---@field delete_selection function(function(integer))


---@class LTeXUtils.UI
---@field cache LTeXUtils.cache|LTeXUtils.hfp_cache|LTeXUtils.words_cache
local rule_ui = {}
rule_ui.__index = rule_ui

---Constructor
---@return LTeXUtils.UI
function rule_ui.new()
	---@type LTeXUtils.UI
	local self = setmetatable(
		{
			---@type LTeXUtils.cache|LTeXUtils.hfp_cache|LTeXUtils.words_cache
			cache = nil,
		},
		rule_ui
	)
	return self
end

---Modifies a rule and updates the internal list.
---@param self LTeXUtils.UI
---@param use_diags boolean
---@param lang string The language identifier (e.g., 'en-GB').
---@param index integer
local function process_input(self, use_diags, lang, index)
	-- get bufnr of current active buffer
	---@type integer
	local bufnr = vim.api.nvim_get_current_buf()
	---@type string
	local new_rule = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]

	self.cache:update_entry(
		index,
		self.cache.lang_rule_to_str(lang, new_rule)
	)
	self.cache:reset_indices()

	-- don't apply cache now
	self.cache.update_flag = false

	-- close popup window; buffer will be automatically wiped
	---@type integer
	local win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_close(win_id, true)

	-- open Telescope window again
	self:new_pick_rule_win(
		self.cache.setting_cfg,
		use_diags,
		Config.rule_ui.telescope_opts
	)

	-- set flag to apply cache at the next possibility
	self.cache.update_flag = true
end

---Creates popup window with the selected ruled from the Telescope window
---and sets a callback for modification.
---@param self LTeXUtils.UI
---@param prompt_bufnr integer
---@param use_diags boolean
local function new_modify_rule_win(self, prompt_bufnr, use_diags)
	---@type table
	local selection = action_state.get_selected_entry()

	-- if selection `nil` do nothing
	if not selection then
		return
	end

	---remember update flag
	---@type boolean
	local update_flag = self.cache.update_flag

	-- don't apply cache now as we need to close Telescope window
	-- and therefore we might jump into the source buffer for a moment
	self.cache.update_flag = false
	telescope_actions.close(prompt_bufnr)

	---@type integer
	local win_id = popup.create('', {
		border = true,
		line = math.floor(vim.o.lines / 2) - 2,
		col = math.floor(vim.o.columns / 2) - 40,
		width= 80,
		minheight = 6,
		maxheight = 20,
		enter = true,
	})

	---@type integer
	local bufnr = vim.api.nvim_win_get_buf(win_id)

	vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
	-- Enable line wrapping
	vim.api.nvim_win_set_option(win_id, 'wrap', true)

	---@type string, string
	local lang, rule = self.cache.selection_to_lang_rule(selection)

	-- Populate the buffer with the text of the rule
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { rule })

	vim.keymap.set({'i', 'n'}, '<CR>', function()
			process_input(self, use_diags, lang, selection.index)
		end,
		{ buffer = bufnr, noremap = false, silent = true }
	)

	-- set `self.cache.update_flag` flag to previous value
	self.cache.update_flag = update_flag
end

---Removes depricated entries from current list
---@param self LTeXUtils.UI
---@param prompt_bufnr integer
local function cleanup_rules(self, prompt_bufnr)
	---@type Telescope.picker
	local picker = require("telescope.actions.state")
					.get_current_picker(prompt_bufnr)
	---@type table<string|integer, string|integer>
	local severities = vim.diagnostic.severity

	---@type integer
	local n = table_utils.max_index(self.cache.data)
	---@type integer
	local row = 0
	-- We can't use `pairs` here because order isn't guaranteed
	for i = 1, n do
		---@type Telescope.entry
		local entry = self.cache.data[i]
		if entry ~= nil then
			if entry.type == severities[2] then
				-- set selection to first line
				picker:set_selection(0)
				break
			elseif entry.type == severities[1] then
				picker:set_selection(row)
				picker:delete_selection(function(selection)
					self.cache:delete_cb(selection)
				end)
			end
			row = row + 1
		end
	end
end

---Simple entry maker for telescope window
---@return function
local function make_simple_entries()
	return function(entry)
		---@type integer
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

---Open new telescope window
---@param opts table window options
---@param use_diags boolean
function rule_ui:new_telescope_win(opts, use_diags)
	pickers.new(opts, {
		prompt_title = self.cache.setting_cfg,
		default_text = "",
		finder = finders.new_table {
			results = self.cache.data,
			entry_maker = not use_diags and make_simple_entries()
				or opts.entry_maker
				or make_entry.gen_from_diagnostics(opts),
		},
		previewer = use_diags and conf.qflist_previewer(opts) or nil,
		sorter = conf.prefilter_sorter {
			tag = "type",
			sorter = conf.generic_sorter(opts),
		},
		attach_mappings = function(_, map)
			---Wrapper for `map` to set multiple keys and modes
			---@param modes_keys table<string, string[]>
			---@param func function(integer)
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
				new_modify_rule_win(self, prompt_bufnr, use_diags)
			end)
			-- set delete key (normal mode only)
			map('n', Config.rule_ui.delete_rule_key, function(prompt_bufnr)
				---@type table
				local current_picker = action_state.get_current_picker(
					prompt_bufnr
				)
				current_picker:delete_selection(function(selection)
					self.cache:delete_cb(selection)
				end)
			end)

			if use_diags then
				map('n',
					Config.rule_ui.cleanup_rules_key,
					function(prompt_bufnr)
						cleanup_rules(self, prompt_bufnr)
				end)

				map('n', Config.rule_ui.goto_key, function(prompt_bufnr)
					---@type table
					local selection = action_state.get_selected_entry()
					telescope_actions.close(prompt_bufnr)
					vim.diagnostic.show()

					---@type integer
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

---Create a new telescope window for modifying `setting_cfg` rules
---@param setting_cfg string 'hiddenFalsePositives'|'disabledRules'
---@param use_diags boolean should diagnostics data be used?
---@param opts table options for telescope window
---@return boolean
function rule_ui:new_pick_rule_win(setting_cfg, use_diags, opts)
	opts = opts or {}
	---@type function()
	local telescope_cb = function ()
		self:new_telescope_win(opts, use_diags)
	end

	-- do we have to collect rules first?
	if self.cache then
		telescope_cb()
		return true
	end

	-- initialise cache and collect entries
	---@type LTeXUtils.cache|LTeXUtils.hfp_cache|LTeXUtils.words_cache
	local win_cache
	if setting_cfg == "hiddenFalsePositives" then
		win_cache = hfp_cache:new(setting_cfg)
	elseif setting_cfg == "disabledRules" then
		win_cache = cache:new(setting_cfg)
	else
		win_cache = words_cache:new(setting_cfg)
	end
	----@cast cache LTeXUtils.cache|LTeXUtils.hfp_cache|LTeXUtils.words_cache
	self.cache = win_cache

	---@type boolean, string|nil
	local ok, err = win_cache:initialise_rules(telescope_cb, use_diags)
	if not ok then
		vim.notify(err or "Error in new_pick_rule_win", vim.log.levels.ERROR)
		return false
	end

	return true
end

return rule_ui
