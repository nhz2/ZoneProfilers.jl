using Test
using ZoneProfilers
using ZoneProfilers: SourceLocation, TestProfiler
using Aqua: Aqua

Aqua.test_all(ZoneProfilers)

include("example-functions.jl")

function example_linenode(line)
    LineNumberNode(line, Symbol(joinpath(@__DIR__, "example-functions.jl")))
end

@testset "zone_begin macro" begin
    profiler = TestProfiler()
    
    # Test that zone_begin_test1 generates the expected messages
    @test isnothing(TestFunctions.zone_begin_test1(;profiler))
    
    messages = profiler.messages[:main]
    
    # Test basic zone_begin without arguments
    @test messages[1].type == :unsafe_zone_begin!
    @test messages[1].active
    @test repr(messages[1].srcloc) == repr(
        SourceLocation(example_linenode(11), "TestFunctions", nothing, 0x00000000)
    )

    # Test with name as string
    @test messages[2].active
    @test repr(messages[2].srcloc) == repr(
        SourceLocation(example_linenode(12), "TestFunctions", "test1-a", 0x000000)
    )
    
    # Test with name as symbol
    @test messages[3].active
    @test repr(messages[3].srcloc) == repr(
        SourceLocation(example_linenode(13), "TestFunctions", "test1b", 0x000000)
    )
    
    # Test red color
    @test messages[4].active
    @test repr(messages[4].srcloc) == repr(
        SourceLocation(example_linenode(14), "TestFunctions", nothing, 0xc50f1f)
    )
    
    # Test blue color
    @test messages[5].active
    @test repr(messages[5].srcloc) == repr(
        SourceLocation(example_linenode(15), "TestFunctions", nothing, 0x0037da)
    )
    
    # Test color as integer
    @test repr(messages[6].srcloc) == repr(
        SourceLocation(example_linenode(16), "TestFunctions", nothing, 0x000001)
    )
    
    # Test color as hex
    @test repr(messages[7].srcloc) == repr(
        SourceLocation(example_linenode(17), "TestFunctions", nothing, 0x112233)
    )
    
    # Test active=true
    @test messages[8].active
    
    # Test active=false
    @test !messages[9].active
    
    # Re run with active_flag on
    TestFunctions.active_flag = true
    TestFunctions.zone_begin_test1(;profiler=new_stack(profiler, :flag_on))
    TestFunctions.active_flag = false
    messages_on = profiler.messages[:flag_on]

    # Test active=variable
    @test !messages[10].active
    @test messages_on[10].active
    @test messages[10].srcloc === messages_on[10].srcloc
    
    # Test active=function
    @test !messages[11].active  # function returns active_flag which is false
    @test messages_on[11].active
    
    # Test multiple arguments
    @test !messages[12].active
    @test messages_on[12].active
    @test repr(messages[12].srcloc) == repr(
        SourceLocation(example_linenode(22), "TestFunctions", "test1c", 0x0037da)
    )
    @test messages[12].srcloc === messages_on[12].srcloc
    
    # Test multiple arguments in different order
    @test !messages[13].active
    @test messages_on[13].active
    @test repr(messages[13].srcloc) == repr(
        SourceLocation(example_linenode(23), "TestFunctions", "test1d", 0x0037da)
    )
    @test messages[13].srcloc === messages_on[13].srcloc

    @test length(messages) == 13  # 13 @zone_begin calls in the function
end

