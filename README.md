# Commit Tracker
A Vim plugin to track files to commit for use with "monolithic" changeset 
VCSes like Subversion and Mercurial.

What do I mean by "monolithic"? I suppose what I mean is "not git," meaning 
that the VCS itself doesn't have the "staging area" (or "index") functionality 
of git, so if you want to commit selectively you have to list the files on the 
command line or supply them in some explicit manner.

This plugin exposes functions to make it drop-dead simple to add and remove 
files that you are editing to a "commit list," which is a simple text file 
listing their full paths. It will let you know if a file you are editing is 
already in the commit list and remind you which commit list you're working 
with.

There is a Powerline segment available that takes this to the next level, 
compatible with the new Python-based Powerline distribution.

## How does it work?
The plugin exposes mappings, of course, which all begin with `L`, short for 
"list" (as in "the commit list"). Those are:

`<leader>la`
:   Add the current file to the commit list.
`<leader>ls`
:   Show the current commit list.
