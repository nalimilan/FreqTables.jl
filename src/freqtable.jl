import Base.ht_keyindex

# Cf. https://github.com/JuliaStats/StatsBase.jl/issues/135
struct UnitWeights <: AbstractVector{Int} end
Base.getindex(w::UnitWeights, ::Integer...) = 1
Base.getindex(w::UnitWeights, ::AbstractVector) = w

# About the type inference limitation which prompts this workaround, see
# https://github.com/JuliaLang/julia/issues/10880
Base.@pure eltypes(T) = Tuple{map(eltype, T.parameters)...}
Base.@pure vectypes(T) = Tuple{map(U -> Vector{U}, T.parameters)...}

# Internal function needed for now so that n is inferred
function _freqtable(x::Tuple,
                    skipmissing::Bool = false,
                    weights::AbstractVector{<:Real} = UnitWeights(),
                    subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing)
    n = length(x)
    n == 0 && throw(ArgumentError("at least one argument must be provided"))

    if !isa(subset, Nothing)
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
        filter!(p -> !any(ismissing, p[1]), d)
    end

    keyvec = collect(keys(d))

    dimnames = Vector{Vector}(undef, n)
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
        na[Name.(k)...] = v
    end

    na
end

freqtable(x::AbstractVector...;
          skipmissing::Bool = false,
          weights::AbstractVector{<:Real} = UnitWeights(),
          subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing) =
    _freqtable(x, skipmissing, weights, subset)

# Internal function needed for now so that n is inferred
function _freqtable(x::NTuple{n, AbstractCategoricalVector}, skipmissing::Bool = false,
                    weights::AbstractVector{<:Real} = UnitWeights(),
                    subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing) where n
    n == 0 && throw(ArgumentError("at least one argument must be provided"))

    if !isa(subset, Nothing)
        x = map(y -> y[subset], x)
        weights = weights[subset]
    end

    len = map(length, x)
    miss = map(v -> eltype(v) >: Missing, x)
    lev = map(x) do v
        eltype(v) >: Missing && !skipmissing ? [levels(v); missing] : allowmissing(levels(v))
    end
    dims = map(length, lev)
    # First entry is for missing values (only correct and used if present)
    ord = map((v, d) -> Int[d; CategoricalArrays.order(v.pool)], x, dims)

	for i in 1:n
	    if len[1] != len[i]
	        error(string("arguments are not of the same length: ", tuple(len...)))
	    end
	end

    if !isa(weights, UnitWeights) && length(weights) != len[1]
        error("'weights' (length $(length(weights))) must be of the same length as vectors (length $(len[1]))")
    end

    sizes = cumprod([dims...])
    a = zeros(eltype(weights), dims)
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
            a[el] += weights[i]
        end
    end

    NamedArray(a, lev, ntuple(i -> "Dim$i", n))
end

freqtable(x::AbstractCategoricalVector...; skipmissing::Bool = false,
          weights::AbstractVector{<:Real} = UnitWeights(),
          subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing) =
    _freqtable(x, skipmissing, weights, subset)

function freqtable(d, x::Symbol...; args...)
    Tables.istable(d) || throw(ArgumentError("data must be a table"))
    cols = Tables.columns(d)
    a = freqtable((getproperty(cols, y) for y in x)...; args...)
    setdimnames!(a, x)
    a
end

"""
    prop(tbl::AbstractArray{<:Number}, [margin::Integer...])

Create table of proportions from a table `tbl` with margins generated for
dimensions specified by `margin`.
If `margin` is omitted proportions over the whole `tbl` are computed.

In particular when `margin` is `1` row proportions,
and when `margin` is `2` column proportions are calculated.

`prop` does not check if `tbl` contains non-negative values.
Calculating `sum` over the result of `prop` over dimensions that are complement of `margin`
produces `AbstractArray` containing only `1.0`, see last example below.

**Examples**

```jldoctest
julia> prop([1 2; 3 4])
2×2 Array{Float64,2}:
 0.1  0.2
 0.3  0.4

julia> prop([1 2; 3 4], 1)
2×2 Array{Float64,2}:
 0.333333  0.666667
 0.428571  0.571429

julia> prop([1 2; 3 4], 2)
2×2 Array{Float64,2}:
 0.25  0.333333
 0.75  0.666667

julia> prop([1 2; 3 4], 1, 2)
2×2 Array{Float64,2}:
 1.0  1.0
 1.0  1.0

julia> pt = prop(reshape(1:12, (2, 2, 3)), 3)
2×2×3 Array{Float64,3}:
[:, :, 1] =
 0.1  0.3
 0.2  0.4

[:, :, 2] =
 0.192308  0.269231
 0.230769  0.307692

[:, :, 3] =
 0.214286  0.261905
 0.238095  0.285714

julia> sum(pt, (1, 2))
1×1×3 Array{Float64,3}:
[:, :, 1] =
 1.0

[:, :, 2] =
 1.0

[:, :, 3] =
 1.0

```
"""
prop(tbl::AbstractArray{<:Number}) = tbl / sum(tbl)

function prop(tbl::AbstractArray{<:Number,N}, margin::Integer...) where N
    lo, hi = extrema(margin)
    (lo < 1 || hi > N) && throw(ArgumentError("margin must be a valid dimension"))
    tbl ./ sum(tbl, dims=tuple(setdiff(1:N, margin)...)::NTuple{N-length(margin),Int})
end

prop(tbl::NamedArray{<:Number}, margin::Integer...) =
    NamedArray(prop(convert(Array, tbl), margin...), tbl.dicts, tbl.dimnames)
