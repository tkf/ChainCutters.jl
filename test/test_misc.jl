module TestMisc

using ChainCutters: unwrap_rec
using Setfield
using Test

@test unwrap_rec(@lens _.a[$1]) === @lens _.a[$1]
@test unwrap_rec(Val(1)) === Val(1)

end  # module
