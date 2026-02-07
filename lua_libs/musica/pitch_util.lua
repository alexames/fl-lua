-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'
local spiral = require 'musica.spiral'
local util = require 'musica.util'

local _ENV, _M = llx.environment.create_module_environment()

local intervals_to_indices = util.intervals_to_indices
local List = llx.List
local Spiral = spiral.Spiral

major_pitch_intervals = List{2, 2, 1, 2, 2, 2, 1}
major_pitch_indices = Spiral(intervals_to_indices(major_pitch_intervals))
minor_pitch_intervals = List{2, 1, 2, 2, 1, 2, 2}
minor_pitch_indices = intervals_to_indices(minor_pitch_intervals)

return _M
