"============================================================================
" FILE: bufManager.vim
" AUTHOR: Quramy <yosuke.kurami@gmail.com>
"============================================================================

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('tsuquyomi')

let s:buf_info_map = {}

function! s:normalize(buf_name)
  return substitute(a:buf_name, '\\', '/', 'g')
endfunction


function! tsuquyomi#bufManager#open(file_name)
  if bufnr(a:file_name) == -1
    return 0
  endif
  let info = {
        \'is_opened': 1,
        \'is_dirty': 0,
        \'bufname': a:file_name
        \}
  let s:buf_info_map[s:normalize(a:file_name)] = info
  return info
endfunction

function! tsuquyomi#bufManager#opendFiles()
  return copy(s:buf_info_map)
endfunction

function! tsuquyomi#bufManager#clearMap()
  let s:buf_info_map = {}
  return 1
endfunction

function! tsuquyomi#bufManager#bufName(file_name)
  let name = s:normalize(a:file_name)
  if !has_key(s:buf_info_map, name)
    return 0
  endif
  return s:buf_info_map[name].bufname
endfunction

function! tsuquyomi#bufManager#close(file_name)
  let name = s:normalize(a:file_name)
  if !has_key(s:buf_info_map, name)
    return 0
  endif
  let s:buf_info_map[name].is_opened = 0
  return 1
endfunction

function! tsuquyomi#bufManager#isOpened(file_name)
  let name = s:normalize(a:file_name)
  if !has_key(s:buf_info_map, name)
    return 0
  endif
  return s:buf_info_map[name].is_opened
endfunction

function! tsuquyomi#bufManager#setDirty(file_name, state)
  let name = s:normalize(a:file_name)
  if !has_key(s:buf_info_map, name)
    return 0
  endif
  let s:buf_info_map[name].is_dirty = a:state
  return 1
endfunction

function! tsuquyomi#bufManager#isDirty(file_name)
  let name = s:normalize(a:file_name)
  if !has_key(s:buf_info_map, name)
    return 0
  endif
  return s:buf_info_map[name].is_dirty
endfunction

function! tsuquyomi#bufManager#whichDirty(file_name_list)
  let result = []
  for file_name in a:file_name_list
    if tsuquyomi#bufManager#isDirty(file_name)
      call add(result, file_name)
    endif
  endfor
  return result
endfunction

function! tsuquyomi#bufManager#tmpfile(file_name)
  let name = s:normalize(a:file_name)
  if !has_key(s:buf_info_map, name)
    return 0
  endif
  if !has_key(s:buf_info_map[name], 'tmpfile')
    let tmpfile = tempname()
    let s:buf_info_map[name].tmpfile = tmpfile
    return tmpfile
  else
    return s:buf_info_map[name].tmpfile
  endif
endfunction

function! tsuquyomi#bufManager#saveTmp(file_name)
  let tmpfile = tsuquyomi#bufManager#tmpfile(a:file_name)
  call writefile(getbufline(a:file_name, 1, '$'), tmpfile)
  return 1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
