# nvimmer-ps

a neovim plugin for PureScript that supplements the built-in purescript-language-server

it adds purescript related commands like


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


-----

Also, it intercepts `purescript.typedHole` command FROM purescript-language-server:

Example: You have code `leftSide _ = ?asdf`, You apply `code action` from lsp (`<leader>ca`), You choose `Apply typed hole suggestion` - This plugin will render telescope picker with list of typed hole suggestions and you can select one to apply.



# Contribute

`./spec` tests dont work yet
