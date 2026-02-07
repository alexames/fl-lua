-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rules for constraining the first and last notes of a figure.
-- @module musica.generation.rules.boundary

local llx = require 'llx'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local tointeger = llx.tointeger

local Rule = rule_module.Rule

--- Rule requiring the first note to have a specific pitch.
-- @type StartOnPitchRule
StartOnPitchRule = class 'StartOnPitchRule' : extends(Rule) {
  --- Creates a new StartOnPitchRule.
  -- @tparam StartOnPitchRule self
  -- @tparam table args Configuration table
  -- @tparam Pitch args.pitch The required starting pitch
  -- @tparam[opt='start_on_pitch'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'start_on_pitch'})
    self.pitch = args.pitch
  end,

  --- Validates that the first note has the required pitch.
  -- @tparam StartOnPitchRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if first note matches
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    if #figure.notes == 0 then
      return false, 'Figure has no notes'
    end
    local first_pitch = figure.notes[1].pitch
    if tointeger(first_pitch) ~= tointeger(self.pitch) then
      return false, string.format('First note is %s, expected %s',
        first_pitch, self.pitch)
    end
    return true
  end,

  --- Converts to Z3 constraint.
  -- @tparam StartOnPitchRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local first_pitch = ctx:pitch_at(1)
    return first_pitch:eq(ctx:pitch_to_z3(self.pitch))
  end,

  __tostring = function(self)
    return string.format('StartOnPitchRule{pitch=%s}', self.pitch)
  end,
}

--- Rule requiring the last note to have a specific pitch.
-- @type EndOnPitchRule
EndOnPitchRule = class 'EndOnPitchRule' : extends(Rule) {
  --- Creates a new EndOnPitchRule.
  -- @tparam EndOnPitchRule self
  -- @tparam table args Configuration table
  -- @tparam Pitch args.pitch The required ending pitch
  -- @tparam[opt='end_on_pitch'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'end_on_pitch'})
    self.pitch = args.pitch
  end,

  --- Validates that the last note has the required pitch.
  -- @tparam EndOnPitchRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if last note matches
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    if #figure.notes == 0 then
      return false, 'Figure has no notes'
    end
    local last_pitch = figure.notes[#figure.notes].pitch
    if tointeger(last_pitch) ~= tointeger(self.pitch) then
      return false, string.format('Last note is %s, expected %s',
        last_pitch, self.pitch)
    end
    return true
  end,

  --- Converts to Z3 constraint.
  -- @tparam EndOnPitchRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local pitch_vars = ctx:get_pitch_vars()
    local last_pitch = pitch_vars[#pitch_vars]
    return last_pitch:eq(ctx:pitch_to_z3(self.pitch))
  end,

  __tostring = function(self)
    return string.format('EndOnPitchRule{pitch=%s}', self.pitch)
  end,
}

return _M
