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

" Function: BCFSetCommitFileName()
" Ask the user to enter a filename for this commit file and see if it exists
" on disk. If not, set it.
function! s:set_commit_filename(...)
	let nochange = (a:0 > 0 && a:1 =~ "nochange") ? 1 : 0

	let path = s:get_option("committed_file_path", "~/commits/")
	let filename = input("Enter a name for your commit file: ")
	echo "\n"
	if(len(filename) && filereadable(path.filename.".commit"))
		" File already exists!
		if !nochange
			echohl WarningMsg|echomsg "This file already exists!"|echohl None
			echo "  y - Yes use this file, empty it first."
			echo "  a - Yes use this file, append to the existing list."
			echo "  n - No, don't use this file."
			let ans = input("Use it anyway? [y/a/N]: ")
			echo "\n"
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
function! s:unset_commit_filename()
	unlet g:committed_filename_base
	unlet g:committed_filename
endfunction

" Function: s:path_format(path)
" Format a path returned by expand() into the format we want in our commit
" file. The user might want to customize this behavior. I don't know how to do
" that elegantly.
function! s:path_format(path)
	let thefile = a:path
	let thefile = substitute(thefile, "\\", "/", "g")
	let thefile = substitute(thefile, "J:", "/cygdrive/j", "")
	return thefile
endfunction

" Function: s:path_un_format(path)
" Reverse path formatting from posix back to Windows to be able to do Windows
" things with it.
function! s:path_un_format(path)
	let thefile = a:path
	let thefile = substitute(thefile, "/cygdrive/j", "J:", "")
	let thefile = substitute(thefile, "/", "\\", "g")
	return thefile
endfunction

" Function: s:add_file()
" Add a file to the commit file list.
function! s:add_file()
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

function! s:exists_in_commit_list(filename)
	let path = s:get_option("committed_file_path", "~/commits/")
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

" Function: BCFShowCommitFile()
" Open the current commit file (if there is one) in a new buffer, splitting
" below by default.
function! s:show_commit_file()
	if(exists("g:committed_filename"))
		let path = s:get_option("committed_file_path", "~/commits/")
		exec "bot split ".path.g:committed_filename
		let &filetype = "BCFCommitFile"
	else
		echohl WarningMsg|echo "There is no commit file set up in this Vim instance."|echohl None
	endif
endfunction

" Function: s:open_file()
" Split the window and open the filename under the cursor in the commit file.
" I really should have a 'commit' file type, but I haven't gotten to that yet.
function! s:open_file()
	let filename = expand("<cfile>")
	echo filename
	if(len(filename))
		let filename = s:path_un_format(filename)
		echo filename
		if(filereadable(filename))
			exec "split ".filename
		endif
	endif
endfunction

" Function: s:get_option(name, default)
" Grab a user-specified option to override the default provided.  Options are
" searched in the window, buffer, then global spaces.
function! s:get_option(name, default)
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

function! committed#status_line_filename()
	if exists("g:committed_filename_base")
		return g:committed_filename_base
	else
		return ""
	endif
endfunction

function! committed#status_line_symbol()
	if(exists("g:committed_filename_base"))
		if(exists("b:committed_list_contains_this_buffer") && b:committed_list_contains_this_buffer)
			return "✔"
		else
			return "✘"
		endif
	endif

	return ""
endfunction

function! s:activate_buffer()
	if(exists("g:committed_filename") && len(g:committed_filename))
		if(len(expand("%:p")))
			let thisfile = s:path_format(expand("%:p"))
			if(len(thisfile))
				let b:committed_list_contains_this_buffer = s:exists_in_commit_list(thisfile)
			endif
		endif
	endif
endfunction

function! s:copy_commit_filename()
	call setreg('*', g:committed_filename_base)
	echo "\"".g:committed_filename_base."\" copied to the star register (default clipboard)."
endfunction

" There is definitely a better way to do this, so let's not for now.
"function! s:BCFAddAllFiles()
"	silent! bufdo! <Leader>la
"endfunction

"nnoremap <silent> <Plug>CommittedAddAllFiles          :<SID>committed#add_all_files()<CR>
nnoremap <silent> <Plug>CommittedAddFile              :call <SID>add_file()<CR>
nnoremap <silent> <Plug>CommittedShowCommitFile       :call <SID>show_commit_file()<CR>
nnoremap <silent> <Plug>CommittedOpenFile             :call <SID>open_file()<CR>
nnoremap <silent> <Plug>CommittedSetCommitFileName    :call <SID>set_commit_filename()<CR>
nnoremap <silent> <Plug>CommittedUnsetCommitFileName  :call <SID>unset_commit_filename()<CR>
nnoremap <silent> <Plug>CommittedCopyCommitFileName   :call <SID>copy_commit_filename()<CR>

if !exists("g:committed_no_mappings") || ! g:committed_no_mappings
	"nmap <unique> <Leader>lA <Plug>CommittedAddFile
	nmap <unique> <Leader>la <Plug>CommittedAddFile
	nmap <unique> <Leader>ls <Plug>CommittedShowCommitFile
	nmap <unique> <Leader>lo <Plug>CommittedOpenFile
	nmap <unique> <Leader>lg <Plug>CommittedSetCommitFileName
	nmap <unique> <Leader>lu <Plug>CommittedUnsetCommitFileName
	nmap <unique> <Leader>lc <Plug>CommittedCopyCommitFileName
endif

autocmd BufEnter,BufWinEnter,WinEnter,TabEnter * call s:activate_buffer()
