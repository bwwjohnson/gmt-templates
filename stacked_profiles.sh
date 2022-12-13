#!/bin/bash
gmt gmtset FORMAT_GEO_MAP D:mm

# Written by Ben Johnson 13-Dec-2022

# USER INPUT HERE:
# modify to match your utm zone (e.g. 42N)
epsg="32642"
# files: shapefile line - profiles will be plotted perpendicular to this; DEM --- note: doesn't work if shapefile lines have been modified/deleted, need to create file each time you change the line.
shp="profile_trace_test"
im="dem-DEM_aligned"
# map scale
scale="1:5000"
#resample DEM (y/n); resolution / m
resample="n"
res=0.3

# profile params
len=20 # length / m
spc=10 # spacing / m
smpl=1 # sample distance / m
# hillshade 
az=315 # light azimuth / deg

# END OF USER INPUT
nodataval=`gdalinfo ${im}.tif | grep NoData | awk -F"=" '{print $2}'`
min=`gdalinfo -mm ${im}.tif | grep Min/Max | awk -F"=" '{print $2}' | awk -F"," '{print $1}'`
min=`gdalinfo -mm ${im}.tif | grep Min/Max | awk -F"=" '{print $2}' | awk -F"," '{print $2}'`
echo =======================================
echo RASTER INFO:
echo Min Elev:  $min
echo Max Elev:  $max
echo No Data Value: $nodataval
echo =======================================
# resample
if [ $resample = "y" ]; then
gdalwarp -r average -tr $res $res  -multi -wo NUM_THREADS=ALL_CPUS -co BLOCKXSIZE=256 -co BLOCKYSIZE=256 -co TILED=YES -co NUM_THREADS=ALL_CPUS -co COMPRESS=LZW ${im}.tif ${im}_${res}m.tif
im=${im}_${res}m
fi
gmt begin ${im}_stacked_profiles
  gmt makecpt -Cdem1 -T$min/$max/50 -Z
  echo "loading ${im}"
  gmt grdmath ${im}.tif $nodataval NAN = masked.grd # mask no data value to NaNs
  gmt grdimage masked.grd -I+a${az}+ne0.8  -Jx$scale  -Q  -B
  # sync shapefile
  rsync /mnt/c/Users/bwwjo/Desktop/profile_trace_test.* .
  # convert shapefile.....
  ogr2ogr -f "GMT"  ${shp}.gmt ${shp}.shp 
  # reproject into utm.....
  ogr2ogr -t_srs EPSG:${epsg} ${shp}_reproj.gmt ${shp}.gmt
  # plot trace sections and endpoints
  gmt plot -Jx$scale -W2p,blue ${shp}_reproj.gmt
  # create median stack of profiles. -S[a = mean (average), m = median, p = mode (maximum likelihood), l = lower, L = lower but only consider positive values, u = upper, U = upper but only consider negative values]
  gmt grdtrack ${shp}_reproj.gmt -Gmasked.grd -C${len}/${spc}/${smpl}+v -Sm+sstack.txt > table.txt
  gmt plot -Jx$scale -W0.5p table.txt
  # Show upper/lower values encountered as an envelope
  gmt convert stack.txt -o0,5 > env.txt
  gmt convert stack.txt -o0,6 -I -T >> env.txt
  # scale the plot according to min/max elevation of envelope
  max=`awk 'BEGIN{max=0}{if(($2)>max)  max=($2)}END {print max}' env.txt`
  min=`awk 'BEGIN{min=100000000}{if(($2)<min)  min=($2)}END {print min}' env.txt`
  # plot stacked profiles
  gmt plot -R-$((${len}/2))/$((${len}/2))/$min/$max -JX15c/7.5c -Glightgray env.txt -Yh+3c
  gmt plot -W3p stack.txt -Bxafg1000+l"Profile distance (m)" -Byaf+l"Elev (m)" -BWSne
  echo "0 -2000 MEDIAN STACKED PROFILE" | gmt text -Gwhite -F+jTC+f14p -Dj8p
  # cleanup
  rm ${shp}_reproj.gmt
  rm masked.grd
  rm ${shp}.gmt
  rm env.txt
  rm stack.txt
  rm table.txt
  rm ${im}_${res}m
gmt end show
