using PyCall
using StatsBase

import Base: convert, show

@compat abstract type Layer end

convert{T<:Layer}(t::Type{T}, x::PyObject) = error("convert(::Type{$T}, ::PyObject) not implemented.")
PyObject{T<:Layer}(l::T) = error("PyObject(::$T) not implemented.")

function StatsBase.weights{T<:Layer}(l::T)
    obj = PyObject(l)
    return obj[:get_weights]()
end

function weights!{T<:Layer}(l::T, W::Array)
    obj = PyObject(l)
    obj[:set_weights](W)
end

function config{T<:Layer}(l::T)
    obj = PyObject(l)
    return obj[:get_config]()
end

function input{T<:Layer}(l::T)
    obj = PyObject(l)
    return Tensor(obj[:input])
end

function input{T<:Layer}(l::T, i::Int)
    obj = PyObject(l)
    return Tensor(obj[:get_input_at](i))
end

function output{T<:Layer}(l::T)
    obj = PyObject(l)
    return Tensor(obj[:output])
end

function output{T<:Layer}(l::T, i::Int)
    obj = PyObject(l)
    return Tensor(obj[:get_output_at](i))
end

function input_shape{T<:Layer}(l::T)
    obj = PyObject(l)
    return obj[:input_shape]
end

function input_shape{T<:Layer}(l::T, i::Int)
    obj = PyObject(l)
    return obj[:get_input_shape_at](i)
end

function output_shape{T<:Layer}(l::T)
    obj = PyObject(l)
    return obj[:output_shape]
end

function output_shape{T<:Layer}(l::T, i::Int)
    obj = PyObject(l)
    return obj[:get_output_shape_at](i)
end

export Layer, weights!, config, input, output, input_shape, output_shape

module Layers

import PyCall: PyObject, pycall, pybuiltin

import ..Keras
import ..Keras: PyDoc

#===========================================
Autogenerating Keras layer wrappers.
===========================================#
const keras_layers = Dict{String, Array}(
    "core" => [
        "Dense",
        "Activation",
        "Dropout",
        "Flatten",
        "Reshape",
        "Permute",
        "RepeatVector",
        "Lambda",
        "ActivityRegularization",
        "Masking",
        "InputLayer",
    ],
    "convolutional" => [
        "Conv1D",
        "Conv2D",
        "SeparableConv2D",
        "Conv2DTranspose",
        "Conv3D",
        "Cropping1D",
        "Cropping2D",
        "Cropping3D",
        "UpSampling1D",
        "UpSampling2D",
        "UpSampling3D",
        "ZeroPadding1D",
        "ZeroPadding2D",
        "ZeroPadding3D",
    ],
    "pooling" => [
        "MaxPooling1D",
        "MaxPooling2D",
        "MaxPooling3D",
        "AveragePooling1D",
        "AveragePooling2D",
        "AveragePooling3D",
        "GlobalMaxPooling1D",
        "GlobalMaxPooling2D",
        "GlobalAveragePooling1D",
        "GlobalAveragePooling2D",
    ],
    "local" => [
        "LocallyConnected1D",
        "LocallyConnected2D"
    ],
    "recurrent" => [
        "Recurrent",
        "SimpleRNN",
        "GRU",
        "LSTM",
    ],
    "embeddings" => [
        "Embedding",
    ],
    "merge" => [
        "Add",
        "Multiply",
        "Average",
        "Maximum",
        "Concatenate",
        "Dot",
    ],
    "advanced_activations" => [
        "LeakyReLU",
        "PReLU",
        "ELU",
        "ThresholdedReLU",
    ],
    "normalization" => [
        "BatchNormalization",
    ],
    "noise" => [
        "GaussianNoise",
        "GaussianDropout",
    ],
    "wrappers" => [
        "TimeDistributed",
        "Bidirectional",
    ],
)

for (submod, layers) in keras_layers
    for l in layers
        layer_name = Symbol(l)

        @eval begin
            type $layer_name <: Keras.Layer
                obj::PyObject

                @doc PyDoc(Keras._layers, Symbol($l)) function $layer_name(args...; kwargs...)
                    new(Keras._layers[Symbol($l)](args...; kwargs...))
                end

                # Create Layer from existing Keras layer PyObject
                function $layer_name(o::PyObject)
                    # Check if it is correct layer
                    if !pybuiltin(:isinstance)(o, Keras._layers[Symbol($l)])
                        msg = string("Tried to create layer ", $l, ", but ", o, " is not matching ", Keras._layers[Symbol($l)])
                        throw(ParseError(msg))
                    end
                    # Wrap PyObject
                    new(o)
                end
            end

            #convert(::Type{$(layer_name)}, obj::PyObject) = $layer_name(obj)
            PyObject(layer::$(layer_name)) = layer.obj
            # Base.Docs.doc(layer::$(layer_name)) = Base.Docs.doc(layer.obj)
            function (layer::$(layer_name))(args...; kwargs...)
                obj = PyObject(layer)
                return obj[:__call__](args...; kwargs...)
            end
        end
    end
end

const keras_merge_funcs = [
    "add",
    "multiply",
    "average",
    "maximum",
    "concatenate",
    "dot",
]

for l in keras_merge_funcs
    layer_name = Symbol(l)

    @eval begin
        @doc PyDoc(Keras._layers, Symbol($l)) function $layer_name(args...; kwargs...)
            Keras._layers[Symbol($l)](args...; kwargs...)
        end
    end
end

end
