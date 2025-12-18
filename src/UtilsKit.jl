"""
    UtilsKit

A comprehensive utility package providing foundational functions for data manipulation, collections management, display formatting, and type introspection.

# Overview

`UtilsKit` serves as a core utility library that provides reusable functions for common programming tasks. It is designed to be type-stable and performant.

# Main Features

## Array Operations
- Array booleanization and masking
- Matrix diagonal operations (upper, lower, off-diagonal)
- Array stacking and view operations
- Invalid value handling and replacement

## Collections and Data Structures
- Dictionary to NamedTuple conversion
- NamedTuple manipulation (field dropping, combining, setting)
- Table to NamedTuple conversion
- List tabularization
- Unique/non-unique element detection

## String Utilities
- String case conversion and formatting
- Prefix/suffix manipulation

## Number Utilities
- Value clamping and validation
- Invalid number detection and replacement
- Fractional and cumulative sum operations

## Display and Formatting
- Colored terminal output with `Crayons`
- ASCII art banners with `FIGlet`
- Logging level management
- Type information display with color coding
- Banner and separator display functions

## Type and Method Utilities
- Type introspection and hierarchy exploration
- Docstring generation for types
- Method manipulation utilities
- Long tuple handling

## Documentation Utilities
- Automated docstring generation
- Type documentation formatting
- Purpose function integration

# Dependencies

- `Accessors`: Utilities for accessing and modifying nested data structures
- `Crayons`: Colored terminal output
- `DataStructures`: Data structure utilities for collections
- `FIGlet`: ASCII art text generation
- `InteractiveUtils`: Interactive utilities for Julia REPL
- `Logging`: Logging framework
- `TypedTables`: Typed table data structures

# Usage Example

```julia
using UtilsKit

# Convert dictionary to NamedTuple
dict = Dict(:a => 1, :b => 2)
nt = dict_to_namedtuple(dict)

# Display a banner (FIGlet)
print_figlet_banner("UtilsKit")

# Work with arrays
arr = [1, 2, 3, 0, -1, 5]
bool_arr = positive_mask(arr)

# String utilities
str = to_uppercase_first("hello_world", "Time")  # Returns :TimeHelloWorld
```

# Notes

- Functions are designed to be type-stable for performance-critical workflows
- The package provides foundational utilities intended for reuse across packages
- Display utilities support both colored and plain text output
- NamedTuple utilities enable efficient manipulation of structured data types

# See Also

- [`dict_to_namedtuple`](@ref) for dictionary conversion
- [`print_figlet_banner`](@ref) for ASCII art display
- [`positive_mask`](@ref) for array masking
- [`get_type_docstring`](@ref) for type documentation generation
"""
module UtilsKit

   # Submodules (file-per-area)
   include("ForNumber.jl")       # UtilsKit.ForNumber
   include("ForString.jl")       # UtilsKit.ForString
   include("ForMethods.jl")      # UtilsKit.ForMethods
   include("ForDocStrings.jl")   # UtilsKit.ForDocStrings
   include("ForCollections.jl")  # UtilsKit.ForCollections
   include("ForLongTuples.jl")   # UtilsKit.ForLongTuples
   include("ForArray.jl")        # UtilsKit.ForArray
   include("ForDisplay.jl")      # UtilsKit.ForDisplay
   include("ForPkg.jl")          # UtilsKit.ForPkg

   # -----------------------------------------------------------------------
   # Flat API (re-export from submodules)
   # -----------------------------------------------------------------------

   # Number
   using .ForNumber: clamp_zero_one, cumulative_sum!, safe_divide, is_invalid_number, replace_invalid_number,
                     at_least_zero, at_least_one, at_most_zero, at_most_one
   export clamp_zero_one, cumulative_sum!, safe_divide, is_invalid_number, replace_invalid_number,
          at_least_zero, at_least_one, at_most_zero, at_most_one

   # String
   using .ForString: to_uppercase_first
   export to_uppercase_first

   # Methods / introspection
   using .ForMethods: do_nothing, get_method_types, get_definitions, get_method_signatures,
                      methods_of, print_method_signatures, purpose, show_methods_of, val_to_symbol
   export do_nothing, get_method_types, get_definitions, get_method_signatures,
          methods_of, print_method_signatures, purpose, show_methods_of, val_to_symbol

   # Docstrings
   using .ForDocStrings: loop_write_type_docstring, write_type_docstring, get_type_docstring
   export loop_write_type_docstring, write_type_docstring, get_type_docstring

   # Collections / NamedTuple utils
   using .ForCollections: dict_to_namedtuple, merge_namedtuple, tc_print,
                          drop_namedtuple_fields, foldl_tuple_unrolled, merge_namedtuple_prefer_nonempty, table_to_namedtuple,
                          namedtuple_from_names_values, duplicates, drop_empty_namedtuple_fields,
                          set_namedtuple_field, set_namedtuple_subfield, list_to_table
   export dict_to_namedtuple, merge_namedtuple, tc_print,
          drop_namedtuple_fields, foldl_tuple_unrolled, merge_namedtuple_prefer_nonempty, table_to_namedtuple,
          namedtuple_from_names_values, duplicates, drop_empty_namedtuple_fields,
          set_namedtuple_field, set_namedtuple_subfield, list_to_table

   # Long tuple utilities
   using .ForLongTuples: LongTuple, foldl_longtuple, to_tuple, to_longtuple
   export LongTuple, foldl_longtuple, to_tuple, to_longtuple

   # Arrays
   using .ForArray: positive_mask, lower_triangle_mask, off_diagonal_mask, upper_triangle_mask,
                    view_at_trailing_indices, off_diagonal_elements, upper_off_diagonal_elements, lower_off_diagonal_elements,
                    stack_as_columns
   export positive_mask, lower_triangle_mask, off_diagonal_mask, upper_triangle_mask,
          view_at_trailing_indices, off_diagonal_elements, upper_off_diagonal_elements, lower_off_diagonal_elements,
          stack_as_columns

   # Display helpers
   using .ForDisplay: set_log_level, print_figlet_banner, print_info, print_info_separator, toggle_type_abbrev_in_stacktrace
   export set_log_level, print_figlet_banner, print_info, print_info_separator, toggle_type_abbrev_in_stacktrace

   # Pkg / extensions helpers
   using .ForPkg: add_extension_to_function, add_extension_to_package, add_package, remove_extension_from_package
   export add_extension_to_function, add_extension_to_package, add_package, remove_extension_from_package

end # module UtilsKit
