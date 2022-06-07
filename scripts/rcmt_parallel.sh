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
[[ $# -ne 2 ]] && { echo "usage: $progname location_file parameter_file"; exit 1; }

[[ ! -s $1 ]] && { echo "ERROR: location file does not exist: $1"; exit 1; }
locfile=$1

[[ ! -s $2 ]] && { echo "ERROR: parameter file does not exist: $2"; exit 1; }
parfile=$2
source $parfile

curdir=$PWD
[[ ! -d REG ]] && { echo "ERROR: directory for RCMT inversion does not exist: REG"; exit 1; }
[[ ! -d REG/DAT ]] && { echo "ERROR: data directory for RCMT does not exist: REG/DAT"; exit 1; }
[[ ! -d REG/GRD ]] && mkdir -p REG/GRD

# check environmental variables
model_file=${GREENDIR}/Models/${vmodel}.mod

/bin/rm -f depths.list
touch depths.list
for depth in $( seq $depth_min $depth_step $depth_max ); do
    sdepth=$( printf "%03d0\n" $depth )
    echo $sdepth >> depths.list
done

parallel -j 50% -a depths.list rcmt_run_depth.sh {1} $parfile
/bin/rm -f depths.list

cd REG/GRD
cat [0-9]???/fmdfit.dat | tee > fmdfit.sum

sort -nr -k7 fmdfit.sum | head -1 > fmdfit.best
read -r code best_depth strike dip rake Mw fit < fmdfit.best
sdepth=$( echo $best_depth | awk '{printf("%04d", 10*$1)}' )

fmplot -FMPLMN -P -S $strike -D $dip -R $rake
plotnps -BGFILL -F7 -EPS -S0.5 < FMPLOT.PLT > FMPLOT.PS
convert -trim -colorspace RGB FMPLOT.PS wfmplot.png

[[ ! -d $sdepth ]] && { echo "ERROR: directory with best solution does not exist: $sdepth"; exit 1; }

cd $sdepth
rcmt_delays.sh

cd $curdir
