local M = {}

-- First active ltex LSP client or nil if there are none
-- NOTE: vim.lsp.get_active_clients returns a table of all the active LSP
-- clients for all the buffers in the current Neovim instance --> don't use
function M.get_ltex()
  for _, client in ipairs(vim.lsp.buf_get_clients()) do
    if client.name == 'ltex' then
      return client
    end
  end
  return nil
end

-- Returns the LSP server settings for a specified 'option' from the given
-- 'client'. Initializes an empty table for the 'option' if it doesn't exist.
function M.get_settings(client, option)
	local settings = client.config.settings.ltex or {}
	if not settings[option] then
		settings[option] = {}
	end
	return settings
end

return M
