using Test

@noinline function get_symbol_ptr(str::String, n::Int)
    s = Symbol("$(str)$(n)")
    s_cconv = Base.cconvert(Ptr{UInt8}, s)
    s_p = Base.unsafe_convert(Ptr{UInt8}, s_cconv)
    s_p
end

@noinline function test_symbol_ptr(str::String, n::Int, p::Ptr{UInt8})
    @test unsafe_string(p) == "$(str)$(n)"
    @test get_symbol_ptr(str, n) === p
end

@testset "symbol lifetimes" begin
    ptrs = Ptr{UInt8}[]
    N = 1000000
    for i in 1:N
        push!(ptrs, get_symbol_ptr("foo", i))
    end
    GC.gc()
    GC.gc()
    GC.gc()
    GC.gc()
    GC.gc()
    for i in 1:N
        test_symbol_ptr("foo", i, ptrs[i])
    end
end

