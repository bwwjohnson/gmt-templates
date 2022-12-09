#!/bin/bash

# plot topography, beachball, gps
# Author B. Johnson 2022 (email: benedict.johnson@st-annes.ox.ac.uk)
# works on GMT V>6

# How to use:
# change name of the map at line 16
# change topogrpahy resolution at line 19 (use info here: https://docs.generic-mapping-tools.org/latest/cookbook/features.html?highlight=earth_relief)
# change map edges at line 21
# change cmt_path to point to your fullcmt.out file at line 26
# change gps_path to point to your gps file at line 27



# SETUP
file=azerbaijan_eqs
# specify topography (read more here: https://docs.generic-mapping-tools.org/latest/cookbook/features.html?highlight=earth_relief)
topo=@earth_relief_30s
# set edges of map frame -- CHANGE THIS
bounds=-R45/51/38/43
# set map projection (20c = 20 centimetres wide map)
proj=-JM20c

# Paths to eathquake files 
cmt_path=fullcmt.out
gps_path=T270_test


# GPS PLOT SETTINGS
col=black         # arrowhead colour
arr=0.2           # arrowhead size
outline=black     # outline colour
thic=0.5          # line thickness
fontsize=5        # font size
confidence=0.95   # confidence ellipse
gpsscale=0.1      # scale
wid=1   		  # width
trans=0           # transparency 


# Read earthquake files into tmp files which gmt meca can read
# gCMT
awk '{print $3,$4,$5,$10,$11,$12,$7,$1}' $cmt_path > tmp_cmt

# read in GPS files into tmp files which gmt velo can read
awk '{print $1,$2,$3,$4,$5,$6,0}' $gps_path > tmp_gps

# start gmt
gmt begin $file
	# make colour palette
	gmt makecpt -Cdem1 -T0/3000/50 -Z
	# calculate gradient of DEM (used for hillshading)
	gmt grdgradient $topo $bounds -Ne0.8 -A100 -fg -G$topo_i.grd
	# produce colour image from DEM gradient
	gmt grdimage $topo $proj $bounds -C -I$topo_i.grd  -Bxa1f0.5 -Bya1f0.5 -BwSnE -t40
	# initialise the map
	gmt basemap $proj $bounds -Bxa1f0.5 -Bya1f0.5 -BwSnE
	# draw map boundaries: -S is lakes and seas; -W is line attributes; -N is national borders
	gmt coast $proj $bounds -Slightblue -Wthinnest,black -N1
	# plot beachball
	gmt meca tmp_cmt $proj $bounds -Sa0.4c -Gred -t$trans
	grep "m i ke" m5_events_2015-2017 | awk '{print $5,$4}' | gmt plot -Sc0.2 -Ggreen
	# plot GPS vectors
	gmt velo tmp_gps -Se${gpsscale}/${confidence}/${fontsize} -G${col} -A9p+e+p${wid}p+n30 -W0.5p,$outline $bounds $proj -L  -t${trans} -V
	echo finished

gmt end show



