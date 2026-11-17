local R = dofile("apps/shipmates/lib/radar.lua")
local H = dofile("tests/harness.lua")
local n = 0
local function test(name, fn) fn(); n = n + 1; print("ok shipmates: " .. name) end
local function state(id, need, offer)
  local s = R.new({need = need, offer = offer}); s.id = id; s.live = true; return s
end

test("corrupt preferences have safe defaults and never restore consent", function()
  for _, bad in ipairs({false, 4, "oops", {need = 0, offer = 99}, {need = 1.5, offer = "2"}, {live = true}}) do
    local s = R.new(bad)
    assert(s.need == 1 and s.offer == 3 and not s.live)
  end
end)

test("complementary topics rank first and duplicate packets do not multiply peers", function()
  local a = state("TEST01", 1, 3)
  local b = state("TEST02", 3, 1)
  local c = state("TEST03", 5, 6)
  for _ = 1, 50 do assert(R.receive(a, b.id, R.payload(b), 100)) end
  assert(R.receive(a, c.id, R.payload(c), 200))
  local list = R.list(a, 200)
  assert(#list == 2 and list[1].id == b.id and list[1].score == 2)
end)

test("mutual hello requires both explicit choices and is counted once", function()
  local a, b = state("TEST01", 1, 3), state("TEST02", 3, 1)
  R.receive(a, b.id, R.payload(b), 0); R.receive(b, a.id, R.payload(a), 0)
  assert(R.hello(a, b.id, 0)); assert(a.count == 0 and b.count == 0)
  R.receive(b, a.id, R.payload(a), 100)
  local ok, mutual = R.hello(b, a.id, 100)
  assert(ok and mutual == a.id and b.count == 1)
  for _ = 1, 10 do R.receive(a, b.id, R.payload(b), 200) end
  assert(a.count == 1 and b.count == 1)
end)

test("lost messages recover from repeated state and expiry uses the exact boundary", function()
  local a, b = state("TEST01", 1, 3), state("TEST02", 3, 1)
  R.receive(a, b.id, R.payload(b), 0)
  assert(#R.list(a, 14999) == 1)
  assert(#R.list(a, 15000) == 0)
  assert(not R.hello(a, b.id, 15000))
  R.receive(a, b.id, R.payload(b), 18000)
  assert(#R.list(a, 18000) == 1)
  R.stop(b); R.receive(a, b.id, R.payload(b), 19000)
  assert(#R.list(a, 19000) == 0)
end)

test("malformed messages, spoofed self messages, and paused traffic are ignored", function()
  local a = state("TEST01", 1, 3)
  local cases = {false, 2, "bad", {}, {v = 1, t = "s", live = true, n = 1, o = 0},
    {v = 1, t = "s", live = true, n = 1.5, o = 2},
    {v = 1, t = "s", live = "true", n = 1, o = 2},
    {v = 1, t = "s", live = true, n = 1, o = 2, h = "<script>"}}
  for _, msg in ipairs(cases) do assert(not R.receive(a, "TEST02", msg, 0)) end
  assert(not R.receive(a, "../../bad", R.payload(a), 0))
  assert(not R.receive(a, a.id, R.payload(a), 0))
  R.stop(a); assert(not R.receive(a, "TEST02", R.payload(state("TEST02", 1, 2)), 0))
end)

test("peer floods stay bounded without evicting an existing conversation", function()
  local a = state("TEST01", 1, 3)
  for i = 1, 500 do
    R.receive(a, "PEER" .. i, {v = 1, t = "s", live = true, n = 1, o = 3}, 1)
  end
  assert(#R.list(a, 2) == R.capacity and a.peers.PEER1 ~= nil)
end)

test("first launch needs one press, starts private, stops, and never saves sharing", function()
  local a = H.app("apps/shipmates", {}, "TEST01")
  assert(a.paused and #a.sent == 0 and a:contains("Find your people."))
  a:press("select"); assert(not a.paused and a.sent[1].data.live)
  a:press("back"); a:tick(1000); a:press("back")
  assert(a.paused and not a.sent[#a.sent].data.live)
  assert(a:press("back") == false)
  local again = H.app("apps/shipmates", a.saved, "TEST01")
  assert(again.paused and #again.sent == 0)
end)

test("unregistered badge gives an actionable error without broadcasting", function()
  local a = H.app("apps/shipmates", {}, nil)
  a:press("select")
  assert(#a.sent == 0 and a.toast:find("Wi-Fi", 1, true))
end)

test("full app flow handles discovery, hello, invite, expiry, and transmission limits", function()
  local a = H.app("apps/shipmates", {}, "TEST01")
  a:press("select")
  a:receive("TEST02", {v = 1, t = "s", live = true, n = 3, o = 1})
  a:tick(1000); assert(a:contains("1 nearby / 1 matches"))
  a:press("select"); a:press("select")
  a:receive("TEST02", {v = 1, t = "s", live = true, n = 3, o = 1, h = "TEST01"})
  assert(a:contains("MEET ") and a.lights and #a.saved.connections == 1)
  a:press("back"); a:press("right"); assert(a.qr:find("/releases/latest", 1, true))
  a:press("back"); a:tick(15000); assert(a:contains("Listening."))
  for i = 2, #a.sent do assert(a.sent[i].at - a.sent[i - 1].at >= 1000) end
end)

test("meeting codes agree, handles are validated, and stored contacts are bounded", function()
  assert(R.code("TEST01", "TEST02") == R.code("TEST02", "TEST01"))
  assert(R.handle("@valid_user") == "@valid_user")
  for _, bad in ipairs({"@", "@a/b", "@bad?x=1", "<script>", "@toolong012345678901"}) do
    assert(R.handle(bad) == nil)
  end
  local a = H.app("apps/shipmates", {}, "TEST01")
  a.owner = "@valid_user"
  a:press("select"); assert(a.sent[1].data.a == "@valid_user")
  for i = 1, 20 do
    local id = "PEER" .. i
    a:receive(id, {v = 1, t = "s", live = true, n = 3, o = 1, a = "@friend", h = "TEST01"})
  end
  a:tick(1000); a:press("select"); a:press("select")
  assert(a.lights and #a.saved.connections == 1)
  a:press("right"); assert(a.qr == "https://x.com/friend")
  a:press("back"); a:press("back"); a:press("back")
  a:press("up"); a:press("select"); assert(a:contains("Keep the connection."))
  a:press("select"); assert(a.qr == "https://x.com/friend")
  a:press("back"); a:press("left"); assert(a.confirm)
  a.confirm(false); assert(#a.saved.connections == 1)
  a:press("left"); a.confirm(true); assert(#a.saved.connections == 0)
  a:tick(20000); assert(not a.lights)
end)

print("Shipmates: " .. n .. " behavioral tests passed")
