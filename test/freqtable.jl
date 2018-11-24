using FreqTables
using Test

x = repeat(["a", "b", "c", "d"], outer=[100]);
# Values not in order to test discrepancy between index and levels with CategoricalArray
y = repeat(["D", "C", "A", "B"], inner=[10], outer=[10]);

tab = @inferred freqtable(x)
@test tab == [100, 100, 100, 100]
@test names(tab) == [["a", "b", "c", "d"]]
@test @inferred prop(tab) == [0.25, 0.25, 0.25, 0.25]
tab = @inferred freqtable(y)
@test tab == [100, 100, 100, 100]
@test names(tab) == [["A", "B", "C", "D"]]
tab = @inferred freqtable(x, y)
@test tab == [30 20 20 30;
              30 20 20 30;
              20 30 30 20;
              20 30 30 20]
@test names(tab) == [["a", "b", "c", "d"], ["A", "B", "C", "D"]]

pt = @inferred prop(tab)
@test pt == [0.075  0.05  0.05 0.075;
             0.075  0.05  0.05 0.075;
              0.05 0.075 0.075  0.05;
              0.05 0.075 0.075  0.05]
pt = @inferred prop(tab, 2)
@test pt == [0.3 0.2 0.2 0.3;
             0.3 0.2 0.2 0.3;
             0.2 0.3 0.3 0.2;
             0.2 0.3 0.3 0.2]
pt = @inferred prop(tab, 1)
@test pt == [0.3 0.2 0.2 0.3;
             0.3 0.2 0.2 0.3;
             0.2 0.3 0.3 0.2;
             0.2 0.3 0.3 0.2]
pt = @inferred prop(tab, 1, 2)
@test pt == [1.0 1.0 1.0 1.0;
             1.0 1.0 1.0 1.0;
             1.0 1.0 1.0 1.0;
             1.0 1.0 1.0 1.0]

tbl = @inferred prop(rand(5, 5, 5, 5), 1, 2)
sumtbl = sum(tbl, dims=(3,4))
@test all(x -> x ≈ 1.0, sumtbl)

@test_throws MethodError prop()
@test_throws MethodError prop(("a","b"))
@test_throws MethodError prop((1, 2))
@test_throws MethodError prop([1,2,3], "a")
@test_throws ArgumentError prop([1,2,3], 2)
@test_throws ArgumentError prop([1,2,3], 0)

tab = @inferred freqtable(x, y,
                          subset=1:20,
                          weights=repeat([1, .5], outer=[10]))
@test tab == [2.0 3.0
              1.0 1.5
              3.0 2.0
              1.5 1.0]
@test names(tab) == [["a", "b", "c", "d"], ["C", "D"]]
pt = @inferred prop(tab)
@test pt == [4 6; 2 3; 6 4; 3 2] / 30.0
pt = @inferred prop(tab, 2)
@test pt == [8  12; 4   6; 12  8; 6   4] / 30.0
pt = @inferred prop(tab, 1)
@test pt == [6 9; 6 9; 9 6; 9 6] / 15.0
pt = @inferred prop(tab, 1, 2)
@test pt == [1.0 1.0; 1.0 1.0; 1.0 1.0; 1.0 1.0]

using CategoricalArrays
cx = CategoricalArray(x)
cy = CategoricalArray(y)

tab = @inferred freqtable(cx)
@test tab == [100, 100, 100, 100]
@test names(tab) == [["a", "b", "c", "d"]]
tab = @inferred freqtable(cy)
@test tab == [100, 100, 100, 100]
@test names(tab) == [["A", "B", "C", "D"]]
tab = @inferred freqtable(cx, cy)
@test tab == [30 20 20 30;
              30 20 20 30;
              20 30 30 20;
              20 30 30 20]
@test names(tab) == [["a", "b", "c", "d"], ["A", "B", "C", "D"]]

tab = @inferred freqtable(cx, cy,
                          subset=1:20,
                          weights=repeat([1, .5], outer=[10]))
@test tab == [0.0 0.0 2.0 3.0
              0.0 0.0 1.0 1.5
              0.0 0.0 3.0 2.0
              0.0 0.0 1.5 1.0]
@test names(tab) == [["a", "b", "c", "d"], ["A", "B", "C", "D"]]


