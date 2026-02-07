-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

Direction = {
  down = -1,
  level = 0,
  same = 0,
  up = 1,
}

return _M
