using Test
using DataFrames, CSV
import MultiDimEquations:defVars, defLoadVars

cd(@__DIR__)
#include(Base.find_package("MultiDimEquations"))
#include("../src/MultiDimEquations.jl")

# NEW TEST
# Checking empty variable definition
(exp,consumption)   = defVars(["product","regions","years"],[String,String,Int64],n=2)
(exp2,consumption2) = defVars([3,2,5],n=2)
exp["banana","Canada",2010] = 2
@test exp["banana","Canada",2010] + 1 == 3
consumption2[2,1,5] = 2
@test consumption2[2,1,5] + 1 == 3




# TEST 1: Testing both defVars()and the @meq macro using a single IndexedTable
df = CSV.read(IOBuffer("""
reg prod var value
us banana production 10
us banana transfCoef    0.6
us banana trValues      2
us apples production    7
us apples transfCoef    0.7
us apples trValues      5
us juice production     missing
us juice transfCoef     missing
us juice trValues       missing
eu banana production    5
eu banana transfCoef    0.7
eu apples production    8
eu apples transfCoef    0.8
eu apples trValues 4
eu juice production missing
eu juice transfCoef missing
eu juice trValues missing
"""), DataFrame, delim=" ", ignorerepeated=true, copycols=true, missingstring="missing") # missing eu banana trValues      1
(production,transfCoef,trValues)     = defLoadVars(["production","transfCoef","trValues"], df,["reg","prod"], varNameCol="var", valueCol="value",sparse=true)
(production2,transfCoef2,trValues2)  = defLoadVars(["production","transfCoef","trValues"], df,["reg","prod"], varNameCol="var", valueCol="value",sparse=false)



dimItems = [unique(df[!,col]) for col in dimsNameCols]
size     = [length(dimItem_i) for dimItem_i in dimItems]
toReturn = defVars(size, valueType=valueType,n=n)

for d in 1:nDims
    dLength = size(d)
    for i in 1:



size = (4,2,3)
outMatrix = fill(missing,size)
nDims = length(size)
nCombs = prod(size)
for c in 1:nCombs
    for d in 1:nDims









consumption                       = defEmptyIT(["reg","prod"],[String,String],valueNames=["consumption"],valueTypes=[Float64],n=1)

consumption                       = defVars(["reg","prod"],[String,String],valueNames=["consumption"],valueTypes=[Float64],n=1)


products = ["banana","apples","juice"]
primPr   = products[1:2]
secPr    = [products[3]]
reg      = ["us","eu"]
# equivalent to [production!(sum(trValues_(r,pp) * transfCoef_(r,pp)  for pp in primPr), r, sp) for r in reg, sp in secPr]
@meq production[r in reg, sp in secPr]   = sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPr)
@meq consumption[r in reg, pp in primPr] = production[r,pp] - trValues[r,pp]
@meq consumption!(r in reg, sp in secPr)  = production_(r, sp)
totalConsumption = sum(consumption_(r,p) for r in reg, p in products)

@test totalConsumption == 26.6

# # TEST 2: Testing both the "old" defVarsDf()and the @meq macro using a single DataFrame as base
# df2 = wsv"""
# reg	prod	var	value
# us	banana	production	10
# us	banana	transfCoef	0.6
# us	banana	trValues	2
# us	apples	production	7
# us	apples	transfCoef	0.7
# us	apples	trValues	5
# us	juice	production	NA
# us	juice	transfCoef	NA
# us	juice	trValues	NA
# eu	banana	production	5
# eu	banana	transfCoef	0.7
# eu	banana	trValues	1
# eu	apples	production	8
# eu	apples	transfCoef	0.8
# eu	apples	trValues	4
# eu	juice	production	NA
# eu	juice	transfCoef	NA
# eu	juice	trValues    NA
# """
# variables =  vcat(unique(dropna(df[:var])),["consumption"])
# defVarsDf(variables,df2;dfName="df2",varNameCol="var", valueCol="value")
# products = ["banana","apples","juice"]
# primPr   = products[1:2]
# secPr    = [products[3]]
# reg      = ["us","eu"]
# # equivalent to [production!(sum(trValues_(r,pp) * transfCoef_(r,pp)  for pp in primPr), r, sp) for r in reg, sp in secPr]
# @meq production!(r in reg, sp in secPr)   = sum(trValues_(r,pp) * transfCoef_(r,pp)  for pp in primPr)
# @meq consumption!(r in reg, pp in primPr) = production_(r,pp) - trValues_(r,pp)
# @meq consumption!(r in reg, sp in secPr)  = production_(r, sp)
# totalConsumption = sum(consumption_(r,p) for r in reg, p in products)
#
# @test totalConsumption == 26.6


# TEST : Testing the @meq macro with individual IndexedTables
a = IndexedTable([["a","a","b","b"],[1,2,1,2]]...,[1,2,3,4])
dim1 = ["a","b"]
dim2 = [1,2]

@meq a[d1 in dim1,2] = a[d1,1]+3
tot = sum(a[d1,d2] for d1 in dim1, d2 in dim2)
@test tot == 14

# Test n: Fake test, this should not pass
# @test 1 == 2
