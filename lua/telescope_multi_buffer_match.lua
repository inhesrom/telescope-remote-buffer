-- Custom telescope extension for searching across all buffers
-- Save this in your neovim config as lua/multi_buffer_search.lua
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local conf = require('telescope.config').values
local make_entry = require('telescope.make_entry')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

-- Main function to search across all buffers
local multi_buffer_exact_find = function(opts)
  opts = opts or {}

  -- Get all valid buffers
  local buffers = vim.api.nvim_list_bufs()
  local valid_buffers = {}
  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_is_valid(buf) then
      table.insert(valid_buffers, buf)
    end
  end

  -- Function to get all lines from all buffers with buffer info
  local function get_all_buffer_lines()
    local results = {}
    for _, bufnr in ipairs(valid_buffers) do
      local filename = vim.api.nvim_buf_get_name(bufnr)
      local display_name = filename
      if filename == "" then
        display_name = "[Buffer " .. bufnr .. "]"
      else
        display_name = vim.fn.fnamemodify(filename, ":t")
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for lnum, line in ipairs(lines) do
        -- Skip empty lines
        if line and line:gsub("%s", "") ~= "" then
          table.insert(results, {
            bufnr = bufnr,
            filename = filename,
            display_name = display_name,
            lnum = lnum,
            text = line
          })
        end
      end
    end
    return results
  end

  -- Custom entry maker to display buffer name + line number + content
  local entry_maker = function(entry)
    local display = string.format(
      "[%s:%d] %s",
      entry.display_name,
      entry.lnum,
      entry.text
    )
    return {
      value = entry,
      ordinal = display,
      display = display,
      filename = entry.filename,
      bufnr = entry.bufnr,
      lnum = entry.lnum,
      text = entry.text
    }
  end

  -- Create the picker
  pickers.new(opts, {
    prompt_title = "Exact Search All Buffers",
    finder = finders.new_table({
      results = get_all_buffer_lines(),
      entry_maker = entry_maker
    }),
    sorter = sorters.get_substr_matcher(),  -- Changed to substring matcher for exact matching
    previewer = conf.grep_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: jump to the line in the buffer
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          vim.api.nvim_set_current_buf(selection.bufnr)
          vim.api.nvim_win_set_cursor(0, {selection.lnum, 0})
          -- Center the cursor in the window
          vim.cmd('normal! zz')
        end
      end)
      -- You can add additional custom mappings here
      return true
    end
  }):find()
end

-- Return the function
return {
  multi_buffer_exact_find = multi_buffer_exact_find  -- Updated function name
}
