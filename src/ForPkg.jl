"""
    OmniTools.ForPkg

Package-management helpers (Julia `Pkg`) and convenience utilities for creating/removing
package extensions (`ext/` scaffolding) and weakdep mappings in `Project.toml`.

Notes:
- Uses `import Pkg as StdPkg` internally to avoid the `OmniTools.ForPkg` name conflict.
"""
module ForPkg

import Pkg as StdPkg
import TOML
using Logging

using ..ForMethods: get_method_signatures

export add_extension_to_function
export add_extension_to_package
export add_package
export remove_extension_from_package

"""
    assertPackageInRegistry(pkgname::String) -> Nothing

Fail fast if `pkgname` cannot be found in any reachable registry.

This is a preflight check to avoid creating extension files / activating environments when the package
name is misspelled or not registered.
"""
function assertPackageInRegistry(pkgname::String)
    regs = try
        StdPkg.Registry.reachable_registries()
    catch err
        throw(error("Could not query registries to validate package name $(repr(pkgname)). Error: $(err)"))
    end
    for r in regs
        # Fast path: RegistryInstance may have `name_to_uuids::Dict{String,Vector{UUID}}`,
        # but on some setups this can be incomplete even when the package exists.
        ntu = getfield(r, :name_to_uuids)
        if haskey(ntu, pkgname)
            return nothing
        end

        # Fallback (authoritative): scan the registry `pkgs::Dict{UUID,PkgEntry}` table by name.
        # This is O(N) in number of packages in the registry, but it avoids false negatives.
        for entry in values(getfield(r, :pkgs))
            if getfield(entry, :name) == pkgname
                return nothing
            end
        end
    end
    reg_names = join((getfield(r, :name) for r in regs), ", ")
    error("Package $(repr(pkgname)) not found in reachable registries ($(reg_names)). Check spelling or add the registry that contains it.")
end


# ---------------------------------------------------------------------------
# add_extension_to_function
# ---------------------------------------------------------------------------

