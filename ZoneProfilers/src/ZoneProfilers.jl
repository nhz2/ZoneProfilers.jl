module ZoneProfilers

export get_tracy_color

export Profiler
export NullProfiler
export null_profiler

export wait_for_connection
export is_connected
export app_info!
export new_stack

export message!

export @zone
export @zone_begin
export zone_end!
export zone_active
export zone_color!
export zone_text!
export zone_value!

export frame_mark!
export frame_mark_begin!
export frame_mark_end!

export plot!

include("colors.jl")

"""
    get_tracy_color(color::Union{UInt32, Symbol})::UInt32

Return the color in 0xRRGGBB format.
Available color symbols are: $(_available_colors)

0x000000 is treated as the default color, not black.
"""
function get_tracy_color(color::Symbol)::UInt32
    _tracycolor(color)
end
get_tracy_color(color::UInt32)::UInt32 = color

include("source-location.jl")
include("macro-magic.jl")

"""
    abstract type Profiler end

An abstract type for interactive tracy like profilers.

Documentation: https://github.com/nhz2/ZoneProfilers.jl
"""
abstract type Profiler end

"""
    struct NullProfiler <: Profiler end

A Profiler that is never active, always connected, and ignores any input.
"""
struct NullProfiler <: Profiler end

"""
    const null_profiler = NullProfiler()
"""
const null_profiler = NullProfiler()

"""
    new_stack(profiler::Profiler, name::Symbol)
    new_stack(profiler::Profiler, name::Function) -> new_stack(profiler, name())

Return a new profiler for a new profiling stack.

Arguments:
- name: a `Symbol`, or a zero-argument function that returns a `Symbol`.
"""
function new_stack(profiler::NullProfiler, name)
    NullProfiler()
end
function new_stack(profiler::Profiler, name)
    new_stack(profiler, name()::Symbol)
end

"""
    is_connected(profiler::Profiler)::Bool

Return true if the profiler is connect.
A `NullProfiler` always returns true.
"""
function is_connected(profiler::NullProfiler)
    true
end


"""
    wait_for_connection(profiler::Profiler; deadline::Union{UInt64, Nothing}=nothing)::Bool

Wait for the profiler to establish a connection to the Tracy client.

This function blocks execution until the profiler is connected or until an optional deadline is reached.
For `TracyProfiler`, this waits for the TCP connection to the Tracy profiler application to be established.
For `NullProfiler` and `TestProfiler`, this returns immediately as they are always considered "connected".

# Arguments
- `profiler::Profiler`: The profiler instance to wait for connection
- `deadline::Union{UInt64, Nothing}=nothing`: Optional deadline in nanoseconds (as from `time_ns()`).
  If `nothing`, waits indefinitely. If provided, returns `false` if the deadline is reached
  before connection is established.

# Returns
- `Bool`: `true` if connection is established, `false` if deadline was reached without connection

# Examples
```julia
# Wait indefinitely for connection
profiler = TracyProfiler()
if wait_for_connection(profiler)
    @zone profiler "main_simulation" main_loop()
end

# Wait with timeout (5 seconds)
deadline = time_ns() + 5_000_000_000  # 5 seconds from now
if wait_for_connection(profiler; deadline=deadline)
    println("Connected to Tracy profiler")
else
    println("Connection timeout - proceeding without profiling")
end
```

# See Also
- [`is_connected`](@ref): Check connection status without blocking
"""
function wait_for_connection(profiler::Profiler; deadline::Union{UInt64, Nothing}=nothing)::Bool
    if isnothing(deadline)
        while !is_connected(profiler)
            sleep(0.01)
        end
        return true
    else
        while !is_connected(profiler)
            time_left = deadline%Int64 - time_ns()%Int64
            time_left < 0 && return false
            sleep(min(0.01, time_left*1E-9))
        end
        return true
    end
end

