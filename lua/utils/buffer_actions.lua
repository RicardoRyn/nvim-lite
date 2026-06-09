local M = {}

---@type number[]
local buffer_order = {}

local special_mode = require("utils.special_mode")
if special_mode.is_active() then
  M.get_buffer_order = function()
    return {}
  end
  M.cycle = function() end
  M.move = function() end
  M.close_in_direction = function() end
  M.pick_close = function() end
  M.is_picking = false
  M.pick_labels = {}
  return M
end

local PICK_ALPHABET = "asdfghjklqwertyuiopzxcvbnm1234567890"

M.pick_labels = {}

M.is_picking = false

---@return string|nil
local function get_session_file()
  local session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sessions")
  local fname = vim.fn.substitute(vim.fn.getcwd(), "[/\\\\:]", "%%", "g") .. ".vim"
  local path = vim.fs.joinpath(session_dir, fname)

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

---@param bufnr number
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

---@param bufnr number
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

local function assign_pick_letters()
  M.pick_labels = {}
  local used = {}

  for _, bufnr in ipairs(buffer_order) do
    local name = buf_to_name(bufnr)
    local filename = name ~= "" and vim.fn.fnamemodify(name, ":t") or ""
    local first_char = filename:sub(1, 1):lower()

    local label = nil

    if first_char ~= "" and not used[first_char] and PICK_ALPHABET:find(first_char, 1, true) then
      -- if the first char is not uesd and belong to PICK_ALPHABET
      label = first_char
    else
      -- if not, find the first unused char in PICK_ALPHABET
      for c in PICK_ALPHABET:gmatch(".") do
        if not used[c] then
          label = c
          break
        end
      end
    end

    if label then
      M.pick_labels[bufnr] = label
      used[label] = true
    end
  end
end

---@param bufnr number
local function close_buffer(bufnr)
  local ok_snacks, snacks_bufdelete = pcall(Snacks, "bufdelete")
  if ok_snacks then
    snacks_bufdelete(bufnr)
  else
    pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
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

---Move the buffer to the left or right in the buffer order.
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

---Cycle to the next/prev buffer in the given direction.
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

---Close all buffers to the left or right of the current buffer in the buffer order.
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

---Pick a buffer to close.
function M.pick_close()
  if M.is_picking then
    return
  end

  assign_pick_letters()
  M.is_picking = true
  vim.api.nvim_exec_autocmds("User", { pattern = "BufferOrderChanged", modeline = false })

  -- wait for user to input char
  local ok, char_ascii = pcall(vim.fn.getchar)

  if ok and char_ascii then
    local input_char = vim.fn.nr2char(char_ascii):lower()
    for bufnr, label in pairs(M.pick_labels) do
      if label == input_char then
        close_buffer(bufnr)
        break
      end
    end
  end

  M.is_picking = false
  M.pick_labels = {}
  vim.api.nvim_exec_autocmds("User", { pattern = "BufferOrderChanged", modeline = false })
end

---Get the current buffer order.
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
