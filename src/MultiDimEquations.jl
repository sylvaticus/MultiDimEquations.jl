
using DataFrames, DataFramesMeta, MacroTools


##############################################################################
##
## defVars()
##
##############################################################################

"""
    defVars(vars, df;<keyword arguments>)

Set getData() and setData() type function for each variable binding to the given dataframe.

# Arguments
* `vars`:  an array of variables for which to build the get/set functions;
* `df`: the dataframe to bind the variables with. The DataFrame must be in long mode with one column for each dimension;
* `dfName` (def "df"): the name of the variable pointing to the DataFrame (this is normally just a string version of the previous parameter);
* `varNameCol` (def "varName"): the name of the dataframe column containing the variable name
* `valueCol` (def "value"): the name of the dataframe column storing the value
* `debug` (def false): returns a touple with the getData() and setData() expressions instead of actual parsing and evaluating them

# Notes:
* This function autogenerate two type of functions:
    * getData-type of function in the form of var1_(dim1=NA,dim2=NA,...)
    * setData-type of function in the form of var1!(value,dim1=NA,dim2=NA,..)
* If debug is passed, the function returns a touple with (getData(), setData()) expressions. These can then be parsed and evaluated as needed.


# Examples
```julia
julia> defVariables(["supply","cons","exp","imp","transfCoeff","tranfCost"], data, dfName="data",varNameCol="variable",valueCol="value")
```
"""
function defVars(vars, df; dfName="df", varNameCol="varName", valueCol="value", debug=false)
    colNames = names(df)
    varColPos = find(x -> x == Symbol(varNameCol), colNames )
    valueColPos = find(x -> x == Symbol(valueCol), colNames )
    deleteat!(colNames , varColPos)
    deleteat!(colNames , find(x -> x == Symbol(valueCol), colNames )) # index changed bec of previous delete
    dimNames = ["$(colNames[i]), " for i in 1:(length(colNames)-1)]
    push!(dimNames, "$(colNames[length(colNames)])")
    dimNamesWithNA = ["$(colNames[i]) = NA, " for i in 1:(length(colNames)-1)]
    push!(dimNamesWithNA, "$(colNames[length(colNames)]) = NA")
    expr1 = ""
    expr2 = ""
    for var in vars
        # Get value
        expr1 *=  "\"\"\"Return the value of $(var) under the dimensions  $(dimNames...).\"\"\""  # documentation string
        expr1  *= "function $(var)_( $(dimNamesWithNA...)  );"
        expr1  *= "return @where($(dfName), :$(varNameCol) .== \"$(var)\", "
        for (i,c) in enumerate(colNames)
        expr1  *= "isequal.(:$(c),$(c) ), "
        end
        expr1  *= ")[end,:$(valueCol)];"
        expr1  *= "end;"
        # Set value
        expr2  *=  "\"\"\"Set the value of $(var) equal to v under the dimensions $(dimNames...) (either updating existing value(s) or creating a new record).\"\"\""
        expr2  *= "function $(var)!(v, $(dimNamesWithNA...)  );"
        expr2  *= "dfFilter = "
        expr2  *= "($(dfName)[:$(varNameCol)] .== \"$var\") "
        if length(colNames) > 0
            expr2  *= " .& "
        end
        for (i,c) in enumerate(colNames)
            expr2  *= "isequal.($(dfName)[:$(c)],$(c) ) "
            if i < length(colNames)
                expr2 *=   " .& "
            else
                expr2 *= ";"
            end
        end
        expr2   *= "if any(dfFilter) > 0;"
        expr2   *=  " df[dfFilter, :$(valueCol)] = v;"
        expr2   *= "else;"
        outNames = []
        for (i,n) in enumerate(names(df))
            if i == valueColPos[1]
                push!(outNames,"v, ")
            elseif i == varColPos[1]
                push!(outNames,"\"$(var)\", ")
            else
                push!(outNames,"$(n), ")
            end
        end
        expr2   *= " push!($(dfName), [ $(outNames...)  ]);"
        expr2   *= "end; end;"
    end
    if debug return (expr1,expr2) end
    pexpr1 = parse(expr1)
    eval(pexpr1)
    pexpr2 = parse(expr2)
    eval(pexpr2)
    return nothing
end

##############################################################################
##
## meq()
##
##############################################################################

"""
   meq(ex)

Macro to transform `f(dim1,dim2,..) = value` into `f(value,dim1,dim2,..)`

With this macro it is possible to write:
```
@meq par1!(d1 in DIM1, d2 in DIM2, dfix3) =  par2(d1,d2)+par3(d1,d2)
```

and obtain
```
[par1!( par2(d1,d2)+par3(d1,d2)   ,d1,d2,dfix3) for d1 in DIM1, d2 in DIM2]
```

That is, it is possible to write code with a LaTex-type syntax.

"""
macro meq(ex)
   @capture(ex, par_(dims__) = rhs_)
   loopElements = []
   dimsPlaceholders = []
   for d in dims
       @capture(d, di_ in DIMi_) || (push!(dimsPlaceholders, d); continue)
       # push!(loopElements, x)
       push!(loopElements, :($di = $DIMi))
       push!(dimsPlaceholders, di)
   end
   ret = Expr(:comprehension, :($par($(rhs),$(dimsPlaceholders...))), loopElements...)
   #show(ret)
   return ret
end
