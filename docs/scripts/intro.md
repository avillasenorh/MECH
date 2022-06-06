# Introduction

The scripts in this repository are a re-write of Herrmann's original scripts.
The main differences/features of these scripts with respect to the original
ones are:

- Instead of having a copy of all the scripts inside each event directory
  now there is only one version of the scripts that works for all events.
- Processing parameters are stored in a single parameter file that can be
  adjusted for each event.
- Event hypocenter and origin time are read from a location file that is
  stored at the top level of the event directory
- The scripts are writen in `bash` shell, instead of the Bourne shell (`sh`)
  as the original one. This means that more powerful features can be used
  (for example conditionals using `[[ ]]`, etc cetera).

The basic processing now consists of 4 steps.

1. Creating the event directories containing a location and a parameter file
2. Data extraction
3. Data selection/QC
4. Inversion

This can be accomplished running the following scripts:

```
$ rcmt_dataselect.sh location_file parameter_file  # extracts data from an SDS
$ rcm_qc.sh                                        # requires input from user
$ rcmt_solution.sh                                 # runs grid search for best solution
```


