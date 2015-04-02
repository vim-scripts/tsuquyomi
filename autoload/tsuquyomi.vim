"============================================================================
" FILE: tsuquyomi.vim
" AUTHOR: Quramy <yosuke.kurami@gmail.com>
"============================================================================

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('tsuquyomi')
let s:Filepath = s:V.import('System.Filepath')
let s:script_dir = expand('<sfile>:p:h')
let s:root_dir = s:Filepath.join(s:script_dir, '../')

"
" ### Utilites {{{
function! s:error(msg)
  echom (a:msg)
  throw 'tsuquyomi: '.a:msg
endfunction

function! s:normalizePath(path)
  return substitute(a:path, '\\', '/', 'g')
endfunction

" Check whether files are opened.
" Found not opend file, show message.
function! s:checkOpenAndMessage(filelist)
  let opened = []
  let not_opend = []
  for file in a:filelist
    if tsuquyomi#bufManager#isOpened(file)
      call add(opened, file)
    else
      call add(not_opend, file)
    endif
  endfor
  if len(not_opend)
    echom '[Tsuquyomi] Buffers ['.join(not_opend, ', ').'] are not opened by TSServer. Please exec command ":TsuquyomiOpen '.join(not_opend).'" and retry.'
  endif
  return [opened, not_opend]
endfunction

" Save current buffer to a temp file, and emit to reload TSServer.
" This function may be called for conversation with TSServer after user's change buffer.
function! s:flash()
  if tsuquyomi#bufManager#isDirty(expand('%:p'))
    let file_name = expand('%:p')
    call tsuquyomi#bufManager#saveTmp(file_name)
    call tsuquyomi#tsClient#tsReload(file_name, tsuquyomi#bufManager#tmpfile(file_name))
    call tsuquyomi#bufManager#setDirty(file_name, 0)
  endif
endfunction

function! s:is_valid_identifier(symbol_str)
  return a:symbol_str =~ '[A-Za-z_\$][A-Za-z_\$0-9]*'
endfunction

" ### Utilites }}}

" ### Public functions {{{
"
function! tsuquyomi#rootDir()
  return s:root_dir
endfunction

" #### Server operations {{{
function! tsuquyomi#startServer()
  return tsuquyomi#tsClient#startTss()
endfunction

function! tsuquyomi#stopServer()
  call tsuquyomi#bufManager#clearMap()
  return tsuquyomi#tsClient#stopTss()
endfunction

function! tsuquyomi#statusServer()
  return tsuquyomi#tsClient#statusTss()
endfunction

" #### Server operations }}}

" #### Notify changed {{{
function! tsuquyomi#letDirty()
  return tsuquyomi#bufManager#setDirty(expand('%:p'), 1)
endfunction
" #### Notify changed }}}

" #### File operations {{{
function! tsuquyomi#open(...)
  let filelist = a:0 ? map(range(1, a:{0}), 'expand(a:{v:val})') : [expand('%:p')]
  for file in filelist
    if file == ''
      continue
    endif
    call tsuquyomi#tsClient#tsOpen(file)
    call tsuquyomi#bufManager#open(file)
  endfor
  return 1
endfunction

function! tsuquyomi#close(...)
  let filelist = a:0 ? map(range(1, a:{0}), 'expand(a:{v:val})') : [expand('%:p')]
  let file_count = 0
  for file in filelist
    if tsuquyomi#bufManager#isOpened(file)
      call tsuquyomi#tsClient#tsClose(file)
      call tsuquyomi#bufManager#close(file)
      let file_count = file_count + 1
    endif
  endfor
  return file_count
endfunction

function! s:reloadFromList(filelist)
  let file_count = 0
  for file in a:filelist
    if tsuquyomi#bufManager#isOpened(file)
      call tsuquyomi#tsClient#tsReload(file, file)
    else
      call tsuquyomi#tsClient#tsOpen(file)
      call tsuquyomi#bufManager#open(file)
    endif
    call tsuquyomi#bufManager#setDirty(file, 0)
    let file_count = file_count + 1
  endfor
  return file_count
endfunction

function! tsuquyomi#reload(...)
  let filelist = a:0 ? map(range(1, a:{0}), 'expand(a:{v:val})') : [expand('%:p')]
  return s:reloadFromList(filelist)
endfunction

function! tsuquyomi#dump(...)
  let filelist = a:0 ? map(range(1, a:{0}), 'expand(a:{v:val})') : [expand('%:p')]
  let [opend, not_opend] = s:checkOpenAndMessage(filelist)

  for file in opend
    call tsuquyomi#tsClient#tsSaveto(file, file.'.dump')
  endfor
endfunction
" #### File operations }}}

" #### Complete {{{
"
function! tsuquyomi#makeCompleteMenu(file, line, offset, entryNames)
  let res_list = tsuquyomi#tsClient#tsCompletionEntryDetails(a:file, a:line, a:offset, a:entryNames)
  let display_texts = []
  for result in res_list
    let l:display = ''
    for part in result.displayParts
      if part.kind == 'lineBreak'
        let l:display = l:display.'{...}'
        break
      endif
      let l:display = l:display.part.text
    endfor
    call add(display_texts, l:display)
  endfor
  return display_texts
