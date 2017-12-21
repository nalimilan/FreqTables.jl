module FreqTables
    using CategoricalArrays
    using DataFrames
    using NamedArrays

    include("freqtable.jl")

    export freqtable, prop
end # module
