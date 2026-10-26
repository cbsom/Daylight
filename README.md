# Daylight

An offline desktop map of daylight, twilight, and night, with the Sun, Moon, planets, and zodiac sky positioned over Earth.

Daylight displays a high-resolution world map in a single window. The daylight side stays bright, the night side is shaded, and a smooth transition shows twilight. A subtle line marks the approximate sunrise/sunset boundary. Sun, Moon, and planet markers show the points on Earth directly beneath them. The Moon uses a real photograph shaded to its phase at the displayed time. Twelve zodiac constellations show individually positioned stars joined in conventional patterns, with a faint ecliptic tracing the Solar System’s reference plane.

The application is built with **C++17 and Qt Quick/QML**. It runs locally, works offline, and updates every 30 seconds in live mode using the computer's current time. Time navigation can hold the entire sky at a selected instant. There are no accounts, API keys, map servers, or runtime downloads.

## Features

- High-resolution, flat world map with north at the top.
- Live daylight and night shading, with a gradual twilight transition.
- A thin, subdued sunrise/sunset boundary.
- Current Sun, Moon, Mercury, Venus, Mars, Jupiter, and Saturn positions over Earth.
- Stylized planet markers, with overlapping bodies drawn in Earth-distance order (nearest in front).
- Twelve zodiac constellations at their natural angular sizes, with faint stars, grey connections, and small labels.
- A subtle continuous ecliptic line. All star data is embedded for offline use.
- Photographic Moon with a calculated phase shadow and a fixed orientation.
- A compact footer with six visibility switches whose settings survive restarts.
- Readable grey constellation labels with dark outlines, plus small body labels.
- A responsive footer that remains on-screen while the map fills the area above it.
- One navigation group with eight selectable intervals, forward/reverse playback, and a live Now button.
- Continuous Earth rotation beneath the sky, with a globe button and speed dropdown in the footer.
- Click-to-zoom, wheel zoom, drag panning, and tracking of a geographic location or celestial body.
- Subtle labeled equator, tropics, and polar circles with their own visibility switch.
- A half-day, half-night Earth icon for the executable and application window.

## Run a packaged copy

If you have a packaged Windows build, extract the whole package and open `Daylight.exe` inside its `app` folder.

Keep the adjacent DLLs and plugin folders with the executable. The packaged application includes its Qt dependencies; users do not need to install Qt separately.

## Build on Windows

### Requirements

- A 64-bit Microsoft C++ toolchain and Windows SDK. Install Visual Studio or Visual Studio Build Tools with **Desktop development with C++**.
- **Qt 6.8 or newer**, including Qt Quick/QML, built for a compatible MSVC x64 toolchain. The project has been built with Qt 6.8.3's `msvc2022_64` package and Visual Studio 2026.
- **CMake 3.21 or newer**.
- **Ninja** for the supplied build script. Visual Studio's C++ CMake tools can provide CMake and Ninja.

The Qt SDK is needed for development. It is not checked into this repository. Python, a browser engine, and Qt WebEngine are not required.

### Compile and deploy

Clone or download this repository, then open an **x64 Native Tools Command Prompt** for your Visual Studio installation. Change to the repository root.

Set `QT_ROOT` to your Qt installation. For example:

```bat
set "QT_ROOT=C:\Qt\6.8.3\msvc2022_64"
set "PATH=%QT_ROOT%\bin;%PATH%"
```

Confirm that the build tools are available:

```bat
cl
cmake --version
ninja --version
```

Build and collect the runtime dependencies:

```bat
outputs\Daylight\source\build.cmd "%QT_ROOT%"
```

The script configures a Release build, compiles the program, copies the executable into `outputs\Daylight\app`, and runs Qt's `windeployqt` tool to collect its required libraries and QML modules.

Launch the result:

```bat
outputs\Daylight\app\Daylight.exe
```

Close any running copy before rebuilding and replacing the executable.

### Manual build

For more control, run the following from the repository root, using the same developer prompt and `QT_ROOT` setting:

```bat
cmake -S outputs\Daylight\source -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%QT_ROOT%"
cmake --build build
```

To assemble a runnable application folder:

```bat
if not exist outputs\Daylight\app mkdir outputs\Daylight\app
copy /y build\Daylight.exe outputs\Daylight\app\Daylight.exe
"%QT_ROOT%\bin\windeployqt.exe" --release --qmldir outputs\Daylight\source --no-translations outputs\Daylight\app\Daylight.exe
```

If Ninja is unavailable, use the `NMake Makefiles` generator in a separate build directory:

```bat
cmake -S outputs\Daylight\source -B build-nmake -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%QT_ROOT%"
cmake --build build-nmake
```

In that case, use `build-nmake\Daylight.exe` in the copy command above. Do not switch generators inside an existing build directory.

### Common build problems

