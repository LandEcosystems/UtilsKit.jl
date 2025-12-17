using Documenter
using UtilsKit

makedocs(
    modules = [UtilsKit],
    sitename = "UtilsKit.jl",
    format = Documenter.HTML(prettyurls = get(ENV, "CI", "") == "true"),
    pages = [
        "Home" => "index.md",
        "API" => [
            "Overview" => "api.md",
            "UtilsKit (flat)" => "api/UtilsKit.md",
            "ForArray" => "api/ForArray.md",
            "ForCollections" => "api/ForCollections.md",
            "ForDisplay" => "api/ForDisplay.md",
            "ForDocStrings" => "api/ForDocStrings.md",
            "ForLongTuples" => "api/ForLongTuples.md",
            "ForMethods" => "api/ForMethods.md",
            "ForNumber" => "api/ForNumber.md",
            "ForPkg" => "api/ForPkg.md",
            "ForString" => "api/ForString.md",
        ],
    ],
)

if get(ENV, "GITHUB_ACTIONS", "") == "true"
    deploydocs(
        repo = "github.com/LandEcosystems/UtilsKit.jl",
        devbranch = "main",
        push_preview = true,
    )
end
