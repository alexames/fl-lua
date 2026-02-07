-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local direction = require 'musica.direction'
local llx = require 'llx'
local note = require 'musica.note'
local scale = require 'musica.scale'
local util = require 'musica.util'

local _ENV, _M = llx.environment.create_module_environment()

-- Only lists whether notes are higher, lower, or the same as previous notes
function directional_contour(melody)
  local contour = List{same}
  for i=2, #melody do
    local previous_note = melody[i-1]
    local next_note = melody[i]
    contour:insert(cmp(next_note.pitch, previous_note.pitch))
  end
  return contour
end

-- Gives series of abitrary indices that represent the relative pitches of the notes
function relative_contour(melody)
  local pitch_set = Set{}
  for i, note in ipairs(melody) do
    pitch_set:insert(tointeger(note.pitch))
  end
  local pitch_list = pitch_set:tolist()
  pitch_list:sort()
  local index_mapping = {}
  for index, key in ipairs(pitch_list) do
    index_mapping[key] = index
  end
  local contour = List{}
  for i, note in ipairs(melody) do
    contour[i] = index_mapping[tointeger(note.pitch)]
  end
  return contour
end

-- Gives the contour of a melody in pitch indices
function pitch_index_contour(melody)
  local contour = List{}
  for i, v in ipairs(melody) do
    contour[i] = tointeger(note.pitch)
  end
  return contour
end

-- Gives the contour of a melody in pitch indices
function scale_index_contour(melody, scale)
  local contour = List{}
  for i, v in ipairs(melody) do
    contour[i] = scale.to_scale_index(note.pitch)
  end
  return contour
end

-- Gives the contour of a melody in pitch indices
function pitch_class_contour(melody)
  local contour = List{}
  for i, v in ipairs(melody) do
    contour[i] = note.pitch.pitch_class
  end
  return contour
end

return _M
