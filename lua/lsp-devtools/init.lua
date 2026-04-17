local M = {}

local ui = require("lsp-devtools.ui")

function M.setup()
    vim.api.nvim_create_user_command("LspDev", function()
        ui.open()
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
