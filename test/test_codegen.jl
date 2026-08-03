# Code generation, in particular the file-in/file-out method of
# `generate_function_code`.

@testset "Code generation" begin

    @testset "expression method" begin
        expr = parse_mathematica("Piecewise[{{t1 + t2, t1 > 0}}, 0]")

        code = generate_function_code(expr; arg_names = [:t1, :t2])
        @test occursin("function generated_func(t1, t2)", code)

        code = generate_function_code(expr; arg_names = [:t2, :t1], func_name = :myfun)
        @test occursin("function myfun(t2, t1)", code)
    end

    @testset "file method" begin
        mktempdir() do dir
            input = joinpath(dir, "myFunc.txt")
            write(input, "Piecewise[{{t1 + t2, t1 > 0}}, 0]\n")
            output = joinpath(dir, "out", "myFunc.jl")

            code = generate_function_code(input, output)

            # The function is named after the input file and takes the free
            # variables of the expression, sorted.
            @test occursin("function myFunc(t1, t2)", code)
            # Nested output directories are created as needed.
            @test isfile(output)
            @test read(output, String) == code

            f = Base.eval(@__MODULE__, Meta.parse(code))
            @test Base.invokelatest(f, 1.0, 2.0) == 3.0
            @test Base.invokelatest(f, -1.0, 2.0) == 0.0
        end
    end

    @testset "file method options" begin
        mktempdir() do dir
            input = joinpath(dir, "myFunc.txt")
            write(input, "Piecewise[{{t1 + t2, t1 > 0}}, 0]\n")

            code = generate_function_code(input, joinpath(dir, "a.jl");
                                          arg_names = [:t2, :t1], func_name = :myfun)
            @test occursin("function myfun(t2, t1)", code)

            f = Base.eval(@__MODULE__, Meta.parse(code))
            @test Base.invokelatest(f, 2.0, 1.0) == 3.0
        end
    end

    @testset "file method edge cases" begin
        mktempdir() do dir
            # An export wrapped over several lines is still one expression.
            wrapped = joinpath(dir, "wrapped.txt")
            write(wrapped, "Piecewise[{{a + b,\n   a > 0}},\n 0]")
            @test occursin("function wrapped(a, b)",
                           generate_function_code(wrapped, joinpath(dir, "wrapped.jl")))

            # A file name that is not a valid Julia identifier falls back to the
            # default function name; `Pi` is a constant, not an argument.
            odd = joinpath(dir, "bad-name.txt")
            write(odd, "2*Pi*r")
            @test occursin("function generated_func(r)",
                           generate_function_code(odd, joinpath(dir, "bad.jl")))

            empty_file = joinpath(dir, "empty.txt")
            write(empty_file, "   \n")
            @test_throws ErrorException generate_function_code(empty_file,
                                                               joinpath(dir, "empty.jl"))
        end
    end

    # The generated code for a real export compiles and agrees with the values
    # checked in test_difficult.jl. Arguments are sorted: (epsi, t, t1, t2).
    @testset "generated code for a difficult function" begin
        mktempdir() do dir
            output = joinpath(dir, "smoothfA.jl")
            input = joinpath(@__DIR__, "..", "difficult_functions", "smoothfA.txt")
            code = generate_function_code(input, output)
            @test occursin("function smoothfA(epsi, t, t1, t2)", code)

            f = Base.eval(@__MODULE__, Meta.parse(code))
            @test Base.invokelatest(f, 0.19, 0.5, 0.5, 0.5) ≈ 1.672345 atol=1e-4
            @test Base.invokelatest(f, 0.1, 0.5, 1.0, 2.0) ≈ 0.351586 atol=1e-4
        end
    end
end
