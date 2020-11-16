# """
# Main program of WRF model.  Responsible for starting up the model, reading in (and
# broadcasting for distributed memory) configuration data, defining and initializing
# the top-level domain, either from initial or restart data, setting up time-keeping, and
# then calling the <a href=integrate.html>integrate</a> routine to advance the domain
# to the ending time of the simulation. After the integration is completed, the model
# is properly shut down.

# Before running, ensure that the path to libwrf.so is in LD_LIBRARY_PATH or LibDl.DL_LOAD_PATH.
# For example:
# ``` bash
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/path/to/WRF/main
# ```
# or 
# ``` julia
# using Libdl
# push!(Libdl.DL_LOAD_PATH, "path/to/WRF/main/")
# ```
# """

# Make sure we're doing big-endian binary IO.
ENV["GFORTRAN_CONVERT_UNIT"] = "big_endian"

# Set up WRF model.
ccall((:__module_wrf_top_MOD_wrf_init, "libwrf"), Cvoid, ())

# Run digital filter initialization if requested.
ccall((:__module_wrf_top_MOD_wrf_dfi, "libwrf"), Cvoid, ())

# WRF model time-stepping.  Calls integrate().
ccall((:__module_wrf_top_MOD_wrf_run, "libwrf"), Cvoid, ())

# WRF model clean-up.  This calls MPI_FINALIZE() for DM parallel runs.  
# ccall((:__module_wrf_top_MOD_wrf_finalize, "libwrf"), Cvoid, ()) # Don't call unless we want to exit session.