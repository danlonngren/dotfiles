" ================================
" Basic settings
" ================================

" Clipboard integration
set clipboard=unnamedplus

" Visual enhancements
set cursorline
set number
set cc=80
set title

" Editing behavior
set hidden
set autoindent
set mouse=a
set inccommand=split

" Window behavior
set splitbelow
set splitright

" Performance
set ttyfast

" File type detection
filetype plugin indent on
syntax on

" Interface enhancements
set wildmenu
set completeopt=menuone,noselect,popup

" ================================
" Plugin management
" ================================

call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')

" Color scheme
Plug 'morhetz/gruvbox'

" Status line and interface
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'

" File management
Plug 'preservim/nerdtree'

" Code editing
Plug 'preservim/nerdcommenter'
Plug 'jiangmiao/auto-pairs'
Plug 'sheerun/vim-polyglot'

" LSP
Plug 'neovim/nvim-lspconfig'

" Completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'

" Git integration
Plug 'tpope/vim-fugitive'

call plug#end()

" ================================
" Color scheme
" ================================

set background=dark
colorscheme gruvbox

" ================================
" Airline
" ================================

let g:airline_solarized_bg='dark'
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled=1
let g:airline#extensions#tabline#left_sep=' '
let g:airline#extensions#tabline#left_alt_sep='|'
let g:airline#extensions#tabline#formatter='unique_tail'

" ================================
" NERDTree
" ================================

let NERDTreeQuitOnOpen=1
let NERDTreeShowHidden=1

" ================================
" Leader key
" ================================

let mapleader = ","

" ================================
" General mappings
" ================================

" File explorer
nnoremap <leader>n :NERDTreeToggle<CR>

" Save
nnoremap <leader>w :w<CR>

" Quit
nnoremap <leader>q :q<CR>

" Split navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Buffer navigation
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>

" ================================
" LSP
" ================================

lua << EOF

-- C++
vim.lsp.enable("clangd")

-- Python
vim.lsp.enable("basedpyright")

-- LSP keybindings
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local opts = { buffer = args.buf }

        vim.keymap.set("n", "K",
            vim.lsp.buf.hover, opts)

        vim.keymap.set("n", "gd",
            vim.lsp.buf.definition, opts)

        vim.keymap.set("n", "gD",
            vim.lsp.buf.declaration, opts)

        vim.keymap.set("n", "gr",
            vim.lsp.buf.references, opts)

        vim.keymap.set("n", "gi",
            vim.lsp.buf.implementation, opts)

        vim.keymap.set("n", "<leader>rn",
            vim.lsp.buf.rename, opts)

        vim.keymap.set("n", "<leader>ca",
            vim.lsp.buf.code_action, opts)

        vim.keymap.set("n", "<leader>e",
            vim.diagnostic.open_float, opts)

        vim.keymap.set("n", "[d",
            vim.diagnostic.goto_prev, opts)

        vim.keymap.set("n", "]d",
            vim.diagnostic.goto_next, opts)
    end
})

EOF

" ================================
" Completion
" ================================

lua << EOF

local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({

    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },

    mapping = cmp.mapping.preset.insert({

        -- Next / previous suggestion
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),

        -- Scroll documentation
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),

        -- Trigger completion
        ["<C-Space>"] = cmp.mapping.complete(),

        -- Accept completion
        ["<CR>"] = cmp.mapping.confirm({
            select = false
        }),

        -- Tab
        ["<Tab>"] = cmp.mapping(function(fallback)

            if cmp.visible() then
                cmp.select_next_item()

            elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()

            else
                fallback()
            end

        end, { "i", "s" }),

        -- Shift-Tab
        ["<S-Tab>"] = cmp.mapping(function(fallback)

            if cmp.visible() then
                cmp.select_prev_item()

            elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)

            else
                fallback()
            end

        end, { "i", "s" }),

        -- Escape
        ["<Esc>"] = cmp.mapping.abort(),
    }),

    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
    }),

})

EOF
