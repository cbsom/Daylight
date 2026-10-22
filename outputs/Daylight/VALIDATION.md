# Prototype validation

Built on Windows x64 with Qt 6.8.3, MSVC 19.51 and CMake 4.3, in Release mode.

- Packaged executable runs with bundled Qt libraries and QML modules.
- Self-test exit code: 0. Astronomy, twilight and lunar phase checks passed.
- Screenshot capture exit code: 0. Map, twilight, Sun and Moon inspected visually.
- Launch to first captured render, including saving a 1280 x 720 PNG: 722 ms.
  This is one measurement beginning inside `main()`, using a hidden window.
  It excludes Windows process/DLL startup and is not a cold-launch benchmark.

The screenshot is `preview.png`. Tests cover equinox/solstice solar declination,
the April 8, 2024 new Moon and March 25, 2024 full Moon, day/night shading,
and waxing/waning illumination orientation.

Current revision: full-night shading is 89% (slightly lighter than the previous
93%), retaining brightened daylight imagery and the continuous twilight fade.
A thin, subdued line marks the standard apparent sunrise/sunset boundary at
solar-center altitude -0.833 degrees. Tests verify points on this contour at
equinox and solstice inclinations, including subsolar longitudes near the date
line. Map-edge wrapping was inspected in the captured preview.

The Moon now uses Gregory H. Revera's photograph with a phase shadow mask.
The Sun and Moon have matching visible diameters of approximately 19 logical
pixels, without solar rays or a halo. Darkening begins at the apparent horizon
line, with an accelerated early-twilight fade. Lunar-phase tests compare the same photographic pixels under
opposite phases, so surface albedo does not affect the checks.

Icon revision: the horizon stroke alpha is reduced from 105 to 48 out of 255.
The executable includes a multi-resolution half-day, half-night Earth icon.
Windows successfully extracted the 32 x 32 associated icon from the packaged
executable; the extracted image and refreshed application preview were inspected.

The GPU and visible interactive resizing have not been independently exercised
through desktop automation. The capture was made by the running Qt application.
