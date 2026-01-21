if get(g:, 'loaded_nyaovim_mini_browser', 0) || !exists('g:nyaovim_version')
    finish
endif

function! s:current_overlay_id() abort
    return bufnr('%')
endfunction

function! s:normalize_overlay_id(id) abort
    if a:id is# v:null || type(a:id) == type(0) && a:id == 0
        return s:current_overlay_id()
    endif
    if type(a:id) == type('')
        if a:id ==# ''
            return s:current_overlay_id()
        endif
        if a:id =~# '^\d\+$'
            return str2nr(a:id)
        endif
        return a:id
    endif
    return a:id
endfunction

function! s:rpc_notify(method, ...) abort
    call call('rpcnotify', extend([0, a:method], a:000))
endfunction

let s:cmdline_marker = '-- BROWSER --'

function! s:precise_log(msg) abort
    if !get(g:, 'nyaovim_mini_browser_precise_debug', 0)
        return
    endif
    let logfile = get(g:, 'nyaovim_mini_browser_precise_debug_file', '/tmp/nyaovim-mini-browser-precise.log')
    let line = strftime('%Y-%m-%d %H:%M:%S') . ' [mini-browser:precise] ' . a:msg
    try
        call writefile([line], logfile, 'a')
    catch
        " Fallback to messages if write fails.
        echomsg line
    endtry
endfunction

function! s:precise_enabled(bufnr) abort
    return getbufvar(a:bufnr, 'minibrowser_precise', 0) == 1
endfunction

function! s:precise_overlay_id(bufnr) abort
    let overlay_id = getbufvar(a:bufnr, 'minibrowser_overlay_id', v:null)
    if overlay_id is# v:null
        return v:null
    endif
    return overlay_id
endfunction

function! s:precise_offsets(bufnr) abort
    let offsets = getbufvar(a:bufnr, 'minibrowser_precise_offsets', v:null)
    if type(offsets) == type([])
        return offsets
    endif
    let lines = getbufline(a:bufnr, 1, '$')
    let offsets = []
    let total = 0
    for line in lines
        call add(offsets, total)
        let total += strlen(line) + 1
    endfor
    call setbufvar(a:bufnr, 'minibrowser_precise_offsets', offsets)
    return offsets
endfunction

function! s:precise_index_for_pos(bufnr, lnum, col) abort
    let offsets = s:precise_offsets(a:bufnr)
    if a:lnum <= 0 || a:lnum > len(offsets)
        return 0
    endif
    let base = offsets[a:lnum - 1]
    let column = max([a:col, 1]) - 1
    return base + column
endfunction

function! s:precise_visual_range(bufnr) abort
    let mode = mode()
    if mode !=# 'v' && mode !=# 'V' && mode !=# "\<C-v>"
        return v:null
    endif
    let start = getpos("'<")
    let endpos = getpos("'>")
    if start[0] != a:bufnr || endpos[0] != a:bufnr
        return v:null
    endif
    let start_lnum = start[1]
    let start_col = start[2]
    let end_lnum = endpos[1]
    let end_col = endpos[2]
    if mode ==# 'V'
        let start_col = 1
        let end_line = getline(end_lnum)
        let end_col = strlen(end_line) + 1
    endif
    if start_lnum > end_lnum || (start_lnum == end_lnum && start_col > end_col)
        let tmp_lnum = start_lnum
        let tmp_col = start_col
        let start_lnum = end_lnum
        let start_col = end_col
        let end_lnum = tmp_lnum
        let end_col = tmp_col
    endif
    let start_idx = s:precise_index_for_pos(a:bufnr, start_lnum, start_col)
    let end_idx = s:precise_index_for_pos(a:bufnr, end_lnum, end_col) + 1
    return [start_idx, end_idx]
endfunction

