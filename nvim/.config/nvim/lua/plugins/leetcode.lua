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
  -- capital `L` group: lowercase `<Leader>l` is AstroNvim's LSP group
  -- (`<Leader>lr` is already bound to LSP rename on Rust buffers)
  --
  -- Covers every active top-level `:Leet` subcommand (see
  -- leetcode.nvim's lua/leetcode/command/init.lua:601 `cmd.commands`)
  -- except: `test`/`hints` (pure aliases of run/info), the commented-out
  -- `session` subtree (inactive in the plugin itself), and `cookie`/
  -- `cache`/`fix` (account sign-in and cache-wipe admin actions -- `fix`
  -- specifically deletes the local cache and quits Neovim, not something
  -- to bind to a key you might fat-finger).
  keys = {
    -- solving a question
    { "<leader>Lr", "<cmd>Leet run<cr>", desc = "Run tests" },
    { "<leader>Ls", "<cmd>Leet submit<cr>", desc = "Submit" },
    { "<leader>LR", "<cmd>Leet reset<cr>", desc = "Reset code" },
    { "<leader>Lp", "<cmd>Leet last_submit<cr>", desc = "Restore last submission" },
    { "<leader>Lj", "<cmd>Leet inject<cr>", desc = "Re-inject boilerplate" },
    { "<leader>Lf", "<cmd>Leet fold<cr>", desc = "Fold imports" },
    { "<leader>Ly", "<cmd>Leet yank<cr>", desc = "Yank solution code" },

    -- finding a question
    { "<leader>Ll", "<cmd>Leet list<cr>", desc = "List questions" },
    { "<leader>Lz", "<cmd>Leet random<cr>", desc = "Random question" },
    { "<leader>Ld", "<cmd>Leet daily<cr>", desc = "Question of the day" },
    { "<leader>Lo", "<cmd>Leet open<cr>", desc = "Open in browser" },

    -- navigation / UI
    { "<leader>Lt", "<cmd>Leet tabs<cr>", desc = "Tabs" },
    { "<leader>Lm", "<cmd>Leet menu<cr>", desc = "Menu" },
    { "<leader>Lv", "<cmd>Leet restore<cr>", desc = "Restore layout" },
    { "<leader>Lc", "<cmd>Leet console<cr>", desc = "Console" },
    { "<leader>Li", "<cmd>Leet info<cr>", desc = "Info" },
    { "<leader>LD", "<cmd>Leet desc<cr>", desc = "Toggle description" },
    { "<leader>La", "<cmd>Leet lang<cr>", desc = "Change language" },
    { "<leader>Lq", "<cmd>Leet exit<cr>", desc = "Exit" },
  },
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
