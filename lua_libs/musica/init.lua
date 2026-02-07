-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

local llx = require 'llx'

local lock <close> = llx.lock_global_table()

--                                           Tested | Docs
----------------------------------------------------+-----
return require 'llx.flatten_submodules' { --        |
  require 'musica.accidental',       -- No     | No
  require 'musica.articulation',     -- No     | No
  require 'musica.beat',             -- No     | No
  require 'musica.channel',          -- No     | No
  require 'musica.chord',            -- Yes    | No
  require 'musica.contour',          -- No     | No
  require 'musica.direction',        -- No     | No
  require 'musica.dynamics',         -- No     | No
  require 'musica.figure',           -- Yes    | No
  require 'musica.instrument',       -- No     | No
  require 'musica.interval_quality', -- No     | No
  require 'musica.lilypond',         -- No     | No
  require 'musica.meter',            -- No     | No
  require 'musica.mode',             -- Yes    | No
  require 'musica.modes',            -- No     | No
  require 'musica.note',             -- Yes    | No
  require 'musica.pattern',          -- No     | No
  require 'musica.pitch',            -- Yes    | No
  require 'musica.pitch_class',      -- No     | No
  require 'musica.pitch_interval',   -- Yes    | No
  require 'musica.quality',          -- Yes    | No
  require 'musica.rhythm',           -- No     | No
  require 'musica.ring',             -- No     | No
  require 'musica.scale',            -- Yes    | No
  require 'musica.scale_degree',     -- No     | No
  require 'musica.scale_index',      -- No     | No
  require 'musica.song',             -- No     | No
  require 'musica.spiral',           -- No     | No
  require 'musica.tempo',            -- No     | No
  require 'musica.util',             -- No     | No
  require 'musica.generation',       -- No     | No
}
