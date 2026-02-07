-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

Accidental = {
  sharp = 1,
  natural = 0,
  flat = -1,
}

return _M
