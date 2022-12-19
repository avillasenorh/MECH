#!/usr/bin/env bash
#: Name        : rcmt_qc3.sh
#: Description : performs data qc for regional centroid moment tensor inversion (RCMT)
#: Usage       : rcmt_qc.sh
#: Date        : 2022-06-01
#: Author      : "Antonio Villasenor" <antonio.villasenor@csic.es>
#: Version     : 1.0
#: Requirements: gsac, saclhdr
#: Arguments   : none
#: Options     : none
set -e # stop on error
set -u # error if variable undefined
set -o pipefail

progname=${0##*/}
[[ $# -ne 1 ]] && { echo "usage: $progname parameter_file"; exit 1; }

[[ ! -s $1 ]] && { echo "ERROR: parameter file does not exist: $1"; exit 1; }
parfile=$1
source $parfile

curdir=$PWD
[[ -d DAT/ROT ]] && cd DAT/ROT

destdir=../../REG/DAT
[[ ! -d $destdir ]] && { echo "ERROR: destination directory does not exist: $destdir"; exit 1; }

nsac=$( /bin/ls -1 *H[ZRT] | wc -l )

[[ $nsac -gt 0 ]] || { echo "ERROR: no rotated SAC files in current directory: $PWD"; cd $curdir; exit 1; }

/bin/rm -f list.dist
for sacfile in *HZ; do

    echo $( saclhdr -DIST $sacfile ) $sacfile >> list.dist

done

sort -n list.dist > list.sorted
/bin/rm -f list.dist

num_sta=0
file_list=( )
while read -r distance vertical; do

    use=$( bc <<< "$distance > 5.0 && $distance < 600.0" )
    [[ $use -eq 0 ]] && { echo "Skipping $vertical $distance"; continue; }
    num_sta=$((num_sta + 1))

    radial=${vertical::-1}R
    transverse=${vertical::-1}T

    if [[ -s $radial && -s $transverse ]]; then
        file_list+=( $transverse )
        file_list+=( $radial )
        file_list+=( $vertical )
    fi

done < list.sorted
/bin/rm -f list.sorted

echo ${file_list[@]}

#fileid list fname dist az format equals concat on
gsac << EOF
fileid list fname dist az
markt on
xlim vel $qc_window_gv $qc_window_pre vel $qc_window_gv $qc_window_post
read ${file_list[@]}
cut off
sort up dist
rtr
taper w $qc_taper
hp c $qc_highpass n 3
lp c $qc_lowpass n 3
#br c 0.12 0.25 n 4 p 2
qdp 10
ppk q relative perplot 3
wh IHDR20
q
EOF


for sacfile in *H[ZRT]; do

    flag=$( saclhdr -IHDR20 $sacfile )
    select=$( echo $flag | awk '{if ($1 == 1) {print "YES"} else {print "NO"}}' )
    [[ $select == "YES" ]] && { echo $sacfile $flag $select; /bin/cp $sacfile $destdir/.; }

done

