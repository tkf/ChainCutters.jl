module TestBroadcastableCallable

using BroadcastableStructs
using ChainCutters: cut, uncut
using Setfield: @set, @set!
using Test
using Zygote

bcapp(f, args...) = f.(args...)

struct WeightedAdd{A, B} <: BroadcastableCallable
    a::A
    b::B
end

(f::WeightedAdd)(u, v) = f.a * u + f.b * v

struct Poly3{T0, T1, T2, T3} <: BroadcastableCallable
    c0::T0
    c1::T1
    c2::T2
    c3::T3
end

(p::Poly3)(x) = p.c0 + p.c1 * x + p.c2 * x^2 + p.c3 * x^3

struct AddCall{F, G} <: BroadcastableCallable
    f::F
    g::G
end

(c::AddCall)(x) = c.f(x) + c.g(x)

@testset "WeightedAdd" begin
    f = WeightedAdd(rand(2)...)
    u = rand(5)
    v = rand(5)

    y_actual, back_actual = Zygote.forward(v -> sum(f.(cut(u), v)), v)
    y_desired, back_desired = Zygote.forward(v -> sum(f.(u, v)), v)
    @test y_actual == y_desired
    @test back_actual(1) == back_desired(1)

    y_actual, back_actual = Zygote.forward(u -> sum(f.(u, cut(v))), u)
    y_desired, back_desired = Zygote.forward(u -> sum(f.(u, v)), u)
    @test y_actual == y_desired
    @test back_actual(1) == back_desired(1)

    y_actual, back_actual = Zygote.forward(f -> sum(f.(cut(u), cut(v))), f)
    y_desired, back_desired = Zygote.forward(f -> sum(f.(u, v)), f)
    @test y_actual == y_desired
    @test back_actual(1) == back_desired(1)

    y_partialcut, back_partialcut = Zygote.forward(f) do f
        @set! f.b = cut(f.b)
        sum(f.(cut(u), cut(v)))
    end
    @test y_partialcut == y_desired
    @test back_partialcut(1) == (
        (
            a = back_desired(1)[1].a,
            b = nothing,
        ),
    )

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

@testset "AddCall{<:Poly3, <:Poly3}" begin
    f = AddCall(Poly3(rand(4)...), Poly3(rand(4)...))
    x = rand(5)

    y_actual, back_actual = Zygote.forward(f.f.c2) do c
        g = cut(@set f.f.c2 = uncut(c))
        # g = Zygote.@showgrad g
        sum(g.(x))
    end
    y_desired, back_desired = Zygote.forward(f.f.c2) do c
        g = @set f.f.c2 = c
        # g = Zygote.@showgrad g
        sum(g.(x))
    end
    @test y_actual == y_desired
    @test back_actual(1) == back_desired(1)
end

@testset "ArgumentError" begin
    f = AddCall(_ -> 0, _ -> 1)

    err = nothing
    try
        Zygote.forward(x -> f.(x), Ref([0.0]))
    catch err
    end
    @test err isa ArgumentError
    @test occursin("Use `cut`", sprint(showerror, err))

    y, back = Zygote.forward(x -> cut(f).(cut(x)), Ref([0.0]))
    @test y == 1
    @test back(1) === (nothing,)
end

end  # module
