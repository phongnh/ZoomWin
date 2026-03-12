" ZoomWin:	Brief-like ability to zoom into/out-of a window
" Author:	Charles Campbell
"			original version by Ron Aaron
" Date:		Mar 09, 2014 
" Version:	25n	ASTRO-ONLY
" History: see :help zoomwin-history {{{1
" GetLatestVimScripts: 508 1 :AutoInstall: ZoomWin.vim

" ---------------------------------------------------------------------
" Load Once: {{{1
if &cp || exists("g:loaded_ZoomWin")
 finish
endif
if v:version < 702
 echohl WarningMsg
 echo "***warning*** this version of ZoomWin needs vim 7.2"
 echohl Normal
 finish
endif
let s:keepcpo        = &cpo
let g:loaded_ZoomWin = "v25n"
if !exists("g:zoomwin_localoptlist")
  if has('nvim')
    let s:localoptlist = ["ai","ar","bh","bin","bl","bomb","bt","cfu","ci","cin","cink","cino","cinw","cms","com","cpt","diff","efm","eol","ep","et","fenc","fex","ff","flp","fo","ft","gp","imi","ims","inde","inex","indk","inf","isk","kmp","lisp","mps","ml","ma","mod","nf","ofu","pi","qe","ro","sw","si","sts","spc","spf","spl","sua","swf","smc","syn","ts","tw","udf","wfh","wfw","wm"]
  else
    let s:localoptlist = ["ai","ar","bh","bin","bl","bomb","bt","cfu","ci","cin","cink","cino","cinw","cms","com","cpt","diff","efm","eol","ep","et","fenc","fex","ff","flp","fo","ft","gp","imi","ims","inde","inex","indk","inf","isk","key","kmp","lisp","mps","ml","ma","mod","nf","ofu","oft","pi","qe","ro","sw","sn","si","sts","spc","spf","spl","sua","swf","smc","syn","ts","tx","tw","udf","wfh","wfw","wm"]
  endif
else
 let s:localoptlist   = g:zoomwin_localoptlist
endif
set cpo&vim
"DechoTabOn

" =====================================================================
"  Functions: {{{1

" ---------------------------------------------------------------------
" ZoomWin#ZoomWin: toggles between a single-window and a multi-window layout {{{2
"          The original version was by Ron Aaron.
fun! ZoomWin#ZoomWin()
"  let g:decho_hide= 1		"Decho
  let l:lzkeep = &lz
  set lz
"  call Dfunc("ZoomWin#ZoomWin() winbufnr(2)=".winbufnr(2))

  " if the vim doesn't have +mksession, only a partial zoom is available {{{3
  if !has("mksession")
   if !exists("s:partialzoom")
    echomsg "missing the +mksession feature; only a partial zoom is available"
	let s:partialzoom= 0
   endif
   if v:version < 630
   	echoerr "***sorry*** you need an updated vim, preferably with +mksession"
   elseif s:partialzoom
   	" partial zoom out
	let s:partialzoom= 0
	exe s:winrestore
   else
   	" partial zoom in
	let s:partialzoom= 1
	let s:winrestore = winrestcmd()
	res
   endif
   let &lz = l:lzkeep
"   call Dret("ZoomWin#ZoomWin : partialzoom=".s:partialzoom)
   return
  endif

  " Close certain windows and save user settings {{{3
  call s:ZoomWinPreserve(0)
  call s:SaveUserSettings()

  if winbufnr(2) == -1
    " there's only one window - restore to multiple-windows mode (zoom out) {{{3
"	call Decho("there's only one window - restore to multiple windows")

    if exists("s:sessionfile") && filereadable(s:sessionfile)
	  " save position in current one-window-only
