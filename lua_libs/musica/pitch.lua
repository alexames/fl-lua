-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Pitch representation for musical notes.
-- A Pitch represents an absolute musical pitch, combining a pitch class
-- (A-G), octave number, and any accidentals (sharps/flats).
-- Pitches support arithmetic: adding a PitchInterval to a Pitch yields
-- a new Pitch, and subtracting two Pitches yields a PitchInterval.
-- @module musica.pitch

local accidental = require 'musica.accidental'
local llx = require 'llx'
local pitch_class = require 'musica.pitch_class'
local pitch_interval = require 'musica.pitch_interval'
local pitch_util = require 'musica.pitch_util'
local tostringf_module = require 'llx.tostringf'

local _ENV, _M = llx.environment.create_module_environment()

local Accidental = accidental.Accidental
local class = llx.class
local isinstance = llx.isinstance
local List = llx.List
local minor_pitch_intervals = pitch_util.minor_pitch_intervals
local PitchClass = pitch_class.PitchClass
local PitchInterval = pitch_interval.PitchInterval
local tointeger = llx.tointeger
local zip = llx.functional.zip
local tostringf = tostringf_module.tostringf
local styles = tostringf_module.styles

--- The octave number for middle C (C4).
local middle_octave = 4

--- MIDI note numbers for octave 0 of each pitch class.
-- Standard MIDI defines middle C (C4) as note 60.
-- Octave numbering starts from C, so C0=12, D0=14, ..., A0=21, B0=23.
local lowest_pitch_indices = {
  [PitchClass.C] = 12,
  [PitchClass.D] = 14,
  [PitchClass.E] = 16,
  [PitchClass.F] = 17,
  [PitchClass.G] = 19,
  [PitchClass.A] = 21,
  [PitchClass.B] = 23,
}

