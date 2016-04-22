import Base.ht_keyindex

# Cf. https://github.com/JuliaStats/StatsBase.jl/issues/135
immutable UnitWeights <: AbstractVector{Int}
end
Base.getindex(w::UnitWeights, ::Integer...) = 1
Base.getindex(w::UnitWeights, ::AbstractVector) = w

# @pure only exists in Julia 0.5
if isdefined(Base, Symbol("@pure"))
    import Base.@pure
else
    macro pure(x) esc(x) end
end

# About the type inference limitation which prompts this workaround, see
# https://github.com/JuliaLang/julia/issues/10880
@pure eltypes(T) = Tuple{map(eltype, T.parameters)...}

# Internal function needed for now so that n is inferred
function _freqtable{n,T<:Real}(x::NTuple{n},
                               weights::AbstractVector{T} = UnitWeights(),
                               subset::Union{Void, AbstractVector{Int}, AbstractVector{Bool}} = nothing)
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

    k = collect(keys(d))

    dimnames = cell(n)
    for i in 1:n
        s = Set{vtypes.parameters[i]}()
        for j in 1:length(k)
            push!(s, k[j][i])
        end

        dimnames[i] = unique(s)
        elty = eltype(dimnames[i])
        if method_exists(isless, (elty, elty))
            sort!(dimnames[i])
        end
    end

    a = zeros(eltype(weights), map(length, dimnames)...)
    na = NamedArray(a, tuple(dimnames...), ntuple(i -> "Dim$i", n))

    for (k, v) in d
        na[k...] = v
    end

    na
end

freqtable{T<:Real}(x::AbstractVector...;
                   weights::AbstractVector{T} = UnitWeights(),
                   subset::Union{Void, AbstractVector{Int}, AbstractVector{Bool}} = nothing) =
    _freqtable(x, weights, subset)

# Internal function needed for now so that n is inferred
function _freqtable{n}(x::NTuple{n, PooledDataVector}, usena = false)
	len = map(length, x)
	lev = map(levels, x)

	for i in 1:n
	    if len[1] != len[i]
	        error(string("arguments are not of the same length: ", tuple(len...)))
	    end
	end

	if usena
        dims = map(l -> length(l) + 1, lev)
	    sizes = cumprod([dims...])
	    a = zeros(Int, dims)

	    for i in 1:len[1]
	        el = Int(x[1].refs[i])

            if el == 0
	            el = dims[1]
	        end

	        for j in 2:n
	            val = Int(x[j].refs[i])

	            if val == zero(val)
	                val = dims[j]
	            end

	            el += Int((val - 1) * sizes[j - 1])
	        end

	        a[el] += 1
	    end

	    NamedArray(a, map(l -> [l; "NA"], lev), ntuple(i -> "Dim$i", n))
	else
        dims = map(length, lev)
	    sizes = cumprod([dims...])
	    a = zeros(Int, dims)

	    for i in 1:len[1]
	        pos = (x[1].refs[i] != zero(UInt))
	        el = Int(x[1].refs[i])

	        for j in 2:n
	            val = x[j].refs[i]

	            if val == zero(val)
	                pos = false
	                break
	            end

	            el += Int((val - 1) * sizes[j - 1])
	        end

	        if pos
	            @inbounds a[el] += 1
	        end
	    end

	    NamedArray(a, lev, ntuple(i -> "Dim$i", n))
	end
end

freqtable(x::PooledDataVector...; usena::Bool = false) = _freqtable(x, usena)

function freqtable(d::DataFrame, x::Symbol...; args...)
    a = freqtable([d[y] for y in x]...; args...)
    setdimnames!(a, x)
    a
end