"	  call Decho("save position in current one-window-only in sponly  (s:sessionfile<".s:sessionfile.">)")
      let l:sponly     = s:SavePosn(0)
      let s:origline = line(".")
      let s:origcol  = virtcol(".")
	  let s:swv      = deepcopy(getwinvar(winnr(),""),1)
	  sil! unlet l:key l:value
	  for [l:key,l:value] in items(s:swv)
	   exe "sil! unlet w:" .. l:key
	   sil! unlet l:key l:value
	  endfor

      " source session file to restore window layout
	  let l:ei_keep = &ei
	  set ei=all noswf bh=hide
	  exe 'sil! so ' .. fnameescape(s:sessionfile)
      let v:this_session= s:sesskeep
	  let l:winrestore = winrestcmd()
	  " restore any and all window variables
	  call s:RestoreWinVars()

      if exists("s:savedposn1")
        " restore windows' positioning and buffers
"		call Decho("restore windows, positions, buffers")
		noautocmd windo call s:RestorePosn(s:savedposn{winnr()})|unlet s:savedposn{winnr()}
        call s:GotoWinNum(s:winkeep)
		execute l:winrestore
        unlet s:winkeep
      endif

	  if exists("s:swv")
	   " restore window variables which possibly were modified while in one-window mode
       for [l:key,l:value] in items(s:swv)
		sil! call setwinvar(winnr(),l:key,l:value)
		sil! unlet l:key l:value
	   endfor
	  endif

	  if line(".") != s:origline || virtcol(".") != s:origcol
	   " If the cursor hasn't moved from the original position,
	   " then let the position remain what it was in the original
	   " multi-window layout.
"	   call Decho("restore position using sponly")
       call s:RestorePosn(l:sponly)
	  endif

	  " delete session file and variable holding its name
"	  call Decho("delete session file<".s:sessionfile.">")
"      call delete(s:sessionfile)
      unlet s:sessionfile
	  let &ei  = l:ei_keep
    endif

	" I don't know why -- but netrw-generated windows end up as [Scratch] even though the bufname is correct.
	" Following code fixes this.  Without the if..[Scratch] test, though, when one attempts to write a file
	" one gets an E13.  Thus, only [Scratch] windows will be affected by this windo command.
	let l:curwin= winnr()
	let l:winrestore = winrestcmd()
	noautocmd windo if bufname(winbufnr(winnr())) == '[Scratch]'|exe "sil! file " .. fnameescape(bufname(winbufnr(winnr())))|endif
	exe l:curwin .. "wincmd w"

	" Restore local window settings
	call s:RestoreWinSettings()
	execute l:winrestore

	" zoomwinstate used by g:ZoomWin_funcref()
	let l:zoomwinstate= 0

   else " there's more than one window - go to only-one-window mode (zoom in){{{3
"	call Decho("there's multiple windows - goto one-window-only")

    let s:winkeep    = winnr()
    let s:sesskeep   = v:this_session

	" doesn't work with the command line window (normal mode q:)
 	if &bt == "nofile" && expand("%") == (v:version < 702 ? 'command-line' : '[Command Line]')
	 echoerr "***error*** ZoomWin#ZoomWin doesn't work with the ".expand("%")." window"
     let &lz= lzkeep
"     call Dret("ZoomWin#ZoomWin : ".expand('%')." window error")
	 return
	endif

	" disable all events (autocmds)
"	call Decho("disable events")
    let l:ei_keep= &ei
	set ei=all
	let l:winrestore = winrestcmd()

	" Save local window settings
	call s:SaveWinSettings()

	" save all window variables
	call s:SaveWinVars()

    " save window positioning commands
"	call Decho("save window positioning commands")
	noautocmd windo let s:savedposn{winnr()}= s:SavePosn(1)
    call s:GotoWinNum(s:winkeep)
	execute l:winrestore

    " set up name of session file
    let s:sessionfile= tempname()
"	call Decho("s:sessionfile<".s:sessionfile.">")

    " save session
