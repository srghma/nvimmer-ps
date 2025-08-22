-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo,
		lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out,                            "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		{
			-- "srghma/nvimmer-ps",
			dir = "/home/srghma/projects/nvimmer-ps",
			config = function()
				print('nvimmer-ps loaded')
				require("nvimmer-ps").setup()
			end,
			dependencies = {
				"nvim-lua/plenary.nvim",     -- Add plenary.nvim as a dependency
				"nvim-telescope/telescope.nvim", -- Add telescope.nvim as a dependency
			},
		},
		{
			"neovim/nvim-lspconfig",
			config = function()
				print('neovim/nvim-lspconfig loaded')
				local nvim_lsp = require("lspconfig")
				nvim_lsp.purescriptls.setup({
					on_attach = function(client, bufnr)
						print('nvimmer-ps on_attach')
						require("nvimmer-ps").setup_on_attach(client, bufnr)
					end,
					on_init = function(client)
						print('nvimmer-ps on_init')
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
		},
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})

vim.filetype.add({
	extension = {
		purs = "purescript"
	}
})
