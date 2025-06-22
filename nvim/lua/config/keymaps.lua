vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Like VSCode keymaps
vim.keymap.set("n", "<C-/>", "gcc", { desc = "Toggle comment", remap = true })
