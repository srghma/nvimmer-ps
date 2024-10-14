local get_identifier_at_cursor = require("nvimmer-ps.utils.get_identifier_at_cursor")
local M = {}

-- Helper function to print inspection results to a file (for debugging)
local function print_inspect_to_file(data)
	local filepath = "/tmp/purescript_lsp_debug.log"
	local file = io.open(filepath, "a")
	if not file then
		print("Could not open file for writing: " .. filepath)
		return
	end
	file:write(vim.inspect(data) .. "\n")
	file:close()
end

-- Function to request a command from the PureScript language server
local function request_command(command, arguments, callback)
	local clients =
			vim.lsp.get_clients { name = "purescriptls", bufnr = vim.api.nvim_get_current_buf() }
	if #clients == 0 then
		print("No active clients for purescriptls")
		return
	end

	for _, client in ipairs(clients) do
		print_inspect_to_file {
			command = command or "No command",
			arguments = arguments or "No arguments",
		}

		client.request("workspace/executeCommand", {
			command = command,
			arguments = arguments,
		}, function(err, result, ctx)
			print_inspect_to_file {
				err = err or "No error",
				result = result or "No result",
				ctx = ctx or "No context",
			}
			if err then print("Error in request_command: " .. vim.inspect(err)) end
			if callback then callback(err, result, ctx) end
		end)
	end
end