@testset "_process_zone_kwargs error handling" begin
    # Test invalid keyword argument format - not an expression
    @test_throws ErrorException("keyword arguments must be in the form \"key = value\". Got :invalid") begin
        ZoneProfilers._process_zone_kwargs([:invalid])
    end
    
    # Test invalid keyword argument format - wrong expression head
    @test_throws ErrorException("keyword arguments must be in the form \"key = value\". Got :(a + b)") begin
        ZoneProfilers._process_zone_kwargs([:(a + b)])
    end
    
    # Test invalid keyword argument format - wrong number of args (only one)
    @test_throws ErrorException("keyword arguments must be in the form \"key = value\". Got :(\$(Expr(:(=), :a)))") begin
        ZoneProfilers._process_zone_kwargs([Expr(:(=), :a)])
    end
    
    # Test invalid keyword argument format - wrong number of args (three)
    @test_throws ErrorException("keyword arguments must be in the form \"key = value\". Got :(\$(Expr(:(=), :a, :b, :c)))") begin
        ZoneProfilers._process_zone_kwargs([Expr(:(=), :a, :b, :c)])
    end
    
    # Test invalid keyword argument format - non-symbol key
    @test_throws ErrorException("keyword arguments must be in the form \"key = value\". Got :(1 = 2)") begin
        ZoneProfilers._process_zone_kwargs([:(1 = 2)])
    end
    
    # Test repeated color keyword
    @test_throws ErrorException("color keyword argument repeated") begin
        ZoneProfilers._process_zone_kwargs([:(color = :red), :(color = :blue)])
    end
    
    # Test invalid color value - expression
    @test_throws ErrorException("color is expected to be a 0xRRGGBB or Symbol literal") begin
        ZoneProfilers._process_zone_kwargs([:(color = some_variable)])
    end
    
    # Test invalid color value - unsupported type
    @test_throws ErrorException("color is expected to be a 0xRRGGBB or Symbol literal") begin
        ZoneProfilers._process_zone_kwargs([:(color = [1, 2, 3])])
    end
    
    # Test repeated name keyword
    @test_throws ErrorException("name keyword argument repeated") begin
        ZoneProfilers._process_zone_kwargs([:(name = "first"), :(name = "second")])
    end
    
    # Test invalid name value - expression
    @test_throws ErrorException("name is expected to be a Symbol, or String literal") begin
        ZoneProfilers._process_zone_kwargs([:(name = some_variable)])
    end
    
    # Test invalid name value - unsupported type
    @test_throws ErrorException("name is expected to be a Symbol, or String literal") begin
        ZoneProfilers._process_zone_kwargs([:(name = 123)])
    end
    
    # Test repeated active keyword
    @test_throws ErrorException("active keyword argument repeated") begin
        ZoneProfilers._process_zone_kwargs([:(active = true), :(active = false)])
    end
    
    # Test unknown keyword
    @test_throws ErrorException("Unknown keyword :unknown") begin
        ZoneProfilers._process_zone_kwargs([:(unknown = value)])
    end
    
    # Test valid cases work (no errors thrown)
    @test ZoneProfilers._process_zone_kwargs([]) == (name=nothing, color=0x000000, active=true)
    @test ZoneProfilers._process_zone_kwargs([:(name = "test")]) == (name="test", color=0x000000, active=true)
    @test ZoneProfilers._process_zone_kwargs([:(color = 0xFF0000)]) == (name=nothing, color=0xFF0000, active=true)
    @test ZoneProfilers._process_zone_kwargs([:(active = false)]) == (name=nothing, color=0x000000, active=false)
end

