module FreqTables
    using CategoricalArrays
    using Tables
    using NamedArrays

    include("freqtable.jl")

    export freqtable, proptable, prop, Name
end # module
