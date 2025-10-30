function logo(;profiler=NullProfiler())
    top = new_stack(profiler, :worker1)
    bottom = new_stack(profiler, :worker2)
    frame_mark!(profiler)
    t1 = Threads.@spawn begin
        frame_mark_begin!(profiler, :red_T)
        message!(bottom, "$(Threads.threadid())")
        @zone bottom color=0xCB3C33 name="" begin
            sleep(0.2)
            message!(bottom, "$(Threads.threadid())")
            for i in 1:4
                @zone_begin bottom color=0xCB3C33 name=""
            end
            sleep(0.1)
            message!(bottom, "$(Threads.threadid())")
            for i in 1:4
                zone_end!(bottom)
            end
            sleep(0.2)
            message!(bottom, "$(Threads.threadid())")
        end
        frame_mark_end!(profiler, :red_T)
        sleep(0.3)
        frame_mark_begin!(profiler, :purple_T)
        message!(bottom, "$(Threads.threadid())")
        @zone bottom color=0x9558B2 name="" begin
            sleep(0.2)
            message!(bottom, "$(Threads.threadid())")
            for i in 1:4
                @zone_begin bottom color=0x9558B2 name=""
            end
            sleep(0.1)
            message!(bottom, "$(Threads.threadid())")
            for i in 1:4
                zone_end!(bottom)
            end
            sleep(0.2)
            message!(bottom, "$(Threads.threadid())")
        end
        frame_mark_end!(profiler, :purple_T)
    end
    t2 = Threads.@spawn begin
        sleep(0.4)
        frame_mark_begin!(profiler, :green_T)
        message!(top, "$(Threads.threadid())")
        @zone top color=0x389826 name="" begin
            sleep(0.2)
            message!(top, "$(Threads.threadid())")
            for i in 1:4
                @zone_begin top color=0x389826 name=""
            end
            sleep(0.1)
            message!(top, "$(Threads.threadid())")
            for i in 1:4
                zone_end!(top)
            end
            sleep(0.2)
            message!(top, "$(Threads.threadid())")
        end
        frame_mark_end!(profiler, :green_T)
    end
    waitall([t1, t2])
    frame_mark!(profiler)
end
