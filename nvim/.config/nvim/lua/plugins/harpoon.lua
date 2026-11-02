-- harpoon: pin a handful of files per project and jump between them by slot.
-- harpoon2 lives on its own branch; master is the old, unmaintained v1 API.

local function harpoon() return require "harpoon" end

local function select(i)
  return function() harpoon():list():select(i) end
end

---@type LazySpec
return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    settings = { save_on_toggle = true },
  },
  config = function(_, opts) harpoon():setup(opts) end,
  keys = {
    { "<Leader>a", function() harpoon():list():add() end, desc = "Harpoon file" },
    {
      "<Leader><Leader>",
      function() harpoon().ui:toggle_quick_menu(harpoon():list()) end,
      desc = "Harpoon menu",
    },
    { "<Leader>1", select(1), desc = "Harpoon file 1" },
    { "<Leader>2", select(2), desc = "Harpoon file 2" },
    { "<Leader>3", select(3), desc = "Harpoon file 3" },
    { "<Leader>4", select(4), desc = "Harpoon file 4" },
    { "[h", function() harpoon():list():prev() end, desc = "Previous harpoon file" },
    { "]h", function() harpoon():list():next() end, desc = "Next harpoon file" },
  },
}
