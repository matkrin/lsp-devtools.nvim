local config = require("lsp-devtools").config

---@alias LspJson table<string, any> | any[]

---@class LspDevtoolsEvent
---@field id integer
---@field kind string
---@field method string
---@field params LspJson | nil
---@field result LspJson | nil
---@field error table | nil
---@field start_time number
---@field end_time number | nil
---@field client_id integer


local M = {}


---@class LspDevtoolsState
---@field events LspDevtoolsEvent[]
---@field max integer
---@field next_id integer
local state = {
    events = {},
    next_id = 1,
}

--- Get a current time for measurement of intervals
function M.now()
    return vim.loop.hrtime() / 1e6 -- ms
end

--- Add and event to state
---@param event LspDevtoolsEvent
function state:add_event(event)
    if not config.filter(event) then
        return
    end

    table.insert(self.events, event)

    if #self.events > config.max_events then
        table.remove(self.events, 1)
    end
end

--- Create an event and return it to the caller
---@param kind string
---@param method string
---@param params table|nil
---@param client_id integer
---@return LspDevtoolsEvent
function M.new_event(kind, method, params, client_id)
    local ev = {
        id = state.next_id,
        kind = kind,
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
