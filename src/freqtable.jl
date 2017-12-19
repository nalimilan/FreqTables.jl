import Base.ht_keyindex

# Cf. https://github.com/JuliaStats/StatsBase.jl/issues/135
immutable UnitWeights <: AbstractVector{Int}
end
Base.getindex(w::UnitWeights, ::Integer...) = 1
Base.getindex(w::UnitWeights, ::AbstractVector) = w

# About the type inference limitation which prompts this workaround, see
# https://github.com/JuliaLang/julia/issues/10880
Base.@pure eltypes(T) = Tuple{map(eltype, T.parameters)...}
Base.@pure vectypes(T) = Tuple{map(U -> Vector{U}, T.parameters)...}

# Internal function needed for now so that n is inferred
function _freqtable{T<:Real}(x::Tuple,
                             skipmissing::Bool = false,
                             weights::AbstractVector{T} = UnitWeights(),
                             subset::Union{Void, AbstractVector{Int}, AbstractVector{Bool}} = nothing)
    n = length(x)
    n == 0 && throw(ArgumentError("at least one argument must be provided"))

    if !isa(subset, Void)
        x = map(y -> y[subset], x)
        weights = weights[subset]
    end

    l = map(length, x)
    vtypes = eltypes(typeof(x))

    for i in 1:n
        if l[1] != l[i]
            error("arguments are not of the same length: $l")
        end
    end

    if !isa(weights, UnitWeights) && length(weights) != l[1]
        error("'weights' (length $(length(weights))) must be of the same length as vectors (length $(l[1]))")
    end

    d = Dict{vtypes, eltype(weights)}()

    for (i, el) in enumerate(zip(x...))
        index = ht_keyindex(d, el)

        if index > 0
            @inbounds d.vals[index] += weights[i]
        else
            @inbounds d[el] = weights[i]
        end
    end

    if skipmissing
        filter!((k, v) -> !any(ismissing, k), d)
    end

    keyvec = collect(keys(d))

    dimnames = Vector{Vector}(n)
    for i in 1:n
        s = Set{vtypes.parameters[i]}()
        for j in 1:length(keyvec)
            push!(s, keyvec[j][i])
        end

        # convert() is needed for Union{T, Missing}, which currently gives a Vector{Any}
        # which breaks inference of the return type
        dimnames[i] = convert(Vector{vtypes.parameters[i]}, unique(s))
        try
            sort!(dimnames[i])
        catch err
            err isa MethodError || rethrow(err)
        end
    end

    a = zeros(eltype(weights), map(length, dimnames)...)::Array{eltype(weights), n}
    na = NamedArray(a, tuple(dimnames...)::vectypes(vtypes), ntuple(i -> "Dim$i", n))

    for (k, v) in d
        na[k...] = v
    end

    na
end

freqtable{T<:Real}(x::AbstractVector...;
                   skipmissing::Bool = false,
                   weights::AbstractVector{T} = UnitWeights(),
                   subset::Union{Void, AbstractVector{Int}, AbstractVector{Bool}} = nothing) =
    _freqtable(x, skipmissing, weights, subset)

# Internal function needed for now so that n is inferred
function _freqtable{n}(x::NTuple{n, AbstractCategoricalVector}, skipmissing::Bool = false)
    len = map(length, x)
    lenn == 0 && throw(ArgumentError("at least one argument must be provided"))

    miss = map(v -> eltype(v) >: Missing, x)
    lev = map(v -> eltype(v) >: Missing && !skipmissing ? [levels(v); missing] : levels(v), x)
    dims = map(length, lev)
    # First entry is for missing values (only correct and used if present)
    ord = map((v, d) -> Int[d; CategoricalArrays.order(v.pool)], x, dims)

	for i in 1:n
	    if len[1] != len[i]
	        error(string("arguments are not of the same length: ", tuple(len...)))
	    end
	end

    sizes = cumprod([dims...])
    a = zeros(Int, dims)
    missingpossible = any(miss)

    @inbounds for i in 1:len[1]
        ref = x[1].refs[i]        
        el = ord[1][ref + 1]
        anymiss = missingpossible & (ref <= 0)

        for j in 2:n
            ref = x[j].refs[i]
            anymiss |= missingpossible & (ref <= 0)
            el += (ord[j][ref + 1] - 1) * sizes[j - 1]
        end

        if !(missingpossible && skipmissing && anymiss)
            a[el] += 1
        end
    end

    NamedArray(a, lev, ntuple(i -> "Dim$i", n))
end

freqtable(x::AbstractCategoricalVector...; skipmissing::Bool = false) = _freqtable(x, skipmissing)

function freqtable(d::AbstractDataFrame, x::Symbol...; args...)
    a = freqtable([d[y] for y in x]...; args...)
    setdimnames!(a, x)
    a
end
