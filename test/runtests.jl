module TestChainCutters
using Test
using Zygote

if lowercase(get(ENV, "CI", "false")) == "true" && !isdefined(Zygote, :pullback)
    @info "Testing with Zygote 0.3 in CI. Monkey patching it for test..."
    @eval Zygote pullback = forward
end

@testset "$file" for file in sort([file for file in readdir(@__DIR__) if
                                   match(r"^test_.*\.jl$", file) !== nothing])
    include(file)
end

using ChainCutters
using Documenter: doctest
doctest(ChainCutters)

end  # module
