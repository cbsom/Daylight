# Offline constellation catalogs

`zodiac.json` contains only the twelve traditional zodiac constellations, with
147 distinct figure vertices and conventional bright-star connections. It is
compiled into the executable. `constellations.json` adds the other 76 figures with 620 figure vertices, for 88 constellations and 767 figure vertices in total. There are no runtime downloads.

Data adapted from **D3-Celestial**, copyright (c) 2015 Olaf Frohn:

- https://github.com/ofrohn/d3-celestial/blob/master/data/constellations.lines.json
- https://github.com/ofrohn/d3-celestial/blob/master/data/stars.6.json
- https://github.com/ofrohn/d3-celestial/blob/master/data/stars.8.json
- https://github.com/ofrohn/d3-celestial/blob/master/data/constellations.json
- https://github.com/ofrohn/d3-celestial/blob/master/readme.md#files

The zodiac subset was retrieved 2026-10-25; the remaining figures were retrieved 2026-10-29. The upstream project is BSD-3-Clause; the full notice is in
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
to index pairs without changing their connections. The remaining 76 figures use the same extraction process. Vertices are matched to stars.6.json, with stars.8.json supplying one Cetus vertex absent from the brighter catalog. The maximum matching distance for the new figures is approximately 0.00374 degrees. The two Serpens components are merged under the name Serpens without adding connections between them. Ophiuchus is included among the other 76 figures. Only stars belonging to these stick figures are drawn; this is not a full star field.

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
astrometric work. Positions and ecliptic update every 30 seconds in live mode and with each navigation or animation frame, and figure sizes are never reduced to an arbitrary height limit.

Style settings are in `zodiacImage()` in `../zodiac.h`. Line widths, dot radii,
and labels use display pixels to keep the overlay quiet when the window grows.

## Visibility

The Zodiac switch shows the twelve traditional figures. All constellations shows all 88, including the zodiac without modifying its saved switch. Turning it off restores the Zodiac setting. Both switches default to hidden on first launch and save their states independently. Labels controls names for both sets. My Horizon fades both sets consistently outside the selected horizon.
