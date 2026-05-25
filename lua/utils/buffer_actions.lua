local M = {}

---@type number[]  the order of buffers (listed, valid)
local buffer_order = {}

---@return string|nil  session file path, or nil if the session file does not exist
local function get_session_file()
  local sep = vim.fn.has("win32") == 1 and "\\" or "/"
  local session_dir = vim.fn.stdpath("state") .. sep .. "sessions"
  local fname = vim.fn.substitute(vim.fn.getcwd(), "[/\\\\:]", "%%", "g") .. ".vim"
  local path = session_dir .. sep .. fname
  if vim.fn.filereadable(path) == 1 then
    return path
  else
    return nil
  end
end

---@param bufnr number
---@return string|nil
local function buf_to_name(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end
  return vim.fn.fnamemodify(name, ":p")
end

local function save_buffer_order()
  local names = {}
  for _, bufnr in ipairs(buffer_order) do
    local name = buf_to_name(bufnr)
    table.insert(names, name)
  end
  vim.g.BufferOrder = vim.json.encode(names)
end

---@param buf number
local function add_buffer_to_buffer_order(bufnr)
  if vim.fn.buflisted(bufnr) == 0 then
    return
  end
  for _, b in ipairs(buffer_order) do
    if b == bufnr then
      return
    end
  end
  buffer_order[#buffer_order + 1] = bufnr

  vim.api.nvim_exec_autocmds("User", { pattern = "BufferOrderChanged", modeline = false })
  save_buffer_order()
end

---@param buf number
local function remove_buffer_from_buffer_order(bufnr)
  for i, b in ipairs(buffer_order) do
    if b == bufnr then
      table.remove(buffer_order, i)

      vim.api.nvim_exec_autocmds("User", { pattern = "BufferOrderChanged", modeline = false })
      save_buffer_order()
      return
    end
  end
end

---@param buf number
local function close_buffer(buf)
  local ok_snacks, snacks_bufdelete = pcall(Snacks, "bufdelete")
  if ok_snacks then
    snacks_bufdelete(buf)
  else
    pcall(vim.api.nvim_buf_delete, buf, { force = false })
  end
end

local function init()
  local raw = vim.g.BufferOrder
  if not raw then
    -- 1. generate buffer_order by session file
    local session_file = get_session_file()
    if session_file then
      for line in io.lines(session_file) do
        if line:match("^badd") then
          local name = vim.fn.fnamemodify(vim.fn.expand(line:match("%S+$")), ":p")
          local bufnr = vim.fn.bufnr(name)
          table.insert(buffer_order, bufnr)
        end
      end
    end
  else
    -- 2. generate buffer order by g:BufferOrder
    local names = vim.json.decode(raw)
    for _, name in ipairs(names) do
      local bufnr = vim.fn.bufnr(name)
      table.insert(buffer_order, bufnr)
    end
  end
end

---@param direction number  1: right, -1: left
function M.move(direction)
  local current_bufnr = vim.api.nvim_get_current_buf()
  local index
  for i, bufnr in ipairs(buffer_order) do
    if bufnr == current_bufnr then
      index = i
      break
    end
  end
  if not index then
    return
  end

  local next_index = index + direction
  if next_index < 1 or next_index > #buffer_order then
    return
  else
    buffer_order[index], buffer_order[next_index] = buffer_order[next_index], buffer_order[index]
  end

  vim.api.nvim_exec_autocmds("User", { pattern = "BufferOrderChanged", modeline = false })
  save_buffer_order()
end

---@param direction number  1: right, -1: left
function M.cycle(direction)
  local current_buf = vim.api.nvim_get_current_buf()
  local index
  for i, buf in ipairs(buffer_order) do
    if buf == current_buf then
      index = i
      break
    end
  end
  local next_index = index + direction
  if next_index < 1 then
    vim.cmd("buffer " .. buffer_order[#buffer_order])
  elseif next_index > #buffer_order then
    vim.cmd("buffer " .. buffer_order[1])
  else
    vim.cmd("buffer " .. buffer_order[next_index])
  end
end

---@alias Direction "'left'" | "'right'"
---@param direction Direction
function M.close_in_direction(direction)
  local current_buf = vim.api.nvim_get_current_buf()

  local index
  for i, buf in ipairs(buffer_order) do
    if buf == current_buf then
      index = i
      break
    end
  end
  if not index then
    return
  end

  local to_close = {}
  if direction == "left" then
    for i = 1, index - 1 do
      to_close[#to_close + 1] = buffer_order[i]
    end
  else
    for i = index + 1, #buffer_order do
      to_close[#to_close + 1] = buffer_order[i]
    end
  end

  for _, buf in ipairs(to_close) do
    close_buffer(buf)
  end
end

function M.get_buffer_order()
  return buffer_order
end

local augroup = vim.api.nvim_create_augroup("AddOrRemoveBufferOrder", { clear = true })
vim.api.nvim_create_autocmd("BufAdd", {
  group = augroup,
  callback = function(args)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) and vim.fn.buflisted(args.buf) == 1 then
        add_buffer_to_buffer_order(args.buf)
      end
    end)
  end,
})
vim.api.nvim_create_autocmd("BufDelete", {
  group = augroup,
  callback = function(args)
    remove_buffer_from_buffer_order(args.buf)
  end,
})
vim.api.nvim_create_autocmd("SessionLoadPost", {
  group = augroup,
  callback = function()
    save_buffer_order()
  end,
})

init()

return M
