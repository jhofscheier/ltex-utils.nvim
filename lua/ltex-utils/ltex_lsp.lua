local M = {}

local Config = require("ltex-utils.config")

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

function M.get_server_rules(bufnr)
end


---Returns a handler for `textDocument/publishDiagnostics` notifications.
---The handler collects diagnostics data using a timer to batch process it.
---@param accumulated_diagnostics table Table to store diagnostics data
---@param callback function Function called after all data is collected
---@return function # "textDocument/publishDiagnostics"-notification handler
function M.on_publish_diags(accumulated_diagnostics, callback)
	local diag_timer = nil

	return function (
		err,
		result,
		ctx
	)
		if err then
			vim.notify("Error on 'textDocument/publishDiagnostics'" ..
				vim.inspect(err), vim.log.levels.ERROR)
				return
		end

		-- The original diagnostics handler
		vim.lsp.with(
			vim.lsp.diagnostic.on_publish_diagnostics, {
				-- custom settings here
			}
		)(err, result, ctx)

		-- Add new diagnostics to our table
		table.insert(accumulated_diagnostics, result)

		-- If there's an existing timer, stop it
		if diag_timer then
			diag_timer:stop()
			diag_timer:close()
		end

		-- Start a new timer
		diag_timer = vim.loop.new_timer()

		-- Schedule the timer to call our function after debounce_time_ms
		diag_timer:start(
			Config.diagnostics.debounce_time_ms,
			0,
			vim.schedule_wrap(function()
				callback()
				-- Clear the diagnostics and the timer
				diag_timer:stop()
				diag_timer:close()
				diag_timer = nil
			end)
		)
	end
end

--- Requests code actions for given diagnostics,
-- processes them, and triggers a final callback.
--
-- @param client The LSP client.
-- @param bufnr The buffer number.
-- @param diags List of diagnostics.
-- @param process_action Function to process each code action.
-- @param final_callback Function called when all requests have been processed.
function M.collect_diagnostics_actions(
	client,
	bufnr,
	diags,
	process_action,
	final_callback
)
	local pending_reqs = 0
	for _, chunk in ipairs(diags) do
		pending_reqs = pending_reqs + #chunk.diagnostics
	end

	for _, chunk in ipairs(diags) do
		local uri = chunk.uri
		for _, diag in ipairs(chunk.diagnostics) do
			 local params = {
				textDocument = { uri = uri },
				range = diag.range,
				context = { diagnostics = diag },
			}

			client.request(
				'textDocument/codeAction',
				params,
				function(err, actions)
					if err then
						vim.notify("Error getting code action: " ..
							vim.inspect(err), vim.log.levels.ERROR)
						return
					end
					process_action(err, actions)

					pending_reqs = pending_reqs - 1

					-- have all request be collected?
					if pending_reqs == 0 then
						final_callback()

						client.notify(
							"workspace/didChangeConfiguration",
							client.config.settings
						)
					end

					return true
				end,
				bufnr
			)
		end
	end
end

return M
