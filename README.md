# MultiDimEquations

Allows to write multi-dimensional equations in Julia using an easy and compact syntax:

"""
@meq nTrees!(r in reg, sp in species, dc in diameterClass[2-end], y in years) = nTrees_(r, sp, dc, y)*(1-mortRate_(r, sp, dc, y-1) - promotionRate_(r, sp, dc, y-1))) +  promotionRate_(r, sp, dc-1, y-1)
"""

It is similar to Algebraic modeling language (AML) like GAMS or Julia/JuMP, but outside the domain of optimisation.

## Installation
`Pkg.clone(https://github.com/sylvaticus/MultiDimEquations.jl.git)` (until the package is not registered)
`Pkg.add("MultiDimEquations")` (when the package is eventually registered)

## Making available the package
Due to the fact that the functions to access the data are dynamically created at run time, and would not be available to you with a normal `import <package>`, you have rather to include the file in your program:

`include("$(Pkg.dir())/MultiDimEquations/src/MultiDimEquations.jl")``

## Definition of the variables:

Define each group of variables with their associated data source. At the moment MultiDimEquations support only DataFrame in long format, i.e. in the format parameter|dim1|dim2|...|value

"""
df = wsv\"\"\"
reg	prod	var	value
us	banana	production	10
us	banana	transfCoef	0.6
us	banana	trValues	2
us	apples	production	7
us	apples	transfCoef	0.7
us	apples	trValues	5
us	juice	production	NA
us	juice	transfCoef	NA
us	juice	trValues	NA
eu	banana	production	5
eu	banana	transfCoef	0.7
eu	banana	trValues	1
eu	apples	production	8
eu	apples	transfCoef	0.8
eu	apples	trValues	4
eu	juice	production	NA
eu	juice	transfCoef	NA
eu	juice	trValues    NA
\"\"\"

variables =  vcat(unique(dropna(df[:var])),["consumption"])
defVars(variables,df;dfName="df",varNameCol="var", valueCol="value")
"""

Each time you run `defVars()`, access functions are automatically created for each variable in the form of `variable_(dim1,dim2,...)` to access the data and `variable!(value,dim1,dim2,..)` to store the value.
For more info type ``?defVars` once you installed and loaded the package.


# Defining the "set" (dimensions) of your data
These are simple Julia Arrays..

"""
products = ["banana","apples","juice"]
primPr   = products[1:2]
secPr    = [products[3]]
reg      = ["us","eu"]
"""

## Write your model using the @meq macros

The @meq macro adds a bit of convenience transforming at parse time (so, without adding run-time overheads) your equation from `par1!( par2(d1,d2)+par3(d1,d2) ,d1,d2,dfix3)` to `par1!(d1 in DIM1, d2 in DIM2, dfix3) =  par2(d1,d2)+par3(d1,d2)`.

"""
# equivalent to [production!(sum(trValues_(r,pp) * transfCoef_(r,pp)  for pp in primPr), r, sp) for r in reg, sp in secPr]
@meq production!(r in reg, sp in secPr)   = sum(trValues_(r,pp) * transfCoef_(r,pp)  for pp in primPr)
@meq consumption!(r in reg, pp in primPr) = production_(r,pp) - trValues_(r,pp)
@meq consumption!(r in reg, sp in secPr)  = production_(r, sp)
"""
For more info on the @meq macro type ?@meq

## Known limitation

This is a young package still under active development.
While very easy to code with, it is not the faster way to access datasets. If speed is your main concern looks for example at [IndexedTables](https://github.com/JuliaComputing/IndexedTables.jl).
Also at this time only `var = ...` assignments are supported.

## Acknowledgements

The development of this package was supported by the French National Research Agency through the [Laboratory of Excellence ARBRE](http://mycor.nancy.inra.fr/ARBRE/), a part of the “Investissements d'Avenir” Program (ANR 11 – LABX-0002-01).
