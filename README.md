use [nvim-automa](https://github.com/hrsh7th/nvim-automa) instead.

# nvim-automa-poc

This repository is a POC that provides macro-like functionality using the new `vim.on_key`.

## Usage

```lua
-- You can `dot-repeat` following key-sequences after setup.
-- `diwi*****<Esc>`
-- `i*****<Esc>` / `a*****<Esc>` / `o*****<Esc>` etc
-- `dd`
require('automa').setup {
  key = '.'
}
```