function M.add_import()
	-- First, get available modules
	request_command("purescript.getAvailableModules", {}, function(err, modules)
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
			request_command(
				"purescript.addModuleImport",
				{ selected_module, qualifier, uri },
				function(add_err, _add_result)
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

function M.build() request_command("purescript.build", {}) end

function M.start() request_command("purescript.startPscIde", {}) end

function M.stop() request_command("purescript.stopPscIde", {}) end

function M.restart() request_command("purescript.restartPscIde", {}) end

-- addIdentImport command
function M.add_explicit_import()
	local uri = vim.uri_from_bufnr(0)
	local at_cursor = get_identifier_at_cursor()
	local default_ident = at_cursor.identifier or ""
	local qualifier = at_cursor.module or nil
	local module = nil
	local namespace = ""

	vim.ui.input({
		prompt = "Identifier: ",
		default = default_ident,
	}, function(ident)
		if not ident or ident == "" then return end

		request_command(
			"purescript.addCompletionImport",
			{ ident, module, qualifier, uri, namespace },
			function(err, result)
				if err then
					print("Error adding import: " .. vim.inspect(err))
					return
				end
				if result and type(result) == "table" and #result > 0 then
					-- Multiple modules provide this identifier, let user choose
					require("telescope.builtin").find_files {
						prompt_title = "Select module for " .. ident .. ":",
						find_command = { "echo", unpack(result) },
						attach_mappings = function(prompt_bufnr, map)
							map("i", "<CR>", function()
								local selection = require("telescope.actions.state").get_selected_entry()
								require("telescope.actions").close(prompt_bufnr)
								if selection then M.add_ident_import_mod(ident, qualifier, uri, selection.value) end
							end)
							return true
						end,
					}
				else
					print("Import added successfully")
				end
			end
		)
	end)
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
		bufnr = bufnr,
	}
end

-- Case Split command
-- TODO: SOME ERROR in the LSP, DOESNT WORK
function M.case_split()
	vim.ui.input({ prompt = "Parameter type: " }, function(ty)
		if not ty then
			print("No type provided")
			return
		end

		local info = get_active_pos_info()
		request_command(
			"purescript.caseSplit-explicit",
			{ info.uri, info.pos.line, info.pos.character, ty },
			function(err, _result)
				if err then
					print("Error in case split: " .. vim.inspect(err))
					return
				end
				print("Case split applied successfully")
			end
		)
	end)
end

-- Add Clause command
function M.add_clause()
	local info = get_active_pos_info()
	request_command(
		"purescript.addClause-explicit",
		{ info.uri, info.pos.line, info.pos.character },
		function(err, _result)
			if err then
				print("Error adding clause: " .. vim.inspect(err))
			else
				print("Clause added successfully")
			end
		end
	)
end

function M.setup_on_init(client)
	client.commands["purescript.typedHole"] = function(command, _ctx)
		local hole_name, uri, range = unpack(command.arguments)
		local type_infos = { select(4, unpack(command.arguments)) }

		vim.validate {
			hole_name = { hole_name, "s" },
			uri = { uri, "s" },
			range = { range, "t" },
			type_infos = { type_infos, "t" },
		}

		for _, type_info in ipairs(type_infos) do
			vim.validate {
				-- example:
				--
				-- declarationType = vim.empty_dict(),
				-- definedAt = vim.empty_dict(),
				-- documentation = vim.empty_dict(),
				-- expandedType = { value0 = "∀ (@f ∷ Type -> Type) (a ∷ Type). Plus f ⇒ f a" },
				-- exportedFrom = { "Control.Plus" },
				-- identifier = "empty",
				-- ["module'"] = "Control.Plus",
				-- ["type'"] = "∀ (@f ∷ Type -> Type) (a ∷ Type). Plus f ⇒ f a"

				declarationType = { type_info.declarationType, "t" },
				definedAt = { type_info.definedAt, "t" },
				documentation = { type_info.documentation, "t" },
				expandedType = { type_info.expandedType, "t" },
				exportedFrom = { type_info.exportedFrom, "t" },
				identifier = { type_info.identifier, "s" },
				["module'"] = { type_info["module'"], "s" },
				["type'"] = { type_info["type'"], "s" },
			}
		end

		-- Use Telescope to display the suggestions
		require("telescope.pickers")
				.new({}, {
					prompt_title = "Select Typed Hole Suggestions for " .. hole_name,
					finder = require("telescope.finders").new_table {
						results = type_infos,
						entry_maker = function(type_info)
							return {
								value = type_info,
								display = function()
									-- Format the display for each entry
									local lines = {
										string.format("Identifier: %s", type_info.identifier),
										string.format("From: %s", type_info["module'"]),
										string.format("Type: %s", type_info["type'"]),
									}
									if type_info.documentation then
										table.insert(lines, string.format("Documentation: %s", type_info.documentation))
									end
									return table.concat(lines, "\n")
								end,
								ordinal = type_info.identifier, -- For sorting
							}
						end,
					},
					attach_mappings = function(_, map)
						map("i", "<CR>", function(prompt_bufnr)
							local selection = require("telescope.actions.state").get_selected_entry()
							require("telescope.actions").close(prompt_bufnr)

							-- Call the typedHole-explicit command with the selected choice
							request_command(
								"purescript.typedHole-explicit",
								{ selection.value.identifier, uri, range, selection.value },
								function(err, result)
									if err then
										print("Error applying typed hole suggestion: " .. vim.inspect(err))
									else
										print("Typed hole suggestion applied successfully" .. vim.inspect(result))
									end
								end
							)
						end)
						return true
					end,
				})
				:find()
	end
end

function M.setup_on_attach(_client, bufnr)
	vim.lsp.set_log_level("debug")

	local function set_keymap(mode, key, command, desc)
		vim.api.nvim_buf_set_keymap(
			bufnr,
			mode,
			key,
			command,
			{ noremap = true, silent = true, desc = desc }
		)
	end

	-- m for import module
	set_keymap(
		"n",
		"<space>am",
		'<Cmd>lua require("nvimmer-ps").add_import()<CR>',
		"Purescript: Show list of available modules, enter to import"
	)
	set_keymap(
		"n",
		"<space>ae",
		'<Cmd>lua require("nvimmer-ps").add_explicit_import()<CR>',
		"Purescript: Will get current symbol, allow change it, show modules that contain it, enter to import"
	)
	set_keymap(
		"n",
		"<space>asi",
		'<Cmd>lua require("nvimmer-ps").search_pursuit()<CR>',
		"Purescript: Search identifier under cursor"
	)
	set_keymap(
		"n",
		"<space>asm",
		'<Cmd>lua require("nvimmer-ps").search_pursuit_modules()<CR>',
		"Purescript: Search modules in Pursuit"
	)
	set_keymap(
		"n",
		"<space>ac",
		'<Cmd>lua require("nvimmer-ps").case_split()<CR>',
		"Purescript: Case split"
	)
	set_keymap(
		"n",
		"<space>aa",
		'<Cmd>lua require("nvimmer-ps").add_clause()<CR>',
		"Purescript: Add clause"
	)

	-- prefix + l for language server + ...
	set_keymap("n", "<space>alb", '<Cmd>lua require("nvimmer-ps").build()<CR>', "Purescript: Build")
	set_keymap("n", "<space>als", '<Cmd>lua require("nvimmer-ps").start()<CR>', "Purescript: Start")
	set_keymap("n", "<space>alt", '<Cmd>lua require("nvimmer-ps").stop()<CR>', "Purescript: Stop")
	set_keymap(
		"n",
		"<space>alr",
		'<Cmd>lua require("nvimmer-ps").restart()<CR>',
		"Purescript: Restart"
	)
end

-- Function to search Pursuit
function M.search_pursuit()
	vim.ui.input({ prompt = "Search Pursuit: " }, function(search_term)
		if not search_term or search_term == "" then return end

		request_command("purescript.search", { search_term }, function(err, results)
			if err then
				print("Error searching Pursuit: " .. vim.inspect(err))
				return
			end

			if results and type(results) == "table" then
				for _, item in ipairs(results) do
					local mod = item.info.mod or "Unknown Module"
					local title = item.info.title or "Unknown Title"
					local text = item.text or "No Description"
					print(string.format("Module: %s, Title: %s, Description: %s", mod, title, text))

					-- Issue the import command for the found module
					request_command("purescript.addModuleImport", { mod, nil, vim.uri_from_bufnr(0) },
						function(add_err)
							if add_err then
								print("Error adding module import: " .. vim.inspect(add_err))
							else
								print("Module import added successfully: " .. mod)
							end
						end)
				end
			else
				print("No results found")
			end
		end)
	end)
end

-- Function to search Pursuit modules
function M.search_pursuit_modules()
	vim.ui.input({ prompt = "Search Pursuit Modules: " }, function(search_term)
		if not search_term or search_term == "" then return end

		request_command("purescript.search", { search_term }, function(err, results)
			if err then
				print("Error searching Pursuit modules: " .. vim.inspect(err))
				return
			end

			if results and type(results) == "table" then
				for _, item in ipairs(results) do
					local mod = item.info.mod or "Unknown Module"
					local package = item.package or "Unknown Package"
					print(string.format("Module: %s, Package: %s", mod, package))

					-- Issue the import command for the found module
					request_command("purescript.addModuleImport", { mod, nil, vim.uri_from_bufnr(0) },
						function(add_err)
							if add_err then
								print("Error adding module import: " .. vim.inspect(add_err))
							else
								print("Module import added successfully: " .. mod)
							end
						end)
				end
			else
				print("No results found")
			end
		end)
	end)
end

return M
