# nvimmer-ps

a neovim plugin for PureScript that supplements the built-in purescript-language-server

# HOW TO INSTALL

```lua
-- lazy.nvim
{
  "srghma/nvimmer-ps",
  dependencies = {
    "nvim-lua/plenary.nvim",     -- Add plenary.nvim as a dependency
    "nvim-telescope/telescope.nvim", -- Add telescope.nvim as a dependency
  },
  config = function()
    -- or require("nvimmer-ps").setup({ keymaps = { ... } })
    require("nvimmer-ps").setup()
    
		local nvim_lsp = require("lspconfig")
		nvim_lsp.purescriptls.setup({
			on_attach = function(client, bufnr)
				require("nvimmer-ps").setup_on_attach(client, bufnr)
			end,
			on_init = function(client)
				require("nvimmer-ps").setup_on_init(client)
			end,
			flags = {
				debounce_text_changes = 150,
			},
			settings = {
				purescript = {
					formatter = "purs-tidy",
					addSpagoSources = true,
				},
			},
		})
  end,
}
```

OR check https://github.com/AstroNvim/astrocommunity/pull/1222

OR check `./nvim-config-test.lua` (can be run with `nvim --clean -u ./nvim-config-test.lua ~/projects/purescript-pathy-node/src/Pathy/Node/OS.purs`)


# Commands


| Keystroke | Command Function | Description |
| --- | --- | --- |
| `<space>am` | `add_import()` | Show list of available modules from spago, `enter` to add import |
| `<space>ae` | `add_explicit_import()` | Will get current symbol, show modules that contain it, enter to add import |
| `<space>asi` | `search_pursuit()` | Search identifier under cursor, all 3 types (declarations, packages, modules), `enter` to open in browser, `ctrl+i` to add import statement (but if package - open in browser) |
| `<space>asm` | `search_pursuit_modules()` | Search modules in Pursuit, like `search_pursuit`, but filters only modules, and shows different UI, same keybindings |
| `<space>ac` | `case_split()` | Case split ([TODO: doesnt work in vscode too](https://github.com/nwolverson/vscode-ide-purescript/issues/224)) |
| `<space>aa` | `add_clause()` | Add clause (generate function from a type of function) |
| `<space>alb` | `build()` | Build |
| `<space>als` | `start()` | Start |
| `<space>alt` | `stop()` | Stop |
| `<space>alr` | `restart()` | Restart |


# Intercepted  

Also, it intercepts `purescript.typedHole` command FROM purescript-language-server:

Example: You have code `leftSide _ = ?asdf`, You apply `code action` from lsp (`<leader>la` in astronvim), You choose `Apply typed hole suggestion` - This plugin will render telescope picker with list of typed hole suggestions and you can select one to apply.

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/vhbRcSjSBJI/0.jpg)](https://www.youtube.com/watch?v=vhbRcSjSBJI)

# Contribute

`./spec` tests dont work yet
