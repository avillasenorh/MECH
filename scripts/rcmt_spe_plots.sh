#!/usr/bin/env bash
#: Name        : rcmt_plots.sh
#: Description : Script to process solution of spectral amplitude inversion
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

# check environmental variables
eigen=${GREENDIR}/${vmodel}.REG/SW/

# model file
model_file=${GREENDIR}/Models/${vmodel}.mod

[[ ! -d $eigen ]] && { echo "ERROR: directory with surface wave eigenfunctions does not exists: $eigen"; exit 1; }

curdir=$PWD
[[ ! -d SPE ]] && { echo "ERROR: directory for spectral amplitude inversion does not exist: SPE"; exit 1; }
#[[ ! -d SPE/DISP ]] && { echo "ERROR: data directory with spectral amplitudes does not exist: SPE/DISP"; exit 1; }
[[ ! -d SPE/GRD ]] && mkdir -p SPE/GRD

cd SPE/GRD
data_file=ALL.DSP

[[ ! -s $data_file ]] && { echo "ERROR: file with spectral amplitudes does not exist: $data_file"; exit 1; }

[[ ! -s fmdfit.dat ]] && { echo "ERROR: file with grid search summary does not exist: fmdfit.dat"; exit 1; }

read -r code depth strike dip rake dum1 dum2 Mw1 Mw2 fit <<< $( sort -nr -k10 fmdfit.dat | head -1 )


# Plot distribution of P axis for best mechanisms for best depth (and "lune" plot)
echo "Plotting distribution of P axis for best depth"
fitfile=$( printf "fmfit%03d.dat" ${depth%%.*} )
[[ ! -s $fitfile ]] && { echo "ERROR: file with summary for best depth does not exist: $fitfile"; exit 1; }

sort -nr -k10 $fitfile | awk '$10 > 0.9 * fit' fit=$fit > solutions.list

/bin/rm -f FMPLOT.PLT fm.plt fmplot.log
while read -r code idepth istrike1 idip irake dum1 dum2 imw1 imww ifit; do

    fmplot -S $istrike1 -D $idip -R $irake -tP >> fmplot.log
    cat FMPLOT.PLT >> fm.plt
    /bin/rm -f FMPLOT.PLT

    istrike2=$( bc -l <<< "$istrike1 + 180" )
    fmplot -S $istrike2 -D $idip -R $irake -tP >> fmplot.log
    cat FMPLOT.PLT >> fm.plt
    /bin/rm -f FMPLOT.PLT

done < solutions.list

plotnps -F7 -W10 -EPS -K < fm.plt > fm.eps
/bin/rm -f fm.plt LUNE.PLT fmplot.log solutions.list

# Plot rake distribution for best depth
echo "Plotting rake distribution for best depth"
/bin/rm -f FMMFIT.PLT fmmfit.eps
fmmfit -DMN 0 -DMX 90 < $fitfile
plotnps -K -F7 -W10 -EPS < FMMFIT.PLT > fmmfit.eps

# Plot best mechanism for grid search in depth
echo "Plotting best mechanism as a function of depth"
/bin/rm -f FMDFIT.PLT fmdfit.eps
fmdfit -HMN 0 -HMX 30 -MECH < fmdfit.dat
plotnps -K -F7 -W10 -EPS < FMDFIT.PLT > fmdfit.eps

/bin/rm -f FMMFIT.PLT FMDFIT.PLT

# Plot best mechanism
echo "Plotting best mechanism"
/bin/rm -f FMPLOT.PLT fmplot.eps
fmplot -S $strike -D $dip -R $rake -FMPLMN
plotnps -S0.5 -F7 -EPS < FMPLOT.PLT > fmplot.eps
/bin/rm -f FMPLOT.PLT LUNE.PLT


# Plot SW radiation patterns with data

norm_distance=1000
mode=0
echo "Calculating radiation patterns for Rayleigh and Love waves"
/bin/rm -f SRADR.TXT SRADR.PLT SRADL.TXT SRADL.PLT

sdprad96 -PATH $eigen -R -DIP $dip -RAKE $rake -STK $strike -DIST $norm_distance  -HS $depth \
    -M $mode -MW $Mw2 -O $data_file  -DMIN $dist_min -DMAX $dist_max -A

sdprad96 -PATH $eigen -L -DIP $dip -RAKE $rake -STK $strike -DIST $norm_distance  -HS $depth \
    -M $mode -MW $Mw2 -O $data_file  -DMIN $dist_min -DMAX $dist_max -A

