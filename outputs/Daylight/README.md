# Daylight

<img width="1282" height="784" alt="Daylight_UJiLygmqMs" src="https://github.com/user-attachments/assets/5b59ebf1-e2f1-42a3-b065-4e701ce5e20c" />

A fully offline Qt Quick desktop application with a high-resolution world map,
daylight and twilight shading, the Sun and Moon, five planets, and the twelve
traditional zodiac constellations. Each body or star is positioned above its
geocentric point on Earth. A faint ecliptic and grey constellation connections
provide context without dominating the map.

Live mode updates every 30 seconds. Time navigation can hold the whole sky at
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

The footer has six switches: **Sun**, **Moon**, **Planets**, **Constellations**,
**Latitude lines**, and **Labels**. Planets controls Mercury, Venus, Mars, Jupiter, and Saturn.
Constellations controls all zodiac figures and the ecliptic. Labels controls
all celestial names. Hiding a body also hides its label; hiding the Sun marker
does not hide daylight shading.

Switch states are saved immediately and restored on the next launch. On the first
launch, Sun, Moon, and Labels are on; Planets, Constellations, and Latitude lines are off. Existing saved choices are preserved. Linux stores preferences in
`~/.config/Daylight/Daylight.conf` (or under `$XDG_CONFIG_HOME`); Windows uses the
current user’s `Software\Daylight\Daylight` registry settings.

**Latitude lines** controls the equator, both tropics (approximately +/-23.44 degrees), and the Arctic/Antarctic Circles (approximately +/-66.56 degrees). These fixed geographic parallels use a subtle green, distinct from the ecliptic, and the switch state is saved. The equator is slightly thicker. Degree labels repeat at the left edge, center and right edge; they follow the Labels switch.

A single navigation group controls all map layers. Click the middle label to choose **5 Minutes**, **15 Minutes**, **30 Minutes**, **1 Hour** (the initial selection), **2 Hours**, **6 Hours**, **1 Sidereal Day**, or **24 Hours**.

The main arrows move once by the selected interval. Each smaller outer section starts animation in that direction; pressing the active section again pauses.

- **5 Minutes through 6 Hours:** advance one selected interval per real second, divided into ten smaller updates for smoother motion. Elapsed time determines the displayed instant.
- **1 Sidereal Day and 24 Hours:** show the first step immediately, then advance one complete interval every half-second. There are no intermediate frames, so daylight shading does not sweep across the map. Each timer tick advances exactly one interval, without repeated or skipped dates caused by rounding. A sidereal step is exactly **23h 56m 4.09s**.

Changing the interval during playback preserves the displayed time and direction and applies the new rate; it does not add an immediate extra step.

Manual stepping pauses playback first. **Escape** pauses; **Now** stops playback and returns to actual current time, with live updates every 30 seconds. All layers use the same displayed instant, including Moon phase and zodiac. Hover descriptions and Tab/Space/Enter navigation are available for the direction controls. Only one playback mode runs at a time: starting Earth rotation stops navigation animation, and starting navigation animation pauses Earth rotation. The selected interval, rotation speed, and playback state are not saved.

Click the map to center and zoom into a place, which stays centered through time navigation and animation. Click the Sun, Moon, or a visible planet to follow that body instead; a small badge identifies the target. Use the wheel to zoom around the pointer, drag to select a new geographic center, and double-click or press **Fit map** to release tracking and reset. Wheel zoom keeps a followed body centered. Zoom is limited to 1-8x; longitude wraps and the camera cannot pan beyond the poles.

The **globe-and-arrow button** in the footer plays Earth scrolling beneath the nearly fixed stars. The adjacent speed dropdown selects one simulated minute to eight simulated hours per real second (default **2 h/s**). Speed choices are **1, 5, 15, or 30 min/s**, and **1, 2, 4, or 8 h/s**. Here, h/s means simulated hours per real second. Speed changes work while paused or playing without jumping the selected time. The Sun, Moon and planets retain their motion against the stars. Clicking the highlighted globe button pauses and holds this view; **Escape** pauses too. **Now** stops playback and restores current time in the usual Earth-fixed view. Selected locations and bodies stay centered through rotation, navigation, and **Now**; use **Fit map** to release tracking. Zoom and playback state are not saved.

The footer stays at the bottom in normal, maximized, and full-screen windows.
The map fills the area above it; controls stack on narrower windows.

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
