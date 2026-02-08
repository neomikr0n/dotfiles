return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#131313',
				base01 = '#131313',
				base02 = '#a59e95',
				base03 = '#a59e95',
				base04 = '#fff6eb',
				base05 = '#fffbf6',
				base06 = '#fffbf6',
				base07 = '#fffbf6',
				base08 = '#ff8d85',
				base09 = '#ff8d85',
				base0A = '#ffc375',
				base0B = '#9fff8d',
				base0C = '#ffdfb6',
				base0D = '#ffc375',
				base0E = '#ffce8d',
				base0F = '#ffce8d',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#a59e95',
				fg = '#fffbf6',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#ffc375',
				fg = '#131313',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#a59e95' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#ffdfb6', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#ffce8d',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#ffc375',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#ffc375',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#ffdfb6',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#9fff8d',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#fff6eb' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#fff6eb' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#a59e95',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
