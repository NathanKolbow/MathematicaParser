using MathematicaParser
using Test

include("testutils.jl")

@testset verbose = true "MathematicaParser.jl" begin
    include("test_piecewise_simple.jl")
    include("test_piecewise_exhaustive.jl")
    include("test_precedence.jl")
    include("test_difficult.jl")
    include("test_codegen.jl")
end
