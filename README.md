# LTeX-Utils.nvim: LTeX Utility functions

Neovim plugin implementing functionality for LSP code actions for [`ltex-ls`](https://github.com/valentjn/ltex-ls), namely
* [`addToDictionary`](https://valentjn.github.io/ltex/ltex-ls/server-usage.html#_ltexaddtodictionary-client),
* [`disableRule`](https://valentjn.github.io/ltex/ltex-ls/server-usage.html#_ltexdisablerules-client), and
* [`hideFalsePositive`](https://valentjn.github.io/ltex/ltex-ls/server-usage.html#_ltexhidefalsepositives-client).

In addition, this plugin provides functions for loading and saving of LSP server settings and custom dictionaries.

There are already several other excellent neovim plugins that provide similar functionality: for example, [LTeX\_extra.nvim](https://github.com/barreiroleo/ltex_extra.nvim#features), [LTeX LS Client](https://github.com/icewind/ltex-client.nvim), and [ltex-ls.nvim](https://github.com/vigoux/ltex-ls.nvim).

> **Question**. Why another LTeX plugin?<br> 
>**Answer**. The last time I checked, these plugins are well written and do a fantastic job.
>However, all of them perform an excessive number of disk reads and writes.
>Some of them after each code action.
>This plugin follows the strategy to load the sever settings and dictionaries when the LTeX LSP server starts up and then leaves responsibility of keeping the current (language) configuration to the LSP server. 
>Convenience functions allow the user to manually read/write settings from/to disk.
>Settings are written to disk when the buffer is closed.

## Installation
Install the plugin with your favourite plugin manager using `{"jhofscheier/ltex-utils.nvim"}`.
Then call `ltex-utils.on_attach()` from the `on_attach` function of your server.
For example, with `lspconfig` this could look like follows:
```lua
require("lspconfig").ltex.setup({
    capabilities = your_capabilities,
    on_attach = function(client, bufnr)
        -- your other on_attach code
        -- for example, I have set
        -- buf_keymap("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
        require("ltex-utils").on_attach()
    end,
    settings = {
        ltex = { your settings },
    },
})
```
By default, dictionaries are saved in a subfolder named `ltex` within Neovim's cache directory.
For instance, if Neovim's cache folder is located at `~/.cache/nvim/`, the dictionaries will be stored in `~/.cache/nvim/ltex/`.
You can change the dictionary folder by running `require("ltex-utils").setup({ dict_path = your_dictionary_path })` at an appropriate place in your config code.
For example, for `lazy.nvim` this could be done as follows:
```lua
{
    "jhofscheier/ltex-utils.nvim",
    config = function ()
        require("ltex-utils").setup({ dict_path = your_dictionary_path })
    end,
},
```

## Usage
Using the mentioned configuration above, activate code actions by pressing `<leader>-ca`.
Navigate to an LTeX issue within your text (LaTeX, Markdown, etc.), then press `<leader>-ca` and choose a suitable option from the menu to fix the problem.

Upon closing the buffer, LSP server settings (including hidden false positives, disabled rules, used languages, and added dictionary words) are saved to disk.
Settings are saved in the same folder as your LaTeX/Markdown file under `your_file_ltex.json`.
Dictionaries are merged with existing (stored) ones and then saved to preserve all words.
By default, dictionaries are saved in Neovim's cache directory, although this can be customised (see [Installation](#installation)).

Use the `:WriteLTeXToFile` command to manually save settings and `:LoadLTeXFromFile` to reload them.

## Caveats

If you frequently use the 'Hide False Positive' code action, be mindful that changes to the manuscript may render these rules obsolete.
Accumulating outdated rules can clutter the `hiddenFalsePositives` list, as LTeX doesn't clean them up automatically.

To avoid this, use 'Hide False Positive' sparingly or manually remove old rules from the `your_file_ltex.json` settings file.
Using regular expressions for `hiddenFalsePositives` can also help to avoid cluttering your hidden false positives list.
Future versions of this plugin will include features for managing and creating more generalised `hiddenFalsePositives` rules (including the use of regular expressions).