- **Qt6 cannot be found:** check that `QT_ROOT` points to the Qt kit directory containing `bin`, `lib`, and `include`, rather than to the top-level Qt installation folder.
- **`cl`, CMake, or Ninja is not found:** use the x64 developer prompt and make sure the relevant Visual Studio C++ and CMake components are installed and on `PATH`.
- **A DLL or QML module is missing when launching:** run `windeployqt` and launch the executable from the resulting `app` folder. Keep that folder's contents together.
- **Changes do not appear:** rebuild, copy the new executable into the application folder, and reopen that copy. QML and image assets are embedded in the executable.

Windows is the existing packaging workflow. A Linux source build has also been verified with Qt 6.8.3 and GCC; Linux packaging and macOS builds have not been validated.

## Build on Linux

Requires a C++17 compiler, CMake 3.21 or newer, Ninja, and **Qt 6.8 or newer** with Qt Quick/QML. The system Qt may be older than the installed SDK; point CMake at the desired Qt kit explicitly.

From the repository root, using the Qt 6.8.3 installation used during development:

```bash
cmake -S outputs/Daylight/source -B build-linux -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$HOME/Qt/6.8.3/gcc_64" \
  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="$PWD/build-linux/bin"

cmake --build build-linux -j "$(nproc)"
./build-linux/bin/Daylight
```

Adjust `CMAKE_PREFIX_PATH` for your installation. The separate `bin` output directory avoids a name collision between the Linux executable and CMake’s generated `Daylight` QML directory.

For subsequent changes, close Daylight, rebuild, and reopen:

```bash
cmake --build build-linux -j "$(nproc)"
./build-linux/bin/Daylight
```

QML, constellation data, and images are embedded, so source changes require a rebuild. No additional downloads are needed when running the application.

## Project layout

```text
outputs/Daylight/
  source/
    CMakeLists.txt        Build configuration and embedded resources
    Main.qml              Responsive map, footer switches, and time buttons
    main.cpp              Astronomy, time navigation, saved settings, and rendering
    zodiac.h              Zodiac coordinates, projection, and subtle sky overlay
    data/
      zodiac.json         Star coordinates, magnitudes, and pattern connections
      README.md           Catalog sources, units, and accuracy notes
      D3-CELESTIAL-LICENSE Bundled zodiac-data license
    app.rc                Embedded Windows executable icon
    build.cmd             Windows build and deployment helper
    assets/
      world_changed.jpg   World map used by the application
      world.jpg           Original NASA map
      moon-full.jpg       Full-Moon photograph
      daylight.ico        Multi-resolution Windows icon
      daylight.png        Larger icon image
      README.md           Image sources and attribution
    tools/
      make-icon.cpp       Utility used to generate the Earth icon
    vendor/
      astronomy.c        Astronomy Engine implementation
      astronomy.h        Astronomy Engine declarations
      LICENSE            Astronomy Engine license
  app/                    Generated executable and runtime dependencies
work/                     Local tools, SDKs, and development files
```

Generated builds, packaged binaries, and downloaded SDKs do not need to be committed. Keep the source files, bundled image assets, and their attribution notices in the repository.

## Controls and saved preferences

On the first launch, the Sun, Moon, and labels are visible. Planets, constellations, and latitude lines start hidden. Saved switch choices take precedence on later launches. The six footer switches control:

| Switch | Shows or hides |
| --- | --- |
| Sun | The Sun marker and its label |
| Moon | The Moon marker and its label |
| Planets | Mercury, Venus, Mars, Jupiter, and Saturn, with their labels |
| Constellations | Zodiac stars, connecting lines, constellation names, and the ecliptic |
| Latitude lines | Equator, both tropics (approximately 23.44 degrees north/south), and both polar circles (approximately 66.56 degrees north/south), in subtle green |
| Labels | Sun, Moon, planet and constellation names, plus latitude degree labels, without hiding the markers or lines |

The switches are independent: hiding labels leaves the bodies and figures visible, and hiding a body also hides its label. Hiding the Sun marker does not turn off daylight shading.

The chosen switch states are saved immediately using Qt settings and restored on the next launch. On Linux they are stored in `~/.config/Daylight/Daylight.conf` (or under `$XDG_CONFIG_HOME`); Windows uses the current user’s `Software\Daylight\Daylight` registry settings. Switches support mouse clicks, Tab navigation, and Space or Enter.

The footer stays anchored to the bottom in normal, maximized, and full-screen windows. The map fills the area above it. Controls share a compact row when space permits and stack on narrower windows.

### Time navigation

A single navigation group controls all map layers. Click the middle label to choose **5 Minutes**, **15 Minutes**, **30 Minutes**, **1 Hour** (the initial selection), **2 Hours**, **6 Hours**, **1 Sidereal Day**, or **24 Hours**.

