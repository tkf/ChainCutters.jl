module BenchBroadcast

using BenchmarkTools
using BroadcastableStructs: BroadcastableCallable
using ChainCutters: cut, uncut
using Parameters: @unpack
using Setfield: @set
using Zygote

suite = BenchmarkGroup()

struct Poly9{T0, T1, T2, T3, T4, T5, T6, T7, T8, T9} <: BroadcastableCallable
    c0::T0
    c1::T1
    c2::T2
    c3::T3
    c4::T4
    c5::T5
    c6::T6
    c7::T7
    c8::T8
    c9::T9
end

function (p::Poly9)(x)
    @unpack c0, c1, c2, c3, c4, c5, c6, c7, c8, c9 = p
    return c0 + c1 * x +
        c2 * x^2 +
        c3 * x^3 +
        c4 * x^4 +
        c5 * x^5 +
        c6 * x^6 +
        c7 * x^7 +
        c8 * x^8 +
        c9 * x^9
end

f_cut(p, x) = c -> sum((cut(@set p.c2 = uncut(c))).(cut(x)))
f_nocut(p, x) = c -> sum((@set p.c2 = c).(x))
f_man(p, x) = function(c)
    @unpack c0, c1, c3, c4, c5, c6, c7, c8, c9 = p
    c2 = c
    y = @. c0 + c1 * x +
        c2 * x^2 +
        c3 * x^3 +
        c4 * x^4 +
        c5 * x^5 +
        c6 * x^6 +
        c7 * x^7 +
        c8 * x^8 +
        c9 * x^9
    return sum(y)
end

let
    xs = rand(1000)
    p = Poly9(rand(10)...)
    suite["f_cut"] = @benchmarkable Zygote.gradient($(f_cut(p, xs)), 1.0)
    suite["f_nocut"] = @benchmarkable Zygote.gradient($(f_nocut(p, xs)), 1.0)
    suite["f_man"] = @benchmarkable Zygote.gradient($(f_man(p, xs)), 1.0)
end

end  # module
BenchBroadcast.suite
