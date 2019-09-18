using Documenter, ChainCutters

makedocs(;
    modules=[ChainCutters],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tkf/ChainCutters.jl/blob/{commit}{path}#L{line}",
    sitename="ChainCutters.jl",
    authors="Takafumi Arakaki <aka.tkf@gmail.com>",
    assets=String[],
)

deploydocs(;
    repo="github.com/tkf/ChainCutters.jl",
)
