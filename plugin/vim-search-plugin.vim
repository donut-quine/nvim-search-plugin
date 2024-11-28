" Got from here: https://dev.to/2nit/how-to-write-neovim-plugins-in-lua-5cca
if exists('g:loaded_search_plugin') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

lua require'search-plugin'.register()

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_search_plugin = 1

