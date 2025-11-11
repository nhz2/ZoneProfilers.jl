# Return the zone macro keyword arguments
function _process_zone_kwargs(kwargs)
    color::UInt32 = 0x000000
    found_color = false
    name::Union{String, Nothing} = nothing
    found_name = false
    active::Any = true
    found_active = false
    for arg in kwargs
        if !(arg isa Expr) || arg.head !== :(=) || length(arg.args) != 2 || !(arg.args[1] isa Symbol)
            error("keyword arguments must be in the form \"key = value\". Got $(repr(arg))")
        end
        local key = arg.args[1]
        local v = arg.args[2]
        if key === :color
            if found_color
                error("color keyword argument repeated")
            end
            found_color = true
            if v isa Integer
                color = v
            elseif v isa QuoteNode && v.value isa Symbol
                color = get_tracy_color(v.value)
            else
                error("color is expected to be a 0xRRGGBB or Symbol literal")
            end
        elseif key === :name
            if found_name
                error("name keyword argument repeated")
            end
            found_name = true
            if v isa QuoteNode && v.value isa Symbol
                name = string(v.value)
            elseif v isa String
                name = v
            else
                error("name is expected to be a Symbol, or String literal")
            end
        elseif key === :active
            if found_active
                error("active keyword argument repeated")
            end
            found_active = true
            active = v
        else
            error("Unknown keyword $(repr(key))")
        end
    end
    (;name, color, active)
end

# Shared documentation for zone macro keyword arguments
const _ZONE_KWARGS_DOC = """
  * `name="zone_name"` or `name=:zone_symbol` - Sets a custom name for the profiling zone. **Must be a literal string or symbol** (not a variable or expression).
  * `color=value` - Sets the color for the profiling zone. **Must be a literal value**, which can be:
    - An integer in 0xRRGGBB format (e.g., `0xFF0000` for red)
    - A symbol representing a named color. Available colors are: $(_available_colors)
    - Since 0x000000 is reserved for the default color, use `0x010101`, or `:black` instead for black.
  * `active=condition` - Controls whether the profiling zone is active. **Evaluated at runtime**. Can be:
    - A `Bool`
    - A zero-argument function that returns a `Bool`
"""


"""
    @zone_begin profiler
    @zone_begin profiler name="zone_name"
    @zone_begin profiler color=:red
    @zone_begin profiler active=false
    @zone_begin profiler name="zone_name" color=0x00FF00 active=true

Begin a profiling zone using the specified profiler context `profiler`. This macro must be paired with a corresponding `zone_end!(profiler)` call to properly close the profiling zone.

The macro accepts the following optional keyword arguments:

$(_ZONE_KWARGS_DOC)

Note: The profiler context `profiler` is also **evaluated at runtime**, while `name` and `color` must be literals.

# Examples

```julia
# Basic usage - begin a profiling zone
profiler = TracyProfiler()
@zone_begin profiler
# ... code to profile ...
zone_end!(profiler)

# Named zone with custom color
@zone_begin profiler name="database_query" color=:blue
# ... database operation ...
zone_end!(profiler)

# Conditional profiling
@zone_begin profiler active=DEBUG_MODE
# ... code that's only profiled in debug mode ...
zone_end!(profiler)

# Using hex color code
@zone_begin profiler name="rendering" color=0x00FF00
# ... rendering code ...
zone_end!(profiler)
```

!!! warning "Manual zone management"
    When using `@zone_begin`, you must manually call `zone_end!(profiler)` to properly close the profiling zone. 
    For automatic zone management, consider using the `@zone` macro instead, which handles both beginning and ending automatically.

See also: [`zone_end!`](@ref), [`@zone`](@ref), [`TracyProfiler`](@ref), [`NullProfiler`](@ref)
"""
macro zone_begin(profiler, kwargs...)
    function_name = string(nameof(__module__)) # For now use module name. TODO A future julia version might support this.
    (;name::Union{String, Nothing}, color::UInt32, active::Any) = _process_zone_kwargs(kwargs)
    srcloc = SourceLocation(__source__, function_name, name, color)
    lock(srcloc_gc_root_lock) do
        push!(srcloc_gc_root, srcloc)
    end
    :(unsafe_zone_begin!($(esc(profiler)), $(srcloc), $(esc(active))))
end

