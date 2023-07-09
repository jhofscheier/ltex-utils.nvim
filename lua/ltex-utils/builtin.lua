local builtin = {}

local actions = require("ltex-utils.actions")
local Config = require("ltex-utils.config")
local rule_ui = require("ltex-utils.rule_ui")

builtin.rule_edit_cache = {}

local function new_win_from_cache(setting_cfg, use_diags)
	use_diags = vim.F.if_nil(use_diags, false)
	local curr_cache = builtin.rule_edit_cache[vim.api.nvim_get_current_buf()]
	if curr_cache then
		-- delete old list of rules
		curr_cache.rules = nil
		curr_cache.changes = nil
		local ok, err = curr_cache:new_pick_rule_win(
			setting_cfg,
			use_diags,
			rule_ui.opts
		)
		if not ok then
			vim.notify(
				err or "Error in modifying rules",
				vim.log.levels.WARN
			)
		end
	end
end

builtin.write_settings_to_file = function ()
	local curr_cache = builtin.rule_edit_cache[vim.api.nvim_get_current_buf()]
	actions.write_ltex_to_file(curr_cache.cache.dictionary)
end

builtin.load_settings_from_file = actions.load_ltex_from_file

builtin.modify_hiddenFalsePositives = function ()
	new_win_from_cache(
		"hiddenFalsePositives",
		Config.diagnostics.diags_false_pos
	)
end

builtin.modify_disabledRules = function ()
	new_win_from_cache("disabledRules", Config.diagnostics.diags_disable_rules)
end

builtin.modify_dict = function ()
	new_win_from_cache("dictionary", false)
end

return builtin
