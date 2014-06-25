import Base.ht_keyindex

function freqtable(x::AbstractVector...;
                   subset::Union(Nothing, AbstractVector{Int}, AbstractVector{Bool}, BitVector) = nothing,
                   weights::Union(Nothing, AbstractVector{Number}) = nothing)
    n = length(x)
    l = map(length, x)
    vtypes = map(eltype, x)

    for i in 1:n
        if l[1] != l[i]
            error("arguments are not of the same length: $l")
        end
    end

    if (isa(subset, AbstractVector{Bool}) || isa(subset, BitVector)) && length(subset) != l[1]
        error("'subset' (length $(length(subset))) must be of the same length as vectors (length $(l[1])) when it is boolean")
    end

    if weights != nothing && length(weights) != l[1]
        error("'weights' (length $(length(weights))) must be of the same length as vectors (length $(l[1]))")
    end

    if weights == nothing
        d = Dict{vtypes, Int}()
    else
        d = Dict{vtypes, eltype(weights)}()
    end

    if isa(subset, AbstractVector{Bool}) || isa(subset, BitVector)
        for i in 1:l[1]
            subset[i] || continue

            el = ntuple(n, j -> x[j][i])
            index = ht_keyindex(d, el)

            if weights == nothing
                if index > 0
                    d.vals[index] += 1
                else
                    d[el] = 1
                end
            else
                if index > 0
                    d.vals[index] += weights[i]
                else
                    d[el] = weights[i]
                end
            end
        end
    else
        if subset == nothing
            subset = 1:l[1]
        end

        for i in subset
            @inbounds el = ntuple(n, j -> x[j][i])
            index = ht_keyindex(d, el)

            if weights == nothing
                if index > 0
                    d.vals[index] += 1
                else
                    d[el] = 1
                end
            else
                @inbounds w = weights[i]

                if index > 0
                    d.vals[index] += w
                else
                    d[el] = w
                end
            end
        end
    end

    k = collect(keys(d))

    dimnames = cell(n)
    for i in 1:n
        s = Set{vtypes[i]}()
        for j in 1:length(k)
            push!(s, k[j][i])
        end
        dimnames[i] = sort!(unique(s))
    end

    a = zeros(Int, ntuple(n, i -> length(dimnames[i])))
    na = NamedArray(a, ntuple(n, i -> dimnames[i]), ntuple(n, i -> "Dim$i"))

    for (k, v) in d
        na[k...] = v
    end

    na
end

function freqtable2(x::AbstractVector...;
                    subset::Union(Nothing, AbstractVector{Int}, AbstractVector{Bool}, BitVector) = nothing,
                    weights::Union(Nothing, AbstractVector{Number}) = nothing)
    n = length(x)
    l = map(length, x)
    vtypes = map(eltype, x)

    for i in 1:n
        if l[1] != l[i]
            error("arguments are not of the same length: $l")
        end
    end

    if (isa(subset, AbstractVector{Bool}) || isa(subset, BitVector)) && length(subset) != l[1]
        error("'subset' (length $(length(subset))) must be of the same length as vectors (length $(l[1])) when it is boolean")
    end

    if weights != nothing && length(weights) != l[1]
        error("'weights' (length $(length(weights))) must be of the same length as vectors (length $(l[1]))")
    end

    d = [Array(t, 0) for t in vtypes]

    if weights == nothing
        counts = Array(Int, 0)
    else
        counts = Array(eltype(weights), 0)
    end

    a = Array(Int, ntuple(n, i -> 0))
    el = cell(n)

    if isa(subset, AbstractVector{Bool}) || isa(subset, BitVector)
        for i in 1:l[1]
            subset[i] || continue

            for j in 1:n
                @inbounds pos = findfirst(d[j], x[j][i])

                if pos == 0
                    @inbounds push!(d[j], x[j][i])
                    a = cat(j, a, zeros(Int, ntuple(n, k -> k == j ? 1 : size(a, k))))
                    @inbounds pos = length(d[j])
                end

                @inbounds el[j] = pos
            end

            @inbounds a[el...] += 1
        end
    else
        if subset == nothing
            subset = 1:l[1]
        end

        for i in subset
            for j in 1:n
                @inbounds dj = d[j]
                @inbounds xji = x[j][i]

                pos = findfirst(dj, xji)

                if pos == 0
                    push!(dj, xji)
                    a = cat(j, a, zeros(Int, ntuple(n, k -> k == j ? 1 : size(a, k))))
                    pos = length(dj)
                end

                @inbounds el[j] = pos
            end

            @inbounds a[el...] += 1
        end
    end

    NamedArray(a, ntuple(n, i -> d[i]), ntuple(n, i -> "Dim$i"))
end

function freqtable(x::PooledDataVector...; usena::Bool = false)
	n = length(x)
	len = [length(y) for y in x]

	for i in 1:n
	    if len[1] != len[i]
	        error(string("arguments are not of the same length: ", tuple(len...)))
	    end
	end

	lev = [levels(y) for y in x]

	if usena
        dims = ntuple(n, i -> length(lev[i]) + 1)
        nalev = Int[dim + 1 for dim in dims]
	    sizes = cumprod(nalev)
	    a = zeros(Int, dims)

	    for i in 1:len[1]
	        el = int(x[1].refs[i])::Int

	        for j in 2:n
	            val = int(x[j].refs[i])::Int

	            if val == zero(val)
	                val = nalev[j]
	            end

	            el += int((val - 1) * sizes[j - 1])::Int
	        end

	        @inbounds a[el] += 1
	    end

	    NamedArray(a, ntuple(n, i -> [lev[i], "NA"]), ntuple(n, i -> "Dim$i"))
	else
        dims = ntuple(n, i -> length(lev[i]))
	    sizes = cumprod([dims...])
	    a = zeros(Int, dims)

	    for i in 1:len[1]
	        pos = (x[1].refs[i] != zero(Uint))
	        el = int(x[1].refs[i])::Int

	        for j in 2:n
	            val = x[j].refs[i]

	            if val == zero(val)
	                pos = false
	                break
	            end

	            el += int((val - 1) * sizes[j - 1])::Int
	        end

	        if pos
	            @inbounds a[el] += 1
	        end
	    end

	    NamedArray(a, ntuple(n, i -> lev[i]), ntuple(n, i -> "Dim$i"))
	end
end
