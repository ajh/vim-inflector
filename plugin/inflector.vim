if exists('g:loaded_inflector')
  finish
endif
let g:loaded_inflector = 1

" Notes on the interface
"
" I'd like two ways of specifing the text to be inflected: motions and visual
" mode.
"
" One the text is selected, I have choices to invoke the inflector:
"
" A. mapping
" B. command
" C. function
" D. menu
" E. tlib input list
"
" A works great with visual and motions. It can delegate the work to a
" function and pass in an arg specifing which mode we're in so the function
" can know how to find the text. But it has the drawback of having to define
" and remember mappings like '<leader>ih', '<leader>iq' etc. I don't think its
" reasonable to define or remember maps for the 15+ inflectors I'd like to
" support.
"
" B Would be great because I could press ':InflectorHumanize' or whatever,
" get command completion support so remember the names and possible
" inflectors. Sadly there doesn't seem to be a way for this to work with
" visual mode, since pressing ':' exits visual mode into normal mode. (see
" http://vim.1045645.n5.nabble.com/Detecting-Visual-mode-td1145930.html). The
" summary is that its not possible to tell whether the command was invoked
" while in visual mode or not, which means the command can't decide what text
" to act on.
"
" C Same fatal flaw as above, can't detect whether the function was called in
" visual mode.
"
" D is to create a menu which can maybe be sensitive to visual mode. But I
" don't think there's a nice way to invoke the menu item in console mode.
" (:emenu Plugin.Inflector.Humanize seems to be the best way).
"
" E This would have a generic mapping like <leader>i which pops up a tlib
" input list where the user choices the inflector to use.
"
" There's maybe another option where I have a generic mapping like <leader>i
" (i for inflector). Since only the mapping can know the mode, it could
" capture the text to a variable. Then call a function with that text.

" Mappings -------------------- {{{
nnoremap <leader>ii :set operatorfunc=<SID>Inflector<cr>g@
vnoremap <leader>ii :<c-u>call <SID>Inflector(visualmode())<cr>
" }}}

" Functions -------------------- {{{
let s:inflections = [
\  'camelize',
\  'classify',
\  'dasherize',
\  'deconstantize',
\  'demodulize',
\  'foreign_key',
\  'humanize',
\  'parameterize',
\  'pluralize',
\  'singularize',
\  'tableize',
\  'titleize',
\  'underscore',
\]

" Inflect the text selected by a motion or visual mode.
function! s:Inflector(type)
    let saved_unnamed_register = @"
    if a:type ==# 'v'
      normal! `<v`>y
    elseif a:type ==# 'char'
      normal! `[v`]y
    else
      return
    endif

    let input_string = @"
    let @" = saved_unnamed_register " restore register

    let inflector = tlib#input#List('s', 'Select one item', s:inflections)
    let output_string = s:InflectWithRuby(input_string, inflector)

    if input_string ==# output_string
      return
    endif

    if a:type ==# 'v'
      execute "normal! `<v`>c" . output_string
    elseif a:type ==# 'char'
      execute "normal! `[v`]c" . output_string
    endif
endfunction

" Return an inflected version of a:string. a:inflector specifies which
" inflector to use, like 'humanize'.
function! s:InflectWithRuby(string, inflector)
  " detect a string that would break out of the here doc sandboxing
  if a:string =~# '\vVIM_INFLECTOR_END'
    echohl WarningMsg
    echom "Nice try fast guy. Don't use a string with VIM_INFLECTOR_END in the contents."
    echohl None
    return a:string
  endif

  if !exists('s:can_inflect_with_ruby')
    let s:can_inflect_with_ruby = s:CanInflectWithRuby()
  endif

  if s:can_inflect_with_ruby ==# 0
    echohl WarningMsg
    echom "ruby inflector failed. Maybe ruby couldn't be found or couldn't load active_support?"
    echohl None
    return a:string
  endif

  let ruby_program = "puts <<VIM_INFLECTOR_END.chomp." . a:inflector . "\n" . a:string . "\nVIM_INFLECTOR_END"

  let output = system("ruby -ractive_support/core_ext/string", ruby_program)
  let output = tlib#string#Chomp(output)
  return output
endfunction

" Return truth whether ruby can be loaded, and does support our inflections.
function! s:CanInflectWithRuby()
  try
    let tests = []
    for method in s:inflections
      call add(tests, '"".respond_to?(:' . method . ')')
    endfor

    let ruby_program = "puts " . join(tests, " && ")
    let output = system("ruby -ractive_support/core_ext/string", ruby_program)
    let output = tlib#string#Chomp(output)

    return output =~# '\vtrue'

  catch
    return 0
  endtry
endfunction
" }}}
