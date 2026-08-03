module MathematicaParser

export parse_mathematica, generate_function_code

const FUNCTION_MAP = Dict(
    "Sin" => :sin, "Cos" => :cos, "Tan" => :tan,
    "ArcSin" => :asin, "ArcCos" => :acos, "ArcTan" => :atan,
    "Sinh" => :sinh, "Cosh" => :cosh, "Tanh" => :tanh,
    "Csch" => :csch, "Sech" => :sech, "Coth" => :coth,
    "Log" => :log, "Exp" => :exp, "Sqrt" => :sqrt,
    "Abs" => :abs, "Max" => :max, "Min" => :min
)

function parse_mathematica(s::AbstractString)
    expr, idx = parse_expr(s, 1)
    idx = skip_whitespace(s, idx)
    if idx <= length(s)
        error("Unexpected trailing characters starting at index $(idx): '$(s[idx:end])'")
    end
    return expr
end

function parse_expr(s::AbstractString, idx::Int = 1)
    return parse_logical_or(s, idx)
end

function parse_logical_or(s::AbstractString, idx::Int)
    left, idx = parse_logical_and(s, idx)
    idx = skip_whitespace(s, idx)

    while idx <= length(s) && startswith(@view(s[idx:end]), "||")
        idx += 2
        idx = skip_whitespace(s, idx)
        right, idx = parse_logical_and(s, idx)
        left = Expr(:(||), left, right)
        idx = skip_whitespace(s, idx)
    end
    return left, idx
end

function parse_logical_and(s::AbstractString, idx::Int)
    left, idx = parse_comparison(s, idx)
    idx = skip_whitespace(s, idx)

    while idx <= length(s) && startswith(@view(s[idx:end]), "&&")
        idx += 2
        idx = skip_whitespace(s, idx)
        right, idx = parse_comparison(s, idx)
        left = Expr(:&&, left, right)
        idx = skip_whitespace(s, idx)
    end
    return left, idx
end

function parse_comparison(s::AbstractString, idx::Int)
    first_operand, idx = parse_term(s, idx)
    idx = skip_whitespace(s, idx)

    op_map = Dict(
        "<=" => :(<=), ">=" => :(>=),
        "<" => :(<), ">" => :(>),
        "==" => :(==), "!=" => :(!=)
    )
    sorted_ops = sort(collect(op_map), by=x->length(x[1]), rev=true)

    # Collect a whole comparison chain: operand op operand op operand ...
    operands = Any[first_operand]
    ops = Symbol[]
    while idx <= length(s)
        matched_op = nothing
        for (op_str, op_sym) in sorted_ops
            if startswith(@view(s[idx:end]), op_str)
                matched_op = (op_str, op_sym)
                break
            end
        end

        matched_op === nothing && break
        op_str, op_sym = matched_op
        idx += length(op_str)
        idx = skip_whitespace(s, idx)
        right, idx = parse_term(s, idx)
        push!(ops, op_sym)
        push!(operands, right)
        idx = skip_whitespace(s, idx)
    end

    isempty(ops) && return first_operand, idx

    # Mathematica chains comparisons: `a < b <= c` means `(a < b) && (b <= c)`.
    # A single comparison is emitted directly; a chain becomes a conjunction.
    expr = Expr(:call, ops[1], operands[1], operands[2])
    for i in 2:length(ops)
        expr = Expr(:&&, expr, Expr(:call, ops[i], operands[i], operands[i + 1]))
    end
    return expr, idx
end

function parse_term(s::AbstractString, idx::Int)
    left, idx = parse_factor(s, idx)
    idx = skip_whitespace(s, idx)

    while idx <= length(s) && (s[idx] == '+' || s[idx] == '-')
        op = s[idx] == '+' ? :(+) : :(-)
        idx += 1
        idx = skip_whitespace(s, idx)
        right, idx = parse_factor(s, idx)
        left = Expr(:call, op, left, right)
        idx = skip_whitespace(s, idx)
    end
    return left, idx
end

function parse_factor(s::AbstractString, idx::Int)
    left, idx = parse_power(s, idx)
    idx = skip_whitespace(s, idx)

    while idx <= length(s)
        if startswith(@view(s[idx:end]), "*^")
            idx += 2
            idx = skip_whitespace(s, idx)
            right, idx = parse_power(s, idx)
            left = Expr(:call, :(*), left, Expr(:call, :(^), 10.0, right))
            idx = skip_whitespace(s, idx)
        elseif s[idx] == '*' || s[idx] == '/'
            op = s[idx] == '*' ? :(*) : :(/)
            idx += 1
            idx = skip_whitespace(s, idx)
            right, idx = parse_power(s, idx)
            left = Expr(:call, op, left, right)
            idx = skip_whitespace(s, idx)
        else
            break
        end
    end
    return left, idx
end

