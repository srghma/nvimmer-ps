local get_identifier_at_cursor = require("nvimmer-ps.utils.get_identifier_at_cursor")

describe("Test example", function()
	it("Test can access vim namespace", function()
		assert(vim, "Cannot access vim namespace")
		assert.are.same(vim.trim("  a "), "a")
	end)
	it(
		"Test can access plenary.nvim dependency",
		function() assert(require("plenary"), "Could not access plenary") end
	)
	it(
		"Test can access module in lua/testproject",
		function() assert(require("nvimmer-ps"), "Could not access main module") end
	)
end)

-- -- Import necessary modules (if using busted or similar)
-- -- local busted = require('busted')
-- -- local get_identifier_at_cursor = require('your_module').get_identifier_at_cursor
--
-- -- Mock vim functions for testing
-- local vim = {
-- 	fn = {
-- 		getline = function(line) return "leftSide _ = " .. line end,
-- 		col = function() return 10 end, -- Adjust as necessary for your tests
-- 	},
-- }
--
-- -- Function to set the cursor and simulate getting the identifier
-- local function test_get_identifier(line, cursor_pos)
-- 	vim.fn.getline = function() return line end
-- 	vim.fn.col = function() return cursor_pos end
-- 	return get_identifier_at_cursor()
-- end
--
-- describe("get_identifier_at_cursor", function()
-- 	it("returns the correct module and identifier for M.Nothing", function()
-- 		local result = test_get_identifier("M.Nothing", 12) -- Cursor on 'N'
-- 		assert.are.same(result, { module = "M", identifier = "Nothing" })
-- 	end)
--
-- 	it("returns the correct identifier for Nothing", function()
-- 		local result = test_get_identifier("Nothing", 9) -- Cursor on 'N'
-- 		assert.are.same(result, { identifier = "Nothing" })
-- 	end)
--
-- 	it("returns the correct module and identifier for A.M.Nothing", function()
-- 		local result = test_get_identifier("A.M.Nothing", 14) -- Cursor on 'N'
-- 		assert.are.same(result, { module = "A.M", identifier = "Nothing" })
-- 	end)
--
-- 	it("returns the correct module and identifier for A.M.Nothing.somefunc", function()
-- 		local result = test_get_identifier("A.M.Nothing.somefunc", 14) -- Cursor on 'N'
-- 		assert.are.same(result, { module = "A.M", identifier = "Nothing" })
-- 	end)
--
-- 	it("returns the correct module and identifier for complex identifier", function()
-- 		local result = test_get_identifier("M.Nothing.someFunc", 12) -- Cursor on 'N'
-- 		assert.are.same(result, { module = "M", identifier = "Nothing" })
-- 	end)
-- end)
