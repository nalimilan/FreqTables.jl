module FreqTables
    using Statistics
    using CategoricalArrays
    using Tables
    using NamedArrays
    using Missings

    include("freqtable.jl")
    include("pairwise.jl")

    export freqtable, proptable, prop, Name
end # module
