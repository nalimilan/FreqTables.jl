function _pairwise!(::Val{:none}, res::AbstractMatrix, f, x, y, symmetric::Bool)
    m, n = size(res)
    for j in 1:n, i in 1:m
        symmetric && i > j && continue
        res[i, j] = f(x[i], y[j])
    end
    if symmetric
        for j in 1:n, i in (j+1):m
            res[i, j] = res[j, i]
        end
    end
    return res
end

function _pairwise!(::Val{:pairwise}, res::AbstractMatrix, f, x, y, symmetric::Bool)
    m, n = size(res)
    for j in 1:n
        ynminds = .!ismissing.(y[j])
        for i in 1:m
            symmetric && i > j && continue

            if x[i] === y[i]
                xnm = ynm = view(y[j], ynminds)
            else
                nminds = .!ismissing.(x[i]) .& ynminds
                xnm = view(x[i], nminds)
                ynm = view(y[j], nminds)
            end
            res[i, j] = f(xnm, ynm)
        end
    end
    if symmetric
        for j in 1:n, i in (j+1):m
            res[i, j] = res[j, i]
        end
    end
    return res
end

function _pairwise!(::Val{:listwise}, res::AbstractMatrix, f, x, y, symmetric::Bool)
    m, n = size(res)
    nminds = .!ismissing.(x[1])
    for i in 2:m
        nminds .&= .!ismissing.(x[i])
    end
    if x !== y
        for j in 1:n
            nminds .&= .!ismissing.(y[j])
        end
    end

    # Computing integer indices once for all vectors is faster
    nminds′ = findall(nminds)
    # TODO: check whether wrapping views in a custom array type which asserts
    # that entries cannot be `missing` (similar to `skipmissing`)
    # could offer better performance
    return _pairwise!(Val(:none), res, f,
                      [view(xi, nminds′) for xi in x],
                      [view(yi, nminds′) for yi in y],
                      symmetric)
end

function _pairwise(::Val{skipmissing}, f, x, y, symmetric::Bool) where {skipmissing}
    inds = keys(first(x))
    for xi in x
        keys(xi) == inds ||
            throw(ArgumentError("All input vectors must have the same indices"))
    end
    for yi in y
        keys(yi) == inds ||
            throw(ArgumentError("All input vectors must have the same indices"))
    end
    x′ = collect(x)
    y′ = collect(y)
    m = length(x)
    n = length(y)

    T = Core.Compiler.return_type(f, Tuple{eltype(x′), eltype(y′)})
    Tsm = Core.Compiler.return_type((x, y) -> f(disallowmissing(x), disallowmissing(y)),
                                     Tuple{eltype(x′), eltype(y′)})

    if skipmissing === :none
        res = Matrix{T}(undef, m, n)
        _pairwise!(Val(:none), res, f, x′, y′, symmetric)
    elseif skipmissing === :pairwise
        res = Matrix{Tsm}(undef, m, n)
        _pairwise!(Val(:pairwise), res, f, x′, y′, symmetric)
    elseif skipmissing === :listwise
        res = Matrix{Tsm}(undef, m, n)
        _pairwise!(Val(:listwise), res, f, x′, y′, symmetric)
    else
        throw(ArgumentError("skipmissing must be one of :none, :pairwise or :listwise"))
    end

    # identity.(res) lets broadcasting compute a concrete element type
    # TODO: using promote_type rather than typejoin (which broadcast uses) would make sense
    # Once identity.(res) is inferred automatically (JuliaLang/julia#30485),
    # the assertion can be removed
    @static if isdefined(Base.Broadcast, :promote_typejoin_union) # Julia >= 1.6
        U = Base.Broadcast.promote_typejoin_union(Union{T, Tsm})
        return (isconcretetype(eltype(res)) ? res : identity.(res))::Matrix{<:U}
    else
        return (isconcretetype(eltype(res)) ? res : identity.(res))
    end