The main arrows move once by the selected interval. Each smaller outer section starts animation in that direction; pressing the active section again pauses.

- **5 Minutes through 6 Hours:** advance one selected interval per real second, divided into ten smaller updates for smoother motion. Elapsed time determines the displayed instant.
- **1 Sidereal Day and 24 Hours:** show the first step immediately, then advance one complete interval every half-second. There are no intermediate frames, so daylight shading does not sweep across the map. Each timer tick advances exactly one interval, without repeated or skipped dates caused by rounding. A sidereal step is exactly **23h 56m 4.09s**.

Changing the interval during playback preserves the displayed time and direction and applies the new rate; it does not add an immediate extra step.

Manual stepping pauses playback first. **Escape** pauses; **Now** stops playback and returns to actual current time, with live updates every 30 seconds. All layers use the same displayed instant, including Moon phase and zodiac. Hover descriptions and Tab/Space/Enter navigation are available for the direction controls. Only one playback mode runs at a time: starting Earth rotation stops navigation animation, and starting navigation animation pauses Earth rotation. The selected interval, rotation speed, and playback state are not saved.

The date/time beneath the controls is local to the computer and includes the UTC offset for the selected date. Steps are elapsed UTC durations, so the local wall-clock hour can change across daylight-saving transitions. The application starts in live mode on each launch; the selected time and playback state are not saved. Controls and layer switches share one compact row when space permits, and stack on narrower windows.

Geographic latitude lines stay fixed on Earth while the celestial overlays move. The slightly thicker equator and the other parallels use green, distinct from the lavender ecliptic. Degree labels repeat at the left edge, center, and right edge (0, +/-23.44, and +/-66.56 degrees); the Labels switch also controls these labels. They have their own saved toggle and do not depend on constellation or label visibility.

### Zoom and pan

Click a place on the map to center it and smoothly zoom in. That geographic location stays centered through time navigation and animation. Click the Sun, Moon, or a visible planet to follow that body instead; a small badge identifies the current target. The mouse wheel zooms around the pointer, from the whole world up to 8x. Drag to pan and lock a new geographic location; longitude wraps seamlessly and vertical panning stops at the poles. Wheel zoom keeps a followed body centered. Double-click the map or use the small **Fit map** control to release the target and show the whole Earth again. Body markers and latitude labels stay readable while zooming. Camera position and zoom are not saved.

### Earth's daily rotation

The **globe-and-arrow button** in the footer plays Earth's daily rotation beneath the sky, at a selectable speed. The adjacent speed dropdown ranges from one simulated minute to eight simulated hours per real second; the default is **2 h/s** (24 hours in 12 seconds). Speed choices are **1, 5, 15, or 30 min/s**, and **1, 2, 4, or 8 h/s**. Here, h/s means simulated hours per real second. Speed can change while paused or playing without jumping the selected time. Stars remain nearly fixed in the view while the continents pass beneath them. The Sun, Moon, and planets retain their independent motion against the stars. Daylight stays aligned with the Sun, rather than being painted permanently onto the moving land.

The globe button is highlighted during playback; click it again to pause. Pausing holds the selected time and sky-oriented view. Hour/day navigation still works in that view; manual steps stop continuous playback first. **Now** stops all playback, returns to current time, and restores the usual Earth-fixed view. **Escape** also pauses, and closing or hiding the window stops playback. A selected geographic location or body remains centered across navigation, rotation, and **Now**. Use **Fit map** to release tracking and watch Earth pass beneath the sky.

Earth movement uses elapsed time and updates about 30 times per second. Astronomy and shading are refreshed at a lower cadence, with lower-resolution night shading during playback, to keep the land motion responsive; full-resolution shading returns when paused. No additional network services or dependencies are needed.

## Customize the appearance

Edit [Main.qml](outputs/Daylight/source/Main.qml) to change the initial window size, footer switches, and body-label appearance. Marker sizes are the `sizes` array in `Sky::markers()` in [main.cpp](outputs/Daylight/source/main.cpp); constellation styling and label size are in [zodiac.h](outputs/Daylight/source/zodiac.h).

In `zodiacImage()`, `font.setPixelSize(...)` controls constellation-label size; the current value is **15 pixels**. The nearby `strokePath()` and `fillPath()` calls control their dark outline and grey fill. Star brightness and connecting-line appearance are set independently, so increasing label readability does not make the figures dominate the map.

Edit [main.cpp](outputs/Daylight/source/main.cpp) to change:

- **Daylight brightness:** the lookup table in `dayImage()`.
- **Night shading and twilight fade:** `nightImage()`.
- **Horizon line:** the painter's pen color, alpha, and width in `nightImage()`.
- **Moon illumination:** `moonImage()`.
- **Sun appearance:** `sunImage()`.
- **Update intervals:** the live refresh timer in `main()` and the playback timers in `Sky`. Navigation choices are `navigationIntervals` and `navigationLabels`; `intervalIndex` selects the initial choice. Continuous rotation speeds are `rotationRates`; `rotationSpeedIndex` selects the initial speed.