"	call Decho("save session")
    let l:ssop_keep = &ssop
	let &ssop     = 'blank,help,winsize,folds,globals,localoptions,options'
	exe 'mksession! ' .. fnameescape(s:sessionfile)
	let l:keepyy= @@
	let l:keepy0= @0
	let l:keepy1= @1
	let l:keepy2= @2
	let l:keepy3= @3
	let l:keepy4= @4
	let l:keepy5= @5
	let l:keepy6= @6
	let l:keepy7= @7
	let l:keepy8= @8
	let l:keepy9= @9
    set lz ei=all bh=
	if v:version >= 700
	 let l:curwin = winnr()

	 try
	  exe "keepalt keepmarks new! " .. fnameescape(s:sessionfile)
	 catch /^Vim\%((\a\+)\)\=:E/
	  let l:seswin = -1
	  windo if winheight(winnr()) > 1 | let l:seswin= winnr() | endif
	  if l:seswin < 0
	   echoerr "Too many windows (not enough room)"
       sil! call delete(s:sessionfile)
       unlet s:sessionfile
       let &lz= l:lzkeep
"       call Dret("ZoomWin#ZoomWin : too many windows")
       return
	  endif
	  exe l:seswin .. "wincmd w"
	  exe "keepalt keepmarks new! " .. fnameescape(s:sessionfile)
	 endtry
	 " modify the session (so that it merely restores window layout)
     sil! keepjumps keepmarks v/wincmd\|split\|resize/d
	 " save modified session
	 " wipe out session window and buffer
	 " restore cursor to the window that was current before editing the session file
     keepalt w!
     keepalt bw!
	 exe l:curwin .. "wincmd w"
	else
	 exe "new! " .. fnameescape(s:sessionfile)
     v/wincmd\|split\|resize/d
     w!
     bw!
    endif
	let @@= l:keepyy
	let @0= l:keepy0
	let @1= l:keepy1
	let @2= l:keepy2
	let @3= l:keepy3
	let @4= l:keepy4
	let @5= l:keepy5
	let @6= l:keepy6
	let @7= l:keepy7
	let @8= l:keepy8
	let @9= l:keepy9
    call histdel('search', -1)
    let @/ = histget('search', -1)

    " restore user's session options and restore event handling
"	call Decho("restore user session options and event handling")
    set nolz
    let &ssop = l:ssop_keep
	let l:curwin= winnr()
    sil! only!
    let &ei   = l:ei_keep
    echomsg expand("%")
	call s:RestoreOneWinSettings(l:curwin)

	" zoomwinstate used by g:ZoomWin_funcref()
	let l:zoomwinstate= 1
  endif

  " restore user option settings {{{3
  call s:RestoreUserSettings()

  " Re-open certain windows {{{3
  call s:ZoomWinPreserve(1)
  
  " call user's optional funcref (callback) functions
  if exists("g:ZoomWin_funcref")
   if type(g:ZoomWin_funcref) == 2
	call g:ZoomWin_funcref(l:zoomwinstate)
   elseif type(g:ZoomWin_funcref) == 3
    for l:Fncref in g:ZoomWin_funcref
     if type(l:Fncref) == 2
	  call l:Fncref(l:zoomwinstate)
     endif
    endfor
   endif
  endif

  let &lz= l:lzkeep
"  call Dret("ZoomWin#ZoomWin")
endfun

" ---------------------------------------------------------------------
" SavePosn: this function sets up a savedposn variable that {{{2
"          has the commands necessary to restore the view
"          of the current window.
fun! s:SavePosn(savewinhoriz)
"  call Dfunc("SavePosn(savewinhoriz=".a:savewinhoriz.") file<".expand("%").">")
  let l:swline = line(".")
  if l:swline == 1 && getline(1) == ""
   " empty buffer
   let l:savedposn= "silent b " .. winbufnr(0)
"   call Dret("SavePosn savedposn<".savedposn.">")
   return l:savedposn
  endif
  let l:swcol = col(".")
  if l:swcol >= col("$")
   let l:swcol= l:swcol + virtcol(".") - virtcol("$")  " adjust for virtual edit (cursor past end-of-line)
  endif
  let l:swwline   = winline()-1
  let l:swwcol    = virtcol(".") - wincol()
