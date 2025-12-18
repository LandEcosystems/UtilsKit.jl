"""
    UtilsKit.ForCollections

Collections / data-structure utilities:
- Dictionary ↔ NamedTuple helpers
- NamedTuple field manipulation and merging
- small helpers for tabular printing and TypedTables interop
"""
module ForCollections

using DataStructures
using Accessors: @set
using TypedTables: Table
using Crayons

export dict_to_namedtuple
export drop_namedtuple_fields
export foldl_tuple_unrolled
export merge_namedtuple_prefer_nonempty
export table_to_namedtuple
export namedtuple_from_names_values
export duplicates
export drop_empty_namedtuple_fields
export set_namedtuple_field
export set_namedtuple_subfield
export list_to_table
export tc_print


"""
    _collectTypeColors(d; _color = true)

Collect colors for all types from nested namedtuples.

# Arguments
- `d`: The input data structure
- `_color`: Whether to use colors (default: true)

# Returns
- A dictionary mapping types to color codes
"""
function _collectTypeColors(data; _color=true)
    all_types = []
    all_types = _collectTypes!(data, all_types)
    c_types = Dict{DataType,Int}()
    # Julia 1.10/1.11 compatible: use simple 4-bit ANSI color codes 0–15 as defaults.
    _default_colors = collect(0:15)
    for (i,t) ∈ enumerate(all_types)
        if _color == true
            c = i<17 ? _default_colors[i] : rand(16:255)
        else
            c = 0
        end
        c_types[t] = c
    end
    return c_types
end


"""
    dict_to_namedtuple(d::AbstractDict)

Convert a nested dictionary to a NamedTuple.

# Arguments
- `d::AbstractDict`: The input dictionary to convert

# Returns
- A NamedTuple with the same structure as the input dictionary

# Examples

```jldoctest
julia> using UtilsKit

julia> dict_to_namedtuple(Dict(:a => 1, :b => 2))
(a = 1, b = 2)
```
"""
function dict_to_namedtuple(dict::AbstractDict)
    for k ∈ keys(dict)
        if dict[k] isa Array{Any,1}
            dict[k] = [v for v ∈ dict[k]]
        elseif dict[k] isa DataStructures.OrderedDict
            dict[k] = dict_to_namedtuple(dict[k])
        end
    end
    dict_tuple = NamedTuple{Tuple(Symbol.(keys(dict)))}(values(dict))
    return dict_tuple
end


"""
    foldl_tuple_unrolled(f, x::Tuple{Vararg{Any, N}}; init)

Generate an unrolled expression to run a function for each element of a tuple to avoid complexity of for loops 
for compiler.

# Arguments
- `f`: The function to apply
- `x`: The tuple to iterate through
- `init`: Initial value for the fold operation

# Returns
- The result of applying the function to each element

# Examples

```jldoctest
julia> using UtilsKit

julia> foldl_tuple_unrolled(+, (1, 2, 3); init=0)
6
```
"""
@generated function foldl_tuple_unrolled(f, x::Tuple{Vararg{Any,N}}; init) where {N}
    exes = Any[:(init = f(init, x[$i])) for i ∈ 1:N]
    return Expr(:block, exes...)
end


"""
    drop_namedtuple_fields(namedtuple::NamedTuple, names::Tuple{Vararg{Symbol}})

Remove specified fields from a NamedTuple.

# Arguments
- `namedtuple`: The input NamedTuple
- `names`: A tuple of field names to remove

# Returns
- A new NamedTuple with the specified fields removed

# Examples

```jldoctest
julia> using UtilsKit

julia> drop_namedtuple_fields((a=1, b=2, c=3), (:b,))
(a = 1, c = 3)
```
"""
function drop_namedtuple_fields(nt::NamedTuple, names::Tuple{Vararg{Symbol}})
    keepnames = Base.diff_names(Base._nt_names(nt), names)
    return NamedTuple{keepnames}(nt)
end

