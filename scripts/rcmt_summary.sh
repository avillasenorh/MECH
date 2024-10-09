#!/usr/bin/env bash
set -euo pipefail

progname=${0##*/}
curdir=$PWD

#[[ $# -ne 2 ]] && { echo "usage: $progname location_file parameter_file"; exit 1; }

/bin/rm -f summary.txt bad.txt
touch summary.txt bad.txt
for event in [12][09]*; do

    location=$event/location.xyzmdate
    [[ ! -s $location ]] && { echo "WARNING: no location file for event $event"; continue; }

    solution=$event/REG/GRD/fmdfit.best
    [[ ! -s $solution ]] && { echo "WARNING: no solution for event $event"; continue; }

    read -r longitude latitude depth magnitude date_time < $location
    read -r code wdepth strike dip rake Mw fit < $solution

    is_good=$( bc -l <<< "$fit > 0.25" )

    if [[ is_good -eq 0 ]]; then

    echo $date_time $latitude $longitude $wdepth $depth $Mw $magnitude $strike $dip $rake $fit | \
    awk '{printf("%s   %7.4f  %8.4f %3.0f (%5.1f)   %3.1f (%3.1f) %4d %3d %4d %8.4f\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)}' - >> bad.txt

    else

    echo $date_time $latitude $longitude $wdepth $depth $Mw $magnitude $strike $dip $rake $fit | \
    awk '{printf("%s   %7.4f  %8.4f %3.0f (%5.1f)   %3.1f (%3.1f) %4d %3d %4d %8.4f\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)}' - >> summary.txt

    fi

done
