-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Time signature representation and operations.
-- Provides utilities for working with musical time signatures.
-- @module musica.time_signature

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class

--- TimeSignature class representing musical time signature.
-- @type TimeSignature
TimeSignature = class 'TimeSignature' {
  --- Constructor.
  -- @function TimeSignature:__init
  -- @tparam TimeSignature self
  -- @tparam table args Table with 'numerator' and 'denominator'
  __init = function(self, args)
    if type(args) == 'table' and args.numerator and args.denominator then
      self.numerator = args.numerator
      self.denominator = args.denominator
    else
      error('TimeSignature requires numerator and denominator', 2)
    end
    
    -- Validate
    if self.numerator <= 0 then
      error('Numerator must be positive', 2)
    end
    if not self:_is_power_of_two(self.denominator) then
      error('Denominator must be a power of 2', 2)
    end
  end,

  --- Check if a number is a power of 2
  _is_power_of_two = function(self, n)
    return n > 0 and (n & (n - 1)) == 0
  end,

  --- Check if this is simple meter (beats divide into 2)
  -- @return true if simple meter
  is_simple = function(self)
    return self.numerator % 3 ~= 0 or self.numerator == 3
  end,

  --- Check if this is compound meter (beats divide into 3)
  -- @return true if compound meter
  is_compound = function(self)
    return self.numerator % 3 == 0 and self.numerator > 3
  end,

  --- Get the number of beats per measure
  -- For compound meter, this is numerator / 3
  -- For simple meter, this is numerator
  -- @return Number of beats
  get_beats_per_measure = function(self)
    if self:is_compound() then
      return self.numerator / 3
    else
      return self.numerator
    end
  end,

  --- Get the note value that gets one beat
  -- For compound meter (6/8, 9/8, etc.), this is dotted quarter
  -- For simple meter (4/4, 3/4, etc.), this is the denominator
  -- @return Beat unit as duration
  get_beat_unit = function(self)
    if self:is_compound() then
      -- In compound meter, beat is dotted (3 subdivisions)
      return (4.0 / self.denominator) * 1.5
    else
      return 4.0 / self.denominator
    end
  end,

  --- Get meter classification (duple, triple, quadruple)
  -- @return String: 'duple', 'triple', or 'quadruple'
  get_meter_type = function(self)
    local beats = self:get_beats_per_measure()
    if beats == 2 then
      return 'duple'
    elseif beats == 3 then
      return 'triple'
    elseif beats == 4 then
      return 'quadruple'
    else
      return 'irregular'
    end
  end,

  --- Get full meter description
  -- @return String like "Simple Duple" or "Compound Triple"
  describe = function(self)
    local meter_class = self:is_simple() and 'Simple' or 'Compound'
    local meter_type = self:get_meter_type()
    return string.format('%s %s (%d/%d)', 
                        meter_class, 
                        meter_type:gsub('^%l', string.upper),
                        self.numerator,
                        self.denominator)
  end,

  __tostring = function(self)
    return string.format('%d/%d', self.numerator, self.denominator)
  end,

  __eq = function(self, other)
    return self.numerator == other.numerator and self.denominator == other.denominator
  end,
}

-- Common time signatures
common_time = TimeSignature{numerator = 4, denominator = 4}  -- 4/4
cut_time = TimeSignature{numerator = 2, denominator = 2}     -- 2/2 (alla breve)
waltz_time = TimeSignature{numerator = 3, denominator = 4}   -- 3/4
march_time = TimeSignature{numerator = 2, denominator = 4}   -- 2/4

-- Compound time signatures
compound_duple = TimeSignature{numerator = 6, denominator = 8}      -- 6/8
compound_triple = TimeSignature{numerator = 9, denominator = 8}     -- 9/8
compound_quadruple = TimeSignature{numerator = 12, denominator = 8} -- 12/8

return _M
