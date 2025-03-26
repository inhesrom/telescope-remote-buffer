-- Custom telescope extension for searching across all buffers with syntax highlighting
-- Save this in your neovim config as lua/multi_buffer_search.lua
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local conf = require('telescope.config').values
local make_entry = require('telescope.make_entry')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

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
            col = 0,
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
                self.ns_id = vim.api.nvim_create_namespace("telescope_multi_buffer_search")
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

            -- If we have the prompt and current line text, highlight the specific match
            local prompt = status.picker and status.picker.prompt and status.picker.prompt:get_prompt()
            if prompt and prompt ~= "" and entry.lnum <= #content then
                local line = content[entry.lnum]
                local start_col, end_col = line:find(prompt, 1, true)

                if start_col then
                    -- Add specific match highlighting (using IncSearch which is usually a different color than Search)
                    vim.api.nvim_buf_add_highlight(
                        self.state.bufnr,  -- buffer handle
                        self.ns_id,        -- namespace ID
                        "IncSearch",       -- highlight group
                        entry.lnum - 1,    -- line (0-indexed)
                        start_col - 1,     -- start column (0-indexed)
                        end_col            -- end column
                    )
                end
            end

            -- Position the cursor and center the view
            vim.api.nvim_win_set_cursor(status.preview_win, {entry.lnum, 0})
            local height = vim.api.nvim_win_get_height(status.preview_win)
            local start_line = math.max(1, entry.lnum - math.floor(height / 2))
            vim.api.nvim_win_set_cursor(status.preview_win, {start_line, 0})
            vim.api.nvim_win_set_cursor(status.preview_win, {entry.lnum, 0})
        end
    })

    -- Create the picker
    pickers.new(opts, {
        prompt_title = "Search All Buffers",
        finder = finders.new_table({
            results = get_all_buffer_lines(),
            entry_maker = entry_maker
        }),
        sorter = require('telescope.sorters').Sorter:new({
            scoring_function = function(_, prompt, line)
                -- Case-sensitive matching
                if not prompt or prompt == "" then
                    return 1
                end

                if line:find(prompt, 1, true) then
                    return 1
                else
                    return -1
                end
            end
        }),
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
    multi_buffer_exact_find = multi_buffer_exact_find
}
