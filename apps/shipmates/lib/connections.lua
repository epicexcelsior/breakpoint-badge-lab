local radar = require("lib.radar")
local M = {capacity = 16}

function M.read(raw)
  local list, seen = {}, {}
  if type(raw) ~= "table" then return list end
  for i = 1, M.capacity do
    local item = raw[i]
    if type(item) == "table" and radar.id(item.id) and not seen[item.id]
      and radar.topic(item.need) and radar.topic(item.offer) then
      list[#list + 1] = {id = item.id, name = radar.handle(item.name), need = item.need, offer = item.offer}
      seen[item.id] = true
    end
  end
  return list
end

function M.put(list, id, peer)
  local result = {{id = id, name = peer.name, need = peer.need, offer = peer.offer}}
  for _, item in ipairs(list) do
    if item.id ~= id and #result < M.capacity then result[#result + 1] = item end
  end
  return result
end

return M
