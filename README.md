# LTeX-Utils.nvim: LTeX Utility functions

| **Note**. The original version of this plugin supported [`ltex-ls`](https://github.com/valentjn/ltex-ls), however this repository has not been maintained for 2 years by the time of writing this README. Therefore, I have updated the plugin and documentation to use the community fork ['ltex-ls-plus'](https://github.com/ltex-plus/ltex-ls-plus) instead.

Neovim plugin implementing functionality for LSP code actions for [`ltex-ls-plus`](https://github.com/ltex-plus/ltex-ls-plus), namely
* [`addToDictionary`](https://ltex-plus.github.io/ltex-plus/ltex-ls-plus/server-usage.html#_ltexaddtodictionary-client),
* [`disableRule`](https://ltex-plus.github.io/ltex-plus/ltex-ls-plus/server-usage.html#_ltexdisablerules-client), and
* [`hideFalsePositive`](https://ltex-plus.github.io/ltex-plus/ltex-ls-plus/server-usage.html#_ltexhidefalsepositives-client).

In addition, the plugin provides functions for loading, saving, and modifying LSP server settings and custom dictionaries.
For a detailed overview, please refer to the [tutorial](TUTORIAL.md).

There are already several excellent Neovim plugins that provide similar functionality: for example, [LTeX\_extra.nvim](https://github.com/barreiroleo/ltex_extra.nvim), [LTeX LS Client](https://github.com/icewind/ltex-client.nvim), and [ltex-ls.nvim](https://github.com/vigoux/ltex-ls.nvim).

> **Question**. Why another LTeX plugin?<br> 
>**Answer**. The last time I checked, these plugins are well written and do a fantastic job.
>However, all of them perform an excessive number of disk reads and writes.
>Some of them after each code action.
>This plugin follows the strategy to load the sever settings and dictionaries when the LTeX LSP server starts up and then leaves responsibility of keeping the current (language) configuration to the LSP server. 
>Settings are automatically written to disk when the buffer is closed.
>Convenience functions allow the user to manually read/write settings from/to disk.

## Requirements

- [ltex-ls-plus](https://github.com/ltex-plus/ltex-ls-plus)
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
Then call `ltex-utils.on_attach(bufnr)` from the `on_attach` function of your server.
For example, with [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig) this could look like follows:
```lua
require("lspconfig").ltex.setup({
    capabilities = your_capabilities,
    on_attach = function(client, bufnr)
        -- your other on_attach code
        -- for example, set keymaps here, like
        -- vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
        -- (see below code block for more details)
        require("ltex-utils").on_attach(bufnr)
    end,
    settings = {
        ltex = { your settings },
    },
})
```
Check the [nvim-lspconfig suggested configuration](https://github.com/neovim/nvim-lspconfig#suggested-configuration) for further details on how to set keybindings.

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
        dictionary = {
            -- Path to the directory where dictionaries are stored.
            -- Defaults to the Neovim cache directory.
            path = vim.api.nvim_call_function("stdpath", {"cache"}) .. "/ltex/",
            ---Returns the dictionary file name for given language `lang`
            filename = function(lang)
                return lang .. ".txt"
            end,
            -- use vim internal dictionary to add unkown words
            use_vim_dict = false,
            -- show/suppress vim command output such as `spellgood` or `mkspell`
            vim_cmd_output = false,
        },
        rule_ui = {
            -- key to modify rule
            modify_rule_key = "<CR>",
            -- key to delete rule
            delete_rule_key = "d",
            -- key to cleanup deprecated rules
            cleanup_rules_key = "c",
            -- key to jump to respective place in file
            goto_key = "g",
            -- enable line numbers in preview window
            previewer_line_number = true,
            -- wrap lines in preview window
            previewer_wrap = true,
            -- options for creating new telescope windows
            telescope = { bufnr = 0 },
        },
        diagnostics = {
            -- time to wait for language tool to complete parsing document
            -- debounce time in milliseconds
            debounce_time_ms = 500,
            -- use diagnostics data for modifying hiddenFalsePositives rules
            diags_false_pos = true,
            -- use diagnostics data for modifying disabledRules rules
            diags_disable_rules = true,
        },
        -- set the ltex-ls ("ltex") or ltex-ls-plus backend ("ltex_plus")
        backend = "ltex_plus",
    },
},
```
When the `use_vim_dict` option is set to `true`, the configuration settings `path` and `filename` are automatically assigned the following default values:

```lua
dictionary = {
    path = vim.fn.stdpath("config") .. "/spell/",
    filename = function(lang)
        return string.match(lang, "^(%a+)-") .. "." ..
        vim.api.nvim_buf_get_option(0, "fileencoding") ..
        ".add"
    end,
}
```

You can overwrite this behaviour by setting these options yourself.

When `use_vim_dict` is enabled, the plugin uses vim's internal functions to manage dictionaries.
For example:
* The 'Add word to dictionary' code actions uses vim's `spellgood` command to add new words into the internal dictionary.
* `LTeXUtils modify_dict` runs `mkspell` upon exit.

This configuration can be advantageous if you prefer to use a single dictionary for both `ltex-ls-plus` and vim's built-in spell checker.

Alternatively, if you want more control over the dictionary, you may set `use_vim_dict` to `false` while configuring `path` and `filename` to update vim's internal dictionary for additional words accordingly.
Please note that in this case, you will be required to manually execute the `mkspell` command.

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

To switch the display of the LTeX LSP server's diagnostics between 'on' and 'off' use `:LTeXUtils toggle_diagnostics`.

More details can be found in the [tutorial](TUTORIAL.md).

## Caveats

If you frequently use the 'Hide False Positive' code action, be mindful that changes to the manuscript may render these rules obsolete.
Accumulating outdated rules can clutter the `hiddenFalsePositives` list, as LTeX doesn't clean them up automatically.


To avoid this, use 'Hide False Positive' sparingly or manually remove obsolete rules through `:LTeXUtils modify_hiddenFalsePositives`.
Direct modification of `the your_file_ltex.json` settings file is not advised.
Using regular expressions for `hiddenFalsePositives` could help prevent clutter in your hidden false positives list.
However, bear in mind that hidden false positive rules hide the entire sentence and might not yield the expected behaviour.
An in-depth explanation is available in the [tutorial](TUTORIAL.md).