"""
    add_extension_to_function(function_to_extend::Function, external_package::String; extension_location::Symbol = :Folder) -> String

Create a folder-style Julia extension entry + include file scaffold for the given `function_to_extend`,
and ensure `Project.toml` contains the needed `[weakdeps]` and `[extensions]` mapping.

The include file name is:
- `<InnerModule><Cap(FunctionName)>.jl` when the function lives under a single inner module (e.g. `SimulationSpinup.jl`)
- otherwise `<RootPackage><Cap(FunctionName)>.jl` (e.g. `MyPkgSpinup.jl`)

The generated include file contains:
- a short header docstring,
- a list of method signatures with repo-relative file paths,
- and a commented “example” method stub using common arg names and the most common last-arg type (best-effort).

This helper is conservative:
- If both entry and include already exist: errors (no overwrite).
- If entry exists but include missing: warns and creates only the include file.
- If include exists but entry missing: warns and creates the entry file including the existing include file (does not modify include).

## Example

```julia
include(joinpath(@__DIR__, "tmp_test_extension.jl"))
using .TmpTestExtension

add_extension_to_function(MyPkg.MyInnerModule.someFunction, "NLsolve"; extension_location=:Folder)
```

# Examples

The full operation modifies `Project.toml` and creates files under `ext/`, so it is not run as a doctest here.
This snippet is a **runnable** smoke-check that the function is available:

```jldoctest
julia> using OmniTools

julia> OmniTools.add_extension_to_function isa Function
true
```
"""
function add_extension_to_function(target_function::Function, external_package::String; extension_location::Symbol = :Folder)
    _logStep("add_extension_to_function", "Starting (external_package=$(external_package), extension_location=$(extension_location))")

    local_module = parentmodule(target_function)
    root_pkg = Base.moduleroot(local_module)
    root_pkg_name = String(nameof(root_pkg))
    ext_module_name = "$(root_pkg_name)$(external_package)Ext"

    root_path = pathof(root_pkg)
    isnothing(root_path) && error("Cannot locate package root for $(root_pkg). Ensure it is a package module with a valid `pathof`.")
    package_root = joinpath(dirname(root_path), "..")

    # First step: ensure the weak dependency is addable/added. If this fails, we stop here and do NOT
    # create any files/directories under `ext/`.
    _ensureProjectExtensionMapping(package_root, external_package, ext_module_name)

    ext_dir = _ensureExtDir(package_root)
    ext_path = extension_location === :File ? ext_dir :
               extension_location === :Folder ? _ensureExtensionFolder(ext_dir, ext_module_name) :
               error("Invalid `extension_location=$(extension_location)`. Expected :File or :Folder.")

    # Inner module inference (single level)
    root_full = Base.fullname(root_pkg)
    fn_mod = parentmodule(target_function)
    fn_full = Base.fullname(fn_mod)
    rel = (length(fn_full) > length(root_full) && fn_full[1:length(root_full)] == root_full) ? fn_full[length(root_full)+1:end] : ()
    inner = length(rel) == 1 ? String(rel[1]) : nothing

    fn_name = String(nameof(target_function))
    cap_name = uppercasefirst(fn_name)
    codefile = isnothing(inner) ? "$(root_pkg_name)$(cap_name).jl" : "$(inner)$(cap_name).jl"

    entry_file = joinpath(ext_path, "$(ext_module_name).jl")
    code_path = joinpath(ext_path, codefile)
    entry_exists = isfile(entry_file)
    code_exists = isfile(code_path)

    # Method signature strings (dedup default-arg expansions + repo-relative paths)
    template_methods = get_method_signatures(target_function; path=:relative_root)
    # Arg name + last-arg type inference (best-effort)
    template_arg_names, template_last_arg_type = _inferCommonArgNames(target_function)

    if entry_exists && code_exists
        error("Both extension entry and include exist.\nEntry: $(entry_file)\nInclude: $(code_path)\nDelete the include file to regenerate it.")
    elseif entry_exists && !code_exists
        _warnStep("add_extension_to_function", "Entry exists but include is missing. Creating include only (no overwrite of entry).")
        _writeExtensionInclude(ext_path, codefile; template=(;
            root_package_name=root_pkg_name,
            inner_module=inner,
            external_package_name=external_package,
            function_name=fn_name,
            methods=template_methods,
            arg_names=template_arg_names,
            last_arg_type=template_last_arg_type,
        ))
    elseif !entry_exists && code_exists
        _warnStep("add_extension_to_function", "Include exists but entry is missing. Creating entry that includes existing include (no changes to include).")
        _writeExtensionEntry(root_pkg_name, inner, external_package, ext_path, ext_module_name, codefile)
    else
        _writeExtensionEntry(root_pkg_name, inner, external_package, ext_path, ext_module_name, codefile)
        _writeExtensionInclude(ext_path, codefile; template=(;
            root_package_name=root_pkg_name,
            inner_module=inner,
            external_package_name=external_package,
            function_name=fn_name,
            methods=template_methods,
            arg_names=template_arg_names,
            last_arg_type=template_last_arg_type,
        ))
    end

    _logStep("add_extension_to_function", "Done. Extension module name: $(ext_module_name)")
    return ext_module_name
end

# ---------------------------------------------------------------------------
# add_extension_to_package
# ---------------------------------------------------------------------------

