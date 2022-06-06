#!/usr/bin/awk -f
(substr($0,80,1) == "1") {
	lat = substr($0,24,7);
	lon = substr($0,31,8);
	dep = substr($0,39,5);
	mag = substr($0,56,4);
	year =   1*substr($0,2,4);
	month =  1*substr($0,7,2);
	day =    1*substr($0,9,2);
	hour =   1*substr($0,12,2);
	minute = 1*substr($0,14,2);
	second = 1.0*substr($0,17,4);
	printf("%9.4f %8.4f %5.1f %4.1f %04d-%02d-%02dT%02d:%02d:%05.2f\n",
	lon, lat, dep, mag, year, month, day, hour, minute, second);
}