"  call Decho("swline #".swline)
"  call Decho("swcol  #".swcol)
"  call Decho("swwline#".swwline)
"  call Decho("swwcol #".swwcol)

  let l:savedposn = "sil! b " .. winbufnr(0)
  let l:savedposn = l:savedposn .. "|" .. l:swline
  let l:savedposn = l:savedposn .. "|sil! norm! 0z\<cr>"
  if l:swwline > 0
   let l:savedposn= l:savedposn .. ":sil! norm! " .. l:swwline .. "\<c-y>\<cr>"
  endif

  if a:savewinhoriz
   if l:swwcol > 0
    let l:savedposn= l:savedposn .. ":sil! norm! 0" .. l:swwcol .. "zl\<cr>"
   endif
   let l:savedposn= l:savedposn .. ":sil! call cursor(" .. l:swline .. "," .. l:swcol .. ")\<cr>"

   " handle certain special settings for the multi-window savedposn call
   "   bufhidden buftype buflisted
   let l:settings= ""
   if &bh != ""
"	call Decho("special handling: changing buf#".bufnr("%")."'s bh=".&bh." to hide")
   	let l:settings="bh=" .. &bh
	setl bh=hide
   endif
   if !&bl
"	call Decho("special handling: changing buf#".bufnr("%")."'s bl=".&bl." to bl")
   	let l:settings= l:settings .. " nobl"
	setl bl
   endif
   if &bt != ""
"	call Decho("special handling: changing buf#".bufnr("%")."'s bt=".&bt.' to ""')
   	let l:settings= l:settings .. " bt=" .. &bt
	setl bt=
   endif
   if l:settings != ""
   	let l:savedposn= l:savedposn .. ":setl " .. l:settings .. "\<cr>"
   endif

  else
   let l:savedposn= l:savedposn .. ":sil! call cursor(" .. l:swline .. "," .. l:swcol .. ")\<cr>"
  endif
"  call Dret("SavePosn savedposn<".savedposn."> : buf#".bufnr("%")." bh=".&bh." bl=".&bl." bt=".&bt)
  return l:savedposn
endfun

" ---------------------------------------------------------------------
" s:RestorePosn: this function restores noname and scratch windows {{{2
fun! s:RestorePosn(savedposn)
"  call Dfunc("RestorePosn(savedposn<".a:savedposn.">) win#".winnr()." scb=".&scb)
  if &scb
   setl noscb
"   try " Decho
    exe a:savedposn
"   catch /^Vim\%((\a\+)\)\=:E/   " Decho
"	call Decho("error occurred") " Decho
"   endtry " Decho
   setl scb
  else
"   try " Decho
    exe a:savedposn
"   catch /^Vim\%((\a\+)\)\=:E/   " Decho
"	call Decho("error occurred") " Decho
"   endtry                        " Decho
  endif
"  call Dret("RestorePosn")
endfun

" ---------------------------------------------------------------------
" CleanupSessionFile: if you exit Vim before cleaning up the {{{2
"                     supposed-to-be temporary session file
fun! ZoomWin#CleanupSessionFile()
"  call Dfunc("ZoomWin#CleanupSessionFile()")
  if exists("s:sessionfile") && filereadable(s:sessionfile)
"   call Decho("sessionfile exists and is readable; deleting it")
   sil! call delete(s:sessionfile)
   unlet s:sessionfile
  endif
"  call Dret("ZoomWin#CleanupSessionFile")
endfun

" ---------------------------------------------------------------------
" GotoWinNum: this function puts cursor into specified window {{{2
fun! s:GotoWinNum(winnum)
"  call Dfunc("GotoWinNum(winnum=".a:winnum.") winnr=".winnr())
  if a:winnum != winnr()
   exe a:winnum."wincmd w"
  endif
"  call Dret("GotoWinNum")
endfun


