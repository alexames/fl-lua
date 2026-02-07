-- arpeggiator.lua
-- Arpeggiates through a C major chord.

local chord = { 60, 64, 67, 72 } -- C E G C
local i = 0

function on_beat(ctx, beat)
  i = (i % #chord) + 1
  ctx.note(chord[i], 90, 0.25)
end
