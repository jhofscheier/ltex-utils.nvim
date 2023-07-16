local cache = require("ltex-utils.cache")

---@class LTeXUtils.hfp_cache: LTeXUtils.cache
---@field initialise_rules function(telescope_cb: function(), use_diags: boolean): boolean, string|nil
local M = cache:new()

---Transforms selection into language and rule pair.
---@param selection table telescope selection object
---@return string # Language descriptor
---@return string # Rule
function M.selection_to_lang_rule(selection)
	---Encodes `str` in json format
	---@param str string
	---@return string
	local json_encode = function (str)
		return vim.fn.json_encode({str}):match("^%s*%[%s*(.-)%s*%]%s*$")
	end
	-- Get selection text; varies based on diagnostic usage.
	---@type string
	local text = selection.text or selection.value.text
	---@type string, string, string
	local lang, rule, sentence = text:match("^(.-)%s*,%s*(.-)%s*:%s*(.*)$")

	-- HACK: The code vim.fn.json_encode({ rule = rule, sentence = sentence })
	-- works too but has the caveat that it swaps rule and sentence leading to
	-- rules of the form '{"sentence":"...","rule":"..."}' but we want to keep
	-- the order as ltex-ls uses
	return lang, string.format(
		'{"rule":%s,"sentence":%s}',
		json_encode(rule),
		json_encode(sentence)
	)
end

---Converts a language and rule pair into a formatted Telescope entry string
---@param lang string
---@param rule string
---@return string
function M.lang_rule_to_str(lang, rule)
	rule = vim.fn.json_decode(rule)
	return string.format("%s, %s: %s", lang, rule.rule, rule.sentence)
end

return M
