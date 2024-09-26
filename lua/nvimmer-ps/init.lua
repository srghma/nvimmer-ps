local function print_inspect_to_file(data)
	local filepath = "/tmp/asdf"
	local inspected_data = vim.inspect(data) .. "\n"
	local file = io.open(filepath, "a")
	if not file then
		print("Could not open file for writing: " .. filepath)
		return
	end
	file:write(inspected_data)
	file:close()
end

local M = {}

-- Function to request a command from the PureScript language server
local function request_command(command, arguments)
	local clients = vim.lsp.get_clients({ name = "purescriptls" })
	for _, client in ipairs(clients) do
		client.request("workspace/executeCommand", {
			command = command,
			arguments = arguments,
		}, function(err, result, _x, _y)
			print_inspect_to_file({ err, result, _x, _y })
			if err then
				print("Error: " .. err.message)
			else
				print("Result: " .. result.message)
			end
		end)
	end
end

M.addCompletionImport = function(identifier, module, uri)
	request_command('purescript.addCompletionImport', { identifier, module, uri })
end

M.addModuleImport = function(module, qualifier, uri)
	request_command('purescript.addModuleImport', { module, qualifier, uri })
end

M.getAvailableModules = function()
	request_command('purescript.getAvailableModules', {})
end

M.build = function()
	request_command('purescript.build', {})
end

M.start = function()
	request_command('purescript.startPscIde', {})
end

M.stop = function()
	request_command('purescript.stopPscIde', {})
end

M.restart = function()
	request_command('purescript.restartPscIde', {})
end

M.search = function(identifier)
	request_command('purescript.search', { identifier })
end

M.command = function(command, ...)
	local args = { ... }
	request_command(command, args)
end

return M
