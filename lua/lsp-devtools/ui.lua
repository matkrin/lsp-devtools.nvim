local STATE = require("lsp-devtools.state").state
local devtools = require("lsp-devtools")
local event_kind = require("lsp-devtools").event_kind

local M = {}

---@type integer | nil
local timeline_buf = nil

---@type boolean
local autoscroll = devtools.config.autoscroll

---@type integer
local ns = vim.api.nvim_create_namespace("lspdev")


--- Set buffer lines by temporarily make buffer modifiable
---@param buf integer Buffer id where lines to set
---@param lines string[] Lines to set into `buf`
local function safe_set_lines(buf, lines)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end


--- Pretty format JSON
---@param json_value any JSON Lua object
---@return string  # Stringified, prettified `json_value`
local function pretty_json(json_value)
    if vim.json and vim.json.encode then
        local ok, result = pcall(vim.json.encode, json_value, { indent = "  " })
        if ok then
            return result
        end
    end
    -- Fallback to older API
    return vim.fn.json_encode(json_value)
end


--- Split prettified JSON string of `value` at newlines
---@param json_value any JSON Lua object
---@return string[]  # List of lines of stringified and prettified `json_value`
local function split_json(json_value)
    return vim.split(pretty_json(json_value), "\n", { trimempty = true })
end


--- Format `event` as a timeline entry
---@param event LspDevtoolsEvent Event to format
---@return string  # The formatted event timeline entry
local function format_timeline_event(event)
    local icon = "  "
    if event.kind == event_kind.CLIENT_NOTIFICATION then
        icon = "C!"
    elseif event.kind == event_kind.SERVER_NOTIFICATION then
        icon = "S!"
    elseif event.kind == event_kind.REQUEST then
        icon = event.end_time and "← " or "→ "
    end
    if event.error then
        icon = "✖ "
    end
    local duration = event.end_time and string.format(" %dms", event.end_time - event.start_time) or ""
    return string.format("%s %-30s%s", icon, event.method, duration)
end


--- Render the chronological list of LSP events
function M.render_timeline()
    if not timeline_buf or not vim.api.nvim_buf_is_valid(timeline_buf) then
        return
    end

    local win = vim.fn.bufwinid(timeline_buf)
    local cursor = nil

    if win ~= -1 and autoscroll then
        local last_line = vim.api.nvim_buf_line_count(timeline_buf)
        vim.api.nvim_win_set_cursor(win, { last_line, 0 })
    end

    local lines = {}
    for i, ev in ipairs(STATE.events) do
        lines[i] = format_timeline_event(ev)
    end

    -- vim.api.nvim_buf_set_lines(timeline_buf, 0, -1, false, lines)
    safe_set_lines(timeline_buf, lines)

    vim.api.nvim_buf_clear_namespace(timeline_buf, ns, 0, -1)

    for i, ev in ipairs(STATE.events) do
        if ev.end_time and (ev.end_time - ev.start_time) > devtools.config.slow_request_threshold then
            vim.hl.range(timeline_buf, ns, "WarningMsg", { i - 1, 0 }, { i - 1, -1 })
        end
    end

    if win ~= -1 and cursor then
        pcall(vim.api.nvim_win_set_cursor, win, cursor)
    end
end

---@param buf integer Buffer id for which to set keymaps
local function set_keymaps(buf)
    -- Inspect
    vim.keymap.set("n", "<CR>", function()
        local line = vim.fn.line(".")
        local event = STATE.events[line]
        if event then
            M.open_inspector(event)
        end
    end, { buffer = buf, desc = "Inspect event under cursor in new split" })

    -- Replay
    vim.keymap.set("n", "r", function()
        local line = vim.fn.line(".")
        local event = STATE.events[line]
        if event then
            M.replay(event)
        end
    end, { buffer = buf, desc = "Replay an event" })

    -- Close
    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(0, true)
    end, { buffer = buf, desc = "Close timeline/event buffer" })

    -- Toggle auto scroll
    vim.keymap.set("n", "t", function()
        autoscroll = not autoscroll
        vim.notify("LspDev autoscroll: " .. tostring(autoscroll), vim.log.levels.INFO)
    end, { buffer = timeline_buf, desc = "Toggle auto-scroll of timeline" })
