#!/bin/bash

# template for creating GNSS profile along specified line

# GNSS psvelo file format:
# whitespace delimited file with columns: lon lat v_e v_n S_e S_n corr site
# no header line

# ===============================
# USER INPUT START HERE:
profile_name=gps_profile_template           # name of plot
gnss_file=gps_psvelo_metz				# GNSS file path
shpfile=wcf_rough                           # fault shapefile
# Map parameters:
topo=@earth_relief_01m
bounds=-R69/72/37.5/39.5
proj=-JM20c
#set start and end points / degrees
elon=71.9
elat=37.8
slon=69.9
slat=39.2
#profile width / km, angle / deg , z range
wid=30
prof_dip=90
# parallel z scale
para_min_z=-30
para_max_z=5
# perpendicular z scale
perp_min_z=-15
perp_max_z=15
#set section length and height / cm
proj_len=10
proj_hgt=5
# GNSS map settings:
col=black
outline=black
thic=0.5
arr=0.2
fontsize=5
confidence=0.95
gpsscale=0.1
arr_wid=1   #in pixels
trans=0  #transparency
# USER INPUT END HERE:
# ===============================


# get profile distance / km
gmt mapproject -Af -G+k  << EOF > tmp_distances
$slon $slat
$elon $elat
EOF
sect_dist=`awk 'NR==2{printf("%d",$4)}' tmp_distances`



