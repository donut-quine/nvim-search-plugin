local api = vim.api
local buf, win

local function center(str)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end

local function open_window()
  buf = api.nvim_create_buf(false, true)
  local border_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'filetype', 'sp')

  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local border_opts = {
    style = "minimal",
    relative = "editor",
    width = win_width + 2,
    height = win_height + 2,
    row = row - 1,
    col = col - 1
  }

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col
  }

  local border_lines = { '╔' .. string.rep('═', win_width) .. '╗' }
  local middle_line = '║' .. string.rep(' ', win_width) .. '║'
  for i=1, win_height do
    table.insert(border_lines, middle_line)
  end
  table.insert(border_lines, '╚' .. string.rep('═', win_width) .. '╝')
  api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

  local border_win = api.nvim_open_win(border_buf, true, border_opts)
  win = api.nvim_open_win(buf, true, opts)
  api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)

  api.nvim_win_set_option(win, 'cursorline', true)

  api.nvim_buf_set_lines(buf, 0, -1, false, { center('Search Plugin window'), '', ''})
  api.nvim_buf_add_highlight(buf, -1, 'SearchPluginHeader', 0, 0, -1)
end

local function get_search_results(pattern)
  local results = {}
  local save_cursor = vim.fn.getpos('.')
  
  -- Перейти в начало файла
  vim.cmd('normal! gg')

  local last_pos = {0, 0} -- Хранение предыдущей позиции
  while true do
    local pos = vim.fn.searchpos(pattern, 'Wn')
    if pos[1] == 0 and pos[2] == 0 then
      break
    end

    table.insert(results, {
      line = pos[1],
      col = pos[2],
      text = vim.fn.getline(pos[1])
    })

    -- Переместиться за текущее совпадение
    vim.fn.cursor(pos[1], pos[2] + 1)
  end

  -- Вернуть курсор на исходное место
  vim.fn.setpos('.', save_cursor)
  return results
end

local function update_view(pattern, search_results)
  api.nvim_buf_set_option(buf, 'modifiable', true)

  local result_lines = {}
  for _, res in ipairs(search_results) do
    table.insert(result_lines, string.format('%d:%d %s', res.line, res.col, res.text))
  end

  if #result_lines == 0 then
    table.insert(result_lines, 'No results found')
  end

  api.nvim_buf_set_lines(buf, 1, 2, false, {center('Search pattern: '..pattern)})
  api.nvim_buf_set_lines(buf, 3, -1, false, result_lines)

  api.nvim_buf_add_highlight(buf, -1, 'spSubHeader', 1, 0, -1)
  api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function close_window()
  api.nvim_win_close(win, true)
end

local function open_file()
  local line = api.nvim_get_current_line()
  local pattern_pos = vim.split(line, ' ')[1];
  local parts = vim.split(pattern_pos, ':')
  local target_line = tonumber(parts[1])
  local target_col = tonumber(parts[2])

  close_window()
  vim.fn.cursor(target_line, target_col)
end

local function move_cursor()
  local new_pos = math.max(4, api.nvim_win_get_cursor(win)[1] - 1)
  api.nvim_win_set_cursor(win, {new_pos, 0})
end

local function set_mappings()
  local mappings = {
    -- ['['] = 'update_view(-1, pattern, search_results)',
    -- [']'] = 'update_view(1, pattern, search_results)',
    ['<cr>'] = 'open_file()',
    -- h = 'update_view(-1, pattern, search_results)',
    -- l = 'update_view(1, pattern, search_results)',
    q = 'close_window()',
    k = 'move_cursor()'
  }

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"search-plugin".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
  local other_chars = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
  }
  for k,v in ipairs(other_chars) do
    api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
  end
end

local function search(pattern)
  local search_results = get_search_results(pattern)
  open_window()
  set_mappings()
  update_view(pattern, search_results)
  api.nvim_win_set_cursor(win, {4, 0})
end

local function register()
  api.nvim_create_user_command(
    'Search', -- имя команды
    function(opts)
      local pattern = opts.args
      require('search-plugin').search(pattern)
    end,
    { nargs = 1 } -- команда принимает один аргумент (шаблон)
  )
end

return {
  search = search,
  update_view = update_view,
  open_file = open_file,
  move_cursor = move_cursor,
  close_window = close_window,
  register = register
}