endfunction

function! tsuquyomi#complete(findstart, base)

  if len(s:checkOpenAndMessage([expand('%:p')])[1])
    return
  endif

  let l:line_str = getline('.')
  let l:line = line('.')
  let l:offset = col('.')
  
  " search backwards for start of identifier (iskeyword pattern)
  let l:start = l:offset 
  while l:start > 0 && l:line_str[l:start-2] =~ "\\k"
    let l:start -= 1
  endwhile

  if(a:findstart)
    call s:flash()
    return l:start - 1
  else
    let l:file = expand('%:p')
    let l:res_dict = {'words': []}
    let l:res_list = tsuquyomi#tsClient#tsCompletions(l:file, l:line, l:start, a:base)

    let length = strlen(a:base)
    let size = g:tsuquyomi_completion_chank_size
    let j = 0

    while j * size < len(l:res_list)
      let entries = []
      let items = []
      let upper = min([(j + 1) * size, len(l:res_list)])
      for i in range(j * size, upper - 1)
        let info = l:res_list[i]
        if !length || info.name[0:length - 1] == a:base
          let l:item = {'word': info.name}
          call add(entries, info.name)
          call add(items, l:item)
        endif
      endfor

      let menus = tsuquyomi#makeCompleteMenu(l:file, l:line, l:start, entries)
      let idx = 0
      for menu in menus
        let items[idx].menu = menu
        call complete_add(items[idx])
        let idx = idx + 1
      endfor
      if complete_check()
        break
      endif
      let j = j + 1
    endwhile

    return []

  endif
endfunction
" ### Complete }}}

" #### Definition {{{
function! tsuquyomi#definition()

  if len(s:checkOpenAndMessage([expand('%:p')])[1])
    return
  endif

  call s:flash()

  let l:file = s:normalizePath(expand('%:p'))
  let l:line = line('.')
  let l:offset = col('.')
  let l:res_list = tsuquyomi#tsClient#tsDefinition(l:file, l:line, l:offset)

  if(len(l:res_list) == 1)
    " If get result, go to the location.
    let l:info = l:res_list[0]
    if l:file == l:info.file
      " Same file
      call cursor(l:info.start.line, l:info.start.offset)
    else
      " If other file, split window
      execute 'split +call\ cursor('.l:info.start.line.','.l:info.start.offset.') '.l:info.file
    endif
  else
    " If don't get result, do nothing.
  endif
endfunction
" #### Definition }}}

" #### References {{{
" Show reference on a location window.
function! tsuquyomi#references()

  if len(s:checkOpenAndMessage([expand('%:p')])[1])
    return
  endif

  call s:flash()

  let l:file = expand('%:p')
  let l:line = line('.')
  let l:offset = col('.')

  " 1. Fetch reference information.
  let l:res = tsuquyomi#tsClient#tsReferences(l:file, l:line, l:offset)

  if(has_key(l:res, 'refs') && len(l:res.refs) != 0)
    let l:location_list = []
    " 2. Make a location list for `setloclist`
    for reference in res.refs
      let l:location_info = {
            \'filename': reference.file,
            \'lnum': reference.start.line,
            \'col': reference.start.offset,
            \'text': reference.lineText
            \}
      call add(l:location_list, l:location_info)
    endfor
    if(len(l:location_list) > 0)
      call setloclist(0, l:location_list, 'r')
      "3. Open location window.
      lwindow
    endif
  else
    echom '[Tsuquyomi] References: Not found...'
  endif
endfunction
" #### References }}}

" #### Geterr {{{
function! tsuquyomi#geterr()
  if len(s:checkOpenAndMessage([expand('%:p')])[1])
    return
  endif

  call s:flash()

  let l:files = [expand('%:p')]
  let l:delayMsec = 50 "TODO export global option

  " 1. Fetch error information from TSServer.
  let result = tsuquyomi#tsClient#tsGeterr(l:files, l:delayMsec)

  let quickfix_list = []
  " 2. Make a quick fix list for `setqflist`.
  if(has_key(result, 'semanticDiag'))
    for diagnostic in result.semanticDiag.diagnostics
      let item = {}
      let item.filename = result.semanticDiag.file
      let item.lnum = diagnostic.start.line
      if(has_key(diagnostic.start, 'offset'))
        let item.col = diagnostic.start.offset
      endif
      let item.text = diagnostic.text
      let item.type = 'E'
      call add(quickfix_list, item)
    endfor
  endif

  if(has_key(result, 'syntaxDiag'))
    for diagnostic in result.syntaxDiag.diagnostics
      let item = {}
      let item.filename = result.syntaxDiag.file
      let item.lnum = diagnostic.start.line
      if(has_key(diagnostic.start, 'offset'))
        let item.col = diagnostic.start.offset
      endif
      let item.text = diagnostic.text
      let item.type = 'E'
      call add(quickfix_list, item)
    endfor
  endif

  call setqflist(quickfix_list, 'r')
  if len(quickfix_list) > 0
    cwindow
  else
    cclose
  endif
