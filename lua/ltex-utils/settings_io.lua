local table_utils = require("ltex-utils.table_utils")

---@class vim.file

local M = {}

 ---Reads and decodes a JSON file.
 ---@param filename string name (path) of the file to be read an decoded
 ---@return table|nil # returns decoded content if successful; `nil` when an error occurs
 ---@return string|nil # respective error message or nil if successful
function M.read_settings(filename)
	---@type vim.file|nil, string
	local fd, err_open = vim.loop.fs_open(filename, "r", 420)  -- octal representation of the permission bits (0644)
	if not fd then
		return nil, err_open
	end

	-- Get the file size
	---@type table|nil, string
	local stat, err_stat = vim.loop.fs_fstat(fd)
	if not stat then
		return nil, err_stat
	end
	---@type integer
	local file_size = stat.size or 0

	-- Read the contents of the file
	---@type string|nil, string
	local contents, err_read = vim.loop.fs_read(fd, file_size, 0)
	if not contents then
		return nil, err_read
	end

	---@type boolean, string|nil
	local ok_close, err_close = pcall(vim.loop.fs_close, fd)
	if not ok_close then
		return nil, err_close
	end

	---@type boolean, table|string|nil
	local ok_decode, contents_json = pcall(vim.json.decode, contents)
	if not ok_decode then
		-- In this case, `contents_json` holds the error message.
		---@cast contents_json string
		return nil, contents_json
	end

	---@cast contents_json table
	return contents_json, nil
end

---Write `settings` to json file specified by `filepath`.
---@param filepath string
---@param settings table
function M.write_settings(filepath, settings)
	vim.schedule(function()
		---@type vim.file|nil, string
		local fd, err_open = vim.loop.fs_open(filepath, "w", 438) -- 438 = 0o666
		if not fd then
			vim.notify(
				"Error opening file: " .. err_open,
				vim.log.levels.ERROR
			)
			return err_open
		end
		---@type boolean, string|nil
		local ok, err = pcall(
								vim.loop.fs_write,
								fd,
								vim.json.encode(settings),
								-1
							 )
		if not ok then
			vim.notify(
				"Error writing to file: " .. vim.inspect(err),
				vim.log.levels.ERROR
			)
			return err
		end

		ok, err = pcall(vim.loop.fs_close, fd)
		if not ok then
			vim.notify(
				"Error closing file: " .. vim.inspect(err),
				vim.log.levels.ERROR
			)
			return err
		end
	end)
end

---Check if the folder exists and create it if not
---@param path string
---@return string|nil
function M.ensure_folder_exists(path)
	---@type table|nil, string|nil
	local folder_stat, err_stat = vim.loop.fs_stat(path)
	-- If there's an error and the folder does not exist, create it
	if not folder_stat and err_stat then
		---@type boolean, string|nil
		local ok, err = pcall(vim.loop.fs_mkdir, path, 448) -- octal representation of the permission bits (0700)
		if not ok then
			-- Handle any error during folder creation
			vim.notify(
				"Error creating folder: " .. vim.inspect(err),
				vim.log.levels.ERROR
			)
			return err
		end
	end
	-- If no error, the folder exists or has been created successfully
	return nil
end

---Updates language-specific dictionary files avoiding duplicates.
---@param dict_path string
---@param dictionaries table<string, string[]> Table with language keys and associated word lists.
---@return string[] # A list of languages that have been updated.
function M.update_dictionary_files(dict_path, dictionaries)
	---@type string[]
	local used_langs = {}
	for lang, dict in pairs(dictionaries) do
		---@type string
		local filename = dict_path .. lang .. ".json"
		---@type string[]|nil
		local saved_dict = M.read_settings(filename)
		-- if there is already a saved dictionary merge it with current one
		if saved_dict then
			dict = table_utils.merge_lists_unique(dict, saved_dict)
		end
		M.write_settings(filename, dict)
		table.insert(used_langs, lang)
	end

	return used_langs
end

---Loads the dictionaries at `dict_path` for languages `langs`.
---@param dict_path string Path to dictionary files
---@param langs string[] List of language identifiers
---@return table<string, string[]>
function M.load_dictionaries(dict_path, langs)
	---@type table<string, string[]>
	local server_dics = {}
	for _, lang in ipairs(langs) do
		---@type string[]|nil, string|nil
		local dict, err = M.read_settings(dict_path .. lang .. ".json")
		if not dict then
			-- if error, update user about problem and continue
			-- loading remaining dictionaries
			vim.notify(
				"Error loading dicitonary: " .. vim.inspect(err),
				vim.log.levels.ERROR
			)
		else
			server_dics[lang] = dict
		end
	end

	return server_dics
end

return M
