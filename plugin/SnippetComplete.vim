" SnippetComplete.vim: Insert mode completion that completes defined
" abbreviations. 
"
" DEPENDENCIES:
"
" Copyright: (C) 2010 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   1.00.002	12-Jan-2010	Completed implementation for defined
"				:iabbrev's. 
"	001	08-Jan-2010	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_SnippetComplete') || (v:version < 700)
    finish
endif
let g:loaded_SnippetComplete = 1

let s:abbreviationExpressions = [['fullid', '\k\+'], ['endid', '\%(\k\@!\S\)\+\k\?'], ['nonid', '\S\+\%(\k\@!\S\)\?']]
function! s:DetermineBaseCol()
"*******************************************************************************
"* PURPOSE:
"   Check the text before the cursor to determine possible base columns where
"   abbreviations of the various types may start. 
"* ASSUMPTIONS / PRECONDITIONS:
"   None. 
"* EFFECTS / POSTCONDITIONS:
"   None. 
"* INPUTS:
"   None. 
"* RETURN VALUES: 
"   List of possible base columns, more stringently defined and shorter
"   abbreviation types come first. Each element consists of a [abbreviationType,
"   baseCol] tuple. 
"*******************************************************************************
    " Locate possible start positions of the abbreviation, searching for
    " full-id, end-id and non-id abbreviations. 
    " If the insertion started in the current line, only consider characters
    " that were inserted by the last insertion. For this, we match with the
    " stored start position of the current insert mode, if insertion started in
    " the current line. The matched text must definitely be somewhere after it,
    " but need not start with the start-of-insert position. 
    let l:insertedTextExpr = (line('.') == s:lastInsertStartPosition[1] ? '\%(\%' . s:lastInsertStartPosition[2] . 'c.\)\?\%>' . s:lastInsertStartPosition[2] . 'c.*\%#\&' : '')
    let l:baseColumns = []
    for l:abbreviationExpression in s:abbreviationExpressions
	let l:startCol = searchpos(l:insertedTextExpr . '\%(' . l:abbreviationExpression[1] . '\)\%#', 'bn', line('.'))[1]
	if l:startCol != 0
	    call add(l:baseColumns, [l:abbreviationExpression[0], l:startCol])
	endif
    endfor
    if empty(l:baseColumns)
	call add(l:baseColumns, ['none', col('.')])
    endif
    return l:baseColumns
endfunction

