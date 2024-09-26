local M = {}

-- Helper function to print inspection results to a file (for debugging)
local function print_inspect_to_file(data)
	local filepath = "/tmp/purescript_lsp_debug.log"
	local inspected_data = vim.inspect(data) .. "\n"
	local file = io.open(filepath, "a")
	if not file then
		print("Could not open file for writing: " .. filepath)
		return
	end
	file:write(inspected_data)
	file:close()
end

-- Function to request a command from the PureScript language server
local function request_command(command, arguments, callback)
	local clients = vim.lsp.get_clients({ name = "purescriptls" })
	for _, client in ipairs(clients) do
		client.request("workspace/executeCommand", {
			command = command,
			arguments = arguments,
		}, function(err, result, ctx)
			print_inspect_to_file({ err = err, result = result, ctx = ctx })
			if callback then
				callback(err, result, ctx)
			end
		end)
	end
end

-- Function to get the identifier at cursor
local function get_identifier_at_cursor()
	local word = vim.fn.expand('<cword>') -- You might want to implement more sophisticated logic here
	-- to determine if the word is a qualified import
	local parts = vim.split(word, '%.')
	if #parts > 1 then
		return { module = table.concat(parts, '.', 1, #parts - 1), identifier = parts[#parts] }
	else
		return { identifier = word }
	end
end

-- Papply command
function M.apply_code_action()
	vim.lsp.buf.code_action()
end

function M.add_import(...)
	local args = { ... }
	local name = #args == 0 and vim.fn.expand('<cword>') or args[1]
	local module = args[2] or vim.NIL

	request_command('purescript.addCompletionImport',
		{ name, module, vim.NIL, 'file://' .. vim.fn.expand('%:p') },
		function(err, result)
			if err then
				print("Error adding import: " .. vim.inspect(err))
				return
			end
			if result and type(result) == "table" then
				-- Handle ambiguous imports using vim.ui.select
				vim.ui.select(result, {
					prompt = "Select import:",
					format_item = function(item) return item end,
				}, function(choice)
					if choice then
						M.add_import(name, choice)
					end
				end)
			end
		end
	)
end

function M.add_module_import()
	-- First, get available modules
	request_command('purescript.getAvailableModules', {}, function(err, modules)
		if err then
			print("Error getting available modules: " .. vim.inspect(err))
			return
		end

		-- Allow user to select a module
		vim.ui.select(modules, {
			prompt = "Select module to import:",
			format_item = function(item) return item end,
		}, function(selected_module)
			if not selected_module then return end

			-- Get the current file's URI
			local uri = vim.uri_from_bufnr(0)

			-- Get the identifier at cursor
			local at_cursor = get_identifier_at_cursor()
			local qualifier = at_cursor.module or vim.NIL

			-- Add the module import
			request_command('purescript.addModuleImport',
				{ selected_module, qualifier, uri },
				function(add_err, add_result)
					if add_err then
						print("Error adding module import: " .. vim.inspect(add_err))
					else
						print("Module import added successfully")
					end
				end
			)
		end)
	end)
end

-- Pbuild command
function M.build()
	request_command('purescript.build', {})
end

-- Pstart command
function M.start()
	request_command('purescript.startPscIde', {})
end

-- Pend command
function M.stop()
	request_command('purescript.stopPscIde', {})
end

-- Prestart command
function M.restart()
	request_command('purescript.restartPscIde', {})
end

-- Psearch command
function M.search(identifier)
	request_command('purescript.search', { identifier },
		function(err, result)
			if err then
				print("Error searching: " .. vim.inspect(err))
				return
			end
			if result and type(result) == "table" then
				local lines = {}
				for _, item in ipairs(result) do
					table.insert(lines, string.format("module %s where", item.mod))
					table.insert(lines, string.format("  %s :: %s", item.identifier, item.typ))
					table.insert(lines, "")
				end
				-- You might want to implement a custom preview function here
				-- For now, we'll just print the results
				print(table.concat(lines, "\n"))
			else
				print("No results found")
			end
		end
	)
end

-- addIdentImport command
function M.add_ident_import()
	local uri = vim.uri_from_bufnr(0)
	local at_cursor = get_identifier_at_cursor()
	local default_ident = at_cursor.identifier or ""
	local qualifier = at_cursor.module

	vim.ui.input({
		prompt = "Identifier: ",
		default = default_ident
	}, function(ident)
		if not ident or ident == "" then return end
		M.add_ident_import_mod(ident, qualifier, uri)
	end)
end

function M.add_ident_import_mod(ident, qualifier, uri, mod)
	request_command('purescript.addCompletionImport',
		{ ident, mod or vim.NIL, qualifier or vim.NIL, uri },
		function(err, result)
			if err then
				print("Error adding import: " .. vim.inspect(err))
				return
			end
			if result and type(result) == "table" and #result > 0 then
				-- Multiple modules provide this identifier, let user choose
				vim.ui.select(result, {
					prompt = "Select module for " .. ident .. ":",
					format_item = function(item) return item end,
				}, function(selected_mod)
					if selected_mod then
						M.add_ident_import_mod(ident, qualifier, uri, selected_mod)
					end
				end)
			else
				print("Import added successfully")
			end
		end
	)
end

-- Pcommand command
function M.execute_command(...)
	local args = { ... }
	local command = table.remove(args, 1)
	request_command(command, args,
		function(err, result)
			if err then
				print("Error executing command: " .. vim.inspect(err))
			else
				print("Command executed successfully")
				print_inspect_to_file(result)
			end
		end
	)
end

-----------------
--- https://github.com/nwolverson/vscode-ide-purescript/blob/7f1f8104b3572c42c8207d5a224dd14c229e9bbb/src/IdePurescript/VSCode/Assist.purs

-- Function to get active position info
local function get_active_pos_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local winnr = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(winnr)
	local uri = vim.uri_from_bufnr(bufnr)

	return {
		pos = { line = cursor[1] - 1, character = cursor[2] },
		uri = uri,
		bufnr = bufnr
	}
end

-- Case Split command
function M.case_split()
	local info = get_active_pos_info()
	vim.ui.input({ prompt = "Parameter type: " }, function(ty)
		if ty then
			request_command('purescript.caseSplit',
				{ info.uri, info.pos.line, info.pos.character, ty },
				function(err, result)
					if err then
						print("Error in case split: " .. vim.inspect(err))
					else
						print("Case split applied successfully")
					end
				end
			)
		end
	end)
end

-- Add Clause command
function M.add_clause()
	local info = get_active_pos_info()
	request_command('purescript.addClause',
		{ info.uri, info.pos.line, info.pos.character },
		function(err, result)
			if err then
				print("Error adding clause: " .. vim.inspect(err))
			else
				print("Clause added successfully")
			end
		end
	)
end

-- Typed Hole command
-- function M.typed_hole(args)
-- 	if #args < 3 then
-- 		print("Insufficient arguments for typed hole")
-- 		return
-- 	end
--
-- 	local name = args[1]
-- 	local uri = args[2]
-- 	local range = args[3]
-- 	local type_infos = vim.list_slice(args, 4)
--
-- 	local items = {}
-- 	for _, info in ipairs(type_infos) do
-- 		table.insert(items, {
-- 			description = info.module,
-- 			detail = info.type,
-- 			label = info.identifier
-- 		})
-- 	end
--
-- 	vim.ui.select(items, {
-- 		prompt = "Filter hole suggestions for " .. name,
-- 		format_item = function(item)
-- 			return string.format("%s: %s (%s)", item.label, item.detail, item.description)
-- 		end
-- 	}, function(choice, idx)
-- 		if choice then
-- 			request_command('purescript.typedHole-explicit',
-- 				{ name, uri, range, type_infos[idx] },
-- 				function(err, result)
-- 					if err then
-- 						print("Error applying typed hole suggestion: " .. vim.inspect(err))
-- 					else
-- 						print("Typed hole suggestion applied successfully")
-- 					end
-- 				end
-- 			)
-- 		end
-- 	end)
-- end

---------------------------
-- Helper function to parse hole information
local function parse_hole_info(info)
	local name = info:match("Hole '(%w+)' inferred type:")
	local suggestions = {}

	for suggestion in info:gmatch("(%w+)%s+::%s+([%w%s%.%->%(%)]+)%s+%-%s+(%w+)") do
		local identifier, type, module = suggestion:match("(%w+)%s+::%s+([%w%s%.%->%(%)]+)%s+%-%s+(%w+)")
		table.insert(suggestions, { identifier = identifier, type = type, module = module })
	end

	return name, suggestions
end

-- Helper function to apply hole suggestion
local function apply_hole_suggestion(name, suggestion)
	local params = vim.lsp.util.make_position_params()
	params.context = { triggerKind = 1 } -- Invoked manually

	vim.lsp.buf_request(0, 'textDocument/completion', params, function(err, result, _, _)
		if err or not result or #result.items == 0 then
			print("Error applying suggestion: " .. vim.inspect(err or "No completion items"))
			return
		end

		-- Find the matching completion item
		local completion_item
		for _, item in ipairs(result.items) do
			if item.label == suggestion.identifier then
				completion_item = item
				break
			end
		end

		if not completion_item then
			print("Could not find matching completion item")
			return
		end

		-- Apply the completion
		vim.lsp.util.apply_text_edit(completion_item.textEdit, 0)
		print("Applied suggestion: " .. suggestion.identifier)
	end)
end
-- Typed Hole command
function M.typed_hole()
	local params = vim.lsp.util.make_position_params()

	vim.lsp.buf_request(0, 'textDocument/hover', params, function(err, result, _, _)
		if err or not result or not result.contents then
			print("Error getting hole information: " .. vim.inspect(err or "No result"))
			return
		end

		local hole_info = result.contents
		if type(hole_info) == "table" then
			hole_info = hole_info.value or hole_info[1].value
		end

		-- Parse the hole information
		local name, suggestions = parse_hole_info(hole_info)

		if not name or #suggestions == 0 then
			print("No valid hole information found")
			return
		end

		-- Present suggestions to the user
		vim.ui.select(suggestions, {
			prompt = "Select suggestion for hole " .. name .. ":",
			format_item = function(item)
				return string.format("%s: %s (%s)", item.identifier, item.type, item.module)
			end
		}, function(choice)
			if choice then
				-- Apply the selected suggestion
				apply_hole_suggestion(name, choice)
			end
		end)
	end)
end

return M
