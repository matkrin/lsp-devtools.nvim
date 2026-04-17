local state = require("lsp-devtools.state")
local ui = require("lsp-devtools.ui")

local M = {}

local attached_clients = {}

---@param client vim.lsp.Client
function M.attach(client)
    if attached_clients[client.id] then
        return
    end
    attached_clients[client.id] = true

    local rpc = client.rpc
    if not rpc or not rpc.request then
        return
    end

    local orig_request = rpc.request

    rpc.request = function(method, params, handler, ...)
        local ev = state.new_event(method, params, client.id)

        vim.schedule(ui.render_timeline)

        ---@diagnostic disable-next-line: redundant-parameter
        return orig_request(method, params, function(err, result, ctx, config)
            ev.end_time = state.now()
            ev.result = result
            ev.error = err

            vim.schedule(ui.render_timeline)

            if handler then
                ---@diagnostic disable-next-line: redundant-parameter
                return handler(err, result, ctx, config)
            end
        end, ...)
    end
end

return M
