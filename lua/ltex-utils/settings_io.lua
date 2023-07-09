local M = {}

local table_utils = require("ltex-utils.table_utils")

--[[Reads and decodes a JSON file.

    Opens the given file, retrieves its content, and decodes the content from JSON.
    Handles errors during file operations and JSON decoding, returning `nil` and 
	the respective error message when an error occurs.

	@param filename The name (path) of the file to be read and decoded.

	@return The decoded content if successful, `nil` otherwise.
	@return nil if successful, error message otherwise.
 --]]
function M.read_settings(filename)
	local fd, err_open = vim.loop.fs_open(filename, "r", 420)  -- octal representation of the permission bits (0644)
	if not fd then
		return nil, err_open
	end

	-- Get the file size
	local stat, err_stat = vim.loop.fs_fstat(fd)
	if not stat then
		return nil, err_stat
	end
	local file_size = stat.size or 0

	-- Read the contents of the file
	local contents, err_read = vim.loop.fs_read(fd, file_size, 0)
	if not contents then
		return nil, err_read
	end

	local ok_close, err_close = pcall(vim.loop.fs_close, fd)
	if not ok_close then
		return nil, err_close
	end

	local ok_decode, contents_json = pcall(vim.json.decode, contents)
	if not ok_decode then
		-- In this case, `contents_json` holds the error message.
		return nil, contents_json
	end

	return contents_json, nil
end

function M.write_settings(filepath, settings)
	vim.schedule(function()
		local fd, err_open = vim.loop.fs_open(filepath, "w", 438) -- 438 = 0o666
		if not fd then
			print("Error opening file: ", err_open)
			return err_open
		end
		local ok, err = pcall(
								vim.loop.fs_write,
								fd,
								vim.json.encode(settings),
								-1
							 )
		if not ok then
			print("Error writing to file: ", err)
			return err
		end

		ok, err = pcall(vim.loop.fs_close, fd)
		if not ok then
			print("Error closing file: ", err)
			return err
		end
	end)
end

-- Check if the folder exists and create it if not
function M.ensure_folder_exists(path)
	local folder_stat, err_stat = vim.loop.fs_stat(path)
	-- If there's an error and the folder does not exist, create it
	if not folder_stat and err_stat then
		local ok, err = pcall(vim.loop.fs_mkdir, path, 448) -- octal representation of the permission bits (0700)
		if not ok then
			-- Handle any error during folder creation
			print("Error creating folder: ", err)
			return err
		end
	end
	-- If no error, the folder exists or has been created successfully
	return nil
end

--[[ 
    Function: update_dictionary_files

    Updates language-specific dictionary files with provided dictionaries,
	avoiding duplicates. Returns a list of the processed languages.

    Parameters:
        dictionaries - A table with language keys and their associated word
					   lists as values.

    Returns:
        A list of languages that have been updated.

--]]
function M.update_dictionary_files(dict_path, dictionaries, cached_changes)
	cached_changes = cached_changes or {}
	local used_langs = {}
	for lang, dict in pairs(dictionaries) do
		local filename = dict_path .. lang .. ".json"
		local saved_dict = M.read_settings(filename)
		-- if there is already a saved dictionary merge it with current one
		if saved_dict then
			dict = table_utils.merge_lists_unique(
				dict,
				saved_dict,
				cached_changes[lang]
			)
		end
		M.write_settings(filename, dict)
		table.insert(used_langs, lang)
	end

	return used_langs
end

function M.load_dictionaries(dict_path, langs, server_dics)
	for _, lang in ipairs(langs) do
		local dict, err = M.read_settings(dict_path .. lang .. ".json")
		if not dict then
			-- if error, update user about problem and continue
			-- loading remaining dictionaries
			print("Error loading dicitonary: ", err)
		else
			server_dics[lang] = dict
		end
	end
end

return M
