"""
    MultiDimEquations

The package provides handy functions to work with NDSparse (from IndexedTables.jl package)
or standard arrays in order to write equations in a concise and readable way.
The formers can be accessed by name, but are somehow slower, the latters are faster
but need to be accessed by position.

`defVars()` defines either empty NDSparse with the dimensions (axis) required or
arrays with the required size and prefilled with `missing` values. More variables
can be defined at once.

`defLoadVar()` and `defLoadVars()` allow to define and import the variables from
a DataFrame in long format (dim1|dim2|...|value), with the second one allowing to
import more varaibles at once, given the presence of a column in the database with
the variable names.

`@meq` is a macro that allows to write your "model equations" more concisely, e.g.
`@meq par1[d1 in DIM1, d2 in DIM2, dfix3] =  par2[d1,d2]+par3[d1,d2]` would be
expanded to use the list comprehension expression above:
`[par1[d1,d2,dfix3] =  par2[d1,d2]+par3[d1,d2] for d1 in DIM1, d2 in DIM2]`

"""
module MultiDimEquations

using DataFrames, IndexedTables

export defLoadVars, defLoadVar, defVars, @meq, getSafe

##############################################################################
#
# defVars()
#
##############################################################################

"""
    defVars(dimNames, dimTypes; <keyword arguments>)

Define empty NDSparse IndexedTable(s) with the specific dimension(s) and type.

# Arguments
* `dimNames`: Array of names of the dimensions to define
* `dimTypes`: Array of types of the dimensions
* `valueType` (def: `Float64`):  Type of the value column of the table
* `n` (def=`1`): Number of copies of the specified tables to return (useful to define multiple variables at once. In such cases a tuple is returned)

# # Examples
# ```julia
# julia> price,demand,supply = defVars(["region","item","class"],[String,String,Int64],valueType=Float64,n=3 )
# julia> waterContent = defVars(["region","item"],[String,String])
# julia> price["US","apple",1] = 3.2
# julia> waterContent["US","apple"] = 0.2
# ```
# """
function defVars(dimNames, dimTypes; valueType=Float64,n=1)
      values = [Array{T,1}() for T in vcat(dimTypes,valueType)]
      if n==1
          return NDSparse(values...,names=Symbol.(dimNames))
      else
          return fill(deepcopy(NDSparse(values...,names=Symbol.(dimNames))),n)
      end
end

"""
    defVars(size; <keyword arguments>)

Define multidimensional array(s) with the specific dimension(s) and type filled all with `missing` values.

# Arguments
* `size`: Tuple of the dimensions required
* `valueType` (def: `Float64`):  Inner type of the array required
* `n` (def=`1`): Number of copies of the specified tables to return (useful to define multiple variables at once. In such cases a tuple is returned)
* `missingValue` (def=`missing`): How to fill the matrix with


# # Examples
# ```julia
# julia> price,demand,supply = defVars((3,4,5),valueType=Float64,n=3 )
# julia> waterContent = defVars((3,4))
# julia> price[2,3,1] = 3.2
# julia> waterContent[2,3] = 0.2
# ```
# """
function defVars(size; valueType=Float64,n=1,missingValue=missing)
    missingValueType = typeof(missingValue)
    val = fill(missingValue,size...)
    val = convert(Array{Union{missingValueType,valueType},length(size)},val)
    if n==1
        return val
    else
        return fill(deepcopy(val),n)
    end
end


##############################################################################
#
# defLoadVars()
#
##############################################################################

"""
    defLoadVar(df, dimsNameCols; <keyword arguments>)

Define the required IndexedTables or Arrays and load the data from a DataFrame in long format while specifing the dimensional columns.

# Arguments
* `df`: The source of the dataframe, that must be in the format dim1|dim2|...|value
* `dimsNameCols`: The names of the columns corresponding to the dimensions over which the variables are defined (the keys)
* `valueCol (def: "value")`: The name of the column in the df containing the values
* `sparse (def: "true")`: Wheter to return `NDSparse` elements (from IndexedTable) or standard arrays
* `missingValue` (def=`missing`): How to fill the matrix with (relevant only for arrays)

# Notes
* Sparse indexed tables can be accessed by element but are slower, standard arrays need to be accessed by position but are faster

# Examples
```julia
julia> vol  = defVars(volumeData,["region","treeSpecie","year"], valueCol="value")
```
"""
function defLoadVar(df, dimsNameCols; valueCol="value",sparse=true,missingValue=missing)
    valueType = eltype(df[!,valueCol])
    nDims     = length(dimsNameCols)
    if sparse
        sDimensions = [Symbol(d) for d in dimsNameCols]
        dimValues  = [df[:,dim] for dim in dimsNameCols]
        values     = df[:,valueCol]
        t = IndexedTables.NDSparse(dimValues..., names=sDimensions, values)
        return t
    else
        toReturn = Array[]
        dimItems = [unique(df[!,col]) for col in dimsNameCols] # this should be general, i.e. independent on the specific variable we are looking at
        size = [length(dimItem_i) for dimItem_i in dimItems]
        varArray = defVars(size, valueType=valueType,n=1,missingValue=missingValue)

        for i in CartesianIndices(varArray)
           cIdx = Tuple(i)
           particularDims = [map(x->dimItems[d][x], cIdx[d]) for d in 1:nDims]
           selectionArray = fill(false,Base.size(df,1))
           for (i,row) in enumerate(eachrow(df))
               dimFilter = true
               for (d,dim) in enumerate(dimsNameCols)
                   if (row[dim] != particularDims[d])
                       dimFilter = false
                       break
                   end
               end
               selectionArray[i] = dimFilter
           end
           particularValueArray = df[selectionArray,valueCol]
           if(length(particularValueArray)>1)
               @error "In converting a long dataframe to an array, I found more than one record with the same keys."
               particularValue = missingValue
           elseif length(particularValueArray)==0 # this combination is not found
               particularValue = missingValue
           else
               particularValue = particularValueArray[1]
           end
           varArray[i]  = particularValue
        end
        varArray
    end
