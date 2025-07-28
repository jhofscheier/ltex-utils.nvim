-- Setup Lsp.
local capabilities = require("lvim.lsp").common_capabilities()
require("lvim.lsp.manager").setup("ltex", {
	on_attach = function ()
		require("ltex-utils").on_attach(bufnr)
		require("lvim.lsp").common_on_attach(client, bufnr)
	end,
	on_init = require("lvim.lsp").common_on_init,
	capabilities = capabilities,
})
