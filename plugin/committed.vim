"  .d8888b.                                    d8b 888   888                888 
" d88P  Y88b                                   Y8P 888   888                888 
" 888    888                                       888   888                888 
" 888         .d88b. 88888b.d88b. 88888b.d88b. 888 888888.88888 .d88b.  .d88888 
" 888        d88''88b.88 '888 '88b.88 '888 '88b.88 888   888   d8P  Y8b.88' 888 
" 888    888 888  888.88  888  888.88  888  888.88 888   888   88888888.88  888 
" Y88b  d88P Y88..88P.88  888  888.88  888  888.88 Y88b. Y88b. Y8b.    Y88b 888 
"  'Y8888P'   'Y88P' 888  888  888.88  888  888.88  'Y888 'Y888 'Y8888  'Y88888 
"
" Vim plugin to build a commit file (a text file listing paths to files to
" commit) by recording the file currently being edited into a new or existing
" commit file.
"
" Version:    1.0b
" Maintainer: Aaron Bieber <aaron@aaronbieber.com>
" License:    The same as Vim itself.
"
" Copyright (c) 2008-2013 Aaron Bieber
"
" Configuration options:
"   g:committed_file_path The path on disk to a location where commit
"                         files should be created/saved. Something like
"                         ~/commits/ or c:/Users/fmulder/commits/. OS path 
"                         expansions work in this path, so $HOME/commits 
"                         is also valid.

" Don't let it get loaded twice.
if exists('g:loaded_committed') || &cp
  finish
endif
let g:loaded_committed = 1

" Ensure that the version is high enough.
if v:version < 700
  call s:warn("Build Commit File requires at least VIM 7.0.")
endif

" Private script variables.
let s:commit_file_entries = []
let s:commit_filename_base = ""
let s:commit_filename = ""

function! committed#status_line_filename() "{{{1
  " Return the base name of the current commit file for use in the status 
  " line (or elsewhere).

  return s:commit_filename_base
endfunction

function! committed#status_line_symbol() "{{{1
  " Return a symbol indicating whether the current file exists within the 
  " configured commit list. This can be any value, even fancy Unicode 
  " symbols.

  if(len(s:commit_filename_base))
    if(s:exists_in_commit_list(expand("%:p")))
      return s:get_option("committed_symbol_true")
    else
      return s:get_option("committed_symbol_false")
    endif
  endif

  return ""
endfunction

function! s:warn(message) "{{{1
  " Display a colorized warning message. You know, for errors.

  echohl WarningMsg
  echom a:message
  echohl None
endfunction

function! s:set_commit_filename(...) "{{{1
  " Ask the user to enter a filename for this commit file and see if it exists
  " on disk. If not, set it.

  let nochange = (a:0 && a:1 =~ "nochange") ? 1 : 0

  let path = s:get_commit_path()
  let filename = input("Enter a name for your commit file: ") | redraw
  if(!len(filename))
    " If a filename was not provided, return zero (failure to set a 
    " filename).
    echo "No commit list name given; aborting."
    return 0
  else
    let s:commit_filename = filename . ".commit"
    let full_filename = path . s:commit_filename

    " If the file is readable and writable, we can try to resume using 
    " that file.
    if(len(glob(full_filename)))
      if(!filereadable(full_filename) || !filewritable(full_filename))
        call s:warn("The specified commit file already exists, but is not readable or writable!")
        return 0
      endif

      " File already exists!
      if(!nochange)
        call s:warn("This file already exists!")
        echo "  y - Yes use this file, empty it first."
        echo "  a - Yes use this file, append to the existing list."
        echo "  n - No, don't use this file."
        let ans = input("Use it anyway? [y/a/N]: ") | redraw
      else
        let ans = "a"
      endif

      if(ans == "n")
        return 0
      endif

      let s:commit_filename_base = filename

      if(ans == "y" || ans == "Y")
        call writefile([], path . filename . ".commit")
      endif

      let s:commit_file_entries = readfile(path . s:commit_filename)
    else
      " File does not exist or is not readable and writable. If the path 
      " is readable and writable, we can assume the user wanted to 
      " create a new file.
      if(nochange)
        call s:warn("To get an existing commit file, the file must exist!")
        return 0
      endif

      if(filewritable(path) == 2)
        call writefile([], full_filename)
        let s:commit_filename_base = filename
        let s:commit_filename = filename . ".commit"
        let s:commit_file_entries = []
      else
        " If the path is not readable or not writable, there really 
        " isn't much that we can do. Complain about it.
        call s:warn("Cannot write to your commit file path (" . path . ").")
        return 0
      endif
    endif
  endif

  " Update everything now that the file is set.
  "call s:activate_buffer()
  return 1
endfunction

function! s:unset_commit_filename() "{{{1
  " Remove the commit file definition for this Vim instance. This basically 
  " turns off commit file tracking globally in this instance of Vim.

  let s:commit_filename_base = ""
  let s:commit_filename = ""
endfunction

function! s:add_file() "{{{1
  " Add the current file to the commit file.

  " If the filename isn't defined yet, ask for a name.
  if(!len(s:commit_filename))
    let set_success = s:set_commit_filename()
    if(!set_success)
      return
    endif
  endif

  let path = s:get_commit_path()
  let thisfile = expand("%:p")
  let thisline = thisfile

  if(s:exists_in_commit_list(thisfile))
    call s:warn("This file already exists in the commit list!")
    return
  endif

  let s:commit_file_entries = readfile(path . s:commit_filename)
  let s:commit_file_entries = s:commit_file_entries + [thisline]
  call writefile(s:commit_file_entries, path . s:commit_filename)

  "let b:committed_list_contains_this_buffer = 1
  echo "Added ".thisfile." to the " . s:commit_filename . " file."
