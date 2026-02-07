-- scale_walk.lua
-- Walks up a C minor scale, then back down.

local scale = { 60, 62, 63, 65, 67, 68, 70, 72 }
local direction = 1
local pos = 1

function on_beat(ctx, beat)
  ctx.note(scale[pos], 80, 0.4)
  ctx.log('Note: ' .. scale[pos])

  pos = pos + direction
  if pos > #scale then
    direction = -1
    pos = #scale
  elseif pos < 1 then
    direction = 1
    pos = 1
  end
end
