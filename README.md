# sayit.nvim

Native macOS text-to-speech for Neovim. Speak a word, selection, motion, line,
paragraph, range, or entire buffer with the built-in `say` command. Triggering a
toggle action while speech is active stops it.

## Requirements

- macOS
- Neovim 0.9 or newer

Run `:checkhealth sayit` to verify the installation.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "nicholasmata/sayit.nvim",
  version = "*", -- use the latest stable release
  opts = {},
}
```

## Configuration

These are all available options and their defaults:

```lua
require("sayit").setup({
  voice = nil,          -- macOS voice name, for example "Samantha"
  rate = nil,           -- positive words-per-minute number
  exit_visual = true,   -- leave Visual mode after capturing the selection
  notify = false,       -- show informational start/stop notifications
  mappings = {
    normal = "<leader>v",
    visual = "<leader>v",
    stop = false,       -- for example "<leader>V"
    operator = false,   -- for example "gs"
  },
})
```

Use `:SayVoices` to inspect installed voices, or run `say -v '?'` in a terminal.

## Commands

| Command | Action |
| --- | --- |
| `:SayWord` | Toggle the word under the cursor |
| `:SayLine` | Toggle the current line |
| `:SayParagraph` | Toggle the surrounding paragraph |
| `:SayBuffer` | Toggle the entire buffer |
| `:[range]SaySelection` | Toggle the supplied line range or current visual selection |
| `:SayStart {text}` | Speak text, replacing current speech |
| `:SayToggle [text]` | Toggle text, or the word under the cursor when omitted |
| `:SayStop` | Stop active speech |
| `:SayVoices` | Open a scratch buffer containing installed voices |

## Mappings and motions

The configured normal and visual mappings toggle the word or selection. The
following `<Plug>` mappings are always available:

```lua
vim.keymap.set("n", "<leader>sw", "<Plug>(SayItWord)")
vim.keymap.set("x", "<leader>s", "<Plug>(SayItSelection)")
vim.keymap.set("n", "<leader>ss", "<Plug>(SayItStop)")
vim.keymap.set("n", "gs", "<Plug>(SayItOperator)")
```

The operator mapping accepts any motion. With the `gs` example, `gsiw` speaks
the inner word, `gsip` speaks a paragraph, and `gsG` speaks to the end of the
buffer.

Set a configured mapping to `false` to disable it. Calling `setup()` again is
supported and removes the plugin's previous configurable mappings.

## Lua API

```lua
local sayit = require("sayit")

sayit.say("Hello from Neovim") -- always starts/replaces speech
sayit.toggle("Hello")          -- stops if active; otherwise speaks
sayit.stop()
sayit.is_speaking()

sayit.say_word()
sayit.say_line()
sayit.say_paragraph()
sayit.say_buffer()
sayit.say_visual(false)
```

Text is passed as an argument vector, not through a shell. The `osascript`
fallback also receives text through its argument list, so quotes and newlines do
not become executable AppleScript.

## Development

Run the headless test suite with:

```sh
NVIM_LOG_FILE=/tmp/sayit-nvim.log nvim --clean --headless -u tests/minimal_init.lua -l tests/sayit_spec.lua
```

Formatting and lint checks use StyLua and Selene:

```sh
stylua --check lua tests
selene lua tests
```

## License

MIT