"""
    unsafe_zone_begin!(profiler::Profiler, srcloc::SourceLocation, active::Bool)::Nothing
    unsafe_zone_begin!(profiler::Profiler, srcloc::SourceLocation, active::Function)::Nothing

Push a zone onto the stack in `profiler`.

This is unsafe because `srcloc` must be GC protected and pinned FOREVER after calling this.

Arguments:
- active: a `Bool`, or a zero-argument function that returns a `Bool`.

See also: [`zone_end!`](@ref)
"""
function unsafe_zone_begin!(profiler::NullProfiler, srcloc::SourceLocation, active)::Nothing
    nothing
end
function unsafe_zone_begin!(profiler::Profiler, srcloc::SourceLocation, active)
    unsafe_zone_begin!(profiler, srcloc, active()::Bool)
end

"""
    zone_end!(profiler::Profiler)::Nothing

Pop a zone off the stack in `profiler`.
"""
function zone_end!(profiler::NullProfiler)::Nothing
    nothing
end

"""
    zone_active(profiler::Profiler)::Bool

Return true if the current zone is active, false otherwise.
"""
function zone_active(profiler::NullProfiler)::Bool
    false
end

"""
    zone_text!(profiler::Profiler, text::String)::Nothing

Add text to the current zone if the current zone is active.
"""
function zone_text!(profiler::NullProfiler, text::String)::Nothing
    nothing
end

"""
    zone_value!(profiler::Profiler, value::UInt64)::Nothing

Add `value` as text to the current zone if the current zone is active.
"""
function zone_value!(profiler::NullProfiler, value::UInt64)::Nothing
    nothing
end

"""
    zone_color!(profiler::Profiler, color)::Nothing

Set the color of the current zone if the current zone is active.

# Arguments
- `profiler`: The profiler instance
- `color`: The color specification, which can be:
  - An UInt32 in 0xRRGGBB format (e.g., `0xFF0000` for red)
  - A symbol representing a named color. Available colors are: $(_available_colors)

# Notes
- This function only has an effect when called within an active profiling zone
- Since 0x000000 is reserved for the default color, use `0x010101`, or `:black` instead for black.
- Colors are converted to 0xRRGGBB format using [`get_tracy_color`](@ref)

# Examples
```julia
profiler = TracyProfiler()

@zone profiler name="rendering" begin
    # Set zone color using different formats
    zone_color!(profiler, 0xFF0000)    # Red using hex
    zone_color!(profiler, :blue)       # Blue using symbol
end

# No effect when zone is inactive
zone_color!(profiler, :red)  # Does nothing - no active zone
```
"""
function zone_color!(profiler::NullProfiler, color::Union{UInt32, Symbol})::Nothing
    nothing
end

_FRAME_DOCS = """
    frame_mark!(profiler::Profiler, name::Union{Symbol, Nothing}=nothing)::Nothing
    frame_mark_begin!(profiler::Profiler, name::Symbol)::Nothing
    frame_mark_end!(profiler::Profiler, name::Symbol)::Nothing

Mark the beginning and/or end of a frame.

# Arguments
- `profiler`: The profiler instance
- `name`: Name of the frame set (required for begin/end functions)

For contiguous frames (where one frame ends exactly when the next begins), use [`frame_mark!`](@ref). For non-contiguous frames or more precise control over frame timing, use [`frame_mark_begin!`](@ref) and [`frame_mark_end!`](@ref) separately.

# Frame Sets
Different `name` values create independent frame sets that can be tracked separately. This is useful for tracking different types of frames (e.g., `:render`, `:physics`, `:audio`).

!!! warning "Matching begin/end calls"
    Every `frame_mark_begin!` must have a corresponding `frame_mark_end!` with the same `name`. Unmatched calls may cause profiler issues.

!!! warning "Mixing frame marking methods"
    Do not mix `frame_mark_begin!`/`frame_mark_end!` with `frame_mark!` for the same frame set name. Choose one approach per frame set and stick with it.

# Examples
```julia
profiler = TracyProfiler()

# Mark main frame boundaries
for frame in 1:1000
    # ... frame work ...
    sleep(0.01)
    frame_mark!(profiler)  # End current frame, start next
end

# Multiple independent frame types
for frame in 1:1000
    frame_mark_begin!(profiler, :render)
    # ... rendering work ...
    sleep(0.01)
    # Start physics frame (can overlap with render)
    frame_mark_begin!(profiler, :physics)
    # ... physics and rendering work ...
    sleep(0.01)
    frame_mark_end!(profiler, :render)
    # ... finishing physics work ...
    sleep(0.01)
    frame_mark_end!(profiler, :physics)

    frame_mark!(profiler)  # End main frame, start next
end
```
"""

