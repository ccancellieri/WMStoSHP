#!/bin/bash

# Founded by SIGEO 
# Author: carlo cancellieri

if [ "$1" == "-h" ]; then
  echo $0 GET_CAPABILITIES_URL CRS
  exit 0
elif [ "$#" -lt 2 ]; then
  echo "Missing params (use -h)"
  exit -1
fi

CRS=$2

curl $1 -o "WMSServer_orig.xml"

if [ $? -eq 0 ]; then
  # all checks passed!
  echo "GetCapabilities fetched from URL ( $1 )"
else
  echo "Failed to fetch WMSServer_orig.xml from URL ( $1 )"
  exit 1
fi

# sed '1d' WMSServer_orig.xml | sed -e "2 s/xmlns=".*"//g" | sed -e "s/xlink\://g" > WMSServer.xml
sed -e "s/xmlns=\".*\"//g"  WMSServer_orig.xml | sed -e "s/xlink\://g" > WMSServer.xml

if [ $? -eq 0 ]; then
  # all checks passed!
  rm WMSServer_orig.xml
else
  echo "Failed to process WMSServer_orig.xml"
  exit 1
fi

# url=`xmllint --format --xpath 'string(//WMS_Capabilities/Service/OnlineResource/@href)' WMSServer.xml`
url=`xmllint --format --xpath 'string(//WMS_Capabilities/Capability/Request/GetCapabilities/DCPType/HTTP/Get/OnlineResource/@href)' WMSServer.xml`

echo "Base url: $url"

layerSize=`xmllint --format --xpath 'count(//WMS_Capabilities/Capability/Layer/Layer/Title)' WMSServer.xml`

echo "Number of layers: $layerSize"

for (( i=1; i<=$layerSize; i++ )); do
  layer_title=`xmllint --format --xpath 'string(//WMS_Capabilities/Capability/Layer/Layer['$i']/Title)' WMSServer.xml`
  layer_name=`xmllint --format --xpath 'string(//WMS_Capabilities/Capability/Layer/Layer['$i']/Name)' WMSServer.xml`
  echo "Working over layer n. $i : "$layer_name
  cmd=$(xmllint --format --xpath '//WMS_Capabilities/Capability/Layer/Layer['$i']/BoundingBox[@CRS="'$CRS'"]/@*' WMSServer.xml)
  #cmd=$(xmllint --format --xpath '//WMS_Capabilities/Capability/Layer/Layer['$i']/BoundingBox[1]/@*' WMSServer.xml)
  if [ -n "$cmd" ]; then
    cmd="$cmd url=\"$url\" ./WMStoSHP.sh '$layer_name' ${layer_title// /_}"
    echo "Executing: $cmd"
    eval $cmd
  else
    echo "unable to find selected CRS ($CRS) for this layer! (skipping)"
  fi
done

if [ $? -eq 0 ]; then
  # all checks passed!
  echo "Job done!"
  rm WMSServer.xml 
else
  echo "Failed to complete all task at layer number $i"
  exit 1
fi

exit 0

