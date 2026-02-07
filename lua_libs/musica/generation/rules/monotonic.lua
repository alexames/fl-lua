-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rules for monotonic pitch movement (ascending/descending melodies).
-- @module musica.generation.rules.monotonic

local z3 = require 'z3'
local llx = require 'llx'
local rule_module = require 'musica.generation.rule'
local direction_module = require 'musica.direction'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List
local tointeger = llx.tointeger

local Rule = rule_module.Rule
local Direction = direction_module.Direction

--- Rule requiring pitches to move monotonically (ascending or descending).
-- @type MonotonicPitchRule
MonotonicPitchRule = class 'MonotonicPitchRule' : extends(Rule) {
  --- Creates a new MonotonicPitchRule.
  -- @tparam MonotonicPitchRule self
  -- @tparam table args Configuration table
  -- @tparam[opt=Direction.up] Direction args.direction Up for ascending, down for descending
  -- @tparam[opt=true] boolean args.strict If true, no repeated pitches allowed
  -- @tparam[opt='monotonic'] string args.name Rule name
  __init = function(self, args)
    args = args or {}
    Rule.__init(self, {name = args.name or 'monotonic'})
    self.direction = args.direction or Direction.up
    self.strict = args.strict ~= false
  end,

  --- Validates that pitches move monotonically.
  -- @tparam MonotonicPitchRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if pitches are monotonic
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i = 2, #figure.notes do
      local prev = tointeger(figure.notes[i-1].pitch)
      local curr = tointeger(figure.notes[i].pitch)

      if self.direction == Direction.up then
        if self.strict and curr <= prev then
          return false, string.format('Note %d (%s) not strictly ascending from note %d (%s)',
            i, figure.notes[i].pitch, i-1, figure.notes[i-1].pitch)
        elseif not self.strict and curr < prev then
          return false, string.format('Note %d (%s) not ascending from note %d (%s)',
            i, figure.notes[i].pitch, i-1, figure.notes[i-1].pitch)
        end
      else
        if self.strict and curr >= prev then
          return false, string.format('Note %d (%s) not strictly descending from note %d (%s)',
            i, figure.notes[i].pitch, i-1, figure.notes[i-1].pitch)
        elseif not self.strict and curr > prev then
          return false, string.format('Note %d (%s) not descending from note %d (%s)',
            i, figure.notes[i].pitch, i-1, figure.notes[i-1].pitch)
        end
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam MonotonicPitchRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local constraints = List{}
    local pitch_vars = ctx:get_pitch_vars()

    for i = 2, #pitch_vars do
      local prev = pitch_vars[i-1]
      local curr = pitch_vars[i]

      if self.direction == Direction.up then
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
    local dir = self.direction == Direction.up and 'ascending' or 'descending'
    local strictness = self.strict and 'strict' or 'non-strict'
    return string.format('MonotonicPitchRule{%s, %s}', dir, strictness)
  end,
}

--- Convenience constructor for ascending pitch rule.
-- @tparam[opt] table args Configuration (strict, name)
-- @treturn MonotonicPitchRule An ascending pitch rule
function AscendingPitchRule(args)
  args = args or {}
  args.direction = Direction.up
  args.name = args.name or 'ascending'
  return MonotonicPitchRule(args)
end

--- Convenience constructor for descending pitch rule.
-- @tparam[opt] table args Configuration (strict, name)
-- @treturn MonotonicPitchRule A descending pitch rule
function DescendingPitchRule(args)
  args = args or {}
  args.direction = Direction.down
  args.name = args.name or 'descending'
  return MonotonicPitchRule(args)
end

return _M
