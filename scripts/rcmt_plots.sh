#!/usr/bin/env bash
#: Name        : rcmt_plots.sh
#: Description : Script to process solution of waveform inversion
#: Usage       : rcmt_plots.sh parfile
#: Date        : 2022-06-10
#: Author      : "Antonio Villasenor" <antonio.villasenor@csic.es>
#: Version     : 1.0
#: Requirements: srfgrd96
#: Arguments   : parameter file
#: Options     : none
set -e # stop on error
set -u # error if variable undefined
set -o pipefail

progname=${0##*/}
[[ $# -ne 1 ]] && { echo "usage: $progname parameter_file"; exit 1; }

[[ ! -s $1 ]] && { echo "ERROR: parameter file does not exist: $2"; exit 1; }
parfile=$1
source $parfile

curdir=$PWD
[[ ! -d REG ]] && { echo "ERROR: directory for waveform inversion does not exist: REG"; exit 1; }
[[ ! -d REG/GRD ]] && { echo "ERROR: directory with waveform inversion results does not exist: REG/GRD"; exit 1; }

cd REG/GRD

[[ ! -s fmdfit.sum ]] && { echo "ERROR: file with grid search summary does not exist: fmdfit.sum"; exit 1; }
[[ ! -s fmdfit.best ]] && sort -nr -k7 fmdfit.sum | head -1 > fmdfit.best

# 1. Plot best focal mechanism

read -r code best_depth strike dip rake Mw fit < fmdfit.best

fmplot -FMPLMN -P -S $strike -D $dip -R $rake
plotnps -BGFILL -F7 -EPS -S0.5 < FMPLOT.PLT > fmplot.eps
#convert -trim -colorspace RGB fmplot.eps fmplot.png

/bin/rm -f FMPLOT.PLT LUNE.PLT

# 2. Plot mechanisms as a function of depth

fmdfit -HMN 0 -HMX 30 -MECH < fmdfit.sum    # 30 hardwired - can be read from parameter file
plotnps -BGFILL -K -EPS -F7 -W10 < FMDFIT.PLT > fmdfit.eps
#convert  -trim fmdfit.eps -background white -alpha remove -alpha off  fmdfit.png

/bin/rm -f FMDFIT.PLT

# cd to directory with best solution

sdepth=$( echo $best_depth | awk '{printf("%04d", 10*$1)}' )

[[ ! -d $sdepth ]] && { echo "ERROR: directory with best solution does not exist: $sdepth"; exit 1; }

cd $sdepth

# 3. Seismograms and synthetics plot

Y0=11
YT=$( bc -l <<< "$Y0 - 0.3" )

/bin/rm -f CMP1.PLT
calplt << EOF
NEWPEN
1
CENTER
1.25 ${YT} 0.2 'Z' 0.0
CENTER
3.50 ${YT} 0.2 'R' 0.0
CENTER
5.75 ${YT} 0.2 'T' 0.0
PEND
EOF
cat CALPLT.PLT > CMP1.PLT
/bin/rm -f CALPLT.*

/bin/rm -f stadepth.list station.list
touch stadepth.list
for sacfile in *[ZRT].obs; do

    sta=$( saclhdr -KSTNM $sacfile )
    distance=$( saclhdr -DIST $sacfile )  # WARNING: it does not write the fractional part !?!?
    echo $sta $distance >> stadepth.list

done

sort -n -k2 stadepth.list | awk '{print $1}' | uniq > station.list
last_station=$( tail -1 station.list )

while read -r station; do

    Y0=$( bc -l <<< "$Y0 - 0.6" )
    if [[ $station == $last_station ]]; then
        pltsac -O -USER9 -TSCB -K -1 -DOAMP  -XLEN 2.0 -X0 0.25 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}Z.[op]??
        cat PLTSAC.PLT >> CMP1.PLT
        pltsac -O -USER9 -TSCB -K -1 -DOAMP  -XLEN 2.0 -X0 2.50 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}R.[op]??
        cat PLTSAC.PLT >> CMP1.PLT
        pltsac -O -USER9 -TSCB -K -1 -DOAMP  -XLEN 2.0 -X0 4.75 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}T.[op]??
        cat PLTSAC.PLT >> CMP1.PLT
    else
        pltsac -O -USER9 -K -1 -DOAMP  -XLEN 2.0 -X0 0.25 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}Z.[op]??
        cat PLTSAC.PLT >> CMP1.PLT
        pltsac -O -USER9 -K -1 -DOAMP  -XLEN 2.0 -X0 2.50 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}R.[op]??
        cat PLTSAC.PLT >> CMP1.PLT
        pltsac -O -USER9 -K -1 -DOAMP  -XLEN 2.0 -X0 4.75 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}T.[op]??
        cat PLTSAC.PLT >> CMP1.PLT
    fi

calplt << EOF
NEWPEN
1
LEFT
7.00 ${Y0} 0.12 '${station}' 0.0
PEND
EOF
cat CALPLT.PLT >> CMP1.PLT
/bin/rm -f CALPLT.*

done < station.list
/bin/rm -f stadepth.list station.list

plotnps -K -EPS -F7 -W10 < CMP1.PLT > cmp1.eps
#gm convert +matte -trim cmp1.eps cmp1.png
#cp cmp1.png cmp1.eps ../.

/bin/rm -f PLTSAC.PLT CMP1.PLT

# 4. Make delay plot

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
plotnps -BGFILL -F7 -W10 -EPS -K < GENPLT.PLT >  delay.eps
#convert -trim delay.eps -background white -alpha remove -alpha off  delay.png
#cp delay.eps delay.png ../.

/bin/rm -f CALPLT.PLT GENPLT.PLT CALPLT.cmd
/bin/rm -f cmdfil cosoff.dat ?.dist ?.dat
