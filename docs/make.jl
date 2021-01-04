using Documenter
using MultiDimEquations

push!(LOAD_PATH,"../src/")
makedocs(sitename="MultiDimEquations.jl Documentation",
         pages = [
            "Index" => "index.md",
            #"MultiDimEquations module" => "MultiDimEquations.md",
         ],
         format = Documenter.HTML(prettyurls = false)
)
# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/sylvaticus/MultiDimEquations.jl.git",
    devbranch = "master"
)