"""
    add_extension_to_package(local_package::Module, external_package::String; extension_location::Symbol = :File) -> String

Register a Julia extension for `local_package`:
- create the extension entry file (`*Ext.jl`) with **no include**
- update `Project.toml` (`[weakdeps]` + `[extensions]`)

This does **not** create any include file scaffold; use [`add_extension_to_function`](@ref) if you want that.

# Examples

```jldoctest
julia> using OmniTools

julia> OmniTools.add_extension_to_package isa Function
true
```
"""
function add_extension_to_package(local_module::Module, external_package::String; extension_location::Symbol = :File)
    _logStep("add_extension_to_package", "Starting (external_package=$(external_package), extension_location=$(extension_location))")

    root_pkg = Base.moduleroot(local_module)
    root_pkg_name = String(nameof(root_pkg))
    ext_module_name = "$(root_pkg_name)$(external_package)Ext"

    root_path = pathof(root_pkg)
    isnothing(root_path) && error("Cannot locate package root for $(root_pkg). Ensure it is a package module with a valid `pathof`.")
    package_root = joinpath(dirname(root_path), "..")

    # First step: ensure the weak dependency is addable/added. If this fails, we stop here and do NOT
    # create any files/directories under `ext/`.
    _ensureProjectExtensionMapping(package_root, external_package, ext_module_name)

    ext_dir = _ensureExtDir(package_root)
    ext_path = extension_location === :File ? ext_dir :
               extension_location === :Folder ? _ensureExtensionFolder(ext_dir, ext_module_name) :
               error("Invalid `extension_location=$(extension_location)`. Expected :File or :Folder.")

    # Optional single inner module name for import statement
    root_full = Base.fullname(root_pkg)
    local_full = Base.fullname(local_module)
    rel = (length(local_full) > length(root_full) && local_full[1:length(root_full)] == root_full) ? local_full[length(root_full)+1:end] : ()
    inner = length(rel) == 1 ? String(rel[1]) : nothing

    _writeExtensionEntry(root_pkg_name, inner, external_package, ext_path, ext_module_name, nothing)
    _logStep("add_extension_to_package", "Done. Extension module name: $(ext_module_name)")
    return ext_module_name
end



"""
    add_package(where_to_add, the_package_to_add)

Adds a specified Julia package to the environment of a given module or project.

# Arguments:
- `where_to_add`: The module or project where the package should be added.
- `the_package_to_add`: The name of the package to add.

# Behavior:
- Activates the environment of the specified module or project.
- Checks if the package is already installed in the environment.
- If the package is not installed:
  - Adds the package to the environment.
  - Removes the `Manifest.toml` file and reinstantiates the environment to ensure consistency.
  - Provides instructions for importing the package in the module.
- Restores the original environment after the operation.

# Notes:
- This function assumes that the `where_to_add` module or project is structured with a standard Julia project layout.
- It requires the `Pkg` module for package management.

# Example:
```julia
add_package(MyModule, "DataFrames")
```

# Examples

```jldoctest
julia> using OmniTools

julia> OmniTools.add_package isa Function
true
```
"""
function add_package(target, package_name)

    from_where = dirname(Base.active_project())
    dir_target = joinpath(dirname(pathof(target)), "../")
    cd(dir_target)
    StdPkg.activate(dir_target)
    is_installed = any(dep.name == package_name for dep in values(StdPkg.dependencies()))

    if is_installed
        @info "$package_name is already installed in $target. Nothing to do. Return to base environment at $from_where".
    else

        StdPkg.add(package_name)
        rm("Manifest.toml")
        StdPkg.instantiate()
        @info "Added $(package_name) to $(target). Add the following to the imports in $(pathof(target)) with\n\nusing $(package_name)\n\n. You may need to restart the REPL/environment at $(from_where)."
    end
    cd(from_where)
    StdPkg.activate(from_where)
    StdPkg.resolve()
end


# ---------------------------------------------------------------------------
# _writeExtensionInclude
# ---------------------------------------------------------------------------

