-- Custom telescope extension for tracking and reopening recent buffers
-- Save this in your neovim config as lua/telescope_recent_buffers.lua

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

-- Module for tracking recent buffers
local M = {}
M.recent_buffers = {}
M.max_buffers = 100
M.cache_file = vim.fn.stdpath("data") .. "/telescope_recent_buffers.json"

-- Function to add a buffer to our recent list
local function add_buffer(bufnr)
    -- Skip special/invalid buffers
    if bufnr == nil or vim.fn.buflisted(bufnr) == 0 then
        return
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        -- Skip unnamed buffers
        return
    end

    -- Get appropriate display name based on buffer type
    local display_name
    if bufname:match("^rsync://") then
        -- For remote buffers, use the last part of the path
        display_name = bufname:match("([^/]+)$") or vim.fn.fnamemodify(bufname, ":t")
    else
        display_name = vim.fn.fnamemodify(bufname, ":t")
    end

    -- Don't add if it's already the most recent buffer
    if #M.recent_buffers > 0 and M.recent_buffers[1].bufname == bufname then
        return
    end

    -- Remove this buffer if it's already in our list
    for i, buf in ipairs(M.recent_buffers) do
        if buf.bufname == bufname then
            table.remove(M.recent_buffers, i)
            break
        end
    end

    -- Add the buffer to the beginning of our list
    table.insert(M.recent_buffers, 1, {
        bufnr = bufnr,
        bufname = bufname,
        display_name = display_name,
        last_used = os.time()
    })

    -- Prune list if it gets too long
    if #M.recent_buffers > M.max_buffers then
        table.remove(M.recent_buffers)
    end
end

-- Setup autocommands to track buffer activity
-- Save recent buffers to disk
function M.save_recent_buffers()
    -- Create a serializable version of our buffer data
    local data_to_save = {}
    for _, buf in ipairs(M.recent_buffers) do
        table.insert(data_to_save, {
            bufname = buf.bufname,
            display_name = buf.display_name,
            last_used = buf.last_used
        })
    end

    -- Convert to JSON and save to file
    local file = io.open(M.cache_file, "w")
    if file then
        file:write(vim.fn.json_encode(data_to_save))
        file:close()
    end
end

-- Load recent buffers from disk
function M.load_recent_buffers()
    local file = io.open(M.cache_file, "r")
    if not file then
        return
    end

    local content = file:read("*all")
    file:close()

    if content and content ~= "" then
        local ok, data = pcall(vim.fn.json_decode, content)
        if ok and data then
            M.recent_buffers = {}
            for _, buf_data in ipairs(data) do
                table.insert(M.recent_buffers, {
                    bufnr = nil, -- Will be set if/when the buffer is reopened
                    bufname = buf_data.bufname,
                    display_name = buf_data.display_name,
                    last_used = buf_data.last_used
                })
            end
        end
    end
end

function M.setup()
    local augroup = vim.api.nvim_create_augroup("TelescopeRecentBuffers", { clear = true })

    -- Track when buffers are entered
    vim.api.nvim_create_autocmd({"BufEnter"}, {
        group = augroup,
        callback = function(args)
            add_buffer(args.buf)
        end,
    })

    -- Save buffers when Neovim is about to exit
    vim.api.nvim_create_autocmd({"VimLeavePre"}, {
        group = augroup,
        callback = function()
            M.save_recent_buffers()
        end,
    })

    -- Load saved buffers
    M.load_recent_buffers()

    -- Add all current buffers on startup
    local buffers = vim.api.nvim_list_bufs()
    for _, bufnr in ipairs(buffers) do
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.fn.buflisted(bufnr) == 1 then
            add_buffer(bufnr)
        end
    end
end

-- Telescope picker for recent buffers
function M.show_recent_buffers(opts)
    opts = opts or {}

    -- Create entries for telescope
    local results = {}
    for _, buf in ipairs(M.recent_buffers) do
        -- Check if this buffer is still valid
        local is_valid = buf.bufnr ~= nil and type(buf.bufnr) == "number" and vim.api.nvim_buf_is_valid(buf.bufnr)

        if not is_valid then
            -- Buffer doesn't exist or is invalid
            local exists = vim.fn.filereadable(buf.bufname) == 1
            table.insert(results, {
                value = buf,
                ordinal = buf.display_name,
                display = string.format("%s [%s]", buf.display_name, exists and "file exists" or "closed"),
                filename = buf.bufname,
                bufname = buf.bufname,
                last_used = buf.last_used
            })
        else
            -- Buffer still exists
            table.insert(results, {
                value = buf,
                ordinal = buf.display_name,
                display = string.format("%s [open]", buf.display_name),
                filename = buf.bufname,
                bufname = buf.bufname,
                bufnr = buf.bufnr,
                last_used = buf.last_used
            })
        end
    end

    -- Create the picker
    pickers.new(opts, {
        prompt_title = "Recent Buffers",
        finder = finders.new_table({
            results = results,
            entry_maker = function(entry)
                return entry
            end
        }),
        sorter = sorters.get_fuzzy_file(),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(prompt_bufnr, map)
            -- Default action: open the buffer if it exists, or the file if it doesn't
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                if selection.bufnr and vim.api.nvim_buf_is_valid(selection.bufnr) then
                    -- If buffer still exists, switch to it
                    local win = vim.api.nvim_get_current_win()
                    vim.api.nvim_win_set_buf(win, selection.bufnr)
                    vim.cmd("buffer " .. selection.bufnr)
                    vim.api.nvim_set_current_buf(selection.bufnr)
                else
                    -- Handle remote paths (rsync://) differently
                    if selection.bufname:match("^rsync://") or selection.bufname:match("^scp://") then
                        -- Use the improved simple_open_remote_file function
                        require('async-remote-write.operations').simple_open_remote_file(selection.bufname, nil, {refresh = true})

                        -- Ensure TreeSitter highlighting is applied
                        vim.defer_fn(function()
                            local bufnr = vim.api.nvim_get_current_buf()
                            if vim.api.nvim_buf_is_valid(bufnr) then
                                local buffer_path = vim.api.nvim_buf_get_name(bufnr)
                                vim.cmd("doautocmd BufReadPost " .. vim.fn.fnameescape(buffer_path))
                            end
                        end, 100)
                    else
                        -- Otherwise, try to open the file normally
                        if vim.fn.filereadable(selection.bufname) == 1 then
                            vim.cmd("edit " .. vim.fn.fnameescape(selection.bufname))
                        else
                            vim.notify("File " .. selection.bufname .. " no longer exists.", vim.log.levels.WARN)
                        end
                    end
                end
            end)

            -- You can add additional custom mappings here
            return true
        end
    }):find()
end

return M
