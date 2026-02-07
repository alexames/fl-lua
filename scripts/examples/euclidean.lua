-- euclidean.lua
-- Generates a Euclidean rhythm pattern.
-- Distributes `hits` pulses as evenly as possible across `steps` steps.

local hits = 5
local steps = 8
local note = 60
local pattern = {}

-- Generate Euclidean rhythm via Bjorklund's algorithm
local function euclidean(h, s)
  local result = {}
  local bucket = 0
  for i = 1, s do
    bucket = bucket + h
    if bucket >= s then
      bucket = bucket - s
      result[i] = true
    else
      result[i] = false
    end
  end
  return result
end

pattern = euclidean(hits, steps)

local step = 0

function on_beat(ctx, beat)
  step = (beat % steps) + 1
  if pattern[step] then
    ctx.note(note, 100, 0.25)
  end
end
