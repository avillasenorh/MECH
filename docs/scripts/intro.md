# Introduction

The scripts in this repository are a re-write of Herrmann's original scripts.
The main differences/features of these scripts with respect to the original
ones are:

- Instead of having a copy of all the scripts inside each event directory
  now there is only one version of the scripts that works for all events.
- Processing parameters are stored in a single parameter file that can be
  adjusted for each event.
- Event hypocenter and origin time are read from a file that is
  stored at the top level of the event directory.
- The scripts are writen in `bash` shell, instead of the Bourne shell (`sh`).
  This was done in order to use more powerful features (for example conditionals
  using `[[ ]]`, etc cetera), resulting in shorter, more compact scripts.
- When possible we have used the shell tool GNU [parallel](https://www.gnu.org/software/parallel/)
  in order to speed up scripts that perform grid search and can be safely
  run in parallel.

The data processing involves first extracting the waveform data, metadata,
and organizing them in directories. This can be divided in the following steps:

- Setting up the event directories
- Data extraction (from disk or from data centers)
- Data pre-processing (conversion to velocity, rotation)

To obtain focal mechanisms using time-domain waveform inversion the following steps
are needed:

- Visual data selection of waveforms with good signal-to-noise ratio
- Inversion/grid search for the best mechanism
- Plotting the results

Finally, to obtain focal mechanisms using inversion of spectral amplitudes of Rayleigh and Love
wave:

- Measure group velocities and spectral amplitudes of surface waves
- Inversion/grid search for the best mechanism
- Plotting the results

This process can be accomplished running the following scripts:

```
# Pre-processing
$ rcmt_setup.sh S-file parameter_file                 # creates event directories
$ rcmt_dataselect.sh location_file parameter_file     # extracts data from an SDS into a miniSEED file
$ rcmt_unpack_mseed.sh location_file parameter_file   # creates SAC files, converts to velocity and rotates

# Time domain full-waveform inversion
$ rcmt_qc.sh parameter_file                           # manually select waveforms for inversion
$ rcmt_solution.sh location_file parameter_file       # runs grid search for best solution
$ rcmt_plots.sh parameter_file                        # plot results

# Surface wave spectral amplitude inversion
$ do_mft -G .../ROT/*Z                                # measure Rayleigh wave dispersion and spectral amplitudes
$ do_mft -G .../ROT/*T                                # measure Love wave dispersion and spectral amplitudes
$ cat *.dsp ../GRD/ALL.DSP                            # create input file for inversion
$ rcmt_spe.sh parameter_file                          # runs grid search for best solution
$ rcmt_spe_plots.sh parameter_file                            # plot results

```


