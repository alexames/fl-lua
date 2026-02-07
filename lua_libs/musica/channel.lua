-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local figure = require 'musica.figure'
local llx = require 'llx'
local note = require 'musica.note'
local tostringf_module = require 'llx.tostringf'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local Figure = figure.Figure
local Note = note.Note
local tostringf = tostringf_module.tostringf
local styles = tostringf_module.styles

FigureInstance = class 'FigureInstance' {
  __init = function(self, time, figure)
    -- check_arguments{self=FigureInstance, time=Number, figure=Figure}
    self.time = time
    self.figure = figure
  end,

  time_adjusted_notes = function(self)
    return function(instance, i)
      i = i + 1
      local note = instance.figure.notes[i]
      return note and i, note and Note{
        pitch = note.pitch,
        time = note.time + instance.time,
        duration = note.duration,
        volume = note.volume,
      }
    end, self, 0
  end,

  __tostringf = function(self, formatter)
    formatter:table_cons 'FigureInstance' {
      {'time', self.time},
      {'figure', self.figure},
    }
  end,

  __tostring = function(self)
    return string.format('FigureInstance(%s, %s)', self.time, self.figure)
  end,
}

Channel = class 'Channel' {
  __init = function(self, instrument, args)
    self.instrument = instrument
    self.figure_instances = llx.List{}
    -- Metadata for sheet music
    args = args or {}
    self.part_name = args.part_name or nil
    self.short_name = args.short_name or nil
    self.clef = args.clef or nil  -- e.g., 'treble', 'bass', 'alto', 'tenor'
    self.transposition = args.transposition or nil  -- For transposing instruments
  end,

  __tostringf = function(self, formatter)
    formatter:table_cons 'Channel' {
      {'instrument', self.instrument},
      {'figure_instances', self.figure_instances},
    }
  end,

  __tostring = function(self)
    return tostringf(self, styles.abbrev)
  end,
}

return _M
