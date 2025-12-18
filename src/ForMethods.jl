"""
    UtilsKit.ForMethods

Method/type introspection helpers:
- list method signatures with file/line info
- summarize type hierarchies and subtypes
- utilities to collect module definitions and provide `purpose` hooks
"""
module ForMethods

using InteractiveUtils: subtypes

export do_nothing
export get_method_types
export get_definitions
export get_method_signatures
export methods_of
export print_method_signatures
export purpose
export show_methods_of
export val_to_symbol


"""
    do_nothing(dat)

Returns the input as is, without any modifications.

# Arguments:
- `dat`: The input data.

# Returns:
The same input data.

# Examples

```jldoctest
julia> using UtilsKit

julia> do_nothing(1)
1
```
"""
function do_nothing(x)
    return x
end



# ---------------------------------------------------------------------------
# get_method_signatures / print_method_signatures
# ---------------------------------------------------------------------------

"""
    get_method_signatures(f::Function; path::Symbol = :relative_pwd) -> Vector{String}

Return method signature strings for `f`, including file/line information.
`path` controls how file paths are shown:
- `:relative_pwd` (default): paths relative to the current working directory (`pwd()`).
- `:relative_root`: paths relative to the root of the defining package.
- `:absolute`: absolute paths.

Default-arg wrapper methods are collapsed: for each unique `(file,line,module)` only the largest-arity method is kept.

# Examples

```jldoctest
julia> using UtilsKit

julia> sigs = get_method_signatures(+);

julia> sigs isa Vector{String}
true
```
"""
function get_method_signatures(f::Function; path::Symbol = :relative_pwd)
    path in (:relative_pwd, :relative_root, :absolute) ||
        error("Invalid `path=$(path)`. Expected :relative_pwd, :relative_root, or :absolute.")
    root_pkg = Base.moduleroot(parentmodule(f))
    root_path = pathof(root_pkg)
    package_root = isnothing(root_path) ? nothing : normpath(joinpath(dirname(root_path), ".."))
    pwd_root = try
        pwd()
    catch
        nothing
    end

    selected = Dict{Tuple{Any,Int,Module},Method}()
    for m in methods(f)
        key = (m.file, m.line, m.module)
        nargs = length(Base.unwrap_unionall(m.sig).parameters) - 1
        if haskey(selected, key)
            prev = selected[key]
            prev_nargs = length(Base.unwrap_unionall(prev.sig).parameters) - 1
            if nargs > prev_nargs
                selected[key] = m
            end
        else
            selected[key] = m
        end
    end

    sigs = String[]
    for m in values(selected)
        sig = Base.unwrap_unionall(m.sig)
        types = sig.parameters[2:end]
        sig_str = string(nameof(f)) * "(" * join(("::" * string(t) for t in types), ", ") * ")"

        file_str = try
            String(m.file)
        catch
            ""
        end
        loc = ""
        if !isempty(file_str)
            abs_file = try
                abspath(Base.expanduser(file_str))
            catch
                file_str
            end
            shown = if path == :absolute
                abs_file
            elseif path == :relative_root
                if isnothing(package_root)
                    abs_file
                else
                    try
                        relpath(abs_file, package_root)
                    catch
                        abs_file
                    end
                end
            else # :relative_pwd
                if isnothing(pwd_root)
                    abs_file
                else
                    try
                        relpath(abs_file, pwd_root)
                    catch
                        abs_file
                    end
                end
            end
            loc = "$(shown):$(m.line)"
        end
        # Put the location first so terminals/editors are more likely to detect a clickable `path:line` link.
        # (Some linkifiers get confused when `::Type` annotations appear before the `path:line` segment.)
        if isempty(loc)
            push!(sigs, "$(sig_str) @ $(m.module)")
        else
            push!(sigs, "$(loc)  $(sig_str) @ $(m.module)")
        end
    end
    return sigs
end


"""
    get_method_types(fn)

Retrieve the types of the arguments for all methods of a given function.

# Arguments
- `fn`: The function for which the method argument types are to be retrieved.

# Returns
- A vector containing the types of the arguments for each method of the function.

# Example
```julia
function example_function(x::Int, y::String) end
function example_function(x::Float64, y::Bool) end

types = get_method_types(example_function)
println(types) # Output: [Int64, Float64]
```

# Examples

```jldoctest
julia> using UtilsKit

julia> get_method_types(+) isa AbstractVector
true
```
"""
function get_method_types(f)
    # Get the method table for the function
    mt = methods(f)
    # Extract the types of the first method
    method_types = map(m -> Base.unwrap_unionall(m.sig).parameters[2], mt)
    return method_types
