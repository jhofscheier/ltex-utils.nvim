if vim.g.loaded_ltex_utils == 1 then
  return
end
vim.g.loaded_ltex_utils = 1

local ltex_lsp = require("ltex-utils.ltex_lsp")
local builtin = require("ltex-utils.builtin")

vim.api.nvim_create_user_command("LTeXUtils", function(opts)
	if #opts.fargs == 1 then
		builtin[opts.fargs[1]]()
	end
--  require("telescope.command").load_command(unpack(opts.fargs))
end, {
	nargs = "*",
	complete = function(_, line)
		local excluded = { "wins" }
		local builtin_list = vim.tbl_filter(function(key)
			return not vim.tbl_contains(excluded, key)
		end, vim.tbl_keys(require("ltex-utils.builtin")))
		local l = vim.split(line, "%s+")
		local n = #l - 2

		if n == 0 then
			table.sort(builtin_list)

			return vim.tbl_filter(function(val)
				return vim.startswith(val, l[2])
			end, builtin_list)
		end

		if n == 1 and l[2] == "modify_dict" then
			local client = ltex_lsp.get_ltex()
			if not client then return end

			local settings, err = ltex_lsp.get_settings(client, "dictionary")
			if not settings then
				return false, err
			end

			local dicts = vim.tbl_keys(settings)
			table.sort(dicts)

			return vim.tbl_filter(function(val)
				return vim.startswith(val, l[3])
			end, dicts)
		end
	end,
})
