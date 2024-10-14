-- Function to get the identifier at cursor
-- if cursor is at `N` inside of `leftSide _ = M.Nothing` it will return `{ module = "M", identifier = "Nothing" }`
-- if cursor is at `N` inside of `leftSide _ = Nothing` it will return `{ identifier = "Nothing" }`
-- if cursor is at `N` inside of `leftSide _ = A.M.Nothing` it will return `{ module = "A.M", identifier = "Nothing" }`
-- if cursor is at `N` inside of `leftSide _ = A.M.Nothing.somefung` it will return `{ module = "A.M", identifier = "Nothing" }`
local function get_identifier_at_cursor()
	-- Get the current line and cursor position
	local line = vim.fn.getline(".")
	local col = vim.fn.col(".") - 1 -- Adjust for 0-based index

	-- Find the start and end of the word (identifier) at the cursor position
	local start_pos = col
	local end_pos = col

	-- Move backwards to find the start of the word
	while start_pos > 0 and line:sub(start_pos, start_pos):match("%w") do
		start_pos = start_pos - 1
	end

	-- Move forwards to find the end of the word
	while end_pos < #line and line:sub(end_pos + 1, end_pos + 1):match("%w") do
		end_pos = end_pos + 1
	end

	-- Get the complete word (identifier) from the line
	local word = line:sub(start_pos + 1, end_pos + 1)

	-- Split the word to handle qualified identifiers
	local parts = vim.split(word, "%.")
	if #parts > 1 then
		return { module = table.concat(parts, ".", 1, #parts - 1), identifier = parts[#parts] }
	else
		return { identifier = word }
	end
end

return get_identifier_at_cursor
