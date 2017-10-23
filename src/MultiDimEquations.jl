
using DataFrames, IndexedTables

##############################################################################
##
## defVars()
##
##############################################################################

"""
    defVars(vars, df;<keyword arguments>)

Set getData() and setData() type function for each variable binding to the IndexedTable that it returns.

# Arguments
* `vars`:  an array of variables for which to build the get/set functions;
* `df`: the dataframe from which to load the inital values of the variables. The DataFrame must be in long mode with one column for each dimension;
* `tableName` (def "df"): the name of the variable pointing to the IndexedTable returned by this function (a string);
* `varNameCol` (def "varName"): the name of the dataframe column containing the variable name
* `valueCol` (def "value"): the name of the dataframe column storing the value
* `retValue` (def NA): what the `var_()`` functions should return if nothing is found (default to NA)
* `debug` (def false): returns a touple with the getData() and setData() expressions instead of actual parsing and evaluating them

# Notes:
* This function autogenerate two type of functions:
    * getData-type of function in the form of var1_(dim1=NA,dim2=NA,...)
    * setData-type of function in the form of var1!(value,dim1=NA,dim2=NA,..)
* If debug is passed, the function returns a touple with (getData(), setData()) expressions. These can then be parsed and evaluated as needed.


# Examples
```julia
julia> tableData = defVars(["supply","cons","exp","imp","transfCoeff","tranfCost"], data, tableName="tableData",varNameCol="variable",valueCol="value")
```
"""
function defVars(vars, df; tableName="table", varNameCol="varName", valueCol="value", retValue=NA, debug=false)

    colNames = names(df)
    varColPos = find(x -> x == Symbol(varNameCol), colNames )
    valueColPos = find(x -> x == Symbol(valueCol), colNames )
    colNamesString = [String(c) for c in colNames]

    deleteat!(colNames , varColPos)
    deleteat!(colNames , find(x -> x == Symbol(valueCol), colNames )) # index changed bec of previous delete

    # creating empty table with types from the DataFrame
    typeVarCol     = eltype(df[Symbol(varNameCol)])
    typeDimCols    = []
    for dim in colNames
        nNA = length(find(x -> isna(x), df[dim]))
        if nNA == 0
            push!(typeDimCols,eltype(df[dim]))
        else
            push!(typeDimCols,Union{eltype(df[dim]),DataArrays.NAtype})
        end
    end
    #typeDimCols    = [eltype(df[dim]) for dim in colNames]
    typeValueCol   = eltype(df[Symbol(valueCol)])
    typeVarDimCols = vcat(typeVarCol,typeDimCols)
    dimValues = [Array{T,1}() for T in typeVarDimCols]
    t = IndexedTables.Table(dimValues..., names=vcat(Symbol(varNameCol),colNames), Array{typeValueCol,1}())

    # filling the table with data
    for r in eachrow(df)
        rv = Any[]
        for d in vcat(Symbol(varNameCol),colNames)
            push!(rv,r[d])
        end
        t[rv...] = r[Symbol(valueCol)]
    end

    # Creating get/set functions for each variable
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
        expr1  *= "    try;"
        expr1  *= "        return $(tableName)[\"$var\",$(dimNames...)];"
        expr1  *= "    catch  e;"
        expr1  *= "        if isa(e, KeyError);"
        expr1  *= "          return $(retValue);"
        expr1  *= "        end;"
        expr1  *= "        rethrow(e);"
        expr1  *= "    end;"
        expr1  *= "end;"
        # Set value
        expr2  *=  "\"\"\"Set the value of $(var) equal to v under the dimensions $(dimNames...) (either updating existing value(s) or creating a new record).\"\"\""
        expr2  *= "function $(var)!(v, $(dimNamesWithNA...)  );"
        expr2  *= "    $(tableName)[\"$var\",$(dimNames...)] = v;"
        expr2  *= "    return v;"
        expr2  *= "end;"
    end
    if debug return (expr1,expr2) end
    pexpr1 = parse(expr1)
    eval(pexpr1)
    pexpr2 = parse(expr2)
    eval(pexpr2)
    return t
end



