#!/usr/bin/env bash
set -euo pipefail

progname=${0##*/}
curdir=$PWD

[[ $# -ne 2 ]] && { echo "usage: $progname parameter_file location_file "; exit 1; }
[[ ! -s $1 ]] && { echo "ERROR: parameter file does not exist: $1"; exit 1; }
[[ ! -s $2 ]] && { echo "ERROR: location file does not exist: $2"; exit 1; }

source $1
locfile=$2

[[ -s DAT/MSEED/extract.ms ]] && { echo "WARNING: DAT/MSEED/extract.ms file alredy exists. Exiting"; exit 1; }

# check binaries
if command -v date > /dev/null && date --version > /dev/null 2>&1; then
    DATE=date
elif command -v gdate > /dev/null && gdate --version > /dev/null 2>&1; then
    DATE=gdate
else
    echo "ERROR: no GNU date command in this system"
    exit 1
fi

[[ $( command -v geo2da ) ]] || { echo "ERROR: geo2da executable is missing"; exit 1; }
[[ $( command -v dataselect ) ]] || { echo "ERROR: dataselect executable is missing"; exit 1; }
[[ $( command -v nor_addchn ) ]] || { echo "ERROR: nor_addchn executable is missing"; exit 1; }

# read hypocenter and origin time in ISO format
read -r evlo evla evdp magnitude origin_time < $locfile

IFS="-" read -r year month day <<< $( echo ${origin_time%T*} )
IFS=":" read -r hour minute fsecond <<< $( echo ${origin_time#*T} )
isecond=${fsecond%.*}

jday=$( $DATE -u --date="$origin_time" +%j )

# calculate time window for data extraction

seconds=$($DATE -u --date="$origin_time" +%s)
start_time=$(bc -l <<< "$seconds - $pre_event")
end_time=$(bc -l <<< "$seconds + $post_event")

ts=$($DATE -u --date="@$start_time" +%Y,%j,%H,%M,%S)
te=$($DATE -u --date="@$end_time" +%Y,%j,%H,%M,%S)

# select stations to extract based on distance

## generate file with distances to each station from lon0,lat0
awk '{print lon0, lat0, $4, $3}' lon0=$lon0 lat0=$lat0 $station_file > geo2da.in
geo2da < geo2da.in > dist.out 2> /dev/null

## generate file with selected stations sorted by distance
awk '{printf("%8.2f\n", 111.1*$1)}' dist.out | paste -d" " - $station_file > dist.tmp
awk '($1 <= sel_dist_max) {printf("%8.2f  %-6s  %-2s\n", $1, $2, $3)}' sel_dist_max=${sel_dist_max} dist.tmp | sort -n > extract.list

echo "Selecting stations closer than $sel_dist_max km"
## loop through stations to create file with time windows and list of miniSEED files to use in extraction
/bin/rm -f selectfile files.list
while read -r dist sta net; do

    /bin/rm -f msfiles.list
    set +e
    (/bin/ls -1 $sds_dir/$year/$net/$sta/???.?/$net.$sta.*.$year.$jday > msfiles.list) 2> /dev/null
    [[ ! -s msfiles.list ]] && { /bin/rm -f msfiles.list; continue; }
    nfiles=$( cat msfiles.list | wc -l )
    cat msfiles.list >> files.list
    echo "$net $sta * [BHSE]H[ENZ12] * $ts $te"  >> selectfile
    set -e
    /bin/rm -f msfiles.list

done < extract.list

# run dataselect

echo "Extracting data windows from SDS at $sds_dir"
dataselect -szs -lso -Pe -s selectfile -o extract.ms @files.list

/bin/rm -f geo2da.in dist.out dist.tmp extract.list selectfile files.list

# Get list of channels in miniSEED file
msi -T extract.ms | grep -vE 'Source|Total' | awk '{print $1}' | sort -u > segments.list
awk -F_ '{printf("%-6s %-3s\n", $2, $4)}' segments.list > LOC/sta_chan.list
nsegments=$( cat segments.list | wc -l )
echo "Total number of channels extracted: $nsegments"
/bin/rm -f segments.list

[[ $nsegments -eq 0 ]] && { echo "ERROR: no data segments extracted for this event"; /bin/rm -f extract.ms; exit 1; }

# move miniSEED file and create a soft link in LOC

mkdir -p DAT/MSEED
/bin/mv extract.ms DAT/MSEED

# create miniSEED file name and rename file
suffix=$( printf "%03d" $nsegments )
msfile_pre=$($DATE -u --date="@$start_time" +%Y-%m-%d-%H%M-%S)
msfile=${msfile_pre}M.${network}_${suffix}

# Edit S-file
cd LOC
sfile=$( /bin/ls -1 ??-????-??L.S?????? )
/bin/cp $sfile ${sfile}.original
ln -s ../DAT/MSEED/extract.ms $msfile

# add waveform file to S-file
awk '{if ($0 ~ /^ STAT SP IPHASW/) {printf(" %-78s6\n",file); print $0} else {print $0}}' file=$msfile ${sfile}.original > sfile.tmp

# modifiy S-file to add component from extract.ms

nor_addchn << END 2> channel_not_found.list
sfile.tmp
$sfile
sta_chan.list
END

/bin/rm -f sfile.tmp sta_chan.list

cd ..
