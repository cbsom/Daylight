# Daylight

A small desktop application that shows where it is day, twilight, and night on Earth right now.

Daylight displays a high-resolution world map in a single window. The daylight side stays bright, the night side is shaded, and a smooth transition shows twilight. A subtle line marks the approximate sunrise/sunset boundary. Sun and Moon markers show the points on Earth directly beneath them, and the Moon uses a real photograph shaded to its current phase.

The application is built with **C++17 and Qt Quick/QML**. It runs locally, works offline, and updates every ten seconds using the computer's current time. There are no accounts, API keys, map servers, or runtime downloads.

## Features

- High-resolution, flat world map with north at the top.
- Live daylight and night shading, with a gradual twilight transition.
- A thin, subdued sunrise/sunset boundary.
- Current Sun and Moon positions over Earth.
- Photographic Moon with a calculated phase shadow and a fixed orientation.
- A simple window with a small footer and no clock or time controls.
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

Windows is the build and packaging workflow currently verified for this project. The main Qt/C++ code is portable, but macOS and Linux builds and packages have not been validated.

## Project layout

```text
outputs/Daylight/
  source/
    CMakeLists.txt        Build configuration and embedded resources
    Main.qml              Window layout, marker sizes, and footer
    main.cpp              Astronomy, twilight shading, and image rendering
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

## Customize the appearance

Edit [Main.qml](outputs/Daylight/source/Main.qml) to change the initial window size, footer, and Sun/Moon marker sizes.

Edit [main.cpp](outputs/Daylight/source/main.cpp) to change:

- **Daylight brightness:** the lookup table in `dayImage()`.
- **Night shading and twilight fade:** `nightImage()`.
- **Horizon line:** the painter's pen color, alpha, and width in `nightImage()`.
- **Moon illumination:** `moonImage()`.
- **Sun appearance:** `sunImage()`.
- **Update interval:** the timer configured in `main()`.

Rebuild after changing C++, QML, or bundled assets.

## Developer checks

The executable includes a self-test for seasonal solar declination, known new/full Moons, phase orientation, day/night shading, and horizon geometry:

```bat
start "" /wait outputs\Daylight\app\Daylight.exe --self-test
echo Exit code: %ERRORLEVEL%
```

Exit code `0` means the checks passed. To capture the current map and exit:

```bat
start "" /wait outputs\Daylight\app\Daylight.exe --capture "%CD%\preview.png"
```

## How to read the map

The map uses an equirectangular projection, with Greenwich at the center. The markers show the geocentric subsolar and sublunar points, rather than the areas where those bodies are visible. Their sizes are illustrative, not to scale.

The horizon line uses a conventional solar-center altitude of approximately **−0.833°**, accounting for the Sun's upper edge and typical horizon refraction. Shading begins at this line, increases through early twilight, and reaches full night at a geometric solar altitude of **−18°**. It is a visual representation rather than a prediction of local sky brightness. See [NOAA's sunrise/sunset calculation notes](https://gml.noaa.gov/grad/solcalc/solareqns.PDF).

The Moon's illuminated fraction is calculated for the current time. Its photograph retains a fixed orientation, with waxing illumination on the right and waning illumination on the left. The display does not simulate lunar libration, eclipses, local atmospheric conditions, terrain obstruction, or light pollution.

The Earth image is based on a fixed NASA Blue Marble composite, not live satellite imagery. Accurate system time is important for the Sun and Moon positions.

## Credits and third-party licenses

- **Earth imagery:** [NASA Earth Observatory, Blue Marble Next Generation with Topography](https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography/), October 2004. The application uses the project's modified `world_changed.jpg`; the original map is retained as `world.jpg`. The Earth icon is also derived from the map.
- **Moon photograph:** [FullMoon2010.jpg by Gregory H. Revera](https://commons.wikimedia.org/wiki/File:FullMoon2010.jpg), licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). The photograph is cropped, resized, and shaded at runtime. The adapted lunar imagery is also provided under CC BY-SA 3.0.
- **Astronomical calculations:** [Astronomy Engine by Don Cross](https://github.com/cosinekitty/astronomy), MIT license. Its source and license are included in [source/vendor](outputs/Daylight/source/vendor/).
- **User interface and rendering:** [Qt](https://www.qt.io/), dynamically linked. Qt and its dependencies retain their applicable licenses. Retain the relevant notices and license materials when distributing packaged builds.

Additional image attribution is recorded in [source/assets/README.md](outputs/Daylight/source/assets/README.md).
