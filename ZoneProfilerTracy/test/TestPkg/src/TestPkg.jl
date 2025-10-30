module TestPkg

using ZoneProfilers

function time_something(;profiler=NullProfiler())
    for _ in 1:100
        @zone profiler name="timing" rand(100)
    end
end

# Try to test the source location survives serialization in a package image.
precompile(time_something, ())

end # module TestPkg
