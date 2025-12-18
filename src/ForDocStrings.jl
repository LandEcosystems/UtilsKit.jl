"""
    UtilsKit.ForDocStrings

Docstring helpers:
- generate structured docstrings for types based on `purpose` and type hierarchies
- write generated docstrings to files (recursively over subtypes)
"""
module ForDocStrings

using Base.Docs: doc as base_doc
using InteractiveUtils: subtypes, supertypes
using ..ForMethods: methods_of, purpose

export loop_write_type_docstring
export write_type_docstring
export get_type_docstring

"""
    get_type_docstring(T::Type)

Generate a docstring for a type in a formatted way.

# Description
This function generates a formatted docstring for a type, including its purpose and type hierarchy.

# Arguments
- `T`: The type for which the docstring is to be generated 

# Returns
- A string containing the formatted docstring for the type.

# Examples

```jldoctest
julia> using UtilsKit

julia> s = get_type_docstring(Int);

julia> occursin("# Int", s)
true
```

"""
function get_type_docstring(typ::Type; purpose_function=purpose)
    doc_string = ""
    doc_string *= "\n# $(nameof(typ))\n\n"
    doc_string *= "$(purpose_function(typ))\n\n"
    doc_string *= "## Type Hierarchy\n\n"
    doc_string *= "```$(join(nameof.(supertypes(typ)), " <: "))```\n\n"
    sub_types = subtypes(typ)
    if length(sub_types) > 0
        doc_string *= "-----\n\n"
        doc_string *= "# Extended help\n\n"
        doc_string *= "## Available methods/subtypes:\n"
        doc_string *= "$(methods_of(typ, is_subtype=true, purpose_function=purpose_function))\n\n"
    end
    return doc_string
end

"""
    write_type_docstring(o_file, T)

Write a docstring for a type to a file.

# Description
This function writes a docstring for a type to a file.

# Arguments
- `o_file`: The file to write the docstring to
- `T`: The type for which the docstring is to be generated

# Returns
- `o_file`: The file with the docstring written to it

# Examples

```jldoctest
julia> using UtilsKit

julia> io = IOBuffer();

julia> struct _TmpNoDocType end;

julia> write_type_docstring(io, _TmpNoDocType) === io
true
```

"""
function write_type_docstring(io, typ; purpose_function=purpose)
    doc_string = base_doc(typ)
    if startswith(string(doc_string), "No documentation found for public symbol")
       write(io, "@doc \"\"\"\n$(get_type_docstring(typ, purpose_function=purpose_function))\n\"\"\"\n")
    #    write(o_file, "$(nameof(T))\n\n")
       write(io, "$(typ)\n\n")
    # else
        # write(o_file, "$(T)\n\n")
        # println("Doc string already exists for $(T), $(doc_string)")
    end
    return io
 end

"""
    loop_write_type_docstring(o_file, T)

Write a docstring for a type to a file.

# Description
This function writes a docstring for a type to a file.

# Arguments
- `o_file`: The file to write the docstring to
- `T`: The type for which the docstring is to be generated

# Returns
- `o_file`: The file with the docstring written to it

# Examples

```jldoctest
julia> using UtilsKit

julia> io = IOBuffer();

julia> abstract type _TmpNoDocAbstract end;

julia> loop_write_type_docstring(io, _TmpNoDocAbstract) === io
true
```

"""
 function loop_write_type_docstring(io, typ; purpose_function=purpose)
    write_type_docstring(io, typ, purpose_function=purpose_function)
    sub_types = subtypes(typ)
    for sub_type in sub_types
       io = loop_write_type_docstring(io, sub_type, purpose_function=purpose_function)
    end
    return io
 end

end # module ForDocStrings
