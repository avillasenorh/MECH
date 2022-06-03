#!/usr/bin/env bash
#: Name        : rcmt_plots.sh
#: Description : make plots of RCMT solution
#: Usage       : rcmt_plots.sh ...
#: Date        : 2022-06-02
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

#progname=${0##*/}
#[[ $# -ne 2 ]] && { echo "usage: $progname argument1 argument2"; exit 1; }

# Clean up previous runs
/bin/rm -f CMP1.plt CALPLT.PLT CALPLT.cmd PLTSAC.PLT

# 1. Best solution
depth_dir=${PWD##*/}
[[ ! -s wvfgrd.${depth_dir}.out ]] && { echo "ERROR: grid search output file does not exist"; exit 1; }
/bin/rm -f FMMFIT.PLT wfmmfit.eps wfmmfit.png

fmmfit -DMN 0 -DMX 90 < wvfgrd.${depth_dir}.out
plotnps -BGFILL -F7 -EPS -K < FMMFIT.PLT > wfmmfit.eps
convert -trim -background white -alpha remove -alpha off wfmmfit.eps wfmmfit.png
/bin/rm -f FMMFIT.PLT wfmmfit.eps

# 2. Data fit versus distance
[[ ! -s ../fmdfit.sum ]] && { echo "ERROR: grid search summary file does not exist. Wrong directory?"; exit 1; }
/bin/rm -f FMDFIT.PLT wfmdfit.eps wfmdfit.png

fmdfit -HMN 0 -HMX 30 -MECH < ../fmdfit.sum
plotnps -BGFILL -K -EPS -F7 -W10 < FMDFIT.PLT > wfmdfit.eps
convert -trim -background white -alpha remove -alpha off wfmdfit.eps wfmdfit.png
/bin/rm -f FMDFIT.PLT wfmdfit.eps

# 3. Comparison between waveforms and synthetics

## Header
Y0=11
YT=$( bc -l <<< "$Y0 - 0.2" )

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

#plotnps -BGFILL -K -EPS -F7 -W10 < CALPLT.PLT > temp.eps
/bin/mv -f CALPLT.PLT CMP1.plt
/bin/rm -f CALPLT.cmd

## Make station list
/bin/rm -f distance.list
touch distance.list
for sacfile in *[ZRT]; do
    saclhdr -NL -DIST -KSTNM $sacfile >> distance.list
done

sort -un distance.list | awk '{print $2}' - > station.list
last_station=$( tail -1 station.list )

while read -r station; do
    Y0=$( bc -l <<< "$Y0 - 0.6" )

    case $station in
    $last_station )
        pltsac -O -USER9 -TSCB -K -1 -DOAMP  -XLEN 2.0 -X0 0.25 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}Z.[op]??
        cat PLTSAC.PLT >> CMP1.plt
        /bin/rm -f PLTSAC.PLT

        pltsac -O -USER9 -TSCB -K -1 -DOAMP  -XLEN 2.0 -X0 2.50 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}R.[op]??
        cat PLTSAC.PLT >> CMP1.plt
        /bin/rm -f PLTSAC.PLT

        pltsac -O -USER9 -TSCB -K -1 -DOAMP  -XLEN 2.0 -X0 4.75 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}T.[op]??
        cat PLTSAC.PLT >> CMP1.plt
        /bin/rm -f PLTSAC.PLT
        ;;
    * )

        pltsac -O -USER9 -K -1 -DOAMP  -XLEN 2.0 -X0 0.25 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}Z.[op]??
        cat PLTSAC.PLT >> CMP1.plt
        /bin/rm -f PLTSAC.PLT

        pltsac -O -USER9 -K -1 -DOAMP  -XLEN 2.0 -X0 2.50 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}R.[op]??
        cat PLTSAC.PLT >> CMP1.plt
        /bin/rm -f PLTSAC.PLT

        pltsac -O -USER9 -K -1 -DOAMP  -XLEN 2.0 -X0 4.75 -Y0 ${Y0} -ABS -YLEN 1.0 ${station}T.[op]??
        cat PLTSAC.PLT >> CMP1.plt
        /bin/rm -f PLTSAC.PLT
        ;;
    esac

    calplt << EOF
NEWPEN
1
LEFT
7.00 ${Y0} 0.12 '${station}' 0.0
PEND
EOF
cat CALPLT.PLT >> CMP1.plt
/bin/rm -f CALPLT.PLT CALPLT.cmd

done < station.list

plotnps -BGFILL -K -EPS -F7 -W10 < CMP1.plt > wcmp1.eps
convert -trim -colorspace RGB -background white -alpha remove -alpha off wcmp1.eps wcmp1.png
/bin/rm -f CMP1.plt wcmp1.eps

/bin/rm -f distance.list station.list