/bin/rm -f kl kr sradl*.eps sradr*.eps
for i in {1..10}; do

    istring=$( printf "%02d" $i )

    reframe -N$i -O < SRADL.PLT > kl
    lsize=$( /bin/ls -l kl | awk '{print $5}' )
    [[ $lsize -gt 100 ]] && plotnps -EPS -F7 -W10 -K < kl > sradl${istring}.eps

    reframe -N$i -O < SRADR.PLT > kr
    rsize=$( /bin/ls -l kr | awk '{print $5}' )
    [[ $rsize -gt 100 ]] && plotnps -EPS -F7 -W10 -K < kr > sradr${istring}.eps

done
/bin/rm -f kl kr

# Compare dispersion curves and attenuation with model predicions
echo "Comparing dispersion curves and attenuation with model predictions"
/bin/rm -f disp.d sobs.d SRFPHG96.PLT SRFPHV96.PLT phv.eps phg.eps
grep SURF96 SRADL.TXT > disp.d
grep SURF96 SRADR.TXT >> disp.d

/bin/cp $model_file model.mod

cat > sobs.d << EOF
  0.00499999989  0.00499999989  0.  0.00499999989  0.
    0    1    1    1    1    1    1    0    1    0
model.mod
disp.d
EOF

surf96 1
srfphv96 -V
srfphv96 -G
plotnps -F7 -W10 -EPS -K < SRFPHV96.PLT > phv.eps
plotnps -F7 -W10 -EPS -K < SRFPHG96.PLT > phg.eps
surf96 39

/bin/rm -f sobs.d disp.d SRFPHG96.PLT SRFPHV96.PLT

# Create stations list
/bin/rm -f station.list
awk '{printf("%-6s %-3s %8.2f %6.1f\n", $19, $20, $8, $9)}' $data_file | sort -u > station.list

while read -r station channel distance azimuth; do

    chn=${channel:0:2}
    echo $station $channel $chn
    /bin/rm -f junkr junkl

    sdpspc96 -X0 5.0 -XLEN 3.0 -YLEN 5 -PATH $eigen -R -DIP $dip -RAKE $rake -STK $strike \
        -DIST $norm_distance -PER -HS $depth -M $mode -MW $Mw2 -O $data_file -STA $station -COMP ${chn}Z >  junkr

    amplitude_max_Rayleigh=$( grep ampmax junkr | awk '{print $5}' )

    sdpspc96 -X0 1.0 -XLEN 3.0 -YLEN 5 -PATH $eigen -L -DIP $dip -RAKE $rake -STK $strike \
        -DIST $norm_distance -PER -HS $depth -M $mode -MW $Mw2 -O $data_file -STA $station -COMP ${chn}T > junkl

    amplitude_max_Love=$( grep ampmax junkl | awk '{print $5}' )

    echo "Maximum amplitudes: $amplitude_max_Rayleigh $amplitude_max_Love"

    sdpspc96 -X0 5.0 -XLEN 3.0 -YLEN 5 -PATH $eigen -R -DIP $dip -RAKE $rake -STK $strike \
        -DIST $norm_distance -PER -HS $depth -M $mode -MW $Mw2 -O $data_file -STA $station -COMP ${chn}Z \
        -YMAX $amplitude_max_Rayleigh >  junkr
    sdpspc96 -X0 1.0 -XLEN 3.0 -YLEN 5 -PATH $eigen -L -DIP $dip -RAKE $rake -STK $strike \
        -DIST $norm_distance -PER -HS $depth -M $mode -MW $Mw2 -O $data_file -STA $station -COMP ${chn}T \
        -YMAX $amplitude_max_Love > junkl


    cat SSPCL.PLT SSPCR.PLT | reframe -N1 -O -YL+500 > TEMP.PLT
    calplt << EOF
NEWPEN
1
LEFT
3.0 6.5 0.20 'Love' 0.0
LEFT
7.0 6.5 0.20 'Rayl' 0.0
LEFT
1.25 2.0 0.15 '$station' 0.0
LEFT
1.25 1.8 0.15 'Az=$azimuth' 0.0
LEFT
1.25 1.6 0.15 'Dist=$distance' 0.0
LEFT
1.25 1.4 0.15 'Norm=$norm_distance' 0.0
PEND
EOF

    cat TEMP.PLT CALPLT.PLT > $station.plt
    plotnps -K  -F7 -W10 -EPS < $station.plt > $station.eps
    /bin/rm -f junkr junkl CALPLT.cmd CALPLT.PLT SSPCL.PLT SSPCR.PLT TEMP.PLT $station.plt

done < station.list