end

##############################################################################
#
# defLoadVars()
#
##############################################################################

"""
    defLoadVars(vars, df, dimsNameCols; <keyword arguments>)

Define the required IndexedTables or Arrays and load the data from a DataFrame in long format while specifing the dimensional columns and the column containing the variable names.

Like `varLoadVar` but here we are extracting multiple variables at once, with one column of the input dataframe storing the variable name.

# Arguments
* `vars`: The array of variables to lookup
* `df`: The source of the dataframe, that must be in the format dim1|dim2|...|varName|value
* `dimsNameCols`: The name of the column containing the dimensions over which the variables are defined
* `varNameCol (def: "varName")`: The name of the column in the df containing the variables names
* `valueCol (def: "value")`: The name of the column in the df containing the values
* `sparse (def: "true")`: Wheter to return `NDSparse` elements (from IndexedTable) or standard arrays

# Notes
* Sparse indexed tables can be accessed by element but are slower, standard arrays need to be accessed by position but are faster

# Examples
```julia
julia> (vol,numberOfTrees)  = defVars(["vol","numberOfTrees"], forestData,["region","treeSpecie","year"], varNameCol="parName", valueCol="value")
```
"""
function defLoadVars(vars, df, dimsNameCols; varNameCol="varName", valueCol="value",sparse=true)
    if sparse
        toReturn = NDSparse[]
    else
        toReturn = Array[]
    end
    for var in vars
        filteredDf = df[df[!,varNameCol] .== var,:]
        varData = defLoadVar(filteredDf, dimsNameCols; valueCol=valueCol,sparse=sparse)
        if length(vars) > 1
            push!(toReturn,varData)
        else
            return varData
        end
    end
    return (toReturn...,)
end


##############################################################################
#
# meq()
#
##############################################################################

"""
    meq(exp)

Macro to expand functions like `t[d1 in dim1, d2 in dim2, dfix,..] = value`

With this macro it is possible to write:

```
@meq par1[d1 in DIM1, d2 in DIM2, dfix3] =  par2[d1,d2]+par3[d1,d2]
```

and obtain
```
[par1[d1,d2,dfix3] =  par2[d1,d2]+par3[d1,d2] for d1 in DIM1, d2 in DIM2]
```

That is, it is possible to write "model equations" in a concise and readable way.

"""
macro meq(eq) # works without MacroTools
    lhs                   = eq.args[1]
    rhs                   = eq.args[2]
    lhs_par               = lhs.args[1]
    lhs_dims              = lhs.args[2:end]
    loop_counters         = [d.args[2] for d in lhs_dims if typeof(d) == Expr]
    loop_sets             = [d.args[2] for d in lhs_dims if typeof(d) == Expr]
    loop_wholeElements    = []
    lhs_dims_placeholders = []
    for d in lhs_dims
        if typeof(d) == Expr && d.args[1] == :in
            push!(lhs_dims_placeholders,d.args[2])
            push!(loop_wholeElements, :($(d.args[2]) = $(d.args[3])))
        else
            push!(lhs_dims_placeholders,d)
        end
    end
    if (lhs.head == :ref)      # lhs is an array
        ret = Expr(:comprehension, :($lhs_par[$(lhs_dims_placeholders...)] = $(rhs)),loop_wholeElements...)
#    elseif (lhs.head == :call) # lhs is a function call
#        ret = Expr(:comprehension, :($lhs_par($(rhs),$(lhs_dims_placeholders...))),loop_wholeElements...)
    else
        error("Didn't understand the Left Hand Side.")
    end
    #show(ret)
    return esc(ret)
end


##############################################################################
#
# getSafe()
#
##############################################################################

"""
    getSafe(idxtable,indices,missingValue=missing)

Return the value stored in a NDSParse table or missingValue if the specified keys are not present.

# Arguments
* `idxtable`: The NDSParse table to lookup
* `indices`: A tuple with the indices to use (`:` is supported)
* `missingValue`: The value to return if the specified keys are not found

# Examples
```julia
julia> volBlackForest2014  = getSafe(forestVolumes,("BlackForest",2014),0.0)
```
"""
function getSafe(idxtable,indices,missingValue=missing)
    try
        return idxtable[indices...]
    catch  e
        if isa(e, KeyError)
            return missingValue
        else
            rethrow(e)
        end
    end
end

end # end module
