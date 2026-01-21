Inner Mini Browser for [NyaoVim](https://github.com/rhysd/NyaoVim)
==================================================================

This is [NyaoVim](https://github.com/rhysd/NyaoVim) UI plugin to open an embedded browser in window.  This is implemented as Web Component and built on [Electron's webview](https://github.com/atom/electron/blob/master/docs/api/web-view-tag.md).

![screenshot](https://raw.githubusercontent.com/rhysd/ss/master/nyaovim-mini-browser/main.gif)

## Installation

Install this repository as Vim plugin with your favorite plugin manager.  Add the overlay layer to your `nyaovimrc.html` as below.

```html
<style>
  /* CSS configurations here */
  .horizontal {
    position: relative;
    display: block;
    width: 100%;
    height: 100%;
  }
  neovim-editor {
    width: 100%;
    height: 100%;
  }
  overlay-manager {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
  }
</style>

<!-- Overlay manager keeps UI plugins on top of the editor -->
<div class="horizontal">
  <neovim-editor id="nyaovim-editor" argv$="[[argv]]"></neovim-editor>
  <overlay-manager editor="[[editor]]"></overlay-manager>
</div>
```

This is a setting example.  You can position `<overlay-manager>` anywhere that sits on top of your editor surface.

### Overlay manager

`overlay-manager` keeps one or more UI plugins (including the mini browser) on a dedicated overlay layer. Every `:MiniBrowser` call now emits `overlay:*` notifications so multiple browser panes can coexist, each bound to the buffer that spawned them—even if the buffer is moved to another window or tab. Legacy `mini-browser:*` notifications are still emitted for backward compatibility.

A convenient way to jump between the overlay and Neovim is to map the focus command, for example:

```vim
nnoremap <Leader>mb :MiniBrowserToggleFocus<CR>
```

Map the focus toggle yourself so it never collides with Neovim defaults, e.g.:

```vim
nnoremap <silent> <C-]> :MiniBrowserToggleFocus<CR>
```

While the overlay has focus, pressing the same key (default `Ctrl+]`) will take you back to the editor.

## Commands

- `:MiniBrowser [url] [id]`: Open (or reuse) a mini browser overlay for the current buffer. If `url` is omitted, the previous page is shown; omit `id` to bind to the current buffer automatically, or supply your own name to manage overlays manually. Add `!` to avoid focusing the browser after opening.
- `:MiniBrowserClose [id]`: Hide the mini browser attached to the current window (or the optional `id`).
- `:MiniBrowserFocus[Browser|Editor|Toggle] [id]`: Focus the mini browser overlay, the editor, or toggle between them using either the current buffer or an explicit `id`.
- `:MiniBrowserPrecise[On|Off|Toggle]`: Enable character-precise navigation/selection sync (caret + selection overlay) for the current buffer.

## Keymaps In Browser

These keymaps are active only when the browser view has focus.

| keymap | description |
| ------ | ----------- |
| `j` | Scroll half page down |
| `k` | Scroll half page up |
| `h` | Scroll half page left |
| `l` | Scroll half page right |
| `Ctrl+]` | Toggle focus back to Vim |
| `Ctrl+\\` then `Ctrl+n` | Focus Vim (insert-safe) |
| `Ctrl+r` | Reload page (`Ctrl+Shift+r` ignores cache) |
| `Ctrl+o` | Back in history |
| `Ctrl+i` | Forward in history |
| `Ctrl+w` | Send `<C-w>` to Vim and focus editor |
| `Ctrl+l` | Echo current URL in `:messages` |
| `Ctrl++` / `Ctrl+=` | Zoom in |
| `Ctrl+-` | Zoom out |
| `Ctrl+Shift+i` | Open DevTools window |

## Precise Navigation Mode

Precise mode keeps Vim as the control surface while the webview renders the page. It builds a text model from the rendered DOM, shows a caret overlay on the page, and mirrors Visual selections.

- Enabled automatically on `:MiniBrowser` by default (toggle with `:MiniBrowserPreciseOff`).
- Scroll is synced: `Ctrl-E`/`Ctrl-Y` scroll the page and the Vim window together.
- Auto-rebuilds on load, resize, and zoom to keep mappings accurate.

### Usage (Vim focused)

- Move with normal Vim motions (`h/j/k/l`, `w`, `b`, `f`, etc.) and watch the caret on the page.
- Select text with Visual mode (`v`) or linewise Visual (`V`); the page shows the same highlight.
- Scroll with `Ctrl-E` / `Ctrl-Y`; the page scrolls without losing caret alignment.

### Configuration

Disable auto-enable:

```vim
let g:nyaovim_mini_browser_precise_auto = 0
```

## Extend Your Usage

This plugin only provides very simple commands.  You can write script to extend your usage with the commands as below.

- Open GitHub issues of current repository
- Look for a word under the cursor in online documentations
- Search something on Google Search
- Play music on SoundCloud ;)
- etc...

### Example1: Open URL under cursor

If you want to open a URL under cursor, adding below mapping to `init.vim` will help you.  Mapping to `<Leader>o` is an example.  You can map it to your favorite key sequence.

```vim
nnoremap <Leader>o :<C-u>MiniBrowser <C-r><C-p><CR>
```

### Example2: [devdocs.io](http://devdocs.io/)

Below is an example configuration to search [devdocs.io](http://devdocs.io) instantly.  `:Devdocs` command is defined.  When parameter is given, it opens devdocs.io with the parameter as query.  If no parameter is given, it opens devdocs.io with the word under cursor.

```vim
function! s:devdocs(query) abort
    if a:query ==# ''
        let cword = expand('<cword>')
        if cword ==# ''
            MiniBrowser http://devdocs.io/
        else
            execute 'MiniBrowser' 'http://devdocs.io/#q='.escape(cword, ' \')
        endif
        return
    endif

    execute 'MiniBrowser' 'http://devdocs.io/#q='.escape(a:query, ' \')
endfunction
command! -nargs=* DevDocs call <SID>devdocs(<q-args>)
```

## Properties of `<mini-browser>`

You can specify `url`, `width`, `useragent`, and `visible` to the tag.

```html
<mini-browser
  url="https://google.com"
  width="600"
  useragent="...(snip)"
  visible
></mini-browser>
```

## License

```
Copyright (c) 2015 rhysd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