const ≅ = isequal
mx = Array{Union{String, Missing}}(x)
my = Array{Union{String, Missing}}(y)
mx[1] = missing
my[[1, 10, 20, 400]] .= missing

mcx = categorical(mx)
mcy = categorical(my)

tab = @inferred freqtable(mx)
tabc = @inferred freqtable(mcx)
@test tab == tabc == [99, 100, 100, 100, 1]
@test names(tab) ≅ names(tabc) ≅ [["a", "b", "c", "d", missing]]
tab = @inferred freqtable(my)
tabc = @inferred freqtable(mcy)
@test tab == tabc == [100, 99, 99, 98, 4]
@test names(tab) ≅ names(tabc) ≅ [["A", "B", "C", "D", missing]]
tab = @inferred freqtable(mx, my)
tabc = @inferred freqtable(mcx, mcy)
@test tab == tabc == [30 20 20 29 0;
                      30 20 20 29 1;
                      20 30 30 20 0;
                      20 29 29 20 2;
                      0   0  0  0 1]
@test names(tab) ≅ names(tabc) ≅ [["a", "b", "c", "d", missing],
                                  ["A", "B", "C", "D", missing]]


tab = @inferred freqtable(mx, skipmissing=true)
tabc = @inferred freqtable(mcx, skipmissing=true)
@test tab == tabc == [99, 100, 100, 100]
@test names(tab) ≅ names(tabc) ≅ [["a", "b", "c", "d"]]
tab = @inferred freqtable(my, skipmissing=true)
tabc = @inferred freqtable(mcy, skipmissing=true)
@test names(tab) ≅ names(tabc) ≅ [["A", "B", "C", "D"]]
@test tab == tabc == [100, 99, 99, 98]
tab = @inferred freqtable(mx, my, skipmissing=true)
tabc = @inferred freqtable(mcx, mcy, skipmissing=true)
@test tab == tabc == [30 20 20 29;
                      30 20 20 29;
                      20 30 30 20;
                      20 29 29 20]


using DataFrames, CSV

for docat in [false, true]
    iris = CSV.read(joinpath(dirname(pathof(DataFrames)), "../test/data/iris.csv"),
                    DataFrame,
                    categorical=docat, allowmissing=:none);
    if docat
        iris[:LongSepal] = categorical(iris[:SepalLength] .> 5.0)
    else
        iris[:LongSepal] = iris[:SepalLength] .> 5.0
    end
    tab = freqtable(iris, :Species, :LongSepal)
    @test tab == [28 22
                   3 47
                   1 49]
    @test names(tab) == [["setosa", "versicolor", "virginica"], [false, true]]
    tab = freqtable(iris, :Species, :LongSepal, subset=iris[:PetalLength] .< 4.0)
    @test tab[1:2, :] == [28 22
                           3  8]
    @test names(tab[1:2, :]) == [["setosa", "versicolor"], [false, true]]
    tab = freqtable(iris, :Species, :LongSepal, subset=iris[:PetalLength] .< 4.0)
    @test tab[1:2, :] == [28 22
                           3  8]
    @test names(tab[1:2, :]) == [["setosa", "versicolor"], [false, true]]

    iris_nt = (Species = iris[:Species], LongSepal = iris[:LongSepal])
    @test freqtable(iris, :Species, :LongSepal) == freqtable(iris_nt, :Species, :LongSepal)

    @test_throws ArgumentError freqtable(iris)
    @test_throws ArgumentError freqtable(nothing, :Species, :LongSepal)
end

# Issue #5
@test @inferred freqtable([Set(1), Set(2)]) == [1, 1]
@test @inferred freqtable([Set(1), Set(2)], [Set(1), Set(2)]) == [1 0; 0 1]

@test_throws ArgumentError freqtable()
@test_throws ArgumentError freqtable(DataFrame())

# Integer dimension
using NamedArrays

df = DataFrame(A = 101:103, B = ["x","y","y"]);
intft = freqtable(df, :A, :B)
@test names(intft) == [[101,102,103],["x","y"]]
@test intft == [1 0;
                0 1;
                0 1]

@test_throws BoundsError intft[101,"x"]
@test intft[Name(101),"x"] == 1
