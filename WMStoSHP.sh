#!/bin/sh

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
_semi=":"

bbox=$minx:$miny:$maxx:$maxy
if [ -n "$CRS" ]; then
  srs=$CRS
else
  srs="EPSG"$_semi"4326"
  echo "unable to find defined SRS variable CRS=\"EPSG:XXX\" using defaults ($srs)"
fi

if [ \( -n "$minx" \) -a \( -n "$miny" \) -a \( -n "$maxx" \) -a \( -n "$maxy" \) ]; then
  bbox="$minx$_comma$miny$_comma$maxx$_comma$maxy"
else
  bbox="-180"$_comma"-90"$_comma"180"$_comma"90"
  echo "unable to find defined bbox variables minx=\"xxx\" miny=\"xxx\" maxx=\"xxx\" maxy=\"xxx\" using defaults ($bbox)"
fi

url=http://localhost:8080/geoserver/wms

## Request (WMS -> MBTiles)

MAX_ZOOM=15
MIN_ZOOM=14
#NEEDS about 35 min
TIMEOUT=36000
TILESET_NAME=$out

curl "$url?service=WMS&version=1.1.0&request=GetMap&tiled=true&layers=$layername&bbox=$bbox&width=768&height=451&srs=$srs&format=mbtiles&transparency=true&bgColor=0xFFFFFF&format_options=max_zoom:$MAX_ZOOM;min_zoom:$MIN_ZOOM;tileset_name:$TILESET_NAME;" --max-time $TIMEOUT -o $out.mbtiles

if [ $? -eq 0 ]; then
  # sometimes geoserver returns 200 but the content is still wrong
  if [ -f wms ]; then
    cat wms;
    rm wms;
    exit 1
  elif [ -n "`file $out.mbtiles | grep SQLite`" ]; then
      # all checks passed!
      echo "$out.mbtiles fetched!"
  else
    # ! mbtiles format file recognized
    cat $out.mbtiles;
    rm $out.mbtiles;
    exit 1
  fi 
else
  echo "Failed to fetch $out.mbtiles"
  exit 1
fi

#Process (MBTiles RGB -> GeoTIFF grayscale with noData)
in=$out
out=$out

# NODATA_VALUE is floor((255+255+255)/3) 
NODATA_VALUE=84

#TODO: BETTER CALC

gdal_calc.py -R $in.mbtiles --R_band=1 -G $in.mbtiles --G_band=2 -B $in.mbtiles --B_band=3 -A $in.mbtiles --A_band=4 --overwrite --calc="(R+G+B)/3" --NoDataValue=$NODATA_VALUE --outfile="$out.tiff"

if [ $? -eq 0 ]; then
  echo "Succesfully generated $out.tiff"
else
  echo "Unable to generate $out.tiff"
  exit 1
fi

## Polygonize (GeoTIFF -> SHP)

in=$out

gdal_polygonize.py $in.tiff -b 1 -f "ESRI Shapefile" $out.shp

if [ $? -eq 0 ]; then
  echo "Succesfully generated $out.shp"
else
  echo "Unable to generate $out.shp"
  exit 1
fi

## Simplify (SHP -> SHP)
in=$out
m=6
out=$in"_simplified_"$m
ogr2ogr -f 'ESRI Shapefile' -simplify $m $out.shp $in.shp

if [ $? -eq 0 ]; then
  echo "Succesfully simplified $in.shp to $out.shp"
else
  echo "Unable to simplify $in.shp"
  exit 1
fi
