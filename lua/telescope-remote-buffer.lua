local M = {}

function M.setup(opts)
    local nmap = function(keys, func, desc)
        vim.keymap.set(
            'n',
            keys,
            func,
            {
                desc = desc,
                noremap = true
            }
        )
    end

    local multi_buffer_fzf = require("telescope_multi_buffer_fzf")
    local multi_buffer_match = require("telescope_multi_buffer_match")
    local recent_buffers = require("telescope_recent_buffers")

    local fzf_mapping
    if opts.fzf then
        fzf_mapping = opts.fzf
    else
        fzf_mapping = "<leader>fz"
    end
    nmap(fzf_mapping, function() multi_buffer_fzf.multi_buffer_fuzzy_find() end, "Fuzzy find in open buffers")

    local match_mapping
    if opts.match then
        match_mapping = opts.match
    else
        match_mapping = "<leader>gb"
    end
    nmap(match_mapping, function() multi_buffer_match.multi_buffer_exact_find() end, "Grep through all open buffers for exact query match")

    local oldfiles_mapping
    if opts.oldfiles then
        oldfiles_mapping = opts.oldfiles
    else
        oldfiles_mapping = "<leader>rb"
    end
    nmap(oldfiles_mapping, function() recent_buffers.show_recent_buffers() end, 'Show recently accessed buffers of all kinds')
end

return M
