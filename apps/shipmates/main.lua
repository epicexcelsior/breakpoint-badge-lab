local radar = require("lib.radar")
local connections = require("lib.connections")
local state = radar.new(storage.get("topics"))
local saved = connections.read(storage.get("connections"))
local INVITE = "https://github.com/epicexcelsior/breakpoint-badge-lab/releases/latest"
local screen, field, person = "home", 1, nil
local last_send, last_ui, last_count = -3000, -1000, -1
local radio_error, peer_list, rows, status, detail, footer
local person_title, meeting, contact
local glow_until = 0
local fingerprint = ""

-- The host acquires the mesh for apps with the permission. Give Wi-Fi back until consent.
if mesh.pause then mesh.pause() end

local function save()
  storage.set("topics", {need = state.need, offer = state.offer})
end

local function broadcast()
  local now = sys.millis()
  if now - last_send < 1000 then return end
  last_send = now
  local ok, why = mesh.send("*", radar.payload(state))
  radio_error = not ok and (why or "radio unavailable") or nil
end

local function people()
  return radar.list(state, sys.millis())
end

local function mutual(id)
  saved = connections.put(saved, id, state.peers[id])
  storage.set("connections", saved)
  local code = radar.code(state.id, id)
  glow_until = sys.millis() + 20000
  for i = 1, led.count do led.hex(i, radar.color(code)) end
  ui.toast("Find meeting code " .. code .. ". Connection saved.")
  print("shipmates: mutual " .. id)
end

local render

