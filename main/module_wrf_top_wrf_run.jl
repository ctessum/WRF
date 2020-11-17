
# """
# WRF run routine.
# """

# """
# Once the top-level domain has been allocated, configured, and
# initialized, the model time integration is ready to proceed.  The start
# and stop times for the domain are set to the start and stop time of the
# model run, and then <a href=integrate.html>integrate</a> is called to
# advance the domain forward through that specified time interval.  On
# return, the simulation is completed.  
# """

# The forecast integration for the most coarse grid is now started.  The
# integration is from the first step (1) to the last step of the simulation.

head_grid_ptr = cglobal((:__module_domain_MOD_head_grid, "libwrf"), Int32)

# ccall((:__module_wrf_top_MOD_wrf_run, "libwrf"), Cvoid, ())
ccall((:wrf_debug_, "libwrf"), Cvoid, (Ref{Int32}, Cstring), 100 , "wrf: calling integrate")

ccall((:__module_integrate_MOD_integrate, "libwrf"), Cvoid, (Ptr{Int32}, ), head_grid_ptr)


#  CALL       wrf_debug ( 100 , 'wrf: back from integrate' )