function parse_power(s::AbstractString, idx::Int)
    left, idx = parse_primary(s, idx)
    idx = skip_whitespace(s, idx)

    if idx <= length(s) && s[idx] == '^'
        idx += 1
        idx = skip_whitespace(s, idx)
        right, idx = parse_power(s, idx)
        left = Expr(:call, :(^), left, right)
    end
    return left, idx
end

function parse_primary(s::AbstractString, idx::Int)
    idx = skip_whitespace(s, idx)
    idx > length(s) && error("Unexpected end of expression")

    char = s[idx]

    if char == '-' || char == '+'
        op = char == '-' ? :(-) : :(+)
        idx += 1
        # `^` binds tighter than unary minus/plus (Mathematica: -E^x == -(E^x)),
        # so the operand is a full power expression, not just a primary.
        val, idx = parse_power(s, idx)
        return Expr(:call, op, val), idx
    elseif char == '!'
        if idx + 1 <= length(s) && s[idx + 1] == '='
            error("Unexpected character '!' at index $(idx)")
        end
        idx += 1
        val, idx = parse_primary(s, idx)
        return Expr(:call, :(!), val), idx
    elseif char == '('
        return parse_group(s, idx)
    elseif char == '{'
        return parse_list_expr(s, idx)
    elseif isdigit(char) || char == '.'
        return parse_number(s, idx)
    elseif is_identifier_start(char)
        return parse_symbol_or_call(s, idx)
    else
        error("Unexpected character '$(char)' at index $(idx)")
    end
end

skip_whitespace(s, idx) = findfirst(c -> !isspace(c), @view s[idx:end]) === nothing ? length(s) + 1 : idx + findfirst(c -> !isspace(c), @view s[idx:end]) - 1

is_identifier_start(c) = isletter(c) || c == '_'
is_identifier_part(c) = isletter(c) || isdigit(c) || c == '_'

function parse_number(s, idx)
    m = match(r"^[+-]?(\d+\.\d*|\.\d+|\d+)([eE][+-]?\d+)?", @view s[idx:end])
    m === nothing && error("Invalid number format at index $(idx)")
    val = Meta.parse(m.match)
    # Ensure all numbers are parsed as floats
    float_val = float(val)
    return float_val, idx + length(m.match)
end

function parse_symbol_or_call(s, idx)
    start_idx = idx
    while idx <= length(s) && is_identifier_part(s[idx])
        idx += 1
    end
    name = String(@view s[start_idx:idx-1])

    idx = skip_whitespace(s, idx)

    if idx <= length(s) && s[idx] == '['
        args, idx = parse_bracket_args(s, idx)

        if name == "Piecewise"
            return transform_piecewise(args), idx
        elseif name == "Inequality"
            return transform_inequality(args), idx
        elseif name == "And"
            return transform_and(args), idx
        elseif name == "Or"
            return transform_or(args), idx
        elseif name == "Not"
            length(args) == 1 || error("Not expects 1 argument")
            return Expr(:call, :(!), args[1]), idx
        end

        julia_func = get(FUNCTION_MAP, name, Symbol(lowercase(name)))
        expr = Expr(:call, julia_func, args...)
        return expr, idx
    else
        if name == "E"
            return :(exp(1)), idx
        elseif name == "Pi"
            return :pi, idx
        else
            return Symbol(name), idx
        end
    end
end

function parse_bracket_args(s, idx)
    @assert s[idx] == '['
    idx += 1
    args = []

    idx = skip_whitespace(s, idx)
    if idx <= length(s) && s[idx] == ']'
        return args, idx + 1
    end

    while idx <= length(s)
        arg, idx = parse_expr(s, idx)
        push!(args, arg)

        idx = skip_whitespace(s, idx)
        if idx <= length(s) && s[idx] == ','
            idx += 1
        elseif idx <= length(s) && s[idx] == ']'
            idx += 1
            break
        else
            error("Expected ',' or ']' inside brackets at index $(idx)")
        end
        idx = skip_whitespace(s, idx)
    end
    return args, idx
end

function parse_list_expr(s, idx)
    @assert s[idx] == '{'
    idx += 1
    elements = []

    idx = skip_whitespace(s, idx)
    if idx <= length(s) && s[idx] == '}'
        return elements, idx + 1
    end

    while idx <= length(s)
        elem, idx = parse_expr(s, idx)
        push!(elements, elem)

        idx = skip_whitespace(s, idx)
        if idx <= length(s) && s[idx] == ','
            idx += 1
        elseif idx <= length(s) && s[idx] == '}'
            idx += 1
            break
        else
            error("Expected ',' or '}' inside list at index $(idx)")
        end
        idx = skip_whitespace(s, idx)
    end
    return elements, idx
end

function parse_group(s, idx)
    @assert s[idx] == '('
    idx += 1
    expr, idx = parse_expr(s, idx)
    idx = skip_whitespace(s, idx)
    if idx > length(s) || s[idx] != ')'
        error("Expected ')' at index $(idx)")
    end
    return expr, idx + 1