gmt begin $profile_name

	gmt makecpt -Cdem1 -T0/3000/50 -Z
	gmt grdgradient $topo $bounds -Ne0.8 -A100 -fg -G$topo_i.grd
	# -Xc and -Yc to centre the plot in the page (important if adding supplementary plots)
	gmt grdimage $topo $proj $bounds -C -I$topo_i.grd -Xc -Yc  -Bxa1f0.5 -Bya1f0.5 -BwSnE -t40
	gmt basemap $proj $bounds -Bxa1f0.5 -Bya1f0.5 -BwSnE
	gmt coast $proj $bounds -Slightblue -Wthinnest,black -N1
	gmt velo $gnss_file -Se${gpsscale}/${confidence}/${fontsize} -G${col} -A9p+e+p${arr_wid}p+n30 -W0.5p,$outline $bounds $proj -L  -t${trans} -V

	echo starting profile....
	# placing markers and lines on map.... (if using)
	echo "$slon $slat" | gmt plot $bounds $proj -Si0.5c -W0.3p -Gorange
	echo "$elon $elat" | gmt plot $bounds $proj -Si0.5c -W0.3p -Gwhite
	# plot section line on map (if using)
	./LINE $slon $elon $slat $elat | gmt plot $bounds $proj -W1p,- 
	echo check map parameters exist...
	echo "start (lon, lat) = ($slon, $slat)"
	echo "end (lon, lat) = ($elon, $elat)"
	echo "section dist = $sect_dist"
	echo "min z = $min_z"
	echo "max z = $max_z"


	echo add depths to fault traces...
	# convert .shp file to gmt-readable using ogr2ogr
	# ogr2ogr -f "GMT" $shpfile.gmt $shpfile.shp

	# to plot on profile as a vertical line, add entries at 30km depth
	# extract the vertices using header line | delete header line | append column with 30 | duplicate each line and change depth from 30 to 0
	sed -n -e '/# @D/,$p' wcf_rough.gmt | sed '1,1 d' | sed '1,$s/$/\ 30/' | sed -E 'p; s/\30/0/' > tmp_wcf0_30

	echo get profile unit vectors...
	para=`awk 'NR==2{printf("%d",$3)}' tmp_distances`
	perp=`bc <<< "$para - 90"`
	echo profile azimuth = $para
	echo perpendicular azimuth = $perp
	echo "1 $para" | gmt vector -N -Co > tmp_unit_para
	echo "1 $perp" | gmt vector -N -Co > tmp_unit_perp
	e_para=`awk '{print $2}' tmp_unit_para`
	n_para=`awk '{print $1}' tmp_unit_para`
	e_perp=`awk '{print $2}' tmp_unit_perp`
	n_perp=`awk '{print $1}' tmp_unit_perp`

	# echo e_para is $e_para
	# echo n_para is $n_para
	# echo e_perp is $e_perp
	# echo n_perp is $n_perp

	echo get profile velocity components...
	# manual dot product using profile parallel and perpendicular unit vector components 
	# for errors, assume ellipse is circle whose radius is the larger of Se and Sn. In this case, error is +/- radius
	echo profile perpendicular components...
	awk -v e_perp="$e_perp" -v n_perp="$n_perp" '{if($5>$6)print $1,$2,$3*e_perp+$4*n_perp,$5,$8}; {if($5<$6)print $1,$2,$3*e_perp+$4*n_perp,$6,$8}' $gnss_file > tmp_gps_perp
	echo profile parallel components...
	awk -v e_para="$e_para" -v n_para="$n_para" '{if($5>$6)print $1,$2,$3*e_para+$4*n_para,$5,$8}; {if($5<$6)print $1,$2,$3*e_para+$4*n_para,$6,$8}' $gnss_file > tmp_gps_para


	echo plot perpendicular....
	# set section perpendicular basemap parameters
	proj2=-JX$proj_len/$proj_hgt
	bounds2=-R-5/$((sect_dist + 5))/$perp_min_z/$perp_max_z
	ori2="-Xc0 -Yc-12" # offset from centre if using with map
	# initialise basemap, add titles
	gmt psbasemap $proj2 $bounds2 $ori2 -BwSEn -Bpxa20+l"Distance along section (km)"  -Bpya2+l"Prof perp vel (mm/yr)"
	# add profile start/end markers
	echo 0 $perp_max_z 0 | gmt psxy $proj2 $bounds2 $ori2 -Si0.8c -W0.3p -Gorange
	echo $sect_dist $perp_max_z 0 | gmt psxy $proj2 $bounds2 $ori2 -Si0.8c -W0.3p -Gwhite
	# project velocity components and plot on profile
	awk '{print $1,$2,$3,$4}' tmp_gps_perp | gmt project -Q -C$slon/$slat -E$elon/$elat -W-$wid/$wid -Fpz -S -Lw | gmt plot $bounds2 $proj2 $ori2 -Sc0.2 -Gblue -Ey -V
	echo plot fault intersections...
	cat tmp_wcf0_30 | gmt project -Q -C$slon/$slat -E$elon/$elat -W-10/10 -Fpz -S -Lw | gmt plot $bounds2 $proj2 $ori2 

	echo plot parallel...
	# set section parallel basemap parameters
	proj2=-JX$proj_len/$proj_hgt
	bounds2=-R-5/$((sect_dist + 5))/$para_min_z/$para_max_z
	# veritcally offset from other section
	ori2="-Xc0 -Yc-19"
	# initialise basemap, add titles
	gmt psbasemap $proj2 $bounds2 $ori2 -BwSEn -Bpxa20+l"Distance along section (km)"  -Bpya2+l"Prof para vel (mm/yr)"
	# add profile start/end markers
	echo 0 $para_max_z 0 | gmt psxy $proj2 $bounds2 $ori2 -Si0.8c -W0.3p -Gorange
	echo $sect_dist $para_max_z 0 | gmt psxy $proj2 $bounds2 $ori2 -Si0.8c -W0.3p -Gwhite
	# project velocity components and plot on profile
	awk '{print $1,$2,$3,$4}' tmp_gps_para | gmt project -Q -C$slon/$slat -E$elon/$elat -W-$wid/$wid -Fpz -S -Lw | gmt plot $bounds2 $proj2 $ori2 -Sc0.2 -Gblue -Ey
	echo plot fault intersections...
	cat tmp_wcf0_30 | gmt project -Q -C$slon/$slat -E$elon/$elat -W-10/10 -Fpz -S -Lw | gmt plot $bounds2 $proj2 $ori2 

	echo removing tmp_... files
	rm tmp*
	
gmt end show

# open pdf using Preview (MacOS)
open -a preview $profile_name.pdf  &
