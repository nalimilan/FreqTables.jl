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

"""
    freqtable(x::AbstractVector...;
              skipmissing::Bool = false, 
              weights::AbstractVector{<:Real} = UnitWeights(),
              subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing])
        
    freqtable(t, cols::Symbol...; 
              skipmissing::Bool = false, 
              weights::AbstractVector{<:Real} = UnitWeights(),
              subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing])

Create frequency table from vectors or table columns.         
        
`t` can be any type of table supported by the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.
        
**Examples**

```jldoctest
julia> freqtable([1, 2, 2, 3, 4, 3])
4-element Named Array{Int64,1}
Dim1  │ 
──────┼──
1     │ 1
2     │ 2
3     │ 2
4     │ 1

julia> df = DataFrame(x=[1, 2, 2, 2], y=[1, 2, 1, 2]);

julia> freqtable(df, :x, :y)
2×2 Named Array{Int64,2}
x ╲ y │ 1  2
──────┼─────
1     │ 1  0
2     │ 1  2
        
julia> freqtable(df, :x, :y, subset=df.x .> 1)
1×2 Named Array{Int64,2}
x ╲ y │ 1  2
──────┼─────
2     │ 1  2
        
```        
"""

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

function freqtable(t, cols::Symbol...; args...)
    Tables.istable(t) || throw(ArgumentError("data must be a table"))
    all_cols = Tables.columns(t)
    a = freqtable((getproperty(all_cols, y) for y in cols)...; args...)
    setdimnames!(a, cols)
    a
end

"""
    prop(tbl::AbstractArray{<:Number};
         margins = nothing)

Create table of proportions from a table `tbl` with margins generated for
dimensions specified by `margins`. 

`margins` must be `nothing` (the default), an `Integer`, or an iterable of `Integer`s.        

If `margins` is `nothing`, proportions over the whole `tbl` are computed.
In particular for a two-dimensional array, when `margins` is `1` row proportions are 
calculated, and when `margins` is `2` column proportions are calculated.
    
`prop` does not check if `tbl` contains non-negative values.

Calculating `sum` over the result of `prop` over dimensions that are complement of `margins`
produces `AbstractArray` containing only `1.0`, see last example below.

**Examples**

```jldoctest
julia> prop([1 2; 3 4])
2×2 Array{Float64,2}:
 0.1  0.2
 0.3  0.4

julia> prop([1 2; 3 4], margins=1)
2×2 Array{Float64,2}:
 0.333333  0.666667
 0.428571  0.571429

julia> prop([1 2; 3 4], margins=2)
2×2 Array{Float64,2}:
 0.25  0.333333
 0.75  0.666667

julia> prop([1 2; 3 4], margins=(1, 2))
2×2 Array{Float64,2}:
 1.0  1.0
 1.0  1.0

julia> pt = prop(reshape(1:12, (2, 2, 3)), margins=3)
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

julia> sum(pt, dims=(1, 2))
1×1×3 Array{Float64,3}:
[:, :, 1] =
 1.0

[:, :, 2] =
 1.0

[:, :, 3] =
 1.0

```
"""

function prop(tbl::AbstractArray{<:Number,N}; margins=nothing) where N
    if margins === nothing
        return tbl / sum(tbl)
    else            
        lo, hi = extrema(margins)
        (lo < 1 || hi > N) && throw(ArgumentError("margins must be a valid dimension"))
        return tbl ./ sum(tbl, dims=tuple(setdiff(1:N, margins)...)::NTuple{N-length(margins),Int})
    end
end

prop(tbl::NamedArray{<:Number}; margins=nothing) =
    NamedArray(prop(convert(Array, tbl); margins=margins), tbl.dicts, tbl.dimnames)

