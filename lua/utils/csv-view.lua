local M = {}

-----------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------
local NS = vim.api.nvim_create_namespace("csvview")
local DEFAULT_DELIMITERS = { ",", "\t", ";", "|", ":" }
local DEFAULT_QUOTE_CHAR = '"'

-----------------------------------------------------------------------------
-- User config
-----------------------------------------------------------------------------
local config = {
  border_char = "│",
  left_spacing = 0, -- spaces between delimiter and field (left side)
  right_spacing = 0, -- spaces between field and delimiter (right side)
}

-----------------------------------------------------------------------------
-- State per buffer
-----------------------------------------------------------------------------
---@type table<integer, table>
local buffer_states = {}

-----------------------------------------------------------------------------
-- Highlight groups
-----------------------------------------------------------------------------
local function define_highlights()
  for i = 0, 9 do
    vim.api.nvim_set_hl(0, "CsvViewCol" .. i, { link = "csvCol" .. i })
  end

  vim.api.nvim_set_hl(0, "CsvViewDelimiter", { link = "Comment" })
  vim.api.nvim_set_hl(0, "CsvViewHeaderLine", { bold = true, underline = true, default = true })
end

-----------------------------------------------------------------------------
-- Utility functions
-----------------------------------------------------------------------------
local function is_number_str(str)
  local trimmed = str:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return false
  end
  return tonumber(trimmed) ~= nil
end

---@return string
local function buf_get_line(bufnr, lnum)
  local count = vim.api.nvim_buf_line_count(bufnr)
  if lnum < 1 or lnum > count then
    return nil
  end
  return vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
end

-----------------------------------------------------------------------------
-- Delimiter detection
-----------------------------------------------------------------------------
---@return integer
local function count_fields_in_line(line, delim, quote_byte)
  local count = 0
  local in_quote = false
  local len = #line
  local delim_byte = delim:byte()
  if len == 0 then
    return 0
  end
  for i = 1, len do
    local b = line:byte(i)
    if b == quote_byte then
      in_quote = not in_quote
    elseif not in_quote and b == delim_byte then
      count = count + 1
    end
  end
  -- +1 for count of fields = delimiters + 1
  return count + 1
end

--- Infer the delimiter by sampling the first few lines and scoring candidate delimiters.
--- More fields score higer, but we alse punish when more inconsistent field counts.
local function detect_delimiter(bufnr, quote_char)
  local n_samples = 10
  local total = vim.api.nvim_buf_line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(n_samples, total), true)
  if #lines == 0 then
    return ","
  end

  local quote_byte = quote_char:byte()
  local best_delim, best_score = ",", -1

  for _, delim in ipairs(DEFAULT_DELIMITERS) do
    local min_c, max_c = math.huge, 0
    local valid = 0
    for _, line in ipairs(lines) do
      if #line > 0 then
        local n = count_fields_in_line(line, delim, quote_byte)
        valid = valid + 1
        if n < min_c then
          min_c = n
        end
        if n > max_c then
          max_c = n
        end
      end
    end
    if valid > 0 and min_c >= 2 then
      -- bonus for more files
      -- penalty for inconsistent fields counts
      local score = min_c * 10 - (max_c - min_c)
      if score > best_score then
        best_score = score
        best_delim = delim
      end
    end
  end

  return best_delim
end

-----------------------------------------------------------------------------
-- Parser
--
-- Design: each physical line is parsed INDEPENDENTLY.
-- Multi-line quoted fields are detected (unclosed quote) so we know which
-- lines are "continuation" lines. But each line's fields are stored with
-- offsets relative to that line's own text.
--
-- For rendering:
--   - First lines (including multi-line starts): render all their fields normally
--   - Continuation lines: only get left-padding (no field rendering)
--   - Column widths: computed from first lines only (continuation lines have
--     different column indices)
-----------------------------------------------------------------------------
--- Find the closing quote position in a line, starting from start_pos.
--- Returns nil if no closing quote found (field continues to next line).
---@return integer|nil
local function find_closing_quote(line, start_pos, quote_byte)
  local len = #line
  local pos = start_pos
  while pos <= len do
    if line:byte(pos) == quote_byte then
      if pos + 1 <= len and line:byte(pos + 1) == quote_byte then
        pos = pos + 2 -- escaped quote ""
      else
        return pos -- closing quote
      end
    else
      pos = pos + 1
    end
  end
  return nil