" ---------------------------------------------------------------------
" ZoomWinPreserve:  This function, largely written by David Fishburn, {{{2
"   allows ZoomWin to "preserve" certain windows:
"
"   	TagList, by Yegappan Lakshmanan
"   	  http://vim.sourceforge.net/scripts/script.php?script_id=273
"
"   	WinManager, by Srinath Avadhanula
"   	  http://vim.sourceforge.net/scripts/script.php?script_id=95
"
"  It does so by closing the associated window upon entry to ZoomWin
"  and re-opening it upon exit by using commands provided by the
"  utilities themselves.
fun! s:ZoomWinPreserve(open)
"  call Dfunc("ZoomWinPreserve(open=".a:open.")")

  if a:open == 0

   " Close Taglist
   if exists('g:zoomwin_preserve_taglist') && exists('g:loaded_taglist')
       " If taglist window is open then close it.
       let s:taglist_winnum = bufwinnr(g:TagList_title)
       if s:taglist_winnum != -1
           " Close the window
           exec "sil! Tlist"
       endif
   endif

   " Close Winmanager
   if exists('g:zoomwin_preserve_winmanager') && exists('g:loaded_winmanager')
       " If the winmanager window is open then close it.
       let s:is_winmgr_vis = IsWinManagerVisible()
       if s:is_winmgr_vis == 1
           exec "WMClose"
       endif
   endif

  else

   " Re-open Taglist
   if exists('g:zoomwin_preserve_taglist') && exists('g:loaded_taglist')
       " If taglist window was open, open it again
       if s:taglist_winnum != -1
           exec "sil! Tlist"
       endif
   endif

   " Re-Open Winmanager
   if exists('g:zoomwin_preserve_winmanager') && exists('g:loaded_winmanager')
       " If the winmanager window is open then close it.
       if s:is_winmgr_vis == 1
           exec "WManager"
       endif
   endif
  endif

"  call Dret("ZoomWinPreserve")
endfun

" ---------------------------------------------------------------------
" s:SaveWinVars: saves a copy of all window-variables into the script variable s:swv_#, {{{2
"                where # is the current window number, for all windows.
fun! s:SaveWinVars()
"  call Dfunc("s:SaveWinVars()")
  noautocmd windo let s:swv_{winnr()}= deepcopy(getwinvar(winnr(),""),1)|let s:swvmatches_{winnr()}= getmatches()
"  call Dret("s:SaveWinVars")
endfun

" ---------------------------------------------------------------------
" s:RestoreWinVars: restores window variables for all windows {{{2
fun! s:RestoreWinVars()
"  call Dfunc("s:RestoreWinVars()")
"  windo call Decho(string(s:swv_{winnr()}))
  noautocmd windo if exists("s:swv_{winnr()}")     |sil! unlet s:key s:value     |for [s:key,s:value] in items(s:swv_{winnr()})|call setwinvar(winnr(),s:key,s:value)|exe "sil! unlet s:key s:value"|endfor|call setmatches(s:swvmatches_{winnr()})|unlet s:swvmatches_{winnr()}|unlet s:swv_{winnr()}|endif
"  call Dret("s:RestoreWinVars")
endfun

" ---------------------------------------------------------------------
" s:SaveUserSettings: save user options, set to zoomwin-safe options.  {{{2
"                     Force window minimum height/width to be >= 1
fun! s:SaveUserSettings()
"  call Dfunc("s:SaveUserSettings()")

  let s:keep_hidden = &hidden
  let s:keep_shm    = &shm
  let s:keep_siso   = &siso
  let s:keep_so     = &so
  let s:keep_ss     = &ss
  let s:keep_wfh    = &wfh
  let s:keep_write  = &write
  if has("clipboard")
"   call Decho("@* save    before: s:keep_star=".@*)
   let s:keep_star   = @*
"   call Decho("@* save    after : s:keep_star=".@*)
  endif
  let s:keep_swf    = &swf

  if v:version < 603
   if &wmh == 0 || &wmw == 0
    let s:keep_wmh = &wmh
    let s:keep_wmw = &wmw
    sil! set wmh=1 wmw=1
   endif
  endif
  set hidden write nowfh so=0 siso=0 ss=0 shm+=A
"  call Dret("s:SaveUserSettings")
endfun

