# lsp-devtools.nvim

A Neovim plugin for inspecting and replaying LSP requests in real time.

`lsp-devtools.nvim` hooks into Neovim's internal LSP RPC layer
(`client.rpc.request`) and records outgoing requests, response times, results,
and errors. It provides an interactive UI showing a timeline of LSP events that
helps debugging.

To start the interactive UI the `LspDev` command is provided. This will open a
split showing LSP requests in a live-updating timeline. Sent requests are marked
with an `→`, requests that additionally received responses with `←` and long
response times are highlighted.

From the timeline view you can further inspect the request under the curser by
pressing <kbd>Enter</kbd> which opens another split showing details like the LSP
method, the client ID, the request duration, request params and response
results.

Pressing <kbd>r</kbd> on a timeline event opens a pop-up window containing this
request's JSON. You can modify the payload and hit <kbd>Enter</kbd> to resend
the request with the modified parameters to the language server.

Only tested with Neovim 0.12

## Installation

<details><summary>vim.pack (Neovim 0.12+)</summary>

```lua
vim.pack.add({
    {
        src = "https://github.com/matkrin/lsp-devtools.nvim",
    },
})

require("lsp-devtools").setup()
```

</details>

<details><summary>lazy.nvim</summary>

```lua
{
    "matkrin/lsp-devtools.nvim",
    config = function()
        require("lsp-devtools").setup()
    end,
}
```

</details>
<details><summary>packer.nvim</summary>

```lua
use({
    "matkrin/lsp-devtools.nvim",
    config = function()
        require("lsp-devtools").setup()
    end,
})
```

</details>

## Usage

Open the timeline UI:

```vim
:LspDev
```

The plugin automatically attaches to all LSP clients using the `LspAttach`
autocmd.

## Configuration

```lua
---@class LspDevtoolsConfig
---@field max_events integer  Maximum stored event
---@field slow_request_threshold integer  Threshold used to mark slow requests
---@field autoscroll boolean  Autoscroll of timeline
---@field filter fun(event:LspDevtoolsEvent):boolean  Call back for filtering events
default_config = {
    max_events = 300,
    slow_request_threshold = 200,
    autoscroll = true,
    filter = function(_)
        return true
    end,
}
```

### Filtering of LSP event

```lua
--- REQUEST | CLIENT_NOTIFICATION | SERVER_NOTIFICATION
local event_kind = require("lsp-devtools").event_kind

require("lsp-devtools").setup({
    -- ...
    filter = function(event)

        -- Only requests, no notifications
        if event.kind ~= event_kind.REQUEST then
            return false
        end

        -- Ignore semantic tokens
        if event.method:match("semanticTokens") then
            return false
        end

        -- Ignore signature help
        if event.method:match("signatureHelp") then
            return false
        end

        return true
    end,
})
```

## Keymaps

### Timeline Window

| Key    | Action                 |
| ------ | ---------------------- |
| `<CR>` | Inspect selected event |
| `r`    | Replay selected event  |
| `t`    | Toggle auto-scroll     |
| `q`    | Close timeline window  |

### Inspector Window

| Key | Action                 |
| --- | ---------------------- |
| `q` | Close inspector window |

### Replay Window

| Key    | Action              |
| ------ | ------------------- |
| `<CR>` | Send replay request |
| `q`    | Close replay window |
