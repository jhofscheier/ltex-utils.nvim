local M = {}

---@class LTeXUtils.Config
---@field dict_path? string
---@field rule_ui? RuleUi.Config
---@field diagnostics? Diagnostics.Config
local defaults = {
	-- Path to the directory where dictionaries are stored.
	-- Defaults to the Neovim cache directory.
	dict_path = vim.api.nvim_call_function("stdpath", {"cache"}) .. "/ltex/",
	---@class RuleUi.Config
	---@filed modify_rule_key string
	---@field delete_rule_key string
	---@field cleanup_rules_key string
	---@field goto_key string
	---@field previewer_line_number boolean
	---@field previewer_wrap  boolean
	---@field telescope table
	rule_ui = {
		-- key to modify rule
		modify_rule_key = "<CR>",
		-- key to delete rule
		delete_rule_key = "d",
		-- key to cleanup deprecated rules
		cleanup_rules_key = "c",
		-- key to jump to respective place in file
		goto_key = "g",
		-- enable line numbers in preview window
		previewer_line_number = true,
		-- wrap lines in preview window
		previewer_wrap = true,
		-- options for creating new telescope windows
		telescope = { bufnr = 0 },
	},
	---@class Diagnostics.Config
	---@field debounce_time_ms? integer
	---@field diags_false_pos boolean
	---@field diags_disable_rules boolean
	diagnostics = {
		-- time to wait for language tool to complete parsing document
		-- debounce time in milliseconds
		debounce_time_ms = 500,
		-- use diagnostics data for modifying hiddenFalsePositives rules
		diags_false_pos = true,
		-- use diagnostics data for modifying disabledRules rules
		diags_disable_rules = true,
	},
}

---@type LTeXUtils.Config
local options


---@param opts? LTeXUtils.Config
function M.setup(opts)
	opts = opts or {}
	options = vim.tbl_deep_extend("force", defaults, opts)
end

return setmetatable(M, {
	__index = function(_, key)
		if options == nil then
			return vim.deepcopy(defaults)[key]
		end
		return options[key]
	end,
})