@testset "@zone macro" begin
    profiler = TestProfiler()
    # Test that zone_function_name generates the expected messages
    @test TestFunctions.zone_function_name(;profiler) == "foo"
    messages = profiler.messages[:main]
    i = 0
    line = 26
    @test messages[i+=1].type == :unsafe_zone_begin!
    @test repr(messages[i].srcloc) == repr(
        SourceLocation(example_linenode(line+=1), "sqrt", nothing, 0x00000000)
    )
    @test messages[i+=1].type == :zone_end!
    @test messages[i+=1].type == :unsafe_zone_begin!
    @test repr(messages[i].srcloc) == repr(
        SourceLocation(example_linenode(line+=1), "Nothing", "mynothing", 0x00000000)
    )
    @test messages[i+=1].type == :zone_end!
    @test messages[i+=1].type == :unsafe_zone_begin!
    @test repr(messages[i].srcloc) == repr(
        SourceLocation(example_linenode(line+=1), "Base.sqrt", "mysqrt", 0x00000000)
    )
    @test messages[i+=1].type == :zone_end!
    @test messages[i+=1].type == :unsafe_zone_begin!
    @test repr(messages[i].srcloc) == repr(
        SourceLocation(example_linenode(line+=1), "TestFunctions", nothing, 0x00000000)
    )
    @test messages[i+=1].type == :zone_end!

    profiler = TestProfiler()
    
    # Test basic @zone usage
    result = @zone profiler begin
        42
    end
    @test result == 42
    
    messages = profiler.messages[:main]
    @test length(messages) == 2
    @test messages[1].type == :unsafe_zone_begin!
    @test messages[1].active == true
    @test messages[2].type == :zone_end!
    
    # Clear messages for next test
    profiler = TestProfiler()
    
    # Test @zone with name and color
    result = @zone profiler name="test_zone" color=:green begin
        "hello"
    end
    @test result == "hello"
    
    messages = profiler.messages[:main]
    @test length(messages) == 2
    @test messages[1].type == :unsafe_zone_begin!
    @test messages[1].active == true
    @test ZoneProfilers._get_string(messages[1].srcloc.name) == "test_zone"
    @test messages[1].srcloc.color == ZoneProfilers.get_tracy_color(:green)
    @test messages[2].type == :zone_end!
    
    # Clear messages for next test
    empty!(profiler.messages[:main])
    
    # Test @zone with active=false
    result = @zone profiler active=false begin
        "inactive"
    end
    @test result == "inactive"
    
    messages = profiler.messages[:main]
    @test length(messages) == 2
    @test messages[1].type == :unsafe_zone_begin!
    @test messages[1].active == false
    @test messages[2].type == :zone_end!
end

@testset "new_stack function" begin
    profiler = TestProfiler()
    
    # Test creating a new stack
    new_profiler = new_stack(profiler, :test_fiber)
    @test profiler.fiber == :main
    @test new_profiler.fiber == :test_fiber
    @test haskey(profiler.messages, :test_fiber)
    @test length(profiler.messages[:test_fiber]) == 0
    
    # Test that operations on new stack go to the right fiber
    @zone_begin new_profiler
    @test length(profiler.messages[:test_fiber]) == 1
    @test length(profiler.messages[:main]) == 0
    
    zone_end!(new_profiler)
    @test length(profiler.messages[:test_fiber]) == 2
    @test profiler.messages[:test_fiber][1].type == :unsafe_zone_begin!
    @test profiler.messages[:test_fiber][2].type == :zone_end!
end

@testset "NullProfiler" begin
    # Test that NullProfiler doesn't crash and returns nothing
    profiler = NullProfiler()
    
    result1 = @zone_begin profiler
    @test result1 === nothing
    
    result2 = zone_end!(profiler)
    @test result2 === nothing
    
    result = @zone profiler begin
        "test"
    end
    @test result == "test"

    result = @zone profiler active=()->error("be more lazy") begin
        "test"
    end
    @test result == "test"
    
    new_profiler = new_stack(profiler, :test)
    @test new_profiler isa NullProfiler

    new_profiler = new_stack(profiler, ()->error("be more lazy"))
    @test new_profiler isa NullProfiler
end

