-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Chord representation and operations.
-- A Chord consists of a root pitch and a quality (the pattern of intervals).
-- Chords can be constructed from explicit pitches or from a root and quality.
-- Supports inversions, arpeggiation, and pitch extraction.
-- @module musica.chord

local llx = require 'llx'
local figure = require 'musica.figure'
local note = require 'musica.note'
local pitch = require 'musica.pitch'
local pitch_interval = require 'musica.pitch_interval'
local quality = require 'musica.quality'
local util = require 'musica.util'

local _ENV, _M = llx.environment.create_module_environment()

local Any = llx.Any
local check_arguments = llx.check_arguments
local class = llx.class
local Figure = figure.Figure
local Function = llx.Function
local Integer = llx.Integer
local List = llx.List
local map = llx.functional.map
local multi_index = util.multi_index
local Note = note.Note
local Number = llx.Number
local Optional = llx.Optional
local Pitch = pitch.Pitch
local PitchInterval = pitch_interval.PitchInterval
local Quality = quality.Quality
local range = llx.functional.range
local Schema = llx.Schema
local Table = llx.Table
local Union = llx.Union

--- Schema for constructing a chord from explicit pitches.
local ChordByPitches = Schema{
  __name='ChordByPitches',
  type=Table,
  properties={
    pitches={
      type=List,
      items={type=Pitch},
    },
  },
  required={'pitches'},
}

--- Schema for constructing a chord from root and quality.
local ChordByRootQuality = Schema{
  __name='ChordByRootQuality',
  type=Table,
  properties={
    root={type=Pitch},
    quality={type=Quality},
  },
  required={'root', 'quality'},
}

--- Combined schema for chord construction arguments.
local ChordArgs = Schema{
  __name='ChordArgs',
  type=Union{ChordByPitches, ChordByRootQuality},
}

