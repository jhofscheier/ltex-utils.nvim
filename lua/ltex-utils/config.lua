local M = {}

---@class LTeXUtils.Config
---@field dictionary? Dictionary.Config
---@field rule_ui? RuleUi.Config
---@field diagnostics? Diagnostics.Config
---@field backend? string
local defaults = {
	---@class Dictionary.Config
	---@field path string
	---@field filename function(string): string
	dictionary = {
		-- Path to the directory where dictionaries are stored.
		-- Defaults to the Neovim state directory.
		path = vim.api.nvim_call_function("stdpath", {"state"}) .. "/ltex/",
		---Returns the dictionary file name for given language `lang`
		---@param lang string
		---@return string
		filename = function(lang)
			return lang .. ".txt"
		end,
		-- use vim internal dictionary to add unkown words
		use_vim_dict = false,
		-- show/suppress vim command output such as `spellgood` or `mkspell`
		vim_cmd_output = false,
	},
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
	-- set the ltex-ls ("ltex") or ltex-ls-plus backend ("ltex_plus")
	backend = "ltex_plus",
}

---@type LTeXUtils.Config
local options

---@param opts? LTeXUtils.Config
function M.setup(opts)
	opts = opts or {}
	local vim_dict_settings = opts.dictionary and opts.dictionary.use_vim_dict
		and {
				dictionary = {
					path = vim.fn.stdpath("config") .. "/spell/",
					filename = function(lang)
						return string.match(lang, "^(%a+)-") .. "." ..
						vim.api.nvim_get_option_value(
							"fileencoding",
							{ buf = 0 }
						) ..
						".add"
					end,
				}
			} or {}
	options = vim.tbl_deep_extend("force", defaults, vim_dict_settings, opts)
end

return setmetatable(M, {
	__index = function(_, key)
		if options == nil then
			return vim.deepcopy(defaults)[key]
		end
		return options[key]
	end,
})
