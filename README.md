# nvimmer-ps

a neovim plugin for PureScript that supplements the built-in purescript-language-server

it adds purescript related commands like


| Keystroke | Command Function | Description |
| --- | --- | --- |
| `<space>am` | `add_import()` | Show list of available modules, enter to import |
| `<space>ae` | `add_explicit_import()` | Will get current symbol, allow change it, show modules that contain it, enter to import |
| `<space>asi` | `search_pursuit()` | Search identifier under cursor |
| `<space>asm` | `search_pursuit_modules()` | Search modules in Pursuit |
| `<space>ac` | `case_split()` | Case split |
| `<space>aa` | `add_clause()` | Add clause |
| `<space>alb` | `build()` | Build |
| `<space>als` | `start()` | Start |
| `<space>alt` | `stop()` | Stop |
| `<space>alr` | `restart()` | Restart |


-----

Also, it intercepts `purescript.typedHole` command FROM purescript-language-server:

Example: You have code `leftSide _ = ?asdf`, You apply `code action` from lsp (`<leader>ca`), You choose `Apply typed hole suggestion` - This plugin will render telescope picker with list of typed hole suggestions and you can select one to apply.



