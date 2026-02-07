-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Generator for musical figures using Z3 constraint solving.
-- The Generator takes a collection of Rules and uses Z3 to find note
-- sequences that satisfy all constraints. It supports both single-solution
-- generation and enumeration of all possible solutions.
-- @module musica.generation.generator

local llx = require 'llx'
local z3 = require 'z3'
local context_module = require 'musica.generation.context'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List
local wrap = llx.coroutine.wrap

local GenerationContext = context_module.GenerationContext

--- Generator for musical figures via constraint solving.
-- @type Generator
Generator = class 'Generator' {
  --- Creates a new Generator.
  -- @tparam Generator self
  -- @tparam table args Configuration table
  -- @tparam[opt] List args.rules List of Rule objects
  -- @tparam[opt] table args.context Context configuration (passed to GenerationContext)
  -- @tparam[opt=100] number args.max_solutions Maximum solutions to enumerate
  __init = function(self, args)
    args = args or {}
    self.rules = List(args.rules or {})
    self.context_args = args.context or {}
    self.max_solutions = args.max_solutions or 100
  end,

  --- Adds a rule to the generator.
  -- @tparam Generator self
  -- @tparam Rule rule The rule to add
  add_rule = function(self, rule)
    self.rules:insert(rule)
  end,

  --- Creates a new generation context and applies all rules.
  -- @tparam Generator self
  -- @treturn GenerationContext The configured context
  _setup_context = function(self)
    local ctx = GenerationContext(self.context_args)

    -- Apply all enabled rules to the context
    for i, rule in ipairs(self.rules) do
      if rule.enabled then
        local constraint = rule:to_z3(ctx)
        if constraint then
          ctx:add_constraint(constraint)
        end
      end
    end

    return ctx
  end,

  --- Generates a single solution.
  -- @tparam Generator self
  -- @treturn Figure|nil A valid figure, or nil if unsatisfiable
  generate_one = function(self)
    local ctx = self:_setup_context()
    local solver = ctx:get_solver()

    local result = solver:check()
    if result == "sat" then
      local model = solver:get_model()
      return ctx:build_figure(model)
    end
    return nil
  end,

  --- Generates all solutions (up to max_solutions).
  -- Returns an iterator that yields (index, figure) pairs.
  -- @tparam Generator self
  -- @treturn function Iterator function
  ['generate_all' | wrap] = function(self)
    local ctx = self:_setup_context()
    local solver = ctx:get_solver()
    local z3_ctx = ctx:get_z3_context()
    local count = 0

    while count < self.max_solutions do
      local result = solver:check()
      if result ~= "sat" then
        break
      end

      local model = solver:get_model()
      local figure = ctx:build_figure(model)

      count = count + 1
      coroutine.yield(count, figure)

      -- Add constraint to exclude this solution
      -- The next solution must differ in at least one variable (pitch, duration, or volume)
      local exclusion = List{}
      for i, pitch_var in ipairs(ctx:get_pitch_vars()) do
        local current_val = model:get_value(pitch_var)
        exclusion:insert(pitch_var:ne(z3_ctx:int_val(current_val)))
      end
      for i, duration_var in ipairs(ctx:get_duration_vars()) do
        local current_val = model:get_value(duration_var)
        exclusion:insert(duration_var:ne(z3_ctx:int_val(current_val)))
      end
      for i, volume_var in ipairs(ctx:get_volume_vars()) do
        local current_val = model:get_value(volume_var)
        exclusion:insert(volume_var:ne(z3_ctx:int_val(current_val)))
      end

      -- At least one variable must be different
      if #exclusion > 0 then
        solver:add(z3.Or(table.unpack(exclusion)))
      else
        break
      end
    end
  end,

  --- Validates a figure against all rules.
  -- @tparam Generator self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all rules pass
  -- @treturn List List of {rule=Rule, error=string} for failed rules
  validate = function(self, figure)
    local failures = List{}
    for i, rule in ipairs(self.rules) do
      if rule.enabled then
        local ok, err = rule:validate(figure)
        if not ok then
          failures:insert({rule = rule, error = err})
        end
      end
    end
    return #failures == 0, failures
  end,

  __tostring = function(self)
    return string.format('Generator{rules=%d, max_solutions=%d}',
      #self.rules, self.max_solutions)
  end,
}

return _M
