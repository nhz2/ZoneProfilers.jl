module ZoneProfilers

abstract type Profiler end

"""
Profiler to disable profiling.
"""
struct NullProfiler <: Profiler end

struct TracyProfiler <: Profiler
    stack::Vector{UInt64}
    fiber::Symbol
end
function TracyProfiler(name::Symbol=:main)
    TracyProfiler(UInt64[], name)
end

struct SourceLocationData
    zone_name::Union{Symbol, Nothing}
    function_name::Union{Symbol, Nothing}
    src_file_name::Symbol
    line::Int64
    color::UInt32
end

"""
    new_stack(ctx::Profiler, name::Symbol)
    new_stack(ctx::Profiler, name_fn::Function) -> new_stack(ctx, name_fn())

Start a new profiling stack.

Arguments:
- name: a Symbol, or a zero-argument function that returns a Symbol.
"""
function new_stack(ctx::NullProfiler, name)
    NullProfiler()
end

function new_stack(ctx::TracyProfiler, name::Symbol)
    TracyProfiler(name)
end
function new_stack(ctx::TracyProfiler, name)
    TracyProfiler(name())
end

#define TracyCZone( ctx, active ) static const struct ___tracy_source_location_data TracyConcat(__tracy_source_location,TracyLine) = { NULL, __func__,  TracyFile, (uint32_t)TracyLine, 0 }; TracyCZoneCtx ctx = ___tracy_emit_zone_begin_callstack( &TracyConcat(__tracy_source_location,TracyLine), TRACY_CALLSTACK, active );
#define TracyCZoneN( ctx, name, active ) static const struct ___tracy_source_location_data TracyConcat(__tracy_source_location,TracyLine) = { name, __func__,  TracyFile, (uint32_t)TracyLine, 0 }; TracyCZoneCtx ctx = ___tracy_emit_zone_begin_callstack( &TracyConcat(__tracy_source_location,TracyLine), TRACY_CALLSTACK, active );
#define TracyCZoneC( ctx, color, active ) static const struct ___tracy_source_location_data TracyConcat(__tracy_source_location,TracyLine) = { NULL, __func__,  TracyFile, (uint32_t)TracyLine, color }; TracyCZoneCtx ctx = ___tracy_emit_zone_begin_callstack( &TracyConcat(__tracy_source_location,TracyLine), TRACY_CALLSTACK, active );
#define TracyCZoneNC( ctx, name, color, active ) static const struct ___tracy_source_location_data TracyConcat(__tracy_source_location,TracyLine) = { name, __func__,  TracyFile, (uint32_t)TracyLine, color }; TracyCZoneCtx ctx = ___tracy_emit_zone_begin_callstack( &TracyConcat(__tracy_source_location,TracyLine), TRACY_CALLSTACK, active );

#define TracyCZoneEnd( ctx ) ___tracy_emit_zone_end( ctx );

#define TracyCZoneText( ctx, txt, size ) ___tracy_emit_zone_text( ctx, txt, size );
#define TracyCZoneName( ctx, txt, size ) ___tracy_emit_zone_name( ctx, txt, size );
#define TracyCZoneColor( ctx, color ) ___tracy_emit_zone_color( ctx, color );
#define TracyCZoneValue( ctx, value ) ___tracy_emit_zone_value( ctx, value );

function zone_begin!(ctx::TracyProfiler, srcloc::SourceLocationData, text, color, value, isactive)
    nothing
end

function zone_end!(ctx)
    nothing
end

function 


end # module ZoneProfilers
