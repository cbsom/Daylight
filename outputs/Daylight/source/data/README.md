# Offline zodiac catalog

`zodiac.json` contains only the twelve traditional zodiac constellations, with
147 distinct figure vertices and conventional bright-star connections. It is
compiled into the executable. There are no runtime downloads.

Data adapted from **D3-Celestial**, copyright (c) 2015 Olaf Frohn:

- https://github.com/ofrohn/d3-celestial/blob/master/data/constellations.lines.json
- https://github.com/ofrohn/d3-celestial/blob/master/data/stars.6.json
- https://github.com/ofrohn/d3-celestial/blob/master/readme.md#files

Retrieved 2026-10-25. The upstream project is BSD-3-Clause; the full notice is in
`D3-CELESTIAL-LICENSE`, which must accompany source and binary redistribution.
The notice is also embedded in the executable resources.

D3-Celestial credits its star catalog to **XHIP: An Extended Hipparcos
Compilation**, Anderson & Francis (2012), VizieR V/137D, and its constellation
figures to the IAU constellation charts with modifications by Olaf Frohn.

## Extraction and units

For Ari, Tau, Gem, Cnc, Leo, Vir, Lib, Sco, Sgr, Cap, Aqr, and Psc, unique vertices
from each figure's polylines were matched to the closest `stars.6.json` catalog
entry. All matches were within 0.01 degrees. Coordinates, Hipparcos identifiers,
and visual magnitudes come from the matched stars; this also reconciles the
small coordinate discrepancy for HIP 43103 in Cancer. Polylines were converted
to index pairs without changing their connections. No other stars are drawn.

`ra` is J2000 right ascension **in degrees**, wrapped to [-180,180], not hours.
`dec` is J2000 declination in degrees. `magnitude` is visual magnitude; `hip` is
the Hipparcos identifier. Each `lines` pair indexes the containing figure's
`stars` array. These fields make the bundled subset inspectable independently
of the rendering code.

Astronomy Engine transforms the catalog directions to the equator of date,
including precession, nutation, and annual aberration, then uses Greenwich
sidereal time to find substellar longitude. The temporary library star slot
uses a very large distance to suppress parallax; individual stellar distances
and proper motions are not supplied by this subset and are not modeled.
The resulting accuracy is appropriate to the map's small dots, not precision
astrometric work. Positions and ecliptic update with the existing ten-second
timer, and figure sizes are never reduced to an arbitrary height limit.

Style settings are in `zodiacImage()` in `../zodiac.h`. Line widths, dot radii,
and labels use display pixels to keep the overlay quiet when the window grows.