function! s:precise_send_update(bufnr) abort
    if !s:precise_enabled(a:bufnr)
        return
    endif
    if bufnr('%') != a:bufnr
        return
    endif
    if getbufvar(a:bufnr, 'minibrowser_precise_rebuilding', 0)
        call s:precise_log('skip update: rebuilding')
        return
    endif
    let overlay_id = s:precise_overlay_id(a:bufnr)
    if overlay_id is# v:null
        call s:precise_log('skip update: no overlay id')
        return
    endif
    let lnum = line('.')
    let colnum = col('.')
    let idx = s:precise_index_for_pos(a:bufnr, lnum, colnum)
    let options = {'preciseCursor': {'index': idx}}
    let range = s:precise_visual_range(a:bufnr)
    if type(range) == type([])
        let options.preciseSelection = {'start': range[0], 'end': range[1]}
        call setbufvar(a:bufnr, 'minibrowser_precise_had_selection', 1)
    elseif getbufvar(a:bufnr, 'minibrowser_precise_had_selection', 0)
        let options.preciseClearSelection = v:true
        call setbufvar(a:bufnr, 'minibrowser_precise_had_selection', 0)
    endif
    call s:precise_log('send update idx=' . idx)
    call s:rpc_notify('overlay:update', {'id': overlay_id, 'options': options})
endfunction

function! s:precise_scroll(delta) abort
    let buffer = bufnr('%')
    if !s:precise_enabled(buffer)
        return
    endif
    let overlay_id = s:precise_overlay_id(buffer)
    if overlay_id is# v:null
        return
    endif
    call s:precise_log('scroll lines=' . a:delta)
    let options = {'preciseScroll': {'lines': a:delta}}
    call s:rpc_notify('overlay:update', {'id': overlay_id, 'options': options})
    let count = abs(a:delta)
    if count > 0
        if a:delta > 0
            execute 'normal! ' . count . "\<C-e>"
        else
            execute 'normal! ' . count . "\<C-y>"
        endif
    endif
endfunction

function! s:precise_apply_maps(bufnr) abort
    if getbufvar(a:bufnr, 'minibrowser_precise_map_set', 0)
        return
    endif
    execute 'nnoremap <silent><buffer> <C-e> :<C-u>call <SID>precise_scroll(1)<CR>'
    execute 'nnoremap <silent><buffer> <C-y> :<C-u>call <SID>precise_scroll(-1)<CR>'
    execute 'xnoremap <silent><buffer> <C-e> :<C-u>call <SID>precise_scroll(1)<CR>'
    execute 'xnoremap <silent><buffer> <C-y> :<C-u>call <SID>precise_scroll(-1)<CR>'
    call setbufvar(a:bufnr, 'minibrowser_precise_map_set', 1)
endfunction

function! s:precise_clear_maps(bufnr) abort
    if !getbufvar(a:bufnr, 'minibrowser_precise_map_set', 0)
        return
    endif
    silent! nunmap <buffer> <C-e>
    silent! nunmap <buffer> <C-y>
    silent! xunmap <buffer> <C-e>
    silent! xunmap <buffer> <C-y>
    call setbufvar(a:bufnr, 'minibrowser_precise_map_set', 0)
endfunction

function! MiniBrowserPreciseRefresh(...) abort
    let buffer = a:0 >= 1 ? a:1 : bufnr('%')
    if !bufexists(buffer)
        return
    endif
    call s:precise_log('refresh buffer=' . buffer)
    call setbufvar(buffer, 'minibrowser_precise_offsets', v:null)
    call setbufvar(buffer, 'minibrowser_precise_rebuilding', 0)
    call s:precise_send_update(buffer)
endfunction

function! MiniBrowserPreciseApply(buffer, lines_json) abort
    if type(a:buffer) != type(0) || !bufexists(a:buffer)
        return
    endif
    call s:precise_log('apply buffer=' . a:buffer)
    let lines = []
    if type(a:lines_json) == type('')
        try
            let lines = json_decode(a:lines_json)
        catch
            let lines = []
        endtry
    elseif type(a:lines_json) == type([])
        let lines = a:lines_json
    endif
    if type(lines) != type([])
        let lines = []
    endif
    call s:precise_log('apply lines=' . len(lines))
    call setbufvar(a:buffer, '&modifiable', 1)
    call setbufline(a:buffer, 1, lines)
    let last = len(lines) + 1
    if line('$', a:buffer) >= last
        call deletebufline(a:buffer, last, '$')
    endif
    call setbufvar(a:buffer, '&modified', 0)
    call setbufvar(a:buffer, '&modifiable', 0)
    call setbufvar(a:buffer, 'minibrowser_precise_offsets', v:null)
    call setbufvar(a:buffer, 'minibrowser_precise_rebuilding', 0)
    call MiniBrowserPreciseRefresh(a:buffer)
