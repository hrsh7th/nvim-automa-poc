---@class automa.Event
---@field mode string
---@field typed string
---@field changedtick integer

---Check if the event sequence should be treated as "dot-repeatable".
---@param events automa.Event[]
---@param idx integer
---@param modes string[]
---@return boolean, integer
local function check_sequence(events, idx, modes)
  local base_idx = idx

  local mode_idx = #modes
  while mode_idx > 0 and idx > 0 do
    local many = false
    local mode = modes[mode_idx]
    if mode:sub(-1, -1) == '*' then
      many = true
      mode = mode:sub(1, -2)
    elseif mode:sub(-1, -1) == '!' then
      mode = mode:sub(1, -2)
    end

    if events[idx].mode ~= mode then
      return false, base_idx
    end
    idx = idx - 1
    if many then
      while events[idx].mode == mode do
        idx = idx - 1
      end
    end
    mode_idx = mode_idx - 1
  end
  return true, idx + 1
end

---The automa instance.
local automa = {}

---The maximum number of events to keep.
automa.MaxEventCount = 200

---The namespace for the automa.
automa.ns = vim.api.nvim_create_namespace("automa")

---@type { mode: string, typed: string, changedtick: integer }[]
automa.events = {}

---The automa setup function.
function automa.setup()
  -- Hijack dot-repeat.
  vim.keymap.set('n', '.', function()
    automa.execute()
  end, { noremap = true, silent = true })

  -- Initialize the events.
  automa.events = { {
    mode = vim.api.nvim_get_mode().mode,
    typed = "",
    changedtick = vim.api.nvim_buf_get_changedtick(0),
  } }

  -- Listen vim.on_key
  vim.on_key(function(_, typed)
    if typed ~= '' then
      table.insert(automa.events, {
        mode = vim.api.nvim_get_mode().mode,
        typed = typed,
        changedtick = vim.api.nvim_buf_get_changedtick(0),
      })
      if #automa.events > automa.MaxEventCount then
        table.remove(automa.events, 1)
      end
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

    -- `diwiINSERT<Esc>` should be treated as dot-repeatable.
    found, idx = check_sequence(automa.events, e_idx, { 'n', 'no*', 'n', 'i*' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    -- `iINSERT<Esc>` should be treated as dot-repeatable.
    found, idx = check_sequence(automa.events, e_idx, { 'n', 'i*' })
    if found then
      table.insert(candidates, { s = idx, e = e_idx })
    end

    -- `dd` should be treated as dot-repeatable.
    found, idx = check_sequence(automa.events, e_idx, { 'n', 'no*' })
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

  vim.api.nvim_feedkeys(typed, '', true)
end

return automa
