# WRF:DRIVER_LAYER:INTEGRATION



#   USE module_domain
#   USE module_driver_constants
#   USE module_nesting
#   USE module_configure
#   USE module_timing
#   USE module_utility

#   USE module_cpl, ONLY : coupler_on, cpl_snd, cpl_defdomain



   #  Input data.

grid = cglobal((:__module_domain_MOD_head_grid, "libwrf"), Any)
grid_id = 1

# module_integrate:integrate
# <DESCRIPTION> 
# This is a driver-level routine that controls the integration of a
# domain and subdomains rooted at the domain. 
# 
# The integrate routine takes a domain pointed to by the argument
# <em>grid</em> and advances the domain and its associated nests from the
# grid's current time, stored within grid%domain_clock, to a given time
# forward in the simulation, stored as grid%stop_subtime. The
# stop_subtime value is arbitrary and does not have to be the same as
# time that the domain finished integrating.  The simulation stop time
# for the grid is known to the grid's clock (grid%domain_clock) and that
# is checked with a call to domain_clockisstoptime prior to beginning the
# loop over time period that is specified by the
# current time/stop_subtime interval.
# 
# The clock, the simulation stop time for the domain, and other timing
# aspects for the grid are set up in the routine
# (<a href="setup_timekeeping.html">setup_timekeeping</a>) at the time
# that the domain is initialized.
# The lower-level time library and the type declarations for the times
# and time intervals used are defined either in 
# external/esmf_time_f90/module_utility.F90 or in 
# external/io_esmf/module_utility.F90 depending on a build-time decision to 
# incorporate either the embedded ESMF subset implementation contained in 
# external/esmf_time_f90 or to use a site-specific installation of the ESMF 
# library.  This decision is made during the configuration step of the WRF 
# build process.  Note that arithmetic and comparison is performed on these 
# data types using F90 operator overloading, also defined in that library.
# 
# This routine is the lowest level of the WRF Driver Layer and for the most
# part the WRF routines that are called from here are in the topmost level
# of the Mediation Layer.  Mediation layer routines typically are not 
# defined in modules. Therefore, the routines that this routine calls
# have explicit interfaces specified in an interface block in this routine.
#
# As part of the Driver Layer, this routine is intended to be non model-specific
# and so a minimum of WRF-specific logic is coded at this level. Rather, there
# are a number of calls to mediation layer routines that contain this logic, some
# of which are merely stubs in WRF Mediation Layer that sits below this routine
# in the call tree.  The routines that integrate calls in WRF are defined in
# share/mediation_integrate.F.
# 
# Flow of control
# 
# 1. Check to see that the domain is not finished 
# by testing the value returned by domain_clockisstoptime for the
# domain.
# 
# 2. <a href=model_to_grid_config_rec.html>Model_to_grid_config_rec</a> is called to load the local config_flags
# structure with the configuration information for the grid stored
# in model_config_rec and indexed by the grid's unique integer id. These
# structures are defined in frame/module_configure.F.
# 
# 3. The current time of the domain is retrieved from the domain's clock
# using domain_get_current_time.  
# 
# 4. Iterate forward while the current time is less than the stop subtime.
# 
# 4.a. Start timing for this iteration (only on node zero in distributed-memory runs)
# 
# 4.b. Call <a href=med_setup_step.html>med_setup_step</a> to allow the mediation layer to 
# do anything that's needed to call the solver for this domain.  In WRF this means setting
# the indices into the 4D tracer arrays for the domain.
# 
# 4.c. Check for any nests that need to be started up at this time.  This is done 
# calling the logical function <a href=nests_to_open.html>nests_to_open</a> (defined in 
# frame/module_nesting.F) which returns true and the index into the current domain's list
# of children to use for the nest when one needs to be started.
# 
# 4.c.1  Call <a href=alloc_and_configure_domain.html>alloc_and_configure_domain</a> to allocate
# the new nest and link it as a child of this grid.
# 
# 4.c.2  Call <a href=setup_Timekeeping.html>setup_Timekeeping</a> for the nest.
# 
# 4.c.3  Initialize the nest's arrays by calling <a href=med_nest_initial.html>med_nest_initial</a>. This will
# either interpolate data from this grid onto the nest, read it in from a file, or both. In a restart run, this
# is also where the nest reads in its restart file.
# 
# 4.d  If a nest was opened above, check for and resolve overlaps (this is not implemented in WRF 2.0, which
# supports multiple nests on the same level but does not support overlapping).
# 
# 4.e  Give the mediation layer an opportunity to do something before the solver is called by
# calling <a href=med_before_solve_io.html>med_before_solve_io</a>. In WRF this is the point at which history and
# restart data is output.
# 
# 4.f  Call <a href=solve_interface.html>solve_interface</a> which calls the solver that advance the domain 
# one time step, then advance the domain's clock by calling domain_clockadvance.  
# The enclosing WHILE loop around this section is for handling other domains 
# with which this domain may overlap.  It is not active in WRF 2.0 and only 
# executes one trip.  
# 
# 4.g Call med_calc_model_time and med_after_solve_io, which are stubs in WRF.
# 
# 4.h Iterate over the children of this domain (<tt>DO kid = 1, max_nests</tt>) and check each child pointer to see
# if it is associated (and therefore, active).
# 
# 4.h.1  Force the nested domain boundaries from this domain by calling <a href=med_nest_force.html>med_nest_force</a>.
# 
# 4.h.2  Setup the time period over which the nest is to run. Sine the current grid has been advanced one time step
# and the nest has not, the start for the nest is this grid's current time minus one time step.  The nest's stop_subtime
# is the current time, bringing the nest up the same time level as this grid, its parent.
# 
# 4.h.3  Recursively call this routine, integrate, to advance the nest's time.  Since it is recursive, this will
# also advance all the domains who are nests of this nest and so on.  In other words, when this call returns, all
# the domains rooted at the nest will be at the current time.
# 
# 4.h.4  Feedback data from the nested domain back onto this domain by calling <a href=med_nest_feedback.html>med_nest_feedback</a>.
# 
# 4.i  Write the time to compute this grid and its subtree. This marks the end of the loop begun at step 4, above.
# 
# 5. Give the mediation layer an opportunity to do I/O at the end of the sequence of steps that brought the
# grid up to stop_subtime with a call to <a href=med_last_solve_io.html>med_last_solve_io</a>.  In WRF, this 
# is used to generate the final history and/or restart output when the domain reaches the end of it's integration.
# There is logic here to make sure this occurs correctly on a nest, since the nest may finish before its parent.
# </DESCRIPTION>

   #  Local data.

