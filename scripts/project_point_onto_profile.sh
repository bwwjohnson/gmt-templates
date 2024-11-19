#!/bin/bash
gmt gmtset FORMAT_GEO_MAP D
file="test_project"
bounds=-R69.0/72.0/37.5/39.5
proj=-JM20c


# profile params
elon=70.5
elat=39.0
slon=70.5
slat=38.0
#profile width / km, angle / deg , z range
wid=100
prof_dip=90
# parallel z scale
para_min_z=-30
para_max_z=5
# perpendicular z scale
perp_min_z=-15
perp_max_z=15
#set section length and height / cm
proj_len=20
proj_hgt=5

# get profile distance / km
gmt mapproject -Af -G+k  << EOF > tmp_distances
$slon $slat
$elon $elat
EOF
sect_dist=`awk 'NR==2{printf("%d",$4)}' tmp_distances`


point1[1]=70.1 
point1[2]=38.7
point1[3]=7.5

point2[1]=71
point2[2]=38.4
point2[3]=2



gmt begin $file
    # plot topo
    gmt grdimage @earth_relief_30s_g $bounds $proj -I+a-45+nt1+m0 -Bxa0.5f0.5 -Bya0.5f0.5
    # plot points on map
    echo ${point1[1]} ${point1[2]} | gmt plot -Sc0.2 -W1p,black -Gred
    echo ${point2[1]} ${point2[2]} | gmt plot -Sc0.2 -W1p,black -Gblue

    # plot section line on map
gmt plot -W2p,- << EOF
$slon $slat
$elon $elat
EOF
    # plot end of section symbols on map
    echo $slon $slat | gmt plot -St1 -W1p,black -Gorange
    echo $elon $elat | gmt plot -St1 -W1p,black -Gpurple

    # starting cross section
    # define cross section projection and boundaries and offset from map
    proj2=-JX$proj_len/$proj_hgt
    bounds2=-R-5/$((sect_dist + 5))/$perp_min_z/$perp_max_z
    ori2="-Xa0 -Ya-6"

    # define cross section basemap and axes
    gmt basemap $proj2 $bounds2 $ori2 -BwSEn -Bpxa20+l"Distance along section (km)"  -Bpya2+l"Depth (km)"
    
    # plot end of section symbols on section
    echo 0 $perp_max_z 0 | gmt plot $proj2 $bounds2 $ori2 -Si0.8c -W0.3p -Gorange
    echo $sect_dist $perp_max_z 0 | gmt psxy $proj2 $bounds2 $ori2 -Si0.8c -W0.3p -Gwhite

    # project points
    echo ${point1[*]} | gmt project -Q -C$slon/$slat -E$elon/$elat -W-$wid/$wid -Fpz -S -Lw | gmt plot $bounds2 $proj2 $ori2 -Sc0.2 -Gblue 
    echo ${point2[*]} | gmt project -Q -C$slon/$slat -E$elon/$elat -W-$wid/$wid -Fpz -S -Lw | gmt plot $bounds2 $proj2 $ori2 -Sc0.2 -Gred
gmt end show
