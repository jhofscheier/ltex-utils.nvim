local M = {}

-- Extends the value of field 'key' in table 't1' with table 't2' if it exists,
-- otherwise initializes field 'k' with table 't2'.
function M.extend_or_init(t1, key, t2)
  if t1[key] then
	  t1[key]=vim.list_extend(t1[key],t2)
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
function M.merge_lists_unique(list1, list2)
	-- Create a table to store the unique elements
	local unique_elements = {}

	-- Add unique elements from list1 and list2 to unique_elements
	for _, list in ipairs({list1, list2}) do
		for _, element in ipairs(list) do
			unique_elements[element] = true
		end
	end

	-- Convert the unique_elements table to a list
	local merged_list = vim.tbl_keys(unique_elements)

	return merged_list
end

return M