Rebuild after changing C++, QML, or bundled assets.

## Developer checks

The executable includes a self-test for seasonal solar declination, known new/full Moons, phase orientation, day/night shading, horizon geometry, zodiac rotation, ecliptic alignment, and date-line wrapping:

```bat
start "" /wait outputs\Daylight\app\Daylight.exe --self-test
echo Exit code: %ERRORLEVEL%
```

On Linux:

```bash
./build-linux/bin/Daylight --self-test
./build-linux/bin/Daylight --capture "$PWD/preview.png"
```

For a headless Linux check, prefix either command with `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software`.

Exit code `0` means the checks passed. To capture the current map on Windows and exit:

```bat
start "" /wait outputs\Daylight\app\Daylight.exe --capture "%CD%\preview.png"
```

The capture waits for the initial rendered layout before saving. During development, the controls were also checked with mouse and keyboard input, saved preferences were restored in a separate process, and navigation was exercised at normal, minimum, ultrawide, maximized, and full-screen sizes. These interaction checks are separate from the built-in `--self-test`.

## How to read the map

The map uses an equirectangular projection, with Greenwich at the center. The markers show the geocentric points directly beneath the Sun, Moon, and five naked-eye planets, rather than the areas where those bodies are visible. Planet positions use the same apparent geocentric calculation as the Sun and Moon and update every 30 seconds in live mode. Mercury is gray, Venus cream, Mars rust-colored, Jupiter banded, and Saturn ringed. Where markers overlap, the nearer body covers the farther one, including overlaps with the Sun and Moon. Their sizes are illustrative, not to scale, so marker overlaps do not predict actual transits or occultations.

The horizon line uses a conventional solar-center altitude of approximately **−0.833°**, accounting for the Sun's upper edge and typical horizon refraction. Shading begins at this line, increases through early twilight, and reaches full night at a geometric solar altitude of **−18°**. It is a visual representation rather than a prediction of local sky brightness. See [NOAA's sunrise/sunset calculation notes](https://gml.noaa.gov/grad/solcalc/solareqns.PDF).

The Moon's illuminated fraction is calculated for the displayed time. Its photograph retains a fixed orientation, with waxing illumination on the right and waning illumination on the left. The display does not simulate lunar libration, eclipses, local atmospheric conditions, terrain obstruction, or light pollution.

The twelve traditional zodiac constellations use bright-star stick figures from D3-Celestial, with XHIP-based J2000 coordinates. Each star is mapped individually to its geocentric point over Earth, corrected for precession, nutation, and annual aberration. Their natural angular sizes are preserved; the map projection can distort the familiar shapes. Stellar proper motion and individual stellar parallax are not modeled, so these are catalog-based positions suitable for this map rather than precision astrometry. The twelve traditional figures exclude Ophiuchus.

The ecliptic is the true ecliptic of date, sampled around the complete circle and projected using the same sidereal rotation as the markers. Zodiac lines, stars, and labels are drawn behind all Solar System markers and remain faint at different window sizes. No network connection is used at runtime.

The Earth image is based on a fixed NASA Blue Marble composite, not live satellite imagery. Accurate system time is important for all sky positions in live mode.

## Credits and third-party licenses

- **Earth imagery:** [NASA Earth Observatory, Blue Marble Next Generation with Topography](https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography/), October 2004. The application uses the project's modified `world_changed.jpg`; the original map is retained as `world.jpg`. The Earth icon is also derived from the map.
- **Moon photograph:** [FullMoon2010.jpg by Gregory H. Revera](https://commons.wikimedia.org/wiki/File:FullMoon2010.jpg), licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). The photograph is cropped, resized, and shaded at runtime. The adapted lunar imagery is also provided under CC BY-SA 3.0.
- **Zodiac data:** [D3-Celestial by Olaf Frohn](https://github.com/ofrohn/d3-celestial), BSD-3-Clause. The embedded subset uses conventional constellation figures and XHIP-based star positions and magnitudes. Sources and extraction details are in [source/data/README.md](outputs/Daylight/source/data/README.md); retain the bundled license when distributing.
- **Astronomical calculations:** [Astronomy Engine by Don Cross](https://github.com/cosinekitty/astronomy), MIT license. Its source and license are included in [source/vendor](outputs/Daylight/source/vendor/).
- **User interface and rendering:** [Qt](https://www.qt.io/), dynamically linked. Qt and its dependencies retain their applicable licenses. Retain the relevant notices and license materials when distributing packaged builds.

Additional image attribution is recorded in [source/assets/README.md](outputs/Daylight/source/assets/README.md).
