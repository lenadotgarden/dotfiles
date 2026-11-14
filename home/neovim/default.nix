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
      lilypond
      prettier
      stylua
      nixfmt-rfc-style
      (python3.withPackages (ps: [ ps.python-ly ])) # fournit `ly` (indentation LilyPond)
    ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
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

      # DankMaterialShell integration: renders a `dms` colorscheme (~/.config/nvim/colors/dms.lua)
      # via matugen once "neovim" is enabled under DMS Settings > Theme > Matugen Templates.
      # Needs: `dms ipc call settings set matugenTemplateNeovim true`, then a theme regen
      # (toggle light/dark once) to generate the file. No-ops gracefully on other hosts.
      (pkgs.vimUtils.buildVimPlugin {
        name = "base46";
        doCheck = false;
        src = pkgs.fetchFromGitHub {
          owner = "AvengeMedia";
          repo = "base46";
          rev = "83522e02c6c3b4ea901c4bffd9e0a5e0371c1fe6"; # v3.0
          hash = "sha256-kwDMC6rYzJYECmGnwn8JiAbffUq7hAXcUH6gPSkk2uI=";
        };
        config = ''
          require("base46").setup({})
        '';
      })

      # Treesitter
      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = ''
          local status_ts, ts_configs = pcall(require, 'nvim-treesitter.configs')
          if status_ts then
            ts_configs.setup({
              highlight = { enable = true },
              indent = { enable = true, disable = { "markdown" } },
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
              ['<C-y>'] = cmp.mapping.complete(),
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
      {
        plugin = conform-nvim;
        type = "lua";
        config = ''
          require("conform").setup({
            formatters = {
              ["ly-indent"] = {
                command = "ly",
                args = { "indent", "-i", "$FILENAME" },
                stdin = false,
              },
            },
            formatters_by_ft = {
              javascript = { "prettier" },
              javascriptreact = { "prettier" },
              typescript = { "prettier" },
              typescriptreact = { "prettier" },
              css = { "prettier" },
              html = { "prettier" },
              json = { "prettier" },
              jsonc = { "prettier" },
              yaml = { "prettier" },
              markdown = { "prettier" },
              lua = { "stylua" },
              nix = { "nixfmt" },
              lilypond = { "ly-indent" },
            },
            format_on_save = {
              timeout_ms = 2000,
              lsp_fallback = true,
            },
          })
          vim.keymap.set({ "n", "v" }, "<leader>cf", function()
            require("conform").format({ async = true, lsp_fallback = true })
          end, { desc = "Formater le buffer (conform)" })
        '';
      }
      {
        plugin = nvim-autopairs;
        type = "lua";
        config = ''
          require("nvim-autopairs").setup({ check_ts = true })
          local cmp_autopairs = require("nvim-autopairs.completion.cmp")
          require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
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

          -- Keymaps Obsidian Tasks & Daily Notes + Auto-bullet continuation (uniquement sur fichiers markdown)
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function()
              vim.keymap.set("n", "<leader>ch", ":Obsidian toggle_checkbox<CR>", { buffer = true, silent = true, desc = "Cocher/Décocher Tâche Obsidian" })
              -- Continuation des listes gérée par le mapping <CR> ci-dessous
              vim.opt_local.formatoptions:remove({ "r", "o" })
              vim.opt_local.indentexpr = ""
              vim.opt_local.smartindent = false

              local function list_prefix(line)
                -- puces : - * +  (avec checkbox optionnelle)
                local indent, marker, box, rest = line:match("^(%s*)([-*+])%s+(%[.%])%s+(.*)$")
                if indent then return indent, marker .. " [ ] ", rest end
                indent, marker, rest = line:match("^(%s*)([-*+])%s+(.*)$")
                if indent then return indent, marker .. " ", rest end
                -- listes numérotées (avec checkbox optionnelle)
                local num, delim
                indent, num, delim, box, rest = line:match("^(%s*)(%d+)([.)])%s+(%[.%])%s+(.*)$")
                if indent then return indent, (tonumber(num) + 1) .. delim .. " [ ] ", rest end
                indent, num, delim, rest = line:match("^(%s*)(%d+)([.)])%s+(.*)$")
                if indent then return indent, (tonumber(num) + 1) .. delim .. " ", rest end
                return nil
              end

              local function continue_list()
                local ok, cmp = pcall(require, "cmp")
                if ok and cmp.visible() then
                  cmp.confirm({ select = true })
                  return
                end
                local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                local line = vim.api.nvim_get_current_line()
                local indent, prefix, content = list_prefix(line)
                if not indent or col < #indent then
                  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
                  return
                end
                -- item vide : on termine la liste
                if content:match("^%s*$") then
                  vim.api.nvim_set_current_line("")
                  vim.api.nvim_win_set_cursor(0, { row, 0 })
                  return
                end
                local before, after = line:sub(1, col), line:sub(col + 1)
                local new_line = indent .. prefix .. after
                vim.api.nvim_buf_set_lines(0, row - 1, row, false, { before, new_line })
                vim.api.nvim_win_set_cursor(0, { row + 1, #indent + #prefix })
              end

              vim.keymap.set("i", "<CR>", continue_list, { buffer = true, silent = true, desc = "Continuer la liste" })
              vim.keymap.set("n", "o", function()
                if list_prefix(vim.api.nvim_get_current_line()) then
                  vim.api.nvim_feedkeys("A" .. vim.api.nvim_replace_termcodes("<CR>", true, false, true), "m", false)
                else
                  vim.api.nvim_feedkeys("o", "n", false)
                end
              end, { buffer = true, silent = true, desc = "Nouvelle ligne (continue la liste)" })
            end,
          })
          vim.keymap.set("n", "<leader>nd", ":Obsidian today<CR>", { silent = true, desc = "Ouvrir la Daily Note d'aujourd'hui" })

          -- Note rapide : ouvre/ferme la Daily Note dans une fenêtre flottante
          -- minimaliste centrée à l'écran (toggle avec <leader>dn).
          local quick_note_win = nil

          local function toggle_quick_note()
            if quick_note_win and vim.api.nvim_win_is_valid(quick_note_win) then
              vim.api.nvim_win_close(quick_note_win, false)
              quick_note_win = nil
              return
            end

            local width = math.floor(vim.o.columns * 0.6)
            local height = math.floor(vim.o.lines * 0.7)
            local row = math.floor((vim.o.lines - height) / 2)
            local col = math.floor((vim.o.columns - width) / 2)

            quick_note_win = vim.api.nvim_open_win(0, true, {
              relative = "editor",
              width = width,
              height = height,
              row = row,
              col = col,
              style = "minimal",
              border = "rounded",
              title = "  Note du jour ",
              title_pos = "center",
            })
            vim.wo[quick_note_win].winblend = 0
            vim.wo[quick_note_win].cursorline = true

            -- On charge le fichier directement (plutôt que ":Obsidian today",
            -- asynchrone et qui "drop" vers une fenêtre existante si la daily
            -- note est déjà ouverte ailleurs) pour être sûr qu'elle s'affiche
            -- bien dans notre fenêtre flottante.
            local note = require("obsidian.daily").today()
            if not note:exists() then
              note:write()
            end
            vim.cmd("edit " .. vim.fn.fnameescape(tostring(note.path)))
            vim.b.note = note

            vim.keymap.set("n", "q", toggle_quick_note, { buffer = true, silent = true, desc = "Fermer la note rapide" })
            vim.keymap.set("n", "<Esc>", toggle_quick_note, { buffer = true, silent = true, desc = "Fermer la note rapide" })

            vim.api.nvim_create_autocmd("WinClosed", {
              pattern = tostring(quick_note_win),
              once = true,
              callback = function() quick_note_win = nil end,
            })
          end

          vim.keymap.set("n", "<leader>dn", toggle_quick_note, { silent = true, desc = "Daily note flottante (toggle)" })
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
                -- Casse les lignes sur un espace plutôt qu'au milieu d'un mot.
                linebreak = true,
                breakindent = true,
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
      {
        plugin = stay-centered-nvim;
        type = "lua";
        config = ''
          -- Garde le curseur verticalement centré à l'écran en permanence
          -- (déplacements, scroll, et aussi en mode Zen puisque ça ne dépend
          -- pas de la mise en page de la fenêtre).
          require("stay-centered").setup({})
          vim.keymap.set("n", "<leader>cc", require("stay-centered").toggle, { silent = true, desc = "Activer/Désactiver le curseur centré" })
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
      (pkgs.vimUtils.buildVimPlugin {
        name = "overview";
        doCheck = false;
        src = pkgs.fetchFromGitHub {
          owner = "adigitoleo";
          repo = "overview.nvim";
          rev = "master";
          hash = "sha256-Qpqd+6/HJrLcduExFSp8CZtIxHGNNqQkztO1GNzaKak=";
        };
        config = ''
           vim.keymap.set("n", "gO", overview.toggle, { desc = "Toggle Overview sidebar for current buffer" })
           vim.keymap.set("n", "go", overview.focus, { desc = "Toggle focus between Overview sidebar and source buffer" })
        '';
      })

      # LilyPond : coloration syntaxique dédiée (accords, variables, etc., bien plus
      # riche que syntax/lilypond.vim de base) + lecteur MIDI/MP3 intégré (<F3>).
      # La compilation + aperçu automatiques à la sauvegarde restent gérées par notre
      # propre autocommande ci-dessous (ce plugin ne compile qu'à la demande, <F5>) ;
      # <F6> reste dispo comme raccourci de secours pour ouvrir le PDF via Skim.
      {
        plugin = nvim-lilypond-suite;
        type = "lua";
        config = ''
          require('nvls').setup({
            lilypond = {
              options = {
                pdf_viewer = "open -a Skim",
              },
            },
          })

          -- Bug du plugin : son ftplugin ajoute "-" et "\\" à iskeyword (pour ses
          -- propres motifs de mots), ce qui casse les motifs `\<` (limite de mot) du
          -- fichier syntax/lilypond.vim — dont celui qui colore les notes elles-mêmes
          -- (lilyPitch). Seuls les nombres, qui n'utilisent pas `\<`, s'en sortaient.
          -- On remet iskeyword à sa valeur par défaut, et on resynchronise la
          -- coloration depuis le début du buffer (nécessaire pour les régions
          -- imbriquées type `{ ... }` sur un fichier un peu long). Le `syntax sync`
          -- doit être différé (vim.schedule) : exécuté tout de suite dans le
          -- FileType, il est écrasé par le chargement de syntax/lilypond.vim qui
          -- n'a pas encore eu lieu à ce moment précis.
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "lilypond",
            callback = function()
              vim.bo.iskeyword = "@,48-57,_,192-255"
              vim.schedule(function()
                vim.cmd("syntax sync fromstart")
              end)
            end,
          })

          -- Le thème "dms" (DankMaterialShell) se recharge tout seul en live quand
          -- le fond d'écran/l'apparence change (voir plus bas dans ce fichier). Toute
          -- réapplication de colorscheme fait un `hi clear`, qui efface les couleurs
          -- lily* définies par nvls.setup() ci-dessus. On les redéfinit donc à chaque
          -- changement de colorscheme, pas seulement une fois au démarrage.
          vim.api.nvim_create_autocmd("ColorScheme", {
            callback = function()
              pcall(require("nvls").syntax)
            end,
          })

          -- Pas de vrai LSP LilyPond disponible : source nvim-cmp maison avec les
          -- commandes/mots-clés les plus courants, pour une autocomplétion légère
          -- sur les fichiers .ly sans avoir besoin d'un serveur LSP.
          local cmp_ok, cmp = pcall(require, "cmp")
          if cmp_ok then
            local lilypond_keywords = {
              "version", "include", "header", "paper", "layout", "midi", "score",
              "new", "context", "with", "set", "unset", "override", "revert", "tweak",
              "relative", "fixed", "transpose", "clef", "key", "time", "tempo", "partial",
              "repeat", "volta", "alternative", "times", "tuplet", "grace",
              "acciaccatura", "appoggiatura", "skip", "mark", "segno", "coda", "fermata",
              "bar", "break", "noBreak", "pageBreak",
              "voiceOne", "voiceTwo", "voiceThree", "voiceFour", "oneVoice",
              "stemUp", "stemDown", "stemNeutral",
              "slurUp", "slurDown", "slurNeutral",
              "tieUp", "tieDown", "tieNeutral",
              "dynamicUp", "dynamicDown", "dynamicNeutral",
              "change", "accidentalStyle", "autoBeamOn", "autoBeamOff",
              "global", "markup", "lyricmode", "lyricsto", "addlyrics",
              "chordmode", "drummode", "figuremode", "notemode",
              "bold", "italic", "sans", "fontsize", "hspace", "vspace",
              "center-column", "column", "concat", "with-color", "with-url",
              "instrumentName", "shortInstrumentName",
            }
            local source = {}
            function source:is_available()
              return vim.bo.filetype == "lilypond"
            end
            function source:get_debug_name()
              return "lilypond"
            end
            function source:complete(_, callback)
              local items = {}
              for _, word in ipairs(lilypond_keywords) do
                table.insert(items, { label = "\\" .. word, insertText = "\\" .. word })
              end
              callback(items)
            end
            cmp.register_source("lilypond", source)
            cmp.setup.filetype("lilypond", {
              sources = cmp.config.sources({
                { name = "lilypond" },
                { name = "luasnip" },
              }, {
                { name = "buffer" },
                { name = "path" },
              }),
            })
          end
        '';
      }
    ];

    initLua = ''
      -- Options de base
      vim.g.mapleader = " "
      vim.opt.termguicolors = true
      vim.opt.background = "dark"

      -- Curseur en bloc (carré) en mode Normal et ligne en mode Insertion
      vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"

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

      -- DankMaterialShell theme, hot-reloaded on wallpaper/light-dark changes by its own
      -- fs watcher. Falls back to catppuccin + GTK dark/light sync when colors/dms.lua
      -- hasn't been generated yet (other hosts, or before the matugen template is enabled).
      if not pcall(vim.cmd.colorscheme, "dms") then
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
      end

      -- Auto-sync Garden on save in Neovim
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = vim.fn.expand("~/Garden") .. "/*",
        callback = function()
          local script = vim.fn.expand("~/.local/bin/sync-garden.sh")
          if vim.fn.executable(script) == 1 then
            vim.fn.jobstart({ script }, { detach = true })
          end
        end,
      })

      -- LilyPond : compile automatiquement à la sauvegarde et rafraîchit l'aperçu PDF
      -- via Skim.app (`brew install --cask skim`) plutôt que Preview, dont `revert`
      -- AppleScript ne fonctionne pas (event non géré, -1708) et dont `open` réutilise
      -- la fenêtre de façon aléatoire. Skim recharge la page en place sans perdre le
      -- scroll/zoom, et son `revert` fonctionne réellement.
      local function lilypond_preview(pdf, bring_to_front)
        local script = {
          "on run argv",
          "  set pdfPath to item 1 of argv",
          "  tell application \"Skim\"",
          "    if (count of (documents whose path is pdfPath)) > 0 then",
          "      revert (document 1 whose path is pdfPath)",
          "    else",
          "      open POSIX file pdfPath",
          "    end if",
          bring_to_front and "    activate" or "",
          "  end tell",
          "end run",
        }
        local args = { "osascript" }
        for _, line in ipairs(script) do
          if line ~= "" then
            table.insert(args, "-e")
            table.insert(args, line)
          end
        end
        table.insert(args, pdf)
        vim.fn.jobstart(args)
      end

      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = { "*.ly", "*.ily" },
        callback = function()
          local file = vim.fn.expand("%:p")
          local basename = vim.fn.expand("%:p:r")
          vim.fn.jobstart({ "lilypond", "-o", basename, file }, {
            on_exit = function(_, code)
              if code == 0 then
                lilypond_preview(basename .. ".pdf", false)
              else
                vim.notify("LilyPond : erreur de compilation (:messages pour le détail)", vim.log.levels.ERROR)
              end
            end,
          })
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "lilypond",
        callback = function()
          vim.keymap.set("n", "<leader>lo", function()
            lilypond_preview(vim.fn.expand("%:p:r") .. ".pdf", true)
          end, { buffer = true, silent = true, desc = "Ouvrir/mettre au premier plan le PDF LilyPond" })
        end,
      })
    '';
  };
}
