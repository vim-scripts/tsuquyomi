scriptencoding utf-8

UTSuite [tsuquyomi#tsClient#tsReload] tsReload

let g:tsuquyomi_use_dev_node_module = 1
let g:tsuquyomi_waittime_after_open = 0.2

let s:V = vital#of('tsuquyomi')
let s:Filepath = s:V.import('System.Filepath')
let s:script_dir = tsuquyomi#rootDir()

"TODO remove later
let g:tsuquyomi_use_dev_node_module = 2
let g:tsuquyomi_tsserver_path = s:Filepath.join(s:script_dir, '../../git/typescript/built/local/tsserver.js')

function! s:test1()
  let file = s:Filepath.join(s:script_dir, 'test/resources/SimpleModule.ts')
  call tsuquyomi#tsClient#tsOpen(file)
  Assert tsuquyomi#tsClient#tsReload(file, file) == 1
  call tsuquyomi#tsClient#stopTss()
endfunction
