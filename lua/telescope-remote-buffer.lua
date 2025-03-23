local M = {}

function M.setup(opts)
    local default_mappings = {
        fzf = "<leader>fz",
        match = "<leader>gb",
        oldfiles = "<leader>rb"
    }
    opts = opts or default_mappings -- Ensure opts exists otherwise set defaults

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
    recent_buffers.setup() --Start tracking buffers so they get stored off

    nmap(opts.fzf, function() multi_buffer_fzf.multi_buffer_fuzzy_find() end, "Fuzzy find in open buffers")
    nmap(opts.match, function() multi_buffer_match.multi_buffer_exact_find() end, "Grep through all open buffers for exact query match")
    nmap(opts.oldfiles, function() recent_buffers.show_recent_buffers() end, 'Show recently accessed buffers of all kinds')
end

return M