endfunction

function! MiniBrowserPreciseApplyFile(buffer, filepath) abort
    if type(a:buffer) != type(0) || !bufexists(a:buffer)
        return
    endif
    if type(a:filepath) != type('')
        return
    endif
    call s:precise_log('apply file buffer=' . a:buffer)
    let content = ''
    try
        let content = join(readfile(a:filepath), "\n")
        call delete(a:filepath)
    catch
        call s:precise_log('apply file read failed')
        return
    endtry
    if content ==# ''
        call s:precise_log('apply file empty')
    endif
    call MiniBrowserPreciseApply(a:buffer, content)
endfunction

function! MiniBrowserPreciseCommand(target, ...) abort
    let buffer = bufnr('%')
    let overlay_id = s:precise_overlay_id(buffer)
    if overlay_id is# v:null
        echoerr 'MiniBrowserPrecise: no overlay bound to current buffer'
        return
    endif
    let cmd = a:target ==# '' ? 'toggle' : a:target
    if cmd ==# 'toggle'
        let enable = !s:precise_enabled(buffer)
    elseif cmd ==# 'on'
        let enable = 1
    elseif cmd ==# 'off'
        let enable = 0
    else
        echoerr 'MiniBrowserPrecise: invalid target'
        return
    endif
    if enable
        call s:precise_log('enable precise mode buffer=' . buffer)
        call setbufvar(buffer, 'minibrowser_precise', 1)
        call setbufvar(buffer, 'minibrowser_precise_offsets', v:null)
        call setbufvar(buffer, 'minibrowser_precise_rebuilding', 1)
        call s:precise_apply_maps(buffer)
        call s:rpc_notify('overlay:update', {'id': overlay_id, 'options': {'preciseMode': v:true, 'preciseRebuild': v:true}})
    else
        call s:precise_log('disable precise mode buffer=' . buffer)
        call setbufvar(buffer, 'minibrowser_precise', 0)
        call s:precise_clear_maps(buffer)
        call s:rpc_notify('overlay:update', {'id': overlay_id, 'options': {'preciseMode': v:false, 'preciseClearSelection': v:true}})
    endif
endfunction

function! s:apply_buffer_settings() abort
    let buffer = bufnr('%')
    let overlay_id = getbufvar(buffer, 'minibrowser_overlay_id', v:null)
    if overlay_id is# v:null
        if getbufvar(buffer, 'minibrowser_i_map_set', 0)
            silent! nunmap <buffer> i
            call setbufvar(buffer, 'minibrowser_i_map_set', 0)
        endif
        return
    endif
    if !exists('g:nyaovim_mini_browser_instances') || !has_key(g:nyaovim_mini_browser_instances, overlay_id)
        return
    endif
    let entry = g:nyaovim_mini_browser_instances[overlay_id]
    if !get(entry, 'settings_applied', 0)
        let entry.prev_modifiable = getbufvar(buffer, '&modifiable')
        let entry.prev_readonly = getbufvar(buffer, '&readonly')
        call setbufvar(buffer, '&modifiable', 0)
        call setbufvar(buffer, '&readonly', 1)
        let entry.settings_applied = 1
        let g:nyaovim_mini_browser_instances[overlay_id] = entry
    endif
    if empty(maparg('i', 'n', 0, 1))
        nnoremap <silent><buffer> i :MiniBrowserFocusBrowser<CR>
        call setbufvar(buffer, 'minibrowser_i_map_set', 1)
    endif
    if s:precise_enabled(buffer)
        call s:precise_apply_maps(buffer)
    endif
endfunction

function! s:show_browser_marker() abort
    let g:nyaovim_mini_browser_cmdline_active = 1
    echohl ModeMsg
    echon s:cmdline_marker
    echohl None
