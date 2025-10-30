# These tests have been ported from https://github.com/topolarity/Tracy.jl/blob/v0.1.4/test/
# Tracy.jl was MIT licensed and was written by Cody Tapscott <cody.tapscott@juliahub.com>, Kristoffer Carlsson <kristoffer.carlsson@juliahub.com>, and Elliot Saba <staticfloat@gmail.com>

using ZoneProfilers
using ZoneProfilerTracy
using Test
using Pkg

profiler = TracyProfiler()

if haskey(ENV, "TRACYJL_WAIT_FOR_TRACY")
    @info "Waiting for tracy to connect..."
    wait_for_connection(profiler)
    @info "Connected!"
end

for i in 1:3
    @zone profiler name="test tracepoint" begin
        println("Hello, world!")
    end
end

for i in 1:5
    @test_throws ErrorException @zone profiler name="test exception" begin
        error("oh no!")
    end
end

Pkg.develop(; path = joinpath(@__DIR__, "TestPkg"), io=devnull)
# Test that a precompiled package also works,
using TestPkg
TestPkg.time_something(;profiler)

@testset "msg" begin
    message!(profiler, "Hello, world!"; color=0xFF00FF)
    message!(profiler, "Hello, sailor!"; color=:red)

    message!(profiler, "")
    message!(profiler, "system color red"; color=:red)
    message!(profiler, "system color green"; color=:green)
    message!(profiler, "system color blue"; color=:blue)
    message!(profiler, "system color yellow"; color=:yellow)
    message!(profiler, "system color magenta"; color=:magenta)
end

for x in range(0, 2pi, 100)
    plot!(profiler, :sin, sin(x))
    plot!(profiler, :cos, 100*cos(x))
    sleep(0.005)
end

for j in 1:5
    @zone profiler name="SLP" color=0x00FF00 begin
        sleep(0.01)
    end
end
for j in 1:10
    @zone profiler name="SROA" color=0x0A141E begin
        sleep(0.01)
    end
end
for j in 1:15
    @zone profiler name="Inlining" color=:red begin
        sleep(0.01)
    end
end

function hsv_to_rgb(h, s, v)
    h = h / 60
    i = floor(h)
    f = h - i
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))

    if i == 0
        r, g, b = v, t, p
    elseif i == 1
        r, g, b = q, v, p
    elseif i == 2
        r, g, b = p, v, t
    elseif i == 3
        r, g, b = p, q, v
    elseif i == 4
        r, g, b = t, p, v
    else
        r, g, b = v, p, q
    end

    r, g, b = round(Int, r * 255), round(Int, g * 255), round(Int, b * 255)

    return UInt32(r<<16 | g<<8 | b)
end

function generate_rainbow(n)
    return [hsv_to_rgb(i * 360 / n, 1, 1) for i in 0:(n-1)]
end

n_outer = 50
n_inner = 10

for color in generate_rainbow(n_outer)
    @zone profiler name="rainbow outer" begin
        zone_text!(profiler, repr(color))
        zone_color!(profiler, color)
        for color in  generate_rainbow(n_inner)
            @zone profiler name="rainbow inner" begin
                zone_text!(profiler, repr(color))
                zone_color!(profiler, color)
                sleep(0.1 / (n_inner * n_outer))
            end
        end
    end
end

for i in 1:10
    @zone profiler name="conditionally disabled" active=isodd(i) begin
        sleep(0.01)
    end
end

sleep(0.5)
