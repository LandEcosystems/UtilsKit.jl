"""
    UtilsKit.ForString

String utilities (kept in a separate submodule to avoid Base name conflicts).
Currently includes helpers for converting snake_case strings to `Symbol`s.
"""
module ForString

export to_uppercase_first


"""
    to_uppercase_first(s::AbstractString, prefix="")

Converts the first letter of each word in a string to uppercase, removes underscores, and adds a prefix.

# Arguments:
- `s`: The input string.
- `prefix`: A prefix to add to the resulting string (default: "").

# Returns:
A `Symbol` with the transformed string.

# Examples

```jldoctest
julia> using UtilsKit

julia> to_uppercase_first("hello_world", "Time")
:TimeHelloWorld
```
"""
function to_uppercase_first(str::AbstractString, prefix::AbstractString="")
    str_s = Base.String(str)
    prefix_s = Base.String(prefix)
    return Symbol(prefix_s * join(uppercasefirst.(split(str_s, "_"))))
end

end # module ForString
