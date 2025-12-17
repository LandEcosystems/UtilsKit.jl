"""
    UtilsKit.ForArray

Array-focused utilities:
- booleanization and masking helpers
- diagonal/off-diagonal helpers for matrices
- lightweight view/stack helpers for arrays
"""
module ForArray

using ..ForNumber: replaceInvalid

export booleanizeArray
export flagLower, flagOffDiag, flagUpper
export getArrayView
export offDiag, offDiagUpper, offDiagLower
export stackArrays

"""
    booleanizeArray(_array)

Converts an array into a boolean array where elements greater than zero are `true`.

# Arguments:
- `_array`: The input array to be converted.

# Returns:
A boolean array with the same dimensions as `_array`.

# Examples

```jldoctest
julia> using UtilsKit

julia> booleanizeArray([1.0, 0.0, -1.0])
3-element BitVector:
 1
 0
 0
```
"""
function booleanizeArray(arr)
    fill_value = 0.0
    arr = map(x -> replaceInvalid(x, fill_value), arr)
    arr_bits = arr .> fill_value
    return arr_bits
end



"""
    flagOffDiag(A::AbstractMatrix)

returns a matrix of same shape as input with 1 for all non diagonal elements

# Examples

```jldoctest
julia> using UtilsKit

julia> flagOffDiag([1 2; 3 4])
2×2 Matrix{Float64}:
 0.0  1.0
 1.0  0.0
```
"""
function flagOffDiag(A::AbstractMatrix)
    o_mat = zeros(size(A))
    for ι ∈ CartesianIndices(A)
        if ι[1] ≠ ι[2]
            o_mat[ι] = 1
        end
    end
    return o_mat
end


"""
    flagLower(A::AbstractMatrix)

returns a matrix of same shape as input with 1 for all below diagonal elements and 0 elsewhere

# Examples

```jldoctest
julia> using UtilsKit

julia> flagLower([1 2; 3 4])
2×2 Matrix{Float64}:
 0.0  0.0
 1.0  0.0
```
"""
function flagLower(A::AbstractMatrix)
    o_mat = zeros(size(A))
    for ι ∈ CartesianIndices(A)
        if ι[1] > ι[2]
            o_mat[ι] = 1
        end
    end
    return o_mat
end

"""
    flagUpper(A::AbstractMatrix)

returns a matrix of same shape as input with 1 for all above diagonal elements and 0 elsewhere

# Examples

```jldoctest
julia> using UtilsKit

julia> flagUpper([1 2; 3 4])
2×2 Matrix{Float64}:
 0.0  1.0
 0.0  0.0
```
"""
function flagUpper(A::AbstractMatrix)
    o_mat = zeros(size(A))
    for ι ∈ CartesianIndices(A)
        if ι[1] < ι[2]
            o_mat[ι] = 1
        end
    end
    return o_mat
end



"""
    getArrayView(data::AbstractArray{<:Any, N}, idxs::Tuple{Vararg{Int}}) where N

Creates a view of the input array `_dat` based on the provided indices tuple `inds`.

# Arguments:
- `_dat`: The input array from which a view is created. Can be of any dimensionality.
- `inds`: A tuple of integer indices specifying the spatial or temporal dimensions to slice.

# Returns:
- A `SubArray` view of `_dat` corresponding to the specified indices.

# Notes:
- The function supports arrays of arbitrary dimensions (`N`).
- For arrays with fewer dimensions than the size of `inds`, an error is thrown.
- For higher-dimensional arrays, the indices are applied to the last dimensions, while earlier dimensions are accessed using `Colon()` (i.e., all elements are included).
- This function avoids copying data by creating a view, which is efficient for large arrays.

# Error Handling:
- Throws an error if the dimensionality of `_dat` is less than the size of `inds`.

# Examples

```jldoctest
julia> using UtilsKit

julia> A = Matrix(reshape(1:9, 3, 3))
3×3 Matrix{Int64}:
 1  4  7
 2  5  8
 3  6  9

julia> getArrayView(A, (2, 3))[]
8
```
"""
function getArrayView end

function getArrayView(data::AbstractArray{<:Any,N}, idxs::Tuple{Int}) where N
    if N == 1
        view(data, first(idxs))
    else
        dim = 1 
        d_size = size(data)
        view_inds = map(d_size) do _
            vi = dim == length(d_size) ? first(idxs) : Colon()
            dim += 1 
            vi
        end
        view(data, view_inds...)
    end
