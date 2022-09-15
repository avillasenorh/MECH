#!/usr/bin/env bash
set -euo pipefail

progname=${0##*/}
curdir=$PWD

[[ $# -lt 2 ]] && { echo "usage: $progname location_file parameter_file [msfile]"; exit 1; }

[[ ! -s $1 ]] && { echo "ERROR: location file does not exist: $1"; exit 1; }
locfile=$1

[[ ! -s $2 ]] && { echo "ERROR: parameter file does not exist: $2"; exit 1; }
source $2

if [[ $# -lt 3 ]]; then
   msfile=${PWD}/DAT/MSEED/extract.ms
else
   if [[ ${3:0:1} == "/" ]]; then
      msfile=$3
   else
      msfile=${PWD}/$3
   fi
fi

[[ ! -e $msfile ]] && { echo "ERROR: miniSEED file does not exist: $msfile"; exit 1; }

# check environmental variables

model_file=${GREENDIR}/Models/${vmodel}.mod
[[ ! -s $model_file ]] && { echo "ERROR: model file does not exist: $model_file"; exit 1; }

# read hypocenter and origin time in ISO format

read -r evlo evla evdp magnitude origin_time < $locfile

IFS="-" read -r year month day <<< $( echo ${origin_time%T*} )
IFS=":" read -r hour minute fsecond <<< $( echo ${origin_time#*T} )
isecond=${fsecond%.*}
msecond=$( bc -l <<< " 1000 * ($fsecond - $isecond)" )

[[ ! -d DAT ]] && { echo "ERROR: waveform directory does not exist: DAT"; exit 1; }
/bin/rm -rf DAT/TMP
mkdir DAT/TMP
[[ ! -d DAT/RAW ]] && mkdir DAT/RAW

cd DAT/TMP

echo "Converting data to SAC"
mseed2sac $msfile 2> extract.log

/bin/rm -f ES.ES[01][0-9]*.SAC    # removes data from Sonseca Array
/bin/mv -n *SAC ../RAW/.

find . -name "*.SAC" -print > sac.list 2> /dev/null
nleft=$( cat sac.list | wc -l )
/bin/rm -f sac.list

[[ $nleft -gt 0 ]] && echo "WARNING: $nleft duplicated SAC files in $PWD"

# IB.E104..HHN.D.2011.098.150613.SAC

echo "Setting SAC headers"

cd ../RAW

for sacfile in *.SAC; do

    IFS="." read -r network station location channel quality oyear ojday dum extension <<< "$sacfile"
    net=$( saclhdr -KNETWK $sacfile )
    sta=$( saclhdr -KSTNM $sacfile )
    loc=$( saclhdr -KHOLE $sacfile )
    chn=$( saclhdr -KCMPNM $sacfile )

    # check that file name and header values are consistent (not done yet)


    # get station coordinates

    /bin/rm -f found.sta
    awk '($1 == sta && $2 == net)' sta=${station} net=${network} $station_file > found.sta
    [[ ! -s found.sta ]] && { echo "WARNING: no coordinates for ${network}.${station}"; /bin/rm -f found.sta; continue; }

    read -r stla stlo stel <<< $( awk '(NR == 1) {print $3, $4, $5}' found.sta )
    /bin/rm -f found.sta

#   echo $network $station $stla $stlo $stel

    if [[ ${channel:(-1)} == "Z" ]]; then
        cmpinc=0.0
        cmpaz=0.0
    elif [[ ${channel:(-1)} == "E" ]]; then
        cmpinc=90.0
        cmpaz=0.0
    elif [[ ${channel:(-1)} == "N" ]]; then
        cmpinc=90.0
        cmpaz=90.0
    else
        echo "WARNING: cannot handle this case yet: ${network}.${station}.${channel}"
        continue
    fi

    gsac << EOF > /dev/null
    rh $sacfile
    ch lovrok true
    ch lcalda true
    ch OCAL $year $month $day $hour $minute $isecond ${msecond%%.*}
    ch EVLA $evla EVLO $evlo EVDP $evdp
    ch STLA $stla STLO $stlo STEL $stel
    ch CMPINC $cmpinc CMPAZ $cmpaz
    wh
    q
EOF

done

# Remove instrument response and convert to velocity

echo "Removing instrument response"
/bin/rm -f transfer.log
touch transfer.log
for sacfile in *.SAC; do

    IFS="." read -r network station location channel quality oyear ojday dum extension <<< "$sacfile"

    respfile=${resp_dir}/RESP.${network}.${station}.${location}.${channel}

    [[ ! -s $respfile ]] && { echo "WARNING: no response file for $sacfile"; continue; }

    delta=$( saclhdr -DELTA $sacfile )
    fhh=$( bc -l <<< "0.50 / $delta" )
    fhl=$( bc -l <<< "0.25 / $delta" )
    set +e
    evalresp $station $channel $oyear $ojday 0.001 $fhh 2049 -u 'vel' -f $respfile
    status=$?
    set -e
    if [[ $status -ne 0 ]]; then
        echo "Error status = $status"
        continue
    fi

    amp_file=AMP.${network}.${station}.${location}.${channel}
    phase_file=PHASE.${network}.${station}.${location}.${channel}

    if [[ -s $amp_file && -s $phase_file ]]; then
        set +e
        gsac << EOF >> transfer.log
        read $sacfile
        rtr
        transfer from eval subtype $amp_file $phase_file TO NONE FREQLIMITS 0.002 0.004 $fhl $fhh
        w ../VEL/${station}.${channel}.${network}.${location}.SAC
        quit
        set -e
EOF
    else
      echo "ERROR: evalresp did not produce AMP and PHASE file for $sacfile"
      /bin/rm -f $amp_file $phase_file
      continue
    fi

#   /bin/rm -f $amp_file $phase_file
done

# Rotate and set additional header files

cd ../VEL

echo "Adding arrival times"

for sacfile in *.SAC; do

    # EALK.HHZ.ES..SAC

    IFS="." read -r station channel network location extension <<< "$sacfile"

    gcarc=$( saclhdr -GCARC $sacfile )
    evdp=$( saclhdr -EVDP $sacfile )
    depmax=$( saclhdr -DEPMAX $sacfile )
    depmim=$( saclhdr -DEPMIN $sacfile )

    dist_undef=$( bc -l <<< "$gcarc < 0.0" )
    [[ $dist_undef -eq 1 ]] && { echo "WARNING: no coordinates for this file: $sacfile"; continue; }

    ans=$( echo $depmax $minamp $maxamp | awk '{if ($1 < $2 || $1 > $3) {print "NO"} else {print "YES"}}' )

    if [[ $ans == "NO" ]]; then
       echo "WARNING: invalid velocity values for $sacfile"
       [[ ! -d BAD ]] && mkdir BAD
       /bin/mv $sacfile BAD/.
       continue
    fi

    a=$( time96 -M $model_file -P -GCARC $gcarc -EVDP $evdp )
    t0=$( time96 -M $model_file -SH -GCARC $gcarc -EVDP $evdp )

    gsac << EOF > /dev/null
    r $sacfile
    synchronize o
    rtr
    hp c $fhigh np 2
    ch A $a T0 $t0 T1 $t0
    w 
    quit
EOF

    [[ ${channel:1:2} == "HZ" ]] && cp $sacfile ../ROT/${station}${network}${location}${channel}

done

echo "Rotating"
for sacfile1 in *.*HE.*.SAC; do

    IFS="." read -r station channel1 network location extension <<< "$sacfile1"

    chn=${channel1:0:2}
    channel2=${channel1/HE/HN}
    sacfile2=${station}.${channel2}.${network}.${location}.SAC

    [[ ! -s $sacfile2 ]] && { echo "WARNING: no N component for $sacfile1"; continue; }

    gsac << EOF > /dev/null
    r $sacfile2 $sacfile1
    rotate to gc
    w ../ROT/${station}${network}${location}${chn}R ../ROT/${station}${network}${location}${chn}T
    quit
EOF


done
