local M = {}

-----------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------
local NS = vim.api.nvim_create_namespace("csvview")
local BORDER_CHAR = "│"
local BORDER_CHAR_WIDTH = 1 -- display width of │
local DEFAULT_DELIMITERS = { ",", "\t", ";", "|", ":" }
local DEFAULT_QUOTE_CHARS = { '"', "'" }

-----------------------------------------------------------------------------
-- State per buffer
-----------------------------------------------------------------------------
local buffer_states = {} ---@type table<integer, table>

-----------------------------------------------------------------------------
-- Highlight groups
-----------------------------------------------------------------------------
local hl_defined = false

local function define_highlights()
  if hl_defined then
    return
  end
  hl_defined = true

  local col_hls = {
    "csvCol0",
    "csvCol1",
    "csvCol2",
    "csvCol3",
    "csvCol4",
    "csvCol5",
    "csvCol6",
    "csvCol7",
    "csvCol8",
  }

  for i, hl in ipairs(col_hls) do
    vim.api.nvim_set_hl(0, "CsvViewCol" .. (i - 1), { fg = hl.fg, bg = hl.bg, default = true })
  end

  vim.api.nvim_set_hl(0, "CsvViewDelimiter", { fg = "#727169", default = true })
  vim.api.nvim_set_hl(0, "CsvViewHeaderLine", { bold = true, underline = true, default = true })
end

-----------------------------------------------------------------------------
-- Utility functions
-----------------------------------------------------------------------------

local function str_display_width(str)
  return vim.fn.strdisplaywidth(str)
end

local function is_number_str(str)
  local trimmed = str:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return false
  end
  return tonumber(trimmed) ~= nil
end

local function buf_get_line(bufnr, lnum)
  local count = vim.api.nvim_buf_line_count(bufnr)
  if lnum < 1 or lnum > count then
    return nil
  end
  return vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
end

-----------------------------------------------------------------------------
-- Delimiter / quote detection
-----------------------------------------------------------------------------

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
  return count + 1
end

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
      local score = min_c * 10 - (max_c - min_c)
      if score > best_score then
        best_score = score
        best_delim = delim
      end
    end
  end

  return best_delim
end

local function detect_quote_char(bufnr)
  local n_samples = 10
  local total = vim.api.nvim_buf_line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(n_samples, total), true)
  local sample = table.concat(lines, "\n")
  local best_quote, best_score = '"', -1

  for _, qc in ipairs(DEFAULT_QUOTE_CHARS) do
    local count = 0
    local qb = qc:byte()
    for i = 1, #sample do
      if sample:byte(i) == qb then
        count = count + 1
      end
    end
    local score = count
    if count > 0 and count % 2 == 0 then
      score = score + 100
    end
    if score > best_score then
      best_score = score
      best_quote = qc
    end
  end

  return best_quote
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
---@field display_text string  text with quotes stripped (for width calculation)
---@field display_width integer
---@field is_number boolean