end

function getArrayView(data::AbstractArray{<:Any,N}, idxs::Tuple{Int,Int}) where N
    if N == 1
        error("cannot get a view of 1-dimensional array in space using spatial indices tuple of size 2")
    elseif N == 2
        view(data, first(idxs), last(idxs))
    else
        dim = 1 
        d_size = size(data)
        view_inds = map(d_size) do _
            vi = dim == length(d_size) ? last(idxs) : dim == length(d_size) - 1 ? first(idxs) : Colon()
            dim += 1 
            vi
        end
        view(data, view_inds...)
    end
end


function getArrayView(data::AbstractArray{<:Any,N}, idxs::Tuple{Int,Int,Int}) where N
    if N < 3
        error("cannot get a view of smaller than 3-dimensional array in space using spatial indices tuple of size 3")
    elseif N == 3
        view(data, first(idxs), idxs[2], last(idxs))
    else
        dim = 1 
        d_size = size(data)
        view_inds = map(d_size) do _
            vi = dim == length(d_size) ? last(idxs) : dim == length(d_size) - 1 ? idxs[2] : dim == length(d_size) - 2 ? first(idxs) : Colon()
            dim += 1 
            vi
        end
        view(data, view_inds...)
    end
end


function getArrayView(data::AbstractArray{<:Any,N}, idxs::Tuple{Int,Int,Int,Int}) where N
    if N < 4
        error("cannot get a view of smaller than 4-dimensional array in space using spatial indices tuple of size 4")
    elseif N == 4
        view(data, first(idxs), idxs[2], idxs[3], last(idxs))
    else
        dim = 1 
        d_size = size(data)
        view_inds = map(d_size) do _
            vi = dim == length(d_size) ? last(idxs) : dim == length(d_size) - 1 ? idxs[3] : dim == length(d_size) - 2 ? idxs[2] : dim == length(d_size) - 3 ? first(idxs) : Colon()
            dim += 1 
            vi
        end
        view(data, view_inds...)
    end
end


"""
    offDiag(A::AbstractMatrix)

returns a vector comprising of off diagonal elements of a matrix

# Examples

```jldoctest
julia> using UtilsKit

julia> collect(offDiag([1 2; 3 4]))
2-element Vector{Int64}:
 3
 2
```
"""
function offDiag(A::AbstractMatrix)
    @view A[[ι for ι ∈ CartesianIndices(A) if ι[1] ≠ ι[2]]]
end

"""
    offDiagLower(A::AbstractMatrix)

returns a vector comprising of below diagonal elements of a matrix

# Examples

```jldoctest
julia> using UtilsKit

julia> collect(offDiagLower([1 2; 3 4]))
1-element Vector{Int64}:
 3
```
"""
function offDiagLower(A::AbstractMatrix)
    @view A[[ι for ι ∈ CartesianIndices(A) if ι[1] > ι[2]]]
end

"""
    offDiagUpper(A::AbstractMatrix)

returns a vector comprising of above diagonal elements of a matrix

# Examples

```jldoctest
julia> using UtilsKit

julia> collect(offDiagUpper([1 2; 3 4]))
1-element Vector{Int64}:
 2
```
"""
function offDiagUpper(A::AbstractMatrix)
    @view A[[ι for ι ∈ CartesianIndices(A) if ι[1] < ι[2]]]
end



"""
    stackArrays(arr)

Stacks a collection of arrays along the first dimension.

# Arguments:
- `arr`: A collection of arrays to be stacked. All arrays must have the same size along their non-stacked dimensions.

# Returns:
- A single array where the input arrays are stacked along the first dimension.
- If the arrays are 1D, the result is a vector.

# Notes:
- The function uses `hcat` to horizontally concatenate the arrays and then creates a view to stack them along the first dimension.
- If the first dimension of the input arrays has a size of 1, the result is flattened into a vector.
- This function is efficient and avoids unnecessary data copying.

# Examples

```jldoctest
julia> using UtilsKit

julia> Matrix(stackArrays(([1, 2], [3, 4])))
2×2 Matrix{Int64}:
 1  3
 2  4
```
"""
function stackArrays(arr)
    result = view(reduce(hcat, arr), :, :)
    return length(arr[1]) == 1 ? vec(result) : result
end

end # module ForArray