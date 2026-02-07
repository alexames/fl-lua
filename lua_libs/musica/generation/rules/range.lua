-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rule for constraining pitch range.
-- @module musica.generation.rules.range

local llx = require 'llx'
local z3 = require 'z3'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List
local tointeger = llx.tointeger

local Rule = rule_module.Rule

--- Rule constraining pitches to a specific range.
-- @type PitchRangeRule
PitchRangeRule = class 'PitchRangeRule' : extends(Rule) {
  --- Creates a new PitchRangeRule.
  -- @tparam PitchRangeRule self
  -- @tparam table args Configuration table
  -- @tparam Pitch|number args.min_pitch Minimum allowed pitch
  -- @tparam Pitch|number args.max_pitch Maximum allowed pitch
  -- @tparam[opt='pitch_range'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'pitch_range'})
    self.min_pitch = tointeger(args.min_pitch)
    self.max_pitch = tointeger(args.max_pitch)
  end,

  --- Validates that all pitches are within range.
  -- @tparam PitchRangeRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all pitches in range
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i, note in ipairs(figure.notes) do
      local pitch_val = tointeger(note.pitch)
      if pitch_val < self.min_pitch then
        return false, string.format('Note %d (%s, MIDI %d) below minimum %d',
          i, note.pitch, pitch_val, self.min_pitch)
      end
      if pitch_val > self.max_pitch then
        return false, string.format('Note %d (%s, MIDI %d) above maximum %d',
          i, note.pitch, pitch_val, self.max_pitch)
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam PitchRangeRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local z3_ctx = ctx:get_z3_context()
    local constraints = List{}

    for i, pitch_var in ipairs(ctx:get_pitch_vars()) do
      constraints:insert(pitch_var:ge(z3_ctx:int_val(self.min_pitch)))
      constraints:insert(pitch_var:le(z3_ctx:int_val(self.max_pitch)))
    end

    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('PitchRangeRule{min=%d, max=%d}',
      self.min_pitch, self.max_pitch)
  end,
}

return _M