##############################################################################
##
## defVarsDf()
##
##############################################################################

"""
    defVarsDf(vars, df;<keyword arguments>)

Set getData() and setData() type function for each variable binding to the given dataframe.

Use this function if you want the data-backend of your model being a DataFrame.
This is slower than `defVars()`` that instead returns a faster IndexedTable and bind get/setData() to that.
To use the get/setData() functions generated by this function you will need the `DataFramesMeta` package.

# Arguments
* `vars`:  an array of variables for which to build the get/set functions;
* `df`: the dataframe to bind the variables with. The DataFrame must be in long mode with one column for each dimension;
* `dfName` (def "df"): the name of the variable pointing to the DataFrame (this is normally just a string version of the previous parameter);
* `varNameCol` (def "varName"): the name of the dataframe column containing the variable name
* `valueCol` (def "value"): the name of the dataframe column storing the value
* `retValue` (def NA): what the `var_()`` functions should return if nothing is found (default to NA)
* `debug` (def false): returns a touple with the getData() and setData() expressions instead of actual parsing and evaluating them

# Notes:
* This function autogenerate two type of functions:
    * getData-type of function in the form of var1_(dim1=NA,dim2=NA,...)
    * setData-type of function in the form of var1!(value,dim1=NA,dim2=NA,..)
* If debug is passed, the function returns a touple with (getData(), setData()) expressions. These can then be parsed and evaluated as needed.


# Examples
```julia
julia> defVarsDf(["supply","cons","exp","imp","transfCoeff","tranfCost"], data, dfName="data",varNameCol="variable",valueCol="value")
```
"""
function defVarsDf(vars, df; dfName="df", varNameCol="varName", valueCol="value", retValue=NA, debug=false)
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
        expr1  *= "out = @where($(dfName), :$(varNameCol) .== \"$(var)\", "
        for (i,c) in enumerate(colNames)
        expr1  *= "isequal.(:$(c),$(c) ), "
        end
        expr1  *= ");"
        expr1  *= "  if size(out)[1] > 0;"
        expr1  *= "    return out[end,:$(valueCol)];"
        expr1  *= "  else;"
        expr1  *= "    return $(retValue);"
        expr1  *= "  end;"
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
        expr2   *= "if any(dfFilter);"
        expr2   *=  " $(dfName)[dfFilter, :$(valueCol)] = v;"
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
        expr2   *= "end; return v; end;"
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
   meq(exp)

Macro to expand functions like `f(dim1,dim2,..) = value` or `t[d1 in dim1, d2 in dim2, dfix,..] = value`

With this macro it is possible to write either:

```
@meq par1!(d1 in DIM1, d2 in DIM2, dfix3) =  par2_(d1,d2)+par3_(d1,d2)
```

and obtain
```
[par1!( par2_(d1,d2)+par3_(d1,d2)   ,d1,d2,dfix3) for d1 in DIM1, d2 in DIM2]
```

or

```
@meq par1[d1 in DIM1, d2 in DIM2, dfix3] =  par2(d1,d2)+par3(d1,d2)
```

and obtain
```
[par1[d1,d2,dfix3] =  par2(d1,d2)+par3(d1,d2) for d1 in DIM1, d2 in DIM2]
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
    elseif (lhs.head == :call) # lhs is a function call
        ret = Expr(:comprehension, :($lhs_par($(rhs),$(lhs_dims_placeholders...))),loop_wholeElements...)
    else
        error("Didn't understand the Left Hand Side.")
    end
    #show(ret)
    return ret
end

# # needs MacroTools
# macro meqold(ex)
#    #return dump(ex)
#    @capture(ex, par_(dims__) = rhs_)
#    loopElements = []
#    dimsPlaceholders = []
#    for d in dims
#        @capture(d, di_ in DIMi_) || (push!(dimsPlaceholders, d); continue)
#        # push!(loopElements, x)
#        push!(loopElements, :($di = $DIMi))
#        push!(dimsPlaceholders, di)
#    end
#    ret = Expr(:comprehension, :($par($(rhs),$(dimsPlaceholders...))), loopElements...)
#    #show(ret)
#    return ret
# end
