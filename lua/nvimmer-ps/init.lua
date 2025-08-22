local get_identifier_at_cursor = require("nvimmer-ps.utils.get_identifier_at_cursor")
local M = {}
local curl = require("plenary.curl")
local previewers = require("telescope.previewers")

-- Helper function to print inspection results to a file (for debugging)
local function print_inspect_to_file(data)
	local filepath = "/tmp/purescript_lsp_debug.log"
	local file = io.open(filepath, "a")
	if not file then
		vim.notify("Could not open file for writing: " .. filepath, vim.log.levels.ERROR)
		return
	end
	file:write(vim.inspect(data) .. "\n")
	file:close()
end

local function open_url(url)
	vim.validate {
		url = { url, "s" },
	}

	local cmd
	if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
		cmd = { "cmd.exe", "/c", "start", '""', url }
	elseif vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 or vim.fn.has("gui_macvim") == 1 then
		cmd = { "open", url }
	else
		cmd = { "xdg-open", url }
	end

	local result = vim.fn.jobstart(cmd, {
		detach = true,
		on_stderr = function(_, data)
			if data and #data > 0 then
				vim.notify("Error opening URL: " .. vim.inspect(data), vim.log.levels.ERROR)
			end
		end,
	})

	if result <= 0 then vim.notify("Failed to open URL: " .. url, vim.log.levels.ERROR) end
end

-- Why not use vim.ui.select?
-- Because if neovim will receive window/showMessageRequest - it will be shown in floating window before showing vim.ui.select window
--
-- by design https://github.com/neovim/neovim/blob/f72dc2b4c805f309f23aff62b3e7ba7b71a554d2/runtime/lua/vim/lsp/handlers.lua#L76
-- TODO: make a pr to purescript-ls to not issue window/showMessageRequest ?
local function my_vim_ui_select(items, opts, callback)
	vim.validate {
		items = { items, "t" },
		opts = { opts, "t" },
		["opts.prompt"] = { opts.prompt, "s" },
		["opts.format_item"] = { opts.format_item, "f" },
		callback = { callback, "f" },
	}

	for _, item in ipairs(items) do
		vim.validate {
			item = { item, "s" },
		}
	end

	require("telescope.pickers")
		.new(opts, {
			results = items,
			prompt_title = opts.prompt,
			finder = require("telescope.finders").new_table {
				results = items,
				entry_maker = function(item)
					local display = opts.format_item(item)
					return { value = item, display = display, ordinal = display }
				end,
			},
			sorter = require("telescope.config").values.generic_sorter {}, -- to have fzf input
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry()
					require("telescope.actions").close(prompt_bufnr)
					callback(selection.value)
				end)
				return true
			end,
		})
		:find()
end

-- Function to request a command from the PureScript language server
local function request_command(command, arguments, callback)
	local clients =
		vim.lsp.get_clients { name = "purescriptls", bufnr = vim.api.nvim_get_current_buf() }
	if #clients == 0 then
		vim.notify("No active clients for purescriptls", vim.log.levels.WARN)
		return
	end

	for _, client in ipairs(clients) do
		print_inspect_to_file("sending command")
		print_inspect_to_file {
			command = command or "No command",
			arguments = arguments or "No arguments",
		}

		client.request("workspace/executeCommand", {
			command = command,
			arguments = arguments,
		}, function(err, result, ctx)
			print_inspect_to_file("received response")
			print_inspect_to_file {
				err = err or "No error",
				result = result or "No result",
				ctx = ctx or "No context",
			}
			if err then
				vim.notify("Error in request_command: " .. vim.inspect(err), vim.log.levels.ERROR)
			end
			if callback then callback(err, result, ctx) end
		end)
	end
end

function M.add_import()
	-- First, get available modules
	request_command("purescript.getAvailableModules", {}, function(err, modules)
		if err then
			vim.notify("Error getting available modules: " .. vim.inspect(err), vim.log.levels.ERROR)
			return
		end

		-- Allow user to select a module
		my_vim_ui_select(modules, {
			prompt = "Select module to import:",
			format_item = function(item) return item end,
		}, function(selected_module)
			if not selected_module then return end

			-- Get the current file's URI
			local uri = vim.uri_from_bufnr(0)

			-- Get the identifier at cursor
			local at_cursor = get_identifier_at_cursor()
			local qualifier = at_cursor.module or nil

			-- Add the module import
			request_command(
				"purescript.addModuleImport",
				{ selected_module, qualifier, uri },
				function(add_err, _add_result)
					if add_err then
						vim.notify("Error adding module import: " .. vim.inspect(add_err), vim.log.levels.ERROR)
					else
						vim.notify("Module import added successfully", vim.log.levels.INFO)
					end
				end
			)
		end)
	end)