"""
    merge_namedtuple_prefer_nonempty(base_nt::NamedTuple, priority_nt::NamedTuple)

Combine property values from base and priority NamedTuples.

# Arguments
- `base_nt`: The base NamedTuple
- `priority_nt`: The priority NamedTuple whose values take precedence

# Returns
- A new NamedTuple combining values from both inputs

# Examples

```jldoctest
julia> using UtilsKit

julia> merge_namedtuple_prefer_nonempty((a=[1], b=[2]), (b=[99],))
(a = [1], b = [99])
```
"""
function merge_namedtuple_prefer_nonempty(base_nt::NamedTuple, priority_nt::NamedTuple)
    combined_nt = (;)
    base_fields = propertynames(base_nt)
    var_fields = propertynames(priority_nt)
    all_fields = Tuple(unique([base_fields..., var_fields...]))
    for var_field ∈ all_fields
        field_value = nothing
        if hasproperty(base_nt, var_field)
            field_value = getfield(base_nt, var_field)
        else
            field_value = getfield(priority_nt, var_field)
        end
        if hasproperty(priority_nt, var_field)
            var_prop = getfield(priority_nt, var_field)
            if !isnothing(var_prop) && length(var_prop) > 0
                field_value = getfield(priority_nt, var_field)
            end
        end
        combined_nt = set_namedtuple_field(combined_nt,
            (var_field, field_value))
    end
    return combined_nt
end


"""
    table_to_namedtuple(tbl; replace_missing_values=false)

Convert a table to a NamedTuple.

# Arguments
- `tbl`: The input table
- `replace_missing_values`: Whether to replace missing values with empty strings

# Returns
- A NamedTuple representation of the table

# Examples

```jldoctest
julia> using UtilsKit

julia> tbl = list_to_table((:a, :b));

julia> table_to_namedtuple(tbl)
(name = [:a, :b],)
```
"""
function table_to_namedtuple(tbl; replace_missing_values=false)
    a_nt = (;)
    for a_p in propertynames(tbl)
        t_p = getproperty(tbl, a_p)
        values_to_replace = t_p
        if replace_missing_values
            values_to_replace = [ismissing(t_p[i]) ? "" : t_p[i] for i in eachindex(t_p)]
        end
        values_to_replace = [values_to_replace...]
        a_nt = set_namedtuple_field(a_nt, (a_p, values_to_replace))
    end
    return a_nt
end


"""
    _collectTypes!(d, all_types)

Collect all types from nested namedtuples.

# Arguments
- `d`: The input data structure
- `all_types`: Array to store collected types

# Returns
- Array of unique types found in the data structure
"""
function _collectTypes!(data, types)
    for k ∈ keys(data)
        if data[k] isa NamedTuple
            push!(types, typeof(data[k]))
            _collectTypes!(data[k], types)
        else
            push!(types, typeof(data[k]))
        end
    end
    return unique(types)
end



"""
    namedtuple_from_names_values(input_data, input_names)

Create a NamedTuple from input data and names.

# Arguments
- `input_data`: Vector of data values
- `input_names`: Vector of names for the fields

# Returns
- A NamedTuple with the specified names and values

# Examples

```jldoctest
julia> using UtilsKit

julia> namedtuple_from_names_values([1, 2], [:a, :b])
(a = 1, b = 2)
```
"""
function namedtuple_from_names_values(values, names)
    return (; Pair.(names, values)...)
end



export merge_namedtuple

"""
Merges algorithm options by combining default options with user-provided options.

This function takes two option dictionaries and combines them, with user options
taking precedence over default options.

# Arguments
- `def_o`: Default options object (NamedTuple/Struct/Dictionary) containing baseline algorithm parameters
- `u_o`: User options object containing user-specified overrides

# Returns
- A merged object containing the combined algorithm options

# Examples

```jldoctest
julia> using UtilsKit

julia> merge_namedtuple((a=1, b=2), (b=99,))
(a = 1, b = 99)
```
"""
function merge_namedtuple(defaults, overrides)
    merged = deepcopy(defaults)
    for field in keys(overrides)
        merged = _setFieldValue(merged, field, getproperty(overrides, field))
    end
    return merged
end

