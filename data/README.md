# MSOA data

The MSOA names use version 1.12 (10 February 2021) of the [House of Commons Library MSOA Names](https://visual.parliament.uk/msoanames) released under the [Open Parliament Licence](https://www.parliament.uk/site-information/copyright/open-parliament-licence/).

The MSOA polygons come from the [ONS MSOA super generalised clipped boundaries 2011](https://geoportal.statistics.gov.uk/datasets/middle-layer-super-output-areas-december-2011-boundaries-super-generalised-clipped-bsc-ew-v3) released under OGLv3. The Scottish Intermediate Zones comes from [SpatialData.gov.scot](https://spatialdata.gov.scot/geonetwork/srv/eng/catalog.search#/metadata/389787c0-697d-4824-9ca9-9ce8cb79d6f5) but are much too high in resolution for our web map so we need to simplify them. However if we just simplify the individual polygons their boundaries will end up different after simplification so we need to first combine them into TopoJSON so that shared boundaries are treated together. To get from Shapefile to simplified GeoJSON we used the following steps:

  1. Load Shapefile into QGIS and export as GeoJSON (WGS84)
  2. Load GeoJSON into [mapshaper.org](https://mapshaper.org/) and export as TopoJSON
  3. Load TopoJSON back into [mapshaper.org](https://mapshaper.org/)
  4. Simplify the shapes using the options `prevent shape removal` and the `Douglas-Peucker` method.
  5. Repair line intersections
  6. `Simplify` to 1.4%
  7. The coordinates were truncated to 4 decimal places
