# MathematicaParser.jl

A small parser that converts plain-text Mathematica function expressions (as
exported from Mathematica) into Julia `Expr` objects and, from there, into Julia
function code.

## Installation

This package is not registered. From the package directory:

```julia
using Pkg
Pkg.develop(path=".")   # or Pkg.activate(".") when working inside the repo
```

## Usage

```julia
using MathematicaParser

# Parse a Mathematica expression string into a Julia Expr
expr = parse_mathematica("Piecewise[{{t1 + t2, t1 > 0}}, 0]")

# Emit a Julia function definition (as a string) for the parsed expression
code = generate_function_code(expr; arg_names = [:t1, :t2])
println(code)
```

### From a file to a file

`generate_function_code` also reads a Mathematica export straight from a text
file and writes the generated Julia function to an output file (returning the
same code as a string). The whole input file is treated as one expression, so
exports that wrap across several lines are fine.

```julia
generate_function_code("difficult_functions/smoothfA.txt", "generated/smoothfA.jl")
```

By default the generated function is named after the input file (`smoothfA.txt`
becomes `function smoothfA(...)`, falling back to `generated_func` if the base
name is not a valid Julia identifier), and its arguments are the free variables
of the expression sorted alphabetically — `smoothfA` above gets
`(epsi, t, t1, t2)`. Pass `arg_names` and `func_name` to control both:

```julia
generate_function_code("difficult_functions/smoothfA.txt", "generated/smoothfA.jl";
                       arg_names = [:t, :t1, :t2, :epsi], func_name = :smoothfA)
```

Missing directories in the output path are created.

### Supported constructs

- Arithmetic (`+ - * /`), powers (`^`), and Mathematica scientific notation (`*^`)
- Comparisons (`< <= > >= == !=`) and logical operators (`&& || !`)
- Function calls mapped to their Julia equivalents (`Sin`, `Cos`, `Sinh`,
  `Cosh`, `Csch`, `Sech`, `Coth`, `Log`, `Exp`, `Sqrt`, `Abs`, `Max`, `Min`, …)
- `Piecewise[...]`, `Inequality[...]`, `And[...]`, `Or[...]`, `Not[...]`
- Constants `E` and `Pi`

Unrecognized function names are lower-cased and passed through as Julia calls.

## Tests

```julia
using Pkg
Pkg.test("MathematicaParser")
```

The test suite covers `Piecewise` handling plus a set of large real-world
expressions stored in [`difficult_functions/`](difficult_functions/).
