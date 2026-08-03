# Regression tests for two parser bugs found via the difficult_functions exports:
#
#   1. Unary minus bound tighter than `^`, so `-E^x` parsed as `(-E)^x` instead
#      of `-(E^x)`.  At even exponents this silently flipped the sign.
#   2. Chained comparisons `a >= t >= b` were folded left-associatively into
#      `(a >= t) >= b` (a Bool compared to a number) instead of Mathematica's
#      `(a >= t) && (t >= b)`.

@testset "Operator precedence & chained comparisons" begin

    # --- unary minus vs. power: `^` binds tighter than unary minus ---
    @test eval_mathematica("-E^2", Symbol[])        ≈ -exp(2.0)
    @test eval_mathematica("-2^2", Symbol[])        == -4.0
    @test eval_mathematica("-E^(-3*t)", [:t], 2.0)  ≈ -exp(-6.0)   # even exponent: sign must stay negative
    @test eval_mathematica("-E^(-6)", Symbol[])     ≈ -exp(-6.0)
    @test eval_mathematica("3 - E^2", Symbol[])     ≈ 3 - exp(2.0) # binary minus is unaffected
    @test eval_mathematica("-E^(-3*t2) + E^(-t2)", [:t2], 2.0) ≈ -exp(-6.0) + exp(-2.0)

    # --- chained comparisons expand to a conjunction ---
    let s = "Piecewise[{{1, 2 >= t >= 1}}, 0]"          # 1 <= t <= 2
        @test eval_mathematica(s, [:t], 1.5) == 1.0
        @test eval_mathematica(s, [:t], 0.5) == 0.0     # (2>=0.5)>=1 wrongly gave true before the fix
        @test eval_mathematica(s, [:t], 2.5) == 0.0
    end
    let s = "Piecewise[{{1, 0 <= t <= 1}}, 0]"
        @test eval_mathematica(s, [:t], 0.5) == 1.0
        @test eval_mathematica(s, [:t], 1.5) == 0.0
    end
    # a three-operator chain: 0 < t < s < 10
    let s = "Piecewise[{{1, 0 < t < u < 10}}, 0]"
        @test eval_mathematica(s, [:t, :u], 1.0, 2.0) == 1.0
        @test eval_mathematica(s, [:t, :u], 2.0, 1.0) == 0.0   # t < u violated
    end
end
