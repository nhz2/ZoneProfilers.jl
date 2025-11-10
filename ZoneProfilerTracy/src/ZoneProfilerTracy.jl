module ZoneProfilerTracy

using LibTracyClient_jll: libTracyClient
using ZoneProfilers:
    SourceLocation,
    Profiler,
    get_tracy_color,
    wait_for_connection

import ZoneProfilers:
    new_stack,
    is_connected,
    app_info!,
    message!,
    unsafe_zone_begin!,
    zone_end!,
    zone_active,
    zone_color!,
    zone_text!,
    zone_value!,
    frame_mark!,
    frame_mark_begin!,
    frame_mark_end!,
    plot!

export TracyProfiler

struct TracyCZoneCtx
    id::UInt32
    active::Cint
end

"""
    struct TracyProfiler <: Profiler

A wrapper of the Tracy C library for profiling marked up code.

A convenience constructor `TracyProfiler(TracyProfiler_jll)`
will start up the tracy GUI.

Documentation: https://github.com/nhz2/ZoneProfilers.jl
"""
mutable struct TracyProfiler <: Profiler
    stack::Vector{TracyCZoneCtx}
    fiber::Symbol
    isactive::Bool
end
function TracyProfiler(name::Symbol=:main)
    TracyProfiler(TracyCZoneCtx[], name, false)
end
# Convenience constructor that also starts the GUI
function TracyProfiler(jll::Module)
    tracy_port = get(ENV, "TRACY_PORT", nothing)
    if isnothing(tracy_port)
        run(`$(jll.tracy()) -a 127.0.0.1`; wait=false)
    else
        run(`$(jll.tracy()) -a 127.0.0.1 -p $(tracy_port)`; wait=false)
    end
    profiler = TracyProfiler()
    wait_for_connection(profiler)
    profiler
end

function new_stack(profiler::TracyProfiler, name::Symbol)
    TracyProfiler(name)
end

function is_connected(profiler::TracyProfiler)
    !iszero(@ccall libTracyClient.___tracy_connected()::Cint)
end

function app_info!(profiler::TracyProfiler, text::String)::Nothing
    @ccall libTracyClient.___tracy_emit_message_appinfo(text::Ptr{UInt8}, ncodeunits(text)::Csize_t)::Cvoid
end

function message!(profiler::TracyProfiler, text::Symbol; color::Union{UInt32, Symbol}=0x000000)::Nothing
    # Manually pull out conversion to avoid task switches in critical section.
    fiber_cconv = Base.cconvert(Ptr{UInt8}, profiler.fiber)
    text_cconv = Base.cconvert(Ptr{UInt8}, text)
    _color = get_tracy_color(color)
    GC.@preserve fiber_cconv text_cconv begin
        fiber_p = Base.unsafe_convert(Ptr{UInt8}, fiber_cconv)
        text_p = Base.unsafe_convert(Ptr{UInt8}, text_cconv)
        @ccall libTracyClient.___tracy_fiber_enter(fiber_p::Ptr{UInt8})::Cvoid
        if iszero(_color)
            @ccall libTracyClient.___tracy_emit_messageL(text_p::Ptr{UInt8}, Cint(0)::Cint)::Cvoid
        else
            @ccall libTracyClient.___tracy_emit_messageLC(text_p::Ptr{UInt8}, _color::UInt32, Cint(0)::Cint)::Cvoid
        end
    end
    nothing
end
function message!(profiler::TracyProfiler, text::String; color::Union{UInt32, Symbol}=0x000000)::Nothing
    # Manually pull out conversion to avoid task switches in critical section.
    fiber_cconv = Base.cconvert(Ptr{UInt8}, profiler.fiber)
    text_cconv = Base.cconvert(Ptr{UInt8}, text)
    size = ncodeunits(text)%Csize_t
    _color = get_tracy_color(color)
    GC.@preserve fiber_cconv text_cconv begin
        fiber_p = Base.unsafe_convert(Ptr{UInt8}, fiber_cconv)
        text_p = Base.unsafe_convert(Ptr{UInt8}, text_cconv)
        @ccall libTracyClient.___tracy_fiber_enter(fiber_p::Ptr{UInt8})::Cvoid
        if iszero(_color)
            @ccall libTracyClient.___tracy_emit_message(text_p::Ptr{UInt8}, size::Csize_t, Cint(0)::Cint)::Cvoid
        else
            @ccall libTracyClient.___tracy_emit_messageC(text_p::Ptr{UInt8}, size::Csize_t, _color::UInt32, Cint(0)::Cint)::Cvoid
        end
    end
    nothing
end

