-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rules for constraining note volumes.
-- @module musica.generation.rules.volume

local llx = require 'llx'
local z3 = require 'z3'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List

local Rule = rule_module.Rule

--- Rule constraining volumes to a specific range.
-- @type VolumeRangeRule
VolumeRangeRule = class 'VolumeRangeRule' : extends(Rule) {
  --- Creates a new VolumeRangeRule.
  -- @tparam VolumeRangeRule self
  -- @tparam table args Configuration table
  -- @tparam number args.min_volume Minimum allowed volume (0.0-1.0)
  -- @tparam number args.max_volume Maximum allowed volume (0.0-1.0)
  -- @tparam[opt='volume_range'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'volume_range'})
    self.min_volume = args.min_volume
    self.max_volume = args.max_volume
  end,

  --- Validates that all volumes are within range.
  -- @tparam VolumeRangeRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all volumes in range
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i, note in ipairs(figure.notes) do
      if note.volume < self.min_volume then
        return false, string.format('Note %d volume %.3f below minimum %.3f',
          i, note.volume, self.min_volume)
      end
      if note.volume > self.max_volume then
        return false, string.format('Note %d volume %.3f above maximum %.3f',
          i, note.volume, self.max_volume)
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam VolumeRangeRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local constraints = List{}
    local min_z3 = ctx:volume_to_z3(self.min_volume)
    local max_z3 = ctx:volume_to_z3(self.max_volume)

    for i, volume_var in ipairs(ctx:get_volume_vars()) do
      constraints:insert(volume_var:ge(min_z3))
      constraints:insert(volume_var:le(max_z3))
    end

    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('VolumeRangeRule{min=%.3f, max=%.3f}',
      self.min_volume, self.max_volume)
  end,
}

--- Rule constraining a specific note to have a specific volume.
-- @type FixedVolumeRule
FixedVolumeRule = class 'FixedVolumeRule' : extends(Rule) {
  --- Creates a new FixedVolumeRule.
  -- @tparam FixedVolumeRule self
  -- @tparam table args Configuration table
  -- @tparam number args.index Note index (1-based)
  -- @tparam number args.volume The required volume (0.0-1.0)
  -- @tparam[opt='fixed_volume'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'fixed_volume'})
    self.index = args.index
    self.volume = args.volume
  end,

  --- Validates that the specified note has the required volume.
  -- @tparam FixedVolumeRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if volume matches
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    if self.index > #figure.notes then
      return false, string.format('Note index %d out of range (figure has %d notes)',
        self.index, #figure.notes)
    end
    local note = figure.notes[self.index]
    if math.abs(note.volume - self.volume) > 0.001 then
      return false, string.format('Note %d volume %.3f != required %.3f',
        self.index, note.volume, self.volume)
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam FixedVolumeRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local volume_var = ctx:volume_at(self.index)
    if not volume_var then
      return nil
    end
    local volume_z3 = ctx:volume_to_z3(self.volume)
    return volume_var:eq(volume_z3)
  end,

  __tostring = function(self)
    return string.format('FixedVolumeRule{index=%d, volume=%.3f}',
      self.index, self.volume)
  end,
}

--- Rule requiring volume to increase or decrease monotonically.
-- Useful for crescendo/decrescendo patterns.
-- @type MonotonicVolumeRule
MonotonicVolumeRule = class 'MonotonicVolumeRule' : extends(Rule) {
  --- Creates a new MonotonicVolumeRule.
  -- @tparam MonotonicVolumeRule self
  -- @tparam table args Configuration table
  -- @tparam boolean args.increasing If true, volume must increase; if false, decrease
  -- @tparam[opt=false] boolean args.strict If true, volumes must strictly increase/decrease
  -- @tparam[opt='monotonic_volume'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'monotonic_volume'})
    self.increasing = args.increasing
    self.strict = args.strict or false
  end,

  --- Validates monotonic volume progression.
  -- @tparam MonotonicVolumeRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if volumes are monotonic
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i = 2, #figure.notes do
      local prev = figure.notes[i-1].volume
      local curr = figure.notes[i].volume
      if self.increasing then
        if self.strict and curr <= prev then
          return false, string.format('Note %d volume %.3f not strictly greater than %.3f',
            i, curr, prev)
        elseif not self.strict and curr < prev then
          return false, string.format('Note %d volume %.3f less than %.3f',
            i, curr, prev)
        end
      else
        if self.strict and curr >= prev then
          return false, string.format('Note %d volume %.3f not strictly less than %.3f',
            i, curr, prev)
        elseif not self.strict and curr > prev then
          return false, string.format('Note %d volume %.3f greater than %.3f',
            i, curr, prev)
        end
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam MonotonicVolumeRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local volume_vars = ctx:get_volume_vars()
    local constraints = List{}

    for i = 2, #volume_vars do
      local prev = volume_vars[i-1]
      local curr = volume_vars[i]
      if self.increasing then
        if self.strict then
          constraints:insert(curr:gt(prev))
        else
          constraints:insert(curr:ge(prev))
        end
      else
        if self.strict then
          constraints:insert(curr:lt(prev))
        else
          constraints:insert(curr:le(prev))
        end
      end
    end

    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    local dir = self.increasing and 'increasing' or 'decreasing'
    local strictness = self.strict and 'strict' or 'non-strict'
    return string.format('MonotonicVolumeRule{%s, %s}', dir, strictness)
  end,
}

return _M
