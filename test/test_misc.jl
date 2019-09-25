module TestMisc

using ChainCutters: unwrap_rec
using Setfield
using Test

@test unwrap_rec(@lens _.a[$1]) === @lens _.a[$1]

end  # module