"$_FRAME_DOCS"
function frame_mark!(profiler::NullProfiler, name::Union{Symbol, Nothing}=nothing)::Nothing
    nothing
end

"$_FRAME_DOCS"
function frame_mark_begin!(profiler::NullProfiler, name::Symbol)::Nothing
    nothing
end

"$_FRAME_DOCS"
function frame_mark_end!(profiler::NullProfiler, name::Symbol)::Nothing
    nothing
end

"""
    message!(profiler::Profiler, text::Union{Symbol, String}; color=0x000000)::Nothing

Print `text` with optional color formatting.

# Arguments
- `profiler`: The profiler instance
- `text`: The message text (symbol or string)
- `color`: Optional color specification (default: 0x000000 for default color), which can be:
  - An integer in 0xRRGGBB format (e.g., `0xFF0000` for red)
  - A symbol representing a named color Available colors are: $(_available_colors)

# Notes
- Since 0x000000 is reserved for the default color, use `0x010101`, or `:black` instead for black.
- Colors are converted to 0xRRGGBB format using [`get_tracy_color`](@ref)

# Examples
```julia
profiler = TracyProfiler()

# Basic message with default color
message!(profiler, "Application started")

# Colored messages for different types
message!(profiler, "Error occurred"; color=:red)
message!(profiler, "Warning: low memory"; color=:yellow)
message!(profiler, Symbol("Debug info"); color=0x808080)
```
"""
function message!(profiler::NullProfiler, text::Union{Symbol, String}; color::Union{UInt32, Symbol}=0x000000)::Nothing
    nothing
end

"""
    plot!(profiler::Profiler, name::Symbol, val::Float64)::Nothing

Plot `val` at the current time on `name` plot.

# Examples
```julia
profiler = TracyProfiler()

# Make a wave
for i in 1:1000
    sleep(0.01)
    plot!(profiler, :wave, sin(i*0.1))
end
```
"""
function plot!(profiler::NullProfiler, name::Symbol, val::Float64)::Nothing
    nothing
end

"""
    app_info!(profiler::Profiler, text::String)::Nothing

Write the trace description.
"""
function app_info!(profiler::NullProfiler, text::String)::Nothing
    nothing
end

#==== Test Profiler ====#
mutable struct TestProfiler <: Profiler
    lock::ReentrantLock
    messages::Dict{Symbol, Vector{Any}}
    frame_times::Dict{Union{Symbol, Nothing}, Vector{UInt64}}
    be_frame_times::Dict{Symbol, NTuple{2, Vector{UInt64}}}
    plots::Dict{Symbol, Vector{Tuple{UInt64, Float64}}}
    fiber::Symbol
    isactive_stack::Vector{Bool}
    isactive::Bool
end
function TestProfiler(name::Symbol=:main)
    TestProfiler(
        ReentrantLock(),
        Dict{Symbol, Vector}(name=>[]),
        Dict{Union{Symbol, Nothing}, Vector{UInt64}}(),
        Dict{Symbol, NTuple{2, Vector{UInt64}}}(),
        Dict{Symbol, Vector{Tuple{UInt64, Float64}}}(),
        name,
        Bool[],
        false,
    )
