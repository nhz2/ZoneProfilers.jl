"""
    profiler_smoke_test(profiler::Profiler)::Nothing

Run through all of the Profiler functions to check everything compiles.
"""
function profiler_smoke_test(profiler::Profiler)::Nothing
    is_connected(profiler)

    app_info!(profiler, "this is app info")
    app_info!(profiler, "more app info")

    new_profiler = new_stack(profiler, :newstack)
    message!(profiler, "hello from main")
    message!(profiler, :my_symbol)
    message!(profiler, :my_symbol_red; color= :red)
    message!(profiler, "hello from main red"; color= :red)
    message!(new_profiler, "hello from newstack")

    @zone profiler sleep(0.01)
    @zone profiler name="zone name" sleep(0.01)
    @zone profiler name="zone name and color" color=:red sleep(0.01)

    @zone profiler name="change stuff" begin
        zone_active(profiler)
        zone_color!(profiler, :blue)
        zone_text!(profiler, "zone text")
        zone_value!(profiler, UInt64(1234))
        zone_text!(profiler, "more text")
    end

    @zone profiler name="not active" active=false begin
        zone_active(profiler)
        zone_color!(profiler, :blue)
        zone_text!(profiler, "zone text")
        zone_value!(profiler, UInt64(1234))
        zone_text!(profiler, "more text")
    end

    frame_mark!(profiler)
    frame_mark!(profiler, :myframe)
    frame_mark_begin!(profiler, :otherframe)
    frame_mark_end!(profiler, :otherframe)

    plot!(profiler, :foo, 3.14)

    nothing
end