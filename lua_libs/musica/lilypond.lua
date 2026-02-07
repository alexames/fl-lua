-- Copyright 2024 Alexander Ames <Alexander.Ames@gmail.com>

--- LilyPond engraving export for musica.
-- Converts Song objects to LilyPond notation format for sheet music generation.
-- @module musica.lilypond

local accidental = require 'musica.accidental'
local llx = require 'llx'
local pitch_class = require 'musica.pitch_class'

local _ENV, _M = llx.environment.create_module_environment()

local Accidental = accidental.Accidental
local PitchClass = pitch_class.PitchClass
local isinstance = llx.isinstance
local tointeger = llx.tointeger

-- LilyPond pitch names for each pitch class
local lilypond_pitch_names = {
  [PitchClass.A] = 'a',
  [PitchClass.B] = 'b',
  [PitchClass.C] = 'c',
  [PitchClass.D] = 'd',
  [PitchClass.E] = 'e',
  [PitchClass.F] = 'f',
  [PitchClass.G] = 'g',
}

-- LilyPond uses c' for middle C (C4), c for C3, c, for C2, etc.
-- Octave 4 = no marks (middle octave in LilyPond's relative mode)
-- For absolute mode: c' is C4, c'' is C5, c is C3, c, is C2
local LILYPOND_MIDDLE_OCTAVE = 3  -- LilyPond's unmarked octave is 3

--- Convert accidentals to LilyPond suffix.
-- @param accidentals Number of semitones sharp (+) or flat (-)
-- @return LilyPond accidental string
local function accidentals_to_lilypond(accidentals)
  if accidentals == 0 then
    return ''
  elseif accidentals > 0 then
    return string.rep('is', accidentals)  -- sharp = 'is', double sharp = 'isis'
  else
    return string.rep('es', -accidentals)  -- flat = 'es', double flat = 'eses'
  end
end

--- Convert octave to LilyPond octave marks.
-- @param octave The octave number (4 = middle C octave)
-- @return LilyPond octave marks string
local function octave_to_lilypond(octave)
  local diff = octave - LILYPOND_MIDDLE_OCTAVE
  if diff > 0 then
    return string.rep("'", diff)  -- Higher octaves use apostrophes
  elseif diff < 0 then
    return string.rep(",", -diff)  -- Lower octaves use commas
  else
    return ''
  end
end

--- Convert a Pitch to LilyPond notation.
-- @param pitch A Pitch object
-- @return LilyPond pitch string (e.g., "c'", "fis''", "bes,")
pitch_to_lilypond = function(pitch)
  local name = lilypond_pitch_names[pitch.pitch_class]
  local acc = accidentals_to_lilypond(pitch.accidentals)
  local oct = octave_to_lilypond(pitch.octave)
  return name .. acc .. oct
end

-- Standard note duration values and their LilyPond equivalents
-- LilyPond uses: 1=whole, 2=half, 4=quarter, 8=eighth, 16=sixteenth, etc.
local DURATION_TOLERANCE = 0.001

--- Find the best LilyPond duration representation for a given beat duration.
-- Handles standard notes, dotted notes, and ties for complex durations.
-- @param duration Duration in beats (quarter note = 1.0)
-- @return LilyPond duration string, and any remaining duration for ties
duration_to_lilypond = function(duration)
  -- Standard durations in beats (quarter note = 1)
  local standard_durations = {
    {beats = 4.0, lily = '1'},      -- whole note
    {beats = 2.0, lily = '2'},      -- half note
    {beats = 1.0, lily = '4'},      -- quarter note
    {beats = 0.5, lily = '8'},      -- eighth note
    {beats = 0.25, lily = '16'},    -- sixteenth note
    {beats = 0.125, lily = '32'},   -- thirty-second note
    {beats = 0.0625, lily = '64'},  -- sixty-fourth note
  }

  -- Dotted durations
  local dotted_durations = {
    {beats = 6.0, lily = '1.'},     -- dotted whole
    {beats = 3.0, lily = '2.'},     -- dotted half
    {beats = 1.5, lily = '4.'},     -- dotted quarter
    {beats = 0.75, lily = '8.'},    -- dotted eighth
    {beats = 0.375, lily = '16.'},  -- dotted sixteenth
  }

  -- Double-dotted durations
  local double_dotted_durations = {
    {beats = 7.0, lily = '1..'},    -- double-dotted whole
    {beats = 3.5, lily = '2..'},    -- double-dotted half
    {beats = 1.75, lily = '4..'},   -- double-dotted quarter
    {beats = 0.875, lily = '8..'},  -- double-dotted eighth
  }

  -- Check exact matches first (with tolerance)
  for _, d in ipairs(double_dotted_durations) do
    if math.abs(duration - d.beats) < DURATION_TOLERANCE then
      return d.lily, 0
    end
  end

  for _, d in ipairs(dotted_durations) do
    if math.abs(duration - d.beats) < DURATION_TOLERANCE then
      return d.lily, 0
    end
  end

  for _, d in ipairs(standard_durations) do
    if math.abs(duration - d.beats) < DURATION_TOLERANCE then
      return d.lily, 0
    end
  end

  -- For non-standard durations, find the largest fitting duration and return remainder
  for _, d in ipairs(standard_durations) do
    if duration > d.beats + DURATION_TOLERANCE then
      return d.lily, duration - d.beats
    end
    if math.abs(duration - d.beats) < DURATION_TOLERANCE then
      return d.lily, 0
    end
  end

  -- Fallback: use the smallest duration we have
  return '64', 0
end

--- Convert a Note to LilyPond notation.
-- @param note A Note object
-- @return LilyPond note string (e.g., "c'4", "fis''8.", "bes,2~ bes,4")
note_to_lilypond = function(note)
  local pitch_str = pitch_to_lilypond(note.pitch)
  local duration_str, remainder = duration_to_lilypond(note.duration)

  if remainder > DURATION_TOLERANCE then
    -- Need to use ties for complex durations
    local result = pitch_str .. duration_str
    while remainder > DURATION_TOLERANCE do
      local next_dur, next_rem = duration_to_lilypond(remainder)
      result = result .. '~ ' .. pitch_str .. next_dur
      remainder = next_rem
    end
    return result
  else
    return pitch_str .. duration_str
  end
end

--- Convert a rest duration to LilyPond notation.
-- @param duration Duration in beats
-- @return LilyPond rest string (e.g., "r4", "r2.")
rest_to_lilypond = function(duration)
  local duration_str, remainder = duration_to_lilypond(duration)

  if remainder > DURATION_TOLERANCE then
    local result = 'r' .. duration_str
    while remainder > DURATION_TOLERANCE do
      local next_dur, next_rem = duration_to_lilypond(remainder)
      result = result .. ' r' .. next_dur
      remainder = next_rem
    end
    return result
  else
    return 'r' .. duration_str
  end
end

--- Generate LilyPond header block from Song metadata.
-- @param song A Song object
-- @return LilyPond header block string
header_to_lilypond = function(song)
  local lines = {'\\header {'}

  if song.title then
    table.insert(lines, string.format('  title = "%s"', song.title))
  end
  if song.subtitle then
    table.insert(lines, string.format('  subtitle = "%s"', song.subtitle))
  end
  if song.composer then
    table.insert(lines, string.format('  composer = "%s"', song.composer))
  end
  if song.arranger then
    table.insert(lines, string.format('  arranger = "Arr. %s"', song.arranger))
  end
  if song.opus then
    table.insert(lines, string.format('  opus = "%s"', song.opus))
  end
  if song.dedication then
    table.insert(lines, string.format('  dedication = "%s"', song.dedication))
  end
  if song.copyright then
    table.insert(lines, string.format('  copyright = "%s"', song.copyright))
  end

  table.insert(lines, '}')
  return table.concat(lines, '\n')
end

--- Convert time signature (meter) to LilyPond.
-- @param meter A Meter object or nil
-- @return LilyPond time signature string
meter_to_lilypond = function(meter)
  if not meter then
    return '\\time 4/4'
  end
  -- Count pulses and determine time signature
  local num_pulses = #meter.pulseSequence
  -- Default to quarter note denominator
  return string.format('\\time %d/4', num_pulses)
end

--- Convert tempo to LilyPond tempo marking.
-- @param tempo A Tempo object or nil
-- @return LilyPond tempo string
tempo_to_lilypond = function(tempo)
  if not tempo then
    return ''
  end
  if tempo.marking then
    -- Use Italian tempo marking with BPM
    local marking_capitalized = tempo.marking:gsub('^%l', string.upper)
    return string.format('\\tempo "%s" 4 = %d', marking_capitalized, tempo.bpm)
  else
    return string.format('\\tempo 4 = %d', tempo.bpm)
  end
end

--- Convert a key to LilyPond key signature.
-- @param key A Scale or key specification, or nil
-- @return LilyPond key signature string
key_to_lilypond = function(key)
  if not key then
    return '\\key c \\major'
  end
  -- If key is a Scale object, extract the tonic and mode
  if key.tonic and key.mode then
    local tonic_str = pitch_to_lilypond(key.tonic):gsub("[',]", "")  -- Remove octave marks
    local mode_str = key.mode.name or 'major'
    return string.format('\\key %s \\%s', tonic_str, mode_str:lower())
  end
  return '\\key c \\major'
end

--- Convert clef specification to LilyPond.
-- @param clef Clef string or nil
-- @return LilyPond clef command
clef_to_lilypond = function(clef)
  local valid_clefs = {
    treble = 'treble',
    bass = 'bass',
    alto = 'alto',
    tenor = 'tenor',
    soprano = 'soprano',
    ['treble_8'] = 'treble_8',
    ['bass_8'] = 'bass_8',
  }
  if clef and valid_clefs[clef] then
    return string.format('\\clef %s', valid_clefs[clef])
  end
  return '\\clef treble'
end

--- Group notes by time to detect chords.
-- @param notes List of notes sorted by time
-- @return List of note groups, where each group contains notes at the same time
local function group_simultaneous_notes(notes)
  local groups = {}
  local current_group = nil
  local current_time = nil

  for _, note in ipairs(notes) do
    if current_time == nil or math.abs(note.time - current_time) > DURATION_TOLERANCE then
      -- New time point
      if current_group then
        table.insert(groups, current_group)
      end
      current_group = {note}
      current_time = note.time
    else
      -- Same time point - add to chord
      table.insert(current_group, note)
    end
  end

  if current_group then
    table.insert(groups, current_group)
  end

  return groups
end

--- Convert a group of simultaneous notes to LilyPond.
-- @param notes List of notes at the same time
-- @return LilyPond chord or single note string
local function note_group_to_lilypond(notes)
  if #notes == 1 then
    return note_to_lilypond(notes[1])
  else
    -- It's a chord - use angle brackets
    -- Sort notes by pitch for consistent output
    table.sort(notes, function(a, b)
      return tointeger(a.pitch) < tointeger(b.pitch)
    end)

    local pitches = {}
    for _, note in ipairs(notes) do
      table.insert(pitches, pitch_to_lilypond(note.pitch))
    end
    local chord_pitches = '<' .. table.concat(pitches, ' ') .. '>'

    -- Use duration of first note (they should all be the same for a proper chord)
    local duration_str, remainder = duration_to_lilypond(notes[1].duration)

    if remainder > DURATION_TOLERANCE then
      -- Need to use ties for complex durations
      local result = chord_pitches .. duration_str
      while remainder > DURATION_TOLERANCE do
        local next_dur, next_rem = duration_to_lilypond(remainder)
        result = result .. '~ ' .. chord_pitches .. next_dur
        remainder = next_rem
      end
      return result
    else
      return chord_pitches .. duration_str
    end
  end
end

--- Convert a channel's music content to LilyPond notation.
-- @param channel A Channel object
-- @param song The parent Song object (for tempo/key/meter info)
-- @return LilyPond music expression string
channel_to_lilypond = function(channel, song)
  -- Collect all notes from all figure instances
  local all_notes = {}
  for _, figure_instance in ipairs(channel.figure_instances) do
    for _, note in figure_instance:time_adjusted_notes() do
      table.insert(all_notes, note)
    end
  end

  -- Sort notes by time
  table.sort(all_notes, function(a, b)
    if math.abs(a.time - b.time) < DURATION_TOLERANCE then
      return tointeger(a.pitch) < tointeger(b.pitch)
    end
    return a.time < b.time
  end)

  if #all_notes == 0 then
    return ''
  end

  -- Group simultaneous notes (chords)
  local note_groups = group_simultaneous_notes(all_notes)

  -- Convert to LilyPond, adding rests where needed
  local music_elements = {}
  local current_time = 0

  for _, group in ipairs(note_groups) do
    local note_time = group[1].time

    -- Add rest if there's a gap
    if note_time > current_time + DURATION_TOLERANCE then
      local gap = note_time - current_time
      table.insert(music_elements, rest_to_lilypond(gap))
    end

    -- Add the note or chord
    table.insert(music_elements, note_group_to_lilypond(group))

    -- Update current time to end of this note
    current_time = note_time + group[1].duration
  end

  return table.concat(music_elements, ' ')
end

--- Generate a complete part for a single channel.
-- @param channel A Channel object
-- @param song The parent Song object
-- @param part_id Unique identifier for the part (used in variable names)
-- @return LilyPond part definition string
--- Convert a number to a LilyPond-safe identifier (using letters).
-- @param n A positive integer
-- @return A string like "A", "B", ..., "Z", "AA", "AB", etc.
local function number_to_id(n)
  local result = ''
  while n > 0 do
    n = n - 1
    result = string.char(65 + (n % 26)) .. result
    n = math.floor(n / 26)
  end
  return result
end

part_to_lilypond = function(channel, song, part_id)
  local lines = {}

  local part_name = channel.part_name or
                    (channel.instrument and channel.instrument.name) or
                    ('Part ' .. part_id)
  local short_name = channel.short_name or part_name:sub(1, 3) .. '.'

  -- Music variable - use letter-based ID to avoid LilyPond parsing issues
  local safe_id = number_to_id(part_id)
  local var_name = 'part' .. safe_id .. 'Music'
  table.insert(lines, var_name .. ' = {')
  table.insert(lines, '  ' .. clef_to_lilypond(channel.clef))
  if song.key then
    table.insert(lines, '  ' .. key_to_lilypond(song.key))
  end
  table.insert(lines, '  ' .. meter_to_lilypond(song.meter))
  if song.tempo then
    table.insert(lines, '  ' .. tempo_to_lilypond(song.tempo))
  end
  table.insert(lines, '  ' .. channel_to_lilypond(channel, song))
  table.insert(lines, '}')
  table.insert(lines, '')

  -- Staff definition
  table.insert(lines, 'part' .. safe_id .. 'Staff = \\new Staff \\with {')
  table.insert(lines, string.format('  instrumentName = "%s"', part_name))
  table.insert(lines, string.format('  shortInstrumentName = "%s"', short_name))
  table.insert(lines, '} { \\' .. var_name .. ' }')

  return table.concat(lines, '\n')
end

--- Generate a standalone part score for a single channel.
-- @param channel A Channel object
-- @param song The parent Song object
-- @param part_id Unique identifier for the part
-- @return Complete LilyPond file content for this part
standalone_part_to_lilypond = function(channel, song, part_id)
  local safe_id = number_to_id(part_id)
  local lines = {
    '\\version "2.24.0"',
    '',
    header_to_lilypond(song),
    '',
    part_to_lilypond(channel, song, part_id),
    '',
    '\\score {',
    '  \\part' .. safe_id .. 'Staff',
    '  \\layout { }',
    '  \\midi { }',
    '}',
  }
  return table.concat(lines, '\n')
end

--- Generate a conductor's score with all parts.
-- @param song A Song object
-- @return Complete LilyPond file content for the conductor's score
conductor_score_to_lilypond = function(song)
  local lines = {
    '\\version "2.24.0"',
    '',
    header_to_lilypond(song),
    '',
  }

  -- Generate all part definitions
  local staff_refs = {}
  for i, channel in ipairs(song.channels) do
    table.insert(lines, part_to_lilypond(channel, song, i))
    table.insert(lines, '')
    table.insert(staff_refs, '    \\part' .. number_to_id(i) .. 'Staff')
  end

  -- Create the score with all staves
  table.insert(lines, '\\score {')
  table.insert(lines, '  \\new StaffGroup <<')
  for _, ref in ipairs(staff_refs) do
    table.insert(lines, ref)
  end
  table.insert(lines, '  >>')
  table.insert(lines, '  \\layout { }')
  table.insert(lines, '  \\midi { }')
  table.insert(lines, '}')

  return table.concat(lines, '\n')
end

--- Convert a Song to a table of LilyPond engravings.
-- Returns a table containing the conductor's score and individual part scores.
-- @param song A Song object
-- @return Table mapping part names to LilyPond content strings
-- @usage
-- local engravings = song:tolilypond()
-- -- engravings["Conductor"] contains the full score
-- -- engravings["Flute I"] contains just the first flute part
tolilypond = function(song)
  local result = {}

  -- Generate conductor's score
  result["Conductor"] = conductor_score_to_lilypond(song)

  -- Generate individual parts
  for i, channel in ipairs(song.channels) do
    local part_name = channel.part_name or
                      (channel.instrument and channel.instrument.name) or
                      ('Part ' .. i)
    result[part_name] = standalone_part_to_lilypond(channel, song, i)
  end

  return result
end

return _M