"""
    proptable(x::AbstractVector...; 
              margins = nothing,
              skipmissing::Bool = false, 
              weights::AbstractVector{<:Real} = UnitWeights(),
              subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing])
        
    proptable(t, cols::Symbol...; 
              margins = nothing,
              skipmissing::Bool = false, 
              weights::AbstractVector{<:Real} = UnitWeights(),
              subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing])

Create a frequency table of proportions from vectors or table columns with margins generated 
for dimensions specified by `margins`. `proptable` is equivalent to calling 
`prop(freqtable(...), margins=margins)`.

`margins` must be `nothing` (the default), an `Integer`, or an iterable of `Integer`s.

If `margins` is `nothing`, proportions over the whole table are computed. When two vectors are
passed and `margins` is `1`, row proportions are calculated, and when `margins` is `2`
column proportions are calculated. More generally, the resulting array will have sums equal 
to one for all dimensions not specified in `margins`.

`t` can be any type of table supported by the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.
            
Calculating `sum` over the result of `proptable` over dimensions that are complement of `margins` produces `AbstractArray` containing only `1.0`. See last example below.
                        
**Examples**

```jldoctest
julia> proptable([1, 2, 2, 3, 4, 3])
4-element Named Array{Float64,1}
Dim1  │ 
──────┼─────────
1     │ 0.166667
2     │ 0.333333
3     │ 0.333333
4     │ 0.166667
            
julia> df = DataFrame(x=[1, 2, 2, 2, 1, 1], y=[1, 2, 1, 2, 2, 2], z=[1, 1, 1, 2, 2, 1]);

julia> proptable(df, :x, :y)
2×2 Named Array{Float64,2}
x ╲ y │        1         2
──────┼───────────────────
1     │ 0.166667  0.333333
2     │ 0.166667  0.333333

julia> proptable(df, :x, :y, subset=df.x .> 1)
1×2 Named Array{Float64,2}
x ╲ y │        1         2
──────┼───────────────────
2     │ 0.333333  0.666667

julia> proptable([1, 2, 2, 2], [1, 1, 1, 2], margins=1)
2×2 Named Array{Float64,2}
Dim1 ╲ Dim2 │        1         2
────────────┼───────────────────
1           │      1.0       0.0
2           │ 0.666667  0.333333

julia> proptable([1, 2, 2, 2], [1, 1, 1, 2], margins=2)
2×2 Named Array{Float64,2}
Dim1 ╲ Dim2 │        1         2
────────────┼───────────────────
1           │ 0.333333       0.0
2           │ 0.666667       1.0

julia> proptable([1, 2, 2, 2], [1, 1, 1, 2], margins=(1,2))
2×2 Named Array{Float64,2}
Dim1 ╲ Dim2 │   1    2
────────────┼─────────
1           │ 1.0  NaN
2           │ 1.0  1.0
            
julia> proptable(df.x, df.y, df.z)
2×2×2 Named Array{Float64,3}

[:, :, Dim3=1] =
Dim1 ╲ Dim2 │        1         2
────────────┼───────────────────
1           │ 0.166667  0.166667
2           │ 0.166667  0.166667

[:, :, Dim3=2] =
Dim1 ╲ Dim2 │        1         2
────────────┼───────────────────
1           │      0.0  0.166667
2           │      0.0  0.166667

julia> pt = proptable(df.x, df.y, df.z, margins=(1,2))
2×2×2 Named Array{Float64,3}

[:, :, Dim3=1] =
Dim1 ╲ Dim2 │   1    2
────────────┼─────────
1           │ 1.0  0.5
2           │ 1.0  0.5

[:, :, Dim3=2] =
Dim1 ╲ Dim2 │   1    2
────────────┼─────────
1           │ 0.0  0.5
2           │ 0.0  0.5            
            
julia> sum(pt, dims=3)
2×2×1 Named Array{Float64,3}

[:, :, Dim3=sum(Dim3)] =
Dim1 ╲ Dim2 │   1    2
────────────┼─────────
1           │ 1.0  1.0
2           │ 1.0  1.0
            
``` 
"""
proptable(x::AbstractVector...;
          margins = nothing,
          skipmissing::Bool = false,
          weights::AbstractVector{<:Real} = UnitWeights(),
          subset::Union{Nothing, AbstractVector{Int}, AbstractVector{Bool}} = nothing) = 
    prop(freqtable(x..., 
                   skipmissing=skipmissing, weights=weights, subset=subset), margins=margins)
            
proptable(t, cols::Symbol...; margins=nothing, kwargs...) = 
    prop(freqtable(t, cols...; kwargs...), margins=margins)
