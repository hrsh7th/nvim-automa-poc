---@class automa.Event
---@field mode string
---@field typed string
---@field edit boolean
---@field undo integer
---@field changedtick integer
---@field changenr integer

---Check if the event sequence should be treated as "dot-repeatable".
---@param events automa.Event[]
---@param idx integer
---@param modes string[]
---@return boolean, integer
local function check_sequence(events, idx, modes)
  local base_idx = idx

  local mode_idx = #modes
  while mode_idx > 0 and idx > 0 do
    local edit = false
    local many = false
    local mode = modes[mode_idx]
    if mode:sub(-1, -1) == '*' then
      many = true
      mode = mode:sub(1, -2)
    elseif mode:sub(-1, -1) == '!' then
      edit = true
      mode = mode:sub(1, -2)
    end

    if events[idx].mode ~= mode or (edit and not events[idx].edit) then
      return false, base_idx
    end

    if events[idx].undo then
      return false, base_idx
    end
    idx = idx - 1

    if many then
      while events[idx].mode == mode and (not edit or events[idx].edit) do
        if events[idx].undo then
          return false, base_idx
        end
        idx = idx - 1
      end
    end
    mode_idx = mode_idx - 1
  end

  if events[base_idx].changedtick == events[idx].changedtick then
    return false, base_idx
  end

  return true, idx + 1
end

---The automa instance.
local automa = {}

---The maximum number of events to keep.
automa.MaxEventCount = 200

---The namespace for the automa.
automa.ns = vim.api.nvim_create_namespace("automa")

---@type automa.Event[]
automa.events = {}

---The automa setup function.
function automa.setup()
  -- Hijack dot-repeat.
  vim.keymap.set('n', '.', function()
    automa.execute()
  end, { noremap = true, silent = true })

  -- Initialize the events.
  automa.events = { {
    mode = '',
    typed = '',
    edit = false,
    changedtick = vim.api.nvim_buf_get_changedtick(0),
    changenr = vim.fn.changenr(),
  } }

  -- Listen vim.on_key
  vim.on_key(function(_, typed)
    if typed ~= '' then
      local mode = vim.api.nvim_get_mode().mode
      vim.schedule(function()
        local changedtick = vim.api.nvim_buf_get_changedtick(0)
        local changenr = vim.fn.changenr()
        local edit = automa.events[#automa.events].changedtick ~= changedtick
        local undo = changenr < automa.events[#automa.events].changenr
        local event = {
          mode = mode,
          typed = typed,
          edit = typed ~= '.' and edit and not undo,
          undo = typed ~= '.' and undo,
          changedtick = changedtick,
          changenr = changenr,
        }
        -- -- debug log
        -- if #automa.events > 1 then
        --   if event.mode ~= 'c' then
        --     if event.edit or automa.events[#automa.events - 1].mode ~= event.mode then
        --       vim.print(event)
        --     end
        --   end
        -- end
        table.insert(automa.events, event)

        if #automa.events > automa.MaxEventCount then
          table.remove(automa.events, 1)
        end
      end)
    end
  end, automa.ns)
end

---The automa execute function.
function automa.execute()
  if #automa.events <= 1 then
    return
  end

  local s_idx = 0
  local e_idx = #automa.events
  while e_idx > 1 do
    local candidates, found, idx = {}, nil, nil

    -- `diwi*****<Esc>`
    found, idx = check_sequence(automa.events, e_idx, { 'n', 'no*', 'n', 'i*' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    -- `ciw*****<Esc>`
    found, idx = check_sequence(automa.events, e_idx, { 'n', 'no*', 'i*' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    -- `Di*****<Esc>`
    found, idx = check_sequence(automa.events, e_idx, { 'n!', 'n', 'i*' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    -- `i*****<Esc>`
    found, idx = check_sequence(automa.events, e_idx, { 'n', 'i*' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    -- `dd`
    found, idx = check_sequence(automa.events, e_idx, { 'n', 'no*' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    -- `D`
    found, idx = check_sequence(automa.events, e_idx, { 'n!' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    if #candidates > 0 then
      local max = 0
      for _, c in ipairs(candidates) do
        if c.e > max then
          max = c.e
          s_idx = c.s
          e_idx = c.e
        end
      end
      break
    end

    e_idx = e_idx - 1
  end

  if s_idx == 0 or e_idx == 0 then
    return
  end

  local typed = ""
  for i = s_idx, e_idx do
    typed = typed .. automa.events[i].typed
  end

  local lazyredraw = vim.o.lazyredraw
  vim.api.nvim_feedkeys(
    vim.keycode('<Cmd>set lazyredraw<CR>') .. typed .. vim.keycode(('<Cmd>set %slazyredraw<CR>'):format(lazyredraw and '' or 'no')),
    'i',
    true
  )
end

return automa
