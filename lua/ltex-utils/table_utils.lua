local M = {}

-- Extends the value of field 'key' in table 't1' with table 't2' if it exists,
-- otherwise initializes field 'k' with table 't2'.
function M.extend_or_init(t1, key, t2)
  if t1[key] then
	  t1[key] = vim.list_extend(t1[key], t2)
  else
    t1[key] = t2
  end
end

--[[ 
    Function: merge_lists

    Merges two input lists (list1 and list2) into one, removing any duplicates.

    Parameters:
        list1 - The first input list.
        list2 - The second input list.

    Returns:
        A new list containing unique elements from both input lists.

    Usage example:
        local list1 = {"a", "b", "c"}
        local list2 = {"b", "c", "d", "e"}
        local merged_list = merge_lists(list1, list2)
        print(vim.inspect(merged_list)) -- Prints: {"a", "b", "c", "d", "e"}
--]]
function M.merge_lists_unique(list1, list2, changes)
	-- Create a table to store the unique elements
	local unique_elements = {}

	if not changes then
		-- Add unique elements from list1 and list2 to unique_elements
		for _, list in ipairs({list1, list2}) do
			for _, element in ipairs(list) do
				unique_elements[element] = true
			end
		end
	else
		-- Add unique elements from list1 and list2 to unique_elements
		-- and apply changes when iterating through lists
		for _, list in ipairs({list1, list2}) do
			for _, element in ipairs(list) do
				local curr_change = changes[element]
				if not curr_change then
					unique_elements[element] = true
				elseif curr_change ~= "" then
					unique_elements[curr_change] = true
				end
			end
		end
	end

	-- Convert the unique_elements table to a list
	local merged_list = vim.tbl_keys(unique_elements)

	return merged_list
end


--function M.apply_changes(list, changes)
--	-- have we received a list?
--	if not list then return end
--
--	local reverse_lookup = {}
--	for idx, value in ipairs(list) do
--		reverse_lookup[value] = key
--	end
--
--	local deletions = {}
--	for _, change in ipairs(changes) do
--		local idx = reverse_lookup[change.old_rule]
--
--		if idx then
--			
--		end
--	end
--
--
--end

--- Modifies a list based on a changes table.
-- For each entry in the list, the function checks if a change should be
-- applied from the changes table. If the change is an empty string, the entry
-- is deleted. If there's no change, the entry is kept. Else, the entry is
-- updated. Entries may be relocated due to deletions.
-- @param list a list of strings
-- @param changes a table with keys as original strings and values as
--        replacements
function M.apply_changes(list, changes)
	-- have we received a list?
	if not list then return end

	local j = 1
	local n = #list
	for i = 1, n do
		local entry = list[i]
		local curr_change = changes[entry]
		if not curr_change then
			-- keep entry and move it if necessary (because of deleted entries)
			if i ~= j then
				list[j] = list[i]
				list[i] = nil
			end
			j = j + 1
		elseif curr_change == "" then
			-- delete entry
			list[i] = nil
		else
			-- update entry and move it to new index if necessary (because of
			-- deleted entries)
			if i ~= j then
				list[j] = curr_change
				list[i] = nil
			else
				list[i] = curr_change
			end
			j = j + 1
		end
	end
end

return M
