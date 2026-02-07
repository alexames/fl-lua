-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rule requiring all pitches to be in a given scale.
-- @module musica.generation.rules.in_scale

local z3 = require 'z3'
local llx = require 'llx'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List
local tointeger = llx.tointeger

local Rule = rule_module.Rule
-- Note: Scale is received as a parameter, no need to import it

--- Rule requiring all pitches to be within a specific scale.
-- Uses modular arithmetic (pitch % 12) to check scale membership
-- across all octaves.
-- @type InScaleRule
InScaleRule = class 'InScaleRule' : extends(Rule) {
  --- Creates a new InScaleRule.
  -- @tparam InScaleRule self
  -- @tparam table args Configuration table
  -- @tparam Scale args.scale The scale to constrain pitches to
  -- @tparam[opt='in_scale'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'in_scale'})
    self.scale = args.scale
  end,

  --- Validates that all notes in a figure are in the scale.
  -- @tparam InScaleRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all notes are in scale
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i, note in ipairs(figure.notes) do
      if not self.scale:contains(note.pitch) then
        return false, string.format('Note %d (%s) not in scale %s',
          i, note.pitch, self.scale)
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- For each pitch variable, constrains pitch % 12 to be one of the
  -- valid pitch classes in the scale.
  -- @tparam InScaleRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local z3_ctx = ctx:get_z3_context()
    local constraints = List{}

    -- Get all valid pitch classes in the scale (mod 12 for octave equivalence)
    local scale_pitches = self.scale:get_pitches()
    local valid_pitch_classes = List{}
    for i, pitch in ipairs(scale_pitches) do
      local pc = tointeger(pitch) % 12
      if not valid_pitch_classes:contains(pc) then
        valid_pitch_classes:insert(pc)
      end
    end

    -- For each note position, pitch % 12 must equal one of the valid pitch classes
    for i, pitch_var in ipairs(ctx:get_pitch_vars()) do
      local valid_options = List{}
      for j, pc in ipairs(valid_pitch_classes) do
        -- (pitch_var % 12) == pc
        local mod_expr = pitch_var - (pitch_var / z3_ctx:int_val(12)) * z3_ctx:int_val(12)
        valid_options:insert(mod_expr:eq(z3_ctx:int_val(pc)))
      end

      if #valid_options > 0 then
        constraints:insert(z3.Or(table.unpack(valid_options)))
      end
    end

    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('InScaleRule{scale=%s}', self.scale)
  end,
}

return _M
