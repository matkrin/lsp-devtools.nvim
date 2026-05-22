local state = require("lsp-devtools.state")
local ui = require("lsp-devtools.ui")
local event_kind = require("lsp-devtools").event_kind

local M = {}

local attached_clients = {}

--- Hooks into Neovim's `rpc.request` by overwriting it with our custom handler
--- that tracks LSP events and saves them in `state` and updates `ui`
---@param client vim.lsp.Client
function M.attach(client)
    if attached_clients[client.id] then
        return
    end
    attached_clients[client.id] = true

    local rpc = client.rpc
    if not rpc then
        return
    end


    -- Requests
    if rpc.request then
        local orig_request = rpc.request

        rpc.request = function(method, params, handler, ...)
            local event = state.new_event(event_kind.REQUEST, method, params, client.id)

            vim.schedule(ui.render_timeline)

            ---@diagnostic disable-next-line: redundant-parameter
            return orig_request(method, params, function(err, result, ctx, config)
                event.end_time = state.now()
                event.result = result
                event.error = err

                vim.schedule(ui.render_timeline)

                if handler then
                    -- Call original handler
                    ---@diagnostic disable-next-line: redundant-parameter
                    return handler(err, result, ctx, config)
                end
            end, ...)
        end
    end

    -- Outgoing notifications
    if rpc.notify then
        local orig_notify = rpc.notify

        rpc.notify = function(method, params)
            state.new_event(event_kind.CLIENT_NOTIFICATION, method, params, client.id)

            vim.schedule(ui.render_timeline)

            return orig_notify(method, params)
        end
    end

    -- Incoming notifications
    local original_handlers = vim.tbl_extend(
        "force",
        vim.lsp.handlers,
        client.handlers or {}
    )

    client.handlers = {}

    for method, handler in pairs(original_handlers) do
        if type(handler) == "function" then
            client.handlers[method] = function(err, result, ctx, config)
                state.new_event(event_kind.SERVER_NOTIFICATION, method, result, client.id)

                vim.schedule(ui.render_timeline)

                return handler(err, result, ctx, config)
            end
        else
            client.handlers[method] = handler
        end
    end
end

return M