@testset "zone modification functions" begin
    profiler = TestProfiler()
    
    # Test zone_text! when zone is inactive (default state)
    zone_text!(profiler, "inactive text")
    @test length(profiler.messages[:main]) == 0  # Should not record anything when inactive
    
    # Test zone_value! when zone is inactive
    zone_value!(profiler, UInt64(42))
    @test length(profiler.messages[:main]) == 0  # Should not record anything when inactive
    
    # Test zone_color! when zone is inactive
    zone_color!(profiler, :red)
    @test length(profiler.messages[:main]) == 0  # Should not record anything when inactive
    
    # Start an active zone
    @zone_begin profiler
    
    # Test zone_text! when zone is active
    zone_text!(profiler, "active text")
    messages = profiler.messages[:main]
    @test length(messages) == 2  # zone_begin + zone_text!
    @test messages[2].type == :zone_text!
    @test messages[2].text == "active text"
    
    # Test zone_value! when zone is active
    zone_value!(profiler, UInt64(123))
    messages = profiler.messages[:main]
    @test length(messages) == 3  # zone_begin + zone_text! + zone_value!
    @test messages[3].type == :zone_value!
    @test messages[3].value == UInt64(123)
    
    # Test zone_color! with symbol when zone is active
    zone_color!(profiler, :blue)
    messages = profiler.messages[:main]
    @test length(messages) == 4  # zone_begin + zone_text! + zone_value! + zone_color!
    @test messages[4].type == :zone_color!
    @test messages[4].color == ZoneProfilers.get_tracy_color(:blue)
    
    # Test zone_color! with hex value when zone is active
    zone_color!(profiler, 0xFF0000)
    messages = profiler.messages[:main]
    @test length(messages) == 5
    @test messages[5].type == :zone_color!
    @test messages[5].color == 0xFF0000
    
    # Test zone_color! when zone is active
    zone_color!(profiler, :green)
    messages = profiler.messages[:main]
    @test length(messages) == 6
    @test messages[6].type == :zone_color!
    @test messages[6].color == ZoneProfilers.get_tracy_color(:green)
    
    # End the zone
    zone_end!(profiler)
    
    # Test that functions return nothing and don't crash after zone ends
    zone_text!(profiler, "after end")
    zone_value!(profiler, UInt64(999))
    zone_color!(profiler, :yellow)
    @test length(profiler.messages[:main]) == 7  # Should not have added any new messages
    
    # Test with NullProfiler to ensure no crashes
    null_profiler = NullProfiler()
    @test zone_text!(null_profiler, "test") === nothing
    @test zone_value!(null_profiler, UInt64(42)) === nothing
    @test zone_color!(null_profiler, :red) === nothing
end

@testset "zone_show macro" begin
    profiler = TestProfiler()
    x = 42
    @zone profiler begin
        @test isnothing(@zone_show(profiler, x))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_text!
    @test messages[2].text == "x = 42"

    profiler = TestProfiler()
    x = 42
    y = 43
    @zone profiler begin
        @test isnothing(@zone_show(profiler, x, y))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_text!
    @test messages[2].text == "x = 42"
    @test messages[3].type == :zone_text!
    @test messages[3].text == "y = 43"

    profiler = TestProfiler()
    @zone profiler begin
        @test isnothing(@zone_show(profiler))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_end!

    profiler = TestProfiler()
    @zone profiler active=false begin
        @test isnothing(@zone_show(profiler, error("should not run")))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_end!

    profiler = NullProfiler()
    @zone profiler begin
        @test isnothing(@zone_show(profiler, error("should not run")))
    end

end

@testset "zone_repr macro" begin
    profiler = TestProfiler()
    x = 42
    @zone profiler begin
        @test isnothing(@zone_repr(profiler, x))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_text!
    @test messages[2].text == "42"

    profiler = TestProfiler()
    x = 42
    y = 43
    @zone profiler begin
        @test isnothing(@zone_repr(profiler, x, y))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_text!
    @test messages[2].text == "42"
    @test messages[3].type == :zone_text!
    @test messages[3].text == "43"

    profiler = TestProfiler()
    @zone profiler begin
        @test isnothing(@zone_repr(profiler))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_end!

    profiler = TestProfiler()
    @zone profiler active=false begin
        @test isnothing(@zone_repr(profiler, error("should not run")))
    end
    messages = profiler.messages[:main]
    @test messages[2].type == :zone_end!

    profiler = NullProfiler()
    @zone profiler begin
        @test isnothing(@zone_repr(profiler, error("should not run")))
    end

