-- Custom telescope extension for searching across all buffers with syntax highlighting
-- Save this in your neovim config as lua/telescope_multi_buffer_fzf.lua

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local conf = require('telescope.config').values
local make_entry = require('telescope.make_entry')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

-- Main function to search across all buffers
local multi_buffer_fuzzy_find = function(opts)
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
      col = 0, -- Add column for proper cursor positioning
      text = entry.text
    }
  end

  -- Create a custom previewer that properly handles syntax highlighting
  local buffer_previewer = previewers.new_buffer_previewer({
    title = "Buffer Preview",
    get_buffer_by_name = function(_, entry)
      return entry.bufnr
    end,
    define_preview = function(self, entry, status)
      -- Use the actual buffer for the preview
      local bufnr = entry.bufnr

      -- Set the previewer buffer to display the content of the actual buffer
      local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, content)

      -- Get the filetype of the original buffer
      local ft = vim.bo[bufnr].filetype

      -- Apply the filetype to the preview buffer for syntax highlighting
      if ft and ft ~= "" then
        vim.bo[self.state.bufnr].filetype = ft
      end

      -- Create a namespace for our highlights if it doesn't exist
      if not self.ns_id then
        self.ns_id = vim.api.nvim_create_namespace("telescope_multi_buffer_fzf")
      end

      -- Clear existing highlights
      vim.api.nvim_buf_clear_namespace(self.state.bufnr, self.ns_id, 0, -1)

      -- Highlight the matched line
      vim.api.nvim_buf_add_highlight(
        self.state.bufnr,   -- buffer handle
        self.ns_id,         -- namespace ID
        "Search",           -- highlight group (using Search which is usually yellow background)
        entry.lnum - 1,     -- line (0-indexed)
        0,                  -- start column
        -1                  -- end column (-1 means the whole line)
      )

      -- Try to highlight specific matches based on fuzzy search
      local prompt = status.picker and status.picker.prompt and status.picker.prompt:get_prompt()
      if prompt and prompt ~= "" and entry.lnum <= #content then
        local line = content[entry.lnum]

        -- For fuzzy search, we need to go character by character
        -- Looking for characters from the prompt
        local chars = {}
        for i = 1, #prompt do
          chars[i] = prompt:sub(i, i)
        end

        -- Try to find these characters in sequence
        local position = 0
        local highlights = {}

        for _, char in ipairs(chars) do
          local found = false
          for i = position + 1, #line do
            if line:sub(i, i):lower() == char:lower() then
              table.insert(highlights, i - 1) -- 0-indexed
              position = i
              found = true
              break
            end
          end
          if not found then break end
        end

        -- Add highlights for matched characters
        for _, pos in ipairs(highlights) do
          vim.api.nvim_buf_add_highlight(
            self.state.bufnr,  -- buffer handle
            self.ns_id,        -- namespace ID
            "IncSearch",       -- highlight group
            entry.lnum - 1,    -- line (0-indexed)
            pos,               -- start column
            pos + 1            -- end column
          )
        end
      end

      -- Position the cursor and center the view
      -- Make sure the line number is valid for the preview buffer
      local preview_line_count = vim.api.nvim_buf_line_count(self.state.bufnr)
      local target_line = math.min(entry.lnum, preview_line_count)

      -- Safe cursor positioning
      pcall(vim.api.nvim_win_set_cursor, status.preview_win, {target_line, 0})

      -- Center the view on the selected line (safely)
      local height = vim.api.nvim_win_get_height(status.preview_win)
      local start_line = math.max(1, math.min(target_line - math.floor(height / 2), preview_line_count))
      pcall(vim.api.nvim_win_set_cursor, status.preview_win, {start_line, 0})
      pcall(vim.api.nvim_win_set_cursor, status.preview_win, {target_line, 0})
    end
  })

  -- Create the picker
  pickers.new(opts, {
    prompt_title = "Fuzzy Search All Buffers",
    finder = finders.new_table({
      results = get_all_buffer_lines(),
      entry_maker = entry_maker
    }),
    sorter = sorters.get_fuzzy_file(),
    previewer = buffer_previewer,
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

      return true
    end
  }):find()
end

-- Return the function
return {
  multi_buffer_fuzzy_find = multi_buffer_fuzzy_find
}
