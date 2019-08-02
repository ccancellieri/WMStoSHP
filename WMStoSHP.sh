#!/bin/sh

# Powered by SIGEO
# Author: carlo cancellieri

##set -x

if [ $1 == "-h" ]; then
  echo $0 LAYERNAME OUTPUT_FILE_NAME
  exit 0
elif [ $# -lt 2 ]; then
  echo "Missing params (use -h)"
  exit -1
fi

layername=$1
out=$2
_comma="%2C"
_semi="%3A"

if [ -n "$CRS" ]; then
  srs=$CRS
else
  srs="EPSG"$_semi"4326"
  echo "unable to find defined SRS variable CRS=\"EPSG:XXX\" using default ($srs)"
fi

if [ \( -n "$minx" \) -a \( -n "$miny" \) -a \( -n "$maxx" \) -a \( -n "$maxy" \) ]; then
#  bbox="$minx$_comma$miny$_comma$maxx$_comma$maxy"
  echo "BBOX: $minx$_comma$miny$_comma$maxx$_comma$maxy"
else
  bbox="-180"$_comma"-90"$_comma"180"$_comma"90"
  echo "unable to find defined bbox variables minx=\"xxx\" miny=\"xxx\" maxx=\"xxx\" maxy=\"xxx\" using defaults ($bbox)"
fi

if [ -z "$url" ]; then
  url=http://localhost:8080/geoserver/wms
  echo "unable to find defined URL variable url=\"http://localhost:8080/geoserver/wms\" using default ($url)"
fi

## Request (WMS -> MBTiles)

MAX_ZOOM=15
MIN_ZOOM=14
#NEEDS about 35 min
TIMEOUT=36000
TILESET_NAME=$out

echo "<GDAL_WMS>
 <Service name=\"WMS\">
 <Version>1.1.1</Version>
 <ServerUrl>$url</ServerUrl>
 <SRS>$srs</SRS>
 <ImageFormat>image/png</ImageFormat>
 <Layers>$layername</Layers>
 <Styles></Styles>
 </Service>
 <DataWindow>
 <UpperLeftX>$minx</UpperLeftX>
 <UpperLeftY>$maxy</UpperLeftY>
 <LowerRightX>$maxx</LowerRightX>
 <LowerRightY>$miny</LowerRightY>
 <SizeX>20000</SizeX>
 <SizeY>20000</SizeY>
 </DataWindow>
 <Timeout>$TIMEOUT</Timeout>
 <MaxConnections>10</MaxConnections>
 <Projection>$srs</Projection>
</GDAL_WMS>" > $out.xml

gdal_translate $out.xml $out.tif

if [ $? -eq 0 ]; then
  # all checks passed!
  echo "$out.tif fetched!"
  rm $out.xml
else
  echo "Failed to fetch $out.tif"
  exit 1
fi

gdaladdo -r cubic --config COMPRESS_OVERVIEW PNG --config INTERLEAVE_OVERVIEW PIXEL --config BIGTIFF_OVERVIEW IF_NEEDED $out.tif 2 4 8 16

#curl "$url?service=WMS&version=1.1.0&request=GetMap&tiled=true&layers=$layername&bbox=$bbox&width=768&height=451&srs=$srs&format=mbtiles&transparency=true&bgColor=0xFFFFFF&format_options=max_zoom:$MAX_ZOOM;min_zoom:$MIN_ZOOM;tileset_name:$TILESET_NAME;" --max-time $TIMEOUT -o $out.mbtiles

if [ $? -eq 0 ]; then
      # all checks passed!
      echo "$out.tif added overviews."
else
  echo "Failed to process $out.tif"
  exit 1
fi

#Process (MBTiles RGB -> GeoTIFF grayscale with noData)
in=$out
out=$out"_gray"

# NODATA_VALUE is floor((255+255+255)/3) 
NODATA_VALUE=84

#TODO: BETTER CALC

gdal_calc.py -R $in.tif --R_band=1 -G $in.tif --G_band=2 -B $in.tif --B_band=3 -A $in.tif --overwrite --calc="(R+G+B)/3" --NoDataValue=$NODATA_VALUE --outfile="$out.tif"

if [ $? -eq 0 ]; then
  echo "Succesfully generated $out.tif"
  rm $in.tif
else
  echo "Unable to generate $out.tif"
  exit 1
fi

## Polygonize (GeoTIFF -> SHP)

_in=$in
in=$out
out=$_in

gdal_polygonize.py $in.tif -b 1 -f "ESRI Shapefile" $out.shp

if [ $? -eq 0 ]; then
  echo "Succesfully generated $out.shp"
  rm $in.tif
else
  echo "Unable to generate $out.shp"
  exit 1
fi

## Simplify (SHP -> SHP)
#in=$out
#m=1
#out=$in"_simplified_"$m
#ogr2ogr -f 'ESRI Shapefile' -simplify $m $out.shp $in.shp

#if [ $? -eq 0 ]; then
#  echo "Succesfully simplified $in.shp to $out.shp"
#else
#  echo "Unable to simplify $in.shp"
#  exit 1
#fi

exit 0
