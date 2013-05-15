# vim:fileencoding=utf-8:noet

from __future__ import absolute_import
from powerline.bindings.vim import getbufvar
from powerline.theme import requires_segment_info

try:
	import vim
except ImportError:
	vim = {}

@requires_segment_info
def commit_status(pl, segment_info):
	if str(vim.eval('exists("g:BCFCommitFileName")')) == '1':
		bcf_filename = vim.eval('g:BCFCommitFileName')

		if len(bcf_filename):
			bcf_list_contains_this_buffer = getbufvar(segment_info['bufnr'], 'BCFListContainsThisBuffer')
			if bcf_list_contains_this_buffer is not None:
				included_in_cl = int(bcf_list_contains_this_buffer)
				if included_in_cl == 1:
					bcf_status_symbol = "✔"
				else:
					bcf_status_symbol = "✘"

				bcf_status_string = bcf_status_symbol + ' ' + bcf_filename
				if len(bcf_status_string) > 40:
					bcf_status_string = bcf_status_string[:19] + '→'

				return [{ 'contents': bcf_status_string, 'highlight_group': [ 'background' ] }]

	return None
