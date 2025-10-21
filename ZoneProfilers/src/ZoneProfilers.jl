module ZoneProfilers

"""
Profiler to disable profiling.
"""
struct NullProfiler end

struct SourceLocationData
    zone_name::Union{Symbol, Nothing}
    function_name::Union{Symbol, Nothing}
    src_file_name::Symbol
    line::Int64
    color::UInt32
end

function set_task_name!(ctx::NullProfiler, fiber::Symbol)
    nothing
end

function zone_begin!(ctx; kwargs...)
    nothing
end

function zone_end!(ctx)
    nothing
end


end # module ZoneProfilers
