#!/usr/bin/env bash
#: Name        : rcmt_sta_map.sh
#: Description : plots maps with stations available and used for current event
#: Usage       : rcmt_sta_map.sh
#: Date        : 2022-12-16
#: Author      : "Antonio Villasenor" <antonio.villasenor@csic.es>
#: Version     : 1.0
#: Requirements: programs required by script (GMT5, gdate, getjul, etc)
#: Arguments   : none
#: Options     : none
set -e # stop on error
set -u # error if variable undefined
set -o pipefail

progname=${0##*/}

#[[ $# -ne 2 ]] && { echo "usage: $progname parameter_file location_file "; exit 1; }
#[[ ! -s $1 ]] && { echo "ERROR: parameter file does not exist: $1"; exit 1; }
#[[ ! -s $2 ]] && { echo "ERROR: location file does not exist: $2"; exit 1; }

#parfile=$1
#locfile=$2

#source $parfile

curdir=$PWD
[[ ! -d DAT/RAW ]] && { echo "ERROR: raw data directory does not exist: DAT/RAW"; exit 1; }
[[ ! -d DAT/VEL ]] && { echo "ERROR: velocity data directory does not exist: DAT/VEL"; exit 1; }
[[ ! -d REG/DAT ]] && { echo "ERROR: used data directory does not exist: REG/DAT"; exit 1; }

/bin/rm -f raw.list vel.list dat.list bad.list
( /bin/ls -1 DAT/RAW/*SAC > raw.list 2> /dev/null )
( /bin/ls -1 DAT/VEL/*SAC > vel.list 2> /dev/null )
( /bin/ls -1 REG/DAT/*[ZRT] > dat.list 2> /dev/null )
[[ -d REG/DAT/NOUSE ]] && ( /bin/ls -1 REG/DAT/NOUSE/*[ZRT] > bad.list 2> /dev/null )

for dataset in raw vel dat bad; do
    /bin/rm -f $dataset.xy
    touch $dataset.xy
    i=0
    while read -r sacfile; do

        [[ ! -f $sacfile ]] && continue
        if [[ $i -eq 0 ]]; then
            ev_lat=$( saclhdr -EVLA $sacfile )
            ev_lon=$( saclhdr -EVLO $sacfile )
        fi
        sta=$( saclhdr -KSTNM $sacfile )
        net=$( saclhdr -KNETWK $sacfile )
        sta_lat=$( saclhdr -STLA $sacfile )
        sta_lon=$( saclhdr -STLO $sacfile )
        if [[ $sta_lat == "-12345" && $sta_lon == "-12345" ]]; then
            echo "WARNING: no coordinates for ${sta}.${net}"
            continue
        fi

        echo $sta_lon $sta_lat $sta $net >> $dataset.xy
        i=$((i + 1))

    done < $dataset.list
    echo $dataset $i

done
/bin/rm -f *.list

[[ ! -s raw.xy ]] && { echo "ERROR: no stations for this event"; /bin/rm -f *.xy; exit 1; }

/bin/rm -f tmp.xy
awk '{print $1, $2}' raw.xy > tmp.xy
echo $ev_lon $ev_lat >> tmp.xy
region=$( gmt info -I2 tmp.xy )
/bin/rm -f tmp.xy

psfile=sta_map.ps
/bin/rm -f $psfile
gmt psbasemap $region -JM16c -Bxa5f1 -Bya5f1 -BWeSn -Xc -Yc -P -K >> $psfile
gmt pscoast -R -J -Df -W0.5p -A1/1/50 -O -K >> $psfile
gmt psxy raw.xy -R -J -St0.2c -W0.5p,black -O -K >> $psfile
gmt psxy vel.xy -R -J -St0.25c -W0.25p,black -Gred -O -K >> $psfile
gmt psxy dat.xy -R -J -St0.30c -W0.25p,black -Ggreen -O -K >> $psfile
gmt psxy -R -J -Sa0.3c -W0.25p,black -Gorange -O -K << END >> $psfile 
$ev_lon $ev_lat
END
gmt psxy -R -J -T -O >> $psfile

cd $curdir
/bin/rm -f raw.list vel.list dat.list bad.list
