# Small, self-contained sanity checks for Piecewise handling.

@testset "Piecewise (simple)" begin
    # Single case with an explicit default value.
    @test eval_mathematica("Piecewise[{{1, t > 0}}, 0]", [:t], 2.0)  == 1.0
    @test eval_mathematica("Piecewise[{{1, t > 0}}, 0]", [:t], -2.0) == 0.0

    # No default supplied -> Mathematica default of 0.
    @test eval_mathematica("Piecewise[{{5, t > 10}}]", [:t], 0.0) == 0.0

    # Multiple cases are evaluated top-to-bottom; the first true case wins.
    let s = "Piecewise[{{1, t > 0}, {2, t > -5}}, 0]"
        @test eval_mathematica(s, [:t], 1.0)   == 1.0   # first case
        @test eval_mathematica(s, [:t], -1.0)  == 2.0   # second case
        @test eval_mathematica(s, [:t], -10.0) == 0.0   # default
    end

    # Case values may be arbitrary expressions, not just literals.
    let s = "Piecewise[{{t^2, t >= 0}}, -1]"
        @test eval_mathematica(s, [:t], 3.0)  == 9.0
        @test eval_mathematica(s, [:t], -1.0) == -1.0
    end

    # A compound condition (&&) guarding a case.
    let s = "Piecewise[{{1, t > 0 && t < 1}}, 0]"
        @test eval_mathematica(s, [:t], 0.5) == 1.0
        @test eval_mathematica(s, [:t], 1.5) == 0.0
    end
end
