# Daylight

A fully offline Qt Quick desktop application with a high-resolution world map,
daylight and twilight shading, the Sun and Moon, five planets, and the twelve
traditional zodiac constellations. Each body or star is positioned above its
geocentric point on Earth. A faint ecliptic and grey constellation connections
provide context without dominating the map.

Live mode updates every ten seconds. Time navigation can hold the whole sky at
a selected instant. All images and star data are embedded; no accounts, API
keys, or runtime downloads are needed.

The repository’s [main README](../../README.md) has complete build instructions,
controls, customization notes, and calculation details.

## Run

Open `app/Daylight.exe`. Keep the entire app folder together; the adjacent Qt
libraries and plugins are required. Qt does not need to be separately installed.
The executable and app window use a half-day, half-night Earth icon, embedded
at multiple sizes for Windows Explorer and the taskbar.

## Controls

The footer has five switches: **Sun**, **Moon**, **Planets**, **Constellations**,
and **Labels**. Planets controls Mercury, Venus, Mars, Jupiter, and Saturn.
Constellations controls all zodiac figures and the ecliptic. Labels controls
all celestial names. Hiding a body also hides its label; hiding the Sun marker
does not hide daylight shading.

Switch states are saved immediately and restored on the next launch. The first
launch starts with everything visible. Linux stores preferences in
`~/.config/Daylight/Daylight.conf` (or under `$XDG_CONFIG_HOME`); Windows uses the
current user’s `Software\Daylight\Daylight` registry settings.

The **left/right arrows** step backward/forward by exactly 24 hours (86,400
seconds) from the displayed instant. All bodies, stars, shading, and Moon phase
use that same time, and live updates pause. **Now** always samples the actual
current time immediately and resumes live updates. The label underneath shows
the displayed local date/time and its UTC offset. A 24-hour step can change the
local wall-clock hour when crossing a daylight-saving transition.

Mouse clicks, Tab navigation, and Space or Enter operate the controls. Rapid
double-clicks on the arrows count as two steps. The application starts in live
mode each time; the selected viewing time is not saved.

The footer stays at the bottom in normal, maximized, and full-screen windows.
The map fits above it with its 2:1 aspect ratio preserved, adding margins where
needed so the controls stay on-screen.

## Design

The map uses an equirectangular projection with north at the top and Greenwich
at the center. Sun, Moon, and planet markers indicate their geocentric subpoints, rather
than their visibility regions. Marker sizes are illustrative. Overlapping
bodies are drawn by distance from Earth, nearest in front. These enlarged
markers do not predict actual transits or occultations.
The Moon uses Gregory H. Revera's full-Moon photograph with a calculated shadow
mask. It has a fixed orientation: waxing illumination is on the right, waning
on the left. The shadowed portion retains a faint outline. Lunar libration and
eclipse coloration are not simulated.

The twelve zodiac figures preserve individual star positions and natural angular
sizes, with conventional grey connecting lines and readable, outlined grey
labels. Catalog coordinates are corrected for precession, nutation, and annual
aberration; individual stellar proper motion and parallax are not modeled.
The true ecliptic of date is drawn as a faint continuous line. Figures wrap at
the map edges and are drawn behind the Solar System markers. All catalog data
and its license are embedded; details are in [source/data/README.md](source/data/README.md).

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

Linux source builds are also verified with Qt 6.8.3 and GCC. From the repository
root, see [the Linux build instructions](../../README.md#build-on-linux).

To adjust constellation-label size, change `font.setPixelSize(...)` in
`source/zodiac.h` (currently 15 pixels), then rebuild. Marker sizes are in
`Sky::markers()` in `source/main.cpp`; body labels and footer controls are in
`source/Main.qml`.

Developer checks: `Daylight.exe --self-test` checks seasonal solar declination,
known new/full Moons, twilight, phase orientation, zodiac rotation, ecliptic
alignment, and date-line wrapping. The option
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

Zodiac figures and XHIP-based star coordinates: D3-Celestial, Olaf Frohn,
BSD-3-Clause. The subset’s sources and extraction notes are in
[source/data/README.md](source/data/README.md). Retain
[source/data/D3-CELESTIAL-LICENSE](source/data/D3-CELESTIAL-LICENSE) with distributions.
https://github.com/ofrohn/d3-celestial

Astronomy Engine: Don Cross, MIT license; license and source are in
`source/vendor/`. https://github.com/cosinekitty/astronomy

Qt is dynamically linked. Qt's applicable open-source licenses and notices are
included in `app/licenses/` when packaged. Qt source is available from
https://download.qt.io/archive/qt/6.8/6.8.3/single/ .
The application may be rebuilt to use modified compatible Qt libraries.
