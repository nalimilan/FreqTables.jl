module FreqTables
    using DataArrays
    using DataFrames
    using NamedArrays

    include("freqtable.jl")

    export freqtable
    export colwisecounts
    export rowwisecounts
end # module
