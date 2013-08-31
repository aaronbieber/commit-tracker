" Vim plugin to build a commit file (a text file listing paths to files to
" commit) by recording the file currently being edited into a new or existing
" commit file.
"
" Version:		1.0a
" Maintainer:	Aaron Bieber <aaron@aaronbieber.com>
" License:		The same as Vim itself.
"
" Copyright (c) 2008-2013 Aaron Bieber
"
" Configuration options:
" 	g:committed_file_path		The path on disk to a location where commit
" 								files should be created/saved. Something like
"								~/commits/ or ~/commits/
"								Make sure you have a trailing slash.
"								@todo Fix this.

" Don't let it get loaded twice.
if exists('g:loaded_buildCommitFile') || &cp
	finish
endif
let g:loaded_buildCommitFile = 1

" Ensure that the version is high enough.
if v:version < 700
	echohl WarningMsg|echomsg "Build Commit File requires at least VIM 7.0."|echohl None
endif

" Temporary values of overridden configuration variables.
let s:optionOverrides = {}

function! committed#status_line_filename() "{{{1
	if exists("g:committed_filename_base")
		return g:committed_filename_base
	else
		return ""
	endif
endfunction

function! committed#status_line_symbol() "{{{1
	if(exists("g:committed_filename_base"))
		if(exists("b:committed_list_contains_this_buffer") && b:committed_list_contains_this_buffer)
			return "✔"
		else
			return "✘"
		endif
	endif

	return ""
endfunction

function! s:set_commit_filename(...) "{{{1
	" Ask the user to enter a filename for this commit file and see if it exists
	" on disk. If not, set it.
	let nochange = (a:0 > 0 && a:1 =~ "nochange") ? 1 : 0

	let path = s:get_option("committed_file_path", "~/commits/")
	let filename = input("Enter a name for your commit file: ") | redraw
	if(len(filename) && filereadable(path.filename.".commit"))
		" File already exists!
		if !nochange
			echohl WarningMsg|echomsg "This file already exists!"|echohl None
			echo "  y - Yes use this file, empty it first."
			echo "  a - Yes use this file, append to the existing list."
			echo "  n - No, don't use this file."
			let ans = input("Use it anyway? [y/a/N]: ") | redraw
		else
			let ans = "a"
		endif

		if(ans == "y" || ans == "Y")
			call writefile([], path.filename.".commit")
			let g:committed_filename_base = filename
			let g:committed_filename = filename.".commit"
		elseif(ans == "a" || ans == "A")
			let g:committed_filename_base = filename
			let g:committed_filename = filename.".commit"
		endif
	elseif(len(filename))
		if !nochange
			let g:committed_filename_base = filename
			let g:committed_filename = filename.".commit"
		else
			echohl WarningMsg|echomsg "When selecting an existing commit file, the file must exist."|echohl None
		endif
	endif

	if(exists("g:committed_filename") && len(g:committed_filename))
		call s:activate_buffer()
	endif
endfunction

" Function: s:unset_commit_filename()
" Remove the commit file definition for this Vim instance.
function! s:unset_commit_filename() "{{{1
	unlet g:committed_filename_base
	unlet g:committed_filename
endfunction

" Function: s:path_format(path)
" Format a path returned by expand() into the format we want in our commit
" file. The user might want to customize this behavior. I don't know how to do
" that elegantly.
function! s:path_format(path) "{{{1
	let thefile = a:path
	let thefile = substitute(thefile, "\\", "/", "g")
	let thefile = substitute(thefile, "J:", "/cygdrive/j", "")
	return thefile
endfunction

function! s:path_un_format(path) "{{{1
	" Reverse path formatting from posix back to Windows to be able to do Windows
	" things with it.

	let thefile = a:path
	let thefile = substitute(thefile, "/cygdrive/j", "J:", "")
	let thefile = substitute(thefile, "/", "\\", "g")
	return thefile
endfunction

function! s:add_file() "{{{1
	" Add the current file to the commit file.

	let path = expand(s:get_option("committed_file_path", "~/commits/"))
	" If the filename isn't defined yet, ask for a name.
	if(!exists("g:committed_filename"))
		call s:set_commit_filename()
	endif

	" If the filename still isn't defined, one was not provided or the user
	" provided a name that already existed and declined to overwrite that
	" file.
	if(!exists("g:committed_filename"))
		echohl WarningMsg|echo "You must set a filename before you can continue."|echohl None
		return
	endif

	let thisfile = s:path_format(expand("%:p"))
	let thisline = thisfile

	if(filereadable(path . g:committed_filename))
		if(s:exists_in_commit_list(thisfile))
			let b:committed_list_contains_this_buffer = 1
			echohl WarningMsg|echo "This file already exists in the commit list!"|echohl None
			return
		endif

		let commits = readfile(path.g:committed_filename)
		let commits = commits + [thisline]
		call writefile(commits, path.g:committed_filename)
	elseif(filewritable(path))
		call writefile([thisline], path.g:committed_filename)
	else
		echohl WarningMsg|echo "Your commit file path is not writable."|echohl None
		call s:unset_commit_filename()
		return
	endif

	let b:committed_list_contains_this_buffer = 1
	echo "Added ".thisfile." to the ".g:committed_filename." file."
