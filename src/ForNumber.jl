"""
    UtilsKit.ForNumber

Number utilities:
- clamping and min/max helpers
- invalid-number detection (`nothing`/`missing`/`NaN`/`Inf`)
- invalid-value replacement and simple helpers like cumulative sum
"""
module ForNumber

export clamp_zero_one
export cumulative_sum!
export safe_divide
export is_invalid_number
export replace_invalid_number
export at_least_zero, at_least_one, at_most_zero, at_most_one

"""
    clamp_zero_one(num)

returns max(min(num, 1), 0)

# Examples

```jldoctest
julia> using UtilsKit

julia> clamp_zero_one(2.0)
1.0

julia> clamp_zero_one(-0.5)
0.0
```
"""
function clamp_zero_one(num)
    return clamp(num, zero(num), one(num))
end

"""
    cumulative_sum!(output::AbstractVector, input::AbstractVector)

fill out the output vector with the cumulative sum of elements from input vector

# Examples

```jldoctest
julia> using UtilsKit

julia> out = zeros(Int, 3);

julia> cumulative_sum!(out, [1, 2, 3])
3-element Vector{Int64}:
 1
 3
 6
```
"""
function cumulative_sum!(output::AbstractVector, input::AbstractVector)
    for i ∈ eachindex(input)
        output[i] = sum(input[1:i])
    end
    return output
end



"""
    safe_divide(num, den)

return either a ratio or numerator depending on whether denomitor is a zero

# Examples

```jldoctest
julia> using UtilsKit

julia> safe_divide(1.0, 2.0)
0.5

julia> safe_divide(1.0, 0.0)
1.0
```
"""
function safe_divide(numerator, denominator)
    if !iszero(denominator)
        ratio = numerator / denominator
    else
        ratio = numerator
    end
    return ratio
end


"""
    is_invalid_number(_data::Number)

Checks if a number is invalid (e.g., `nothing`, `missing`, `NaN`, or `Inf`).

# Arguments:
- `_data`: The input number.

# Returns:
`true` if the number is invalid, otherwise `false`.

# Examples

```jldoctest
julia> using UtilsKit

julia> is_invalid_number(NaN)
true

julia> is_invalid_number(1.0)
false
```
"""
function is_invalid_number(x)
    return isnothing(x) || ismissing(x) || isnan(x) || isinf(x)
end



"""
    at_least_zero(num)

returns max(num, 0)

# Examples

```jldoctest
julia> using UtilsKit

julia> at_least_zero(-1.0)
0.0
```
"""
function at_least_zero(num)
    return max(num, zero(num))
end


"""
    at_least_one(num)

returns max(num, 1)

# Examples

```jldoctest
julia> using UtilsKit

julia> at_least_one(0.5)
1.0
```
"""
function at_least_one(num)
    return max(num, one(num))
end


"""
    at_most_zero(num)

returns min(num, 0)

# Examples

```jldoctest
julia> using UtilsKit

julia> at_most_zero(1.0)
0.0
```
"""
function at_most_zero(num)
    return min(num, zero(num))
end


"""
    at_most_one(num)

returns min(num, 1)

# Examples

```jldoctest
julia> using UtilsKit

julia> at_most_one(2.0)
1.0
```
"""
function at_most_one(num)
    return min(num, one(num))
end


"""
    replace_invalid_number(_data, _data_fill)

Replaces invalid numbers in the input with a specified fill value.

# Arguments:
- `_data`: The input number.
- `_data_fill`: The value to replace invalid numbers with.

# Returns:
The input number if valid, otherwise the fill value.

# Examples

```jldoctest
julia> using UtilsKit

julia> replace_invalid_number(NaN, 0.0)
0.0

julia> replace_invalid_number(2.0, 0.0)
2.0
```
"""
function replace_invalid_number(x, fill_value)
    x = is_invalid_number(x) ? fill_value : x
    return x
end

end # module ForNumber
