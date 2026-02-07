-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Composite rules for combining multiple rules.
-- Provides logical operators (AND, OR, NOT) over rules.
-- @module musica.generation.rules.composite

local llx = require 'llx'
local z3 = require 'z3'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List

local Rule = rule_module.Rule

--- Composite rule that requires ALL child rules to pass.
-- @type AllOfRule
AllOfRule = class 'AllOfRule' : extends(Rule) {
  --- Creates a new AllOfRule.
  -- @tparam AllOfRule self
  -- @tparam table args Configuration table
  -- @tparam[opt] List args.rules List of rules that must all pass
  -- @tparam[opt='all_of'] string args.name Rule name
  __init = function(self, args)
    args = args or {}
    Rule.__init(self, {name = args.name or 'all_of'})
    self.rules = List(args.rules or {})
  end,

  --- Adds a rule to the collection.
  -- @tparam AllOfRule self
  -- @tparam Rule rule The rule to add
  add = function(self, rule)
    self.rules:insert(rule)
  end,

  --- Validates that ALL child rules pass.
  -- @tparam AllOfRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all rules pass
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i, child_rule in ipairs(self.rules) do
      if child_rule.enabled then
        local ok, err = child_rule:validate(figure)
        if not ok then
          return false, string.format('%s failed: %s', child_rule.name, err)
        end
      end
    end
    return true
  end,

  --- Converts to Z3 constraint (conjunction of all child constraints).
  -- @tparam AllOfRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local constraints = List{}
    for i, child_rule in ipairs(self.rules) do
      if child_rule.enabled then
        local c = child_rule:to_z3(ctx)
        if c then
          constraints:insert(c)
        end
      end
    end
    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('AllOfRule{%d rules}', #self.rules)
  end,
}

--- Composite rule that requires ANY child rule to pass.
-- @type AnyOfRule
AnyOfRule = class 'AnyOfRule' : extends(Rule) {
  --- Creates a new AnyOfRule.
  -- @tparam AnyOfRule self
  -- @tparam table args Configuration table
  -- @tparam[opt] List args.rules List of rules where at least one must pass
  -- @tparam[opt='any_of'] string args.name Rule name
  __init = function(self, args)
    args = args or {}
    Rule.__init(self, {name = args.name or 'any_of'})
    self.rules = List(args.rules or {})
  end,

  --- Adds a rule to the collection.
  -- @tparam AnyOfRule self
  -- @tparam Rule rule The rule to add
  add = function(self, rule)
    self.rules:insert(rule)
  end,

  --- Validates that at least one child rule passes.
  -- @tparam AnyOfRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if any rule passes
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i, child_rule in ipairs(self.rules) do
      if child_rule.enabled then
        local ok, _ = child_rule:validate(figure)
        if ok then
          return true
        end
      end
    end
    return false, 'No child rules passed'
  end,

  --- Converts to Z3 constraint (disjunction of child constraints).
  -- @tparam AnyOfRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local constraints = List{}
    for i, child_rule in ipairs(self.rules) do
      if child_rule.enabled then
        local c = child_rule:to_z3(ctx)
        if c then
          constraints:insert(c)
        end
      end
    end
    if #constraints == 0 then
      return nil
    end
    return z3.Or(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('AnyOfRule{%d rules}', #self.rules)
  end,
}

--- Composite rule that negates a child rule.
-- @type NotRule
NotRule = class 'NotRule' : extends(Rule) {
  --- Creates a new NotRule.
  -- @tparam NotRule self
  -- @tparam table args Configuration table
  -- @tparam Rule args.rule The rule to negate
  -- @tparam[opt='not'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'not'})
    self.child = args.rule
  end,

  --- Validates that the child rule FAILS.
  -- @tparam NotRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if child rule fails
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    local ok, _ = self.child:validate(figure)
    if ok then
      return false, string.format('Child rule %s should have failed', self.child.name)
    end
    return true
  end,

  --- Converts to Z3 constraint (negation of child constraint).
  -- @tparam NotRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local c = self.child:to_z3(ctx)
    if c then
      return z3.Not(c)
    end
    return nil
  end,

  __tostring = function(self)
    return string.format('NotRule{%s}', self.child.name)
  end,
}

return _M
