module ChainCutters

# Use README as the docstring of the module:
@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end ChainCutters

using Setfield: Setfield, setproperties, Lens
using ForwardDiff
using ForwardDiff: Dual
using Requires
using ZygoteRules

const constructorof = try
    Setfield.constructorof
catch
    Setfield.constructor_of
end

@inline foldlargs(op, x) = x
@inline foldlargs(op, x1, x2, xs...) = foldlargs(op, op(x1, x2), xs...)

@inline _count(f, xs) = foldlargs(0, xs...) do c, x
    f(x) ? c + 1 : c
end

fieldvalues(obj) = ntuple(i -> getfield(obj, i), nfields(obj))
__fieldnames(obj) = __fieldnames(typeof(obj))
@generated __fieldnames(::Type{T}) where T = fieldnames(T)  # danger zone
# TODO: check if I need __fieldnames

# asnamedtuple(obj) = NamedTuple{__fieldnames(obj)}(fieldvalues(obj))

cut(x) = x
uncut(x) = x

abstract type Wrapper{T} end

struct Const{T} <: Wrapper{T}
    value::T
end

struct Variable{T} <: Wrapper{T}
    value::T
end

unwrap(x) = x
unwrap(x::Wrapper) = getfield(x, :value)

_cut(x) = Const(x)
_cut(x::Wrapper) = x

_uncut(x) = Variable(x)
_uncut(x::Wrapper) = x

Base.getproperty(x::Const, name) = _cut(getproperty(unwrap(x), name))
Base.getproperty(x::Variable, name) = _uncut(getproperty(unwrap(x), name))
Base.getproperty(x::Const, name::Symbol) = _cut(getproperty(unwrap(x), name))
Base.getproperty(x::Variable, name::Symbol) = _uncut(getproperty(unwrap(x), name))

nothingsfor(obj) =
    NamedTuple{__fieldnames(obj)}(ntuple(_ -> nothing, nfields(obj)))

# Let's use this ugly formatting until `literal_getproperty` is moved
# to ZygoteRules.jl: https://github.com/FluxML/ZygoteRules.jl/issues/3
function __init__()
    @require Zygote="e88e6eb3-aa80-5325-afca-941959d7151f" begin

using .Zygote: Zygote, unbroadcast

@adjoint function Zygote.literal_getproperty(obj::Wrapper, ::Val{name}) where name
    Zygote.literal_getproperty(obj, Val(name)), function(Δ)
        nt = nothingsfor(unwrap(obj))
        (setproperties(nt, NamedTuple{(name,)}((Δ,))), nothing)
    end
end

    end  # @require begin
end  # function __init__


Setfield.setproperties(obj::Const, patch) =
    Const(setproperties(unwrap(obj), patch))

Setfield.setproperties(obj::Variable, patch) =
    Variable(setproperties(unwrap(obj), patch))

Base.getindex(x::Const, I...) = _cut(getindex(unwrap(x), I...))
Base.getindex(x::Variable, I...) = _uncut(getindex(unwrap(x), I...))

Base.setindex(x::Const, I...) = _cut(Base.setindex(unwrap(x), I...))
Base.setindex(x::Variable, I...) = _uncut(Base.setindex(unwrap(x), I...))

@inline unwrap_rec(x::T) where T =
    if Base.issingletontype(T)
        x
    elseif Base.isstructtype(T)
        constructorof(T)(unwrap_rec(fieldvalues(x))...)
    else
        x
    end
@inline unwrap_rec(x::AbstractArray) = x
@inline unwrap_rec(x::Wrapper) = unwrap_rec(unwrap(x))
@inline unwrap_rec(x::Union{Tuple, NamedTuple}) = map(unwrap_rec, x)

# A workaround for: https://github.com/jw3126/Setfield.jl/pull/84
@inline unwrap_rec(x::Lens) = x

@adjoint unwrap(x) = unwrap(x), y -> (y,)
@adjoint cut(x) = _cut(x), y -> (y,)  # not `nothing`
@adjoint uncut(x) = _uncut(x), y -> (y,)
# Note:
# * `cut` may `uncut` so the pullback of `cut(x)` should be preserved
# * Functions touching `Const` and `Variable` are responsible for unwrapping
#   them.  So, there is no `y.value` in the pullback here.