"""
    _writeExtensionInclude(ext_path::String, codefile::Union{Nothing,String}; template=nothing) -> Union{Nothing,String}

Create the include file if missing; errors if it already exists (no overwrite).
"""
function _writeExtensionInclude(ext_path::String, codefile::Union{Nothing,String}; template::Union{Nothing,NamedTuple}=nothing)
    isnothing(codefile) && return nothing
    codepath = joinpath(ext_path, codefile)
    isfile(codepath) && error("Extension include file already exists: $(codepath)\nDelete it to regenerate.")

    _logStep("_writeExtensionInclude", "Creating include file: $(codepath)")
    open(codepath, "w") do io
        if isnothing(template)
            println(io, "# Extension code for $(codefile)")
            return
        end

        fn = get(template, :function_name, "unknown_function")
        root_pkg = get(template, :root_package_name, "LocalPackage")
        inner = get(template, :inner_module, nothing)
        ext_pkg = get(template, :external_package_name, "ExternalPkg")
        mlist = get(template, :methods, nothing)
        arg_names = get(template, :arg_names, nothing)
        last_arg_type = get(template, :last_arg_type, nothing)

        qualified_mod = isnothing(inner) ? root_pkg : "$(root_pkg).$(inner)"
        qualified_fn = "$(qualified_mod).$(fn)"

        println(io, "\"\"\"")
        println(io, "Extension methods for `$(qualified_fn)`.")
        println(io, "")
        println(io, "This file is included from the extension module and can use `$(ext_pkg)`.")
        println(io, "\"\"\"")
        println(io, "")
        println(io, "# Bring the target function into scope for adding methods. This should be done using `import` and not `using`.")
        if isnothing(inner)
            println(io, "import $(root_pkg): $(fn)")
        else
            println(io, "import $(root_pkg).$(inner): $(fn)")
        end
        println(io, "")

        println(io, "# get all the types needed to dispatch the function. These types should defined in a corresponding file in $(root_pkg) so that they can be used for dispatching and setup, if that were needed.")
        println(io, "# using $(root_pkg): A, b, c")
        println(io, "")


        if !isnothing(mlist)
            println(io, "# Example methods (for reference):")
            for m in mlist
                println(io, "# - $(m)")
            end
            println(io, "")
        end

        println(io, "# ------------------------------------------------------------------")
        println(io, "# Add your extension methods below. The Example is a tentative placeholder for the method signature and should be replaced with the actual method signature.")
        println(io, "")
        if !isnothing(arg_names) && !isnothing(last_arg_type) && length(arg_names) >= 1
            args = collect(String.(arg_names))
            last_name = args[end]
            prefix_args = length(args) > 1 ? join(args[1:end-1], ", ") * ", " : ""
            println(io, "# function $(fn)($(prefix_args)$(last_name)::$(last_arg_type); kwargs...)")
        else
            println(io, "# function $(fn)(args...; kwargs...)")
        end
        println(io, "#     # TODO: implement")
        println(io, "# end")
    end
    _logStep("_writeExtensionInclude", "Wrote: $(codepath)")
    return codepath
end

# ---------------------------------------------------------------------------
# _writeExtensionEntry
# ---------------------------------------------------------------------------

"""
    _writeExtensionEntry(main_package_name::String, inner_module::Union{Nothing,String}, extension_package_name::String, ext_path::String, ext_module_name::String, codefile::Union{Nothing,String}) -> String

Create the extension entry file (`<ExtModuleName>.jl`). Errors if it already exists (no overwrite).
"""
function _writeExtensionEntry(
    main_package_name::String,
    inner_module::Union{Nothing,String},
    extension_package_name::String,
    ext_path::String,
    ext_module_name::String,
    codefile::Union{Nothing,String},
)
    ext_file = joinpath(ext_path, "$(ext_module_name).jl")
    isfile(ext_file) && error("Extension entry file already exists: $(ext_file)\nDelete it to regenerate.")

    _logStep("_writeExtensionEntry", "Creating extension entry file: $(ext_file)")

    extended_target = isnothing(inner_module) ? main_package_name : "$main_package_name.$inner_module"
    # Only emit the `import` in the entry file when we are NOT generating/including an extension code file.
    # If we are including an extension code file, that file is responsible for importing the function(s)
    # being extended (and any needed modules).
    import_stmt = if isnothing(codefile)
        isnothing(inner_module) ? "import $main_package_name" : "import $main_package_name: $inner_module"
    else
        ""
    end
    include_stmt = isnothing(codefile) ? "" : "include(\"$(codefile)\")"
    modify_stmt = isnothing(codefile) ? "" : "Modify the code in the \"$(codefile)\" file to extend the package."

    open(ext_file, "w") do io
        println(io, """
\"\"\"
    $(ext_module_name)

Julia extension module that enables $(extension_package_name) backends for `$(extended_target)`.

# Notes:
- This module is loaded automatically by Julia's package extension mechanism when $(extension_package_name) is available (see root `Project.toml` `[weakdeps]` + `[extensions]`).
- End users typically should not `using $(ext_module_name)` directly; instead `using $(main_package_name)` is sufficient once the weak dependency is installed.
- The extension code is included in the `ext/` directory and is automatically loaded when the extension package is installed.

$(modify_stmt)
\"\"\"
module $(ext_module_name)

    using $(extension_package_name)
    $(import_stmt)
    $(include_stmt)

end
""")
    end

    _logStep("_writeExtensionEntry", "Wrote: $(ext_file)")
    return ext_file
