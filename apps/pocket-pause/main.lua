local session = require("lib.session")
local s = session.new(storage.get("settings"))
local title, phase, clock, progress, note
local painted = -1000

local function save()
  storage.set("settings", {mode = s.mode, choice = s.choice})
end

local function show()
  local word, value = session.frame(s)
  phase:text(word)
  progress:set(math.floor(value))
  local remaining = math.max(0, math.ceil((session.duration(s) - s.elapsed) / 1000))
  clock:text(string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60))
  title:text(s.mode == 1 and "Breathe" or "Focus")
  note:text(s.finished and "A small reset. Carry it with you."
    or (s.started and (s.lights and "RIGHT turns lights off" or "RIGHT adds soft lights")
    or "UP mode / LEFT & RIGHT duration"))
  ui.hint(s.finished and "SELECT again  BACK settings"
    or (s.started and (s.running and "SELECT pause  BACK stop" or "SELECT resume  BACK stop")
    or "SELECT start  CANCEL exit"))
  if s.lights and s.running then
    local light = math.floor(value * 0.4)
    led.fill(math.floor(light * 0.3), math.floor(light * 0.7), light)
  else led.off() end
end

ui.bg("bg")
title = ui.label(12, 8, "", {size = 20, color = "aqua"})
phase = ui.label(12, 53, "", {size = 32, w = 296})
clock = ui.label(12, 103, "", {size = 32, mono = true})
progress = ui.bar(12, 154, 296, 8, 0)
note = ui.label(12, 174, "", {size = 12, color = "dim", w = 296})
show()

function on_key(key, rep)
  if key == "select" and not rep then
    session.toggle(s)
    print("pause: " .. (s.running and "running" or "paused"))
  elseif key == "back" then
    if not s.started then return false end
    session.reset(s)
    print("pause: reset")
  elseif s.started and key == "right" then s.lights = not s.lights
  elseif not s.started then
    if key == "up" or key == "down" then s.mode = 3 - s.mode; save()
    elseif key == "left" or key == "right" then
      s.choice = (s.choice - 1 + (key == "right" and 1 or -1)) % 3 + 1
      save()
    end
  end
  show()
  return true
end

function on_tick(ms)
  if session.step(s, ms) then print("pause: complete") end
  if sys.millis() - painted >= 100 then painted = sys.millis(); show() end
end

function on_exit() led.off() end

print("pause: ready")