function _adjoint(::typeof(*), A0, B0)
    A = unwrap(A0)
    B = unwrap(B0)
    return A * B, function mul_pullback(Δ)
        (A0 isa Const ? nothing : Δ * B',
         B0 isa Const ? nothing : A' * Δ)
    end
end

function _adjoint(::typeof(+), A0, B0)
    A = unwrap(A0)
    B = unwrap(B0)
    return A + B, function add_pullback(Δ)
        (A0 isa Const ? nothing : Δ,
         B0 isa Const ? nothing : Δ)
    end
end

function _adjoint(::typeof(-), A0, B0)
    A = unwrap(A0)
    B = unwrap(B0)
    return A - B, function add_pullback(Δ)
        (A0 isa Const ? nothing : Δ,
         B0 isa Const ? nothing : -Δ)
    end
end

for op in (*, +, -)
    @eval begin
        @adjoint $op(A::Wrapper, B) = _adjoint($op, A, B)
        @adjoint $op(A, B::Wrapper) = _adjoint($op, A, B)
        @adjoint $op(A::Wrapper, B::Wrapper) = _adjoint($op, A, B)
    end
end

const NonDifferentiableType = Union{
    Const,
    # From `Broadcast.broadcastable(x) = Ref(x)`:
    Symbol,
    AbstractString,
    # Function,  # closures may contain `Real`s
    UndefInitializer,
    Nothing,
    RoundingMode,
    Missing,
    Val,
    Ptr,
    Regex,
    # From `Type` is also treated similarly in `Broadcast.broadcastable`:
    Type,
}

nondifferentiable(::T) where T = nondifferentiable(T)
nondifferentiable(::Type) = false
nondifferentiable(::Type{<:NonDifferentiableType}) = true
nondifferentiable(::Type{<:AbstractArray{<:NonDifferentiableType}}) = true

differentiable(::T) where T = differentiable(T)
differentiable(::Type) = false
differentiable(::Type{<:Real}) = true
differentiable(::Type{<:AbstractArray{<:Real}}) = true
# How about Union{Missing,Real}?

supported(x) = nondifferentiable(x) || differentiable(x)

# Based on `Zygote.broadcast_forward`:

function dual_function(f::F, args0::NTuple{N, Any}) where {F, N}
    nvariables = _count(x -> !(x isa Const), args0)
    partials, = foldlargs(((), 0), args0...) do (partials, n), x
        if nondifferentiable(x)
            ((partials..., nothing), n)
        else
            @assert differentiable(x)
            i = n + 1
            ((partials..., ntuple(j -> i == j, nvariables)), i)
        end
    end

    return function dual_function_impl(args::Vararg{Any, N})
        ds = ntuple(Val(N)) do i
            if partials[i] === nothing
                args[i]
            else
                Dual(args[i], partials[i])
            end
        end
        return f(ds...)
    end
end

broadcast_adjoint(f, args::Vararg{Const}) =
    f.(map(unwrap, args)...), _ -> nothing

function broadcast_adjoint(f, args0...)
    map(args0) do x
        supported(x) && return
        throw(ArgumentError(string(
            "Differentiation w.r.t ", x, " is not supported.\n",
            "Use `cut` to mark it as a constant.",
        )))
    end
    args = map(unwrap, args0)
    out = dual_function(f, args0).(args...)
    eltype(out) <: Dual || return (out, _ -> nothing)
    y = map(ForwardDiff.value, out)
    back(ȳ) = foldlargs(((nothing,), 0), args0...) do (partials, n), x
        if x isa Const
            ((partials..., nothing), n)
        else
            i = n + 1
            p = unbroadcast(unwrap(x), ((a, b) -> a * b.partials[i]).(ȳ, out))
            ((partials..., p), i)
        end
    end[1]
    return y, back
end

@inline _rewrap(x) = _rewrap(identity, x)
@inline _rewrap(wrap::F, x) where F  = wrap(x)
@inline _rewrap(::typeof(identity), x::Variable) = _rewrap(identity, unwrap(x))
@inline _rewrap(::typeof(identity), x::Const) = _rewrap(_cut, unwrap(x))
@inline _rewrap(::typeof(_cut), x::Variable) = _rewrap(identity, unwrap(x))
@inline _rewrap(::typeof(_cut), x::Const) = _rewrap(_cut, unwrap(x))

using BroadcastableStructs:
    BroadcastableCallable,
    BroadcastableStruct,
    calling,
    deconstruct,
    reconstruct

@inline function _rewrap(wrap::F, obj::T) where {F, T <: BroadcastableStruct}
    fields = map(x -> _rewrap(wrap, x), fieldvalues(obj))
    return constructorof(T)(fields...)
end

@adjoint function Broadcast.broadcasted(
    c::Union{Const{<:BroadcastableCallable}, BroadcastableCallable},
    args...,
)
    obj = _rewrap(c) :: BroadcastableCallable
    y, back = broadcast_adjoint(
        calling(obj),
        deconstruct(obj)...,
        args...,
    )
    function broadcastablecallable_pullback(Δ)
        partials = back(Δ)
        partials === nothing && return nothing
        ∂obj, ∂args = reconstruct(obj, Base.tail(partials)...) do T, fields
            NamedTuple{__fieldnames(T)}(fields)
        end
        return (∂obj, ∂args...)
    end
    return y, broadcastablecallable_pullback
end

end # module
