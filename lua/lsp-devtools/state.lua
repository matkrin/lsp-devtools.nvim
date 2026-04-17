---@alias LspJson table<string, any>|any[]

---@class LspDevtoolsEvent
---@field id integer
---@field method string
---@field params LspJson|nil
---@field result LspJson|nil
---@field error table|nil
---@field start_time number
---@field end_time number|nil
---@field client_id integer


local M = {}

---@class LspDevtoolsState
---@field events LspDevtoolsEvent[]
---@field max integer
---@field next_id integer
local state = {
    events = {},
    max = 300,
    next_id = 1,
}

function M.now()
    return vim.loop.hrtime() / 1e6 -- ms
end

---@param ev LspDevtoolsEvent
function state:add_event(ev)
    table.insert(self.events, ev)
    if #self.events > self.max then
        table.remove(self.events, 1)
    end
end

---@param method string
---@param params table|nil
---@param client_id integer
---@return LspDevtoolsEvent
function M.new_event(method, params, client_id)
    local ev = {
        id = state.next_id,
        method = method,
        params = params,
        result = nil,
        error = nil,
        start_time = M.now(),
        end_time = nil,
        client_id = client_id,
    }

    state.next_id = state.next_id + 1
    state:add_event(ev)

    return ev
end

M.state = state

return M
