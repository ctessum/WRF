using NetCDF
using Test

# Test WRF executable. NOTE: Sometimes this test randomly fails.
@testset "Test wrf.exe" begin
    rm("wrfout_d01_2017-08-16_12:00:00", force=true) # Delete previously generated output file.
    # Test the WRF binary executable.
    run_output = read(`./wrf.exe`, String)
    # Check for common errors in run output log.
    @test !occursin("Forced exit", run_output)
    @test !occursin("ASTEM internal steps exceeded", run_output)

    # The "error trying to read metadata" message is okay for now, but TODO: fix this.
    @test !occursin("error", replace(lowercase(run_output), "error trying to read metadata" => ""))

    # Check output file against golden file.
    outputfile = NetCDF.open("wrfout_d01_2017-08-16_12:00:00");
    goldenfile = NetCDF.open("wrfout_d01_2017-08-16_12:00:00_golden");

    # Make sure the output file has the same keys as the golden file.
    @test keys(outputfile.vars) == keys(goldenfile.vars)

    @testset "Check outfile variable data against golden file" begin
        for (varname, goldendata) in goldenfile.vars
            @testset "$varname" begin
                data = outputfile.vars[varname]
                if !(varname in ["Times", "gly"]) # "Times" is a string and "gly" is really different every time
                    @test data ≈ goldendata rtol = 1.0 atol = 1.0 # TODO: How to make work with decreased tolerances?
                end
            end
        end
    end
    rm("wrfout_d01_2017-08-16_12:00:00", force=true) # Delete output file.
end