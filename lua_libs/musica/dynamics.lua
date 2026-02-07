-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local _ENV, _M = llx.environment.create_module_environment()

Dynamic = llx.class 'Dynamic' {
  __init = function(self, long_name, short_name, volume)
    self.long_name = long_name
    self.short_name = short_name
    self.volume = volume
  end,
}

local dynamics_list = llx.List{
  -- Meaning "nothing". May be used at the start of a crescendo to indicate "start from nothing" or at the end of a diminuendo to indicate "fade out to nothing".
  Dynamic('niente', 'n', 0.0),
  -- Extremely soft. Softer dynamics occur very infrequently and would be specified with additional ps.
  Dynamic('pianissississimo', 'pppp', 0.1),
  -- Extremely soft. Softer dynamics occur very infrequently and would be specified with additional ps.
  Dynamic('pianississimo', 'ppp', 0.2),
  -- Very soft.
  Dynamic('pianissimo', 'pp', 0.3),
  -- Soft; louder than pianissimo.
  Dynamic('piano', 'p', 0.4),
  -- Moderately soft; louder than piano.
  Dynamic('mezzo_piano', 'mp', 0.5),
  -- Moderately loud; softer than forte. If no dynamic appears, mezzo-forte is assumed to be the prevailing dynamic level.
  Dynamic('mezzo_forte', 'mf', 0.6),
  -- Loud.
  Dynamic('forte', 'f', 0.7),
  -- Very loud.
  Dynamic('fortissimo', 'ff', 0.8),
  -- Extremely loud. Louder dynamics occur very infrequently and would be specified with additional fs.
  Dynamic('fortississimo', 'fff', 0.9),
  -- Extremely loud. Louder dynamics occur very infrequently and would be specified with additional fs.
  Dynamic('fortissississimo', 'ffff', 1.0),
}

dynamics = {}
for i, dynamic in dynamics_list do
  dynamics[dynamic.long_name] = dynamic
  dynamics[dynamic.short_name] = dynamic
end

return _M

-- -- Literally "forced", denotes an abrupt, fierce accent on a single sound or chord. When written out in full, it applies to the sequence of sounds or chords under or over which it is placed. Sforzando is not to be confused with rinforzando.
-- local sforzando = Dynamic('sforzando', 'sfz', )
-- -- Indicates that the note is to be played with a loud attack, and then immediately become soft.
-- local fortepiano = Dynamic('fortepiano', 'fp', )

--   -- A gradual increase in volume.
--   -- Can be extended under many notes to indicate that the volume steadily increases during the passage.
--   Crescendo
--   -- A gradual decrease in volume. Can be extended in the same manner as crescendo.
--   Diminuendo
--   Decrescendo