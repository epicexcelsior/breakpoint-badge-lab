-- Absolute state tolerates lost packets. No received field becomes executable code.
local M = {}
M.topics = {"Building", "Design", "Feedback", "Learning", "Hiring", "Coffee"}
M.ttl = 15000
M.capacity = 24

local function integer(n, lo, hi)
  return type(n) == "number" and n == math.floor(n) and n >= lo and n <= hi
end

function M.id(value)
  return type(value) == "string" and #value >= 3 and #value <= 16
    and value:match("^[A-Za-z0-9]+$") ~= nil
end

function M.topic(value, fallback)
  return integer(value, 1, #M.topics) and value or fallback
end

function M.handle(value)
  if type(value) ~= "string" or #value < 2 or #value > 16 then return nil end
  return value:match("^@[%w_]+$") and value or nil
end

function M.code(a, b)
  if a > b then a, b = b, a end
  local hash = 0
  for i = 1, #(a .. b) do hash = (hash * 31 + (a .. b):byte(i)) % 4096 end
  return string.format("%03X", hash)
end

function M.color(code)
  local palette = {0x14F195, 0x9945FF, 0xFF9B50, 0x53BFFF, 0xFF66AA, 0xE8D84D, 0x65D3C8, 0xCDA4FF}
  return palette[tonumber(code, 16) % #palette + 1]
end

function M.new(saved)
  saved = type(saved) == "table" and saved or {}
  return {need = M.topic(saved.need, 1), offer = M.topic(saved.offer, 3),
    live = false, peers = {}, target = nil, mutual = {}, count = 0}
end

function M.score(state, peer)
  return (state.need == peer.offer and 1 or 0) + (state.offer == peer.need and 1 or 0)
end

function M.expire(state, now)
  for id, p in pairs(state.peers) do
    if now - p.seen >= M.ttl or now < p.seen then state.peers[id] = nil end
  end
end

function M.list(state, now)
  M.expire(state, now)
  local list = {}
  for id, p in pairs(state.peers) do
    list[#list + 1] = {id = id, name = p.name, need = p.need, offer = p.offer,
      incoming = p.hello == state.id, mutual = state.mutual[id] == true,
      score = M.score(state, p)}
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.id < b.id
  end)
  return list
end

function M.payload(state)
  return {v = 1, t = "s", n = state.need, o = state.offer, live = state.live,
    h = state.live and state.target or nil, a = state.live and state.name or nil}
end

function M.receive(state, from, msg, now)
  if not state.live or not M.id(from) or from == state.id or type(msg) ~= "table"
    or msg.v ~= 1 or msg.t ~= "s" or type(msg.live) ~= "boolean"
    or not M.topic(msg.n) or not M.topic(msg.o)
    or (msg.h ~= nil and not M.id(msg.h))
    or (msg.a ~= nil and not M.handle(msg.a)) then return false end
  if not msg.live then state.peers[from] = nil; return true end
  M.expire(state, now)
  if not state.peers[from] then
    local count = 0
    for _ in pairs(state.peers) do count = count + 1 end
    -- Keep existing people stable under an unsolicited peer flood.
    if count >= M.capacity then return false end
  end
  state.peers[from] = {name = msg.a, need = msg.n, offer = msg.o, hello = msg.h, seen = now}
  if msg.h == state.id and state.target == from and not state.mutual[from] then
    if state.count < M.capacity then
      state.mutual[from] = true
      state.count = state.count + 1
      return true, from
    end
  end
  return true
end

function M.hello(state, id, now)
  M.expire(state, now)
  if not state.live or not state.peers[id] then return false end
  state.target = id
  local p = state.peers[id]
  if p.hello == state.id and not state.mutual[id] and state.count < M.capacity then
    state.mutual[id] = true
    state.count = state.count + 1
    return true, id
  end
  return true
end

function M.stop(state)
  state.live = false
  state.target = nil
  state.peers = {}
end

return M