#   CHARACTER*32                           :: outname, rstname
#   TYPE(domain) , POINTER                 :: grid_ptr , new_nest
#   TYPE(domain)                           :: intermediate_grid
#   INTEGER                                :: step
#   INTEGER                                :: nestid , kid
#   LOGICAL                                :: a_nest_was_opened
#   INTEGER                                :: fid , rid
#   LOGICAL                                :: lbc_opened
#   REAL                                   :: time, btime, bfrq
#   CHARACTER*256                          :: message, message2,message3
#   TYPE (grid_config_rec_type)            :: config_flags
#   LOGICAL , EXTERNAL                     :: wrf_dm_on_monitor
#   INTEGER                                :: idum1 , idum2 , ierr , open_status
#   LOGICAL                                :: should_do_last_io
#   LOGICAL                                :: may_have_moved



   # This allows us to reference the current grid from anywhere beneath 
   # this point for debugging purposes.  
ccall((:__module_domain_MOD_set_current_grid_ptr, "libwrf"), Cvoid, (Ptr{Any},), grid)
   # CALL set_current_grid_ptr( grid )
ccall((:push_communicators_for_domain_, "libwrf"), Cvoid, (Int32,), grid_id)
   # CALL push_communicators_for_domain( grid%id )

if !ccall((:__module_domain_MOD_domain_clockisstoptime, "libwrf"), bool, (Ptr{Any},), grid)
    model_config_rec = cglobal((:__module_configure_MOD_model_config_rec, "libwrf"), Ptr{Any})
    config_flags = Ref{Any}
    @ccall libwrf.__module_configure_MOD_model_to_grid_config_rec(grid_id::Int32, model_config_rec::Ptr{Any}, config_flags::Ptr{Any})::Cvoid
    config_flags_grid_allowed = true
    if config_flags_grid_allowed
        #@ccall libwrf.__module_domain_MOD_domain_clockprint(150, grid, "DEBUG:  top of integrate(),")

        while ! @ccall libwrf.__module_domain_MOD_domain_clockisstopsubtime(grid::Ptr{Any})::bool
            if @ccall wrf_dm_on_monitor_()::bool 
                grid_active_this_task = true
                if grid_active_this_task
                    @ccall libwrf.__module_timing_MOD_start_timing()::Cvoid
                end
            end
            @ccall libwrf.med_setup_step_(grid::Ptr{Any}, config_flags::Ptr{Any})::Cvoid
            a_nest_was_opened = false
            # for each nest whose time has come...
            while @ccall libwrf.__module_nesting_MOD_nests_to_open(grid, nestid, kid)::bool
               # nestid is index into model_config_rec (module_configure) of the grid
               # to be opened; kid is index into an open slot in grid's list of children
                a_nest_was_opened = true
                @ccall libwrf.med_pre_nest_initial_(grid, nestid, config_flags)
                active_this_task = true
                @ccall libwrf.__module_domain_MOD_alloc_and_configure_domain(nestid, active_this_task, new_nest,  grid, kid)
                @ccall libwrf.setup_timekeeping_(new_nest)
                @ccall libwrf.med_nest_initial_(grid, new_nest, config_flags)
                if grid_active_this_task 
                    if grid % dfi_stage == DFI_STARTFWD
                        @ccall wrf_dfi_startfwd_init(new_nest)
                    end
                    if coupler_on
                        @ccall cpl_defdomain(new_nest) 
                    end
                end # active_this_task
            end
            if a_nest_was_opened
                @ccall set_overlaps(grid)   # find overlapping and set pointers
            end

            if grid_active_this_task
            # Accumulation calculation for DFI
                @ccall dfi_accumulate ( grid )
            end # active_this_task

            if grid_active_this_task
                @ccall med_before_solve_io (grid, config_flags)
            end # active_this_task

            grid_ptr => grid
            while ASSOCIATED(grid_ptr) 

                if grid_ptr % active_this_task
                    @ccall set_current_grid_ptr(grid_ptr)
                    @ccall wrf_debug(100, "module_integrate: calling solve interface ")

                    @ccall solve_interface ( grid_ptr ) 

                end
                @ccall domain_clockadvance ( grid_ptr )
                @ccall wrf_debug(100, "module_integrate: back from solve interface ")
               # print lots of time-related information for testing
               # switch this on with namelist variable self_test_domain
                @ccall domain_time_test(grid_ptr, "domain_clockadvance")
                grid_ptr => grid_ptr % sibling
            end # DO
            @ccall set_current_grid_ptr(grid)
            @ccall med_calc_model_time (grid, config_flags)
            if grid % active_this_task 
                @ccall med_after_solve_io (grid, config_flags)
            end

            grid_ptr => grid
            while ( ASSOCIATED(grid_ptr) )
                for kid = 1:max_nests
                    if ASSOCIATED(grid_ptr % nests(kid) % ptr) 
                        @ccall set_current_grid_ptr(grid_ptr % nests(kid) % ptr)
                   # Recursive -- advance nests from previous time level to this time level.
                        @ccall wrf_debug(100, "module_integrate: calling med_nest_force ")
                        @ccall med_nest_force (grid_ptr, grid_ptr % nests(kid) % ptr)
                        @ccall wrf_debug(100, "module_integrate: back from med_nest_force ")
                        grid_ptr % nests(kid) % ptr % start_subtime = domain_get_current_time(grid) - domain_get_time_step(grid)
                        grid_ptr % nests(kid) % ptr % stop_subtime = domain_get_current_time(grid)
                    end
                end # DO

                for kid = 1:max_nests
                    if ASSOCIATED(grid_ptr % nests(kid) % ptr) 
                        @ccall set_current_grid_ptr(grid_ptr % nests(kid) % ptr)
                        WRITE(message, *)grid % id, " module_integrate: recursive call to integrate "
                        @ccall wrf_debug(100, message)
                        @ccall integrate ( grid_ptr % nests(kid) % ptr ) 
                        WRITE(message, *)grid % id, " module_integrate: back from recursive call to integrate "
                        @ccall wrf_debug(100, message)
                    end
                end # DO
                may_have_moved = false
                for kid = 1:max_nests
                    if ASSOCIATED(grid_ptr % nests(kid) % ptr)
                        @ccall set_current_grid_ptr(grid_ptr % nests(kid) % ptr)
                        if ! ( domain_clockisstoptime(head_grid) || domain_clockisstoptime(grid) ||  domain_clockisstoptime(grid_ptr % nests(kid) % ptr) )
                            @ccall wrf_debug(100, "module_integrate: calling med_nest_feedback ")
                            @ccall med_nest_feedback (grid_ptr, grid_ptr % nests(kid) % ptr, config_flags)
                            @ccall wrf_debug(100, "module_integrate: back from med_nest_feedback ")
                        end

                    end 
                end

                if coupler_on 
                    @ccall cpl_snd(grid_ptr) 
                end
                grid_ptr => grid_ptr % sibling
            end
            @ccall set_current_grid_ptr(grid)
            #  Report on the timing for a single time step.
            if wrf_dm_on_monitor() 
                if grid_active_this_task
                    @ccall domain_clock_get (grid, current_timestr = message2)

               # if config_flags%use_adaptive_time_step then
               #   WRITE ( message , FMT = '("main (dt=",F6.2,"): time ",A," on domain ",I3)' ) grid%dt, TRIM(message2), grid%id
               # else
               #   WRITE ( message , FMT = '("main: time ",A," on domain ",I3)' ) TRIM(message2), grid%id
               # end
                    @ccall end_timing ( TRIM(message) )
                end # active_this_task
            end
            @ccall med_endup_step (grid, config_flags)
        end # DO

        if grid_active_this_task
         # Accumulation calculation for DFI
            @ccall dfi_accumulate ( grid )
        end # active_this_task



         # Avoid double writes on nests if this is not really the last time;
         # Do check for write if the parent domain is ending.
        if grid_id == 1                # head_grid
            if grid_active_this_task
                @ccall med_last_solve_io (grid, config_flags)
            end
        else
         # zip up the tree and see if any ancestor is at its stop time
            should_do_last_io = domain_clockisstoptime(head_grid)
            grid_ptr => grid 
            while grid_ptr % id != 1
                if domain_clockisstoptime(grid_ptr) 
                    should_do_last_io = true
                end
                grid_ptr => grid_ptr % parents(1) % ptr
            end
            if should_do_last_io 
                grid_ptr => grid 
                @ccall med_nest_feedback (grid_ptr % parents(1) % ptr, grid, config_flags)
                if grid % active_this_task 
                    @ccall med_last_solve_io (grid, config_flags)
                end
            end
        end
    end
end
@ccall pop_communicators_for_domain
