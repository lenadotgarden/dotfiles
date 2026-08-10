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
              { name = 'orgmode' },
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
          vim.keymap.set("n", "<leader>5", function() ui.nav_file(5) end, { desc = "Sauter au fichier Harpoon 5" })
        '';
      }
      lazygit-nvim
      {
        plugin = render-markdown-nvim;
        type = "lua";
        config = ''
          require('render-markdown').setup()
        '';
      }

      {
        plugin = pkgs.vimUtils.buildVimPlugin {
          name = "org-bullets.nvim";
          src = pkgs.fetchFromGitHub {
            owner = "akinsho";
            repo = "org-bullets.nvim";
            rev = "main";
            sha256 = "0f7fch2sbzpgh1qz79b75amrk5jbhrsy2rx9bmbi5mjxyspsl1sf";
          };
          dontBuild = true;
          installPhase = ''
            mkdir -p $out
            cp -r * $out/
          '';
        };
        type = "lua";
        config = ''
          require('org-bullets').setup()
        '';
      }
      {
        plugin = org-roam-nvim;
        type = "lua";
        config = ''
          local garden_path = vim.fn.expand('~/Garden')
          local org_roam = require("org-roam")
          org_roam.setup({
            directory = garden_path,
          })

          -- Keymaps Org-Roam
          vim.keymap.set("n", "<leader>nf", function() org_roam.api.find_node() end, { desc = "Org-Roam Find Node" })
          vim.keymap.set("n", "<leader>ni", function() org_roam.api.insert_node() end, { desc = "Org-Roam Insert Node" })
          vim.keymap.set("n", "<leader>nc", function() org_roam.api.capture() end, { desc = "Org-Roam Capture" })
          vim.keymap.set("n", "<leader>nl", function() org_roam.api.toggle_roam_buffer() end, { desc = "Org-Roam Toggle Backlinks Buffer" })
          vim.keymap.set("n", "<leader>nm", function() org_roam.api.insert_node_immediate() end, { desc = "Org-Roam Insert Node Immediate" })
        '';
      }

      {
        plugin = orgmode;
        type = "lua";
        config = ''
          local garden_path = vim.fn.expand('~/Garden')
          require('orgmode').setup({
            org_agenda_files = {
              garden_path .. '/*.org',
              garden_path .. '/**/*.org',
            },
            org_default_notes_file = garden_path .. '/refile.org',
            org_todo_keywords = { 'IDEA(i)', 'TODO(t)', 'NEXT(n)', 'WAITING(w)', 'PROJ(p)', '|', 'DONE(d)', 'CANCELLED(c)' },
            org_todo_keyword_faces = {
              IDEA = ':foreground yellow :weight bold',
              NEXT = ':foreground blue :weight bold',
              WAITING = ':foreground orange :weight bold',
              PROJ = ':foreground purple :weight bold',
              CANCELLED = ':foreground gray',
            },
            mappings = {
              global = {
                org_agenda = false,
              },
              org = {
                org_toggle_checkbox = '<leader>x',
                org_todo = '<leader>ct',
              },
            },
          })

          vim.api.nvim_create_autocmd("FileType", {
            pattern = "org",
            callback = function()
              -- Mappings additionnels pour cocher/décocher les cases (- [ ])
              local toggle_cb = function() require('orgmode').action('org_toggle_checkbox') end
              vim.keymap.set({ "n", "v" }, "<leader>cx", toggle_cb, { buffer = true, desc = "Toggle Checkbox (- [ ])" })
              vim.keymap.set({ "n", "v" }, "<leader>ch", toggle_cb, { buffer = true, desc = "Toggle Checkbox (- [ ])" })

              -- Suivre un lien Orgmode avec Entrée (<CR>)
              vim.keymap.set("n", "<CR>", function()
                require('orgmode').action('org_open_at_point')
              end, { buffer = true, desc = "Ouvrir Lien Org" })
              
              -- Forcer le raccourci dans les buffers org pour écraser tout conflit
              vim.keymap.set("n", "<leader>oa", "<cmd>OrgSuperAgenda<CR>", { buffer = true, silent = true, desc = "Ouvrir Org Super Agenda" })
            end,
          })

          -- Keymaps Globaux Orgmode
          vim.keymap.set("n", "<leader>oa", "<cmd>OrgSuperAgenda<CR>", { silent = true, desc = "Ouvrir Org Super Agenda" })
          vim.keymap.set("n", "<leader>oA", function() require('orgmode').action('agenda.prompt') end, { silent = true, desc = "Ouvrir Org Agenda standard (Toutes les vues)" })
          vim.keymap.set("n", "<leader>os", function() require('orgmode').action('agenda.prompt') end, { silent = true, desc = "Ouvrir le menu Agenda standard" })
          vim.keymap.set("n", "<leader>oc", ":OrgCapture<CR>", { silent = true, desc = "Org Capture Note" })
        '';
      }
      {
        plugin = pkgs.vimUtils.buildVimPlugin {
          name = "org-super-agenda.nvim";
          src = pkgs.fetchFromGitHub {
            owner = "hamidi-dev";
            repo = "org-super-agenda.nvim";
            rev = "main";
            sha256 = "03mz520aybxxm4n9a2lipz55sacj7bawpn7lif5x25hqzb4g1vp0";
          };
          dontBuild = true;
          installPhase = ''
            mkdir -p $out
            cp -r * $out/
          '';
        };
        type = "lua";
        config = ''
          local garden_path = vim.fn.expand('~/Garden')
          require("org-super-agenda").setup({
            org_directories = { garden_path },
            todo_states = {
              { name='IDEA',     keymap='oi', color='#F1FA8C', strike_through=false, fields={'filename','todo','headline','priority','date','tags'} },
              { name='TODO',     keymap='ot', color='#FF5555', strike_through=false, fields={'filename','todo','headline','priority','date','tags'} },
              { name='NEXT',     keymap='on', color='#8BE9FD', strike_through=false, fields={'filename','todo','headline','priority','date','tags'} },
              { name='WAITING',  keymap='ow', color='#FFB86C', strike_through=false, fields={'filename','todo','headline','priority','date','tags'} },
              { name='PROJ',     keymap='op', color='#BD93F9', strike_through=false, fields={'filename','todo','headline','priority','date','tags'} },
              { name='DONE',     keymap='od', color='#50FA7B', strike_through=true,  fields={'filename','todo','headline','priority','date','tags'} },
              { name='CANCELLED',keymap='oc', color='#6272A4', strike_through=true,  fields={'filename','todo','headline','priority','date','tags'} },
            },
            keymaps = {
              filter_reset      = 'oa', toggle_other      = 'oo', filter            = 'of',
              filter_fuzzy      = 'oz', filter_query      = 'oq', undo              = 'u',
              reschedule        = 'cs', set_deadline      = 'cd', cycle_todo        = 't',
              set_state         = 's',  reload            = 'r',  refile            = 'R',
              hide_item         = 'x',  preview           = 'K',  clock_in          = 'I',
              clock_out         = 'O',  clock_cancel      = 'X',  clock_goto        = 'gI',
              reset_hidden      = 'gX', fold_all          = 'zM', unfold_all        = 'zR',
              toggle_duplicates = 'D',  cycle_view        = 'ov', bulk_mark         = 'm',
              bulk_unmark_all   = 'M',  bulk_reselect     = 'gv', bulk_action       = 'B',
              open_view         = 'V',
            },
            window = {
              width = 0.8, height = 0.7, border = 'rounded', title = 'Org Super Agenda',
              title_pos = 'center', margin_left = 0, margin_right = 0, fullscreen_border = 'none',
            },
            groups = {
              { name = '📥 Inbox',     matcher = function(i)
                  local f = (i.file or ""):lower()
                  return (f:match("refile") or f:match("inbox")) and i.todo_state ~= "DONE" and i.todo_state ~= "CANCELLED"
                end, sort={ by='date_nearest', order='asc' } },
              { name = '⭐ Today',      matcher = function(i) return ((i.scheduled and i.scheduled:is_today()) or (i.deadline and i.deadline:is_today())) end, sort={ by='scheduled_time', order='asc' } },
              { name = '🗓️ Upcoming',   matcher = function(i)
                  local days = 10
                  local d1 = i.deadline  and i.deadline:days_from_today()
                  local d2 = i.scheduled and i.scheduled:days_from_today()
                  return (d1 and d1 > 0 and d1 <= days) or (d2 and d2 > 0 and d2 <= days)
                end, sort={ by='date_nearest', order='asc' } },
              { name = '⏳ Overdue',    matcher = function(i) return i.todo_state ~= "DONE" and i.todo_state ~= "CANCELLED" and ((i.deadline and i.deadline:is_past()) or (i.scheduled and i.scheduled:is_past())) end, sort={ by='date_nearest', order='asc' } },
              { name = '⚡ Anytime',    matcher = function(i)
                  local f = (i.file or ""):lower()
                  local is_inbox = f:match("refile") or f:match("inbox")
                  local is_someday = i:has_tag("someday")
                  local is_future = i.scheduled and i.scheduled:days_from_today() > 0
                  local is_done = (i.todo_state == "DONE" or i.todo_state == "CANCELLED")
                  local has_todo = i.todo_state and i.todo_state ~= ""
                  return has_todo and not is_done and not is_inbox and not is_someday and not is_future
                end, sort={ by='date_nearest', order='asc' } },
              { name = '☁️ Someday',    matcher = function(i) return i:has_tag("someday") end },
            },
            hide_empty_groups  = true,
            allow_duplicates   = true,
            view_mode          = 'classic',
            custom_views       = {
              anytime = {
                name = '⚡ Anytime',
                filter = '-file:refile -file:inbox -tag:someday -is:done sched<=0 has:todo',
              },
            },
          })
        '';
      }
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

          -- Keymaps Obsidian Tasks & Daily Notes (uniquement sur fichiers markdown)
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function()
              vim.keymap.set("n", "<leader>ch", ":Obsidian toggle_checkbox<CR>", { buffer = true, silent = true, desc = "Cocher/Décocher Tâche Obsidian" })
            end,
          })
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
        plugin = neorg;
        type = "lua";
        config = ''
          require("neorg").setup({
            load = {
              ["core.defaults"] = {},
              ["core.dirman"] = {
                config = {
                  workspaces = {
                    garden = "~/Garden",
                  },
                  default_workspace = "garden",
                },
              },
              ["core.completion"] = {
                config = {
                  engine = "nvim-cmp",
                },
              },
              ["core.journal"] = {
                config = {
                  workspace = "garden",
                },
              },
              ["core.summary"] = {},
            },
          })

          -- Keymaps Neorg
          local map = vim.keymap.set
          map("n", "<leader>nn", ":Neorg workspace garden<CR>", { silent = true, desc = "Ouvrir le workspace Neorg (Garden)" })
          map("n", "<leader>nj", ":Neorg journal today<CR>", { silent = true, desc = "Ouvrir le Journal Neorg d'aujourd'hui" })
          map("n", "<leader>ni", ":Neorg index<CR>", { silent = true, desc = "Ouvrir l'index du workspace Neorg" })
          map("n", "<leader>nt", ":Neorg toc<CR>", { silent = true, desc = "Table des matières Neorg" })
          map("n", "<leader>nc", function()
            vim.opt.conceallevel = vim.opt.conceallevel:get() == 0 and 2 or 0
          end, { silent = true, desc = "Basculer le masquage des symboles (conceallevel)" })
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
      fzf-lua
      {
        plugin = dressing-nvim;
        type = "lua";
        config = ''
          require('dressing').setup()
        '';
      }
      {
        plugin = parrot-nvim;
        type = "lua";
        config = ''
          require("parrot").setup({
            providers = {
              openai = {
                name = "openai",
                endpoint = "https://api.deepseek.com/v1/chat/completions",
                api_key = os.getenv("DEEPSEEK_API_KEY") or "",
                models = { "deepseek-chat" },
                topic = {
                  model = "deepseek-chat",
                  params = { max_tokens = 64 },
                },
                params = {
                  chat = { model = "deepseek-chat", temperature = 0.2, top_p = 0.9 },
                  command = { model = "deepseek-chat", temperature = 0.2, top_p = 0.9 },
                },
              },
            },

            prompts = {
              Correction = [[
Tu es mon éditeur. Ton rôle est d'appliquer STRICTEMENT la modification ou correction demandée par l'utilisateur sur le texte fourni.

Demande de l'utilisateur : {{command}}

Règles à suivre :
- Applique uniquement la demande ci-dessus.
- Préserve impérativement le style "Trash" (cru, direct, gonzo), le ton, et les noms propres.
- Préserve strictement les balises Markdown ou Org Mode (liens, titres, listes, gras, etc.).

Ne rajoute aucune formule de politesse, ni aucune explication. Réponds uniquement avec le texte final modifié.
              ]],

              Fluidification = [[
Réécris la sélection en français naturel et fluide, dans un style de reportage.
Corrige les erreurs, mais ne modifie pas les faits, les citations ou le niveau de langue.
Préserve strictement la syntaxe Markdown ou Org Mode.

Instructions spécifiques pour cette réécriture : {{command}}

Réponds uniquement avec le texte final.
              ]],
            },

            enable_preview_mode = false,
            preview_auto_apply = false,
            toggle_target = "vsplit",
          })

          vim.keymap.set("v", "<leader>ac", function()
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
            vim.schedule(function()
              vim.ui.input({ prompt = "Instructions pour Correction (vide=auto): " }, function(input)
                if input == nil then return end
                local cmd = "PrtRewrite Correction"
                if input ~= "" then cmd = cmd .. " " .. input end
                vim.cmd("'<,'>" .. cmd)
              end)
            end)
          end, { desc = "Corriger la sélection avec l'IA" })

          vim.keymap.set("v", "<leader>af", function()
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
            vim.schedule(function()
              vim.ui.input({ prompt = "Instructions pour Fluidification (vide=auto): " }, function(input)
                if input == nil then return end
                local cmd = "PrtRewrite Fluidification"
                if input ~= "" then cmd = cmd .. " " .. input end
                vim.cmd("'<,'>" .. cmd)
              end)
            end)
          end, { desc = "Fluidifier la sélection avec l'IA" })
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
