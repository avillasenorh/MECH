#!/usr/bin/env bash
#: Name        : rcmt_qc.sh
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

gsac << EOF
fileid list fname dist az format equals concat on
markt on
xlim vel 3.3 -30 vel 3.3 70
r *H[ZRT]
cut off
sort up dist
rtr
taper w 0.05
hp c $fhighpass n 3
lp c $flowpass n 3
br c 0.12 0.25 n 4 p 2
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

