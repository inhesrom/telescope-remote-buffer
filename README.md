# Remote Buffer Telescope Extensions
This plugin was created to support usage of [remote-ssh.nvim](https://github.com/inhesrom/remote-ssh.nvim)
It allows using telescope on buffers loaded with remote content, where no local file exists for the buffer contents as it was loaded from a remote buffer over SSH

## Features
- Fuzzy find in all open buffers
- Grep through all open buffers
- Look at recently opened buffers (especially remote buffers)

## Setup
```lua
return {
    "inhesrom/telescope-remote-buffer",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim"
    },
    config = function()
        require("telescope-remote-buffer").setup({
            -- fzf = 'mapping to trigger fuzzy finding' --default: <leader>fz
            -- match = 'mapping to trigger matching' --default: <leader>gb
            -- oldfiles = 'mapping to show recent/old buffers including buffers with remote content' --default: <leader>rb
        })
    end
}
```
