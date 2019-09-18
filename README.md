# ChainCutters

[![Build Status](https://travis-ci.com/tkf/ChainCutters.jl.svg?branch=master)](https://travis-ci.com/tkf/ChainCutters.jl)
[![Codecov](https://codecov.io/gh/tkf/ChainCutters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tkf/ChainCutters.jl)
[![Coveralls](https://coveralls.io/repos/github/tkf/ChainCutters.jl/badge.svg?branch=master)](https://coveralls.io/github/tkf/ChainCutters.jl?branch=master)

## Treating arguments as constants

Use `ChainCutters.cut(x)` to treat `x` as a constant.  Only `*`, `+`
and `-` are supported.

```julia
julia> using ChainCutters: cut

julia> using LinearAlgebra, Zygote

julia> A = [
           1  9  1
           9  1  2
           5  3  5
       ];

julia> B = [
           7  9  1
           9  1  6
           5  3  5
       ];

julia> C, back = Zygote.forward(A, B) do A, B
           cut(A) * B
       end;

julia> C == A * B
true

julia> ∂A, ∂B = back(I(3));

julia> ∂A === nothing  # `A` is treated as a constant
true

julia> ∂B
3×3 Array{Int64,2}:
 1  9  5
 9  1  3
 1  2  5
```
