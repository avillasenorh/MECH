#!/usr/bin/env bash
#: Name        : ${0##*/}
#: Description : Template for bash-shell scripts
#: Usage       : bash_template.sh input_files -o output_file -V
#: Date        : $(date +%Y-%m-%d)
#: Author      : "Antonio Villasenor" <antonio.villasenor@csic.es>
#: Version     : 1.0
#: Requirements: programs required by script (GMT5, gdate, getjul, etc)
#: Arguments   : argument1
#:               argument2
#: Options     : -o output_file   - write ouput to output file
#:               -h               - print help
#:               -V               - verbose
set -e # stop on error
set -u # error if variable undefined
set -o pipefail

progname=${0##*/}
#[[ $# -ne 2 ]] && { echo "usage: $progname argument1 argument2"; exit 1; }

# loop through all prediction files
for component in Z R T; do
    /bin/rm -f ${component}.dat
    touch ${component}.dat
    for pred_file in *${component}.pre; do
        saclhdr -NL -AZ -USER9 $pred_file >> ${component}.dat
    done
done

/bin/rm -f wvfdly96.out
wvfdly96 | tee wvfdly96.out > /dev/null # redirection using ">" does not work !?!?!

az_shift=$( grep AZSHIFT wvfdly96.out | awk '{print $2}' )
t0_shift=$( grep T0SHIFT wvfdly96.out | awk '{print $2}' )
r_shift=$( grep RSHIFT wvfdly96.out | awk '{print $2}' )

awk '{printf("%10.1f %10.1f\n", $1, -3.1*($2 - t0))}' t0=$t0_shift Z.dat > Z.dist
awk '{printf("%10.1f %10.1f\n", $1, -3.1*($2 - t0))}' t0=$t0_shift R.dat > R.dist
awk '{printf("%10.1f %10.1f\n", $1, -3.1*($2 - t0)/0.92)}' t0=$t0_shift T.dat > T.dist

/bin/rm -f cosoff.dat
touch cosoff.dat
for azimuth in {0..360..20}; do
    var=$( bc -l <<< "$r_shift * c( ( $azimuth - $az_shift ) * 3.1415927 / 180.0 )" )
    echo $azimuth $var | awk '{printf("%10.1f %10.1f\n", $1, $2)}' >> cosoff.dat
done

cat << EOF > cmdfil
'Z.dist' 2 0.01 'SQ'
'R.dist' 2 0.01 'CI'
'T.dist' 1 0.01 'TR'
'cosoff.dat' 1 0.04 'NO'
EOF

genplt -XMIN 0 -XMAX 360 -YMIN -30 -YMAX 30 -YLEN 2 -XLEN 6 -C cmdfil -Y0 2.0  -TX 'Azimuth' -TY 'Offset (km )' > /dev/null 2>&1
calplt -V << EOF > /dev/null
NEWPEN
1
CENTER
5.0 4.2 0.14 'Estimate of location error' 0.0

NEWPEN
2
SFILL
'SQ' 0.1 1.4 1.1 
NEWPEN
1
LEFT
1.6 1.05 0.10 'Z-Rayl 3.1 km/s' 0.0

NEWPEN
2
SFILL
'CI' 0.1 3.8 1.1
NEWPEN
1
LEFT
4.0 1.05 0.10 'R-Rayl 3.1 km/s' 0.0

NEWPEN
4
SFILL
'TR' 0.1 6.2 1.1
NEWPEN
1
LEFT
6.4 1.05 0.10 'T-Love 3.5 km/s' 0.0
NEWPEN
1

LEFT
1.35 0.8 0.10 'T0shift (sec)=' 0.0
NUMBER
2.8 0.8 0.10 $t0_shift 0.0 1
LEFT
3.75 0.8 0.10 'AZshift (deg)=' 0.0
NUMBER
5.2 0.8 0.10 $az_shift 0.0 1
LEFT
6.15 0.8 0.10 'Rshift (km)=' 0.0
NUMBER
7.4 0.8 0.10 $r_shift 0.0 1
PEND
EOF

cat CALPLT.PLT >> GENPLT.PLT
plotnps -BGFILL -F7 -W10 -EPS -K < GENPLT.PLT >  wdelay.eps
convert -trim wdelay.eps -background white -alpha remove -alpha off  wdelay.png

/bin/rm -f CALPLT.PLT GENPLT.PLT CALPLT.cmd

/bin/rm -f cmdfil cosoff.dat ?.dist ?.dat
