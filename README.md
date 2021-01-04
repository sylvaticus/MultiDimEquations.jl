# MultiDimEquations

Allows to write multi-dimensional equations in Julia using a readable and compact syntax:

```
@meq nTrees[r in reg, sp in species, dc in diameterClass[2-end], y in years] = nTrees[r, sp, dc, y-1]*(1-mortRate[r, sp, dc, y-1] - promotionRate[r, sp, dc, y-1]) +  nTrees[r, sp, dc-1, y-1] * promotionRate[r, sp, dc-1, y-1]
```

It allow to write your model in a similar way of using an Algebraic modeling language (AML) like GAMS or Julia/JuMP, but outside the domain of optimisation.

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://sylvaticus.github.io/MultiDimEquations.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://sylvaticus.github.io/MultiDimEquations.jl/dev)
[![Build status (Github Actions)](https://github.com/sylvaticus/MultiDimEquations.jl/workflows/CI/badge.svg)](https://github.com/sylvaticus/MultiDimEquations.jl/actions)
[![codecov.io](http://codecov.io/github/sylvaticus/MultiDimEquations.jl/coverage.svg?branch=master)](http://codecov.io/github/sylvaticus/MultiDimEquations.jl?branch=master)

## Installation
* `] add "MultiDimEquations"`

## Using the package
 `using MultiDimEquations`

## Definition of the variables:

Define or define and load the data for each group of variables from a DataFrame in long format, i.e. in the format dim1|dim2|...|value or dim1|dim2|...|variableName|value

```
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

(production,transfCoef,trValues) = defLoadVars(["production","transfCoef","trValues"], df,["reg","prod"], varNameCol="var", valueCol="value",sparse=true)
consumption                      = defVars(["reg","prod"],[String,String])
```

For more info type `?defVars` or `?defLoadVars` once you installed and loaded the package or consult the documentation ([stable](https://sylvaticus.github.io/MultiDimEquations.jl/stable)|[development](https://sylvaticus.github.io/MultiDimEquations.jl/dev))


# Defining the "set" (dimensions) of your data
These are simple Julia Arrays..

```
reg      = unique(df.reg)
products = unique(df.prod)
primPr   = products[1:2]
secPr    = [products[3]]
```

## Write your model using the @meq macro

The @meq macro adds a bit of convenience transforming at parse time (so, without adding run-time overheads) your equation from `par1[d1 in DIM1, d2 in DIM2, dfix3] = par2[d1,d2]+par3[d1,d2]` to `[par1[d1,d2,dfix3] = par2[d1,d2]+par3[d1,d2] for d1 in dim1, d2 in dim2]`.

```
# equivalent to [production[r, sp] = sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPr) for r in reg, sp in secPr]
@meq production[r in reg, sp in secPr]   = sum(trValues[r,pp] * transfCoef[r,pp]  for pp in primPr)
@meq consumption[r in reg, pp in primPr] = production[r,pp] - trValues[r,pp]
@meq consumption[r in reg, sp in secPr]  = production[r, sp]
```

For more info on the @meq macro type `?@meq` or consult the documentation ([stable](https://sylvaticus.github.io/MultiDimEquations.jl/stable)|[development](https://sylvaticus.github.io/MultiDimEquations.jl/dev))

## Known limitation
- At this time, only `var = ...` assignments are supported.

## Acknowledgements

The development of this package was supported by the French National Research Agency through the [Laboratory of Excellence ARBRE](http://mycor.nancy.inra.fr/ARBRE/), a part of the “Investissements d'Avenir” Program (ANR 11 – LABX-0002-01).
