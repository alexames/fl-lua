-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

ScaleDegree = llx.List{
  tonic = 0,
  supertonic = 1,
  mediant = 2,
  subdominant = 3,
  dominant = 4,
  submediant = 5,
  leading_tone = 6,
}

return _M
