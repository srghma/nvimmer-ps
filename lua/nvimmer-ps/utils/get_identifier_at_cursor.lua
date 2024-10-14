-- Function to get the identifier at cursor
-- if cursor is at `N` inside of `leftSide _ = M.Nothing` it will return `{ module = "M", identifier = "Nothing" }`
-- if cursor is at `N` inside of `leftSide _ = Nothing` it will return `{ identifier = "Nothing" }`
-- if cursor is at `N` inside of `leftSide _ = A.M.Nothing` it will return `{ module = "A.M", identifier = "Nothing" }`
-- if cursor is at `N` inside of `leftSide _ = A.M.Nothing.somefung` it will return `{ module = "A.M", identifier = "Nothing" }`
--
-- to test :lua =require("nvimmer-ps.utils.get_identifier_at_cursor")()
local function get_identifier_at_cursor()
	-- Get the current line and cursor position
	local line = vim.fn.getline(".")
	local col = vim.fn.col(".") - 1 -- Adjust for 0-based index

	-- Find the start and end of the identifier at the cursor position
	local start_pos = col
	local end_pos = col

	-- Move backwards to find the start of the identifier
	while
		start_pos > 0
		and (line:sub(start_pos, start_pos):match("[%w%.]") or line:sub(start_pos, start_pos) == "_")
	do
		start_pos = start_pos - 1
	end

	-- Move forwards to find the end of the identifier
	while
		end_pos < #line
		and (
			line:sub(end_pos + 1, end_pos + 1):match("%w") or line:sub(end_pos + 1, end_pos + 1) == "_"
		)
	do
		end_pos = end_pos + 1
	end

	-- Get the complete identifier from the line
	local full_identifier = line:sub(start_pos + 1, end_pos)

	-- Split the identifier to handle qualified identifiers
	local parts = vim.split(full_identifier, "%.")

	-- Handle cases with module names
	if #parts > 1 then
		local identifier = parts[#parts]
		table.remove(parts, #parts)
		local module = table.concat(parts, ".")
		return { module = module, identifier = identifier }
	else
		return { identifier = full_identifier }
	end
end

return get_identifier_at_cursor