" ---------------------------------------------------------------------
" s:RestoreUserSettings: restore user option settings {{{2
fun! s:RestoreUserSettings()
"  call Dfunc("s:RestoreUserSettings()")
"  call Decho("restore user option settings")
  let &hidden= s:keep_hidden
  let &shm   = s:keep_shm
  let &siso  = s:keep_siso
  let &so    = s:keep_so
  let &ss    = s:keep_ss
  let &wfh   = s:keep_wfh
  let &write = s:keep_write
  if has("clipboard") && exists("s:keep_star")
"   call Decho( "@* restore before: s:keep_star=".@*)
   let @*     = s:keep_star
"   call Decho("@* restore after : s:keep_star=".@*)
  endif
  let &swf   = s:keep_swf
  if v:version < 603
   if exists("s:keep_wmw")
    let &wmh= s:keep_wmh
    let &wmw= s:keep_wmw
   endif
  endif
"  call Dret("s:RestoreUserSettings")
endfun

" ---------------------------------------------------------------------
" s:SaveWinSettings: saves all windows' local settings {{{2
fun! s:SaveWinSettings()
"  call Dfunc("s:SaveWinSettings() curwin#".winnr())
  if exists("s:localoptlist") && !empty(s:localoptlist)
   let l:curwin= winnr()
   for l:localopt in s:localoptlist
    noautocmd windo exe "let s:swv_" .. l:localopt .. "_{winnr()}= &" .. l:localopt
   endfor
   exe "noautocmd " .. l:curwin .. "wincmd w"
  endif
"  call Dret("s:SaveWinSettings : &bt=".&bt." s:swv_bt_".curwin."=".s:swv_bt_{curwin})
endfun

" ---------------------------------------------------------------------
" s:RestoreWinSettings: restores all windows' local settings {{{2
fun! s:RestoreWinSettings()
"  call Dfunc("s:RestoreWinSettings() bh=".&bh." bt=".&bt." bl=".&bl)
  if exists("s:localoptlist") && !empty(s:localoptlist)
   let l:curwin= winnr()
   for l:localopt in s:localoptlist
    exe 'noautocmd windo if exists("s:swv_' .. l:localopt .. '_{winnr()}")|if &' .. l:localopt .. '!=# s:swv_' .. l:localopt .. '_{winnr()}|let &' .. l:localopt .. '= s:swv_' .. l:localopt .. '_{winnr()}|endif|unlet s:swv_' .. l:localopt .. '_{winnr()}|endif'
   endfor
   exe "noautocmd " .. l:curwin .. "wincmd w"
  endif
"  call Dret("s:RestoreWinSettings : bh=".&bh." bt=".&bt." bl=".&bl)
endfun

" ---------------------------------------------------------------------
" s:RestoreOneWinSettings: assumes that s:SaveWinSettings() was called previously; this function restores the specified window's local settings {{{2
fun! s:RestoreOneWinSettings(wnum)
"  call Dfunc("s:RestoreOneWinSettings(wnum=".a:wnum.") s:swv_bt_".a:wnum."=".s:swv_bt_{a:wnum}." bh=".&bh." bt=".&bt." bl=".&bl)
  if exists("s:localoptlist") && !empty(s:localoptlist)
   for l:localopt in s:localoptlist
"    call Decho('windo if exists("s:swv_'.localopt.'_{a:wnum}")|let &'.localopt.'= s:swv_'.localopt.'_{a:wnum}|unlet s:swv_'.localopt.'_{a:wnum}|endif')
    exe 'noautocmd windo if exists("s:swv_' .. l:localopt .. '_{a:wnum}")|if &' .. l:localopt .. '!=# s:swv_' .. l:localopt .. '_{a:wnum}|let &' .. l:localopt .. '= s:swv_' .. l:localopt .. '_{a:wnum}|endif|unlet s:swv_' .. l:localopt .. '_{a:wnum}|endif'
   endfor
  endif
"  call Dret("s:RestoreOneWinSettings : bh=".&bh." bt=".&bt." bl=".&bl)
endfun

" =====================================================================
"  Restore: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo

" ---------------------------------------------------------------------
"  Modelines: {{{1
" vim: ts=4 fdm=marker
