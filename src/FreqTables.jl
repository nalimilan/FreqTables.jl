module FreqTables
    using CategoricalArrays
    using DataFrames
    using NamedArrays

    include("freqtable.jl")

    export freqtable, proptable
end # module
