local Config = require("ltex-utils.config")


local M = {}

---@class vim.loop.timer
---@field start function()
---@field stop function()
---@field close function()


---Returns the first active LTeX LSP client attached to a buffer.
---NOTE: vim.lsp.buf_get_clients() is deprecated;
---use vim.lsp.get_active_clients instead.
---NOTE: vim.lsp.get_active_clients is deprecated form nvim 0.12;
---use vim.lsp.get_clients instead.
---@param bufnr integer|nil Buffer number; if not provided uses current buffer.
---@return table|nil # LTeX LSP client if found, otherwise nil.
function M.get_ltex(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client.name == 'ltex' then
			return client
		end
	end

	return nil
end

---Returns the LSP server settings for a specified 'option' from the given
---'client'. Initializes an empty table for the 'option' if it doesn't exist.
---@param client table LTeX LSP client
---@param option string
---@return table<string, string[]>
function M.get_settings_or_init(client, option)
	---@type table
	local settings = client.config.settings.ltex or {}

	if not settings[option] then
		settings[option] = {}
	end

	return settings
end

---Retrieves specified settings from the LTeX LSP server configuration.
---@param client table LTeX LSP client
---@param setting_cfg string The settings configuration to retrieve.
---@return table<string, string[]>|nil # Returns the settings table if found.
---@return string|nil # Returns nil and an error message if not found.
function M.get_settings(client, setting_cfg)
	---@type table
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

---Returns a handler for `textDocument/publishDiagnostics` notifications.
---The handler collects diagnostics data using a timer to batch process it.
---@param accumulated_diagnostics table Table to store diagnostics data
---@param callback function Function called after all data is collected
---@return function(table, vim.lsp.diagnostic.diagnostic, table) # "textDocument/publishDiagnostics"-notification handler
function M.on_publish_diags(accumulated_diagnostics, callback)
	---@type vim.loop.timer|nil
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
		-- use vim.diagnostic.config(({opts}, {namespace}) for custom settings
		vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)

		-- Add new diagnostics to our table
		table.insert(accumulated_diagnostics, result)

		-- If there's an existing timer, stop it
		if diag_timer then
			diag_timer:stop()
			diag_timer:close()
			diag_timer = nil
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

---Requests code actions for given diagnostics, processes them, and triggers a
---final callback.
---@param client table The LTeX LSP server.
---@param bufnr integer The buffer number.
---@param diags vim.lsp.diagnostic.diagnostic List of diagnostics.
---@param process_action function(string, vim.lsp.diagnostic.action[]) Function to process each code action.
---@param final_cb function() Function called when all requests have been processed.
function M.actions_from_diags(client, bufnr, diags, process_action, final_cb)
	---@type integer
	local pending_reqs = 0
	for _, chunk in ipairs(diags) do
		pending_reqs = pending_reqs + #chunk.diagnostics
	end

	for _, chunk in ipairs(diags) do
		---@type string
		local uri = chunk.uri
		for _, diag in ipairs(chunk.diagnostics) do
			---@type table
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
						final_cb()

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
