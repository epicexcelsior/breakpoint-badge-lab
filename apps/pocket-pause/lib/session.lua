local M = {}
M.durations = {{1, 3, 5}, {5, 15, 25}}

function M.new(saved)
  saved = type(saved) == "table" and saved or {}
  local mode = saved.mode == 2 and 2 or 1
  local choice = type(saved.choice) == "number" and saved.choice == math.floor(saved.choice)
    and saved.choice >= 1 and saved.choice <= 3 and saved.choice or 1
  return {mode = mode, choice = choice, elapsed = 0, running = false,
    started = false, finished = false, lights = false}
end

function M.duration(s) return M.durations[s.mode][s.choice] * 60000 end

function M.step(s, ms)
  if not s.running then return false end
  if type(ms) ~= "number" or ms ~= ms or ms < 0 then return false end
  s.elapsed = math.min(M.duration(s), s.elapsed + ms)
  if s.elapsed >= M.duration(s) then
    s.running = false; s.finished = true
    return true
  end
  return false
end

function M.toggle(s)
  if s.finished then s.elapsed = 0; s.finished = false; s.started = false end
  s.running = not s.running
  s.started = true
end

function M.reset(s)
  s.elapsed = 0; s.running = false; s.started = false; s.finished = false
end

function M.frame(s)
  if s.finished then return "Done", 100 end
  if s.started and not s.running then return "Paused", 0 end
  if not s.started then return s.mode == 1 and "Take a moment." or "Make some space.", 0 end
  if s.mode == 2 then return "Focus", s.elapsed / M.duration(s) * 100 end
  local phase = s.elapsed % 10000
  if phase < 4000 then return "Breathe in", phase / 4000 * 100 end
  return "Breathe out", (10000 - phase) / 6000 * 100
end

return M