--- Represents a musical chord.
-- A chord is defined by its root pitch and quality (the pattern of intervals
-- that define the chord type, e.g., major, minor, diminished).
-- @type Chord
Chord = class 'Chord' {
  --- Creates a new Chord.
  -- Can be constructed either from a list of pitches or from a root and quality.
  -- @function Chord:__init
  -- @tparam Chord self
  -- @tparam table args Construction arguments
  -- @tparam[opt] List args.pitches List of Pitch objects (derives root and quality)
  -- @tparam[opt] Pitch args.root Root Pitch of the chord
  -- @tparam[opt] Quality args.quality Quality defining the chord type (default: major)
  -- @usage
  -- local c_major = Chord{root=Pitch.c4, quality=Quality.major}
  -- local from_pitches = Chord{pitches=List{Pitch.c4, Pitch.e4, Pitch.g4}}
  __init = function(self, args)
    check_arguments{self=Chord, args=ChordArgs}
    if args.pitches then
      self.root = args.pitches[1]
      self.quality = Quality{pitches=args.pitches}
    else
      self.root = args.root
      self.quality = args.quality or Quality.major
    end
  end,

  --- Gets all pitches in the chord.
  -- @return List of Pitch objects
  get_pitches = function(self)
    check_arguments{self=Chord}
    return self:to_pitches(range(0, #self-1))
  end,

  --- Gets the chord's quality.
  -- @return Quality object
  get_quality = function(self)
    check_arguments{self=Chord}
    return self.quality
  end,

  --- Converts a chord index to a pitch.
  -- @function Chord:to_pitch
  -- @tparam Chord self
  -- @tparam number chord_index Zero-based index into the chord
  -- @treturn Pitch Pitch at that index
  to_pitch = function(self, chord_index)
    check_arguments{self=Chord, chord_index=Integer}
    return self.root + self.quality[chord_index + 1]
  end,

  --- Converts multiple chord indices to pitches.
  -- @function Chord:to_pitches
  -- @tparam Chord self
  -- @tparam List scale_indices List of zero-based indices
  -- @treturn List List of Pitch objects
  to_pitches = function(self, scale_indices)
    check_arguments{self=Chord,
                    scale_indices=Schema{type=List,
                                         items={type=Integer}}}
    return map(function(scale_index)
      return self:to_pitch(scale_index)
    end, scale_indices)
  end,

  --- Gets a pitch at an extended index (wrapping through octaves).
  -- Indices beyond the chord size wrap around with octave transposition.
  -- @function Chord:to_extended_pitch
  -- @tparam Chord self
  -- @tparam number chord_index The extended index
  -- @tparam[opt] PitchInterval extension_interval Interval for octave extension (default: octave)
  -- @treturn Pitch Pitch at the extended index
  to_extended_pitch = function(self, chord_index, extension_interval)
    check_arguments{self=Chord,
                    chord_index=Integer,
                    extension_interval=Optional{PitchInterval}}
    local extension_interval = extension_interval or PitchInterval.octave
    return self.root + util.extended_index(chord_index,
                                           self.quality.pitch_intervals,
                                           extension_interval)
  end,

  --- Converts multiple extended indices to pitches.
  -- @function Chord:to_extended_pitches
  -- @tparam Chord self
  -- @tparam List chord_indices List of extended indices
  -- @tparam[opt] PitchInterval extension_interval Interval for octave extension (default: octave)
  -- @treturn List List of Pitch objects
  to_extended_pitches = function(self, chord_indices, extension_interval)
    check_arguments{self=Chord,
                    chord_indices=Schema{type=Any, items={type=Integer}},
                    extension_interval=Optional{PitchInterval}}
    extension_interval = extension_interval or PitchInterval.octave
    return map(function(chord_index)
      return self:to_extended_pitch(chord_index, extension_interval)
    end, chord_indices)
  end,

  --- Creates an inversion of the chord.
  -- An inversion moves the lowest n notes up by an octave.
  -- @function Chord:inversion
  -- @tparam Chord self
  -- @tparam number n The inversion number (0 = root position, 1 = first inversion, etc.)
  -- @tparam[opt] PitchInterval octave_interval Interval for octave (default: PitchInterval.octave)
  -- @treturn Chord New Chord in the specified inversion
  -- @usage
  -- local c_major = Chord{root=Pitch.c4, quality=Quality.major}
  -- local first_inv = c_major:inversion(1)  -- E in bass
  inversion = function(self, n, octave_interval)
    check_arguments{self=Chord,
                    n=Integer,
                    octave_interval=Optional{Integer}}
    octave_interval = octave_interval or PitchInterval.octave
    if n == 0 then
      return self
    end

    local inverted_intervals = List{}
    for i=1, #self do
      local index = n + i - 1
      local octave_index = index // #self
      local octave_offset = octave_interval * octave_index
      inverted_intervals[i] = self.quality[index % #self + 1] + octave_offset
    end
    return Chord{root=self.root + inverted_intervals[1],
                 quality=Quality{pitch_intervals=inverted_intervals}}
  end,

  --- Checks if the chord contains a specific pitch.
  -- @function Chord:contains
  -- @tparam Chord self
  -- @tparam Pitch pitch The Pitch to check
  -- @treturn boolean true if the chord contains the pitch
  contains = function(self, pitch)
    check_arguments{self=Chord, pitch=Pitch}
    return self:get_pitches():find(pitch) ~= nil
  end,

  --- Checks equality of two chords.
  -- @function Chord:__eq
  -- @tparam Chord self
  -- @tparam Chord other Another Chord
  -- @treturn boolean true if root and quality are equal
  __eq = function(self, other)
    check_arguments{self=Chord, other=Chord}
    return self.root == other.root and self.quality == other.quality
  end,

  --- Combines chords or adds a bass note (slash chord).
  -- @function Chord:__div
  -- @tparam Chord self
  -- @tparam Pitch|Chord other A Pitch (for slash chord) or another Chord
  -- @treturn Chord New Chord combining all pitches
  -- @usage
  -- local c_over_g = c_major / Pitch.g3  -- C/G slash chord
  __div = function(self, other)
    check_arguments{self=Chord, other=Union{Pitch,Chord}}
    local other_pitches
    if isinstance(other, Pitch) then
      other_pitches = List{other}
    else
      other_pitches = other:get_pitches()
    end

    local pitches = self:get_pitches()
    pitches = pitches .. other_pitches
    pitches:sort()
    return Chord{pitches=pitches}
  end,

  --- Returns the number of notes in the chord.
  -- @return Number of pitches
  __len = function(self)
    check_arguments{self=Chord}
    return #self.quality
  end,

  --- Allows indexing the chord to get pitches.
  -- @param index Zero-based index
  -- @return Pitch at that index
  __index = multi_index(function(self, index)
    return self:to_pitch(index)
  end),

  --- Returns a string representation of the chord.
  -- @return String like "Chord{root=Pitch.c4, quality=Quality.major}"
  __tostring = function(self)
    check_arguments{self=Chord}
    return string.format('Chord{root=%s, quality=%s}', self.root, self.quality)
  end,
}

--- Creates an arpeggiated figure from a chord.
-- Generates a sequence of notes playing the chord tones in order.
-- @param args Arpeggiation parameters
-- @param args.chord The Chord to arpeggiate
-- @param args.duration Note duration (default: 1.0)
-- @param args.time_step Time between notes (default: same as duration)
-- @param args.volume Note volume
-- @param args.index_pattern Custom pattern of chord indices
-- @param args.index_pattern_fn Function to generate index pattern
-- @param args.count Number of notes if using pattern function
-- @param args.figure_duration Total duration of the figure
-- @param args.extension_interval Interval for extending beyond chord size
-- @return Figure containing the arpeggiated notes
-- @usage
-- local arp = arpeggiate{chord=c_major, duration=0.25, time_step=0.25}
function arpeggiate(args)
  check_arguments{
    args=Schema{
      type=Table,
      properties={
        chord={type=Chord},
        duration={type=Number},
        index_pattern_fn={type=Function},
        index_pattern={type=Union{Table,Function}},
        time_step={type=Number},
        volume={type=Number},
        count={type=Integer},
        figure_duration={type=Number},
        extension_interval={type=PitchInterval},
      }
    }
  }
  local chord = args.chord
  local duration = args.duration or 1.0
  local index_pattern = args.index_pattern
  local time_step = args.time_step or duration
  local volume = args.volume
  local figure_duration = args.figure_duration
  local extension_interval = args.extension_interval or PitchInterval.octave

  local chord_indices
  local count
  if index_pattern then
    chord_indices = index_pattern
  else
    local index_pattern_fn = args.index_pattern_fn or range
    count = args.count or #chord
    chord_indices = List(index_pattern_fn(count))
  end

  local pitches = chord:to_extended_pitches(chord_indices)
  local notes = List{}
  for i, pitch in ipairs(pitches) do
    notes[i] = Note{pitch=pitch, time=(i - 1) * time_step, duration=duration, volume=volume}
  end

  if figure_duration == nil then
    figure_duration = 0
    for i, note in ipairs(notes) do
      local note_end = note.time + note.duration
      if note_end > figure_duration then
        figure_duration = note_end
      end
    end
  end
  return Figure{duration=figure_duration, notes=notes}
end

return _M