end

# ---------------------------------------------------------------------------
# _ensureExtDir / _ensureExtensionFolder
# ---------------------------------------------------------------------------

"""
    _ensureExtDir(package_root::String) -> String

Ensure `<package_root>/ext` exists.
"""
function _ensureExtDir(package_root::String)
    ext_dir = joinpath(package_root, "ext")
    if !isdir(ext_dir)
        mkpath(ext_dir)
        _logStep("_ensureExtDir", "Created directory: $(ext_dir)")
    end
    return ext_dir
end

"""
    _ensureExtensionFolder(ext_dir::String, ext_module_name::String) -> String

Ensure `ext/<ExtModuleName>/` exists.
"""
function _ensureExtensionFolder(ext_dir::String, ext_module_name::String)
    ext_path = joinpath(ext_dir, ext_module_name)
    if !isdir(ext_path)
        mkpath(ext_path)
        _logStep("_ensureExtensionFolder", "Created directory: $(ext_path)")
    end
    return ext_path
end

# ---------------------------------------------------------------------------
# _ensureProjectExtensionMapping
# ---------------------------------------------------------------------------

"""
    _ensureProjectExtensionMapping(package_root::String, external_package::String, ext_module_name::String) -> Nothing

Ensure `Project.toml` includes `external_package` in `[weakdeps]` and maps
`ext_module_name = "external_package"` in `[extensions]`. May call `Pkg.add(...; target=:weakdeps)`.
"""
function _ensureProjectExtensionMapping(package_root::String, external_package::String, ext_module_name::String)
    package_root = normpath(abspath(package_root))
    project_file = joinpath(package_root, "Project.toml")
    project = TOML.parsefile(project_file)

    actions = String[]

    # Keep track of the previously active project so we can restore it even if Pkg errors.
    prev_project = try
        Base.active_project()
    catch
        nothing
    end

    # First step: attempt the Pkg operation(s). If this fails (e.g. package not found), we want the
    # natural Pkg error and we should not proceed to create extension files.
    in_weakdeps = haskey(project, "weakdeps") && haskey(project["weakdeps"], external_package)
    in_deps = haskey(project, "deps") && haskey(project["deps"], external_package)

    # If the package is already a hard dependency, prefer moving it to [weakdeps] by editing Project.toml
    # directly (this avoids edge cases in some Pkg versions when rm'ing while juggling active envs).
    if in_deps && !in_weakdeps
        if !haskey(project, "weakdeps")
            project["weakdeps"] = Dict{String,Any}()
            push!(actions, "created [weakdeps] table")
        end
        uuid_str = project["deps"][external_package]
        project["weakdeps"][external_package] = uuid_str
        delete!(project["deps"], external_package)
        push!(actions, "moved \"$external_package\" from [deps] -> [weakdeps] in Project.toml")
        open(project_file, "w") do io
            TOML.print(io, project)
        end
        # Refresh after edit
        project = TOML.parsefile(project_file)
        in_weakdeps = true
        in_deps = false
    end

    try
        StdPkg.activate(package_root)
        if !in_weakdeps || in_deps
            StdPkg.add(external_package; target=:weakdeps)
            push!(actions, "added/ensured \"$external_package\" in [weakdeps] via Pkg")
        end
    finally
        if !isnothing(prev_project)
            try
                # `Base.active_project()` returns a Project.toml path; activating it directly is the most robust.
                StdPkg.activate(prev_project)
            catch
            end
        end
    end

    # Refresh project after Pkg operations (Pkg may have rewritten Project.toml).
    project = TOML.parsefile(project_file)

    if !haskey(project, "extensions")
        project["extensions"] = Dict{String,Any}()
        push!(actions, "created [extensions] table")
    end

    # Remove reversed mapping if present
    if haskey(project["extensions"], external_package) && project["extensions"][external_package] == ext_module_name
        delete!(project["extensions"], external_package)
        push!(actions, "removed reversed mapping \"$external_package\" = \"$ext_module_name\"")
    end

    project["extensions"][ext_module_name] = external_package
    push!(actions, "set [extensions] \"$ext_module_name\" = \"$external_package\"")

    open(project_file, "w") do io
        TOML.print(io, project)
    end
    _logStep("_ensureProjectExtensionMapping", "Updated $(project_file)")
    for a in actions
        _logStep("_ensureProjectExtensionMapping", "- $(a)")
    end
    return nothing
