module TestArithmetic

using ChainCutters: cut, uncut
using Test
using Zygote

@testset for op in (*, +, -)
    n = 5
    A = rand(n, n)
    B = rand(n, n)
    Δ = rand(n, n)

    y_plain, back_plain = Zygote.pullback(op, A, B)
    y_cut1, back_cut1 = Zygote.pullback((a, b) -> op(cut(a), b), A, B)
    y_cut2, back_cut2 = Zygote.pullback((a, b) -> op(a, cut(b)), A, B)
    diff_plain = back_plain(Δ)
    diff_cut1 = back_cut1(Δ)
    diff_cut2 = back_cut2(Δ)

    @test y_cut1 == y_plain
    @test y_cut2 == y_plain
    @test diff_cut1[1] == nothing
    @test diff_cut1[2] == diff_plain[2]
    @test diff_cut2[1] == diff_plain[1]
    @test diff_cut2[2] == nothing
end

end  # module