end

---@class CsvField
---@field offset integer       0-based byte offset in the line
---@field len integer          byte length in the line
---@field text string          raw field text from the line
---@field display_width integer
---@field is_number boolean

--- Parse a single physical line into fields.
--- Each field has offset/len relative to THIS line.
--- Also returns has_unclosed_quote to detect multi-line records.
local function parse_line(line, delim, quote_char, continuation)
  if not line or #line == 0 then
    return {}, false
  end

  local delim_byte = delim:byte()
  local quote_byte = quote_char:byte()

  local fields = {} ---@type CsvField[]
  local pos = 1
  local field_start = 1
  local len = #line
  local has_unclosed_quote = false

  -- For continuation lines: find the closing quote and skip past it
  if continuation then
    local close_pos = find_closing_quote(line, 1, quote_byte)
    if close_pos then
      -- Advance past the closing quote; let the main loop find the delimiter
      pos = close_pos + 1
    else
      -- No closing quote on this line — entire line continues the multi-line field
      has_unclosed_quote = true
      local text = line:sub(field_start)
      local field = { offset = field_start - 1, len = len, text = text }
      field.display_width = vim.fn.strdisplaywidth(field.text)
      field.is_number = is_number_str(field.text)
      table.insert(fields, field)
      return fields, has_unclosed_quote
    end
  end

  -- scan the line byte by byte to find delimiters and quotes
  while pos <= len do
    local b = line:byte(pos)

    if b == quote_byte then
      -- Quoted field: search for closing quote on THIS line only
      local close_pos = find_closing_quote(line, pos + 1, quote_byte)
      if close_pos then
        pos = close_pos + 1
        -- Continue scanning (might hit delimiter next)
      else
        -- No closing quote on this line — this is a multi-line start
        has_unclosed_quote = true
        break -- stop parsing this line
      end
    elseif b == delim_byte then
      local text = line:sub(field_start, pos - 1)
      table.insert(fields, { offset = field_start - 1, len = pos - field_start, text = text })
      pos = pos + 1
      field_start = pos
    else
      pos = pos + 1
    end
  end

  local text = line:sub(field_start)
  table.insert(fields, { offset = field_start - 1, len = #line - field_start + 1, text = text })

  -- compute display_width, is_number for each field
  for _, f in ipairs(fields) do
    f.display_width = vim.fn.strdisplaywidth(f.text)
    f.is_number = is_number_str(f.text)
  end

  return fields, has_unclosed_quote
end

--- Detect the end of a multi-line record starting at start_lnum.
--- Returns the line number where the multi-line record ends.
local function find_multiline_end(bufnr, start_lnum, quote_char)
  local quote_byte = quote_char:byte()
  local total = vim.api.nvim_buf_line_count(bufnr)
  -- No stupid csv file should have a multi-line field that long without a closing quote, right?
  local max_lookahead = 50
  local lnum = start_lnum + 1

  while lnum <= total and lnum <= start_lnum + max_lookahead do
    local line = buf_get_line(bufnr, lnum)
    if not line then
      return lnum
    end

    -- Search for the closing quote on this line
    local close = find_closing_quote(line, 1, quote_byte)
    if close then
      return lnum -- this line contains the closing quote
    end
    lnum = lnum + 1
  end

  return lnum - 1 -- hit lookahead limit
end

--- Parse all lines, detect multi-line records, and compute column widths for alignment.
local function compute_metrics(bufnr, delim, quote_char)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local rows = {} ---@type table<integer, { fields: CsvField[], continuation: boolean, parent_lnum: integer?, skipped_ncol: integer? }>
  local column_widths = {} ---@type table<integer, integer>

  local lnum = 1
  while lnum <= total_lines do
    local line = buf_get_line(bufnr, lnum)
    if not line then
      lnum = lnum + 1
      goto continue
    end

    local fields, has_unclosed_quote = parse_line(line, delim, quote_char, false)
    rows[lnum] = { fields = fields, continuation = false }

    if not has_unclosed_quote then
      -- Normal single-line record: all fields count toward column widths
      for col_idx, f in ipairs(fields) do
        if not column_widths[col_idx] or f.display_width > column_widths[col_idx] then
          column_widths[col_idx] = f.display_width
        end
      end
      lnum = lnum + 1
    else
      -- Multi-line record: first line's fields count toward column widths
      for col_idx, f in ipairs(fields) do
        if not column_widths[col_idx] or f.display_width > column_widths[col_idx] then
          column_widths[col_idx] = f.display_width
        end
      end

      -- Find where the multi-line record ends
      local end_lnum = find_multiline_end(bufnr, lnum, quote_char)

      -- Mark continuation lines
      local parent_col = #fields -- the multi-line field is the last column of the parent line
      local skipped = #fields - 1
      for cl = lnum + 1, end_lnum do
        local cline = buf_get_line(bufnr, cl)
        local cfields = {}
        if cline then
          cfields, _ = parse_line(cline, delim, quote_char, true)
        end
        rows[cl] = {
          fields = cfields,
          continuation = true,
          parent_lnum = lnum,
          skipped_ncol = skipped,
        }
        -- All fields of a continuation line contribute to column widths.
        -- The first field continues the multi-line field (parent_col),
        -- subsequent fields start new columns after it.
        for fidx, cf in ipairs(cfields) do
          local col = parent_col + fidx - 1
          if not column_widths[col] or cf.display_width > column_widths[col] then
            column_widths[col] = cf.display_width
          end
        end
        skipped = skipped + math.max(0, #cfields - 1)
      end

      lnum = end_lnum + 1
    end

    ::continue::
  end

  return {
    rows = rows,
    column_widths = column_widths,
  }
end

-----------------------------------------------------------------------------
-- Renderer
-----------------------------------------------------------------------------
local function add_extmark(state, bufnr, line, col, opts)
  local id = vim.api.nvim_buf_set_extmark(bufnr, NS, line - 1, col, opts)
  if not state.extmarks[line] then
    state.extmarks[line] = {}
  end
  table.insert(state.extmarks[line], id)
  state.rendered[line] = true
  return id
end

local function get_align_direction(field)
  return field.is_number and "right" or "left"
end

--- Render a single field: virtual padding + highlight + delimiter
local function render_field(state, bufnr, lnum, col_idx, field, fields, column_widths, field_idx)
  field_idx = field_idx or col_idx
  local col_width = column_widths[col_idx]
  if not col_width then
    return
  end
  col_width = math.max(col_width, 1)

  local align_dir = get_align_direction(field)
  local align_padding = col_width - field.display_width

  -- Spacing: configurable gap between delimiter and field
  local before_padding = config.left_spacing
  local after_padding = config.right_spacing

  -- First field on the line: no leading spacing (no previous delimiter)
  if field.offset == 0 then
    before_padding = 0
  end

  if align_dir == "right" then
    before_padding = before_padding + align_padding
  else
    after_padding = after_padding + align_padding
  end

  -- Virtual padding before field
  if before_padding > 0 then
    add_extmark(state, bufnr, lnum, field.offset, {
      virt_text = { { string.rep(" ", before_padding) } },
      virt_text_pos = "inline",
      right_gravity = false,
    })
  end

  -- Virtual padding after field
  if after_padding > 0 then
    add_extmark(state, bufnr, lnum, field.offset + field.len, {
      virt_text = { { string.rep(" ", after_padding) } },
      virt_text_pos = "inline",
      right_gravity = true,
    })
  end

  -- Column color highlight
  local hl_name = "CsvViewCol" .. (col_idx - 1) % 9
  add_extmark(state, bufnr, lnum, field.offset, {
    hl_group = hl_name,
    end_col = field.offset + field.len,
  })

  -- Delimiter after this field (unless last)
  if field_idx < #fields then
    local next_field = fields[field_idx + 1]
    add_extmark(state, bufnr, lnum, field.offset + field.len, {
      hl_group = "CsvViewDelimiter",
      end_col = next_field.offset,
      conceal = config.border_char,
    })
  end
end

--- Render a single line
local function render_line(state, bufnr, lnum, metrics)
  if state.rendered[lnum] then
    return
  end

  local row = metrics.rows[lnum]
  if not row then
    state.rendered[lnum] = true
    return
  end

  -- Continuation line: add left-padding, then render fields
  if row.continuation then
    local skipped = row.skipped_ncol or 0
    if skipped > 0 then
      local pad = 0
      for i = 1, skipped do
        local w = metrics.column_widths[i] or 1
        w = math.max(w, 1)
        if i == 1 then
          pad = pad + w + config.right_spacing + 1 -- col_width + right spacing + boder
        else
          pad = pad + config.left_spacing + w + config.right_spacing + 1 -- left_spacing + col_width + right_spacing + border
        end
      end
      pad = pad + config.left_spacing
      if pad > 0 then
        add_extmark(state, bufnr, lnum, 0, {
          virt_text = { { string.rep(" ", pad) } },
          virt_text_pos = "inline",
          right_gravity = false,
        })
      end
    end
    -- Render continuation fields starting from column (skipped + 1)
    local fields = row.fields
    for field_idx, field in ipairs(fields) do
      local col_idx = skipped + field_idx
      render_field(state, bufnr, lnum, col_idx, field, fields, metrics.column_widths, field_idx)
    end
    state.rendered[lnum] = true
    return
  end

  -- Normal line: render all fields
  local fields = row.fields
  if #fields == 0 then
    state.rendered[lnum] = true
    return
  end

  for col_idx, field in ipairs(fields) do
    render_field(state, bufnr, lnum, col_idx, field, fields, metrics.column_widths)
  end

  -- First line gets header highlight
  if lnum == 1 then
    add_extmark(state, bufnr, lnum, 0, { line_hl_group = "CsvViewHeaderLine" })
  end
end

--- Render all visible lines in the viewport
local function render_visible(state, bufnr, metrics)
  local winids = vim.fn.win_findbuf(bufnr)
  if #winids == 0 then
    return
  end

  local winid = winids[1]
  local top = vim.fn.line("w0", winid)
  local bot = vim.fn.line("w$", winid)

  -- only render the visible lines on screen
  for lnum = top, bot do
    render_line(state, bufnr, lnum, metrics)
  end
end

-----------------------------------------------------------------------------
-- Column navigation
-----------------------------------------------------------------------------
--- Find the field index (1-based) that contains the given column position
local function find_field_index(fields, col)
  local idx = 1
  for i = #fields, 1, -1 do
    if col >= fields[i].offset then
      idx = i
      break
    end
  end
  return idx
end

--- Navigate to the next field in the current row
local function goto_next_field()
  local bufnr = vim.api.nvim_get_current_buf()
  local state = buffer_states[bufnr]
  if not state or not state.enabled or not state.metrics then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1]
  local col = cursor[2] -- 0-based column

  local row = state.metrics.rows[lnum]
  if not row or row.continuation or #row.fields == 0 then
    return
  end

  local fields = row.fields
  local current_idx = find_field_index(fields, col)

  -- Move to next field
  if current_idx < #fields then
    local next_field = fields[current_idx + 1]
    vim.api.nvim_win_set_cursor(0, { lnum, next_field.offset })
  end
end

--- Navigate to the previous field in the current row
local function goto_prev_field()
  local bufnr = vim.api.nvim_get_current_buf()
  local state = buffer_states[bufnr]
  if not state or not state.enabled or not state.metrics then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1]
  local col = cursor[2] -- 0-based column

  local row = state.metrics.rows[lnum]
  if not row or row.continuation or #row.fields == 0 then
    return
  end

  local fields = row.fields
  local current_idx = find_field_index(fields, col)

  -- Move to previous field
  if current_idx > 1 then
    local prev_field = fields[current_idx - 1]
    vim.api.nvim_win_set_cursor(0, { lnum, prev_field.offset })
  end
end

-----------------------------------------------------------------------------
-- Enable / Disable
-----------------------------------------------------------------------------
local function clear_rendering(bufnr, state)
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  state.extmarks = {}
  state.rendered = {}
end

local function setup_window(winid, enable)
  if enable then
    vim.api.nvim_set_option_value("conceallevel", 2, { scope = "local", win = winid })
    vim.api.nvim_set_option_value("concealcursor", "nvic", { scope = "local", win = winid })
    vim.api.nvim_set_option_value("wrap", false, { scope = "local", win = winid })
  else
    vim.api.nvim_set_option_value("conceallevel", 0, { scope = "local", win = winid })
    vim.api.nvim_set_option_value("concealcursor", "", { scope = "local", win = winid })
  end
end

local function enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if buffer_states[bufnr] and buffer_states[bufnr].enabled then
    return
  end

  define_highlights()

  local quote_char = DEFAULT_QUOTE_CHAR
  local delim = detect_delimiter(bufnr, quote_char)
  local metrics = compute_metrics(bufnr, delim, quote_char)

  local state = {
    enabled = true,
    extmarks = {},
    rendered = {},
    metrics = metrics,
    delimiter = delim,
    quote_char = quote_char,
  }
  buffer_states[bufnr] = state

  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    setup_window(winid, true)
  end

  -- Setup keybindings
  vim.keymap.set({ "n", "i" }, "<Tab>", goto_next_field, { buffer = bufnr, desc = "Go to next CSV field" })
  vim.keymap.set({ "n", "i" }, "<S-Tab>", goto_prev_field, { buffer = bufnr, desc = "Go to previous CSV field" })

  render_visible(state, bufnr, metrics)
end

local function disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = buffer_states[bufnr]
  if not state or not state.enabled then
    return
  end

  clear_rendering(bufnr, state)

  -- Remove keybindings
  pcall(vim.keymap.del, { "n", "i" }, "<Tab>", { buffer = bufnr })
  pcall(vim.keymap.del, { "n", "i" }, "<S-Tab>", { buffer = bufnr })

  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    setup_window(winid, false)
  end

  state.enabled = false
  state.metrics = nil
end

-----------------------------------------------------------------------------
-- Autocommands
-----------------------------------------------------------------------------
local augroup = vim.api.nvim_create_augroup("CsvViewStandalone", { clear = true })

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = augroup,
  callback = function(args)
    local bufnr = args.buf
    local state = buffer_states[bufnr]
    if state and state.enabled and state.metrics then
      render_visible(state, bufnr, state.metrics)
    end
  end,
})

vim.api.nvim_create_autocmd("WinScrolled", {
  group = augroup,
  callback = function(args)
    local winid = args.win
    if not winid then
      return
    end
    local ok, bufnr = pcall(vim.api.nvim_win_get_buf, winid)
    if not ok then
      return
    end
    local state = buffer_states[bufnr]
    if state and state.enabled and state.metrics then
      render_visible(state, bufnr, state.metrics)
    end
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = augroup,
  callback = function(args)
    local bufnr = args.buf
    local state = buffer_states[bufnr]
    if state and state.enabled then
      clear_rendering(bufnr, state)
      local metrics = compute_metrics(bufnr, state.delimiter, state.quote_char)
      state.metrics = metrics
      render_visible(state, bufnr, metrics)
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
  group = augroup,
  callback = function(args)
    buffer_states[args.buf] = nil
  end,
})

-----------------------------------------------------------------------------
-- API
-----------------------------------------------------------------------------
vim.api.nvim_create_user_command("CsvViewToggle", function()
  M.toggle()
end, { desc = "Toggle CSV table view for current buffer" })

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  enable()
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = buffer_states[bufnr]
  if state and state.enabled then
    disable(bufnr)
  else
    enable(bufnr)
  end
end

return M
