# FreqTables

[![Build Status](https://travis-ci.org/nalimilan/FreqTables.jl.svg?branch=master)](https://travis-ci.org/nalimilan/FreqTables.jl)
[![Coverage Status](https://coveralls.io/repos/nalimilan/FreqTables.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/nalimilan/FreqTables.jl?branch=master)
[![FreqTables](http://pkg.julialang.org/badges/FreqTables_0.4.svg)](http://pkg.julialang.org/?pkg=FreqTables&ver=0.4)
[![FreqTables](http://pkg.julialang.org/badges/FreqTables_0.5.svg)](http://pkg.julialang.org/?pkg=FreqTables&ver=0.5)

This package allows computing one- or multi-way frequency tables (a.k.a. contingency or pivot tables) from
any type of vector or array. It includes support for [`PooledDataArray`s](https://github.com/JuliaStats/DataArrays.jl)
and [`DataFrame`s](https://github.com/JuliaStats/DataFrames.jl/), as well as for weighted counts.

Tables are represented as [`NamedArray`](https://github.com/davidavdav/NamedArrays.jl/) objects.

```julia
julia> using FreqTables
julia> x = repeat(["a", "b", "c", "d"], outer=[100]);
julia> y = repeat(["A", "B", "C", "D"], inner=[10], outer=[10]);
julia> freqtable(x)
4-element NamedArrays.NamedArray{Int64,1,Array{Int64,1},Tuple{Dict{ASCIIString,Int64}}}
a 100
b 100
c 100
d 100

julia> freqtable(x, y)
4x4 NamedArrays.NamedArray{Int64,2,Array{Int64,2},Tuple{Dict{ASCIIString,Int64},Dict{ASCIIString,Int64}}}
Dim1 \ Dim2 A  B  C  D 
a           30 20 30 20
b           30 20 30 20
c           20 30 20 30
d           20 30 20 30

julia> freqtable(x, y, subset=1:20)
4x2 NamedArrays.NamedArray{Int64,2,Array{Int64,2},Tuple{Dict{ASCIIString,Int64},Dict{ASCIIString,Int64}}}
Dim1 \ Dim2 A B
a           3 2
b           3 2
c           2 3
d           2 3

julia> freqtable(x, y, subset=1:20, weights=repeat([1, .5], outer=[10]))
4x2 NamedArrays.NamedArray{Float64,2,Array{Float64,2},Tuple{Dict{ASCIIString,Int64},Dict{ASCIIString,Int64}}}
Dim1 \ Dim2 A   B  
a           3.0 2.0
b           1.5 1.0
c           2.0 3.0
d           1.0 1.5
```

For convenience, when working with a data frame, one can also pass the `DataFrame` object and columns as symbols:
```julia
julia> using RDatasets

julia> iris = dataset("datasets", "iris");

julia> iris[:LongSepal] = iris[:SepalLength] .> 5.0;

julia> freqtable(iris, :Species, :LongSepal)
3x2 NamedArrays.NamedArray{Int64,2,Array{Int64,2},Tuple{Dict{ASCIIString,Int64},Dict{Bool,Int64}}}
Species \ LongSepal false true 
setosa              28    22   
versicolor          3     47   
virginica           1     49   

julia> freqtable(iris, :Species, :LongSepal, subset=iris[:PetalLength] .< 4.0)
2x2 NamedArrays.NamedArray{Int64,2,Array{Int64,2},Tuple{Dict{ASCIIString,Int64},Dict{Bool,Int64}}}
Species \ LongSepal false true 
setosa              28    22   
versicolor          3     8    
```

When working with a dataframe where all values are of the same type (e.g. unlabeled data, or a subset of a larger dataframe that also contains strings, Float64s, etc.), you can pass just the dataframe (or subset of the dataframe) of interest
```julia
julia> df = DataFrame(s1 = repeat(collect(1:3), inner=4), s2 = repeat(collect(1:3), outer=4), s3 = fill(1, 12))
12×3 DataFrames.DataFrame
│ Row │ s1 │ s2 │ s3 │
├─────┼────┼────┼────┤
│ 1   │ 1  │ 1  │ 1  │
│ 2   │ 1  │ 2  │ 1  │
│ 3   │ 1  │ 3  │ 1  │
│ 4   │ 1  │ 1  │ 1  │
│ 5   │ 2  │ 2  │ 1  │
│ 6   │ 2  │ 3  │ 1  │
│ 7   │ 2  │ 1  │ 1  │
│ 8   │ 2  │ 2  │ 1  │
│ 9   │ 3  │ 3  │ 1  │
│ 10  │ 3  │ 1  │ 1  │
│ 11  │ 3  │ 2  │ 1  │
│ 12  │ 3  │ 3  │ 1  │

julia> freqtable(df)
3×3 Named Array{Int64,2}
value ╲ column │ s1  s2  s3
───────────────┼───────────
1              │  4   4  12
2              │  4   4   0
3              │  4   4   0
```
