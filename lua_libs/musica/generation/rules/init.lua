-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Rule submodules for musical generation.
-- @module musica.generation.rules

local llx = require 'llx'

local lock <close> = llx.lock_global_table()

return require 'llx.flatten_submodules' {
  require 'musica.generation.rules.boundary',
  require 'musica.generation.rules.composite',
  require 'musica.generation.rules.duration',
  require 'musica.generation.rules.in_scale',
  require 'musica.generation.rules.interval',
  require 'musica.generation.rules.monotonic',
  require 'musica.generation.rules.overshoot',
  require 'musica.generation.rules.range',
  require 'musica.generation.rules.volume',
}
