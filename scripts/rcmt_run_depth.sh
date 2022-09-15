#!/usr/bin/env bash
#: Name        : rcmt_run_depth.sh
#: Description : Runs waveform inversion for a given depth
#: Usage       : rcmt_run_depth.sh depth_string parfile
#: Date        : 2022-06-01
#: Author      : "Antonio Villasenor" <antonio.villasenor@csic.es>
#: Version     : 1.0
#: Requirements: ...
#: Arguments   : depth string (0010 for 1 km)
#:               parameter file
#: Options     : none
set -e # stop on error
set -u # error if variable undefined
#set -o pipefail  # commented out because it makes script to stop in Linux systems

progname=${0##*/}
[[ $# -ne 2 ]] && { echo "usage: $progname depth_string parameter_file"; exit 1; }
sdepth=$1

[[ ! -s $2 ]] && { echo "ERROR: parameter file does not exist: $2"; exit 1; }
source $2

curdir=$PWD
datadir=REG/DAT
[[ ! -d $datadir ]] && { echo "ERROR: data directory does not exist: $datadir"; exit 1; }
grddir=REG/GRD
[[ ! -d $grddir ]] && { echo "ERROR: grid search directory does not exist: $grddir"; exit 1; }

# Create depth directory
echo "Removing and creating depth directory $grddir/$sdepth"
cd $grddir
/bin/rm -rf ./$sdepth
mkdir -p ./$sdepth
cd ./$sdepth

# Initialize gsac macros to cut, filter, and decimate waveforms and Green's functions
/bin/rm -f cut_green.m cut_wave.m
touch cut_green.m cut_wave.m
echo "cuterr fillz" >> cut_green.m
echo "cuterr fillz" >> cut_wave.m

/bin/rm -f wvfgrd.${sdepth}.in
touch wvfgrd.${sdepth}.in

# Loop through all SAC files
for sacfile in $curdir/$datadir/*H[ZRT]; do

    station=$( saclhdr -KSTNM $sacfile )
    channel=$( saclhdr -KCMPNM $sacfile )
    delta=$( saclhdr -DELTA $sacfile )
    distance=$( saclhdr -DIST $sacfile )

    nam=${channel:(-1)}
    comp=0
    case $channel in
        BHZ|HHZ|HNZ) comp=1 ;;
        BHR|HHR|HNR) comp=2 ;;
        BHT|HHT|HNT) comp=3 ;;
        *) break;;
    esac

#   echo Processing $sacfile $station $channel $delta $distance $comp $nam

    # get file name of closest Green's function
    ctl_file=${GREENDIR}/${vmodel}.REG/${sdepth}/W.CTL
    [[ ! -s $ctl_file ]] && { echo "ERROR: CTL file does not exist for $sdepth"; exit 1; }

#   NOTE: this pipep commands fail in Linux when setting "set -o pipefail" (although it seems to work!?)
    echo $distance | cat - $ctl_file | \
    awk '{if (NR == 1) {d = $1;} else {dd = sqrt((d-$1)*(d-$1)); printf("%s %8.4f %8d %12.2f\n", $7, $2, $1, dd)}}' | \
    sort -n -k4 | head -1 > ${station}.dist

#   /bin/rm -f diff.out
#   touch diff.out
#   while read -r gf_dist delta npts val1 val2 str1 str2; do
#       dist_diff=$( bc -l <<< "sqrt( ($gf_dist - $distance) * ($gf_dist - $distance) )" )
#       echo $dist_diff >> diff.out
#   done < $ctl_file
#   nl1=$( cat $ctl_file | wc -l )
#   nl2=$( cat diff.out | wc -l )
#   [[ $nl1 -ne $nl2 ]] && { echo "ERROR: CTL and difference file have different sizes: $nl1 $nl2"; continue; }

#   paste -d" " $ctl_file diff.out | sort -n -k8 | \
#   awk '(NR == 1) {printf("%s %8.4f %8d %12.2f\n", $7, $2, $1, $8)}' > ${station}.dist
#   /bin/rm -f diff.out

#   awk '{d = dist - $1; if (d < 0.0) d=-d; printf("%s %8.4f %8d %12.2f\n", $7, $2, $1, d)}' \
#   dist=$distance $ctl_file | sort -n -k4 | head -1 > ${station}.dist

    # calculate distance weight and create input file for wvfgrd96
    wt=$( echo $distance $dref | awk '{if ($1 < $2) print $1/$2; else print $2/$1;}' )
    echo $comp ${station}${nam} $station $wt >> wvfgrd.${sdepth}.in

    read -r grn_file rate ndist offset < ${station}.dist
    /bin/rm -f ${station}.dist

    # copy Green's functions for each station (only one time per station) 
    for grn in ZDD RDD ZDS RDS TDS ZSS RSS TSS ZEX REX; do
        grn_full=${GREENDIR}/${vmodel}.REG/${sdepth}/${grn_file}.${grn}
        [[ ! -e $grn_full ]] && { echo "ERROR: Green's function file $grn_full does not exist"; exit 1; }

        if [[ ! -e ${station}.${grn} ]]; then
            /bin/cp $grn_full ${station}.${grn}
            if [[ $windowisp -eq 0 ]]; then
                cutl=$( bc -l <<< "$distance / $vel - $tb" )
                cuth=$( bc -l <<< "$distance / $vel + $te" )
                echo "cut o $cutl o $cuth" >> cut_green.m
            else
                echo "cut a $cutl a $cuth" >> cut_green.m
            fi
            echo "r ${station}.${grn}" >> cut_green.m
            echo "rtr" >> cut_green.m
            echo "taper w 0.1" >> cut_green.m
            echo "hp c  ${fhighpass} np ${npole} p ${pass}" >> cut_green.m
            echo "lp c  ${flowpass} np ${npole} p ${pass}" >> cut_green.m
            if [[ $microseism_reject -eq 1 ]]; then
                echo "br c ${mfl} ${mfh} n ${mnpole} p 2" >> cut_green.m
            fi
            echo "w ${station}.${grn}" >> cut_green.m
        fi
    done 

    gdelta=$( saclhdr -DELTA ${station}.ZSS )

    if [[ $windowisp -eq 0 ]]; then
        cutl=$( bc -l <<< "$distance / $vel - $tb" )
        cuth=$( bc -l <<< "$distance / $vel + $te" )
        echo "cut o $cutl o $cuth" >> cut_wave.m
    else
        echo "cut a $cutl a $cuth" >> cut_wave.m
    fi
    echo "r ${sacfile}" >> cut_wave.m
    echo "rtr" >> cut_wave.m
    echo "taper w 0.1" >> cut_wave.m
    echo "hp c  ${fhighpass} np ${npole} p ${pass}" >> cut_wave.m
    echo "lp c  ${flowpass} np ${npole} p ${pass}" >> cut_wave.m
    if [[ $microseism_reject -eq 1 ]]; then
        echo "br c ${mfl} ${mfh} n ${mnpole} p 2" >> cut_wave.m
    fi
    echo "interpolate DELTA $gdelta" >> cut_wave.m
    echo "w ${station}${nam}" >> cut_wave.m

done

# Run gsac to cut, filter, and decimate waveforms and Green's functions
echo "q" >> cut_wave.m
cat cut_green.m cut_wave.m | gsac > gsac.log

# Run grid search for this depth
wvfgrd96 -N $nshft << EOF
wvfgrd.${sdepth}.in
wvfgrd.${sdepth}.out
EOF

# Clean up Green's functions

/bin/rm -f *.[RTZ][DES][DSX]
cd $curdir