function! s:GetAbbreviations()
    let l:abbreviations = ''
    let l:save_verbose = &verbose
    try
	set verbose=0	" Do not include any "Last set from" info. 
	redir => l:abbreviations
	silent iabbrev
    finally
	redir END
	let &verbose = l:save_verbose
    endtry

    let l:globalMatches = []
    let l:localMatches = []
    try
	for l:abb in split(l:abbreviations, "\n")
	    let [l:lhs, l:flags, l:rhs] = matchlist(l:abb, '^\S\s\+\(\S\+\)\s\+\([* ][@ ]\)\(.*\)$')[1:3]
	    let l:match = { 'word': l:lhs, 'menu': l:rhs }
	    call add((l:flags =~# '@' ? l:localMatches : l:globalMatches), l:match)
	endfor
    catch /^Vim\%((\a\+)\)\=:E688/	" catch error E688: More targets than List items
	" When there are no abbreviations, Vim returns "No abbreviation found". 
    endtry

    " A buffer-local abbreviation overrides an existing global abbreviation with
    " the same {lhs}. 
    for l:localWord in map(copy(l:localMatches), 'v:val.word')
	call filter(l:globalMatches, 'v:val.word !=# ' . string(l:localWord))
    endfor
    return l:globalMatches + l:localMatches
endfunction

function! s:GetBase( baseCol, cursorCol )
    return strpart(getline('.'), a:baseCol - 1, (a:cursorCol - a:baseCol))
endfunction
function! s:MatchAbbreviations( abbreviations, abbreviationFilterExpr, baseCol )
    let l:base = s:GetBase(a:baseCol, col('.'))
"****D echomsg '****' a:baseCol l:base

    let l:filter = 'v:val.word =~#' . string(a:abbreviationFilterExpr)
    if ! empty(l:base)
	let l:filter .= ' && v:val.word =~# ''^\V'' . ' . string(escape(l:base, '\'))
    endif
    return filter(copy(a:abbreviations), l:filter)
endfunction
let s:filterExpr = {
\   'fullid': '^\k\+$',
\   'endid': '^\%(\k\@\!\S\)\+\k$',
\   'nonid': '^\S*\%(\k\@!\S\)$',
\   'none': '^\S\+$'
\}
function! s:GetAbbreviationCompletions()
    let l:baseColumns = s:DetermineBaseCol()
    let l:abbreviations = s:GetAbbreviations()
"****D echomsg '####' string(l:baseColumns)

    let l:completionsByBaseCol = {}
    for [l:abbreviationType, l:baseCol] in l:baseColumns
	let l:matches = s:MatchAbbreviations(l:abbreviations, s:filterExpr[l:abbreviationType], l:baseCol)
"****D echomsg '****' l:abbreviationType string(l:matches)
	if ! empty(l:matches)
	    let l:completions = get(l:completionsByBaseCol, l:baseCol, [])
	    let l:completions += l:matches
	    let l:completionsByBaseCol[l:baseCol] = l:completions
	endif
    endfor
"****D echomsg '****' string(l:completionsByBaseCol)
    return l:completionsByBaseCol
endfunction
function! s:CompletionCompare( c1, c2 )
    return (a:c1.word ==# a:c2.word ? 0 : a:c1.word ># a:c2.word ? 1 : -1)
endfunction

function! s:SetupCmdlineForBaseMessage()
    " The message about multiple bases should appear in the same way as Vim's
    " built-in "match m of n" completion mode messages. Unfortunately, an active
    " 'showmode' setting may prevent the user from seeing the message in a
    " one-line command line. Thus, we temporarily disable the 'showmode'
    " setting. 
    if &showmode && &cmdheight == 1
	set noshowmode

	" Use a single-use autocmd to restore the 'showmode' setting when the
	" cursor is moved (this already happens when a next match is selected,
	" but then the "match m of n" message takes over) or insert mode is
	" left. 
	augroup SnippetCompleteTemporaryNoShowMode
	    autocmd!
	    autocmd CursorMovedI,InsertLeave * set showmode | autocmd! SnippetCompleteTemporaryNoShowMode
	augroup END
    endif
endfunction
function! s:ShowMultipleBasesMessage( nextIdx, baseNum, nextBase )
    call s:SetupCmdlineForBaseMessage()

    echohl ModeMsg
    echo '-- Snippet completion (^X]^N^P) '
    echohl Question
    echon printf('base %d of %d; next: ', a:nextIdx, a:baseNum)
    echohl None
    echon a:nextBase
endfunction
function! s:RecordPosition()
    " The position record consists of the current cursor position, the buffer,
    " window and tab page number and the buffer's current change state. 
    " As soon as you make an edit, move to another buffer or even the same
    " buffer in another tab page or window (or as a minor side effect just close
    " a window above the current), the position changes. 
    return getpos('.') + [bufnr(''), winnr(), tabpagenr()]
endfunction
let s:lastCompletionsByBaseCol = {}
let s:nextBaseIdx = 0
let s:initialCompletePosition = []
let s:lastCompleteEndPosition = []
function! s:SnippetComplete()
"****D echomsg '****' string(s:RecordPosition())
    let l:baseNum = len(keys(s:lastCompletionsByBaseCol))
    if s:initialCompletePosition == s:RecordPosition() && l:baseNum > 1
	" The Snippet complete mapping is being repeatedly executed on the same
	" position, and we have multiple completion bases. Use the next/first
	" base from the cached completions. 
	let l:baseIdx = s:nextBaseIdx
    else
	" This is a new completion. 
	let s:lastCompletionsByBaseCol = s:GetAbbreviationCompletions()

	let l:baseIdx = 0
	let l:baseNum = len(keys(s:lastCompletionsByBaseCol))
	let s:initialCompletePosition = s:RecordPosition()
	let s:initialCompletionCol = col('.')	" Note: The column is also contained in s:initialCompletePosition, but a separate variable is more expressive. 
    endif

    " Multiple bases are presented from shortest base (i.e. largest base column)
    " to longest base. Full-id abbreviations have the most restrictive pattern
    " and thus always generate the shortest bases; end-id and non-id
    " abbreviations accept more character classes and can result in longer
    " bases. 
    let l:baseColumns = reverse(sort(keys(s:lastCompletionsByBaseCol)))

    if l:baseNum > 0
	" Show the completions for the current base. 
	call complete(l:baseColumns[l:baseIdx], sort(s:lastCompletionsByBaseCol[l:baseColumns[l:baseIdx]], 's:CompletionCompare'))
	let s:lastCompleteEndPosition = s:RecordPosition()

	if l:baseNum > 1
	    " There are multiple bases; make subsequent invocations cycle
	    " through them.  
	    let s:nextBaseIdx = (l:baseIdx < l:baseNum - 1 ? l:baseIdx + 1 : 0)

	    " Note: Setting the completions typically inserts the first match
	    " and thus advances the cursor. We need the initial cursor position
	    " to resolve the next base(s) only up to what has actually been
	    " entered. 
	    let l:nextBase = s:GetBase(l:baseColumns[s:nextBaseIdx], s:initialCompletionCol)

	    " Indicate to the user that additional bases exist, and offer a
	    " preview of the next one. 
	    call s:ShowMultipleBasesMessage(l:baseIdx + 1, l:baseNum, l:nextBase)
	endif
    endif

    return ''
endfunction
function! s:PreSnippetCompleteExpr()
    " To be able to detect a repeat completion, we need to return the cursor to
    " the initial completion position, but setting the completions typically
    " inserts the first match and thus advances the cursor. That resulting
    " completion end position (after the completions are shown) is recorded in
    " s:lastCompleteEndPosition. This position can change if the user selects
    " another completion match (via CTRL-N) that has a different length, and
    " only then re-triggers the completion for the next abbreviation base. 
    " We can still handle this situation by checking for an active popup menu;
    " that means that (presumably, could be from another completion type)
    " another abbreviation completion had been triggered. 
    " To return the cursor to the inital completion position, CTRL-E is used to
    " end the completion; this may only not work when 'completeopt' contains
    " "longest" (Vim returns to what was typed or longest common string). 
    let l:baseNum = len(keys(s:lastCompletionsByBaseCol))
    return (pumvisible() || s:lastCompleteEndPosition == s:RecordPosition() && l:baseNum > 1 ? "\<C-e>" : '')
endfunction

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
    autocmd InsertEnter * let s:lastInsertStartPosition = getpos('.')
augroup END

" Triggering a completion typically inserts the first match and thus
" advances the cursor. We need the original cursor position to detect the
" repetition of the completion at the same position, in case the user wants to
" use another completion base. The reset of the cursor position is done in a
" preceding expression mapping, because it is not allowed to change the cursor
" position from within the actual s:SnippetComplete() expression. 
inoremap <silent> <Plug>SnippetComplete <C-r>=<SID>PreSnippetCompleteExpr()<CR><C-r>=<SID>SnippetComplete()<CR>
if ! hasmapto('<Plug>SnippetComplete', 'i')
    imap <C-x>] <Plug>SnippetComplete
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
