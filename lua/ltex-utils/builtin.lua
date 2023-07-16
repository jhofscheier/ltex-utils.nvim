local builtin = {}

local actions = require("ltex-utils.actions")
local Config = require("ltex-utils.config")

---@type table<integer, LTeXUtils.UI>
builtin.wins = {}

---Creates new Telescope window for modifying rules or words.
---@param setting_cfg string
---@param use_diags boolean
local function new_win(setting_cfg, use_diags)
	use_diags = vim.F.if_nil(use_diags, false)
	---@type LTeXUtils.UI
	local win = builtin.wins[vim.api.nvim_get_current_buf()]
	if win then
		-- delete old cache
		win.cache = nil
		---@type boolean, string|nil
		local ok, err = win:new_pick_rule_win(
			setting_cfg,
			use_diags,
			Config.rule_ui.telescope
		)
		if not ok then
			vim.notify(
				err or "Error in modifying rules",
				vim.log.levels.WARN
			)
		end
	end
end

---Writes LTeX LSP server settings to filej
builtin.write_settings_to_file = actions.write_ltex_to_file

---Loads LTeX LSP server settings from file
builtin.load_settings_from_file = actions.load_ltex_from_file

---Opens new Telescope window to modify hidden false positive rules.
builtin.modify_hiddenFalsePositives = function ()
	new_win(
		"hiddenFalsePositives",
		Config.diagnostics.diags_false_pos
	)
end

---Opens new Telescope window to modify disabled rules list.
builtin.modify_disabledRules = function ()
	new_win("disabledRules", Config.diagnostics.diags_disable_rules)
end

---Opens new Telescope window to modify dictionaries (including saved ones).
builtin.modify_dict = function ()
	new_win("dictionary", false)
end

return builtin