endfunction

function! tsuquyomi#reloadAndGeterr()
  if tsuquyomi#tsClient#statusTss() != 'undefined'
    return tsuquyomi#geterr()
    "return tsuquyomi#reload() && tsuquyomi#geterr()
  endif
endfunction

" #### Geterr }}}

" #### Balloon {{{
function! tsuquyomi#balloonexpr()

  if tsuquyomi#tsClient#tsReload() != 'undefined'
    call s:flash()
    let l:filename = buffer_name(v:beval_bufnr)
    let res = tsuquyomi#tsClient#tsQuickinfo(l:filename, v:beval_lnum, v:beval_col)
    if has_key(res, 'displayString')
      return res.displayString
    endif
  endif
endfunction
" #### Balloon }}}

" #### Rename {{{
function! tsuquyomi#renameSymbol()

  if len(s:checkOpenAndMessage([expand('%:p')])[1])
    return
  endif

  call s:flash()

  let l:filename = expand('%:p')
  let l:line = line('.')
  let l:offset = col('.')

  " * Make a list of locations of symbols to be replaced.
  let l:res_dict = tsuquyomi#tsClient#tsRename(l:filename, l:line, l:offset, 0, 0)

  " * Check the symbol is renameable
  if !has_key(l:res_dict, 'info') 
    "TODO message
    echom '[Tsuquyomi] No symbol to be rename'
    return
  elseif !l:res_dict.info.canRename
    echom '[Tsuquyomi] '.l:res_dict.info.localizedErrorMessage
    return
  endif

  " TODO to be able to change multiple buffer.
  "
  " * Check affection only current buffer.
  if len(l:res_dict.locs) != 1 || s:normalizePath(expand('%:p')) != l:res_dict.locs[0].file
    let file_list = map(copy(l:res_dict.locs), 'v:val.file')
    let dirty_file_list = tsuquyomi#bufManager#whichDirty(file_list)

    " if len(dirty_file_list)
    "   echom '[Tsuquyomi] This action will be affect to other buffers. Please save the following files and retry.'
    "   echohl string
    "   echom join(dirty_file_list, ', ')
    "   echohl none
    "   return
    " endif
    call s:reloadFromList(dirty_file_list)

  endif


  let l:location_list = []

  " for file_hit in l:res_dict.locs
  "   for reference in file_hit.locs
  "     let l:location_info = {
  "           \ 'filename': file_hit.file,
  "           \ 'lnum': reference.start.line,
  "           \ 'col': reference.start.offset,
  "           \ 'text': l:res_dict.info.displayName
  "           \ }
  "     call add(l:location_list, l:location_info)
  "   endfor
  " endfor

  " if !len(l:location_list)
  "   echom '[Tsuquyomi] No symbol to be rename...'
  " endif

  " call setloclist(0, l:location_list, 'r')
  " lwindow
  "

  " * Question user what new symbol name.
  echohl String
  let renameTo = input('[Tsuquyomi] New symbol name : ')
  echohl none 
  if !s:is_valid_identifier(renameTo)
    echo ' '
    echom '[Tsuquyomi] It is a not valid identifer.'
    return
  endif

  let s:locs_dict = {}
  let s:rename_to = renameTo
  let other_buf_list = []

  " * Execute to replace symbols by location, by buffer
  for fileLoc in l:res_dict.locs
    let buffer_name = tsuquyomi#bufManager#bufName(fileLoc.file)
    let s:locs_dict[buffer_name] = fileLoc.locs
    let changed_count = 0
    if buffer_name != expand('%:p')
      call add(other_buf_list, buffer_name)
      continue
    endif
    let changed_count = s:renameLocal()
  endfor

  echohl String
  echo ' '
  echo 'Changed '.changed_count.' locations.'
  echohl none 

  for otherbuf in other_buf_list
    " * If target buffer is opened in some window?
    "  * opened: change current window?
    "  * not opened: open current window to buffer.
    execute('silent split +call\ s:renameLocal() '.otherbuf)
  endfor

endfunction

function! s:renameLocal()
  let changed_count = 0
  let filename = expand('%:p')
  let locations_in_buf = s:locs_dict[expand('%:p')]
  let renameTo = s:rename_to
  for span in locations_in_buf
    if span.start.line != span.end.line
      echom '[Tsuquyomi] this span is across multiple lines. '
      return
    endif

    let lineidx = span.start.line
    let linestr = getline(lineidx)
    if span.start.offset - 1
      let pre = linestr[:(span.start.offset - 2)]
      let post = linestr[(span.end.offset - 1):]
      let linestr = pre.renameTo.post
    else
      let post = linestr[(span.end.offset - 1):]
      let linestr = renameTo.post
    endif
    call setline(lineidx, linestr)
    let changed_count = changed_count + 1
  endfor
  call tsuquyomi#reload()
  return changed_count
endfor

endfunction
" #### Rename }}}

" ### Public functions }}}

let &cpo = s:save_cpo
unlet s:save_cpo