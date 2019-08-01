looking at here:
http://map.sitr.regione.sicilia.it/ArcGIS/services/BCC_PIANI_PAESAGGISTICI/AG_beni_paesaggistici_rettifica_2019/MapServer/WMSServer?version=1.3.0&request=GetCapabilities

you see layer '0' has CRS="CRS:84" minx="12.825667" miny="37.036893" maxx="14.096261" maxy="37.790941"

while the url of the server is:

http://map.sitr.regione.sicilia.it/ArcGIS/services/BCC_PIANI_PAESAGGISTICI/AG_beni_paesaggistici_rettifica_2019/MapServer/WMSServer

so we call

CRS="CRS:84" minx="12.825667" miny="37.036893" maxx="14.096261" maxy="37.790941" url="http://map.sitr.regione.sicilia.it/ArcGIS/services/BCC_PIANI_PAESAGGISTICI/AG_beni_paesaggistici_rettifica_2019/MapServer/WMSServer" ./WMStoSHP.sh 0 Agrigento_0

layer '1':

CRS="CRS:84" minx="12.893691" miny="37.165077" maxx="13.766580" maxy="37.703743" url="http://map.sitr.regione.sicilia.it/ArcGIS/services/BCC_PIANI_PAESAGGISTICI/AG_beni_paesaggistici_rettifica_2019/MapServer/WMSServer" ./WMStoSHP.sh 1 Agrigento_1
