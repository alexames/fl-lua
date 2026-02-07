-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rule for overshoot melodic patterns.
-- An overshoot pattern rises above a target pitch before descending to it,
-- creating an arc-like melodic contour.
-- @module musica.generation.rules.overshoot

local llx = require 'llx'
local z3 = require 'z3'
local rule_module = require 'musica.generation.rule'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List
local tointeger = llx.tointeger

local Rule = rule_module.Rule

--- Rule implementing overshoot pattern: ascend past target, then descend to it.
-- The melody rises above the target pitch, then falls back down.
-- @type OvershootRule
OvershootRule = class 'OvershootRule' : extends(Rule) {
  --- Creates a new OvershootRule.
  -- @tparam OvershootRule self
  -- @tparam table args Configuration table
  -- @tparam Pitch args.source_pitch Starting pitch
  -- @tparam Pitch args.target_pitch Ending pitch (destination)
  -- @tparam[opt=2] number args.overshoot_amount Minimum semitones above target
  -- @tparam[opt] number args.peak_position Fixed position for the peak (1-based index)
  -- @tparam[opt='overshoot'] string args.name Rule name
  __init = function(self, args)
    Rule.__init(self, {name = args.name or 'overshoot'})
    self.source_pitch = args.source_pitch
    self.target_pitch = args.target_pitch
    self.overshoot_amount = args.overshoot_amount or 2
    self.peak_position = args.peak_position
  end,

  --- Validates that the figure follows an overshoot pattern.
  -- @tparam OvershootRule self
  -- @tparam Figure figure The figure to validate
  -- @treturn boolean true if pattern is valid
  -- @treturn string|nil error message if validation fails
  validate = function(self, figure)
    local notes = figure.notes
    if #notes < 3 then
      return false, 'Need at least 3 notes for overshoot pattern'
    end

    local source = tointeger(self.source_pitch)
    local target = tointeger(self.target_pitch)
    local min_peak = target + self.overshoot_amount

    -- Check first note
    if tointeger(notes[1].pitch) ~= source then
      return false, string.format('First note is %s, expected %s',
        notes[1].pitch, self.source_pitch)
    end

    -- Check last note
    if tointeger(notes[#notes].pitch) ~= target then
      return false, string.format('Last note is %s, expected %s',
        notes[#notes].pitch, self.target_pitch)
    end

    -- Find peak
    local peak_idx, peak_val = 1, tointeger(notes[1].pitch)
    for i, note in ipairs(notes) do
      local val = tointeger(note.pitch)
      if val > peak_val then
        peak_val = val
        peak_idx = i
      end
    end

    -- Peak must exceed target by overshoot_amount
    if peak_val < min_peak then
      return false, string.format('Peak (%d) does not overshoot target (%d) by %d semitones',
        peak_val, target, self.overshoot_amount)
    end

    -- Peak must not be first or last
    if peak_idx == 1 or peak_idx == #notes then
      return false, 'Peak cannot be first or last note'
    end

    -- If peak_position is specified, check it matches
    if self.peak_position and peak_idx ~= self.peak_position then
      return false, string.format('Peak at position %d, expected %d',
        peak_idx, self.peak_position)
    end

    return true
  end,

  --- Converts to Z3 constraints.
  -- @tparam OvershootRule self
  -- @tparam GenerationContext ctx The generation context
  -- @treturn z3.expr Z3 constraint expression
  to_z3 = function(self, ctx)
    local z3_ctx = ctx:get_z3_context()
    local pitch_vars = ctx:get_pitch_vars()
    local n = #pitch_vars

    if n < 3 then
      return nil
    end

    local source = ctx:pitch_to_z3(self.source_pitch)
    local target = ctx:pitch_to_z3(self.target_pitch)
    local min_peak = z3_ctx:int_val(tointeger(self.target_pitch) + self.overshoot_amount)

    local constraints = List{}

    -- First note is source
    constraints:insert(pitch_vars[1]:eq(source))

    -- Last note is target
    constraints:insert(pitch_vars[n]:eq(target))

    if self.peak_position then
      -- Fixed peak position
      local peak_var = pitch_vars[self.peak_position]
      constraints:insert(peak_var:ge(min_peak))

      -- Ascending to peak (non-strict to allow repeated notes)
      for i = 2, self.peak_position do
        constraints:insert(pitch_vars[i]:ge(pitch_vars[i-1]))
      end

      -- Descending from peak (non-strict)
      for i = self.peak_position + 1, n do
        constraints:insert(pitch_vars[i]:le(pitch_vars[i-1]))
      end

      return z3.And(table.unpack(constraints))
    else
      -- Peak position is variable - use disjunction over possible positions
      local peak_options = List{}
      for peak_idx = 2, n - 1 do
        local peak_constraints = List{}
        local peak_var = pitch_vars[peak_idx]

        -- This position is >= min_peak
        peak_constraints:insert(peak_var:ge(min_peak))

        -- It's the maximum (no other position is higher)
        for i = 1, n do
          if i ~= peak_idx then
            peak_constraints:insert(pitch_vars[i]:le(peak_var))
          end
        end

        -- Ascending to this peak
        for i = 2, peak_idx do
          peak_constraints:insert(pitch_vars[i]:ge(pitch_vars[i-1]))
        end

        -- Descending from this peak
        for i = peak_idx + 1, n do
          peak_constraints:insert(pitch_vars[i]:le(pitch_vars[i-1]))
        end

        peak_options:insert(z3.And(table.unpack(peak_constraints)))
      end

      constraints:insert(z3.Or(table.unpack(peak_options)))
      return z3.And(table.unpack(constraints))
    end
  end,

  __tostring = function(self)
    return string.format('OvershootRule{source=%s, target=%s, overshoot=%d}',
      self.source_pitch, self.target_pitch, self.overshoot_amount)
  end,
}

return _M
