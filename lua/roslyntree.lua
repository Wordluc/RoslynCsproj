local M = {}

M.setupCsprojOperation = function()
	local tree = require("nvim-tree.events")
	if not package.loaded["nvim-tree.events"] then
		print("Package is not loaded.")
	end
	local events = require("nvim-tree.events").Event

	tree.subscribe(events.FileCreated, function(data)
		require("csprojManager").add_element(data.fname)
	end)

	tree.subscribe(events.WillRemoveFile, function(data)
		require("csprojManager").remove_element(data.fname)
	end)

	tree.subscribe(events.NodeRenamed, function(data)
		require("csprojManager").remove_element(data.old_name)
		require("csprojManager").add_element(data.new_name)
	end)
	vim.api.nvim_create_user_command('AddFile', function()
		require("csprojManager").add_element(vim.fn.expand("%:p"))
	end, { bang = true, nargs = '*' })
end
return M
