# MultiDimEquations.jl

Documentation for the [MultiDimEquations.jl](https://github.com/sylvaticus/MultiDimEquations.jl) package

# The MultiDimEquations Module

```@docs
MultiDimEquations
```

## Module Index

```@index
Modules = [MultiDimEquations]
Order   = [:constant, :type, :function, :macro]
```

## Example

### Input data...
```julia
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
eu banana trValues      1
eu apples production    8
eu apples transfCoef    0.8
eu apples trValues 4
eu juice production missing
eu juice transfCoef missing
eu juice trValues missing
"""), DataFrame, delim=" ", ignorerepeated=true, copycols=true, missingstring="missing")
```

### ...using NDSparse:

```julia
reg      = unique(df.reg)
products = unique(df.prod)
primPr   = products[1:2]
secPr    = [products[3]]

(production,transfCoef,trValues) = defLoadVars(["production","transfCoef","trValues"], df,["reg","prod"], varNameCol="var", valueCol="value",sparse=true)
consumption                      = defVars(["reg","prod"],[String,String])

# equivalent to [production[r, sp] = sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPr) for r in reg, sp in secPr]
@meq production[r in reg, sp in secPr]   = sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPr)
@meq consumption[r in reg, pp in primPr] = production[r,pp] - trValues[r,pp]
@meq consumption[r in reg, sp in secPr]  = production[r, sp]
```

### ...using normal arrays:

```julia
reg      = unique(df.reg)
products = unique(df.prod)
primPrIdx = [1,2]
secPrIdx  = [3]

(production,transfCoef,trValues) = defLoadVars(["production","transfCoef","trValues"], df,["reg","prod"], varNameCol="var", valueCol="value",sparse=false)
consumption                      = defVars([length(reg),length(products))

@meq production[r in eachindex(reg), sp in secPrIdx]   =  sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPrIdx)
@meq consumption[r in eachindex(reg), pp in primPrIdx] = production[r,pp] - trValues[r,pp]
@meq consumption[r in eachindex(reg), sp in secPrIdx]  = production[r, sp]
```

## Detailed API

```@autodocs
Modules = [MultiDimEquations]
Order   = [:constant, :type, :function, :macro]
```
