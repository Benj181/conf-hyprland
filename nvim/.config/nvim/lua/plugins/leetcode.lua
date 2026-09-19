-- leetcode.nvim: browse, run and submit LeetCode problems from nvim.
-- Launch with `cd ~/dev/leet-code && nvim leetcode.nvim`.

local home = vim.fn.expand "~/dev/leet-code"

-- Each solution is a loose `<id>.<slug>.rs` file, which rust-analyzer ignores
-- unless it belongs to a project. Rather than a Cargo workspace (file names with
-- dots and dashes can't be modules), list every file as its own crate in a
-- rust-project.json and ask rust-analyzer to reload whenever a question opens.
local function sync_rust_project()
  local sysroot = vim.trim(vim.fn.system { "rustc", "--print", "sysroot" })
  local crates = {}
  for _, file in ipairs(vim.fn.glob(home .. "/*.rs", false, true)) do
    table.insert(crates, { root_module = vim.fn.fnamemodify(file, ":t"), edition = "2021", deps = {}, cfg = {} })
  end
  vim.fn.writefile({
    vim.json.encode {
      sysroot = sysroot,
      sysroot_src = sysroot .. "/lib/rustlib/src/rust/library",
      crates = crates,
    },
  }, home .. "/rust-project.json")
  for _, client in ipairs(vim.lsp.get_clients { name = "rust_analyzer" }) do
    client:request("rust-analyzer/reloadWorkspace", nil, function() end)
  end
end

-- Types LeetCode's judge defines for you. Injected code is stripped on run/submit.
local rust_prelude = {
  "#[allow(dead_code)]",
  "struct Solution;",
  "",
  "#[allow(dead_code)]",
  "#[derive(PartialEq, Eq, Clone, Debug)]",
  "pub struct ListNode {",
  "    pub val: i32,",
  "    pub next: Option<Box<ListNode>>,",
  "}",
  "",
  "#[allow(dead_code)]",
  "#[derive(Debug, PartialEq, Eq)]",
  "pub struct TreeNode {",
  "    pub val: i32,",
  "    pub left: Option<std::rc::Rc<std::cell::RefCell<TreeNode>>>,",
  "    pub right: Option<std::rc::Rc<std::cell::RefCell<TreeNode>>>,",
  "}",
}

---@type LazySpec
return {
  "kawre/leetcode.nvim",
  cmd = "Leet",
  lazy = vim.fn.argv(0, -1) ~= "leetcode.nvim",
  build = function() vim.cmd "TSInstall html" end,
  dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
  opts = {
    arg = "leetcode.nvim",
    lang = "rust",
    storage = { home = home },
    picker = { provider = "snacks-picker" },
    injector = {
      rust = { before = rust_prelude },
    },
    hooks = {
      question_enter = {
        function(q)
          if q.lang == "rust" then sync_rust_project() end
        end,
      },
    },
  },
}