end

--- Open event timeline view
function M.open()
    -- If buffer exists and is visible -> jump to it
    if timeline_buf and vim.api.nvim_buf_is_valid(timeline_buf) then
        local win = vim.fn.bufwinid(timeline_buf)

        if win ~= -1 then
            vim.api.nvim_set_current_win(win)
            return
        end

        -- Buffer exists but not visible -> open it in a split
        vim.cmd("split")
        vim.api.nvim_win_set_buf(0, timeline_buf)
        return
    end

    -- Buffer doesn't exist -> create fresh
    timeline_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[timeline_buf].filetype = "lspdev"
    vim.bo[timeline_buf].buftype = "nofile"
    vim.bo[timeline_buf].swapfile = false
    vim.bo[timeline_buf].bufhidden = "hide"

    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, timeline_buf)

    set_keymaps(timeline_buf)
    M.render_timeline()

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = timeline_buf,
        callback = function()
            local win = vim.fn.bufwinid(timeline_buf)
            if win == -1 then return end

            local last_line = vim.api.nvim_buf_line_count(timeline_buf)
            local cursor = vim.api.nvim_win_get_cursor(win)[1]

            -- If user is NOT near bottom -> disable follow mode
            if cursor < last_line - 2 then
                autoscroll = false
            else
                autoscroll = true
            end
        end,
    })
end

---@param event LspDevtoolsEvent
function M.open_inspector(event)
    local buf = vim.api.nvim_create_buf(false, true)

    local lines = {
        "method: " .. event.method,
        "client: " .. event.client_id,
        event.end_time and ("duration: " .. (event.end_time - event.start_time) .. "ms") or "pending",
        "",
        "params:",
        "",
    }

    vim.list_extend(lines, split_json(event.params or {}))
    vim.list_extend(lines, { "", "result:", "" })
    vim.list_extend(lines, split_json(event.result or {}))

    -- vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    safe_set_lines(buf, lines)
    vim.bo[buf].filetype = "json"

    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)

    -- folding
    vim.wo.foldmethod = "indent"
    vim.wo.foldlevel = 99

    -- Close inspector buffer
    vim.keymap.set("n", "q", "<cmd>bd!<cr>", { buffer = buf })
end

---@param event LspDevtoolsEvent
---@param client vim.lsp.Client
---@param buf integer
local function send_replay(event, client, buf)
    local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local ok, decoded = pcall(vim.fn.json_decode, content)

    if not ok then
        vim.notify("LspDev - Error: Invalid JSON", vim.log.levels.ERROR)
        return
    end

    client:request(event.method, decoded, function(err, _)
        if err then
            vim.notify("LspDev - Replayed: " .. event.method .. " error", vim.log.levels.ERROR)
        else
            vim.notify("LspDev - Replayed: " .. event.method .. " ok", vim.log.levels.INFO)
        end
    end)
end

---@param event LspDevtoolsEvent
function M.replay(event)
    local client = vim.lsp.get_client_by_id(event.client_id)
    if not client then
        vim.notify("LspDev - Error: No client", vim.log.levels.ERROR)
        return
    end
    if event.kind ~= event_kind.REQUEST then
        vim.notify("LspDev - Only requests can be replayed", vim.log.levels.WARN)
        return
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, split_json(event.params or {}))
    vim.bo[buf].filetype = "json"

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = 80,
        height = 20,
        row = 5,
        col = 10,
        border = "single",
    })

    --- Send replay
    vim.keymap.set("n", "<CR>", function()
        send_replay(event, client, buf)
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf })

    --- Close replay edit
    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf })
end

return M
