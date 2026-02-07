-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Generation context managing Z3 variables and music mappings.
-- The GenerationContext bridges between musical concepts (Pitch, Note, Figure)
-- and Z3 constraint solving. It creates Z3 variables for each note position
-- and handles conversion between music objects and Z3 values.
-- @module musica.generation.context

-- Require z3 before llx to avoid strict mode conflicts
local z3 = require 'z3'
local llx = require 'llx'

-- Require individual musica modules to avoid circular dependency
-- (musica.init now includes musica.generation)
local figure_module = require 'musica.figure'
local note_module = require 'musica.note'
local pitch_module = require 'musica.pitch'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List
local tointeger = llx.tointeger

local Figure = figure_module.Figure
local Note = note_module.Note
local Pitch = pitch_module.Pitch

--- Generation context for Z3 constraint solving.
-- Manages Z3 variables for pitch, duration, and volume of each note position.
-- @type GenerationContext
GenerationContext = class 'GenerationContext' {
  --- Creates a new GenerationContext.
  -- @tparam GenerationContext self
  -- @tparam table args Configuration table
  -- @tparam number args.num_notes Number of notes to generate
  -- @tparam[opt=1000] number args.duration_precision Multiplier for duration (Z3 uses integers)
  -- @tparam[opt=1000] number args.volume_precision Multiplier for volume (Z3 uses integers)
  __init = function(self, args)
    args = args or {}
    self.z3_ctx = z3.Context()
    self.solver = z3.Solver(self.z3_ctx)

    -- Configuration
    self.num_notes = args.num_notes or 8
    -- Precision multipliers for converting floats to integers
    -- Duration and volume are stored as integers: real_value * precision
    self.duration_precision = args.duration_precision or 1000
    self.volume_precision = args.volume_precision or 1000

    -- Z3 variables for each note position
    self.pitch_vars = List{}
    self.duration_vars = List{}
    self.volume_vars = List{}

    -- Create variables
    self:_create_variables()
  end,

  --- Creates Z3 variables for each note position.
  -- @tparam GenerationContext self
  _create_variables = function(self)
    for i = 1, self.num_notes do
      -- Pitch as integer (MIDI number)
      local pitch_var = self.z3_ctx:int_const(string.format("pitch_%d", i))
      self.pitch_vars:insert(pitch_var)

      -- Duration as integer (real duration * precision)
      local duration_var = self.z3_ctx:int_const(string.format("duration_%d", i))
      self.duration_vars:insert(duration_var)
      -- Duration must be positive
      self.solver:add(duration_var:gt(self.z3_ctx:int_val(0)))

      -- Volume as integer (real volume * precision, range 0-1 maps to 0-precision)
      local volume_var = self.z3_ctx:int_const(string.format("volume_%d", i))
      self.volume_vars:insert(volume_var)
      -- Volume must be in range [0, precision] (maps to [0.0, 1.0])
      self.solver:add(volume_var:ge(self.z3_ctx:int_val(0)))
      self.solver:add(volume_var:le(self.z3_ctx:int_val(self.volume_precision)))
    end
  end,

  --- Gets the Z3 context.
  -- @tparam GenerationContext self
  -- @treturn z3.Context The Z3 context
  get_z3_context = function(self)
    return self.z3_ctx
  end,

  --- Gets the Z3 solver.
  -- @tparam GenerationContext self
  -- @treturn z3.Solver The Z3 solver
  get_solver = function(self)
    return self.solver
  end,

  --- Gets pitch variable at index (1-based).
  -- @tparam GenerationContext self
  -- @tparam number index 1-based index
  -- @treturn z3.expr The Z3 integer variable for pitch at this position
  pitch_at = function(self, index)
    return self.pitch_vars[index]
  end,

  --- Gets all pitch variables.
  -- @tparam GenerationContext self
  -- @treturn List List of Z3 integer variables
  get_pitch_vars = function(self)
    return self.pitch_vars
  end,

  --- Gets duration variable at index (1-based).
  -- @tparam GenerationContext self
  -- @tparam number index 1-based index
  -- @treturn z3.expr The Z3 integer variable for duration at this position
  duration_at = function(self, index)
    return self.duration_vars[index]
  end,

  --- Gets all duration variables.
  -- @tparam GenerationContext self
  -- @treturn List List of Z3 integer variables
  get_duration_vars = function(self)
    return self.duration_vars
  end,

  --- Gets volume variable at index (1-based).
  -- @tparam GenerationContext self
  -- @tparam number index 1-based index
  -- @treturn z3.expr The Z3 integer variable for volume at this position
  volume_at = function(self, index)
    return self.volume_vars[index]
  end,

  --- Gets all volume variables.
  -- @tparam GenerationContext self
  -- @treturn List List of Z3 integer variables
  get_volume_vars = function(self)
    return self.volume_vars
  end,

  --- Gets the number of notes.
  -- @tparam GenerationContext self
  -- @treturn number Number of note positions
  get_num_notes = function(self)
    return self.num_notes
  end,

  --- Gets the duration precision multiplier.
  -- @tparam GenerationContext self
  -- @treturn number The precision multiplier
  get_duration_precision = function(self)
    return self.duration_precision
  end,

  --- Gets the volume precision multiplier.
  -- @tparam GenerationContext self
  -- @treturn number The precision multiplier
  get_volume_precision = function(self)
    return self.volume_precision
  end,

  --- Adds a constraint to the solver.
  -- @tparam GenerationContext self
  -- @tparam z3.expr constraint The Z3 constraint to add
  add_constraint = function(self, constraint)
    self.solver:add(constraint)
  end,

  --- Converts a Pitch to a Z3 integer value.
  -- @tparam GenerationContext self
  -- @tparam Pitch pitch The pitch to convert
  -- @treturn z3.expr Z3 integer literal
  pitch_to_z3 = function(self, pitch)
    return self.z3_ctx:int_val(tointeger(pitch))
  end,

  --- Creates a Z3 integer value.
  -- @tparam GenerationContext self
  -- @tparam number value The integer value
  -- @treturn z3.expr Z3 integer literal
  int_val = function(self, value)
    return self.z3_ctx:int_val(value)
  end,

  --- Converts a Z3 model integer value to a Pitch.
  -- @tparam GenerationContext self
  -- @tparam number value The MIDI note number
  -- @treturn Pitch The corresponding pitch
  z3_to_pitch = function(self, value)
    return Pitch{midi_index = value}
  end,

  --- Converts a duration Z3 value to a real number.
  -- @tparam GenerationContext self
  -- @tparam number value The Z3 integer value
  -- @treturn number The real duration
  z3_to_duration = function(self, value)
    return value / self.duration_precision
  end,

  --- Converts a real duration to a Z3 integer value.
  -- @tparam GenerationContext self
  -- @tparam number duration The real duration
  -- @treturn z3.expr Z3 integer literal
  duration_to_z3 = function(self, duration)
    return self.z3_ctx:int_val(math.floor(duration * self.duration_precision + 0.5))
  end,

  --- Converts a volume Z3 value to a real number.
  -- @tparam GenerationContext self
  -- @tparam number value The Z3 integer value
  -- @treturn number The real volume (0.0-1.0)
  z3_to_volume = function(self, value)
    return value / self.volume_precision
  end,

  --- Converts a real volume to a Z3 integer value.
  -- @tparam GenerationContext self
  -- @tparam number volume The real volume (0.0-1.0)
  -- @treturn z3.expr Z3 integer literal
  volume_to_z3 = function(self, volume)
    return self.z3_ctx:int_val(math.floor(volume * self.volume_precision + 0.5))
  end,

  --- Builds a Figure from the current Z3 model.
  -- @tparam GenerationContext self
  -- @tparam z3.Model model The Z3 model with solution values
  -- @treturn Figure A figure with notes matching the solution
  build_figure = function(self, model)
    local notes = List{}
    local time = 0

    for i = 1, self.num_notes do
      local pitch_val = model:get_value(self.pitch_vars[i])
      local pitch = self:z3_to_pitch(pitch_val)

      local duration_val = model:get_value(self.duration_vars[i])
      local duration = self:z3_to_duration(duration_val)

      local volume_val = model:get_value(self.volume_vars[i])
      local volume = self:z3_to_volume(volume_val)

      local note = Note{
        pitch = pitch,
        time = time,
        duration = duration,
        volume = volume,
      }
      notes:insert(note)
      time = time + duration
    end

    return Figure{duration = time, notes = notes}
  end,

  __tostring = function(self)
    return string.format('GenerationContext{num_notes=%d}', self.num_notes)
  end,
}

return _M
