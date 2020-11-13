using WRF
using Test

@testset "WRF.jl" begin
    cd("julia")
    include("julia/test.jl")
    cd("../")
end
