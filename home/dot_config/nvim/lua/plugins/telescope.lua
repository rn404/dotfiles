return {
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      get_selection_window = function()
        return vim.api.nvim_get_current_win()
      end,
    },
  },
}
