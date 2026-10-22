# Daylight

A single-window Qt Quick desktop application with a local 5400 x 2700 world map,
current daylight and smoothly shaded twilight, and Sun and Moon markers.
There is no clock or time slider. The display updates every ten seconds and uses
the computer's current UTC time. No network connection is used at runtime.

## Run

Open `app/Daylight.exe`. Keep the entire app folder together; the adjacent Qt
libraries and plugins are required. Qt does not need to be separately installed.
The executable and app window use a half-day, half-night Earth icon, embedded
at multiple sizes for Windows Explorer and the taskbar.

## Design

The map uses an equirectangular projection with north at the top and Greenwich
at the center. Sun and Moon markers indicate their geocentric subpoints, rather
than where either body is rising or setting. Marker sizes are illustrative.
The Moon uses Gregory H. Revera's full-Moon photograph with a calculated shadow
mask. It has a fixed orientation: waxing illumination is on the right, waning
on the left. The shadowed portion retains a faint outline. Lunar libration and
eclipse coloration are not simulated.

Astronomy Engine computes apparent equatorial coordinates of date and sidereal
time to obtain terrestrial longitude. Illumination uses the lunar phase angle.
Twilight darkening begins at the apparent sunrise/sunset line. It increases
more quickly through early twilight, then fades gently into full night at
18 degrees below the geometric horizon.
The thin, subdued boundary marks apparent sunrise/sunset: the Sun's center is
0.833 degrees below the geometric horizon, accounting approximately for its
upper limb and standard atmospheric refraction. Actual visibility varies with
weather, terrain and atmospheric conditions. The Sun is a small plain disk;
its marker size is illustrative, rather than an angular sky scale.
The map is a fixed October
2004 NASA composite, not live satellite imagery.

## Build

Requires Qt 6.8 or newer with Qt Quick, a compatible x64 Microsoft C++ toolchain,
CMake, and Ninja. In an x64 Visual Studio Developer Command Prompt:

```
source\build.cmd C:\Qt\6.8.3\msvc2022_64
```

The default Qt CMake QML module pipeline embeds assets and precompiles QML.
Use a release build. The installer should deploy an ordinary application folder
to avoid unpacking an archive on every launch.

Developer checks: `Daylight.exe --self-test` checks seasonal solar declination,
known new/full moons, twilight and the illumination orientation. The option
`--capture absolute-path.png` captures the window and exits.

## Credits and licenses

Map: NASA Earth Observatory, Blue Marble Next Generation with Topography,
October 2004. Credit: Reto Stockli, NASA Earth Observatory.
https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography/

Full Moon photograph: Gregory H. Revera, FullMoon2010.jpg, CC BY-SA 3.0.
https://commons.wikimedia.org/wiki/File:FullMoon2010.jpg
https://creativecommons.org/licenses/by-sa/3.0/
The photograph is cropped, resized and shaded at runtime. The adapted lunar
imagery, including the lunar image visible in preview.png, is supplied under
CC BY-SA 3.0. The original photograph is bundled in source/assets/moon-full.jpg.

Sunrise/sunset convention:
https://gml.noaa.gov/grad/solcalc/solareqns.PDF

Astronomy Engine: Don Cross, MIT license; license and source are in
`source/vendor/`. https://github.com/cosinekitty/astronomy

Qt is dynamically linked. Qt's applicable open-source licenses and notices are
included in `app/licenses/` when packaged. Qt source is available from
https://download.qt.io/archive/qt/6.8/6.8.3/single/ .
The application may be rebuilt to use modified compatible Qt libraries.
