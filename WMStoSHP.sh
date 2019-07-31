#!/bin/sh

if [ $1 == "-h" ]; then
  echo $0 LAYERNAME BBOX OUTPUT_FILE_NAME
  exit 0
elif [ $# -lt 3 ]; then
  echo "Missing params (use -h)"
  exit -1
fi

layername=$1
bbox=$2
out=$3

srs=EPSG%3A4326
url=http://localhost:8080/geoserver/wms

## Request (WMS -> MBTiles)

MAX_ZOOM=15
MIN_ZOOM=14
#NEEDS about 35 min
TIMEOUT=36000
TILESET_NAME=$out

curl "$url?service=WMS&version=1.1.0&request=GetMap&layers=$layername&bbox=$bbox&width=768&height=451&srs=$srs&format=mbtiles&transparency=true&bgColor=0xFFFFFF&format_options=max_zoom:$MAX_ZOOM;min_zoom:$MIN_ZOOM;tileset_name:$TILESET_NAME;" --max-time $TIMEOUT -o $out.mbtiles

if [ $? -eq 0 ]; then
  if [ -f wms ]; then
	cat wms;
        rm wms;
        exit 1
  fi
  echo "$out.mbtiles fetched!"
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
