local M = {}


---@class LspDevtoolsEventKind
---@field REQUEST "request"
---@field CLIENT_NOTIFICATION "client_notification"
---@field SERVER_NOTIFICATION "server_notification"
M.event_kind = {
    REQUEST = "request",
    CLIENT_NOTIFICATION = "client_notification",
    SERVER_NOTIFICATION = "server_notification",
}


---@class LspDevtoolsConfig
---@field max_events integer  Maximum stored event
---@field slow_request_threshold integer  Threshold used to mark slow requests
---@field autoscroll boolean  Autoscroll of timeline
---@field filter fun(event:LspDevtoolsEvent):boolean  Call back for filtering events
M.config = {
    max_events = 300,
    slow_request_threshold = 200,
    autoscroll = true,
    filter = function(_)
        return true
    end,
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    vim.api.nvim_create_user_command("LspDev", function()
        require("lsp-devtools.ui").open()
    end, {})

    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client then
                require("lsp-devtools.attach").attach(client)
            end
        end,
    })
end

return M