endfunction

function! s:remove_file() "{{{1
  " Remove the current file from the commit list, if there is one.

  " If the filename isn't defined yet, ask for a name.
  if(!len(s:commit_filename))
    call s:warn("You cannot remove this file because no commit file is set.")
  endif

  let path = s:get_commit_path()
  let thisfile = expand("%:p")
  let thisline = thisfile

  if(filereadable(path . s:commit_filename))
    " We need a literal match, not a path match, so we don't use 
    " s:exists_in_commit_list here, instead we use index().
    let file_index = index(s:commit_file_entries, thisfile)
    if(file_index > -1)
      call remove(s:commit_file_entries, file_index)
      echo "Removed " . thisfile . " from the " . s:commit_filename_base . " commit file."
      call writefile(s:commit_file_entries, s:get_commit_path() . s:commit_filename)
      exe "redrawstatus!"
    endif
  endif
endfunction

function! s:get_commit_path()
  let path = expand(s:get_option("committed_file_path"))
  if(strpart(path, len(path) - 1, 1) != "/")
    let path = path . "/"
  endif

  return path
endfunction

function! s:exists_in_commit_list(filename) "{{{1
  " Determine whether the given filename exists in the current commit list, 
  " presuming that it is set.

  for line in s:commit_file_entries
    " If the commit line is entirely found within the buffer path, we 
    " presume that the buffer path's parent folder is included in the 
    " commit list.
    if(match(a:filename, line) > -1)
      return 1
    endif
  endfor

  return 0
endfunction

function! s:show_commit_file() "{{{1
  " Open the current commit file (if there is one) in a new buffer, splitting
  " below by default.

  if(len(s:commit_filename))
    let path = s:get_commit_path()
    exe 'bot split ' . escape(path . s:commit_filename, ' ')
    setf committed_list
  else
    call s:warn("There is no commit file set up in this Vim instance.")
  endif
endfunction

function! s:open_file() "{{{1
  " While in the commit file view, split the window and open the filename 
  " under the cursor while closing the commit file view. This is, by 
  " default, bound to the enter key in that view.

  let filename = expand("<cfile>")
  if(len(filename) && filereadable(filename))
    let list_buffer_number = bufnr("%")
    exec "split " . filename
    exec "bd! " . list_buffer_number
  endif
endfunction

function! s:get_option(name) "{{{1
  " Grab a user-specified option if defined, or the default that is 
  " configured at the top of the script.

  if exists('g:' . a:name)
    return g:{a:name}
  else
    return s:option_defaults[a:name]
  endif
endfunction

function! s:activate_buffer() "{{{1
  " Look for the current buffer in the current commit file, if it is set. 
  " This is called when buffers are focused or changed so that things like 
  " the status line segment stay up-to-date.

  if(len(s:commit_filename))
    if(len(expand("%:p")))
      let thisfile = expand("%:p")
      if(len(thisfile))
        "let b:committed_list_contains_this_buffer = s:exists_in_commit_list(thisfile)
      endif
    endif
  endif
endfunction
" }}}

" Default option values.
let s:option_defaults = {
  \ "committed_file_path"     : "~/commits",
  \ "committed_symbols_fancy" : 0,
  \ "committed_symbol_true"   : "✔",
  \ "committed_symbol_false"  : "✘" }

if(!s:get_option("committed_symbols_fancy"))
  let s:option_defaults["committed_symbol_true"] = "<+>"
  let s:option_defaults["committed_symbol_false"] = "<->"
endif

" Set up the publicly available mappings that users can map real keys to, if 
" they wish to override the defaults.
nmap <silent> <Plug>CommittedAddFile             :call <SID>add_file()<CR>
nmap <silent> <Plug>CommittedRemoveFile          :call <SID>remove_file()<CR>
nmap <silent> <Plug>CommittedShowCommitFile      :call <SID>show_commit_file()<CR>
nmap <silent> <Plug>CommittedSetCommitFileName   :call <SID>set_commit_filename("nochange")<CR>
nmap <silent> <Plug>CommittedUnsetCommitFileName :call <SID>unset_commit_filename()<CR>

" Configure default mappings unless the user has asked us not to by setting 
" this global variable.
if !exists("g:committed_no_mappings") || ! g:committed_no_mappings
  nmap <unique> <Leader>la <Plug>CommittedAddFile
  nmap <unique> <Leader>lr <Plug>CommittedRemoveFile
  nmap <unique> <Leader>ls <Plug>CommittedShowCommitFile
  nmap <unique> <Leader>lg <Plug>CommittedSetCommitFileName
  nmap <unique> <Leader>lu <Plug>CommittedUnsetCommitFileName
endif

" This function configures the mappings within the commit list window when it 
" is opened.
function! s:configure_list_mappings()
  nmap <Enter> :call <SID>open_file()<CR>
  nmap <Esc> :bd!<CR>
endfunction

" Update local state when a buffer, window, or tab is entered. This keeps the 
" status line and other such things synchronized.
"autocmd BufEnter,BufWinEnter,WinEnter,TabEnter * call s:activate_buffer()

" Configure the commit list window when it is created.
augroup committed_list
  autocmd!
  autocmd BufReadPost *.commit setfiletype committed_list
  autocmd FileType committed_list call s:configure_list_mappings()
augroup END

" vim: set ts=2 sw=2 et :
