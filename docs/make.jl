using DocumenterVitepress
using Documenter
using OmniTools

makedocs(;
    sitename = "OmniTools.jl",
    authors = "OmniTools.jl Contributors",
    clean = true,
    format = DocumenterVitepress.MarkdownVitepress(
        repo = "github.com/LandEcosystems/OmniTools.jl",
    ),
    remotes = nothing,
    draft = false,
    warnonly = true,
    source = "src",
    build = "build",
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/LandEcosystems/OmniTools.jl",
    target = joinpath(@__DIR__, "build"),
    branch = "gh-pages",
    devbranch = "main",
    push_preview = true
)
