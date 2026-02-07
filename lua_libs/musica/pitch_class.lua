-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local class, environment = llx { 'class', 'environment' }

local _ENV, _M = llx.environment.create_module_environment()

PitchClass = class 'PitchClass' {
  __init = function(self, args)
    self.name = args.name
    self.index = args.index
  end,

  __tostring = function(self)
    local fmt = 'PitchClass.%s'
    return fmt:format(self.name)
  end,
}

PitchClass.A = PitchClass{name='A', index=1}
PitchClass.B = PitchClass{name='B', index=2}
PitchClass.C = PitchClass{name='C', index=3}
PitchClass.D = PitchClass{name='D', index=4}
PitchClass.E = PitchClass{name='E', index=5}
PitchClass.F = PitchClass{name='F', index=6}
PitchClass.G = PitchClass{name='G', index=7}
PitchClass[1] = PitchClass.A
PitchClass[2] = PitchClass.B
PitchClass[3] = PitchClass.C
PitchClass[4] = PitchClass.D
PitchClass[5] = PitchClass.E
PitchClass[6] = PitchClass.F
PitchClass[7] = PitchClass.G

return _M