end

@testset "frame marking functions" begin
    profiler = TestProfiler()
    
    # Test frame_mark! with default name (nothing)
    frame_mark!(profiler)
    @test haskey(profiler.frame_times, nothing)
    @test length(profiler.frame_times[nothing]) == 1
    @test profiler.frame_times[nothing][1] isa UInt64
    
    # Test frame_mark! with multiple calls
    frame_mark!(profiler)
    frame_mark!(profiler)
    @test length(profiler.frame_times[nothing]) == 3
    
    # Test frame_mark! with named frame set
    frame_mark!(profiler, :render)
    @test haskey(profiler.frame_times, :render)
    @test length(profiler.frame_times[:render]) == 1
    @test !haskey(profiler.be_frame_times, :render)  # Should not affect be_frame_times
    
    # Test frame_mark_begin! and frame_mark_end!
    frame_mark_begin!(profiler, :game_loop)
    @test haskey(profiler.be_frame_times, :game_loop)
    @test !haskey(profiler.frame_times, :game_loop)  # Should not affect frame_times
    
    begin_times, end_times = profiler.be_frame_times[:game_loop]
    @test length(begin_times) == 1
    @test length(end_times) == 0
    @test begin_times[1] isa UInt64
    
    # End the frame
    frame_mark_end!(profiler, :game_loop)
    begin_times, end_times = profiler.be_frame_times[:game_loop]
    @test length(begin_times) == 1
    @test length(end_times) == 1
    @test end_times[1] isa UInt64
    
    # Operations on new stack should affect the same frame tracking
    frame_mark!(new_stack(profiler, :stack2), :shared_frame)
    @test haskey(profiler.frame_times, :shared_frame)
    @test length(profiler.frame_times[:shared_frame]) == 1
    
    # Test NullProfiler compatibility
    null_profiler = NullProfiler()
    @test frame_mark!(null_profiler) === nothing
    @test frame_mark!(null_profiler, :test) === nothing
    @test frame_mark_begin!(null_profiler, :test) === nothing
    @test frame_mark_end!(null_profiler, :test) === nothing
end

@testset "message! function" begin
    profiler = TestProfiler()
    
    # Test basic message
    message!(profiler, "test message")
    messages = profiler.messages[:main]
    @test length(messages) == 1
    @test messages[1].type == :message!
    @test messages[1].text == "test message"
    @test messages[1].color == 0x000000
    
    # Test with color
    message!(profiler, "colored"; color=:red)
    @test length(messages) == 2
    @test messages[2].text == "colored"
    @test messages[2].color == ZoneProfilers.get_tracy_color(:red)
    
    # Test with NullProfiler
    @test message!(NullProfiler(), "test") === nothing
    @test message!(NullProfiler(), "test"; color=0x0000FF) === nothing
end

@testset "plot! function" begin
    profiler = TestProfiler()
    
    # Test basic plot
    plot!(profiler, :fps, 60.0)
    @test haskey(profiler.plots, :fps)
    @test length(profiler.plots[:fps]) == 1
    @test profiler.plots[:fps][1][2] == 60.0  # value
    @test profiler.plots[:fps][1][1] isa UInt64  # timestamp
    
    # Test multiple values
    plot!(profiler, :fps, 58.5)
    plot!(profiler, :memory, 1024.0)
    @test length(profiler.plots[:fps]) == 2
    @test length(profiler.plots[:memory]) == 1
    @test profiler.plots[:fps][2][2] == 58.5
    @test profiler.plots[:memory][1][2] == 1024.0
    
    # Test with NullProfiler
    @test plot!(NullProfiler(), :test, 1.0) === nothing
end

ZoneProfilers.profiler_smoke_test(NullProfiler())
ZoneProfilers.profiler_smoke_test(TestProfiler())

include("test-symbol-lifetimes.jl")
