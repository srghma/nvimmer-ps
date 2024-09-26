<!-- LTeX: enabled=false -->

# nvim-various-textobjs-movements 🟪🔷🟡

<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/srghma/nvim-various-textobjs-movements">
<img alt="badge" src="https://dotfyle.com/plugins/srghma/nvim-various-textobjs-movements/shield"/></a>

## Installation

**Variant 1:** Have `nvim-various-textobjs-movements` set up all the keybindings from the
table above for you.

```lua
-- lazy.nvim
{
	"srghma/nvim-various-textobjs-movements",
	event = "UIEnter",
	opts = {
		go_to_indentation_top_withBlanks = "K",
		go_to_indentation_bottom_withBlanks = "J",
		go_to_indentation_top_noBlanks = "<C-M-k>",
		go_to_indentation_bottom_noBlanks = "<C-M-j>",
	},
}

-- packer
use {
	"srghma/nvim-various-textobjs-movements",
	config = function ()
		require("various-textobjs-movements").setup({
			go_to_indentation_top_withBlanks = "K",
			go_to_indentation_bottom_withBlanks = "J",
			go_to_indentation_top_noBlanks = "<C-M-k>",
			go_to_indentation_bottom_noBlanks = "<C-M-j>",
		})
	end,
}
```

## Configuration

### Options

The `.setup()` call is optional if you are fine with the defaults below.

```lua
-- default config
require("various-textobjs-movements").setup {
	go_to_indentation_top_withBlanks = "K",
	go_to_indentation_bottom_withBlanks = "J",
	go_to_indentation_top_noBlanks = "<C-M-k>",
	go_to_indentation_bottom_noBlanks = "<C-M-j>",
}
```

## Credits

**Thanks**

-   https://github.com/chrisgrieser/nvim-various-textobjs/
