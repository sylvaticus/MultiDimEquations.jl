using Test
using DataFrames, CSV
using MultiDimEquations

println("*** Start testing of MultiDimEquations...")

# *** NEW TEST
# Checking empty variable definition
(exp,consumption)   = defVars(["product","regions","years"],[String,String,Int64],n=2)
(exp2,consumption2) = defVars([3,2,5],n=2,missingValue=missing)
consumption10 = defVars(["product","regions","years"],[String,String,Int64])
consumption20 = defVars([3,2,5])
@test consumption10 == consumption
@test Base.size(consumption20) == Base.size(consumption2)
exp["banana","Canada",2010] = 2
@test exp["banana","Canada",2010] + 1 == 3
consumption2[2,1,5] = 2
@test consumption2[2,1,5] + 1 == 3

# *** NEW TEST
# checking loading variables from long-format dataframe
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

prodDf      = df[df.var .== "production",:]
prodSingle  = defLoadVar(prodDf,["reg","prod"], valueCol="value",sparse=true)
prodSingle2 = defLoadVar(prodDf,["reg","prod"], valueCol="value",sparse=false)

(production,transfCoef,trValues)     = defLoadVars(["production","transfCoef","trValues"], df,["reg","prod"], varNameCol="var", valueCol="value",sparse=true)
(production2,transfCoef2,trValues2)  = defLoadVars(["production","transfCoef","trValues"], df,["reg","prod"], varNameCol="var", valueCol="value",sparse=false)

reg = unique(df.reg)
products = unique(df.prod)

@test trValues["eu","apples"] == 4
@test trValues2[findfirst(isequal("eu"),reg),findfirst(isequal("apples"),products)] == 4

# *** NEW TEST
# checking the @meq macro

primPr    = products[1:2]
secPr     = [products[3]]
primPrIdx = [1,2]
secPrIdx  = [3]
nReg      = length(reg)

trValues["eu","banana"] = 1
trValues2[findfirst(isequal("eu"),reg),findfirst(isequal("banana"),products)] = 1
[production[r,sp]   =  sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPr) for r in reg, sp in secPr]
a = deepcopy(production)
@meq production[r in reg, sp in secPr]   = sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPr)
b = deepcopy(production)
[production2[r,sp]   =  sum(trValues2[r,pp] * transfCoef2[r,pp]  for pp in primPrIdx) for r in eachindex(reg), sp in secPrIdx]
c = deepcopy(production2)
@meq production2[r in eachindex(reg), sp in secPrIdx]   =  sum(trValues2[r,pp] * transfCoef2[r,pp]  for pp in primPrIdx)
d = deepcopy(production2)

@test a["us","juice"] ≈ b["us","juice"] ≈ c[findfirst(isequal("us"),reg),findfirst(isequal("juice"),products)] ≈ d[findfirst(isequal("us"),reg),findfirst(isequal("juice"),products)] ≈ 4.7

consumption  = defVars(["reg","prod"],[String,String])
consumption2 = defVars([2,3])

@meq consumption[r in reg, pp in primPr] = production[r,pp] - trValues[r,pp]
@meq consumption[r in reg, sp in secPr]  = production[r, sp]
totalConsumption = sum(consumption[r,p] for r in reg, p in products)
@test totalConsumption == 26.6

@meq consumption2[r in eachindex(reg), pp in primPrIdx] = production2[r,pp] - trValues2[r,pp]
@meq consumption2[r in eachindex(reg), sp in secPrIdx]  = production2[r, sp]
totalConsumption2 = sum(consumption2[r,p] for r in eachindex(reg), p in eachindex(products))
@test totalConsumption2 == 26.6


# *** NEW TEST
# checking getSafe()

@test getSafe(production,("us","banana"))      == 10
@test getSafe(production,("us","oranges"),0.0) == 0.0
