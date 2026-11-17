-- Deterministic stand-in. Real host compatibility is tested by tools/emulator.mjs.
local H = {}

function H.app(folder, saved, id)
  local h = {now = 0, saved = saved or {}, sent = {}, logs = {}, labels = {}, lights = false, count = 0}
  local env = {}
  for _, name in ipairs({"assert", "error", "ipairs", "pairs", "next", "pcall", "select", "tonumber",
    "tostring", "type", "string", "table", "math", "utf8", "coroutine", "setmetatable", "getmetatable"}) do
    env[name] = _G[name]
  end
  env._G = env
  env.print = function(...) h.logs[#h.logs + 1] = table.concat({...}, " ") end
  env.sys = {millis = function() return h.now end}
  env.badge = {id = function() return id end, owner = function() return h.owner end}
  env.storage = {get = function(k) return h.saved[k] end,
    set = function(k, value) h.saved[k] = value end}
  env.led = {off = function() h.lights = false end,
    count = 8, hex = function(i, color) h.lights = true; h.color = color end,
    fill = function(r, g, b)
      assert(r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255)
      h.lights = true
    end}
  env.mesh = {
    pause = function() h.paused = true end,
    resume = function() h.paused = false end,
    send = function(to, data)
      h.sent[#h.sent + 1] = {to = to, data = data, at = h.now}
      if h.radio_error then return nil, h.radio_error end
      return true
    end,
  }
  local function obj(text)
    h.count = h.count + 1
    assert(h.count <= 128, "UI object budget")
    local o = {value = text}
    function o:text(value) assert(#value <= 200, "Label budget"); self.value = value end
    function o:set(value) assert(value == math.floor(value) and value >= 0 and value <= 100); self.value = value end
    function o:select(i) self.index = i end
    function o:selected() return self.index or 1 end
    function o:items(items) self.rows = items end
    return o
  end
  env.ui = {W = 320, H = 218,
    clear = function() h.count = 0; h.labels = {}; h.focus = nil end,
    bg = function() end,
    hint = function(text) h.hint = text end,
    toast = function(text) h.toast = text end,
    confirm = function(text, callback) h.confirm = callback end,
    rect = function() return obj() end,
    qr = function(x, y, size, text) h.qr = text; return obj(text) end,
    bar = function() return obj(0) end,
    label = function(x, y, text)
      assert(x >= 0 and x < 320 and y >= 0 and y < 218)
      local o = obj(text); h.labels[#h.labels + 1] = o; return o
    end,
    list = function(x, y, w, height, items, options)
      local o = obj(); o.rows = items; o.options = options; h.focus = o; return o
    end,
  }
  local loaded = {}
  env.require = function(name)
    assert(name:match("^[a-z0-9_.]+$") and not name:find("..", 1, true))
    if loaded[name] == nil then
      loaded[name] = assert(loadfile(folder .. "/" .. name:gsub("%.", "/") .. ".lua", "t", env))()
    end
    return loaded[name]
  end
  function h:press(key, rep)
    local focus = self.focus
    if focus and #focus.rows > 0 then
      if key == "up" then focus:select(math.max(1, focus:selected() - 1)); return true end
      if key == "down" then focus:select(math.min(#focus.rows, focus:selected() + 1)); return true end
      if key == "select" then focus.options.on_select(focus:selected()); return true end
    end
    return env.on_key(key, rep or false)
  end
  function h:tick(ms) self.now = self.now + ms; if env.on_tick then env.on_tick(ms) end end
  function h:receive(from, msg) if env.on_mesh then env.on_mesh(from, msg) end end
  function h:contains(text)
    for _, label in ipairs(self.labels) do if label.value:find(text, 1, true) then return true end end
    return false
  end
  h.env = env
  assert(loadfile(folder .. "/main.lua", "t", env))()
  return h
end

return H
