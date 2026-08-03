# More exhaustive Piecewise coverage:
#   1. Chained inequalities (a < b <= c and similar), via Mathematica's Inequality[]
#   2. Nested Piecewise expressions
#   3. The constant E raised to various powers
#   4. A range of trigonometric / hyperbolic functions

@testset "Piecewise (exhaustive)" begin

    # -------------------------------------------------------------------
    # 1. Chained inequalities: a < b <= c and similar.
    #    Mathematica exports these as Inequality[a, Less, b, LessEqual, c],
    #    which must expand to the conjunction (a < b) && (b <= c).
    # -------------------------------------------------------------------
    @testset "chained inequalities" begin
        # 0 < t <= 2  (half-open on the left, closed on the right)
        let s = "Piecewise[{{1, Inequality[0, Less, t, LessEqual, 2]}}, 0]"
            @test eval_mathematica(s, [:t], 1.0) == 1.0   # strictly inside
            @test eval_mathematica(s, [:t], 2.0) == 1.0   # closed upper bound included
            @test eval_mathematica(s, [:t], 0.0) == 0.0   # open lower bound excluded
            @test eval_mathematica(s, [:t], 3.0) == 0.0   # above the range
        end

        # 1 <= t < 3  (closed on the left, half-open on the right)
        let s = "Piecewise[{{1, Inequality[1, LessEqual, t, Less, 3]}}, 0]"
            @test eval_mathematica(s, [:t], 1.0) == 1.0   # closed lower bound included
            @test eval_mathematica(s, [:t], 2.0) == 1.0
            @test eval_mathematica(s, [:t], 3.0) == 0.0   # open upper bound excluded
            @test eval_mathematica(s, [:t], 0.5) == 0.0
        end

        # Descending chain: 3 > t >= 1  (equivalent to 1 <= t < 3)
        let s = "Piecewise[{{1, Inequality[3, Greater, t, GreaterEqual, 1]}}, 0]"
            @test eval_mathematica(s, [:t], 1.0) == 1.0
            @test eval_mathematica(s, [:t], 2.0) == 1.0
            @test eval_mathematica(s, [:t], 3.0) == 0.0
            @test eval_mathematica(s, [:t], 0.5) == 0.0
        end

        # An && of two independent bounds should behave like the chain above.
        let s = "Piecewise[{{1, t >= 1 && t < 3}}, 0]"
            @test eval_mathematica(s, [:t], 1.0) == 1.0
            @test eval_mathematica(s, [:t], 3.0) == 0.0
        end
    end

    # -------------------------------------------------------------------
    # 2. Nested Piecewise expressions.
    # -------------------------------------------------------------------
    @testset "nested Piecewise" begin
        # Outer selects the inner Piecewise for t < 5, otherwise -1.
        # Inner returns 1 for t > 0, otherwise 0.
        let s = "Piecewise[{{Piecewise[{{1, t > 0}}, 0], t < 5}}, -1]"
            @test eval_mathematica(s, [:t], 1.0)  == 1.0    # inner: t > 0
            @test eval_mathematica(s, [:t], -1.0) == 0.0    # inner default
            @test eval_mathematica(s, [:t], 6.0)  == -1.0   # outer default
        end

        # Nesting inside the condition slot as well as the value slot.
        let s = "Piecewise[{{10, Piecewise[{{t > 0, t < 10}}, t > -10]}}, 0]"
            @test eval_mathematica(s, [:t], 5.0)   == 10.0  # 0<t<10 -> true
            @test eval_mathematica(s, [:t], -5.0)  == 0.0   # inner true but value cond false
            @test eval_mathematica(s, [:t], 20.0)  == 10.0  # outer-range default t>-10 true
        end
    end

    # -------------------------------------------------------------------
    # 3. The constant E raised to various powers.
    #    E parses to exp(1); E^x is therefore exp(1)^x ≈ exp(x).
    # -------------------------------------------------------------------
    @testset "E raised to powers" begin
        @test eval_mathematica("E^t", [:t], 1.0) ≈ exp(1.0)
        @test eval_mathematica("E^(x + y)", [:x, :y], 1.0, 2.0) ≈ exp(3.0)
        @test eval_mathematica("E^(2*t)", [:t], 1.5) ≈ exp(3.0)
        @test eval_mathematica("E^(-t)", [:t], 2.0) ≈ exp(-2.0)
        @test eval_mathematica("E^(t^2)", [:t], 2.0) ≈ exp(4.0)

        # E powers selected by a Piecewise branch.
        let s = "Piecewise[{{E^(x + y), x > 0}}, E^(-x)]"
            @test eval_mathematica(s, [:x, :y], 1.0, 2.0)  ≈ exp(3.0)
            @test eval_mathematica(s, [:x, :y], -1.0, 2.0) ≈ exp(1.0)
        end
    end

    # -------------------------------------------------------------------
    # 4. Trigonometric and hyperbolic functions.
    #    Sin/Cos/Sinh/Cosh/Csch are mapped explicitly; Csc (and Sec, Cot)
    #    fall through to their lower-cased Julia Base equivalents.
    # -------------------------------------------------------------------
    @testset "trig / hyperbolic functions" begin
        @test eval_mathematica("Sin[Pi/2]", Symbol[]) ≈ 1.0
        @test eval_mathematica("Cos[0]", Symbol[])     ≈ 1.0
        @test eval_mathematica("Sinh[0]", Symbol[])    == 0.0
        @test eval_mathematica("Cosh[0]", Symbol[])    == 1.0
        @test eval_mathematica("Csc[Pi/2]", Symbol[])  ≈ 1.0
        @test eval_mathematica("Csch[1]", Symbol[])    ≈ csch(1.0)

        # Pythagorean identity holds for any argument.
        @test eval_mathematica("Sin[x]^2 + Cos[x]^2", [:x], 0.7) ≈ 1.0
        # Hyperbolic identity: cosh^2 - sinh^2 == 1.
        @test eval_mathematica("Cosh[x]^2 - Sinh[x]^2", [:x], 1.3) ≈ 1.0

        # Trig combined with E powers, gated by a Piecewise branch.
        let s = "Piecewise[{{E^t * Csch[t], t > 0}}, 0]"
            @test eval_mathematica(s, [:t], 1.0) ≈ exp(1.0) * csch(1.0)
            @test eval_mathematica(s, [:t], -1.0) == 0.0
        end
    end
end
