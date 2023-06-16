local M = {}

--- Returns the first active LTeX LSP client attached to a buffer.
--
-- @param bufnr Buffer number (optional). If not provided, uses current buffer.
-- @return LTeX LSP client if found, otherwise nil.
-- NOTE: vim.lsp.buf_get_clients() is deprecated;
-- use vim.lsp.get_active_clients instead.
function M.get_ltex(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	for _, client in ipairs(vim.lsp.get_active_clients({ buffer = bufnr })) do
		if client.name == 'ltex' then
			return client
		end
	end

	return nil
end

-- Returns the LSP server settings for a specified 'option' from the given
-- 'client'. Initializes an empty table for the 'option' if it doesn't exist.
function M.get_settings_or_init(client, option)
	local settings = client.config.settings.ltex or {}

	if not settings[option] then
		settings[option] = {}
	end

	return settings
end

--- Retrieves specified settings from the LTeX LSP server configuration.
--
-- @param client The LTeX LSP client.
-- @param setting_cfg The settings configuration to retrieve.
-- @return table, string Returns the settings table if found. Returns nil and
--                       an error message if not found.
--
function M.get_settings(client, setting_cfg)
	local settings = client.config.settings.ltex

	-- Check if active server has settings `setting_cfg`
	if not settings[setting_cfg] then
		return nil, string.format(
			"The current LTeX server has no settings: %s\n",
			setting_cfg
		)
	end

	return settings[setting_cfg]
end

--- Retrieves the specified settings for a given language from the LTeX LSP
--  server configuration.
--
-- @param client The LTeX LSP client.
-- @param setting_cfg The settings configuration to retrieve.
-- @param lang The language for which settings should be retrieved.
-- @return table, string Returns the language-specific settings table if found.
--                       Returns nil and an error message if not found.
--
function M.get_settings_for_lang(client, setting_cfg, lang)
	local settings, err = M.get_settings(client, setting_cfg)

	if not settings then
		return nil, err
	end

	local lang_rules = settings[lang]
	if not lang_rules then
		return nil, string.format(
			"The avitve LTeX server has no %s for %s\n",
			setting_cfg,
			lang
		)
	end

	return lang_rules
end

return M