end

local function request_simple_command(command)
	request_command(command, {}, function(err, result, ctx)
		if err then
			vim.notify("Error running" .. command .. ": " .. vim.inspect(err), vim.log.levels.ERROR)
			return
		end
		vim.notify("Success running " .. command .. ": " .. vim.inspect(result), vim.log.levels.INFO)
	end)
end

function M.build() request_simple_command("purescript.build") end

function M.start() request_simple_command("purescript.startPscIde") end

function M.stop() request_simple_command("purescript.stopPscIde") end

function M.restart() request_simple_command("purescript.restartPscIde") end

-- addIdentImport command https://github.com/nwolverson/vscode-ide-purescript/blob/524a8285b528a86d4014d761f858984fee3c05f9/src/IdePurescript/VSCode/Imports.purs#L26
function M.add_explicit_import()
	local uri = vim.uri_from_bufnr(0)
	local at_cursor = get_identifier_at_cursor()

	vim.ui.input({ prompt = "Identifier: ", default = at_cursor.identifier or "" }, function(ident)
		if not ident or ident == "" then
			vim.notify("No identifier provided", vim.log.levels.WARN)
			return
		end

		request_command("purescript.addCompletionImport", {
			ident, -- ident
			nil, -- module
			at_cursor.module or nil, -- qualifier
			uri, -- uri
			"", -- namespace
		}, function(err, result)
			-- will return array like { "Data.Argonaut.Decode", "Data.Argonaut.Decode.Error", "Data.Codec.Argonaut", "Data.Codec.Argonaut.Common", "Data.Codec.Argonaut.Compat" }

			if err then
				vim.notify("Error adding import: " .. vim.inspect(err), vim.log.levels.ERROR)
				return
			end

			if not result and type(result) ~= "table" and #result <= 0 then
				vim.notify("No modules provide this identifier", vim.log.levels.WARN)
				return
			end

			my_vim_ui_select(result, {
				prompt = "Select module for " .. ident .. ":",
				format_item = function(item) return item end,
			}, function(selected_module)
				if not selected_module then
					vim.notify("You didn't select a module", vim.log.levels.WARN)
					return
				end

				request_command("purescript.addCompletionImport", {
					ident, -- ident
					selected_module, -- module
					at_cursor.module or nil, -- qualifier
					uri, -- uri
					"", -- namespace
				}, function(err, _result)
					if err then
						vim.notify("Error adding import: " .. vim.inspect(err), vim.log.levels.ERROR)
						return
					end
					vim.notify("Module import added successfully", vim.log.levels.INFO)
				end)
			end)
		end)
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
			vim.notify("No type provided", vim.log.levels.WARN)
			return
		end

		local info = get_active_pos_info()
		request_command(
			"purescript.caseSplit-explicit",
			{ info.uri, info.pos.line, info.pos.character, ty },
			function(err, _result)
				if err then
					vim.notify("Error in case split: " .. vim.inspect(err), vim.log.levels.ERROR)
					return
				end
				vim.notify("Case split applied successfully", vim.log.levels.INFO)
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
				vim.notify("Error adding clause: " .. vim.inspect(err), vim.log.levels.ERROR)
			else
				vim.notify("Clause added successfully", vim.log.levels.INFO)
			end
		end
	)
end

function M.setup_on_init(client)
	-- print(vim.inspect("setup_on_init"))
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
								if type_info.documentation and not vim.tbl_isempty(type_info.documentation) then
									table.insert(lines, string.format("Documentation: %s", type_info.documentation))
								end
								return table.concat(lines, "\n")
							end,
							ordinal = type_info.identifier, -- For sorting
						}
					end,
				},
				sorter = require("telescope.config").values.generic_sorter {}, -- to have fzf input
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
									vim.notify(
										"Error applying typed hole suggestion: " .. vim.inspect(err),
										vim.log.levels.ERROR
									)
								else
									vim.notify(
										"Typed hole suggestion applied successfully" .. vim.inspect(result),
										vim.log.levels.INFO
									)
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

----------------------------------------------------------------------------------
--- PURSUIT RELATED

-- Function to perform an HTTP request to Pursuit using plenary's curl wrapper
-- example output is array of tables like this:

-- {
-- 	info = {
-- 		module = "Reactix.Hooks",
-- 		title = "nothing",
-- 		type = "declaration",
-- 		typeOrValue = "ValueLevel",
-- 		typeText = "Effect Unit",
-- 	},
-- 	markup = "<p>A cleanup handler that does nothing</p>\n",
-- 	package = "purescript-reactix",
-- 	text = "A cleanup handler that does nothing\n",
-- 	url =
-- 	"https://pursuit.purescript.org/packages/purescript-reactix/0.6.1/docs/Reactix.Hooks#v:nothing",
-- 	version = "0.6.1",
-- }
local function pursuit_request(search_term, callback)
	local url = "https://pursuit.purescript.org/search?q=" .. search_term

	local response = curl.get(url, {
		accept = "application/json",
	})

	if response.status ~= 200 then
		callback(nil, "HTTP request failed with status: " .. response.status)
		return
	end

	local decoded = vim.json.decode(response.body)
	if type(decoded) ~= "table" then
		callback(nil, "Invalid response format")
		return
	end

	for _, result in ipairs(decoded) do
		local function validate_result()
			vim.validate {
				result = { result, "t" },
				["markup"] = { result.markup, "s" },
				["text"] = { result.text, "s" },
				["url"] = { result.url, "s" },
				["version"] = { result.version, "s" },
				["info.type"] = { result.info.type, "s" },
			}
			if result.info.type == "declaration" then
				vim.validate {
					["info.module"] = { result.info.module, "s" },
					["info.title"] = { result.info.title, "s" },
					["info.type"] = { result.info.type, "s" },
					["info.typeOrValue"] = { result.info.typeOrValue, "s" },
					["info.typeText"] = { result.info.typeText, "s" },
				}
			elseif result.info.type == "package" then
				vim.validate {
					["info.deprecated"] = { result.info.deprecated, "b" },
				}
			elseif result.info.type == "module" then
				vim.validate {
					["info.module"] = { result.info.module, "b" },
				}
			else
				error("Invalid result format")
			end
		end

		pcall(
			validate_result,
			function(err) vim.notify("Validation error: " .. err, vim.log.levels.ERROR) end
		)
	end

	callback(decoded, nil) -- Pass the decoded result to the callback
end

local function pursuit_request_modules(search_term, callback)
	pursuit_request(search_term, function(results, err)
		if err then
			callback(nil, err)
			return
		end

		local only_modules = vim.tbl_filter(
			function(result) return result.info.type == "module" end,
			results
		)
		callback(only_modules, nil)
	end)
end

-- "https://pursuit.purescript.org/packages/purescript-reactix/0.6.1/docs/Reactix.Hooks#v:nothing",
-- to
-- "purescript-reactix/0.6.1/Reactix.Hooks#v:nothing"
local function url_to_path_with_query(url)
	-- Use Lua's string patterns to remove the domain and keep the path
	local path_with_query = url:gsub("https://pursuit.purescript.org/packages/", ""):gsub("/docs", "")
	return path_with_query
end

local function handle_enter_key(prompt_bufnr)
	local selection = require("telescope.actions.state").get_selected_entry()
	require("telescope.actions").close(prompt_bufnr)
	if selection then
		-- Open the URL in the browser
		open_url(selection.value.url)
	end
end

local function handle_ctrl_i(at_cursor, prompt_bufnr)
	local selection = require("telescope.actions.state").get_selected_entry()
	require("telescope.actions").close(prompt_bufnr)

	if selection.value.info.type == "declaration" then
		local uri = vim.uri_from_bufnr(0)
		local ident = selection.value.info.title
		local qualifier = at_cursor.module or nil
		local module = selection.value.info.module
		local namespace = ""

		request_command(
			"purescript.addCompletionImport",
			{ ident, module, qualifier, uri, namespace },
			function(err, result)
				if err then
					vim.notify("Error adding completion import: " .. vim.inspect(err), vim.log.levels.ERROR)
				else
					vim.notify(
						"Completion import added successfully: " .. selection.value.info.title,
						vim.log.levels.INFO
					)
				end
			end
		)
	elseif selection.value.info.type == "package" then
		vim.notify(
			"Selected module is a package, not a declaration, opening link in browser",
			vim.log.levels.WARN
		)
		open_url(selection.value.url)
	elseif selection.value.info.type == "module" then
		local selected_module = selection.value.info.module
		local qualifier = at_cursor.module or nil
		local uri = vim.uri_from_bufnr(0)
		-- Issue the import command for the selected module
		request_command(
			"purescript.addModuleImport",
			{ selected_module, qualifier, uri },
			function(add_err)
				if add_err then
					vim.notify("Error adding module import: " .. vim.inspect(add_err), vim.log.levels.ERROR)
				else
					vim.notify("Module import added successfully: " .. selected_module, vim.log.levels.INFO)
				end
			end
		)
	else
		vim.notify("Selected module is unknown", vim.log.levels.WARN)
	end
