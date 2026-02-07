-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Tempo representation and operations.
-- Provides utilities for working with musical tempo markings and BPM.
-- @module musica.tempo

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class

-- Tempo markings with typical BPM ranges
local tempo_markings = {
  grave = {min = 25, max = 45, typical = 35},
  largo = {min = 40, max = 60, typical = 50},
  lento = {min = 45, max = 60, typical = 53},
  larghetto = {min = 60, max = 66, typical = 63},
  adagio = {min = 66, max = 76, typical = 71},
  adagietto = {min = 70, max = 80, typical = 75},
  andante = {min = 76, max = 108, typical = 92},
  andantino = {min = 80, max = 108, typical = 94},
  moderato = {min = 108, max = 120, typical = 114},
  allegretto = {min = 112, max = 120, typical = 116},
  allegro = {min = 120, max = 156, typical = 138},
  vivace = {min = 156, max = 176, typical = 166},
  presto = {min = 168, max = 200, typical = 184},
  prestissimo = {min = 200, max = 240, typical = 220},
}

--- Tempo class representing musical tempo.
-- @type Tempo
Tempo = class 'Tempo' {
  --- Constructor.
  -- @function Tempo:__init
  -- @tparam Tempo self
  -- @tparam table|number args Table with 'bpm' (number) or 'marking' (string), or just a number for BPM
  __init = function(self, args)
    if type(args) == 'number' then
      -- Allow Tempo(120) shorthand
      self.bpm = args
      self.marking = nil
    elseif args.bpm then
      self.bpm = args.bpm
      self.marking = args.marking
    elseif args.marking then
      local marking_lower = args.marking:lower()
      local marking_data = tempo_markings[marking_lower]
      if not marking_data then
        error(string.format('Unknown tempo marking: %s', args.marking), 2)
      end
      self.bpm = marking_data.typical
      self.marking = marking_lower
    else
      error('Tempo requires either bpm or marking', 2)
    end
  end,

  --- Get tempo in microseconds per beat (for MIDI)
  -- @return Microseconds per quarter note
  get_microseconds_per_beat = function(self)
    return math.floor(60000000 / self.bpm)
  end,

  --- Get tempo marking name if set
  -- @return Tempo marking string or nil
  get_marking = function(self)
    return self.marking
  end,

  --- Get human-readable tempo description
  -- @return String describing the tempo
  describe = function(self)
    if self.marking then
      return string.format('%s (%d BPM)', self.marking:gsub('^%l', string.upper), self.bpm)
    else
      return string.format('%d BPM', self.bpm)
    end
  end,

  --- Check if BPM is within range for a tempo marking.
  -- @function Tempo:is_in_range
  -- @tparam Tempo self
  -- @tparam string marking Tempo marking name
  -- @treturn boolean true if BPM is in range
  is_in_range = function(self, marking)
    local marking_lower = marking:lower()
    local marking_data = tempo_markings[marking_lower]
    if not marking_data then
      return false
    end
    return self.bpm >= marking_data.min and self.bpm <= marking_data.max
  end,

  __tostring = function(self)
    return self:describe()
  end,
}

-- Common tempo constants
grave = Tempo{marking = 'grave'}
largo = Tempo{marking = 'largo'}
lento = Tempo{marking = 'lento'}
larghetto = Tempo{marking = 'larghetto'}
adagio = Tempo{marking = 'adagio'}
adagietto = Tempo{marking = 'adagietto'}
andante = Tempo{marking = 'andante'}
andantino = Tempo{marking = 'andantino'}
moderato = Tempo{marking = 'moderato'}
allegretto = Tempo{marking = 'allegretto'}
allegro = Tempo{marking = 'allegro'}
vivace = Tempo{marking = 'vivace'}
presto = Tempo{marking = 'presto'}
prestissimo = Tempo{marking = 'prestissimo'}

return _M