"""
    _setFieldValue(o, p, v)

Set a field in an options object.

# Arguments
- `o`: The options object (NamedTuple or mutable struct)
- `p`: The field name to update
- `v`: The new value to assign

# Variants:
1. **For `NamedTuple` options**:
   - Updates the field in an immutable `NamedTuple` by creating a new `NamedTuple` with the updated value.
   - Uses the `@set` macro for immutability handling.

2. **For mutable struct options (e.g., BayesOpt)**:
   - Directly updates the field in the mutable struct using `Base.setproperty!`.

# Returns:
- The updated options object with the specified field modified.

# Notes:
- This function is used internally by `merge_namedtuple` to handle field updates in both mutable and immutable options objects.
- Ensures compatibility with different types of optimization algorithm configurations.

# Examples:
1. **Updating a `NamedTuple`**:
```julia
options = (max_iters = 100, tol = 1e-6)
updated_options = _setFieldValue(options, :tol, 1e-8)
```

2. **Updating a mutable struct**:
```julia
mutable struct BayesOptConfig
    max_iters::Int
    tol::Float64
end
config = BayesOptConfig(100, 1e-6)
updated_config = _setFieldValue(config, :tol, 1e-8)
```
"""
function _setFieldValue end

function _setFieldValue(options::NamedTuple, field, value)
    options = @set options[field] = value
    return options
end


function _setFieldValue(options, field, value)
    Base.setproperty!(options, field, value)
    return options
end




"""
    duplicates(x::AbstractArray{T}) where T

Finds and returns a vector of duplicate elements in the input array.

# Arguments:
- `x`: The input array.

# Returns:
A vector of duplicate elements.

# Examples

```jldoctest
julia> using UtilsKit

julia> duplicates([1, 2, 2, 3, 3, 3])
2-element Vector{Int64}:
 2
 3
```
"""
function duplicates(items::AbstractArray{T}) where {T}
    xs = sort(items)
    duplicatedvector = T[]
    for i ∈ eachindex(xs)[2:end]
        if (
            isequal(xs[i], xs[i-1]) &&
            (length(duplicatedvector) == 0 || !isequal(duplicatedvector[end], xs[i]))
        )
            push!(duplicatedvector, xs[i])
        end
    end
    return duplicatedvector
end



"""
    drop_empty_namedtuple_fields(tpl::NamedTuple)

Remove all empty fields from a NamedTuple.

# Arguments
- `tpl`: The input NamedTuple

# Returns
- A new NamedTuple with empty fields removed

# Examples

```jldoctest
julia> using UtilsKit

julia> drop_empty_namedtuple_fields((a=(;), b=(x=1,)))
(b = (x = 1,),)
```
"""
function drop_empty_namedtuple_fields(nt::NamedTuple)
    indx = findall(x -> x != NamedTuple(), values(nt))
    nkeys, nvals = tuple(collect(keys(nt))[indx]...), values(nt)[indx]
    return NamedTuple{nkeys}(nvals)
end


"""
    set_namedtuple_subfield(tpl, fieldname, vals)

Set a subfield of a NamedTuple.

# Arguments
- `tpl`: The input NamedTuple
- `fieldname`: The name of the field to set
- `vals`: Tuple containing subfield name and value

# Returns
- A new NamedTuple with the updated subfield

# Examples

```jldoctest
julia> using UtilsKit

julia> set_namedtuple_subfield((a=(;),), :a, (:x, 1))
(a = (x = 1,),)
```
"""
function set_namedtuple_subfield(nt::NamedTuple, fieldname::Symbol, vals::Tuple{Symbol,Any})
    if !hasproperty(nt, fieldname)
        nt = set_namedtuple_field(nt, (fieldname, (;)))
    end
    return (; nt..., fieldname => (; getfield(nt, fieldname)..., first(vals) => last(vals)))
end


"""
    set_namedtuple_field(tpl, vals)

Set a field in a NamedTuple.

# Arguments
- `tpl`: The input NamedTuple
- `vals`: Tuple containing field name and value

# Returns
- A new NamedTuple with the updated field

# Examples

```jldoctest
julia> using UtilsKit

julia> set_namedtuple_field((a=1,), (:b, 2))
(a = 1, b = 2)
```
"""
set_namedtuple_field(nt::NamedTuple, vals::Tuple{Symbol,Any}) = (; nt..., first(vals) => last(vals))



