module TestBroadcastableCallable

using BroadcastableStructs
using ChainCutters: cut, uncut
using Setfield: @set
using Test
using Zygote

bcapp(f, args...) = f.(args...)

struct WeightedAdd{A, B} <: BroadcastableCallable
    a::A
    b::B
end

(f::WeightedAdd)(u, v) = f.a * u + f.b * v

@testset begin
    f = WeightedAdd(rand(2)...)
    u = rand(5)
    v = rand(5)

    #=
    y_actual, back_actual = Zygote.forward(v -> sum(f.(cut(u), v)), v)
    y_desired, back_desired = Zygote.forward(v -> sum(f.(u, v)), v)
    @test y_actual == y_desired
    @test back_actual(1) == back_desired(1)

    y_actual, back_actual = Zygote.forward(u -> sum(f.(u, cut(v))), u)
    y_desired, back_desired = Zygote.forward(u -> sum(f.(u, v)), u)
    @test y_actual == y_desired
    @test back_actual(1) == back_desired(1)
    =#

    y_actual, back_actual = Zygote.forward(f.a) do a
        g = cut(@set f.a = uncut(a))
        # g = Zygote.@showgrad g
        sum(g.(u, v))
    end
    y_desired, back_desired = Zygote.forward(f.a) do a
        g = @set f.a = a
        # g = Zygote.@showgrad g
        sum(g.(u, v))
    end
    @test y_actual == y_desired
    @test back_actual(1) == back_desired(1)

    @testset "all constants" begin
        function h(a)
            g = cut(@set f.a = a)
            sum(g.(cut(u), cut(v)))
        end
        y_actual, back_actual = Zygote.forward(h, f.a)
        @test y_actual == h(f.a)
        @test back_actual(1) == (nothing,)
    end
end

end  # module
