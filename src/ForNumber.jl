"""
    UtilsKit.ForNumber

Number utilities:
- clamping and min/max helpers
- invalid-number detection (`nothing`/`missing`/`NaN`/`Inf`)
- invalid-value replacement and simple helpers like cumulative sum
"""
module ForNumber

export clampZeroOne
export cumSum!
export getFrac
export isInvalid
export maxZero, maxOne, minZero, minOne
export replaceInvalid

"""
    clampZeroOne(num)

returns max(min(num, 1), 0)

# Examples

```jldoctest
julia> using UtilsKit

julia> clampZeroOne(2.0)
1.0

julia> clampZeroOne(-0.5)
0.0
```
"""
function clampZeroOne(num)
    return clamp(num, zero(num), one(num))
end

"""
    cumSum!(i_n::AbstractVector, o_ut::AbstractVector)

fill out the output vector with the cumulative sum of elements from input vector

# Examples

```jldoctest
julia> using UtilsKit

julia> out = zeros(Int, 3);

julia> cumSum!([1, 2, 3], out)
3-element Vector{Int64}:
 1
 3
 6
```
"""
function cumSum!(input::AbstractVector, output::AbstractVector)
    for i ∈ eachindex(input)
        output[i] = sum(input[1:i])
    end
    return output
end



"""
    getFrac(num, den)

return either a ratio or numerator depending on whether denomitor is a zero

# Examples

```jldoctest
julia> using UtilsKit

julia> getFrac(1.0, 2.0)
0.5

julia> getFrac(1.0, 0.0)
1.0
```
"""
function getFrac(numerator, denominator)
    if !iszero(denominator)
        ratio = numerator / denominator
    else
        ratio = numerator
    end
    return ratio
end


"""
    isInvalid(_data::Number)

Checks if a number is invalid (e.g., `nothing`, `missing`, `NaN`, or `Inf`).

# Arguments:
- `_data`: The input number.

# Returns:
`true` if the number is invalid, otherwise `false`.

# Examples

```jldoctest
julia> using UtilsKit

julia> isInvalid(NaN)
true

julia> isInvalid(1.0)
false
```
"""
function isInvalid(x)
    return isnothing(x) || ismissing(x) || isnan(x) || isinf(x)
end



"""
    maxZero(num)

returns max(num, 0)

# Examples

```jldoctest
julia> using UtilsKit

julia> maxZero(-1.0)
0.0
```
"""
function maxZero(num)
    return max(num, zero(num))
end


"""
    maxOne(num)

returns max(num, 1)

# Examples

```jldoctest
julia> using UtilsKit

julia> maxOne(0.5)
1.0
```
"""
function maxOne(num)
    return max(num, one(num))
end


"""
    minZero(num)

returns min(num, 0)

# Examples

```jldoctest
julia> using UtilsKit

julia> minZero(1.0)
0.0
```
"""
function minZero(num)
    return min(num, zero(num))
end


"""
    minOne(num)

returns min(num, 1)

# Examples

```jldoctest
julia> using UtilsKit

julia> minOne(2.0)
1.0
```
"""
function minOne(num)
    return min(num, one(num))
end


"""
    replaceInvalid(_data, _data_fill)

Replaces invalid numbers in the input with a specified fill value.

# Arguments:
- `_data`: The input number.
- `_data_fill`: The value to replace invalid numbers with.

# Returns:
The input number if valid, otherwise the fill value.

# Examples

```jldoctest
julia> using UtilsKit

julia> replaceInvalid(NaN, 0.0)
0.0

julia> replaceInvalid(2.0, 0.0)
2.0
```
"""
function replaceInvalid(x, fill_value)
    x = isInvalid(x) ? fill_value : x
    return x
end

end # module ForNumber
