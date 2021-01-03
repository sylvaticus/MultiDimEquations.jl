module MultiDimEquations

using DataFrames, IndexedTables

export defLoadVars, defVars, @meq


##############################################################################
#
# defVars()
#
##############################################################################

"""
  defVars(vars, df, dimensions;<keyword arguments>)

Create the required IndexedTables from a common DataFrame while specifing the dimensional columns.

# Arguments
* `vars`: the array of variables to lookup
* `df`: the source of the dataframe, that must be in the format parName|d1|d2|...|value
* `dimsNameCols`: the name of the column containing the dimensions over which the variables are defined
* `varNameCol (def: "varName")`: the name of the column in the df containing the variables names
* `valueCol (def: "value")`: the name of the column in the df containing the values

# Examples
```julia
julia> (vol,mortCoef)  = defVars(["vol","mortCoef"], forData,["region","d1","year"], varNameCol="parName", valueCol="value")
```
"""
function defLoadVars(vars, df, dimsNameCols; varNameCol="varName", valueCol="value",sparse=false)
    valueType = eltype(df[!,valueCol])
    nDims     = length(dimsNameCols)
    if sparse
        toReturn = NDSparse[]
        sDimensions = [Symbol(d) for d in dimsNameCols]
        for var in vars
            filteredDf = df[df[!,varNameCol] .== var,:]
            dimValues  = [filteredDf[:,dim] for dim in dimsNameCols]
            values     = filteredDf[:,valueCol]
            t = IndexedTables.NDSparse(dimValues..., names=sDimensions, values)
            if length(vars) > 1
                push!(toReturn,t)
            else
                return t
            end
        end
        return (toReturn...,)
    else
        toReturn = Array[]
        for var in vars
            dfVar = df[df[!,varNameCol] .== var,:]
            dimItems = [unique(dfVar[!,col]) for col in dimsNameCols]
            size = [length(dimItem_i) for dimItem_i in dimItems]
            varArray = defVars(size, valueType=valueType,n=1)[1]

            for i in CartesianIndices(varArray)
               cIdx = Tuple(i)
               particularDims = [map(x->dimItems[d][x], cIdx[d]) for d in 1:nDims]

               selectionArray = fill(false,Base.size(dfVar,1))
               for (i,row) in enumerate(eachrow(dfVar))
                   dimFilter = true
                   for (d,dim) in enumerate(dimsNameCols)
                       if (row[dim] != particularDims[d])
                           dimFilter = false
                           break
                       end
                   end
                   selectionArray[i] = dimFilter
               end
               particularValueArray = dfVar[selectionArray,valueCol]
               if(length(particularValueArray)>1)
                   @error "In converting a long dataframe to an array, I found more than one record with the same keys."
               elseif length(particularValueArray)==0
                   particularValue = missing
               else
                   particularValue = particularValueArray[1]
               end
               varArray[i]  = particularValue
            end
            push!(toReturn,varArray)
        end
        return (toReturn...,)
    end
end

##############################################################################
#
# defVars()
#
##############################################################################

"""
  defVars(dimNames, dimTypes; <keyword arguments>)

Define empty IndexedTable(s) with the specific dimension(s) and type(s).

# Arguments
* `dimNames`: array of names of the dimensions to define (can be empty)
* `dimTypes`: array of types of the dimensions (must be same length of dimNames if the latter is not null)
* `valueType=[Float64]` array of types of the value cols to define (must be same length of valueNames if the latter is not null)
* `n=1`: number of copies of the specified tables to return

# # Examples
# ```julia
# julia> price,demand,supply = defEmptyVars(["region","item","qclass"],[String,String,Int64],valueNames=["val2000","val2010"],valueTypes=[Float64,Float64],n=3 )
# julia> waterContent = defEmptyVars(["region","item"],[String,String])
# julia> price["US","apple",1] = 3.2,3.4
# julia> waterContent["US","apple"] = 0.2
# ```
#
# # Notes
# Single index or single column can not be associated to a name.
# """
function defVars(dimNames, dimTypes; valueType=Float64,n=1)
      values = [Array{T,1}() for T in vcat(dimTypes,valueType)]
      return fill(deepcopy(NDSparse(values...,names=Symbol.(dimNames))),n)
end

function defVars(size; valueType=Float64,n=1)
    return fill(deepcopy(Array{Union{Missing,valueType},length(size)}(missing,size...)),n)
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

That is, it is possible to write equations in a concise and readable way

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
    return ret
end


end # end module
