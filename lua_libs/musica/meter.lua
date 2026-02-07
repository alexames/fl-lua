-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

local class = llx.class
local List = llx.List

Pulse = class 'Pulse' {
  __init = function(self, duration)
    self.duration = duration or 1
  end
}

StressedPulse = class 'StressedPulse' :extends(Pulse) {
  isStressed = function(self)
    return true
  end
}

UnstressedPulse = class UnstressedPulse : extends(Pulse) {
  isStressed = function(self)
    return false
  end
}

-- The sequence of stressed and unstressed beats in a phrase.
Meter = class 'Meter' {
  __init = function(self, pulses)
    self.pulseSequence = pulses
  end;

  duration = function(self)
    -- return sum(pulse.duration for pulse in self.pulseSequence)
  end;

  beats = function(self, numberOfBeats)
    return numberOfBeats
  end;

  pulses = function(self, numberOfPulses)
    error(NotImplementedError())
  end;

  measures = function(self, numberOfMeasures)
    return numberOfMeasures * self.duration()
  end;
}

MeterProgression = class 'MeterProgression' {
  __init = function(self, periods)
    self.periods = periods
  end;

  duration = function(self)
    -- return sum(meter.duration() * measures
    --            for meter, measures in self.periods)
  end;
}

four_four = Meter(List{StressedPulse(),
                       UnstressedPulse(),
                       StressedPulse(),
                       UnstressedPulse()})

common_meter = four_four

return _M
