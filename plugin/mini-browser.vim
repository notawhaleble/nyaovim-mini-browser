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

augroup nyaovim_mini_browser
    autocmd!
    autocmd BufEnter * call <SID>apply_buffer_settings()
augroup END

let g:loaded_nyaovim_mini_browser = 1