--- Parse a single physical line into fields.
--- Each field has offset/len relative to THIS line.
--- Also returns has_unclosed_quote to detect multi-line records.
local function parse_line(line, delim, quote_char)
  if not line or #line == 0 then
    return {}, false
  end

  local delim_bytes = {}
  for i = 1, #delim do
    delim_bytes[i] = delim:byte(i)
  end
  local delim_first = delim_bytes[1]
  local delim_len = #delim_bytes
  local quote_byte = quote_char:byte()

  local fields = {} ---@type CsvField[]
  local pos = 1
  local field_start = 1
  local len = #line
  local has_unclosed_quote = false

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
    elseif b == delim_first then
      local is_match = true
      if delim_len > 1 then
        for i = 2, delim_len do
          if pos + i - 1 > len or line:byte(pos + i - 1) ~= delim_bytes[i] then
            is_match = false
            break
          end
        end
      end

      if is_match then
        local text = line:sub(field_start, pos - 1)
        table.insert(fields, { offset = field_start - 1, len = pos - field_start, text = text })
        pos = pos + delim_len
        field_start = pos
      else
        pos = pos + 1
      end
    else
      pos = pos + 1
    end
  end

  -- Final field (rest of line after last delimiter)
  if not has_unclosed_quote then
    local text = line:sub(field_start)
    table.insert(fields, { offset = field_start - 1, len = #line - field_start + 1, text = text })
  else
    -- For multi-line start: the unclosed quoted field extends to end of line
    -- We still record it as a field on this line (for rendering the partial text)
    local text = line:sub(field_start)
    table.insert(fields, { offset = field_start - 1, len = #line - field_start + 1, text = text })
  end

  -- Compute display_text, display_width, is_number for each field
  for _, f in ipairs(fields) do
    local t = f.text
    if t:sub(1, 1) == quote_char and t:sub(-1) == quote_char and #t >= 2 then
      f.display_text = t:sub(2, -2):gsub(quote_char .. quote_char, quote_char)
    else
      f.display_text = t
    end
    f.display_width = str_display_width(f.display_text)
    f.is_number = is_number_str(f.display_text)
  end

  return fields, has_unclosed_quote
end

-----------------------------------------------------------------------------
-- Metrics
--
-- Parse all lines, detect multi-line records, compute column widths.
-- Multi-line records: when a line has an unclosed quote, subsequent lines
-- are continuation lines until we find a line with a closing quote.
--
-- Only first-line fields contribute to column widths.
-----------------------------------------------------------------------------

--- Detect the end of a multi-line record starting at start_lnum.
--- Returns the line number where the multi-line record ends.
local function find_multiline_end(bufnr, start_lnum, quote_char)
  local quote_byte = quote_char:byte()
  local total = vim.api.nvim_buf_line_count(bufnr)
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

    local fields, has_unclosed_quote = parse_line(line, delim, quote_char)
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
      local n_first_line_cols = #fields
      for col_idx, f in ipairs(fields) do
        if not column_widths[col_idx] or f.display_width > column_widths[col_idx] then
          column_widths[col_idx] = f.display_width
        end
      end

      -- Find where the multi-line record ends
      local end_lnum = find_multiline_end(bufnr, lnum, quote_char)

      -- Mark continuation lines
      local skipped = n_first_line_cols -- number of parent columns "passed"
      for cl = lnum + 1, end_lnum do
        local cline = buf_get_line(bufnr, cl)
        local cfields = {}
        if cline then
          cfields, _ = parse_line(cline, delim, quote_char)
        end
        rows[cl] = {
          fields = cfields,
          continuation = true,
          parent_lnum = lnum,
          skipped_ncol = skipped,
        }
        -- Continuation line fields do NOT contribute to column widths
        -- (they have different column indices in the multi-line context)
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
local function render_field(state, bufnr, lnum, col_idx, field, fields, column_widths)
  local col_width = column_widths[col_idx]
  if not col_width then
    return
  end
  col_width = math.max(col_width, 1)

  local align_dir = get_align_direction(field)
  local align_padding = col_width - field.display_width

  -- Spacing: 1 space gap between delimiter and field
  local spacing = 1
  local before_padding = spacing
  local after_padding = spacing

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
  if col_idx < #fields then
    local next_field = fields[col_idx + 1]
    add_extmark(state, bufnr, lnum, field.offset + field.len, {
      hl_group = "CsvViewDelimiter",
      end_col = next_field.offset,
      conceal = BORDER_CHAR,
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

  -- Continuation line: only add left-padding, no field rendering
  if row.continuation then
    local skipped = row.skipped_ncol or 0
    if skipped > 0 then
      -- Calculate padding width for all skipped parent columns
      -- padding = col1_width + sum(col_i_width + 2 + BORDER_WIDTH for i=2..skipped)
      -- col1_width has no left spacing (it's the first column)
      local pad = 0
      for i = 1, skipped do
        local w = metrics.column_widths[i] or 1
        w = math.max(w, 1)
        if i == 1 then
          pad = pad + w + 1 -- col_width + right spacing
        else
          pad = pad + w + 2 + BORDER_CHAR_WIDTH -- left_spacing + col_width + right_spacing + border
        end
      end
      if pad > 0 then
        add_extmark(state, bufnr, lnum, 0, {
          virt_text = { { string.rep(" ", pad) } },
          virt_text_pos = "inline",
          right_gravity = false,
        })
      end
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

  for lnum = top, bot do
    render_line(state, bufnr, lnum, metrics)
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

  local quote_char = detect_quote_char(bufnr)
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

  render_visible(state, bufnr, metrics)
end

local function disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = buffer_states[bufnr]
  if not state or not state.enabled then
    return
  end

  clear_rendering(bufnr, state)

  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    setup_window(winid, false)
  end

  state.enabled = false
  state.metrics = nil
end

local function toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = buffer_states[bufnr]
  if state and state.enabled then
    disable(bufnr)
  else
    enable(bufnr)
  end
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

vim.api.nvim_create_user_command("CSVViewToggle", function()
  toggle()
end, { desc = "Toggle CSV table view for current buffer" })

function M.setup(opts)
  opts = opts or {}
end

toggle()

return M