"""
    list_to_table(_list)

Converts a list or tuple into a table using `TypedTables`.

# Arguments:
- `_list`: The input list or tuple.

# Returns:
A table representation of the input list.

# Examples

```jldoctest
julia> using UtilsKit

julia> tbl = list_to_table((:a, :b));

julia> propertynames(tbl)
(:name,)
```
"""
function list_to_table(list)
    table = Table((; name=[list...]))
    return table
end

"""
    tc_print(d; _color=true, _type=true, _value=true, t_op=true)

Print a formatted representation of a data structure with type annotations and colors.

# Arguments
- `d`: The object to print
- `_color`: Whether to use colors (default: true)
- `_type`: Whether to show types (default: false)
- `_value`: Whether to show values (default: true)
- `_tspace`: Starting tab space
- `space_pad`: Additional space padding

# Returns
- Nothing (prints to console)

# Examples

```jldoctest
julia> using UtilsKit

julia> redirect_stdout(devnull) do
           tc_print((a=1, b=(c=2,)); _color=false)
       end === nothing
true
```
"""
function tc_print(data; _color=true, _type=false, _value=true, _tspace="", space_pad="")
    colors_types = _collectTypeColors(data; _color=_color)
    # aio = AnnotatedIOBuffer()
    lc = nothing
    ttf = _tspace * space_pad
    for k ∈ sort(collect(keys(data)))
        if data[k] isa NamedTuple
            tp = " = (;"
            if length(data[k]) > 0
                printstyled(Crayon(; foreground=colors_types[typeof(data[k])]), "$(k)$(tp)\n")
            else
                printstyled(Crayon(; foreground=colors_types[typeof(data[k])]), "$(k)$(tp)")
            end
            tc_print(data[k]; _color=_color, _type=_type, _value=_value, _tspace=ttf, space_pad="  ")
        else
            if _type == true
                tp = "::$(typeof(data[k]))"
                if tp == "::NT"
                    tp = "::Tuple"
                end
            else
                tp = ""
            end
            if typeof(data[k]) <: Float32
                to_print = "$(ttf) $(k) = $(data[k])f0$(tp),\n"
                if !_value
                    to_print = "$(ttf) $(k)$(tp),\n"
                end
                print(Crayon(; foreground=colors_types[typeof(data[k])]),
                    to_print)
            elseif typeof(data[k]) <: AbstractVector
                to_print = "$(ttf) $(k) = $(data[k])$(tp),\n"
                if !_value
                    to_print = "$(ttf) $(k)$(tp),\n"
                end
                print(Crayon(; foreground=colors_types[typeof(data[k])]), to_print)
            elseif typeof(data[k]) <: Matrix
                print(Crayon(; foreground=colors_types[typeof(data[k])]), "$(ttf) $(k) = [\n")
                tt_row = repeat(ttf[1], length(ttf) + 1)
                for row ∈ eachrow(data[k])
                    row_str = nothing
                    if eltype(row) == Float32
                        row_str = join(row, "f0 ") * "f0"
                    else
                        row_str = join(row, " ")
                    end
                    print(Crayon(; foreground=colors_types[typeof(data[k])]),
                        "$(tt_row) $(row_str);\n")
                end
                print(Crayon(; foreground=colors_types[typeof(data[k])]), "$(tt_row) ]$(tp),\n")
            else
                to_print = "$(ttf) $(k) = $(data[k])$(tp),"
                if !_value
                    to_print = "$(ttf) $(k)$(tp),"
                end
                print(Crayon(; foreground=colors_types[typeof(data[k])]),
                    to_print)
            end
            lc = colors_types[typeof(data[k])]
        end
        # end
        if _type == true
            _tspace = _tspace * " "
            print(Crayon(; foreground=lc), " $(ttf))::NamedTuple,\n")
        else
            if data[k] isa NamedTuple
                print(Crayon(; foreground=lc), "$(ttf)),\n")
            end
        end
    end
end

end # module ForCollections

