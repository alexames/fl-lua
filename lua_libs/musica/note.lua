-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'
local pitch = require 'musica.pitch'
local tostringf_module = require 'llx.tostringf'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local Pitch = pitch.Pitch
local tostringf = tostringf_module.tostringf
local styles = tostringf_module.styles

local NoteArgs = llx.Schema{
  __name='NoteArgs',
  type=llx.Table,
  properties={
    -- pitch={type=llx.Union{Pitch,llx.Integer}},
    time={type=llx.Number},
    duration={type=llx.Number},
    volume={type=llx.Number},
  },
}

--- A note, with a pitch, time, duration and volume
Note = class 'Note' {
  --- Initializes a Note.
  __init = function(self, arg)
    -- llx.check_arguments{self=Note, arg=NoteArgs}
    self.pitch = arg.pitch
    self.time = arg.time
    self.duration = arg.duration
    self.volume = arg.volume or 1.0
  end,

  --- Adjust the duration so that the note finishes at the given time.
  set_finish = function(self, finish)
    -- llx.check_arguments{self=Note, finish=Number}
    self.duration = finish - self.time
  end,

  --- Returns the time at which the note terminates.
  finish = function(self)
    -- llx.check_arguments{self=Note}
    return self.time + self.duration
  end,

  --- Check equality of two notes.
  __eq = function(self, other)
    llx.check_arguments{self=Note, other=Note}
    return self.pitch == other.pitch
           and self.time == other.time
           and self.duration == other.duration
           and self.volume == other.volume
  end,
  
  __tostringf = function(self, formatter)
    formatter:table_cons 'Note' {
      {'pitch', self.pitch},
      {'time', self.time},
      {'duration', self.duration},
      {'volume', self.volume},
    }
  end,

  --- Returns a string representation of the note.
  __tostring = function(self)
    return tostringf(self, styles.abbrev)
  end,
}

return _M
