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
		path = vim.api.nvim_call_function("stdpath", { "state" }) .. "/ltex/",
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


---Returns directory for vim dictionary spell files. We follow neovim's
---strategy:
---1. If custom_path is not writable (or nil), default to neovim's standard
---   logic of determining the directory where to put spell files. That is:
---2. Return first writable directory from the runtimepath variable.
---3. If none of the directories in runtimepath are writable, default current
---   working directory.
---4. If current working directory not writable return nil and log error
---   message.
---@param custom_path? string
---@return string | nil spell_path -- returns writable path for writing vim dict
local function get_vim_dict_dir(custom_path)
	-- First try user-provided `custom_path` (if not nil and not empty string).
	if custom_path and custom_path ~= "" then
		if vim.fn.filewritable(custom_path) == 2 then
			return custom_path
		end
	end

	-- If `custom_path` not writable, fallback to neovim's standard logic of
	-- determining directory for spell files.
	local rtp = vim.o.runtimepath
	if rtp and rtp ~= "" then
		local paths = vim.split(rtp, ',', { plain = true })

		for _, path in ipairs(paths) do
			local expanded_path = vim.fn.expand(path)
			if expanded_path and expanded_path ~= "" then
				local spell_dir = expanded_path .. "/spell"

				-- Check if spell directory exists and is writable
				if vim.fn.filewritable(spell_dir) == 2 then
					return spell_dir
				end

				-- If spell directory doesn't exist but parent is writable,
				-- create it
				if vim.fn.filewritable(expanded_path) == 2 and
					vim.fn.isdirectory(spell_dir) == 0 then
					if vim.fn.mkdir(spell_dir, "p") == 1 then
						return spell_dir
					end
				end
			end
		end
	end

	-- If default_path is not writable, fallback to current directory.
	local cwd = vim.fn.getcwd()
	if cwd and cwd ~= "" then
		if vim.fn.filewritable(cwd) == 2 then
			return cwd
		end
	end

	-- If each approach fails, return nil and log error message.
	vim.notify(
		"Could not find valid directory for writing vim dictionary. " ..
		"All dictionary data held by ltex will be lost. We are sorry.",
		vim.log.levels.ERROR
	)
	return nil
end

---@param opts? LTeXUtils.Config
function M.setup(opts)
	opts = opts or {}
	local vim_dict_settings = opts.dictionary and opts.dictionary.use_vim_dict
		and {
			dictionary = {
				path = get_vim_dict_dir(vim.fn.stdpath("config") .. "/spell/"),
				filename = function(lang)
					local fileencoding = vim.api.nvim_get_option_value(
						"fileencoding",
						{ buf = 0 }
					) or "utf-8"

					return string.match(lang, "^(%a+)-") .. "." ..
						fileencoding .. ".add"
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
