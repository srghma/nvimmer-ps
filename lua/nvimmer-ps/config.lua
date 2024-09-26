local M = {}
--------------------------------------------------------------------------------
---@class config
---@field lookForwardSmall? number
---@field lookForwardBig? number
---@field useDefaultKeymaps? boolean
---@field disabledKeymaps? string[]
---@field notifyNotFound? boolean

---@type config
local defaultConfig = {
	go_to_indentation_top_withBlanks = "K",
	go_to_indentation_bottom_withBlanks = "J",
	go_to_indentation_top_noBlanks = "<C-M-k>",
	go_to_indentation_bottom_noBlanks = "<C-M-j>",
}
M.config = defaultConfig

---optional setup function
---@param userConfig? config
function M.setup(userConfig)
	M.config = vim.tbl_deep_extend("force", M.config, userConfig or {})

	if M.config.useDefaultKeymaps then
		require("various-textobjs.default-keymaps").setup(M.config)
	end
end

--------------------------------------------------------------------------------
return M