endfunction

function! s:clear_browser_marker() abort
    if get(g:, 'nyaovim_mini_browser_cmdline_active', 0)
        let g:nyaovim_mini_browser_cmdline_active = 0
        echo ''
    endif
endfunction

function! MiniBrowserOpen(bang, ...) abort
    let buffer = bufnr('%')
    let target = win_getid()
    let has_url = a:0 >= 1 && a:1 !=# ''
    let overlay_id = buffer
    if a:0 >= 2
        let overlay_id = s:normalize_overlay_id(a:2)
        if type(overlay_id) == type(0) && bufexists(overlay_id)
            let buffer = overlay_id
            if buffer != bufnr('%')
                let target = 0
            endif
        endif
    endif
    let focus = !a:bang && get(g:, 'nyaovim_mini_browser_focus_on_open', v:false)
    let options = {
                \ 'focus': focus,
                \ 'visible': 1,
                \ 'targetWin': target,
                \ 'overlayId': overlay_id,
                \ 'buffer': buffer,
                \ 'trigger': 'command-open',
                \ 'matchActiveWindow': v:false,
                \ 'overlayMode': v:true,
                \ }
    if has_url
        let options['url'] = a:1
    endif
    if a:0 >= 3
        let options['height'] = a:3
    endif
    call s:rpc_notify('overlay:open', {
                \ 'id': overlay_id,
                \ 'plugin': 'mini-browser',
                \ 'options': options,
                \ })

    let legacy_args = [0, 'mini-browser:open']
    if has_url
        call add(legacy_args, a:1)
    endif
    if !focus
        call add(legacy_args, 0)
    elseif a:bang
        call add(legacy_args, 0)
    endif
    call call('rpcnotify', legacy_args)

    if !exists('g:nyaovim_mini_browser_instances')
        let g:nyaovim_mini_browser_instances = {}
    endif
    let prev = get(g:nyaovim_mini_browser_instances, overlay_id, {})
    let entry = {
                \ 'buffer': buffer,
                \ 'winid': target,
                \ 'url': has_url ? a:1 : get(prev, 'url', ''),
                \ 'prev_statusline': get(prev, 'prev_statusline', getbufvar(buffer, '&statusline')),
                \ 'focus': focus ? 'browser' : 'editor',
                \ }
    if has_url
        let entry.url = a:1
    endif
    let g:nyaovim_mini_browser_instances[overlay_id] = entry

    call setbufvar(buffer, 'minibrowser_overlay_id', overlay_id)
    execute 'autocmd! nyaovim_mini_browser BufWipeout <buffer=' . buffer . '>'
    execute 'autocmd nyaovim_mini_browser BufWipeout <buffer=' . buffer . '> call MiniBrowserClose(' . overlay_id . ')'

    call MiniBrowserNotifyFocus(buffer, focus ? 'browser' : 'editor')
    call s:apply_buffer_settings()
endfunction

function! MiniBrowserClose(...) abort
    let overlay_id = a:0 >= 1 ? s:normalize_overlay_id(a:1) : (exists('b:minibrowser_overlay_id') ? b:minibrowser_overlay_id : s:current_overlay_id())
    call s:rpc_notify('overlay:close', {'id': overlay_id, 'trigger': 'command-close', 'destroy': v:true})
    call rpcnotify(0, 'mini-browser:close')
    if exists('g:nyaovim_mini_browser_instances') && has_key(g:nyaovim_mini_browser_instances, overlay_id)
        let info = g:nyaovim_mini_browser_instances[overlay_id]
        if has_key(info, 'prev_statusline')
            call setbufvar(info.buffer, '&statusline', info.prev_statusline)
        endif
        if has_key(info, 'prev_modifiable')
            call setbufvar(info.buffer, '&modifiable', info.prev_modifiable)
        endif
        if has_key(info, 'prev_readonly')
            call setbufvar(info.buffer, '&readonly', info.prev_readonly)
        endif
        if bufexists(info.buffer) && getbufvar(info.buffer, 'minibrowser_i_map_set', 0)
            if bufnr('%') == info.buffer
                silent! nunmap <buffer> i
            endif
            call setbufvar(info.buffer, 'minibrowser_i_map_set', 0)
        endif
        if bufexists(info.buffer) && getbufvar(info.buffer, 'minibrowser_precise', 0)
            call s:precise_clear_maps(info.buffer)
            call setbufvar(info.buffer, 'minibrowser_precise', 0)
            call setbufvar(info.buffer, 'minibrowser_precise_offsets', v:null)
        endif
        if bufexists(info.buffer)
            call setbufvar(info.buffer, 'minibrowser_overlay_id', v:null)
        endif
        call remove(g:nyaovim_mini_browser_instances, overlay_id)
    endif
    silent! redrawstatus
