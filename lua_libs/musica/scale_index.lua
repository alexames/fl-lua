-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

ScaleIndex = llx.List{
  first = 0,
  second = 1,
  third = 2,
  fourth = 3,
  fifth = 4,
  sixth = 5,
  seventh = 6,
  octave = 7,
}

return _M
