"""
    UtilsKit.ForDisplay

Display / logging utilities:
- banners (FIGlet) and lightweight terminal UI helpers
- log level helpers and styled informational output
"""
module ForDisplay

using Crayons
using Logging
using FIGlet

export set_log_level
export print_figlet_banner
export print_info
export print_info_separator
export toggle_type_abbrev_in_stacktrace

figlet_fonts = ("3D Diagonal", "3D-ASCII", "3d", "4max", "5 Line Oblique", "5x7", "6x9", "AMC AAA01", "AMC Razor", "AMC Razor2", "AMC Slash", "AMC Slider", "AMC Thin", "AMC Tubes", "AMC Untitled", "ANSI Regular", "ANSI Shadow", "Big Money-ne", "Big Money-nw", "Big Money-se", "Big Money-sw", "Bloody", "Caligraphy2", "DOS Rebel", "Dancing Font", "Def Leppard", "Delta Corps Priest 1", "Electronic", "Elite", "Fire Font-k", "Fun Face", "Georgia11", "Larry 3D", "Lil Devil", "Line Blocks", "NT Greek", "NV Script", "Red Phoenix", "Rowan Cap", "S Blood", "THIS", "Two Point", "USA Flag", "Wet Letter", "acrobatic", "alligator", "alligator2", "alligator3", "alphabet", "arrows", "asc_____", "avatar", "banner", "banner3", "banner3-D", "banner4", "barbwire", "bell", "big", "bolger", "braced", "bright", "bulbhead", "caligraphy", "charact2", "charset_", "clb6x10", "colossal", "computer", "cosmic", "crawford", "crazy", "diamond", "doom", "fender", "fraktur", "georgi16", "ghoulish", "graffiti", "hollywood", "jacky", "jazmine", "maxiwi", "merlin1", "nancyj", "nancyj-improved", "nscript", "o8", "ogre", "pebbles", "reverse", "roman", "rounded", "rozzo", "script", "slant", "small", "soft", "speed", "standard", "stop", "tanja", "thick", "train", "univers", "whimsy");


"""
    set_log_level()

Sets the logging level to `Info`.

# Examples

```jldoctest
julia> using UtilsKit

julia> set_log_level();
```
"""
function set_log_level()
    logger = ConsoleLogger(stderr, Logging.Info)
    global_logger(logger)
    return nothing
end

"""
    set_log_level(log_level::Symbol)

Sets the logging level to the specified level.

# Arguments:
- `log_level`: The desired logging level (`:debug`, `:warn`, `:error`).

# Examples

```jldoctest
julia> using UtilsKit

julia> set_log_level(:warn);
```
"""
function set_log_level(log_level::Symbol)
    logger = ConsoleLogger(stderr, Logging.Info)
    if log_level == :debug
        logger = ConsoleLogger(stderr, Logging.Debug)
    elseif log_level == :warn
        logger = ConsoleLogger(stderr, Logging.Warn)
    elseif log_level == :error
        logger = ConsoleLogger(stderr, Logging.Error)
    end
    global_logger(logger)
    return nothing
end

"""
    print_figlet_banner(disp_text="UtilsKit"; color=true, n=1, pause=0.1)

Displays the given text as a banner using `FIGlet`.

# Arguments:
- `disp_text`: The text to display (default: "UtilsKit").
- `color`: Whether to display the text in random colors (default: `true`).
- `n`: Number of times to display the banner (default: 1).
- `pause`: Seconds to sleep between repetitions when `n>1` (default: 0.1).

# Examples

```jldoctest
julia> using UtilsKit

julia> redirect_stdout(devnull) do
           print_figlet_banner("UtilsKit"; color=false, n=1, pause=0.0)
       end === nothing
true
```
"""
function print_figlet_banner(disp_text="UtilsKit"; color::Bool=true, n::Integer=1, pause::Real=0.1)
    n < 1 && return nothing
    for i in 1:n
        if color
            print(Crayon(; foreground=rand(0:255)), "\n")
        end
        println("######################################################################################################\n")
        FIGlet.render(disp_text, rand(figlet_fonts))
        println("######################################################################################################")
        if i < n
            sleep(pause)
        end
    end
    return nothing
end

# Backward-compatible (within this release): allow `print_figlet_banner(text, color)` positional calls
print_figlet_banner(disp_text, color::Bool; n::Integer=1, pause::Real=0.1) = print_figlet_banner(disp_text; color=color, n=n, pause=pause)



