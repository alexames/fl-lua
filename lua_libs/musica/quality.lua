-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'
local pitch = require 'musica.pitch'
local pitch_interval = require 'musica.pitch_interval'
local util = require 'musica.util'

local _ENV, _M = llx.environment.create_module_environment()

local multi_index = util.multi_index
local Pitch = pitch.Pitch
local PitchInterval = pitch_interval.PitchInterval

local QualityByPitches = llx.Schema{
  __name='QualityByPitches',
  type=llx.Table,
  properties={
    pitches={
      type=llx.List,
      items={type=Pitch},
    },
    name={type=llx.String},
  },
  required={'pitches'},
}

local QualityByPitchIntervals = llx.Schema{
  __name='QualityByPitchIntervals',
  type=llx.Table,
  properties={
    pitch_intervals={
      type=llx.List,
      items={type=PitchInterval},
    },
    name={type=llx.String},
  },
  required={'pitch_intervals'},
}

-- local QualityArgumentsSchema = llx.Schema{
--   __name='QualityArgumentsSchema',
--   type=llx.Union{QualityByPitches, QualityByPitchIntervals},
-- }

Quality = llx.class 'Quality' {
  __init = function(self, args)
    -- llx.check_arguments{self=Quality, args=QualityArgumentsSchema}
    self.name = args.name
    local pitch_intervals = args.pitch_intervals
    local pitches = args.pitches
    if pitch_intervals and pitch_intervals[1] ~= PitchInterval.unison then
      local first_interval = pitch_intervals[1]
      for i, interval in ipairs(pitch_intervals) do
        pitch_intervals[i] = interval - first_interval
      end
    elseif pitches then
      pitch_intervals = llx.List{}
      pitches:sort()
      local first_pitch = pitches[1]
      for i, pitch in ipairs(pitches) do
        pitch_intervals[i] = pitch - first_pitch
      end
    end
    self.pitch_intervals = pitch_intervals
  end,

  __index = multi_index(function(self, index)
    return self.pitch_intervals[index]
  end),

  __eq = function(self, other)
    return self.pitch_intervals == other.pitch_intervals
  end;

  __len = function(self)
    return #self.pitch_intervals
  end;

  __tostring = function(self)
    if self == Quality.major then
      return "Quality.major"
    elseif self == Quality.minor then
      return "Quality.minor"
    elseif self == Quality.augmented then
      return "Quality.augmented"
    elseif self == Quality.diminished then
      return "Quality.diminished"
    end
    return string.format("Quality{pitch_intervals=%s}", self.pitch_intervals)
  end;
}

Quality.major = Quality{pitch_intervals=llx.List{PitchInterval.unison, PitchInterval.major_third, PitchInterval.perfect_fifth}}
Quality.minor = Quality{pitch_intervals=llx.List{PitchInterval.unison, PitchInterval.minor_third, PitchInterval.perfect_fifth}}
Quality.augmented = Quality{pitch_intervals=llx.List{PitchInterval.unison, PitchInterval.major_third, PitchInterval.augmented_fifth}}
Quality.diminished = Quality{pitch_intervals=llx.List{PitchInterval.unison, PitchInterval.minor_third, PitchInterval.diminished_fifth}}

return _M