end

# ---------------------------------------------------------------------------
# _extensionIncludeFilename
# ---------------------------------------------------------------------------

"""
    _extensionIncludeFilename(inner_module::Union{Nothing,String}, function_name::String) -> String

Return `<InnerModule><Cap(function_name)>.jl` or `<Cap(function_name)>.jl`.
"""
function _extensionIncludeFilename(inner_module::Union{Nothing,String}, function_name::String)
    cap = uppercasefirst(function_name)
    prefix = isnothing(inner_module) ? "" : inner_module
    return "$(prefix)$(cap).jl"
end

"""
    _logStep(caller::AbstractString, message::AbstractString) -> Nothing

Print a standardized progress message.
"""
function _logStep(caller::AbstractString, message::AbstractString)
    println("[$(caller)] $(message)")
    return nothing
end

# ---------------------------------------------------------------------------
# remove_extension_from_package
# ---------------------------------------------------------------------------

"""
    remove_extension_from_package(local_package::Module, external_package::String) -> String

Remove extension registration from `Project.toml` and attempt to remove `external_package` from the environment
(`Pkg.rm` + `Pkg.resolve`) so the `Manifest.toml` is updated. Prints a shell-mode command to delete the
entry file or folder under `ext/` (auto-detected).

# Examples

```jldoctest
julia> using OmniTools

julia> OmniTools.remove_extension_from_package isa Function
true
```
"""
function remove_extension_from_package(local_module::Module, external_package::String)
    _logStep("remove_extension_from_package", "Starting (external_package=$(external_package))")

    root_pkg = Base.moduleroot(local_module)
    root_pkg_name = String(nameof(root_pkg))
    ext_module_name = "$(root_pkg_name)$(external_package)Ext"

    root_path = pathof(root_pkg)
    isnothing(root_path) && error("Cannot locate package root for $(root_pkg).")
    package_root = joinpath(dirname(root_path), "..")
    ext_dir = joinpath(package_root, "ext")

    file_entry = joinpath(ext_dir, "$(ext_module_name).jl")
    folder_entry = joinpath(ext_dir, ext_module_name, "$(ext_module_name).jl")
    ext_folder = joinpath(ext_dir, ext_module_name)
    file_exists = isfile(file_entry)
    folder_exists = isfile(folder_entry)

    project_file = joinpath(package_root, "Project.toml")
    project = TOML.parsefile(project_file)

    if haskey(project, "extensions") && haskey(project["extensions"], ext_module_name)
        delete!(project["extensions"], ext_module_name)
        _logStep("remove_extension_from_package", "Removed [extensions] mapping: $(ext_module_name) = \"$(external_package)\"")
    else
        _warnStep("remove_extension_from_package", "No [extensions] mapping found for $(ext_module_name).")
    end
    if haskey(project, "extensions") && haskey(project["extensions"], external_package) && project["extensions"][external_package] == ext_module_name
        delete!(project["extensions"], external_package)
        _logStep("remove_extension_from_package", "Removed reversed mapping: $(external_package) = \"$(ext_module_name)\"")
    end
    if haskey(project, "weakdeps") && haskey(project["weakdeps"], external_package)
        delete!(project["weakdeps"], external_package)
        _logStep("remove_extension_from_package", "Removed [weakdeps] entry for $(external_package).")
    end
    if haskey(project, "deps") && haskey(project["deps"], external_package)
        delete!(project["deps"], external_package)
        _warnStep("remove_extension_from_package", "Removed [deps] entry for $(external_package).")
    end

    open(project_file, "w") do io
        TOML.print(io, project)
    end
    _logStep("remove_extension_from_package", "Wrote: $(project_file)")

    try
        StdPkg.activate(package_root)
        try
            StdPkg.rm(external_package)
            _logStep("remove_extension_from_package", "Ran Pkg.rm(\"$(external_package)\") (Manifest updated).")
        catch
            _warnStep("remove_extension_from_package", "Pkg.rm(\"$(external_package)\") failed (maybe not installed).")
        end
        try StdPkg.resolve() catch end
    catch
        _warnStep("remove_extension_from_package", "Pkg environment update failed; Manifest may be unchanged.")
    end

    if file_exists && folder_exists
        _warnStep("remove_extension_from_package", "Both file- and folder-style entries exist. Remove one (or both):")
        _warnStep("remove_extension_from_package", "  ; rm -f \"$(file_entry)\"")
        _warnStep("remove_extension_from_package", "  ; rm -rf \"$(ext_folder)\"")
    elseif folder_exists
        _warnStep("remove_extension_from_package", "Detected folder-style extension. Remove with:\n  ; rm -rf \"$(ext_folder)\"")
    elseif file_exists
        _warnStep("remove_extension_from_package", "Detected file-style extension. Remove with:\n  ; rm -f \"$(file_entry)\"")
    else
        _warnStep("remove_extension_from_package", "No extension entry found under ext/. Potential commands:")
        _warnStep("remove_extension_from_package", "  ; rm -f \"$(file_entry)\"")
        _warnStep("remove_extension_from_package", "  ; rm -rf \"$(ext_folder)\"")
    end

    _logStep("remove_extension_from_package", "Done. Extension module name: $(ext_module_name)")
    return ext_module_name