end

-- Function to search Pursuit
function M.search_pursuit()
	local at_cursor = get_identifier_at_cursor()
	vim.ui.input(
		{ prompt = "Search Pursuit: ", default = vim.fn.expand("<cword>") },
		function(search_term)
			if not search_term or search_term == "" then return end

			pursuit_request(search_term, function(results, err)
				if err then
					vim.notify("Error searching Pursuit: " .. err, vim.log.levels.ERROR)
					return
				end

				if not results or type(results) ~= "table" or #results == 0 then
					vim.notify("No results found", vim.log.levels.WARN)
					return
				end

				require("telescope.pickers")
					.new({}, {
						prompt_title = "Select Module to Import or Open Link (click <CR> to open in browser, <C-i> to import)",
						finder = require("telescope.finders").new_table {
							results = results,
							entry_maker = function(item)
								local formatted_url = url_to_path_with_query(item.url)
								return {
									value = item,
									display = formatted_url,
									ordinal = formatted_url, -- For sorting
								}
							end,
						},
						sorter = require("telescope.config").values.generic_sorter {}, -- to have fzf input
						previewer = previewers.new_buffer_previewer {
							define_preview = function(self, entry, _status)
								local content = vim.inspect(entry)
								self.state.bufnr = self.state.bufnr or vim.api.nvim_create_buf(false, true)
								vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(content, "\n"))
								-- vim.api.nvim_win_set_buf(status.preview_win, self.state.bufnr)
							end,
						},
						attach_mappings = function(_, map)
							map("i", "<CR>", function(prompt_bufnr) handle_enter_key(prompt_bufnr) end)
							map("i", "<C-i>", function(prompt_bufnr) handle_ctrl_i(at_cursor, prompt_bufnr) end)
							return true
						end,
					})
					:find()
			end)
		end
	)
end

-- Function to search Pursuit modules
function M.search_pursuit_modules()
	local at_cursor = get_identifier_at_cursor()
	vim.ui.input(
		{ prompt = "Search Pursuit Modules: ", default = vim.fn.expand("<cword>") },
		function(search_term)
			if not search_term or search_term == "" then return end

			pursuit_request_modules(search_term, function(results, err)
				if err then
					vim.notify("Error searching Pursuit modules: " .. err, vim.log.levels.ERROR)
					return
				end

				if not results or type(results) ~= "table" or #results == 0 then
					vim.notify("No results found", vim.log.levels.WARN)
					return
				end

				-- Use Telescope to display the results
				require("telescope.pickers")
					.new({}, {
						prompt_title = "Select Module to Import or Open Link (click <CR> to open in browser, <C-i> to import)",
						finder = require("telescope.finders").new_table {
							results = results,
							entry_maker = function(item)
								return {
									value = item,
									display = string.format(
										"%s in %s (%s)",
										item.info.module,
										item.package,
										item.version
									),
									ordinal = item.info.module, -- For sorting
								}
							end,
						},
						sorter = require("telescope.config").values.generic_sorter {}, -- to have fzf input
						attach_mappings = function(_, map)
							map("i", "<CR>", function(prompt_bufnr) handle_enter_key(prompt_bufnr) end)
							map("i", "<C-i>", function(prompt_bufnr) handle_ctrl_i(at_cursor, prompt_bufnr) end)
							return true
						end,
					})
					:find()
			end)
		end
	)
end

function M.pursuit_query(query)
	vim.validate {
		query = { query, "s" },
	}

	if #query == 0 then
		vim.notify("No query provided", vim.log.levels.WARN)
		return
	end

	open_url("https://pursuit.purescript.org/search?q=" .. query)
end

local function get_visual_selection()
	local s_start = vim.fn.getpos("'<")
	local s_end = vim.fn.getpos("'>")
	local n_lines = math.abs(s_end[2] - s_start[2]) + 1
	local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
	lines[1] = string.sub(lines[1], s_start[3], -1)
	if n_lines == 1 then
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
	else
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
	end
	return table.concat(lines, "\n")
