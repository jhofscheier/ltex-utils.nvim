local builtin = {}

local actions = require('ltex-utils.actions')
local modify_rule = require('ltex-utils.modify_rule')

builtin.write_settings_to_file = actions.write_ltex_to_file

builtin.load_settings_from_file = actions.load_ltex_from_file

builtin.modify_hiddenFalsePositives = function ()
	modify_rule.new_pick_rule_win(modify_rule.opts, "hiddenFalsePositives")
end

builtin.modify_disabledRules = function ()
	modify_rule.new_pick_rule_win(modify_rule.opts, "disabledRules")
end

builtin.modify_dict = function ()
	modify_rule.new_pick_rule_win(modify_rule.opts, "dictionary")
end

return builtin