function unsafe_zone_begin!(profiler::TracyProfiler, srcloc::SourceLocation, active::Bool)
    profiler.isactive = active
    if active
        # Manually pull out conversion to avoid task switches in critical section.
        fiber_cconv = Base.cconvert(Ptr{UInt8}, profiler.fiber)
        srcloc_cconv = Base.cconvert(Ref{SourceLocation}, srcloc)
        GC.@preserve fiber_cconv srcloc_cconv begin
            fiber_p = Base.unsafe_convert(Ptr{UInt8}, fiber_cconv)
            srcloc_p = Base.unsafe_convert(Ref{SourceLocation}, srcloc_cconv)
            @ccall libTracyClient.___tracy_fiber_enter(fiber_p::Ptr{UInt8})::Cvoid
            ret = @ccall libTracyClient.___tracy_emit_zone_begin(srcloc_p::Ref{SourceLocation}, Cint(1)::Cint)::TracyCZoneCtx
        end
        push!(profiler.stack, ret)
    else
        push!(profiler.stack, TracyCZoneCtx(UInt32(0), Cint(false)))
    end
    nothing
end

function zone_end!(profiler::TracyProfiler)
    zonectx = pop!(profiler.stack)
    if profiler.isactive
        # Manually pull out conversion to avoid task switches in critical section.
        fiber_cconv = Base.cconvert(Ptr{UInt8}, profiler.fiber)
        GC.@preserve fiber_cconv begin
            fiber_p = Base.unsafe_convert(Ptr{UInt8}, fiber_cconv)
            @ccall libTracyClient.___tracy_fiber_enter(fiber_p::Ptr{UInt8})::Cvoid
            @ccall libTracyClient.___tracy_emit_zone_end(zonectx::TracyCZoneCtx)::Cvoid
        end
    end
    profiler.isactive = !isempty(profiler.stack) && !iszero(last(profiler.stack).active)
    nothing
end

function zone_active(profiler::TracyProfiler)
    profiler.isactive
end

function zone_color!(profiler::TracyProfiler, color)::Nothing
    if zone_active(profiler)
        zonectx = last(profiler.stack)
        # Manually pull out conversion to avoid task switches in critical section.
        fiber_cconv = Base.cconvert(Ptr{UInt8}, profiler.fiber)
        _color = get_tracy_color(color)
        GC.@preserve fiber_cconv begin
            fiber_p = Base.unsafe_convert(Ptr{UInt8}, fiber_cconv)
            @ccall libTracyClient.___tracy_fiber_enter(fiber_p::Ptr{UInt8})::Cvoid
            @ccall libTracyClient.___tracy_emit_zone_color(zonectx::TracyCZoneCtx, _color::UInt32)::Cvoid
        end
    end
    nothing
end

function zone_text!(profiler::TracyProfiler, text::String)::Nothing
    if zone_active(profiler)
        zonectx = last(profiler.stack)
        # Manually pull out conversion to avoid task switches in critical section.
        fiber_cconv = Base.cconvert(Ptr{UInt8}, profiler.fiber)
        text_cconv = Base.cconvert(Ptr{UInt8}, text)
        size = ncodeunits(text)%Csize_t
        GC.@preserve fiber_cconv text_cconv begin
            fiber_p = Base.unsafe_convert(Ptr{UInt8}, fiber_cconv)
            text_p = Base.unsafe_convert(Ptr{UInt8}, text_cconv)
            @ccall libTracyClient.___tracy_fiber_enter(fiber_p::Ptr{UInt8})::Cvoid
            @ccall libTracyClient.___tracy_emit_zone_text(zonectx::TracyCZoneCtx, text_p::Ptr{UInt8}, size::Csize_t)::Cvoid
        end
    end
    nothing
end

function zone_value!(profiler::TracyProfiler, value::UInt64)::Nothing
    if zone_active(profiler)
        zonectx = last(profiler.stack)
        # Manually pull out conversion to avoid task switches in critical section.
        fiber_cconv = Base.cconvert(Ptr{UInt8}, profiler.fiber)
        GC.@preserve fiber_cconv begin
            fiber_p = Base.unsafe_convert(Ptr{UInt8}, fiber_cconv)
            @ccall libTracyClient.___tracy_fiber_enter(fiber_p::Ptr{UInt8})::Cvoid
            @ccall libTracyClient.___tracy_emit_zone_value(zonectx::TracyCZoneCtx, value::UInt64)::Cvoid
        end
    end
    nothing
end

function frame_mark!(profiler::TracyProfiler, name::Union{Symbol, Nothing}=nothing)::Nothing
    if isnothing(name)
        @ccall libTracyClient.___tracy_emit_frame_mark(C_NULL::Ptr{UInt8})::Cvoid
    else
        @ccall libTracyClient.___tracy_emit_frame_mark(name::Ptr{UInt8})::Cvoid
    end
end
function frame_mark_begin!(profiler::TracyProfiler, name::Symbol)::Nothing
    @ccall libTracyClient.___tracy_emit_frame_mark_start(name::Ptr{UInt8})::Cvoid
end
function frame_mark_end!(profiler::TracyProfiler, name::Symbol)::Nothing
    @ccall libTracyClient.___tracy_emit_frame_mark_end(name::Ptr{UInt8})::Cvoid
end

function plot!(profiler::TracyProfiler, name::Symbol, val::Float64)::Nothing
    @ccall libTracyClient.___tracy_emit_plot(name::Ptr{UInt8}, val::Cdouble)::Cvoid
end

end # module ZoneProfilerTracy
