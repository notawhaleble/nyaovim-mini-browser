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

function! MiniBrowserOpen(bang, ...) abort
    let buffer = bufnr('%')
    let target = win_getid()
    let has_url = a:0 >= 1 && a:1 !=# ''
    let overlay_id = buffer
    if a:0 >= 2
        let overlay_id = s:normalize_overlay_id(a:2)
    endif
    let focus = !a:bang
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
    if a:bang
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
                \ 'focus': focus ? 'browser' : get(prev, 'focus', 'editor'),
                \ }
    if has_url
        let entry.url = a:1
    endif
    let g:nyaovim_mini_browser_instances[overlay_id] = entry

    let b:minibrowser_overlay_id = overlay_id
    execute 'autocmd! nyaovim_mini_browser BufWipeout <buffer=' . buffer . '>'
    execute 'autocmd nyaovim_mini_browser BufWipeout <buffer=' . buffer . '> call MiniBrowserClose(' . overlay_id . ')'

    call MiniBrowserNotifyFocus(buffer, focus ? 'browser' : 'editor')
endfunction

function! MiniBrowserClose(...) abort
    let overlay_id = a:0 >= 1 ? s:normalize_overlay_id(a:1) : (exists('b:minibrowser_overlay_id') ? b:minibrowser_overlay_id : s:current_overlay_id())
    call s:rpc_notify('overlay:close', {'id': overlay_id, 'trigger': 'command-close', 'destroy': v:true})
    call rpcnotify(0, 'mini-browser:close')
    if exists('b:minibrowser_overlay_id') && b:minibrowser_overlay_id ==# overlay_id
        unlet b:minibrowser_overlay_id
    endif
    if exists('g:nyaovim_mini_browser_instances') && has_key(g:nyaovim_mini_browser_instances, overlay_id)
        let info = g:nyaovim_mini_browser_instances[overlay_id]
        if has_key(info, 'prev_statusline')
            call setbufvar(info.buffer, '&statusline', info.prev_statusline)
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
    let base = get(g:nyaovim_mini_browser_instances[a:bufnr], 'prev_statusline', getbufvar(a:bufnr, '&statusline'))
    let base = substitute(base, '\s\+MiniBrowserFocus:\w\+$', '', '')
    let base = substitute(base, '\s\+$', '', '')
    let status = base . ' ' . focus
    call setbufvar(a:bufnr, '&statusline', status)
    silent! redrawstatus
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
augroup END

let g:loaded_nyaovim_mini_browser = 1
