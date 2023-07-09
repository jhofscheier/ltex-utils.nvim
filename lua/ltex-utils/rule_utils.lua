local rule_utils = {}

local setting_quickfix_map = {
	hiddenFalsePositives = "quickfix.ltex.hideFalsePositives",
	disabledRules = "quickfix.ltex.disableRules",
	dictionary = "quickfix.ltex.addToDictionary",
}

local setting_cmd_cfg_map = {
	hiddenFalsePositives = "falsePositives",
	disabledRules = "ruleIds",
}

-- use local variable to reduce table lookup costs
local severities = vim.diagnostic.severity

--- Converts a language and rule pair into a formatted string.
--
-- @param lang The language of the rule.
-- @param rule The rule in JSON format.
--
-- @return string A formatted string representation of the language and rule.
function rule_utils.lang_rule_to_str(lang, rule)
	rule = vim.fn.json_decode(rule)
	return string.format("%s, %s: %s", lang, rule.rule, rule.sentence)
end

local function quickfix_from_action(actions, setting_cfg)
	for _, action in ipairs(actions) do
		if action.kind == setting_quickfix_map[setting_cfg] then
			return action
		end
	end
	return nil
end

---Transforms selection into language and rule pair.
---@param selection table telescope selection object
---@return string # Language descriptor
---@return string # Rule
function rule_utils.selection_to_lang_rule(selection)
	-- Get selection text; varies based on diagnostic usage.
	local text = selection.text or selection.value.text
	local lang, rule, sentence = text:match("^(.-)%s*,%s*(.-)%s*:%s*(.*)$")
	return lang, string.format(
		'{"rule":"%s","sentence":"%s"}',
		rule,
		sentence:gsub("\\", "\\\\")
	)
end

---Sorts passed parameter `tbl` in place: first type, then line number
---@param tbl table<string, table>
----@return table # list of telescope entries
function rule_utils.sorted_rules_list(tbl)
	--local lst = vim.tbl_values(tbl)

	table.sort(tbl, function(a,b)
		if a.type == b.type then
			return a.lnum < b.lnum
		else
			return a.type < b.type
		end
	end)

--	return lst
end

---comment
---@param rules_tbl table<string, table>
---@param diags table
---@param rule string[]
---@param filename string
---@param bufnr integer
local function process_rule(rules_tbl, diags, rule, filename, bufnr)
	local text = rule_utils.lang_rule_to_str(unpack(rule))
	local curr_entry = rules_tbl[text]

	if curr_entry then
		-- only update server's rules
		if curr_entry.type == severities[1] then
			curr_entry.lnum = diags.range.start.line + 1
			curr_entry.col = diags.range.start.character + 1
			curr_entry.type = severities[3]
		end
	else
		rules_tbl[text] = {
			bufnr = bufnr,
			filename = filename,
			lnum = diags.range.start.line + 1,
			col = diags.range.start.character + 1,
			text = text,
			type = severities[2],
		}
	end
end

--- Callback for collecting relevant code actions into `rules_tbl`.
-- @param rules_tbl Table for storing rules.
-- @param bufnr Buffer number.
-- @param setting_cfg Configuration setting.
-- @param err Error object, if any.
-- @param actions Code actions to process.
function rule_utils.get_actions_callback(
	rules_tbl,
	bufnr,
	setting_cfg,
	err,
	actions
)
	if err then
		vim.notify(
			"Error getting code actions: " .. vim.inspect(err),
			vim.log.levels.ERROR
		)
		return
	end

	local quickfix = quickfix_from_action(actions, setting_cfg)
	if not quickfix then
		vim.notify("Error retrieving " .. setting_cfg .. " from actions")
		return
	end
	for i, argument in ipairs(quickfix.command.arguments) do
		local filename = argument.uri and argument.uri:sub(8)
				or vim.api.nvim_buf_get_name(bufnr)
		for lang, rules in pairs(argument[setting_cmd_cfg_map[setting_cfg]]) do
			for _, rule in ipairs(rules) do
				process_rule(
					rules_tbl,
					quickfix.diagnostics[i],
					{ lang, rule },
					filename,
					bufnr
				)
			end
		end
	end
end

--- Collects server settings rules, applying user changes from cache.
-- @param cache Table storing user-applied changes to rules.
-- @param settings Server settings.
-- @param bufnr Buffer number.
-- @return Table with rules, considering user changes.
function rule_utils.get_settings_rules(cache, settings, bufnr)
	local filename = vim.api.nvim_buf_get_name(bufnr)

	-- initialise rules table with server settings
	local rules_tbl = {}
	for lang, rules in pairs(settings) do
		local cached_lang_rules = cache[lang] or {}
		for _, rule in ipairs(rules) do
			local curr_change = cached_lang_rules[rule]
			rule = not curr_change and rule
				or #curr_change > 0 and curr_change
				or nil
			if rule then
				local text = rule_utils.lang_rule_to_str(lang, rule)
				rules_tbl[text] = {
					bufnr = bufnr,
					filename = filename,
					lnum = 1,
					col = 1,
					text = text,
					type = severities[1],
				}
			end
		end
	end

	return rules_tbl
end

return rule_utils
