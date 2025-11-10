# Example functions that use the profile macros for testing purposes
# Make sure to add new examples to the bottom of the file to avoid messing up
# the line numbers.
module TestFunctions

using ZoneProfilers: NullProfiler, @zone, @zone_begin, zone_end!

global active_flag = false

function zone_begin_test1(;profiler=NullProfiler())
    @zone_begin profiler
    @zone_begin profiler name= "test1-a"
    @zone_begin profiler name= :test1b
    @zone_begin profiler color= :red
    @zone_begin profiler color= :blue
    @zone_begin profiler color= 0x000001
    @zone_begin profiler color= 0x112233
    @zone_begin profiler active= true
    @zone_begin profiler active= false
    @zone_begin profiler active= active_flag
    @zone_begin profiler active= ()->active_flag
    @zone_begin profiler active= active_flag color= :blue name= :test1c
    @zone_begin profiler name= :test1d active= active_flag color= :blue
end

function zone_function_name(;profiler=NullProfiler())
    @zone profiler sqrt(2.0)
    @zone profiler name="mynothing" Nothing()
    @zone profiler name="mysqrt" Base.sqrt(2.0)
    @zone profiler "foo"
end

end  # module TestFunctions