endfunction

function! MiniBrowserList() abort
    if !exists('g:nyaovim_mini_browser_instances') || empty(g:nyaovim_mini_browser_instances)
        echo 'No mini-browser instances'
        return
    endif
    let lines = [' ID    FOCUS   URL']
    for [bufnr, info] in sort(items(g:nyaovim_mini_browser_instances))
        let mark = getbufvar(bufnr, '&modified') ? ' [+]' : ''
        let url = get(info, 'url', '')
        let focus = toupper(get(info, 'focus', 'editor'))
        call add(lines, printf('%-6d %-7s %s%s', bufnr, focus, url, mark))
    endfor
    echo join(lines, "\n")
endfunction

function! MiniBrowserFocusCommand(target, ...) abort
    let overlay_id = a:0 >= 1 ? s:normalize_overlay_id(a:1) : s:current_overlay_id()
    let focus_target = a:target
    if type(focus_target) != type('') || focus_target ==# ''
        let focus_target = 'toggle'
    endif
    call s:rpc_notify('overlay:focus', overlay_id, focus_target, 'command-focus')
    call rpcnotify(0, 'mini-browser:focus', focus_target)
endfunction

function! MiniBrowserNotifyFocus(bufnr, state) abort
    if !exists('g:nyaovim_mini_browser_instances')
        let g:nyaovim_mini_browser_instances = {}
    endif
    if !bufexists(a:bufnr)
        return
    endif
    let focus = a:state ==# 'browser' ? 'browser' : 'editor'
    if !has_key(g:nyaovim_mini_browser_instances, a:bufnr)
        return
    endif
    let g:nyaovim_mini_browser_instances[a:bufnr].focus = focus
    if focus ==# 'browser' && bufnr('%') == a:bufnr
        call s:show_browser_marker()
    else
        call s:clear_browser_marker()
    endif
endfunction

command! -nargs=* -bang MiniBrowser call MiniBrowserOpen(<bang>0, <f-args>)
command! -nargs=? MiniBrowserClose call MiniBrowserClose(<f-args>)
command! -nargs=? MiniBrowserFocus call MiniBrowserFocusCommand('toggle', <f-args>)
command! -nargs=? MiniBrowserFocusEditor call MiniBrowserFocusCommand('editor', <f-args>)
command! -nargs=? MiniBrowserFocusBrowser call MiniBrowserFocusCommand('browser', <f-args>)
command! -nargs=? MiniBrowserToggleFocus call MiniBrowserFocusCommand('toggle', <f-args>)
command! MiniBrowserList call MiniBrowserList()
command! -nargs=+ MiniBrowserFocusState call MiniBrowserNotifyFocus(<f-args>)
command! -nargs=? MiniBrowserPrecise call MiniBrowserPreciseCommand(<q-args>)
command! -nargs=? MiniBrowserPreciseOn call MiniBrowserPreciseCommand('on')
command! -nargs=? MiniBrowserPreciseOff call MiniBrowserPreciseCommand('off')

augroup nyaovim_mini_browser
    autocmd!
    autocmd BufEnter * call <SID>apply_buffer_settings()
augroup END

augroup nyaovim_mini_browser_precise
    autocmd!
    autocmd CursorMoved,CursorMovedI * call <SID>precise_send_update(bufnr('%'))
    autocmd ModeChanged * call <SID>precise_send_update(bufnr('%'))
augroup END

let g:loaded_nyaovim_mini_browser = 1
