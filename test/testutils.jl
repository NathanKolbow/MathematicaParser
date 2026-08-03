# Shared test helpers, included once by runtests.jl before the individual
# test files.

# Compile a parsed expression into a callable over the given argument symbols.
compile(expr, argnames::Vector{Symbol}) =
    Base.eval(@__MODULE__, Expr(:->, Expr(:tuple, argnames...), expr))

# Parse `s`, build a function of `argnames`, and evaluate it at `values`.
# `invokelatest` is required because the function is created at runtime.
function eval_mathematica(s::AbstractString, argnames::Vector{Symbol}, values...)
    expr = parse_mathematica(s)
    f = compile(expr, argnames)
    return Base.invokelatest(f, values...)
end