end

function _pairwise_general(::Val{skipmissing}, f, x, y, symmetric::Bool) where {skipmissing}
    if symmetric && x !== y
        throw(ArgumentError("symmetric=true only makes sense passing a single set of variables"))
    end
    if Tables.istable(x) && Tables.istable(y)
        xcols = Tables.columns(x)
        ycols = Tables.columns(y)
        xcolnames = [String(nm) for nm in Tables.columnnames(xcols)]
        ycolnames = [String(nm) for nm in Tables.columnnames(ycols)]
        xcolsiter = (Tables.getcolumn(xcols, i) for i in 1:length(xcolnames))
        ycolsiter = (Tables.getcolumn(ycols, i) for i in 1:length(ycolnames))
        res = _pairwise(Val(skipmissing), f, xcolsiter, ycolsiter, symmetric)
        return NamedArray(res, (xcolnames, ycolnames))
    else
        x′ = collect(x)
        y′ = collect(y)
        if all(xi -> xi isa AbstractArray, x′) && all(yi -> yi isa AbstractArray, y′)
            return _pairwise(Val(skipmissing), f, x′, y′, symmetric)
        else
            throw(ArgumentError("x and y must be either iterators of AbstractArrays, " *
                                "or Tables.jl objects"))
        end
    end
end

"""
    pairwise(f, x[, y], symmetric::Bool=false, skipmissing::Symbol=:none)

Return a matrix holding the result of applying `f` to all possible pairs
of vectors in iterators `x` and `y`. Rows correspond to
vectors in `x` and columns to vectors in `y`. If `y` is omitted then a
square matrix crossing `x` with itself is returned.

Alternatively, if `x` and `y` are tables (in the Tables.jl sense), return
a `NamedMatrix` holding the result of applying `f` to all possible pairs
of columns in `x` and `y`.

# Keyword arguments
- `symmetric::Bool=false`: If `true`, `f` is only called to compute
  for the lower triangle of the matrix, and these values are copied
  to fill the upper triangle. Only possible when `y` is omitted.
  This is automatically set to `true` when `f` is `cor` or `cov`.
- `skipmissing::Symbol=:none`: If `:none` (the default), missing values
  in input vectors are passed to `f` without any modification.
  Use `:pairwise` to skip entries with a `missing` value in either
  of the two vectors passed to `f` for a given pair of vectors in `x` and `y`.
  Use `:listwise` to skip entries with a `missing` value in any of the
  vectors in `x` or `y`; note that this is likely to drop a large part of
  entries.
  If `f` is `cor`, diagonal values are set to 1 even in the presence
  of `missing`, `NaN`, `Inf` entries.
"""
pairwise(f, x, y=x; symmetric::Bool=false, skipmissing::Symbol=:none) =
    _pairwise_general(Val(skipmissing), f, x, y, symmetric)

# cor(x) ensures 1 of the right type is returned for diagonal cells
# (without actual computations)
pairwise(::typeof(cor), x, y; symmetric::Bool=false, skipmissing::Symbol=:none) =
    pairwise((x, y) -> x === y ? cor(x) : cor(x, y), x, y,
             symmetric=symmetric, skipmissing=skipmissing)

# cov(x) is faster than cov(x, x)
pairwise(::typeof(cov), x, y; symmetric::Bool=false, skipmissing::Symbol=:none) =
    pairwise((x, y) -> x === y ? cov(x) : cov(x, y), x, y,
             symmetric=symmetric, skipmissing=skipmissing)

pairwise(::typeof(cor), x; symmetric::Bool=true, skipmissing::Symbol=:none) =
    pairwise(cor, x, x, symmetric=symmetric, skipmissing=skipmissing)

pairwise(::typeof(cov), x; symmetric::Bool=true, skipmissing::Symbol=:none) =
    pairwise(cov, x, x, symmetric=symmetric, skipmissing=skipmissing)