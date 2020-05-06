module FreqTables
    using CategoricalArrays
    using Tables
    using NamedArrays
    using Missings

    include("freqtable.jl")

    export freqtable, proptable, prop, Name
end # module
