# OmniTools.jl

[![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] [![][ci-img]][ci-url] [![][codecov-img]][codecov-url] [![Julia][julia-img]][julia-url] [![License: EUPL-1.2](https://img.shields.io/badge/License-EUPL--1.2-blue)](https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12)

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://LandEcosystems.github.io/OmniTools.jl/dev/

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://LandEcosystems.github.io/OmniTools.jl/stable/

[ci-img]: https://github.com/LandEcosystems/OmniTools.jl/workflows/CI/badge.svg
[ci-url]: https://github.com/LandEcosystems/OmniTools.jl/actions?query=workflow%3ACI

[codecov-img]: https://codecov.io/gh/LandEcosystems/OmniTools.jl/branch/main/graph/badge.svg
[codecov-url]: https://codecov.io/gh/LandEcosystems/OmniTools.jl

[julia-img]: https://img.shields.io/badge/julia-v1.10+-blue.svg
[julia-url]: https://julialang.org/

A comprehensive utility package providing foundational functions for data manipulation, collections management, display formatting, and type introspection.

## Features

- **Array Operations**: Booleanization, matrix diagonal operations, array stacking, and view operations
- **Collections Management**: Dictionary to NamedTuple conversion, NamedTuple manipulation, table operations
- **String Utilities**: Case conversion, formatting, and prefix/suffix manipulation
- **Number Utilities**: Value clamping, validation, and invalid number handling
- **Display & Formatting**: Colored terminal output, ASCII art banners, logging utilities
- **Type Introspection**: Type hierarchy exploration, docstring generation, method utilities
- **Performance**: Type-stable functions designed for performance-critical workflows

## Submodules (optional)

The package keeps a flat API for convenience (e.g. `positive_mask(...)`), but also exposes submodules:

```julia
using OmniTools

OmniTools.ForArray.positive_mask([1, 0, -1])
OmniTools.ForNumber.replace_invalid_number(NaN, 0.0)
```

Note: long-tuple utilities live under `OmniTools.ForLongTuples` to avoid naming conflicts with `Base` and with the exported `LongTuple` type.

## Installation

```julia
using Pkg
Pkg.add("OmniTools")
```

## Quick Start

```julia
using OmniTools

# Convert dictionary to NamedTuple
dict = Dict(:a => 1, :b => 2, :c => Dict(:d => 3))
nt = dict_to_namedtuple(dict)

# Display a banner (FIGlet)
print_figlet_banner("OmniTools")

# Work with arrays
arr = [1, 2, 3, 0, -1, 5]
bool_arr = positive_mask(arr)

# String utilities
str = to_uppercase_first("hello_world", "Time")  # Returns :TimeHelloWorld

```

## Main Functionality

### Array Operations

- `positive_mask`: Convert arrays to boolean masks
- `upper_triangle_mask`, `lower_triangle_mask`, `off_diagonal_mask`: Matrix mask helpers
- `off_diagonal_elements`, `upper_off_diagonal_elements`, `lower_off_diagonal_elements`: Extract off-diagonal elements
- `stack_as_columns`: Stack multiple arrays as columns
- `view_at_trailing_indices`: Create array views using trailing indices

### Collections and Data Structures

- `dict_to_namedtuple`: Convert nested dictionaries to NamedTuples
- `namedtuple_from_names_values`: Create NamedTuples from names + values
- `drop_namedtuple_fields`: Remove fields from NamedTuples
- `merge_namedtuple_prefer_nonempty`: Combine NamedTuples (preferring non-empty fields)
- `table_to_namedtuple`: Convert tables to NamedTuples
- `set_namedtuple_field`, `set_namedtuple_subfield`: Modify NamedTuple fields
- `list_to_table`: Convert lists to a `TypedTables.Table`
- `duplicates`: Find duplicate elements

### String Utilities

- `to_uppercase_first`: Convert strings to camelCase/PascalCase

### Number Utilities

- `clamp_zero_one`: Clamp values between 0 and 1
- `at_least_zero`, `at_least_one`, `at_most_zero`, `at_most_one`: Value limiting functions
- `is_invalid_number`: Check for invalid numbers
- `replace_invalid_number`: Replace invalid values
- `safe_divide`: Safe divide (returns numerator if denominator is zero)
- `cumulative_sum!`: In-place cumulative sum (dest-first: `cumulative_sum!(output, input)`)

### Display and Formatting

- `print_figlet_banner`: Display ASCII art banners (FIGlet)
- `print_info`: Display formatted information
- `print_info_separator`: Display separators
- `set_log_level`: Configure logging levels
- `toggle_type_abbrev_in_stacktrace`: Toggle stack trace display

### Type and Documentation Utilities

- `get_type_docstring`: Generate formatted docstrings for types
- `write_type_docstring`: Write type docstrings to files
- `loop_write_type_docstring`: Batch write type docstrings

## Dependencies

- `Accessors`: Nested data structure access
- `Crayons`: Colored terminal output
- `DataStructures`: Collection utilities
- `FIGlet`: ASCII art generation
- `InteractiveUtils`: REPL utilities
- `Logging`: Logging framework
- `StyledStrings`: Styled text output
- `TypedTables`: Typed table structures

## Documentation

For detailed documentation, see the [OmniTools.jl documentation](https://landecosystems.github.io/OmniTools.jl).

## License

This package is licensed under the EUPL-1.2 (European Union Public Licence v. 1.2). See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please open an issue or pull request in this repository.

## Authors

OmniTools.jl Contributors
