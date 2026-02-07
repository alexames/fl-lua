-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rules for constraining melodic intervals between consecutive notes.
-- @module musica.generation.rules.interval

local llx = require 'llx'
local z3 = require 'z3'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List
local tointeger = llx.tointeger

local Rule = rule_module.Rule

--- Rule limiting the maximum interval between consecutive notes.
-- @type MaxIntervalRule
MaxIntervalRule = class 'MaxIntervalRule' : extends(Rule) {
  --- Creates a new MaxIntervalRule.
  -- @tparam MaxIntervalRule self
  -- @tparam table args Configuration table
  -- @tparam number args.max_semitones Maximum allowed interval in semitones
  -- @tparam[opt='max_interval'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'max_interval'})
    self.max_semitones = args.max_semitones
  end,

  --- Validates that no interval exceeds the maximum.
  -- @tparam MaxIntervalRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all intervals within limit
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i = 2, #figure.notes do
      local prev = tointeger(figure.notes[i-1].pitch)
      local curr = tointeger(figure.notes[i].pitch)
      local interval = math.abs(curr - prev)
      if interval > self.max_semitones then
        return false, string.format('Interval of %d semitones between notes %d and %d exceeds maximum %d',
          interval, i-1, i, self.max_semitones)
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- Uses the constraint: -max <= (curr - prev) <= max
  -- @tparam MaxIntervalRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local z3_ctx = ctx:get_z3_context()
    local constraints = List{}
    local pitch_vars = ctx:get_pitch_vars()
    local max_val = z3_ctx:int_val(self.max_semitones)

    for i = 2, #pitch_vars do
      local prev = pitch_vars[i-1]
      local curr = pitch_vars[i]
      local diff = curr - prev

      -- diff >= -max and diff <= max
      constraints:insert(diff:ge(-max_val))
      constraints:insert(diff:le(max_val))
    end

    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('MaxIntervalRule{max_semitones=%d}', self.max_semitones)
  end,
}

--- Rule requiring conjunct (stepwise) motion.
-- All intervals must be 2 semitones or less (major second).
-- @type ConjunctMotionRule
ConjunctMotionRule = class 'ConjunctMotionRule' : extends(Rule) {
  --- Creates a new ConjunctMotionRule.
  -- @tparam ConjunctMotionRule self
  -- @tparam[opt] table args Configuration table
  -- @tparam[opt=2] number args.max_step Maximum step size in semitones
  -- @tparam[opt='conjunct_motion'] string args.name Rule name
  __init = function(self, args)
    args = args or {}
    Rule.__init(self, {name = args.name or 'conjunct_motion'})
    self.max_step = args.max_step or 2
  end,

  --- Validates that all motion is conjunct (stepwise).
  -- @tparam ConjunctMotionRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all motion is stepwise
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i = 2, #figure.notes do
      local prev = tointeger(figure.notes[i-1].pitch)
      local curr = tointeger(figure.notes[i].pitch)
      local interval = math.abs(curr - prev)
      if interval > self.max_step then
        return false, string.format('Leap of %d semitones between notes %d and %d (max step: %d)',
          interval, i-1, i, self.max_step)
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam ConjunctMotionRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local z3_ctx = ctx:get_z3_context()
    local constraints = List{}
    local pitch_vars = ctx:get_pitch_vars()
    local max_val = z3_ctx:int_val(self.max_step)

    for i = 2, #pitch_vars do
      local prev = pitch_vars[i-1]
      local curr = pitch_vars[i]
      local diff = curr - prev

      constraints:insert(diff:ge(-max_val))
      constraints:insert(diff:le(max_val))
    end

    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('ConjunctMotionRule{max_step=%d}', self.max_step)
  end,
}

return _M
