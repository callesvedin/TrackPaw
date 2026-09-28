#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts a GPX track (e.g. drawn in gpx.studio) into the "lat,lon" waypoint
# list the `screenshots` lane feeds to `xcrun simctl location start`, and
# rewrites the `waypoints` array, `walk_speed_m_s`, and the summary comment
# in fastlane/Fastfile in place. Also rewrites the "Morning walk with Bella"
# snapshot fixture's path (TrackPaw/Persistance/PersistenceController+Snapshot.swift)
# to the same points, so the EditTrack screenshot — which shows that fixture,
# per TrackListView's sort order — matches the live-tracking screenshot's route
# instead of its own unrelated placeholder loop.
#
# Usage: ruby fastlane/gpx_to_waypoints.rb path/to/track.gpx [speed_m_s]
#
# speed_m_s must be a bare number (e.g. `4`, not `speed:4` or `--speed=4` —
# this is a plain Ruby script, not a fastlane lane). When omitted, it defaults
# to whatever `walk_speed_m_s` is currently set to in the Fastfile, so a rerun
# without it doesn't silently reset the pace back to some other default.

require "rexml/document"

gpx_path = ARGV[0] or abort "Usage: #{$PROGRAM_NAME} path/to/track.gpx [speed_m_s]"
abort "No such file: #{gpx_path}" unless File.exist?(gpx_path)

fastfile_path = File.expand_path("Fastfile", __dir__)
fastfile = File.read(fastfile_path)
current_speed = fastfile[/walk_speed_m_s\s*=\s*([\d.]+)/, 1]

speed =
  if ARGV[1]
    begin
      Float(ARGV[1])
    rescue ArgumentError
      abort "speed_m_s must be a plain number like `4`, not `#{ARGV[1]}` " \
            "(this script takes positional args, not fastlane's `key:value` style)."
    end
  elsif current_speed
    current_speed.to_f
  else
    6.0
  end
abort "speed_m_s must be greater than 0, got #{speed}" unless speed.positive?

doc = REXML::Document.new(File.read(gpx_path))
points = REXML::XPath.match(doc, "//trkpt").map { |pt| [pt.attributes["lat"].to_f, pt.attributes["lon"].to_f] }
points = REXML::XPath.match(doc, "//rtept").map { |pt| [pt.attributes["lat"].to_f, pt.attributes["lon"].to_f] } if points.empty?
abort "No <trkpt>/<rtept> points found in #{gpx_path}" if points.empty?

def haversine_meters(a, b)
  earth_radius_m = 6_371_000.0
  lat1, lon1 = a.map { |v| v * Math::PI / 180 }
  lat2, lon2 = b.map { |v| v * Math::PI / 180 }
  dlat = lat2 - lat1
  dlon = lon2 - lon1
  h = (Math.sin(dlat / 2)**2) + (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(dlon / 2)**2))
  2 * earth_radius_m * Math.asin(Math.sqrt(h))
end

total_meters = points.each_cons(2).sum { |a, b| haversine_meters(a, b) }
duration_seconds = total_meters / speed

puts "#{points.size} waypoints"
puts format("Total distance: %.0fm", total_meters)
puts format("At %.1f m/s: ~%.0fs to walk once", speed, duration_seconds)

# ScreenshotTests tracks for ~25s after the walk starts; a shorter walk parks
# at its last waypoint before the screenshot and the path stops growing.
if duration_seconds < 30
  warn format("WARNING: the walk only takes ~%.0fs at %.1f m/s — the live-tracking " \
              "screenshot is taken ~25s in, so pick a lower speed or a longer track.",
              duration_seconds, speed)
end

waypoint_strings = points.map { |lat, lon| format('"%.6f,%.6f"', lat, lon) }
lines = waypoint_strings.each_slice(4).map { |slice| "      #{slice.join(", ")}" }
array_literal = "waypoints = [\n#{lines.join(",\n")}\n    ].join(\" \")"

total_km = format("%.2f", total_meters / 1000.0)
summary_line = "# Current route: ~#{total_km}km, #{points.size} waypoints, " \
               "~#{duration_seconds.round}s to walk once at #{speed} m/s."

speed_str = speed == speed.to_i ? speed.to_i.to_s : speed.to_s
speed_assignment = "walk_speed_m_s = #{speed_str}"

waypoints_regex = /waypoints = \[.*?\]\.join\(" "\)/m
summary_regex = /# Current route:.*/
speed_regex = /walk_speed_m_s\s*=\s*[\d.]+/

abort "Could not find `waypoints = [...].join(\" \")` in #{fastfile_path} — not modified." unless fastfile.match?(waypoints_regex)
abort "Could not find the `# Current route:` summary line in #{fastfile_path} — not modified." unless fastfile.match?(summary_regex)
abort "Could not find `walk_speed_m_s = ...` in #{fastfile_path} — not modified." unless fastfile.match?(speed_regex)

updated = fastfile.sub(waypoints_regex, array_literal).sub(summary_regex, summary_line).sub(speed_regex, speed_assignment)
File.write(fastfile_path, updated)
puts "Updated #{fastfile_path}"

fixture_path = File.expand_path("../TrackPaw/Persistance/PersistenceController+Snapshot.swift", __dir__)
fixture = File.read(fixture_path)

swift_points = points.map { |lat, lon| format("            CLLocation(latitude: %.6f, longitude: %.6f)", lat, lon) }
swift_array = "morningWalk.laidPath = [\n#{swift_points.join(",\n")}\n        ]"
length_assignment = "morningWalk.length = #{total_meters.round}"

fixture_path_regex = /morningWalk\.laidPath = \[.*?\]/m
fixture_length_regex = /morningWalk\.length = \d+/

abort "Could not find `morningWalk.laidPath = [...]` in #{fixture_path} — not modified." unless fixture.match?(fixture_path_regex)
abort "Could not find `morningWalk.length = ...` in #{fixture_path} — not modified." unless fixture.match?(fixture_length_regex)

updated_fixture = fixture.sub(fixture_path_regex, swift_array).sub(fixture_length_regex, length_assignment)
File.write(fixture_path, updated_fixture)
puts "Updated #{fixture_path}"
