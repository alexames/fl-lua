-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

local enum_module = require 'llx.enum'
local enum = enum_module.enum

--- Articulation enum representing different ways to play notes
Articulation = enum {
  -- Normal articulation (no modification)
  'normal',
  
  -- Staccato: Short, detached (50% duration)
  'staccato',
  
  -- Staccatissimo: Very short, very detached (25% duration)
  'staccatissimo',
  
  -- Legato: Smooth, connected (100% duration, overlapping)
  'legato',
  
  -- Tenuto: Full value, slight emphasis (100% duration, +10% volume)
  'tenuto',
  
  -- Accent: Emphasized (100% duration, +20% volume)
  'accent',
  
  -- Marcato: Strongly accented (100% duration, +40% volume)
  'marcato',
  
  -- Portato/Mezzo-staccato: Half-detached (75% duration)
  'portato',
}

--- Get duration multiplier for an articulation
-- @param articulation Articulation enum value
-- @return Duration multiplier (0.0 to 1.0)
function get_duration_multiplier(articulation)
  if articulation == Articulation.staccato then
    return 0.5
  elseif articulation == Articulation.staccatissimo then
    return 0.25
  elseif articulation == Articulation.portato then
    return 0.75
  else
    -- normal, legato, tenuto, accent, marcato all use full duration
    return 1.0
  end
end

--- Get volume multiplier for an articulation
-- @param articulation Articulation enum value
-- @return Volume multiplier (1.0 = no change)
function get_volume_multiplier(articulation)
  if articulation == Articulation.tenuto then
    return 1.1  -- +10%
  elseif articulation == Articulation.accent then
    return 1.2  -- +20%
  elseif articulation == Articulation.marcato then
    return 1.4  -- +40%
  else
    return 1.0  -- No change
  end
end

--- Apply articulation to a note
-- Modifies the note's duration and volume based on articulation
-- @param note Note object to modify
-- @param articulation Articulation enum value
function apply_to_note(note, articulation)
  local duration_mult = get_duration_multiplier(articulation)
  local volume_mult = get_volume_multiplier(articulation)
  
  note.duration = note.duration * duration_mult
  note.volume = math.min(1.0, note.volume * volume_mult)
  note.articulation = articulation
end

--- Apply articulation to all notes in a figure
-- @param figure Figure object
-- @param articulation Articulation enum value
function apply_to_figure(figure, articulation)
  for _, note in ipairs(figure.notes) do
    apply_to_note(note, articulation)
  end
end

--- Get human-readable description of articulation
-- @param articulation Articulation enum value
-- @return String description
function describe(articulation)
  if articulation == Articulation.staccato then
    return 'Staccato (short, detached)'
  elseif articulation == Articulation.staccatissimo then
    return 'Staccatissimo (very short)'
  elseif articulation == Articulation.legato then
    return 'Legato (smooth, connected)'
  elseif articulation == Articulation.tenuto then
    return 'Tenuto (held, slight emphasis)'
  elseif articulation == Articulation.accent then
    return 'Accent (emphasized)'
  elseif articulation == Articulation.marcato then
    return 'Marcato (strongly accented)'
  elseif articulation == Articulation.portato then
    return 'Portato (half-detached)'
  else
    return 'Normal'
  end
end

return _M