end

"""
    methods_of(T::Type; ds="", is_subtype=false, bullet=" - ")
    methods_of(M::Module; the_type=Type, internal_only=true)

Display subtypes and their purposes for a type or module in a formatted way.

# Description
This function provides a hierarchical display of subtypes and their purposes for a given type or module. For types, it shows a tree-like structure of subtypes and their purposes. For modules, it shows all defined types and their subtypes.

# Arguments
- `T::Type`: The type whose subtypes should be displayed
- `M::Module`: The module whose types should be displayed
- `ds::String`: Delimiter string between entries (default: newline)
- `is_subtype::Bool`: Whether to include nested subtypes (default: false)
- `bullet::String`: Bullet point for each entry (default: " - ")
- `the_type::Type`: Type of objects to display in module (default: Type)
- `internal_only::Bool`: Whether to only show internal definitions (default: true)

# Returns
- A formatted string showing the hierarchy of subtypes and their purposes

# Examples
```julia
# Display subtypes of a type
methods_of(LandEcosystem)

# Display with custom formatting
methods_of(LandEcosystem; ds=", ", bullet=" * ")

# Display including nested subtypes
methods_of(LandEcosystem; is_subtype=true)

# Display types in a module
methods_of(MyModule)

# Display specific types in a module
methods_of(MyModule; the_type=Function)
```

# Extended help
The output format for types is:
```
## TypeName
Purpose of the type

## Available methods/subtypes:
 - subtype1: purpose
 - subtype2: purpose
    - nested_subtype1: purpose
    - nested_subtype2: purpose
```

If no subtypes exist, it will show " - `None`".

# Examples

```jldoctest
julia> using UtilsKit

julia> occursin("Available", methods_of(Int))
true
```
"""
function methods_of end

function methods_of(T::Type; ds="\n", is_subtype=false, bullet=" - ", purpose_function=purpose)
    sub_types = subtypes(T)
    type_name = nameof(T)
    if !is_subtype
        ds *= "## $type_name\n$(purpose_function(T))\n\n"
        ds *= "## Available methods/subtypes:\n"
    end

    if isempty(sub_types) && !is_subtype
        ds *= " - `None`\n"
    else
        for sub_type in sub_types
            sub_type_name = nameof(sub_type)
            ds *= "$bullet `$(sub_type_name)`: $(purpose_function(sub_type)) \n"
            sub_sub_types = subtypes(sub_type)
            if !isempty(sub_sub_types)
                ds = methods_of(sub_type; ds=ds, is_subtype=true, bullet="    " * bullet, purpose_function=purpose_function)
            end
        end
    end
    return ds
end

function methods_of(M::Module; the_type=Type, internal_only=true, purpose_function=purpose)
    defined_types = get_definitions(M, the_type, internal_only=internal_only)
    ds = "\n"
    foreach(defined_types) do defined_type
        M_type = getproperty(M, nameof(defined_type))
        M_subtypes = subtypes(M_type)
        is_subtype = isempty(M_subtypes)
        ds = is_subtype ? ds : ds * "\n"
        ds = methods_of(M_type; ds=ds, is_subtype=is_subtype, bullet=" - ", purpose_function=purpose_function)
    end
    return ds
end


"""
    print_method_signatures(f::Function; path::Symbol = :relative_pwd, io::IO = stdout, path_color::Symbol = :cyan) -> Nothing

Print method signatures as a bulleted list.

- The leading `path:line` segment (when present) is colored (defaults to `:cyan`).
- Uses [`get_method_signatures`](@ref) under the hood.

# Examples

```jldoctest
julia> using UtilsKit

julia> redirect_stdout(devnull) do
           print_method_signatures(+)
       end === nothing
true
```
"""
function print_method_signatures(f::Function; path::Symbol = :relative_pwd, io::IO = stdout, path_color::Symbol = :cyan)
    for s in get_method_signatures(f; path=path)
        parts = split(s, "  ", limit=2)
        if length(parts) == 2
            loc, rest = parts[1], parts[2]
            print(io, "- ")
            printstyled(io, loc; color=path_color, bold=true)
            println(io)
            println(io, "  ", rest)
        else
            println(io, "- ", s)
        end
    end
    return nothing
