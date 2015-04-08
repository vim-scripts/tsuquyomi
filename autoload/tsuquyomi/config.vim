"============================================================================
" FILE: config.vim
" AUTHOR: Quramy <yosuke.kurami@gmail.com>
"============================================================================
"
scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('tsuquyomi')
let s:P = s:V.import('ProcessManager')
let s:Filepath = s:V.import('System.Filepath')
let s:script_dir = expand('<sfile>:p:h')

let s:tss_cmd = ''

function! tsuquyomi#config#preconfig()

  if !exists('g:tsuquyomi_is_available')
    if !s:P.is_available()
      " 1. vimproc installation check
      let g:tsuquyomi_is_available = 0
      call s:deleteCommand()
      echom '[Tsuquyomi] Shougo/vimproc.vim is not installed. Please install it.'
    else
      " 2. tsserver installation check
      let s:tss_cmd = tsuquyomi#config#tsscmd()
      if s:tss_cmd == ''
        let g:tsuquyomi_is_available = 0
        call s:deleteCommand()
      else
        let g:tsuquyomi_is_available = 1
      endif
    endif
  endif

  return g:tsuquyomi_is_available
endfunction

function! s:deleteCommand()
  delc TsuquyomiStartTss
  delc TsuquyomiStopTss
  delc TsuquyomiStatusTss
endfunction

function! tsuquyomi#config#tsscmd()
  if g:tsuquyomi_use_dev_node_module == 0
    let l:cmd = 'tsserver'
    if !executable(l:cmd)
      echom '[Tsuquyomi] tsserver is not installed. Try "npm -g install typescript".'
      return ''
    endif
  else
    if g:tsuquyomi_use_dev_node_module == 1
      let l:path = s:Filepath.join(s:script_dir, '../../../node_modules/typescript/bin/tsserver.js')
    elseif g:tsuquyomi_use_dev_node_module == 2
      let l:path = g:tsuquyomi_tsserver_path
    else
      echom '[Tsuquyomi] Invalid option value "g:tsuquyomi_use_dev_node_module".'
      return ''
    endif
    if filereadable(l:path) != 1
      echom '[Tsuquyomi] tsserver.js does not exist. Try "npm install"., '.l:path
      return ''
    endif
    let l:cmd = g:tsuquyomi_nodejs_path.' "'.l:path.'"'
  endif
  return l:cmd
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
