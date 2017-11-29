# FreqTables

[![Build Status](https://travis-ci.org/nalimilan/FreqTables.jl.svg?branch=master)](https://travis-ci.org/nalimilan/FreqTables.jl)
[![Coverage Status](https://coveralls.io/repos/nalimilan/FreqTables.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/nalimilan/FreqTables.jl?branch=master)
[![FreqTables](http://pkg.julialang.org/badges/FreqTables_0.6.svg)](http://pkg.julialang.org/?pkg=FreqTables&ver=0.6)

This package allows computing one- or multi-way frequency tables (a.k.a. contingency or pivot tables) from
any type of vector or array. It includes support for [`CategoricalArray`](https://github.com/JuliaData/CategoricalArrays.jl)
and [`DataFrame`](https://github.com/JuliaData/DataFrames.jl), as well as for weighted counts.

Tables are represented as [`NamedArray`](https://github.com/davidavdav/NamedArrays.jl/) objects.

```julia
julia> using FreqTables

julia> x = repeat(["a", "b", "c", "d"], outer=[100]);

julia> y = repeat(["A", "B", "C", "D"], inner=[10], outer=[10]);

julia> freqtable(x)
4-element Named Array{Int64,1}
Dim1  │
──────┼────
a     │ 100
b     │ 100
c     │ 100
d     │ 100

julia> freqtable(x, y)
4×4 Named Array{Int64,2}
Dim1 ╲ Dim2 │  A   B   C   D
────────────┼───────────────
a           │ 30  20  30  20
b           │ 30  20  30  20
c           │ 20  30  20  30
d           │ 20  30  20  30

julia> freqtable(x, y, subset=1:20)
4×2 Named Array{Int64,2}
Dim1 ╲ Dim2 │ A  B
────────────┼─────
a           │ 3  2
b           │ 3  2
c           │ 2  3
d           │ 2  3

julia> freqtable(x, y, subset=1:20, weights=repeat([1, .5], outer=[10]))
4×2 Named Array{Float64,2}
Dim1 ╲ Dim2 │   A    B
────────────┼─────────
a           │ 3.0  2.0
b           │ 1.5  1.0
c           │ 2.0  3.0
d           │ 1.0  1.5
```

For convenience, when working with a data frame, one can also pass a `DataFrame` object and columns as symbols:
```julia
julia> using DataFrames, CSV

julia> iris = CSV.read(joinpath(Pkg.dir("DataFrames"), "test/data/iris.csv"));

julia> iris[:LongSepal] = iris[:SepalLength] .> 5.0;

julia> freqtable(iris, :Species, :LongSepal)
3×2 Named Array{Int64,2}
Species ╲ LongSepal │ false   true
────────────────────┼─────────────
setosa              │    28     22
versicolor          │     3     47
virginica           │     1     49

julia> freqtable(iris, :Species, :LongSepal, subset=iris[:PetalLength] .< 4.0)
2×2 Named Array{Int64,2}
Species ╲ LongSepal │ false   true
────────────────────┼─────────────
setosa              │    28     22
versicolor          │     3      8
```
