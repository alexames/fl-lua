-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rhythm representation and operations.
-- Provides utilities for working with rhythmic patterns and note durations.
-- @module musica.rhythm

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List

--- Rhythm class representing a sequence of note durations.
-- @type Rhythm
Rhythm = class 'Rhythm' {
  --- Constructor.
  -- @function Rhythm:__init
  -- @tparam Rhythm self
  -- @tparam table args Table with 'durations' (list of numbers)
  __init = function(self, args)
    if type(args) == 'table' and args.durations then
      self.durations = List(args.durations)
    elseif type(args) == 'table' and #args > 0 then
      -- Allow Rhythm{1, 0.5, 0.5} shorthand
      self.durations = List(args)
    else
      self.durations = List{}
    end
  end,

  --- Get total duration of the rhythm
  -- @return Sum of all durations
  total_duration = function(self)
    local total = 0
    for _, duration in ipairs(self.durations) do
      total = total + duration
    end
    return total
  end,

  --- Augment rhythm (multiply all durations by factor).
  -- @function Rhythm:augment
  -- @tparam Rhythm self
  -- @tparam number factor Multiplication factor
  -- @treturn Rhythm New Rhythm with augmented durations
  augment = function(self, factor)
    local new_durations = List{}
    for _, duration in ipairs(self.durations) do
      new_durations:insert(duration * factor)
    end
    return Rhythm{durations = new_durations}
  end,

  --- Diminish rhythm (divide all durations by factor).
  -- @function Rhythm:diminish
  -- @tparam Rhythm self
  -- @tparam number factor Division factor
  -- @treturn Rhythm New Rhythm with diminished durations
  diminish = function(self, factor)
    return self:augment(1.0 / factor)
  end,

  --- Repeat rhythm n times.
  -- @function Rhythm:repeat_pattern
  -- @tparam Rhythm self
  -- @tparam number n Number of repetitions
  -- @treturn Rhythm New Rhythm with repeated pattern
  repeat_pattern = function(self, n)
    local new_durations = List{}
    for i = 1, n do
      for _, duration in ipairs(self.durations) do
        new_durations:insert(duration)
      end
    end
    return Rhythm{durations = new_durations}
  end,

  --- Reverse rhythm
  -- @return New Rhythm with reversed durations
  retrograde = function(self)
    local new_durations = List{}
    for i = #self.durations, 1, -1 do
      new_durations:insert(self.durations[i])
    end
    return Rhythm{durations = new_durations}
  end,

  __tostring = function(self)
    local duration_strs = {}
    for i, duration in ipairs(self.durations) do
      table.insert(duration_strs, tostring(duration))
    end
    return string.format('Rhythm{%s}', table.concat(duration_strs, ', '))
  end,
}

-- Common note durations (in quarter note units)
whole_note = 4.0
half_note = 2.0
quarter_note = 1.0
eighth_note = 0.5
sixteenth_note = 0.25
thirty_second_note = 0.125

-- Dotted note durations
dotted_whole = whole_note * 1.5      -- 6.0
dotted_half = half_note * 1.5        -- 3.0
dotted_quarter = quarter_note * 1.5  -- 1.5
dotted_eighth = eighth_note * 1.5    -- 0.75

-- Triplet note durations (divide by 3 instead of 2)
quarter_triplet = quarter_note * 2 / 3  -- 0.667
eighth_triplet = eighth_note * 2 / 3    -- 0.333
sixteenth_triplet = sixteenth_note * 2 / 3  -- 0.167

-- Common rhythmic patterns
common_patterns = {
  -- Simple patterns
  whole = Rhythm{whole_note},
  half_half = Rhythm{half_note, half_note},
  four_quarters = Rhythm{quarter_note, quarter_note, quarter_note, quarter_note},
  eight_eighths = Rhythm{eighth_note, eighth_note, eighth_note, eighth_note,
                        eighth_note, eighth_note, eighth_note, eighth_note},
  
  -- Dotted patterns
  dotted_quarter_eighth = Rhythm{dotted_quarter, eighth_note},
  
  -- Syncopated patterns
  eighth_quarter_eighth = Rhythm{eighth_note, quarter_note, eighth_note},
  
  -- Triplet patterns
  quarter_triplets = Rhythm{quarter_triplet, quarter_triplet, quarter_triplet},
}

return _M
