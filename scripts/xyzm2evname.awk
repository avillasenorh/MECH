#!/usr/bin/awk -f
{
	lat = $2;
	lon = $1;
	dep = $3;
	mag = $4;
    split($5, dt, "T");
    split(dt[1], yymmdd, "-");
    split(dt[2], hhmmss, ":"); 
	year = yymmdd[1];
	month = yymmdd[2];
	day = yymmdd[3];
	hour = hhmmss[1];
	minute = hhmmss[2];
	isecond = substr(hhmmss[3],1,2);
	printf("%04d%02d%02d%02d%02d%02d", year, month, day, hour, minute, isecond);
}
