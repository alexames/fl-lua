-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'
local note = require 'musica.note'
local tostringf_module = require 'llx.tostringf'
local tostringf = tostringf_module.tostringf
local styles = tostringf_module.styles

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local Note = note.Note

local FigureArgs = llx.Schema{
  __name='FigureArgs',
  type=llx.Table,
  properties={
    duration={type=llx.Number},
    notes={type=llx.List, items={type=llx.Table}},
    melody={type=llx.List, items={type=llx.Table}},
  },
}

Figure = class 'Figure' {
  __init = function(self, args)
    -- check_arguments{self=Figure, args=FigureArgs}
    self.duration = args.duration
    local notes = args.notes
    local melody = args.melody
    local new_notes = llx.List{}
    if notes then
      for i, note in ipairs(notes) do
        new_notes[i] = Note(note)
      end
    elseif melody then
      local time = 0
      for i, note in ipairs(melody) do
        local new_note = Note(note)
        new_note.time = time
        time = time + new_note.duration
        new_notes[i] = new_note
      end
    end
    self.notes = new_notes
  end,

  apply = function(self, transformation)
    -- check_arguments{self=Figure, transformation=Function}
    return Figure{self.duration, notes=map(self.notes, transformation)}
  end,

  __add = function(self, other)
    -- check_arguments{self=Figure, other=Figure}
    return merge({self, other})
  end,

  __mul = function(self, repetitions)
    -- check_arguments{self=Figure, repetitions=Integer}
    return repeat_figure(self, repetitions)
  end,

  __concat = function(self, other)
    -- check_arguments{self=Figure, other=Figure}
    return concatenate({self, other})
  end,

  __eq = function(self, other)
    -- check_arguments{self=Figure, other=Figure}
    return self.duration == other.duration and self.notes == other.notes
  end,

  __tostringf = function(self, formatter)
    formatter:table_cons 'Figure' {
      {'duration', self.duration},
      {'notes', self.notes, element_style=styles.abbrev},
    }
  end,

  __tostring = function(self)
    -- check_arguments{self=Figure}
    return tostringf(self, styles.abbrev)
  end,
}

function merge(figures)
  local duration = nil
  local result = llx.List{}
  for _, figure in ipairs(figures) do
    if duration == nil then
      duration = figure.duration
    elseif duration ~= figure.duration then
      -- error(Value_error())
    end

    for i, note in ipairs(figure.notes) do
      result:insert(Note(note))
    end
  end
  return Figure{duration=duration, notes=result}
end

function concatenate(figures)
  local offset = 0
  local result = llx.List{}
  for i, figure in ipairs(figures) do
    for j, note in ipairs(figure.notes) do
      new_note = Note(note)
      new_note.time = new_note.time +offset
      result:insert(new_note)
    end
    offset = offset + figure.duration
  end
  return Figure{duration=offset, notes=result}
end

function repeat_figure(figure, repeat_count)
  repeat_count = repeat_count or 2
  return concatenate(llx.List{figure} * repeat_count)
end

function repeat_volta(figure, endings)
  local figures = llx.List{}
  for i, ending in ipairs(endings) do
    figures:extend({figure, ending})
  end
  return concatenate(figures)
end

return _M
