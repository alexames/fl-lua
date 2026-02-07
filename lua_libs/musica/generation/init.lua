-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- Generation module for procedural music creation using Z3 constraint solving.
-- @module musica.generation

local llx = require 'llx'

local lock <close> = llx.lock_global_table()

return require 'llx.flatten_submodules' {
  require 'musica.generation.context',
  require 'musica.generation.generator',
  require 'musica.generation.rule',
  require 'musica.generation.rules',
}
