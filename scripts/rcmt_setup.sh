#!/usr/bin/env bash
set -euo pipefail

progname=${0##*/}
curdir=$PWD

[[ $# -ne 2 ]] && { echo "usage: $progname sfile parfile"; exit 1; }

[[ ! -s $1 ]] && { echo "ERROR: S-file does not exist: $1"; exit 1; }
sfile=$1

[[ ! -s $2 ]] && { echo "ERROR: parameter file does not exist: $2"; exit 1; }
parfile=$2

#evname=$( ~/devel/MECH/scripts/nor2evname.awk $sfile )
evname=$( awk '/I$/ {print substr($0,61,14)}' $sfile )

[[ -z $evname ]] && { echo "ERROR: invalid directory name for $sfile"; exit 1; }
echo $evname

[[ -d $evname ]] && { echo "ERROR: event directory already exists: $evname"; exit 1; }

mkdir -p $evname $evname/LOC $evname/DAT $evname/REG
mkdir -p $evname/DAT/RAW $evname/DAT/VEL $evname/DAT/ROT
mkdir -p $evname/REG/DAT $evname/REG/GRD

/bin/cp -v $parfile $evname/.
~/devel/MECH/scripts/nor2xyzmdate.awk $sfile > $evname/location.xyzmdate
/bin/cp -v $sfile $evname/LOC/.