end

# ---------------------------------------------------------------------------
# Internal helpers (not exported)
# ---------------------------------------------------------------------------

function _inferCommonArgNames(f::Function)
    arg_name_counts = Dict{Int,Dict{String,Int}}()
    last_type_counts = Dict{String,Int}()
    for m in methods(f)
        sig = Base.unwrap_unionall(m.sig)
        types = sig.parameters[2:end]
        nargs = length(types)
        try
            ci = first(Base.code_lowered(f, Tuple{types...}))
            if length(ci.slotnames) >= nargs + 1
                for i in 1:nargs
                    nm = String(ci.slotnames[i+1])
                    if isempty(nm) || startswith(nm, "#")
                        nm = "arg$(i)"
                    end
                    pos = get!(arg_name_counts, i, Dict{String,Int}())
                    pos[nm] = get(pos, nm, 0) + 1
                end
            end
        catch
        end
        if nargs > 0
            lt = string(types[end])
            last_type_counts[lt] = get(last_type_counts, lt, 0) + 1
        end
    end

    common_arg_names = nothing
    if !isempty(arg_name_counts)
        maxpos = maximum(keys(arg_name_counts))
        common_arg_names = [begin
            d = get(arg_name_counts, i, Dict{String,Int}())
            isempty(d) ? "arg$(i)" : first(sort(collect(d), by=x->x[2], rev=true))[1]
        end for i in 1:maxpos]
    end
    common_last_type = isempty(last_type_counts) ? nothing : first(sort(collect(last_type_counts), by=x->x[2], rev=true))[1]
    return common_arg_names, common_last_type
end

"""
    _warnStep(caller::AbstractString, message::AbstractString) -> Nothing

Emit a real Julia warning (via `Logging.@warn`) with a standardized message prefix.
"""
function _warnStep(caller::AbstractString, message::AbstractString)
    @warn "[$(caller)] $(message)"
    return nothing
end

end # module ForPkg
