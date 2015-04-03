"============================================================================
" FILE: tsuquyomi.vim
" AUTHOR: Quramy <yosuke.kurami@gmail.com>
"============================================================================

scriptencoding utf-8

if !tsuquyomi#config#preconfig()
  finish
endif

let s:V = vital#of('tsuquyomi')
let s:P = s:V.import('ProcessManager')

if(!exists(g:tsuquyomi_is_available) && !s:P.is_available())
  let g:tsuquyomi_is_available = 0
  echom '[Tsuquyomi] Shougo/vimproc.vim is not installed. Please install it.'
  finish
endif
if(!g:tsuquyomi_is_available)
  finish
endif

let g:tsuquyomi_is_available = 1

command! -buffer -nargs=* -complete=buffer TsuquyomiOpen    :call tsuquyomi#open(<f-args>)
command! -buffer -nargs=* -complete=buffer TsuquyomiClose   :call tsuquyomi#close(<f-args>)
command! -buffer -nargs=* -complete=buffer TsuquyomiReload  :call tsuquyomi#reload(<f-args>)
command! -buffer -nargs=* -complete=buffer TsuquyomiDump    :call tsuquyomi#dump(<f-args>)

command! -buffer TsuquyomiDefinition    :call tsuquyomi#definition()
command! -buffer TsuquyomiReferences    :call tsuquyomi#references()
command! -buffer TsuquyomiGeterr        :call tsuquyomi#geterr()
command! -buffer TsuquyomiRenameSymbol  :call tsuquyomi#renameSymbol()

noremap <silent> <buffer> <Plug>(TsuquyomiDefinition)     :TsuquyomiDefinition <CR>
noremap <silent> <buffer> <Plug>(TsuquyomiReferences)     :TsuquyomiReferences <CR>
noremap <silent> <buffer> <Plug>(TsuquyomiRenameSymbol)   :TsuquyomiRenameSymbol <CR>

augroup tsuquyomi_defaults
  autocmd!
  autocmd BufWritePost *.ts silent! call tsuquyomi#reloadAndGeterr()
  autocmd TextChanged,TextChangedI *.ts silent! call tsuquyomi#letDirty()
augroup END

" Default mapping.
if !hasmapto('<Plug>(TsuquyomiDefinition)')
  map <buffer> <C-]> <Plug>(TsuquyomiDefinition)
endif
if !hasmapto('<Plug>(TsuquyomiReferences)')
  map <buffer> <C-^> <Plug>(TsuquyomiReferences)
endif

setlocal bexpr=tsuquyomi#balloonexpr()
setlocal omnifunc=tsuquyomi#complete

if g:tsuquyomi_auto_open
  silent! call tsuquyomi#open()
endif