"""
    @zone profiler expression
    @zone profiler name="zone_name" expression
    @zone profiler color=:red expression
    @zone profiler active=false expression
    @zone profiler name="zone_name" color=0x00FF00 active=true expression

Execute the given `expression` within a profiling zone using the specified profiler context `profiler`.

The macro accepts the following optional keyword arguments (which must appear before the expression):

$(_ZONE_KWARGS_DOC)

Note: The profiler context `profiler` and the `expression` are both **evaluated at runtime**, while `name` and `color` must be literals.

# Examples

```julia
# Basic usage - profile an expression
profiler = TracyProfiler()
result = @zone profiler begin
    # ... code to profile ...
    expensive_computation()
end

# Named zone with custom color
@zone profiler name="database_query" color=:blue begin
    db_query("SELECT * FROM users")
end

# Single line expression
@zone profiler name="math" sqrt(x^2 + y^2)

# Conditional profiling
@zone profiler active=DEBUG_MODE begin
    debug_analysis()
end

# Using hex color code
@zone profiler name="rendering" color=0x00FF00 render_frame()
```

See also: [`@zone_begin`](@ref), [`zone_end!`](@ref), [`TracyProfiler`](@ref), [`NullProfiler`](@ref)
"""
macro zone(profiler, otherargs...)
    if iszero(length(otherargs))
        error("usage: @zone profiler [optional keyword arguments] <expression>")
    end
    expr = last(otherargs)
    # Try to use the function name from the expression
    # otherwise use the module name
    function_name = if (expr isa Expr) && expr.head === :call && !isempty(expr.args)
        string(first(expr.args))
    else
        string(nameof(__module__))
    end
    (;name::Union{String, Nothing}, color::UInt32, active::Any) = _process_zone_kwargs(otherargs[1:end-1])
    srcloc = SourceLocation(__source__, function_name, name, color)
    lock(srcloc_gc_root_lock) do
        push!(srcloc_gc_root, srcloc)
    end
    quote
        unsafe_zone_begin!($(esc(profiler)), $(srcloc), $(esc(active)))
        try
            $(esc(otherargs[end]))
        finally
            zone_end!($(esc(profiler)))
        end
    end
end

"""
    @zone_show profiler variable1 variable2 ...

A convenience macro for displaying variable names and their values as text annotations in the current profiling zone.

For each variable or expression passed, the macro generates a guarded call that only evaluates the expression and adds text when the zone is active. The macro is equivalent to writing:
```julia
zone_active(profiler) && zone_text!(profiler, "variable = \$(repr(variable))")
```

for each variable.

# Examples

```julia
profiler = TracyProfiler()
x = 42
y = "hello"
z = [1, 2, 3]

@zone profiler name="computation" begin
    # Show variable values in the zone
    @zone_show profiler x y z
    # This adds three text lines to the zone:
    # "x = 42"
    # "y = \"hello\""
    # "z = [1, 2, 3]"
    
    # ... rest of computation ...
end

@zone profiler name="debug" active=false begin
    @zone_show profiler expensive_computation()
    # expensive_computation() is NOT called when zone is inactive
end

```

See also: [`@zone_repr`](@ref), [`zone_text!`](@ref), [`zone_active`](@ref), [`@zone`](@ref)
"""
macro zone_show(profiler, exs...)
    blk = Expr(:block)
    for ex in exs
        ex_string = string(ex)
        push!(blk.args, :(zone_active($(esc(profiler))) && zone_text!($(esc(profiler)), "$($(ex_string)) = $(repr($(esc(ex))))")))
    end
    push!(blk.args, :(nothing))
    return blk
end

"""
    @zone_repr profiler variable1 variable2 ...

A convenience macro for displaying the repr of variables or expressions as text annotations in the current profiling zone.

For each variable or expression passed, the macro generates a guarded call that only evaluates the expression and adds text when the zone is active. The macro is equivalent to writing:
```julia
zone_active(profiler) && zone_text!(profiler, repr(variable))
```

for each variable.

This is similar to [`@zone_show`](@ref) but without the "variable = " prefix, displaying only the repr output.

# Examples

```julia
profiler = TracyProfiler()
x = 42
y = "hello"
z = [1, 2, 3]

@zone profiler name="computation" begin
    # Show repr of variable values in the zone
    @zone_repr profiler x y z
    # This adds three text lines to the zone:
    # "42"
    # "\"hello\""
    # "[1, 2, 3]"
    
    # ... rest of computation ...
end

@zone profiler name="debug" active=false begin
    @zone_repr profiler expensive_computation()
    # expensive_computation() is NOT called when zone is inactive
end

```

See also: [`@zone_show`](@ref), [`zone_text!`](@ref), [`zone_active`](@ref), [`@zone`](@ref)
"""
macro zone_repr(profiler, exs...)
    blk = Expr(:block)
    for ex in exs
        push!(blk.args, :(zone_active($(esc(profiler))) && zone_text!($(esc(profiler)), repr($(esc(ex))))))
    end
    push!(blk.args, :(nothing))
    return blk
end