endfunction

function! s:exists_in_commit_list(filename) "{{{1
	" Determine whether the given filename exists in the current commit list, 
	" presuming that it is set.

	let path = expand(s:get_option("committed_file_path", "~/commits/"))
	if(exists("g:committed_filename"))
		if(filereadable(path . g:committed_filename))
			let commits = readfile(path . g:committed_filename)
			for line in commits
				" If the commit line is entirely found within the buffer path,
				" we presume that the buffer path's parent folder is included
				" in the commit list.
				let line_path = matchlist(line, "^[^\t]*")[0]
				if(match(a:filename, line_path) > -1)
					return 1
				endif
			endfor

			return 0
		endif
	endif

	return 0
endfunction

function! s:show_commit_file() "{{{1
	" Open the current commit file (if there is one) in a new buffer, splitting
	" below by default.

	if(exists("g:committed_filename"))
		let path = expand(s:get_option("committed_file_path", "~/commits/"))
		exec "bot split " . path.g:committed_filename
		setf committed_list
	else
		echohl WarningMsg|echo "There is no commit file set up in this Vim instance."|echohl None
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

function! s:get_option(name, default) "{{{1
	" Grab a user-specified option to override the default provided.  Options are
	" searched in the window, buffer, then global spaces.

	if has_key(s:optionOverrides, a:name) && len(s:optionOverrides[a:name]) > 0
		return s:optionOverrides[a:name][-1]
	elseif exists('w:' . a:name)
		return w:{a:name}
	elseif exists('b:' . a:name)
		return b:{a:name}
	elseif exists('g:' . a:name)
		return g:{a:name}
	else
		return a:default
	endif
endfunction

function! s:activate_buffer() "{{{1
	" Look for the current buffer in the current commit file, if it is set. 
	" This is called when buffers are focused or changed so that things like 
	" the status line segment stay up-to-date.

	if(exists("g:committed_filename") && len(g:committed_filename))
		if(len(expand("%:p")))
			let thisfile = s:path_format(expand("%:p"))
			if(len(thisfile))
				let b:committed_list_contains_this_buffer = s:exists_in_commit_list(thisfile)
			endif
		endif
	endif
endfunction

function! s:copy_commit_filename() "{{{1
	" Copy the current commit filename to the system clipboard. This might not 
	" be useful or portable.

	call setreg('*', g:committed_filename_base)
	echo "\"".g:committed_filename_base."\" copied to the star register (default clipboard)."
endfunction
" }}}

nmap <silent> <Plug>CommittedAddFile              :call <SID>add_file()<CR>
nmap <silent> <Plug>CommittedShowCommitFile       :call <SID>show_commit_file()<CR>
nmap <silent> <Plug>CommittedSetCommitFileName    :call <SID>set_commit_filename()<CR>
nmap <silent> <Plug>CommittedUnsetCommitFileName  :call <SID>unset_commit_filename()<CR>
nmap <silent> <Plug>CommittedCopyCommitFileName   :call <SID>copy_commit_filename()<CR>

if !exists("g:committed_no_mappings") || ! g:committed_no_mappings
	nmap <unique> <Leader>la <Plug>CommittedAddFile
	nmap <unique> <Leader>ls <Plug>CommittedShowCommitFile
	nmap <unique> <Leader>lg <Plug>CommittedSetCommitFileName
	nmap <unique> <Leader>lu <Plug>CommittedUnsetCommitFileName
	nmap <unique> <Leader>lc <Plug>CommittedCopyCommitFileName
endif

function! s:configure_list_mappings()
	nmap <Enter> :call <SID>open_file()<CR>
	nmap <Esc> :bd!<CR>
endfunction

autocmd BufEnter,BufWinEnter,WinEnter,TabEnter * call s:activate_buffer()

augroup committed_list
	autocmd!
	autocmd BufReadPost *.commit setfiletype committed_list
	autocmd FileType committed_list call s:configure_list_mappings()
augroup END