end

function M.pursuit_query_visual()
	local query = get_visual_selection()
	vim.notify("Opening query: " .. query, vim.log.levels.INFO)
	M.pursuit_query(query)
end

function M.pursuit_query_normal()
	local at_cursor = get_identifier_at_cursor()
	local query = table.concat({ at_cursor.module, at_cursor.identifier }, ".")
	vim.notify("Opening query: " .. query, vim.log.levels.INFO)
	M.pursuit_query(query)
end

----------------------------------------------------------------------------------

function M.setup_on_attach(_client, bufnr)
	-- vim.lsp.set_log_level("debug")

	-- print(vim.inspect("setup_on_attach"))
	-- print(vim.inspect(M.current_config))
	local keymaps = M.current_config.keymaps

	local function set_keymap(mode, key, command, desc)
		vim.api.nvim_buf_set_keymap(
			bufnr,
			mode,
			key,
			command,
			{ noremap = true, silent = true, desc = desc }
		)
	end

	-- add command to vim :PSearch
	vim.api.nvim_create_user_command(
		"PSearch",
		function(opts) M.pursuit_query(opts.args) end,
		{ nargs = 1, desc = "Open browser with https://pursuit.purescript.org/search?q=SELECTION" }
	)

	-- Normal mode mappings
	set_keymap(
		"n",
		keymaps.normal_mode.add_import,
		'<Cmd>lua require("nvimmer-ps").add_import()<CR>',
		"Purescript: Add import - Show list of available modules, enter to import"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.add_explicit_import,
		'<Cmd>lua require("nvimmer-ps").add_explicit_import()<CR>',
		"Purescript: Add explicit import - Will get current symbol, allow change it, show modules that contain it, enter to import"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.search_pursuit,
		'<Cmd>lua require("nvimmer-ps").search_pursuit()<CR>',
		"Purescript: Search Pursuit - Search identifier under cursor"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.search_pursuit_modules,
		'<Cmd>lua require("nvimmer-ps").search_pursuit_modules()<CR>',
		"Purescript: Search Pursuit modules"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.case_split,
		'<Cmd>lua require("nvimmer-ps").case_split()<CR>',
		"Purescript: Case split"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.add_clause,
		'<Cmd>lua require("nvimmer-ps").add_clause()<CR>',
		"Purescript: Add clause"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.build,
		'<Cmd>lua require("nvimmer-ps").build()<CR>',
		"Purescript: Build"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.start,
		'<Cmd>lua require("nvimmer-ps").start()<CR>',
		"Purescript: Start"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.stop,
		'<Cmd>lua require("nvimmer-ps").stop()<CR>',
		"Purescript: Stop"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.restart,
		'<Cmd>lua require("nvimmer-ps").restart()<CR>',
		"Purescript: Restart"
	)
	set_keymap(
		"n",
		keymaps.normal_mode.pursuit_query,
		'<Cmd>lua require("nvimmer-ps").pursuit_query_normal()<CR>',
		"Purescript: open browser with https://pursuit.purescript.org/search?q=IDENTIFIER"
	)

	-- Visual mode mappings
	set_keymap(
		"v",
		keymaps.visual_mode.pursuit_query,
		'<Cmd>lua require("nvimmer-ps").pursuit_query_visual()<CR>',
		"Purescript: open browser with https://pursuit.purescript.org/search?q=SELECTION"
	)
end

----------------------------------------------------------------------------------
local default_keymaps = {
	normal_mode = {
		add_import = "<space>am",
		add_explicit_import = "<space>ae",
		search_pursuit = "<space>asi",
		search_pursuit_modules = "<space>asm",
		case_split = "<space>ac",
		add_clause = "<space>aa",
		-- prefix + l for language server + ...
		build = "<space>alb",
		start = "<space>als",
		stop = "<space>alt",
		restart = "<space>alr",
		pursuit_query = "<space>asq",
	},
	visual_mode = {
		pursuit_query = "<space>asq",
	},
}

M.current_config = nil

-- should be called before setup_on_attach
function M.setup(config_overrides)
	-- print(vim.inspect(config_overrides))
	config_overrides = config_overrides or {}
	vim.validate {
		config_overrides = { config_overrides, "t" },
	}
	M.current_config = vim.tbl_deep_extend("force", { keymaps = default_keymaps }, config_overrides)
end

return M