end



"""
    show_methods_of(T)

Display the subtypes and their purposes of a type in a formatted way.

# Description
This function displays the hierarchical structure of subtypes and their purposes for a given type. It uses `methods_of` internally to generate the formatted output and prints it to the console.

# Arguments
- `T`: The type whose subtypes and purposes should be displayed

# Returns
- `nothing`

# Examples
```julia
# Display subtypes of LandEcosystem
show_methods_of(LandEcosystem)

# Display subtypes of a specific model type
show_methods_of(ambientCO2)
```

# Extended help
The output format is the same as `methods_of`, showing:
```
## TypeName
Purpose of the type

## Available methods/subtypes:
 - subtype1: purpose
 - subtype2: purpose
    - nested_subtype1: purpose
    - nested_subtype2: purpose
```

This function is a convenience wrapper around `methods_of` that automatically prints the output to the console.

# Examples

```jldoctest
julia> using UtilsKit

julia> redirect_stdout(devnull) do
           show_methods_of(Int)
       end === nothing
true
```
"""
function show_methods_of(typ; purpose_function=Base.Docs.doc)
    println(methods_of(typ, purpose_function=purpose_function))
    return nothing
end

"""
get_definitions(a_module, what_to_get; internal_only=true)

Returns all defined (and optionally internal) objects in a module.

# Arguments
- `a_module`: The module to search for defined things
- `what_to_get`: The type of things to get (e.g., Type, Function)
- `internal_only`: Whether to only include internal definitions (default: true)

# Returns
- An array of all defined things in the module

# Example
```julia
# Get all defined types in a module
defined_types = get_definitions(MyModule, Type)
```

# Examples

```jldoctest
julia> using UtilsKit

julia> get_definitions(UtilsKit, Function; internal_only=false) isa Vector
true
```
"""
function get_definitions(mod::Module, kind; internal_only=true)
    all_defined_things = filter(x -> isdefined(mod, x) && isa(getproperty(mod, x), kind), names(mod))
    defined_things = all_defined_things
    if internal_only
        defined_things = []
        for d_thing in all_defined_things
            d = getproperty(mod, d_thing)
            d_parent = parentmodule(d)
            if nameof(d_parent) == nameof(mod)
                push!(defined_things, d)
            end
        end
    end
    return defined_things
end



"""
    purpose(T::Type)

Returns a string describing the purpose of a type.

# Description
- This is a base function that should be extended by each package for their specific types.
- `purpose(::Type{T})` should return a descriptive string explaining the role / meaning of `T`.
- If the purpose is not defined for a specific type, the default implementation provides guidance on how to define it.


# Arguments
- `T::Type`: The type whose purpose should be described

# Returns
- A string describing the purpose of the type
    
# Example
```julia
# Define the purpose for a specific model
purpose(::Type{BayesOptKMaternARD5}) = "Bayesian Optimization using Matern 5/2 kernel with Automatic Relevance Determination from BayesOpt.jl"

# Retrieve the purpose
println(purpose(BayesOptKMaternARD5))  # Output: "Bayesian Optimization using Matern 5/2 kernel with Automatic Relevance Determination from BayesOpt.jl"
```

# Examples

```jldoctest
julia> using UtilsKit

julia> occursin("Undefined purpose", purpose(Int))
true
```
"""
function purpose end

purpose(T) = "Undefined purpose for $(nameof(T)) of type $(typeof(T)). Add `purpose(::Type{$(nameof(T))}) = \"the_purpose\"` in appropriate function/type definition file."



"""
    val_to_symbol(val)

Returns the symbol corresponding to the type of the input value.

# Arguments:
- `val`: The input value.

# Returns:
A `Symbol` representing the type of the input value.

# Examples

```jldoctest
julia> using UtilsKit

julia> val_to_symbol(Val(:x))
:x
```
"""
function val_to_symbol(x)
    return typeof(x).parameters[1]
end

end # module ForMethods