end

function transform_piecewise(args)
    cases = args[1]
    default_val = length(args) > 1 ? args[2] : 0.0

    expr = default_val
    for case in reverse(cases)
        val = case[1]
        cond = case[2]
        expr = :(($cond) ? $val : $expr)
    end
    return expr
end

function transform_inequality(args)
    if length(args) % 2 == 0
        error("Malformed Inequality expression.")
    end

    op_map = Dict(
        :Less => :(<), :LessEqual => :(<=),
        :Greater => :(>), :GreaterEqual => :(>=),
        :Equal => :(==), :Unequal => :(!=)
    )

    resolved = [i % 2 == 0 ? get(op_map, args[i], args[i]) : args[i] for i in 1:length(args)]

    if length(resolved) == 3
        return Expr(:call, resolved[2], resolved[1], resolved[3])
    end

    expr = Expr(:&&, Expr(:call, resolved[2], resolved[1], resolved[3]))
    i = 4
    while i < length(resolved)
        sub_comp = Expr(:call, resolved[i], resolved[i-1], resolved[i+1])
        push!(expr.args, sub_comp)
        i += 2
    end
    return expr
end

function transform_and(args)
    isempty(args) && return true
    expr = args[1]
    for i in 2:length(args)
        expr = Expr(:&&, expr, args[i])
    end
    return expr
end

function transform_or(args)
    isempty(args) && return false
    expr = args[1]
    for i in 2:length(args)
        expr = Expr(:(||), expr, args[i])
    end
    return expr
end

function generate_function_code(parsed_expr; arg_names::Vector{Symbol} = [:t2],
                                arg_types::Union{Nothing,Vector{Type}} = nothing,
                                func_name::Symbol = :generated_func)
    local args_str::Vector
    if isnothing(arg_types) || length(arg_types) == 0
        args_str = join(arg_names, ", ")
    else
        args_str = join(["$(an)::$(at)" for (an, at) in zip(arg_names, arg_types)])
    end
    body_str = string(parsed_expr)

    return """
    function $func_name($args_str)
        return $body_str
    end
    """
end

"""
    generate_function_code(input_path, output_path; arg_names = nothing,
                           func_name = <input file's base name>)

Read the plain-text Mathematica expression stored in `input_path`, parse it, and
write the generated Julia function definition to `output_path`. The whole file is
treated as a single expression, so exports that wrap across several lines are fine.

`func_name` defaults to the input file's base name (`smoothfA.txt` becomes
`function smoothfA(...)`), falling back to `generated_func` when that base name is
not a valid Julia identifier. `arg_names` defaults to the free variables found in
the parsed expression, sorted alphabetically; pass it explicitly to control the
argument order. Returns the generated code, which is also written to `output_path`.
"""
function generate_function_code(input_path::AbstractString, output_path::AbstractString;
                                arg_names::Union{Nothing,Vector{Symbol}} = nothing,
                                arg_types::Union{Nothing,Vector{Type}} = nothing,
                                func_name::Union{Nothing,Symbol} = nothing)
    text = read(input_path, String)
    isempty(strip(text)) && error("Input file is empty: $(input_path)")

    parsed_expr = parse_mathematica(strip(text))
    args = arg_names === nothing ? free_variables(parsed_expr) : arg_names
    name = func_name === nothing ? default_func_name(input_path) : func_name

    code = generate_function_code(parsed_expr; arg_names = args, func_name = name, arg_types = arg_types)

    out_dir = dirname(output_path)
    isempty(out_dir) || mkpath(out_dir)
    write(output_path, code)
end

function default_func_name(input_path::AbstractString)
    stem = splitext(basename(input_path))[1]
    return Base.isidentifier(stem) ? Symbol(stem) : :generated_func
end

# Symbols the parser emits for Mathematica constants rather than for user
# variables; they must not be mistaken for function arguments.
const RESERVED_SYMBOLS = Set([:pi])

# Free variables of a parsed expression, sorted so the argument order is
# reproducible across runs.
function free_variables(parsed_expr)
    vars = Set{Symbol}()
    collect_free_variables!(vars, parsed_expr)
    return sort!(collect(vars))
end

collect_free_variables!(vars, x) = nothing

collect_free_variables!(vars, s::Symbol) = (s in RESERVED_SYMBOLS || push!(vars, s); nothing)

function collect_free_variables!(vars, expr::Expr)
    # In a call the first argument is the callee, not a variable.
    operands = expr.head === :call ? @view(expr.args[2:end]) : expr.args
    collect_free_variables!(vars, operands)
end

function collect_free_variables!(vars, xs::AbstractVector)
    for x in xs
        collect_free_variables!(vars, x)
    end
    return nothing
end

end
