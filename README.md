# LTeX-Utils.nvim: LTeX Utility functions

Neovim plugin implementing functionality for LSP code actions for [`ltex-ls`](https://github.com/valentjn/ltex-ls), namely
* [`addToDictionary`](https://valentjn.github.io/ltex/ltex-ls/server-usage.html#_ltexaddtodictionary-client),
* [`disableRule`](https://valentjn.github.io/ltex/ltex-ls/server-usage.html#_ltexdisablerules-client), and
* [`hideFalsePositive`](https://valentjn.github.io/ltex/ltex-ls/server-usage.html#_ltexhidefalsepositives-client).

In addition, the plugin provides functions for loading, saving, and modifying LSP server settings and custom dictionaries.
For a detailed overview, please refer to the tutorial.

There are already several other excellent Neovim plugins that provide similar functionality: for example, [LTeX\_extra.nvim](https://github.com/barreiroleo/ltex_extra.nvim), [LTeX LS Client](https://github.com/icewind/ltex-client.nvim), and [ltex-ls.nvim](https://github.com/vigoux/ltex-ls.nvim).

> **Question**. Why another LTeX plugin?<br> 
>**Answer**. The last time I checked, these plugins are well written and do a fantastic job.
>However, all of them perform an excessive number of disk reads and writes.
>Some of them after each code action.
>This plugin follows the strategy to load the sever settings and dictionaries when the LTeX LSP server starts up and then leaves responsibility of keeping the current (language) configuration to the LSP server. 
>Settings are automatically written to disk when the buffer is closed.
>Convenience functions allow the user to manually read/write settings from/to disk.

## Requirements

- [ltex-ls](https://github.com/valentjn/ltex-ls)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [Telescope](https://github.com/nvim-telescope/telescope.nvim)
- optional:
  - [telescope-fzf-native.nvim](https://github.com/nvim-telescope/telescope-fzf-native.nvim)

## Installation
Install the plugin with your favourite plugin manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "jhofscheier/ltex-utils.nvim",
    dependencies = {
        "neovim/nvim-lspconfig",
        "nvim-telescope/telescope.nvim",
        -- "nvim-telescope/telescope-fzf-native.nvim", -- optional
    },
    opts = {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
    },
},
```
Then call `ltex-utils.on_attach()` from the `on_attach` function of your server.
For example, with [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig) this could look like follows:
```lua
require("lspconfig").ltex.setup({
    capabilities = your_capabilities,
    on_attach = function(client, bufnr)
        -- your other on_attach code
        -- for example, set keymaps here, like
        -- vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
        -- (see below code block for more details)
        require("ltex-utils").on_attach()
    end,
    settings = {
        ltex = { your settings },
    },
})
```
Check the [nvim-lspconfig suggested configuration](https://github.com/neovim/nvim-lspconfig#suggested-configuration) for furhter details on how to set keybindings.

## Configuration

By default, dictionaries are saved in a subfolder named `ltex` within Neovim's cache directory.
For instance, if Neovim's cache folder is located at `~/.cache/nvim/`, the dictionaries will be stored in `~/.cache/nvim/ltex/`.
You can change the dictionary folder and other options by running `require("ltex-utils").setup({ your options here })` at an appropriate place in your config code.
For example, for `lazy.nvim` this could be done as follows.
`ltex-utils.nvim` comes with the following defaults:
```lua
{
    "jhofscheier/ltex-utils.nvim",
    dependencies = {
        "neovim/nvim-lspconfig",
        "nvim-telescope/telescope.nvim",
        -- "nvim-telescope/telescope-fzf-native.nvim", -- optional
    },
    opts = {
        delete_rule_key = "d",
        dict_path = vim.api.nvim_call_function("stdpath", {"cache"}) .. "/ltex/",
        modify_rule_key = "<CR>",
        win_opts = {},
    },
},

```

## Usage
Using the mentioned configuration above, activate code actions by pressing `<leader>-ca`.
Navigate to an LTeX issue within your text (LaTeX, Markdown, etc.), then press `<leader>-ca` and choose a suitable option from the menu to fix the problem.

Upon closing the buffer, LSP server settings (including hidden false positives, disabled rules, used languages, and added dictionary words) are saved to disk.
Settings are saved in the same folder as your LaTeX/Markdown file under `your_file_ltex.json`.
Dictionaries are merged with existing (stored) ones and then saved to preserve all words.
By default, dictionaries are saved in Neovim's cache directory, although this can be customised (see [Installation](#installation)).


You can manually save settings with the `:LTeXUtils write_settings_to_file` command, and reload them with `:LTeXUtils load_settings_from_file`.

The `:LTeXUtils modify_dict` command allows you to inspect, edit, or delete entries in the relevant dictionary.

To examine, change, or remove entries in the `disabledRules` or `hiddenFalsePositives` lists, use the `:LTeXUtils modify_disabledRules` or `:LTeX modify_hiddenFalsePositives` commands respectively.

More details can be found in the [tutorial](TUTORIAL.md).

## Caveats

If you frequently use the 'Hide False Positive' code action, be mindful that changes to the manuscript may render these rules obsolete.
Accumulating outdated rules can clutter the `hiddenFalsePositives` list, as LTeX doesn't clean them up automatically.


To avoid this, use 'Hide False Positive' sparingly or manually remove obsolete rules through `:LTeXUtils modify_hiddenFalsePositives`.
Direct modification of `the your_file_ltex.json` settings file is not advised.
Using regular expressions for `hiddenFalsePositives` could help prevent clutter in your hidden false positives list.
However, bear in mind that hidden false positive rules hide the entire sentence and might not yield the expected behaviour.
An in-depth explanation is available in the [tutorial](TUTORIAL.md).

