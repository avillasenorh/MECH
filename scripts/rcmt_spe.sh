#!/usr/bin/env bash
#: Name        : rcmt_spe.sh
#: Description : Script to obtain focal mechanism from the inversion of surface wave spectral amplitudes
#: Usage       : rcmt_spe.sh parfile
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

# check environmental variables
eigen=${GREENDIR}/${vmodel}.REG/SW/

[[ ! -d $eigen ]] && { echo "ERROR: directory with surface wave eigenfunctions does not exists: $eigen"; exit 1; }

curdir=$PWD
[[ ! -d SPE ]] && { echo "ERROR: directory for spectral amplitude inversion does not exist: SPE"; exit 1; }
[[ ! -d SPE/DISP ]] && { echo "ERROR: data directory with spectral amplitudes does not exist: SPE/DISP"; exit 1; }
[[ ! -d SPE/GRD ]] && mkdir -p SPE/GRD

cd SPE/GRD
data_file=ALL.DSP

[[ ! -s $data_file ]] && { echo "ERROR: file with spectral amplitudes does not exist: $data_file"; exit 1; }
/bin/rm -f fmfit*

srfgrd96 -N2 -PATH ${eigen} -O ${data_file} \
    -DMIN ${dist_min}  -DMAX ${dist_max} \
    -DMN ${dip_min}    -DMX ${dip_max}    -DD ${dip_step} \
    -RMN ${rake_min}   -RMX ${rake_max}   -DR ${rake_step} \
    -SMN ${strike_min} -SMX ${strike_max} -DS ${strike_step} \
    -HMN ${depth_min}  -HMX ${depth_max}  -DH ${depth_step} \
    -FMIN ${fit_min}   -PMN ${period_min} 