local function update_radar()
  rows = people()
  local items, keys, matches = {}, {}, 0
  for _, p in ipairs(rows) do
    if p.score > 0 then matches = matches + 1 end
    local mark = p.mutual and "Met" or (p.incoming and "Hello!" or (p.score > 0 and "Match" or "Nearby"))
    items[#items + 1] = {title = (p.name or p.id) .. "  " .. mark,
      sub = "Offers " .. radar.topics[p.offer] .. " / needs " .. radar.topics[p.need]}
    keys[#keys + 1] = p.id .. (p.name or "") .. mark .. p.need .. p.offer
  end
  local key = table.concat(keys, ",")
  if key ~= fingerprint then
    local selected = peer_list:selected()
    peer_list:items(items)
    if #items > 0 then peer_list:select(math.max(1, math.min(selected or 1, #items))) end
    fingerprint = key
  end
  local count = #rows
  if count ~= last_count then
    print("shipmates: nearby " .. count)
    last_count = count
  end
  if radio_error then
    status:text("Radio: " .. radio_error)
  elseif count == 0 then
    status:text("Listening. Open Shipmates on a friend.")
  else
    status:text(count .. " nearby / " .. matches .. " matches")
  end
end

local function update_detail()
  radar.expire(state, sys.millis())
  local p = state.peers[person]
  if not p then
    detail:text("Out of range\nBACK returns to people")
    footer:text("People disappear after 15 seconds.")
    return
  end
  person_title:text(p.name or person)
  meeting:text(state.mutual[person] and ("MEET " .. radar.code(state.id, person)) or "Say hello.")
  detail:text("Offers " .. radar.topics[p.offer] .. "\nNeeds " .. radar.topics[p.need])
  local result = state.mutual[person] and (p.name and "Same glow. Same meeting code.\nRIGHT opens their profile."
    or "Same glow. Same meeting code.\nAsk for their contact in person.")
    or (p.hello == state.id and "They said hello. SELECT to reply."
    or (state.target == person and "Hello sent. Waiting for their reply."
    or "SELECT says hello to this badge."))
  footer:text(result)
end

render = function()
  ui.clear()
  ui.bg("bg")
  peer_list = nil
  if screen == "home" then
    ui.label(12, 8, "Find your people.", {size = 20})
    ui.label(12, 39, "One ask. One offer. A connection to keep.", {size = 12, color = "dim"})
    ui.rect(8, field == 1 and 63 or (field == 2 and 101 or 139), 304, 35, {color = "panel", radius = 6})
    ui.label(16, 73, "NEED", {size = 12, color = "dim"})
    ui.label(94, 69, radar.topics[state.need], {size = 20, color = "green"})
    ui.label(16, 111, "OFFER", {size = 12, color = "dim"})
    ui.label(94, 107, radar.topics[state.offer], {size = 20})
    ui.label(16, 145, "Connections", {size = 20})
    ui.label(267, 145, tostring(#saved), {size = 20, color = "green"})
    ui.label(12, 181, state.live and "Sharing nearby. BACK stops sharing."
      or "Shares handle, topics, badge ID nearby.", {size = 12, color = "dim", w = 296})
    ui.hint(state.live and "L/R edit  SELECT people  BACK stop" or "L/R edit  UP/DOWN field  SELECT start")
  elseif screen == "radar" then
    ui.label(12, 7, "People nearby", {size = 20})
    status = ui.label(12, 34, "Listening...", {size = 12, color = "dim", w = 296})
    fingerprint = "!"
    peer_list = ui.list(8, 57, 304, 138, {}, {on_select = function(i)
      local p = rows[i]
      if p then person = p.id; screen = "person"; render() end
    end})
    ui.hint("SELECT hello  RIGHT invite  BACK edit")
    update_radar()
  elseif screen == "person" then
    person_title = ui.label(12, 7, person, {size = 20, color = "green"})
    meeting = ui.label(12, 36, "", {size = 32})
    detail = ui.label(12, 83, "", {size = 20, w = 296})
    footer = ui.label(12, 141, "", {size = 14, w = 296})
    ui.label(12, 182, "Handles are unverified. Meet in public.", {size = 12, color = "dim"})
    ui.hint("SELECT hello  RIGHT profile  BACK people")
    update_detail()
  elseif screen == "saved" then
    ui.label(12, 7, "Keep the connection.", {size = 20})
    ui.label(12, 36, #saved == 0 and "Mutual hellos save here. Start with a friend."
      or "Saved on this badge. SELECT to follow up.", {size = 12, color = "dim", w = 296})
    local items = {}
    for _, p in ipairs(saved) do
      items[#items + 1] = {title = p.name or p.id, sub = "Offers " .. radar.topics[p.offer]}
    end
    peer_list = ui.list(8, 59, 304, 136, items, {on_select = function(i)
      contact = saved[i]
      if contact then screen = "contact"; render() end
    end})
    ui.hint("SELECT profile  LEFT clear  BACK home")
  elseif screen == "contact" or screen == "profile" then
    ui.label(12, 3, contact.name or contact.id, {size = 20})
    if contact.name then
      ui.qr(80, 29, 160, "https://x.com/" .. contact.name:sub(2))
    else
      ui.label(12, 65, "No public handle shared.", {size = 20, w = 296})
      ui.label(12, 105, "Ask for their contact in person.", {size = 14, color = "dim", w = 296})
    end
    ui.hint("Scan to follow up  BACK returns")
  else
    ui.label(12, 3, "Bring a friend.", {size = 20})
    ui.qr(80, 29, 160, INVITE)
    ui.hint("Scan for free downloads  BACK people")
  end
end

function on_key(key, rep)
  if screen == "contact" or screen == "profile" then
    if key == "back" then screen = screen == "contact" and "saved" or "person"; render() end
    return true
  end
  if screen == "saved" then
    if key == "back" then screen = "home"; render()
    elseif key == "left" and not rep then
      ui.confirm("Delete saved connections?", function(yes)
        if yes then saved = {}; storage.set("connections", saved); render() end
      end)
    end
    return true
  end
  if screen == "invite" then
    if key == "back" then screen = "radar"; render() end
    return true
  end
  if screen == "person" then
    if key == "back" then screen = "radar"; render()
    elseif key == "right" then
      local p = state.peers[person]
      if p then contact = {id = person, name = p.name}; screen = "profile"; render() end
    elseif key == "select" and not rep then
      local ok, connected = radar.hello(state, person, sys.millis())
      if not ok then ui.toast("This badge left. BACK finds people.")
      else
        print("shipmates: hello " .. person)
        if connected then mutual(connected) end
        -- The next state beacon repeats the hello even when this packet is lost.
        broadcast()
        update_detail()
      end
    end
    return true
  end
  if screen == "radar" then
    if key == "back" then screen = "home"; render()
    elseif key == "right" then screen = "invite"; render() end
    return true
  end
  if key == "up" or key == "down" then
    field = (field - 1 + (key == "down" and 1 or -1)) % 3 + 1; render()
  elseif (key == "left" or key == "right") and field < 3 then
    local attr = field == 1 and "need" or "offer"
    state[attr] = (state[attr] - 1 + (key == "right" and 1 or -1)) % #radar.topics + 1
    save(); render()
  elseif key == "select" and not rep then
    if field == 3 then screen = "saved"; render(); return true end
    if not state.live then
      state.id = badge.id()
      if not radar.id(state.id) then
        ui.toast("Use OS Wi-Fi once to activate this badge.")
        return true
      end
      state.name = radar.handle(badge.owner())
      state.live = true
      if mesh.resume then mesh.resume() end
      print("shipmates: sharing on")
      broadcast()
    end
    screen = "radar"; render()
  elseif key == "back" then
    if not state.live then return false end
    radar.stop(state)
    led.off(); glow_until = 0
    broadcast()
    if mesh.pause then mesh.pause() end
    print("shipmates: sharing off")
    render()
  end
  return true
end

function on_tick()
  local now = sys.millis()
  if glow_until > 0 and now >= glow_until then led.off(); glow_until = 0 end
  if state.live and now - last_send >= 3000 then broadcast() end
  if now - last_ui < 1000 then return end
  last_ui = now
  if screen == "radar" then update_radar()
  elseif screen == "person" then update_detail() end
end

function on_mesh(from, message)
  local changed, connected = radar.receive(state, from, message, sys.millis())
  if connected then mutual(connected) end
  if changed and screen == "person" then update_detail() end
end

function on_exit()
  if state.live then radar.stop(state); broadcast() end
  led.off()
  print("shipmates: closed")
end

print("shipmates: ready, sharing off")
render()
