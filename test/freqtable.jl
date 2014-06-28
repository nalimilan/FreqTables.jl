using Tables
using Base.Test

x = repeat(["a", "b", "c", "d"], outer=[100]);
y = repeat(["A", "B", "C", "D"], inner=[10], outer=[10]);

@test freqtable(x).array == [100, 100, 100, 100]
@test freqtable(y).array == [100, 100, 100, 100]
@test freqtable(x, y).array == [30 20 30 20;
                                30 20 30 20;
                                20 30 20 30;
                                20 30 20 30]


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
