using FreqTables
using Base.Test

x = repeat(["a", "b", "c", "d"], outer=[100]);
# Values not in order to test discrepancy between index and levels with CategoricalArray
y = repeat(["D", "C", "A", "B"], inner=[10], outer=[10]);

tab = @inferred freqtable(x)
@test tab == [100, 100, 100, 100]
@test names(tab) == [["a", "b", "c", "d"]]
tab = @inferred freqtable(y)
@test tab == [100, 100, 100, 100]
@test names(tab) == [["A", "B", "C", "D"]]
tab = @inferred freqtable(x, y)
@test tab == [30 20 20 30;
              30 20 20 30;
              20 30 30 20;
              20 30 30 20]
@test names(tab) == [["a", "b", "c", "d"], ["A", "B", "C", "D"]]

tab =freqtable(x, y,
               subset=1:20,
               weights=repeat([1, .5], outer=[10]))
@test tab == [2.0 3.0
              1.0 1.5
              3.0 2.0
              1.5 1.0]
@test names(tab) == [["a", "b", "c", "d"], ["C", "D"]]


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


using Missings
const ≅ = isequal
mx = Array{Union{String, Missing}}(x)
my = Array{Union{String, Missing}}(y)
mx[1] = missing
my[[1, 10, 20, 400]] = missing

mcx = categorical(mx)
mcy = categorical(my)

tab = freqtable(mx)
tabc = freqtable(mcx)
@test tab == tabc == [99, 100, 100, 100, 1]
@test names(tab) ≅ names(tabc) ≅ [["a", "b", "c", "d", missing]]
tab = freqtable(my)
tabc = freqtable(mcy)
@test tab == tabc == [100, 99, 99, 98, 4]
@test names(tab) ≅ names(tabc) ≅ [["A", "B", "C", "D", missing]]
tab = freqtable(mx, my)
tabc = freqtable(mcx, mcy)
@test tab == tabc == [30 20 20 29 0;
                      30 20 20 29 1;
                      20 30 30 20 0;
                      20 29 29 20 2;
                      0   0  0  0 1]
@test names(tab) ≅ names(tabc) ≅ [["a", "b", "c", "d", missing],
                                  ["A", "B", "C", "D", missing]]


tab = freqtable(mx, skipmissing=true)
tabc = freqtable(mcx, skipmissing=true)
@test tab == tabc == [99, 100, 100, 100]
@test names(tab) ≅ names(tabc) ≅ [["a", "b", "c", "d"]]
tab = freqtable(my, skipmissing=true)
tabc = freqtable(mcy, skipmissing=true)
@test names(tab) ≅ names(tabc) ≅ [["A", "B", "C", "D"]]
@test tab == tabc == [100, 99, 99, 98]
tab = freqtable(mx, my, skipmissing=true)
tabc = freqtable(mcx, mcy, skipmissing=true)
@test tab == tabc == [30 20 20 29;
                      30 20 20 29;
                      20 30 30 20;
                      20 29 29 20]


using DataFrames, CSV
iris = CSV.read(joinpath(Pkg.dir("DataFrames"), "test/data/iris.csv"), categorical=false);
iris[:LongSepal] = iris[:SepalLength] .> 5.0
tab = freqtable(iris, :Species, :LongSepal)
@test tab == [28 22
               3 47
               1 49]
@test names(tab) == [["setosa", "versicolor", "virginica"], [false, true]]
tab = freqtable(iris, :Species, :LongSepal, subset=iris[:PetalLength] .< 4.0)
@test tab == [28 22
               3  8]
@test names(tab) == [["setosa", "versicolor"], [false, true]]

# Issue #5
@test freqtable([Set(1), Set(2)]) == [1, 1]
@test freqtable([Set(1), Set(2)], [Set(1), Set(2)]) == eye(2)
