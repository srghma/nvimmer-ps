local _MODREV, _SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "nvimmer-ps"
version = _MODREV .. _SPECREV

test_dependencies = {
	-- "lua >= 5.1",
	"plenary.nvim",
	"nlua",
}

source = {
	url = "git://github.com/srghma/" .. package,
}

-- build = {
-- 	type = "builtin",
-- 	-- type = "busted",
-- }
