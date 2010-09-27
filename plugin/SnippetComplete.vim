" SnippetComplete.vim: Insert mode completion that completes defined
" abbreviations. 
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - SnippetComplete.vim autoload script. 
"
" Copyright: (C) 2010 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   1.01.003	25-Sep-2010	Moved functions from plugin to separate autoload
"				script. 
"   1.00.002	12-Jan-2010	Completed implementation for defined
"				:iabbrev's. 
"	001	08-Jan-2010	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_SnippetComplete') || (v:version < 700)
    finish
endif
let g:loaded_SnippetComplete = 1

" In order to determine the base column of the completion, we need the start
" position of the current insertion. Mark '[ isn't set until we (at least
" temporarily via i_CTRL-O) move out of insert mode; however doing so then
" prevents the completed abbreviation from being expanded: The insertion was
" interrupted, and Vim doesn't consider the full expanded abbreviation to have
" been inserted in the current insert mode. 
" To work around this, we use an autocmd to capture the cursor position whenever
" insert mode is entered. 
augroup SnippetComplete
    autocmd!
    autocmd InsertEnter * let g:SnippetComplete_LastInsertStartPosition = getpos('.')
augroup END

" Triggering a completion typically inserts the first match and thus
" advances the cursor. We need the original cursor position to detect the
" repetition of the completion at the same position, in case the user wants to
" use another completion base. The reset of the cursor position is done in a
" preceding expression mapping, because it is not allowed to change the cursor
" position from within the actual SnippetComplete#SnippetComplete() expression. 
inoremap <silent> <Plug>SnippetComplete <C-r>=SnippetComplete#PreSnippetCompleteExpr()<CR><C-r>=SnippetComplete#SnippetComplete()<CR>
if ! hasmapto('<Plug>SnippetComplete', 'i')
    imap <C-x>] <Plug>SnippetComplete
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