end

function new_stack(profiler::TestProfiler, name::Symbol)
    lock(profiler.lock) do
        get!(profiler.messages, name, [])
    end
    TestProfiler(
        profiler.lock,
        profiler.messages,
        profiler.frame_times,
        profiler.be_frame_times,
        profiler.plots,
        name,
        Bool[],
        false,
    )
end

function is_connected(profiler::TestProfiler)
    true
end

function unsafe_zone_begin!(profiler::TestProfiler, srcloc::SourceLocation, active::Bool)
    lock(profiler.lock) do
        push!(profiler.isactive_stack, active)
        profiler.isactive = active
        push!(profiler.messages[profiler.fiber], (;type=:unsafe_zone_begin!, srcloc, active, t_ns= time_ns()))
    end
    nothing
end

function zone_end!(profiler::TestProfiler)
    pop!(profiler.isactive_stack)
    lock(profiler.lock) do
        push!(profiler.messages[profiler.fiber], (;type=:zone_end!, t_ns= time_ns()))
        profiler.isactive = !isempty(profiler.isactive_stack) && last(profiler.isactive_stack)
    end
    nothing
end

function zone_active(profiler::TestProfiler)
    profiler.isactive
end

function zone_text!(profiler::TestProfiler, text::String)::Nothing
    if zone_active(profiler)
        lock(profiler.lock) do
            push!(profiler.messages[profiler.fiber], (;type=:zone_text!, text))
        end
    end
    nothing
end

function zone_value!(profiler::TestProfiler, value::UInt64)::Nothing
    if zone_active(profiler)
        lock(profiler.lock) do
            push!(profiler.messages[profiler.fiber], (;type=:zone_value!, value))
        end
    end
    nothing
end

function zone_color!(profiler::TestProfiler, color::Union{Symbol, UInt32})::Nothing
    if zone_active(profiler)
        _color = get_tracy_color(color)
        lock(profiler.lock) do
            push!(profiler.messages[profiler.fiber], (;type=:zone_color!, color=_color))
        end
    end
    nothing
end

function frame_mark!(profiler::TestProfiler, name::Union{Symbol, Nothing}=nothing)::Nothing
    @assert !haskey(profiler.be_frame_times, name)
    lock(profiler.lock) do
        push!(get!(Vector{UInt64}, profiler.frame_times, name), time_ns())
    end
    nothing
end
function frame_mark_begin!(profiler::TestProfiler, name::Symbol)::Nothing
    @assert !haskey(profiler.frame_times, name)
    lock(profiler.lock) do
        times = get!(()->(UInt64[], UInt64[]), profiler.be_frame_times, name)
        @assert length(first(times)) == length(last(times))
        push!(first(times), time_ns())
    end
    nothing
end
function frame_mark_end!(profiler::TestProfiler, name::Symbol)::Nothing
    @assert !haskey(profiler.frame_times, name)
    lock(profiler.lock) do
        times = profiler.be_frame_times[name]
        @assert length(first(times)) == length(last(times)) + 1
        push!(last(times), time_ns())
    end
    nothing
end

function message!(profiler::TestProfiler, text::Union{Symbol, String}; color::Union{UInt32, Symbol}=0x000000)::Nothing
    _color = get_tracy_color(color)
    lock(profiler.lock) do
        push!(profiler.messages[profiler.fiber], (;type=:message!, text, color=_color, t_ns= time_ns()))
    end
    nothing
end

function plot!(profiler::TestProfiler, name::Symbol, val::Float64)::Nothing
    lock(profiler.lock) do
        data = get!(()->(Tuple{UInt64,Float64}[]), profiler.plots, name)
        push!(data, (time_ns(), val))
    end
    nothing
end

function app_info!(profiler::TestProfiler, text::String)::Nothing
    nothing
end

end # module ZoneProfilers
