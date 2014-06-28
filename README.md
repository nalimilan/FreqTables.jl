# Tables

[![Build Status](https://travis-ci.org/nalimilan/Tables.jl.svg?branch=master)](https://travis-ci.org/nalimilan/Tables.jl)

Installation
------------

    julia> Pkg.clone("git://github.com/nalimilan/Tables.jl.git")

Usage
-----

```jlcon
julia> using Tables
julia> x = repeat(["a", "b", "c", "d"], outer=[100]);
julia> y = repeat(["A", "B", "C", "D"], inner=[10], outer=[10]);
julia> show(freqtable(x))
4-element NamedArray{Int64,1}
a 100
b 100
c 100
d 100
julia> show(freqtable(x, y))
4x4 NamedArray{Int64,2}
Dim1 \ Dim2 A  B  C  D 
a           30 20 30 20
b           30 20 30 20
c           20 30 20 30
d           20 30 20 30

julia> show(freqtable(x, y, subset=1:20))
4x2 NamedArray{Int64,2}
Dim1 \ Dim2 A B
a           3 2
b           3 2
c           2 3
d           2 3

julia> show(freqtable(x, y, subset=1:20, weights=repeat([1, .5], outer=[10])))
4x2 NamedArray{Float64,2}
Dim1 \ Dim2 A   B  
a           3.0 2.0
b           1.5 1.0
c           2.0 3.0
d           1.0 1.5
```