"""
    print_info(func, file_name, line_number, info_message; spacer=" ", n_f=1, n_m=1)

Logs an informational message with optional function, file, and line number context.

# Arguments
- `func`: The function object or `nothing` if not applicable.
- `file_name`: The name of the file where the message originates.
- `line_number`: The line number in the file.
- `info_message`: The message to log.
- `spacer`: (Optional) String used for spacing in the log output (default: `" "`).
- `n_f`: (Optional) Number of times to repeat `spacer` before the function/file info (default: `1`).
- `n_m`: (Optional) Number of times to repeat `spacer` before the message (default: `1`).

# Example
```julia
print_info(myfunc, "myfile.jl", 42, "Computation finished")
```

# Examples

```jldoctest
julia> using UtilsKit

julia> redirect_stdout(devnull) do
           print_info(nothing, "file.jl", 1, "hello"; n_f=0, n_m=0)
       end === nothing
true
```
"""
function print_info(func, file_name, line_number, info_message; spacer=" ", n_f=1, n_m=1, display_color=(0, 152, 221))
    func_space = spacer ^ n_f
    info_space = spacer ^ n_m
    file_link = ""
    mpi_color = (17, 102, 86)  # Default color for info messages
    if !isnothing(func)
        file_link = " $(nameof(func)) (`$(first(splitext(basename(file_name))))`.jl:$(line_number)) => "
        # display_color = (79, 255, 55)
        # display_color = :red
        display_color = (74, 192, 60)
    end
    show_str = "$(func_space)$(file_link)$(info_space)$(info_message)"

    println(_colorizeBacktickedSegments(show_str, display_color))
    # @info show_str
end


"""
    _colorizeBacktickedSegments(s::String, color)

Returns a string with segments enclosed in backticks (`) colored using the specified RGB color.

# Arguments
- `s::String`: The input string. Segments to be colored should be enclosed in backticks (e.g., `"This is `colored` text"`).
- `color`: An RGB tuple (e.g., `(0, 152, 221)`) specifying the foreground color to use.

# Returns
- A string with the specified segments colored, suitable for display in terminals that support ANSI color codes.

# Example
```julia
println(_colorizeBacktickedSegments("This is `colored` text", (0, 152, 221)))
```
This will print "This is colored text" with "colored" in the specified color.

# Notes
- Only the segments between backticks are colored; other text remains uncolored.
- The function uses Crayons.jl for coloring, so output is best viewed in compatible terminals.

# Examples

```jldoctest
julia> using UtilsKit

julia> UtilsKit.ForDisplay._colorizeBacktickedSegments("This is `colored` text", (0, 152, 221)) isa String
true
```
"""
function _colorizeBacktickedSegments(text::String, color)
    # Create a Crayon object with the specified color
    crayon = Crayon(foreground = color)

    # Split the string by backticks
    parts = split(text, "`")

    # Initialize an empty string for the output
    output = ""

    # Iterate through the parts and color the segments
    for (i, part) in enumerate(parts)
        if i % 2 == 0  # Even indices are segments to color
            output *= string(crayon(part))  # Convert CrayonWrapper to string
        else
            output *= part  # Odd indices are regular text
        end
    end

    return output
end

"""
    print_info_separator(; sep_text="", sep_width=100, display_color=(223,184,21))

Prints a visually distinct separator line to the console, optionally with centered text.

# Arguments
- `sep_text`: (Optional) A string to display centered within the separator. If empty, a line of dashes is printed. Default is `""`.
- `sep_width`: (Optional) The total width of the separator line. Default is `100`.
- `display_color`: (Optional) An RGB tuple specifying the color of the separator line. Default is `(223,184,21)`.

# Example
```julia
print_info_separator()
print_info_separator(sep_text=" SECTION START ", sep_width=80)
```

# Notes
- The separator line is colored for emphasis.
- Useful for visually dividing output sections in logs or the console.

# Examples

```jldoctest
julia> using UtilsKit

julia> redirect_stdout(devnull) do
           print_info_separator(sep_text=" SECTION ", sep_width=40)
       end === nothing
true
```
"""
function print_info_separator(; sep_text="", sep_width=100, display_color=(223,184,21))
    if isempty(sep_text) 
        sep_text=repeat("-", sep_width)
    else
        sep_remain = (sep_width - length(sep_text))%2
        sep_text = repeat("-", div(sep_width - length(sep_text) + sep_remain, 2)) * sep_text * repeat("-", div(sep_width - length(sep_text) + sep_remain, 2))
    end
    print_info(nothing, @__FILE__, @__LINE__, "\n`$(sep_text)`\n", display_color=display_color, n_f=0, n_m=0)
end    


"""
    toggle_type_abbrev_in_stacktrace(toggle=true)

Modifies the display of stack traces to reduce verbosity for NamedTuples.

# Arguments:
- `toggle`: Whether to enable or disable the modification (default: `true`).

# Examples

```jldoctest
julia> using UtilsKit

julia> toggle_type_abbrev_in_stacktrace(true);
```
"""
function toggle_type_abbrev_in_stacktrace(toggle=true)
    if toggle
        eval(:(Base.show(io::IO, nt::Type{<:NamedTuple}) = print(io, "NT")))
        eval(:(Base.show(io::IO, nt::Type{<:Tuple}) = print(io, "T")))
        eval(:(Base.show(io::IO, nt::Type{<:NTuple}) = print(io, "NT")))
    else
        # TODO: Restore the default behavior (currently not implemented).
        eval(:(Base.show(io::IO, nt::Type{<:NTuple}) = Base.show(io::IO, nt::Type{<:NTuple})))
    end
    return nothing
end

end # module ForDisplay
