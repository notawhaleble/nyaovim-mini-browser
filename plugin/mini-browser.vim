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
endfunction

function! MiniBrowserClose(...) abort
    let overlay_id = a:0 >= 1 ? s:normalize_overlay_id(a:1) : s:current_overlay_id()
    call s:rpc_notify('overlay:close', {'id': overlay_id, 'trigger': 'command-close'})
    call rpcnotify(0, 'mini-browser:close')
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

command! -nargs=* -bang MiniBrowser call MiniBrowserOpen(<bang>0, <f-args>)
command! -nargs=? MiniBrowserClose call MiniBrowserClose(<f-args>)
command! -nargs=? MiniBrowserFocus call MiniBrowserFocusCommand('toggle', <f-args>)
command! -nargs=? MiniBrowserFocusEditor call MiniBrowserFocusCommand('editor', <f-args>)
command! -nargs=? MiniBrowserFocusBrowser call MiniBrowserFocusCommand('browser', <f-args>)
command! -nargs=? MiniBrowserToggleFocus call MiniBrowserFocusCommand('toggle', <f-args>)

let g:loaded_nyaovim_mini_browser = 1
