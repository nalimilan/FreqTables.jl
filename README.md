# FreqTables

[![Build Status](https://travis-ci.org/nalimilan/FreqTables.jl.svg?branch=master)](https://travis-ci.org/nalimilan/FreqTables.jl)

Installation
------------

```julia
julia> Pkg.clone("git://github.com/nalimilan/FreqTables.jl.git")
```

Usage
-----

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
