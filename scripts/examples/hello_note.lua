-- hello_note.lua
-- Plays middle C (MIDI note 60) on every beat.

function on_beat(ctx, beat)
    ctx.note(60, 100, 0.5)  -- pitch=C4, velocity=100, duration=0.5 beats
    ctx.log("Beat " .. beat .. ": C4")
end
