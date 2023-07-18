local M = {}

---Checks if string `str` starts with string `start`
---@param str string
---@param start string
---@return boolean	
local function starts_with(str, start)
	return str:sub(1, #start) == start
end

---Returns the namespace of LTeX LSP server for buffer `bufnr`; nil if not
---successful.
---@param bufnr integer
---@return integer|nil
local function get_ltex_namespace(bufnr)
	---@type string
	local lsp_server_name = "vim.lsp.ltex." .. tostring(bufnr)
	for ns, ns_metadata in pairs(vim.diagnostic.get_namespaces()) do
		if starts_with(ns_metadata.name, lsp_server_name) then
			return ns
		end
	end
	return nil
end

---Toggles the LTeX diagnostics hints on/off
---@param bufnr integer|nil
function M.toggle_diags(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	---@type integer|nil
	local ns = get_ltex_namespace(bufnr)
	if not ns then
		vim.notify("Error in toggle_diags: no namespace for LTeX LSP server")
		return
	end

	---@type boolean
	local is_disabled = vim.diagnostic.is_disabled(bufnr, ns)

	if is_disabled then
		vim.diagnostic.enable(bufnr, ns)
	else
		vim.diagnostic.disable(bufnr, ns)
	end
end

return M
