-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rules for constraining note durations.
-- @module musica.generation.rules.duration

local llx = require 'llx'
local z3 = require 'z3'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List

local Rule = rule_module.Rule

--- Rule constraining durations to a specific range.
-- @type DurationRangeRule
DurationRangeRule = class 'DurationRangeRule' : extends(Rule) {
  --- Creates a new DurationRangeRule.
  -- @tparam DurationRangeRule self
  -- @tparam table args Configuration table
  -- @tparam number args.min_duration Minimum allowed duration
  -- @tparam number args.max_duration Maximum allowed duration
  -- @tparam[opt='duration_range'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'duration_range'})
    self.min_duration = args.min_duration
    self.max_duration = args.max_duration
  end,

  --- Validates that all durations are within range.
  -- @tparam DurationRangeRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if all durations in range
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    for i, note in ipairs(figure.notes) do
      if note.duration < self.min_duration then
        return false, string.format('Note %d duration %.3f below minimum %.3f',
          i, note.duration, self.min_duration)
      end
      if note.duration > self.max_duration then
        return false, string.format('Note %d duration %.3f above maximum %.3f',
          i, note.duration, self.max_duration)
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam DurationRangeRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local constraints = List{}
    local min_z3 = ctx:duration_to_z3(self.min_duration)
    local max_z3 = ctx:duration_to_z3(self.max_duration)

    for i, duration_var in ipairs(ctx:get_duration_vars()) do
      constraints:insert(duration_var:ge(min_z3))
      constraints:insert(duration_var:le(max_z3))
    end

    if #constraints == 0 then
      return nil
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    return string.format('DurationRangeRule{min=%.3f, max=%.3f}',
      self.min_duration, self.max_duration)
  end,
}

--- Rule constraining total duration of all notes.
-- @type TotalDurationRule
TotalDurationRule = class 'TotalDurationRule' : extends(Rule) {
  --- Creates a new TotalDurationRule.
  -- @tparam TotalDurationRule self
  -- @tparam table args Configuration table
  -- @tparam[opt] number args.min_total Minimum total duration
  -- @tparam[opt] number args.max_total Maximum total duration
  -- @tparam[opt] number args.exact_total Exact total duration (overrides min/max)
  -- @tparam[opt='total_duration'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'total_duration'})
    self.exact_total = args.exact_total
    self.min_total = args.min_total
    self.max_total = args.max_total
  end,

  --- Validates that total duration is within bounds.
  -- @tparam TotalDurationRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if total duration in range
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    local total = 0
    for i, note in ipairs(figure.notes) do
      total = total + note.duration
    end

    if self.exact_total then
      -- Allow small floating point tolerance
      if math.abs(total - self.exact_total) > 0.001 then
        return false, string.format('Total duration %.3f != exact %.3f',
          total, self.exact_total)
      end
    else
      if self.min_total and total < self.min_total then
        return false, string.format('Total duration %.3f below minimum %.3f',
          total, self.min_total)
      end
      if self.max_total and total > self.max_total then
        return false, string.format('Total duration %.3f above maximum %.3f',
          total, self.max_total)
      end
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam TotalDurationRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local duration_vars = ctx:get_duration_vars()
    if #duration_vars == 0 then
      return nil
    end

    -- Sum all duration variables
    local sum = duration_vars[1]
    for i = 2, #duration_vars do
      sum = sum + duration_vars[i]
    end

    local constraints = List{}

    if self.exact_total then
      local exact_z3 = ctx:duration_to_z3(self.exact_total)
      constraints:insert(sum:eq(exact_z3))
    else
      if self.min_total then
        local min_z3 = ctx:duration_to_z3(self.min_total)
        constraints:insert(sum:ge(min_z3))
      end
      if self.max_total then
        local max_z3 = ctx:duration_to_z3(self.max_total)
        constraints:insert(sum:le(max_z3))
      end
    end

    if #constraints == 0 then
      return nil
    elseif #constraints == 1 then
      return constraints[1]
    end
    return z3.And(table.unpack(constraints))
  end,

  __tostring = function(self)
    if self.exact_total then
      return string.format('TotalDurationRule{exact=%.3f}', self.exact_total)
    else
      return string.format('TotalDurationRule{min=%s, max=%s}',
        self.min_total or 'nil', self.max_total or 'nil')
    end
  end,
}

--- Rule constraining a specific note to have a specific duration.
-- @type FixedDurationRule
FixedDurationRule = class 'FixedDurationRule' : extends(Rule) {
  --- Creates a new FixedDurationRule.
  -- @tparam FixedDurationRule self
  -- @tparam table args Configuration table
  -- @tparam number args.index Note index (1-based)
  -- @tparam number args.duration The required duration
  -- @tparam[opt='fixed_duration'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'fixed_duration'})
    self.index = args.index
    self.duration = args.duration
  end,

  --- Validates that the specified note has the required duration.
  -- @tparam FixedDurationRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if duration matches
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    if self.index > #figure.notes then
      return false, string.format('Note index %d out of range (figure has %d notes)',
        self.index, #figure.notes)
    end
    local note = figure.notes[self.index]
    if math.abs(note.duration - self.duration) > 0.001 then
      return false, string.format('Note %d duration %.3f != required %.3f',
        self.index, note.duration, self.duration)
    end
    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam FixedDurationRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local duration_var = ctx:duration_at(self.index)
    if not duration_var then
      return nil
    end
    local duration_z3 = ctx:duration_to_z3(self.duration)
    return duration_var:eq(duration_z3)
  end,

  __tostring = function(self)
    return string.format('FixedDurationRule{index=%d, duration=%.3f}',
      self.index, self.duration)
  end,
}

return _M
