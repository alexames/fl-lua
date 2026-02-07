-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'
local util = require 'musica.util'

local _ENV, _M = llx.environment.create_module_environment()

local UniqueSymbol = util.UniqueSymbol

IntervalQuality = {
  major = UniqueSymbol('IntervalQuality.major'),
  minor = UniqueSymbol('IntervalQuality.minor'),
  diminished = UniqueSymbol('IntervalQuality.diminished'),
  augmented = UniqueSymbol('IntervalQuality.augmented'),
  perfect = UniqueSymbol('IntervalQuality.perfect'),
}

return _M
