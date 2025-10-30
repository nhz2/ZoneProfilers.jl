const MAX_NAME_LEN = 511
const MAX_FUNCTION_LEN = 511
const MAX_FILE_LEN = 2047

# Putting this in another struct emulates the const char* field that tracy expects.
mutable struct ConstStringRef{N}
    const data::NTuple{N, UInt8}
end
function ConstStringRef{N}(data::AbstractVector{UInt8}) where N
    if length(data) ≥ N
        throw(ArgumentError("length of data $(length(data)) must be less than $(N)"))
    end
    # Using ntuple directly is slow to compile, so map to a padded Vector
    null_padded_data = map(1:N) do i
        if i ≤ length(data)
            data[begin + i - 1]
        else
            0x00
        end
    end
    ConstStringRef{N}(Tuple(null_padded_data))
end
function _get_string(x::ConstStringRef)::String
    data = collect(x.data)
    n = findfirst(iszero, data)
    if isnothing(n)
        throw(ArgumentError("No null termination found"))
    else
        return String(view(data, 1:n-1))
    end
end

"""
    mutable struct SourceLocation

A type compatible with Tracy's ___tracy_source_location_data.
This type is designed to be interpolated in a macro return expression to ensure it
doesn't get GC'ed.
"""
mutable struct SourceLocation
    name::ConstStringRef{MAX_NAME_LEN + 1}
    # Currently function_name is used for the module name
    function_name::ConstStringRef{MAX_FUNCTION_LEN + 1}
    file::ConstStringRef{MAX_FILE_LEN + 1}
    line::UInt32
    color::UInt32
    function SourceLocation(name::ConstStringRef{MAX_NAME_LEN + 1}, function_name::ConstStringRef{MAX_FUNCTION_LEN + 1}, file::ConstStringRef{MAX_FILE_LEN + 1}, line::UInt32, color::UInt32)
        new(name, function_name, file, line, color)
    end
    # set name to NULL
    function SourceLocation(name::Nothing, function_name::ConstStringRef{MAX_FUNCTION_LEN + 1}, file::ConstStringRef{MAX_FILE_LEN + 1}, line::UInt32, color::UInt32)
        x = new()
        x.function_name = function_name
        x.file = file
        x.line = line
        x.color = color
        x
    end
end
function SourceLocation(source::LineNumberNode, function_name::String, name::Union{String, Nothing}, color::UInt32)
    filepath = string(source.file)
    line = UInt32(source.line)
    name_data = if isnothing(name)
        nothing
    else
        if 0x00 in codeunits(name)
            throw(ArgumentError("name: $(repr(name)) must not contain null"))
        end
        ConstStringRef{MAX_NAME_LEN + 1}(codeunits(name))
    end
    if 0x00 in codeunits(function_name)
        throw(ArgumentError("function_name: $(repr(function_name)) must not contain null"))
    end
    SourceLocation(
        name_data,
        ConstStringRef{MAX_FUNCTION_LEN + 1}(codeunits(function_name)),
        ConstStringRef{MAX_FILE_LEN + 1}(codeunits(filepath)),
        line,
        color,
    )
end

function Base.show(io::IO, srcloc::SourceLocation)
    summary(io, srcloc)
    print(io, "(LineNumberNode($(srcloc.line), $(repr(Symbol(_get_string(srcloc.file))))), ")
    print(io, "$(repr(_get_string(srcloc.function_name))), ")
    if isdefined(srcloc, :name)
        print(io, "$(repr(_get_string(srcloc.name))), ")
    else
        print(io, "nothing, ")
    end
    print(io, "$(repr(srcloc.color)))")
    nothing
end