--- Represents an absolute musical pitch.
-- A Pitch combines a pitch class (A-G), octave, and accidentals to
-- represent a specific frequency. Pitches can be compared, added to
-- intervals, and converted to/from MIDI note numbers.
-- @type Pitch
Pitch = class 'Pitch' {
  --- Creates a new Pitch.
  -- Can be constructed from pitch_class/octave/accidentals, from a
  -- pitch_index (MIDI-like absolute number), or from a midi_index.
  -- @function Pitch:__init
  -- @tparam Pitch self
  -- @tparam table args Table with construction parameters
  -- @tparam[opt] PitchClass args.pitch_class PitchClass (A-G)
  -- @tparam[opt=4] number args.octave Octave number (default: 4 for middle octave)
  -- @tparam[opt=0] number args.accidentals Number of semitones sharp (+) or flat (-)
  -- @tparam[opt] number args.pitch_index Absolute pitch as integer (alternative to above)
  -- @tparam[opt] number args.midi_index MIDI note number (alternative, 0-127)
  -- @usage
  -- local c4 = Pitch{pitch_class=PitchClass.C, octave=4}
  -- local fsharp3 = Pitch{pitch_class=PitchClass.F, octave=3, accidentals=1}
  -- local from_midi = Pitch{midi_index=60}  -- Middle C
  __init = function(self, args)
    local pitch_class = args.pitch_class
    local octave = args.octave or middle_octave
    local accidentals = args.accidentals or 0
    local pitch_index = args.pitch_index
    local midi_index = args.midi_index
    if midi_index then
      local pitch_classes = {
        [0] = PitchClass.C, PitchClass.C,
        PitchClass.D, PitchClass.D,
        PitchClass.E,
        PitchClass.F, PitchClass.F,
        PitchClass.G, PitchClass.G,
        PitchClass.A, PitchClass.A,
        PitchClass.B,
      }
      pitch_index = midi_index
      pitch_class = pitch_classes[midi_index % 12]
      -- Octave is calculated from C (MIDI 12 = C0)
      octave = (midi_index - lowest_pitch_indices[PitchClass.C]) // 12
    end
    self.pitch_class = pitch_class
    self.octave = octave
    if pitch_index then
      local natural_pitch = lowest_pitch_indices[pitch_class] + (self.octave * 12)
      self.accidentals = pitch_index - natural_pitch
    else
      self.accidentals = accidentals
    end
  end,

  --- Checks if two pitches are enharmonically equivalent.
  -- Two pitches are enharmonic if they sound the same (same MIDI number)
  -- but may be spelled differently (e.g., C# and Db).
  -- @function Pitch:is_enharmonic
  -- @tparam Pitch self
  -- @tparam Pitch other Another Pitch to compare
  -- @treturn boolean true if enharmonically equivalent
  -- @usage
  -- local csharp = Pitch{pitch_class=PitchClass.C, accidentals=1}
  -- local dflat = Pitch{pitch_class=PitchClass.D, accidentals=-1}
  -- csharp:is_enharmonic(dflat)  -- true
  is_enharmonic = function(self, other)
    return tointeger(self) == tointeger(other)
  end,

  --- Converts the pitch to an integer (MIDI note number).
  -- @return MIDI note number (0-127 for standard range)
  __tointeger = function(self)
    return lowest_pitch_indices[self.pitch_class]
           + (self.octave * 12)
           + self.accidentals
  end,

  --- Checks equality of two pitches.
  -- Pitches are equal if they have the same MIDI note number.
  -- @function Pitch:__eq
  -- @tparam Pitch self
  -- @tparam Pitch other Another Pitch
  -- @treturn boolean true if equal
  __eq = function(self, other)
    return tointeger(self) == tointeger(other)
  end,

  --- Less-than comparison.
  -- @function Pitch:__lt
  -- @tparam Pitch self
  -- @tparam Pitch other Another Pitch
  -- @treturn boolean true if self is lower than other
  __lt = function(self, other)
    return tointeger(self) < tointeger(other)
  end,

  --- Less-than-or-equal comparison.
  -- @function Pitch:__le
  -- @tparam Pitch self
  -- @tparam Pitch other Another Pitch
  -- @treturn boolean true if self is lower than or equal to other
  __le = function(self, other)
    return tointeger(self) <= tointeger(other)
  end,

  --- Adds a PitchInterval to this pitch.
  -- @function Pitch:__add
  -- @tparam Pitch self
  -- @tparam PitchInterval pitch_interval The interval to add
  -- @treturn Pitch A new Pitch that is the given interval above this one
  -- @usage
  -- local c4 = Pitch.c4
  -- local e4 = c4 + PitchInterval.major_third
  __add = function(self, pitch_interval)
    local pitch_class = PitchClass[(self.pitch_class.index + pitch_interval.number - 1) % 7 + 1]
    local octave = math.floor(self.octave + (self.pitch_class.index + pitch_interval.number - 1) / 7)
    local pitch_index = tointeger(self) + tointeger(pitch_interval)
    return Pitch{pitch_class=pitch_class,
                 octave=octave,
                 pitch_index=pitch_index}
  end,

  --- Subtracts a Pitch or PitchInterval.
  -- If subtracting a Pitch, returns the PitchInterval between them.
  -- If subtracting a PitchInterval, returns a new lower Pitch.
  -- @function Pitch:__sub
  -- @tparam Pitch self
  -- @tparam Pitch|PitchInterval other A Pitch or PitchInterval
  -- @treturn PitchInterval|Pitch PitchInterval (if Pitch) or Pitch (if PitchInterval)
  -- @usage
  -- local c4 = Pitch.c4
  -- local e4 = Pitch.e4
  -- local interval = e4 - c4  -- major third
  -- local a3 = c4 - PitchInterval.minor_third
  __sub = function(self, other)
    self, other = llx.metamethod_args(Pitch, self, other)
    if isinstance(other, Pitch) then
      local self_pitch_class_octave = (self.pitch_class.index - 1) + self.octave * 7
      local other_pitch_class_octave = (other.pitch_class.index - 1) + other.octave * 7
      return PitchInterval{number=self_pitch_class_octave - other_pitch_class_octave,
                           semitone_interval=tointeger(self) - tointeger(other)}
    elseif isinstance(other, PitchInterval) then
      local pitch_class = PitchClass[(self.pitch_class.index - other.number - 1) % 7 + 1]
      local octave = self.octave + math.floor((self.pitch_class.index - other.number - 1) / 7)
      local pitch_index = tointeger(self) - tointeger(other)
      return Pitch{pitch_class=pitch_class,
                   pitch_index=pitch_index}
    end
  end,

  --- Formats the pitch for the tostringf system.
  -- @function Pitch:__tostringf
  -- @tparam Pitch self
  -- @tparam StringFormatter formatter The StringFormatter to use
  __tostringf = function(self, formatter)
    if lowest_pitch_indices[PitchClass.A] <= tointeger(self)
        and tointeger(self) < 128
        and Accidental.flat <= self.accidentals
        and self.accidentals <= Accidental.sharp then
      local pitch_class_name = self.pitch_class.name:lower()
      local accidental = ''
      if self.accidentals == Accidental.flat then
        accidental = 'flat'
      elseif self.accidentals == Accidental.sharp then
        accidental = 'sharp'
      end
      formatter:module_class_field(
        'musica', 'Pitch',
        pitch_class_name .. accidental .. tostring(self.octave))
    end

    formatter:table_cons{'musica', 'Pitch'} {
      {'pitch_class', self.pitch_class},
      {'octave', self.octave},
      {'accidentals', self.accidentals}
    }
  end,

  --- Returns a string representation of the pitch.
  -- @return String like "Pitch.c4" or "Pitch.fsharp3"
  __tostring = function(self)
    return tostringf(self, styles.abbrev)
  end,
}

-- Generate named pitch constants (Pitch.c4, Pitch.csharp4, etc.)
-- for all pitches in the MIDI range (0-127).
local current_pitch = lowest_pitch_indices[PitchClass.A]
local current_octave = 0
local accidental_args = {
  {suffix='', accidental=Accidental.natural},
  {suffix='flat', accidental=Accidental.flat},
  {suffix='sharp', accidental=Accidental.sharp},
}

local pitch_classes = List{
  PitchClass.A,
  PitchClass.B,
  PitchClass.C,
  PitchClass.D,
  PitchClass.E,
  PitchClass.F,
  PitchClass.G,
}
while current_pitch < 128 do
  for i, pitch_class, interval in zip(pitch_classes, minor_pitch_intervals) do
    for unused, args in ipairs(accidental_args) do
      local pitch_name = pitch_class.name:lower() .. args.suffix .. current_octave
      Pitch[pitch_name] = Pitch{pitch_class=pitch_class,
                                octave=current_octave,
                                accidentals=args.accidental}
    end
    current_pitch = current_pitch + interval
  end
  current_octave = current_octave + 1
end

return _M
