-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Base class for musical generation rules.
-- Rules define constraints on musical sequences. They can validate existing
-- Figures and generate Z3 constraints for the Generator to solve.
-- @module musica.generation.rule

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class

--- Abstract base class for musical rules.
-- Rules have two primary functions:
-- 1. Validate a Figure to check if it satisfies the rule
-- 2. Convert to Z3 constraints for use in generation
-- @type Rule
Rule = class 'Rule' {
  --- Creates a new Rule.
  -- @tparam Rule self
  -- @tparam table args Configuration table
  -- @tparam[opt='unnamed_rule'] string args.name Name for this rule
  -- @tparam[opt=true] boolean args.enabled Whether rule is active
  __init = function(self, args)
    args = args or {}
    self.name = args.name or 'unnamed_rule'
    self.enabled = args.enabled ~= false
  end,

  --- Validates a Figure against this rule.
  -- Must be overridden in subclasses.
  -- @tparam Rule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if the figure satisfies the rule
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    error('Rule:validate must be overridden in subclass')
  end,

  --- Converts this rule to Z3 constraints.
  -- Must be overridden in subclasses.
  -- @tparam Rule self
  -- @tparam GenerationContext ctx The generation context with Z3 variables
  -- @treturn expr|nil Z3 constraint expression, or nil if no constraint
  to_z3 = function(self, ctx)
    error('Rule:to_z3 must be overridden in subclass')
  end,

  __tostring = function(self)
    return string.format('Rule<%s>', self.name)
  end,
}

return _M
