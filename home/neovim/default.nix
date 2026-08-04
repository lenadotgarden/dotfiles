{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
    
    extraPackages = with pkgs; [
      gcc
      git
      gnumake
      unzip
      tree-sitter
      ripgrep
      fd
      nodejs
      wl-clipboard
      xclip
    ];

    plugins = with pkgs.vimPlugins; [
      # Thèmes
      {
        plugin = catppuccin-nvim;
        type = "lua";
        config = ''
          require("catppuccin").setup({
            flavour = "auto",
            background = { light = "latte", dark = "mocha" },
            transparent_background = true,
            integrations = {
              cmp = true,
              gitsigns = true,
              nvimtree = true,
              treesitter = true,
              notify = true,
              native_lsp = { enabled = true },
            },
          })
          vim.cmd.colorscheme("catppuccin")
        '';
      }
      auto-dark-mode-nvim

      # Treesitter
      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = ''
          local status_ts, ts_configs = pcall(require, 'nvim-treesitter.configs')
          if status_ts then
            ts_configs.setup({
              highlight = { enable = true },
              indent = { enable = true },
            })
          end
        '';
      }
      nvim-treesitter-context

      # LSP & Completion
      nvim-lspconfig
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp_luasnip
      luasnip
      {
        plugin = nvim-cmp;
        type = "lua";
        config = ''
          local cmp = require('cmp')
          local luasnip = require('luasnip')
          cmp.setup({
            snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
            mapping = cmp.mapping.preset.insert({
              ['<C-b>'] = cmp.mapping.scroll_docs(-4),
              ['<C-f>'] = cmp.mapping.scroll_docs(4),
              ['<C-Space>'] = cmp.mapping.complete(),
              ['<CR>'] = cmp.mapping.confirm({ select = true }),
              ['<Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
                else fallback() end
              end, { 'i', 's' }),
            }),
            sources = cmp.config.sources({
              { name = 'nvim_lsp' },
              { name = 'luasnip' },
            }, {
              { name = 'buffer' },
              { name = 'path' },
            })
          })
        '';
      }

      # Navigation & Outils
      plenary-nvim
      nui-nvim
      nvim-web-devicons
      {
        plugin = neo-tree-nvim;
        type = "lua";
        config = ''
          require("neo-tree").setup({})
          vim.keymap.set("n", "<C-n>", ":Neotree filesystem toggle left<CR>", { silent = true })
        '';
      }
      {
        plugin = dashboard-nvim;
        type = "lua";
        config = ''
          require('dashboard').setup({
            theme = 'hyper',
            config = {
              header = {
                "",
                "   ██████╗  █████╗ ██████╗ ██████╗ ███████╗███╗   ██╗██╗   ██╗██╗███╗   ███╗",
                "  ██╔════╝ ██╔══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║██║   ██║██║████╗ ████║",
                "  ██║  ███╗███████║██████╔╝██║  ██║█████╗  ██╔██╗ ██║██║   ██║██║██╔████╔██║",
                "  ██║   ██║██╔══██║██╔══██╗██║  ██║██╔══╝  ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
                "  ╚██████╔╝██║  ██║██║  ██║██████╔╝███████╗██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
                "   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
                "",
              },
              shortcut = {
                { icon = ' ', desc = 'Find File', action = 'Telescope find_files', key = 'f' },
                { icon = ' ', desc = 'Find Text', action = 'Telescope live_grep', key = 'g' },
                { icon = ' ', desc = 'Dotfiles', action = 'Telescope find_files cwd=~/dotfiles', key = 'd' },
              },
              footer = {}
            },
          })
        '';
      }
      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
          local telescope = require("telescope")
          telescope.setup({
            defaults = { preview = { treesitter = false } }
          })
          local builtin = require("telescope.builtin")
          vim.keymap.set("n", "<C-o>", builtin.find_files, {})
          vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
        '';
      }
      telescope-ui-select-nvim
      vim-tmux-navigator
      gitsigns-nvim
      {
        plugin = harpoon;
        type = "lua";
        config = ''
          local mark = require("harpoon.mark")
          local ui = require("harpoon.ui")

          vim.keymap.set("n", "<leader>a", mark.add_file, { desc = "Ajouter le fichier à Harpoon" })
          vim.keymap.set("n", "<leader>h", ui.toggle_quick_menu, { desc = "Ouvrir le menu Harpoon" })

          vim.keymap.set("n", "<leader>1", function() ui.nav_file(1) end, { desc = "Sauter au fichier Harpoon 1" })
          vim.keymap.set("n", "<leader>2", function() ui.nav_file(2) end, { desc = "Sauter au fichier Harpoon 2" })
          vim.keymap.set("n", "<leader>3", function() ui.nav_file(3) end, { desc = "Sauter au fichier Harpoon 3" })
          vim.keymap.set("n", "<leader>4", function() ui.nav_file(4) end, { desc = "Sauter au fichier Harpoon 4" })
        '';
      }
      lazygit-nvim
      render-markdown-nvim
      {
        plugin = obsidian-nvim;
        type = "lua";
        config = ''
          require("obsidian").setup({
            legacy_commands = false,
            picker = {
              name = "telescope.nvim",
            },
            workspaces = {
              {
                name = "Garden",
                path = "~/Garden",
              },
            },
            daily_notes = {
              folder = "1 Journal",
              date_format = "%Y/%m/%Y-%m-%d %a",
              alias_format = "%B %d, %Y",
            },
            ui = {
              enable = true,
            },
            checkboxes = {
              [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
              ["x"] = { char = "", hl_group = "ObsidianDone" },
            },
          })

          -- Keymaps Obsidian Tasks & Daily Notes
          vim.keymap.set("n", "<leader>ch", ":Obsidian toggle_checkbox<CR>", { silent = true, desc = "Cocher/Décocher Tâche Obsidian" })
          vim.keymap.set("n", "<leader>nd", ":Obsidian today<CR>", { silent = true, desc = "Ouvrir la Daily Note d'aujourd'hui" })
        '';
      }
      {
        plugin = todo-comments-nvim;
        type = "lua";
        config = ''
          require("todo-comments").setup({
            keywords = {
              TODO = { icon = "☑ ", color = "info" },
            },
          })
          vim.keymap.set("n", "<leader>st", ":TodoTelescope<CR>", { silent = true, desc = "Rechercher toutes les tâches (TODO)" })
        '';
      }
      {
        plugin = zen-mode-nvim;
        type = "lua";
        config = ''
          require("zen-mode").setup({
            window = {
              backdrop = 0.95,
              width = 95,
              height = 1,
              options = {
                signcolumn = "no",
                number = false,
                relativenumber = false,
                cursorline = false,
              },
            },
            plugins = {
              gitsigns = { enabled = false },
              tmux = { enabled = true },
            },
          })
          vim.keymap.set("n", "<leader>z", ":ZenMode<CR>", { silent = true })
        '';
      }
    ];

    initLua = ''
      -- Options de base
      vim.g.mapleader = " "
      vim.opt.tabstop = 2
      vim.opt.softtabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.smartindent = true
      vim.opt.autoindent = true
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.cursorline = true
      vim.opt.conceallevel = 2
      vim.opt.clipboard = "unnamedplus"

      -- Navigation entre Fenêtres / Panneaux (Ctrl + h/j/k/l) & Tmux
      vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true })
      vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true })
      vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true })
      vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true })

      -- Navigation entre Onglets Neovim (gt / gT ou Tab / Shift-Tab)
      vim.keymap.set("n", "<Tab>", ":tabnext<CR>", { silent = true })
      vim.keymap.set("n", "<S-Tab>", ":tabprevious<CR>", { silent = true })

      -- Modern Neovim 0.11 Native LSP setup
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      for _, server in ipairs({ "nil_ls", "ts_ls", "lua_ls", "html", "cssls" }) do
        vim.lsp.config(server, { capabilities = capabilities })
        vim.lsp.enable(server)
      end

      -- Auto Dark Mode setup
      local status_adm, auto_dark_mode = pcall(require, "auto-dark-mode")
      if status_adm then
        auto_dark_mode.setup({
          update_interval = 1000,
          set_dark_mode = function()
            vim.api.nvim_set_option_value("background", "dark", {})
            vim.cmd("colorscheme catppuccin-mocha")
          end,
          set_light_mode = function()
            vim.api.nvim_set_option_value("background", "light", {})
            vim.cmd("colorscheme catppuccin-latte")
          end,
        })
      end
    '';
  };
}
