using FreqTables
using Base.Test

x = repeat(["a", "b", "c", "d"], outer=[100]);
y = repeat(["A", "B", "C", "D"], inner=[10], outer=[10]);

@test freqtable(x).array == [100, 100, 100, 100]
@test freqtable(y).array == [100, 100, 100, 100]
@test freqtable(x, y).array == [30 20 30 20;
                                30 20 30 20;
                                20 30 20 30;
                                20 30 20 30]

@test freqtable(x, y,
                subset=1:20,
                weights=repeat([1, .5], outer=[10])).array == [3.0 2.0
                                                               1.5 1.0
                                                               2.0 3.0
                                                               1.0 1.5]


using DataArrays
xpda = PooledDataArray(x)
ypda = PooledDataArray(y)

@test freqtable(xpda).array == [100, 100, 100, 100]
@test freqtable(ypda).array == [100, 100, 100, 100]
@test freqtable(xpda, ypda).array == [30 20 30 20;
                                      30 20 30 20;
                                      20 30 20 30;
                                      20 30 20 30]

xpda[1] = NA
ypda[[1, 10, 20, 400]] = NA

@test freqtable(xpda).array == [99, 100, 100, 100]
@test freqtable(ypda).array == [98, 99, 100, 99]
@test freqtable(xpda, ypda).array == [29 20 30 20;
                                      29 20 30 20;
                                      20 30 20 30;
                                      20 29 20 29]

@test freqtable(xpda, usena=true).array == [99, 100, 100, 100, 1]
@test freqtable(ypda, usena=true).array == [98, 99, 100, 99, 4]
@test freqtable(xpda, ypda, usena=true).array == [29 20 30 20 0;
                                                  29 20 30 20 1;
                                                  20 30 20 30 0;
                                                  20 29 20 29 2;
                                                  0 0 0 0 1]


using RDatasets
iris = dataset("datasets", "iris")
iris[:LongSepal] = iris[:SepalLength] .> 5.0
@test freqtable(iris, :Species, :LongSepal).array == [28 22
                                                       3 47
                                                       1 49]
@test freqtable(iris, :Species, :LongSepal,
                subset=iris[:PetalLength] .< 4.0).array ==[28 22
                                                            3  8]

# Issue #5
@test freqtable([Set(1), Set(2)]).array == [1, 1]
@test freqtable([Set(1), Set(2)], [Set(1), Set(2)]).array == eye(2)
