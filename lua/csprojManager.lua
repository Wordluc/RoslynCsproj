local uv = require('luv')
local M = {}

---@param fullpath string
local function get_filename_from_fullpath(fullpath)
	return fullpath:match("([^/|\\]+)$") or ""
end

local function get_path_from_fullpath(fullpath)
	local nameFile = get_filename_from_fullpath(fullpath)
	if nameFile == "" then
		return fullpath
	end
	return fullpath:sub(1, - #nameFile - 1)
end
---@param fullpath string full path of the file
---@param client vim.lsp.Client client
---@param typeOperation "created" | "changed" | "deleted"
local function did_change_watched_file(fullpath, client, typeOperation)
	vim.defer_fn(
		function()
			local types={
				"created" , "changed" , "deleted"}
				---comment
				---@param array {}string 
				---@param element any
				---@return number
				local function find(array,element)
					for i,el in pairs(array) do
						if el==element then
							return i
						end
					end 
					return -1
				end
				local indexType=find(types,typeOperation)
				if indexType==-1 then
					print("error type")
					return
				end
				client.request("workspace/didChangeWatchedFiles", {
					changes = {
						{
							uri = "file:///"..fullpath:sub(1,fullpath:len()-1),
							type = indexType
						}
					}
				}, function(err, result)
					print("didChangeWatchedFiles ",fullpath,indexType)
					if err ~= nil then
						print(err)
					end
					if result ~= nil then
						print(result)
					end
				end)
		end,1000)
end
---@param path1 string
---@param path2 string
---@return string --it return the relative path from path1 to path2
---example: c:\Users\pippo\paperino\home.csproj, c:\Users\pippo\paperino\scr\pluto\brontolo.cs -> scr\pluto
local function get_relative_path_from_path1_path2(path1, path2)
	return path2:sub(#path1 + 1) --+1 since i don't wanna include the \ at the beginning
end

---@param path string --where to start searching
---@return string,string --it return the totalpath and name of the csproj
local function find_csproj(path)
	local csprojPath = ""
	local csprojName = ""
	vim.fs.find(function(_name, _path)
		if _name:match("%.csproj$") then
			csprojPath = _path
			csprojName = _name:sub(1, #_name)
			return true
		end
		return false
	end, { upward = true, path = path, limit = math.huge, })
	return csprojPath, csprojName
end

local function find_another_sibling(path, siblingName)
	local another_siblingName = ""
	for _name, type in vim.fs.dir(path) do
		if type == "file" then
			if _name ~= siblingName and _name:match("%.cs$") then
				another_siblingName = _name
				break
			end
		end
	end
	return another_siblingName
end

local function clean_path_name(path)
	path = path:gsub("/", "\\")
	path = path:gsub("^[/|\\]", "")
	return path
end

M.add_element = function(totalpath)
	uv.run("nowait") -- This is necessary to start the event loop
	local filePath = get_path_from_fullpath(totalpath)
	local fileName = get_filename_from_fullpath(totalpath)
	local csprojPath = ""
	local csprojName = ""
	local siblingName = ""

	--find csproj
	csprojPath, csprojName = find_csproj(filePath)
	if csprojPath == "" then
		print("No csproj found")
		return
	end
	--find sibling
	siblingName = find_another_sibling(filePath, fileName)
	--calculate relative path
	local relative_path_file = get_relative_path_from_path1_path2(csprojPath, filePath)
	--cleanig path
	relative_path_file = clean_path_name(relative_path_file)

	local stdin = uv.new_pipe()
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()
	local script_path = debug.getinfo(1, "S").source:sub(2)
	local executable_path = script_path:match(".*/") .. "/csprojManager/csprojManager.exe"
	local handle, pid = uv.spawn(
	executable_path
	, { stdio = { stdin, stdout, stderr } }, function()
		stdin:close()
		stdout:close()
		stderr:close()
	end
	)
	if not pid or not handle then
		print("error:manager not found,path:" .. executable_path)
		return
	end
	local input = {
		CsprojPath = clean_path_name(vim.fs.joinpath(csprojPath, csprojName)),
		WhenAddElement = clean_path_name(relative_path_file .. siblingName),
		ElementToAdd = string.format('<Compile Include="%s" />', clean_path_name(relative_path_file .. fileName)),
	}
	if siblingName == "" then --if there is no sibling use the directory path instead
		input.WhenAddElement = relative_path_file
	end

	local json = vim.fn.json_encode(input)
	stdin:write("add\n")
	stdin:write(json .. "\n")
	stdout:read_start(function(e, data)
		assert(not e, e)
		if data then
			vim.schedule(function()
				for _, client in pairs(vim.lsp.get_clients({ name = "roslyn" })) do
					did_change_watched_file(totalpath, client, "created")
				end
				print(data)
			end)
		end
	end)
	stderr:read_start(function(e, data)
		assert(not e, e)
		if data then
			print(data)
		end
	end)
end
---@param totalpath string --file to remove
M.remove_element = function(totalpath) --TODO
	uv.run("nowait")                    -- This is necessary to start the event loop
	local filePath = get_path_from_fullpath(totalpath)
	local fileName = get_filename_from_fullpath(totalpath)
	local csprojPath = ""
	local csprojName = ""

	--find csproj
	csprojPath, csprojName = find_csproj(filePath)
	if csprojPath == "" then
		print("No csproj found")
		return
	end
	--calculate relative path
	local relative_path_file = get_relative_path_from_path1_path2(csprojPath, filePath)
	--cleanig path
	relative_path_file = clean_path_name(relative_path_file)

	local stdin = uv.new_pipe()
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()
	local script_path = debug.getinfo(1, "S").source:sub(2)
	local executable_path = script_path:match(".*/") .. "/csprojManager/csprojManager.exe"
	local handle, pid = uv.spawn(
	executable_path
	, { stdio = { stdin, stdout, stderr } }, function()
		stdin:close()
		stdout:close()
		stderr:close()
	end
	)
	if not pid or not handle then
		print("error:manager not found,path:" .. executable_path)
		return
	end
	local input = {
		CsprojPath = clean_path_name(vim.fs.joinpath(csprojPath, csprojName)),
		ToRemove = string.format('<Compile Include="%s" />', clean_path_name(relative_path_file .. fileName))
	}

	local json = vim.fn.json_encode(input)
	stdin:write("remove\n")
	stdin:write(json .. "\n")
	stdout:read_start(function(e, data)
		assert(not e, e)
		if data then
			vim.schedule(function()
				for _, client in pairs(vim.lsp.get_clients({ name = "roslyn" })) do
					did_change_watched_file(totalpath, client, "deleted")
				end
				print(data)
			end)
		end
	end)
	stderr:read_start(function(e, data)
		assert(not e, e)
		if data then
			print(data)
		end
	end)
end
return M
