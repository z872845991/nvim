-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)
return {
	-- NOTE: Yes, you can install new plugins here!
	'mfussenegger/nvim-dap',
	-- NOTE: And you can specify dependencies as well
	dependencies = {
		-- Creates a beautiful debugger UI
		'rcarriga/nvim-dap-ui',

		-- Required dependency for nvim-dap-ui
		'nvim-neotest/nvim-nio',

		-- Installs the debug adapters for you
		'williamboman/mason.nvim',
		'jay-babu/mason-nvim-dap.nvim',

		-- Add your own debuggers here
		'leoluz/nvim-dap-go',
	},
	keys = {
		-- Basic debugging keymaps, feel free to change to your liking!
		{
			'<leader>os',
			function()
				require('dap').continue()
			end,
			desc = 'Debug: Start/Continue',
		},
		{
			'<leader>oj',
			function()
				require('dap').step_over()
			end,
			desc = 'Debug: Step Over',
		},
		{
			'<leader>ok',
			function()
				require('dap').step_into()
			end,
			desc = 'Debug: Step Into',
		},
		{
			'<leader>ol',
			function()
				require('dap').step_out()
			end,
			desc = 'Debug: Step Out',
		},
		{
			'<leader>ob',
			function()
				require('dap').toggle_breakpoint()
			end,
			desc = 'Debug: Toggle Breakpoint',
		},
		{
			'<leader>oB',
			function()
				require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
			end,
			desc = 'Debug: Set Breakpoint',
		},
		-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
		{
			'<leader>op',
			function()
				require('dapui').toggle()
			end,
			desc = 'Debug: See last session result.',
		},
	},
	config = function()
		local dap = require 'dap'
		local dapui = require 'dapui'

		require('mason-nvim-dap').setup {
			-- Makes a best effort to setup the various debuggers with
			-- reasonable debug configurations
			automatic_installation = true,

			-- You can provide additional configuration to the handlers,
			-- see mason-nvim-dap README for more information
			handlers = {},

			-- You'll need to check that you have the required things installed
			-- online, please don't ask me how to install them :)
			ensure_installed = {
				-- Update this to ensure that you have the debuggers for the langs you want
				'delve',
				'python',
			},
		}

		-- Dap UI setup
		-- For more information, see |:help nvim-dap-ui|
		dapui.setup {
			-- Set icons to characters that are more likely to work in every terminal.
			--    Feel free to remove or use ones that you like more! :)
			--    Don't feel like these are good choices.
			icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
			controls = {
				icons = {
					pause = '⏸',
					play = '▶',
					step_into = '⏎',
					step_over = '⏭',
					step_out = '⏮',
					step_back = 'b',
					run_last = '▶▶',
					terminate = '⏹',
					disconnect = '⏏',
				},
			},
		}

		-- Change breakpoint icons
		-- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
		-- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
		-- local breakpoint_icons = vim.g.have_nerd_font
		--     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
		--   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
		-- for type, icon in pairs(breakpoint_icons) do
		--   local tp = 'Dap' .. type
		--   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
		--   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
		-- end

		dap.listeners.after.event_initialized['dapui_config'] = dapui.open
		dap.listeners.before.event_terminated['dapui_config'] = dapui.close
		dap.listeners.before.event_exited['dapui_config'] = dapui.close

		-- debugpy adapter
		dap.adapters.python = function(cb, config)
			if config.request == 'attach' then
				---@diagnostic disable-next-line: undefined-field
				local port = (config.connect or config).port
				---@diagnostic disable-next-line: undefined-field
				local host = (config.connect or config).host or '127.0.0.1'
				cb({
					type = 'server',
					port = assert(port, '`connect.port` is required for a python `attach` configuration'),
					host = host,
					options = {
						source_filetype = 'python',
					},
				})
			else
				local env_path = os.getenv("CONDA_PREFIX") or os.getenv("VIRTUAL_ENV")
				if env_path then
					env_path = env_path .. "/bin"
				else
					env_path = "/usr/bin"
				end
				cb({
					type = 'executable',
					command = env_path .. "/python",
					args = { '-m', 'debugpy.adapter' },
					options = {
						source_filetype = 'python',
					},
				})
			end
		end
		-- debugpy configuration
		local dap = require('dap')
		dap.configurations.python = {
			{
				-- The first three options are required by nvim-dap
				type = 'python', -- the type here established the link to the adapter definition: `dap.adapters.python`
				request = 'launch',
				name = "Launch file",

				program = "${file}", -- This configuration will launch the current file if used.
				args = function()
					local input = vim.fn.input("Please Input Args: ")
					return vim.split(input, " ", { trimempty = true })
				end,
				pythonPath = function()
					-- debugpy supports launching an application with a different interpreter then the one used to launch debugpy itself.
					-- The code below looks for a `venv` or `.venv` folder in the current directly and uses the python within.
					-- You could adapt this - to for example use the `VIRTUAL_ENV` environment variable.

					local conda_prefix = os.getenv("CONDA_PREFIX")
					if conda_prefix then
						return conda_prefix .. "/bin/python"
					end
					-- 如果没有 conda，再检查 virtualenv 环境变量
					local virtualenv = os.getenv("VIRTUAL_ENV")
					if virtualenv then
						return virtualenv .. "/bin/python"
					end

					local cwd = vim.fn.getcwd()
					if vim.fn.executable(cwd .. '/venv/bin/python') == 1 then
						return cwd .. '/venv/bin/python'
					elseif vim.fn.executable(cwd .. '/.venv/bin/python') == 1 then
						return cwd .. '/.venv/bin/python'
					else
						return '/usr/bin/python'
					end
				end,
			},
		}


		-- Install golang specific config
		require('dap-go').setup {
			delve = {
				-- On Windows delve must be run attached or it crashes.
				-- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
				detached = vim.fn.has 'win32' == 0,
			},
		}
	end,
}
