module structure_texture_decomposition

export ST_decomposition

using Base.Filesystem
# Agregamos la ubicación del entorno de Julia al path
const main_dir = dirname(dirname(dirname(@__FILE__)))
push!(LOAD_PATH, main_dir)

using FileIO
using ProgressMeter
using LinearAlgebra
using Statistics

"""
pad_array(arr::Array{Float64, 2})::Array{Float64, 2}

Función que recibe un array y regresa el mismo array pero con 2 columans y dos filas más.
Estas filas y columnas se generan copiando la fila/columna más cercana a la orilla del array
original.

Ejemplo:

c

->

c  c  c\\
c  c  c\\
c  c  c

# Arguments
- `arr::Array{Float64, 2}`: array de dos dimensiones.

# Returns
- `Array{Float64, 2}`: array de dos dimensiones con dos filas y dos columnas más que el array original.
"""
function pad_array(arr::Array{Float64,2})::Array{Float64,2}
    
    padded_arr::Array{Float64,2} = zeros(size(arr) .+ 2)

    # Center
    padded_arr[2:end-1, 2:end-1] .= arr

    # Top and Bottom
    padded_arr[1, 2:end-1] .= arr[1, :]
    padded_arr[end, 2:end-1] .= arr[end, :]

    # Left and Right
    padded_arr[2:end-1, 1] .= arr[:, 1]
    padded_arr[2:end-1, end] .= arr[:, end]

    # Corners
    padded_arr[1, 1] = arr[1, 1]
    padded_arr[1, end] = arr[1, end]
    padded_arr[end, 1] = arr[end, 1]
    padded_arr[end, end] = arr[end, end]

    return padded_arr
end


function null_pad_array(arr::Array{Float64,2})::Array{Float64,2}
    
    padded_arr::Array{Float64,2} = zeros(size(arr) .+ 2)

    # Center
    padded_arr[2:end-1, 2:end-1] .= arr

    return padded_arr
end


"""
ST-decomposition(
	f::Array{Float64, 2};
	lamb::Float64 = 1/10,
	mu::Float64 = 1/10,
    p::Int = 1,
    max_iters::Int = 100,
    epsilon = 1.5
	)::Tuple{Array{Float64, 2}, Array{Float64, 2}}

Función que recibe una imagen y regresa la textura y la estructura de la imagen mediante el método
presentado en

L. Vese and S. Osher, “Modeling Textures with Total Variation Min-
imization and Oscillating Patterns in Image Processing,”, vol. 02-19,
UCLA CAM Rep., May 2002.

y sugerido en

M. Bertalmio, L. Vese, G. Sapiro, and S. Osher, "Simultaneous
Structure and Texture Image Inpainting," IEEE Transactions on 
Image Processing, vol. 12, no. 8, pp. 882-889, August 2003.

La intención es descomponer la imagen en la forma 
f = u + v,
donde u es la estructura de la imagen, es decir, una imágen con bordes claros que contienen partes
homogéneas de la imagen original, y v es la textura (y ruido) de la imagen, es decir, una imágen
constituida de patrones repetidos con detalles de pequeña escala (de valores no relacionados, en
el caso de ruido).

# Arguments
- `f::Array{Float64, 2}`: imagen en forma de array.
- `lamb::Float64`: peso asociado al error ||f - (u + v)||_2 (default: 1/10).
- `mu::Float64`: peso asociado a la norma de v (default: 1/10).
- 'p::Int': parámetro de la norma p a utilizar (más grande, mas preciso pero más lento) (default: 1).
- 'max_iters::Int': número máximo de iteraciones (default: 100).
- 'epsilon': parámetro para evitar divisiones por cero (default: 1.5).

# Returns
- `Tuple{Array{Float64, 2}, Array{Float64, 2}}`: tupla con la estructura y la textura de la imagen.

# Raises
- `ArgumentError`: si `lamb` o `mu` no son no-negativos.
- `ArgumentError`: si `p` no es un entero positivo.
"""
function ST_decomposition(
    f::Array{Float64,2};
    lamb::Float64=0.16,
    mu::Float64=0.01,
    p::Int=1,
    max_iters::Int=100,
    epsilon::Float64 = 1e-1,
    ajuste::Float64 = 1.5
)#::Tuple{Array{Float64,2},Array{Float64,2}}
    if lamb < 0 || mu < 0
        throw(ArgumentError("lamb y mu deben ser no-negativos"))
    end
    if p <= 0
        throw(ArgumentError("p debe ser un entero positivo"))
    end

    f_pad::Array{Float64,2} = pad_array(f)
    f_x::Array{Float64,2} = zeros(size(f_pad)) # df/dx
    f_y::Array{Float64,2} = zeros(size(f_pad)) # df/dy
    @. f_x[2:end-1, 2:end-1] = (f_pad[3:end, 2:end-1] - f_pad[1:end-2, 2:end-1]) / 2.0
    @. f_y[2:end-1, 2:end-1] = (f_pad[2:end-1, 3:end] - f_pad[2:end-1, 1:end-2]) / 2.0

    f_x = f_x[2:end-1, 2:end-1]
    f_y = f_y[2:end-1, 2:end-1]

    gradient_magnitude::Array{Float64,2} = similar(f)
    @. gradient_magnitude = sqrt(f_x .^ 2 + f_y .^ 2)

    g1_n::Array{Float64,2} = similar(f)
    g2_n::Array{Float64,2} = similar(f)

    u_n::Array{Float64,2} = copy(f)
    @. g1_n = (-1 / (2 * lamb)) * (f_x / (gradient_magnitude + epsilon))
    @. g2_n = (-1 / (2 * lamb)) * (f_y / (gradient_magnitude + epsilon))

    c1::Array{Float64,2} = zeros(size(u_n))
    c2::Array{Float64,2} = zeros(size(u_n))
    c3::Array{Float64,2} = zeros(size(u_n))
    c4::Array{Float64,2} = zeros(size(u_n))

    println()
    println("applying structure-texture decomposition...")
    decomposition_progress = Progress(max_iters, 1, "Decomposing")

    u_n_next::Array{Float64,2} = similar(f)
    g1_n_next::Array{Float64,2} = similar(f)
    g2_n_next::Array{Float64,2} = similar(f)
    
    for _ in 1:max_iters
        u_n = pad_array(u_n)
        g1_n = null_pad_array(g1_n)
        g2_n = null_pad_array(g2_n)

        @. c1 = 1 / (epsilon + sqrt(
            (u_n[3:end, 2:end-1] - u_n[2:end-1, 2:end-1])^2
            +
            ((u_n[2:end-1, 3:end] - u_n[2:end-1, 1:end-2]) / 2.0)^2
        ))
        @. c2 = 1 / (epsilon + sqrt(
            (u_n[2:end-1, 2:end-1] - u_n[1:end-2, 2:end-1])^2
            +
            ((u_n[1:end-2, 3:end] - u_n[1:end-2, 1:end-2]) / 2.0)^2
        ))
        @. c3 = 1 / (epsilon + sqrt(
            ((u_n[3:end, 2:end-1] - u_n[1:end-2, 2:end-1]) / 2.0)^2
            +
            (u_n[2:end-1, 3:end] - u_n[2:end-1, 2:end-1])^2
        ))
        @. c4 = 1 / (epsilon + sqrt(
            ((u_n[3:end, 1:end-2] - u_n[1:end-2, 1:end-2]) / 2.0)^2
            +
            (u_n[2:end-1, 2:end-1] - u_n[2:end-1, 1:end-2])^2
        ))

        @. u_n_next = (1 / (1 + 1 / (2 * lamb) * (c1 + c2 + c3 + c4))) * (
            f_pad[2:end-1, 2:end-1] - (g1_n[3:end, 2:end-1] - g1_n[1:end-2, 2:end-1]) / 2.0 - (g2_n[2:end-1, 3:end] - g2_n[2:end-1, 1:end-2]) / 2.0
            +
            1 / (2 * lamb) * (c1 * u_n[3:end, 2:end-1] + c2 * u_n[1:end-2, 2:end-1] + c3 * u_n[2:end-1, 3:end] + c4 * u_n[2:end-1, 1:end-2])
        )

        # Compute the matrix sqrt(g1^2 + g2^2)
        magnitude = sqrt.(g1_n.^2 .+ g2_n.^2)
        
        # Compute the p-norm of the magnitude matrix
        p_norm = norm(magnitude, p)
        
        # Calculate (p_norm)^(1-p)
        factor = (p_norm + epsilon)^(1-p)
        
        # Compute (magnitude)^(p-2)
        magnitude_power = (magnitude .+ epsilon).^(p-2)
        
        # Combine the results
        Hg1g2 = factor * magnitude_power

        println(mean(Hg1g2))

        @. g1_n_next = (2 * lamb / (ajuste + mu * Hg1g2[2:end-1, 2:end-1] + 4 * lamb)) * (
            (u_n[3:end, 2:end-1] - u_n[1:end-2, 2:end-1]) / 2.0
            -
            (f_pad[3:end, 2:end-1] - f_pad[1:end-2, 2:end-1]) / 2.0
            +
            g1_n[3:end, 2:end-1] + g1_n[1:end-2, 2:end-1]
            +
            1 / 2 * (
                2 * g2_n[2:end-1, 2:end-1]
                +
                g2_n[1:end-2, 1:end-2]
                +
                g2_n[3:end, 3:end]
                -
                g2_n[2:end-1, 1:end-2]
                -
                g2_n[1:end-2, 2:end-1]
                -
                g2_n[3:end, 2:end-1]
                -
                g2_n[2:end-1, 3:end]
            )
        )
        
        @. g2_n_next = (2 * lamb / (ajuste + mu * Hg1g2[2:end-1, 2:end-1] + 4 * lamb)) * (
            (u_n[2:end-1, 3:end] - u_n[2:end-1, 1:end-2]) / 2.0
            -
            (f_pad[2:end-1, 3:end] - f_pad[2:end-1, 1:end-2]) / 2.0
            +
            g2_n[2:end-1, 3:end] + g2_n[2:end-1, 1:end-2]
            +
            1 / 2 * (
                2 * g1_n[2:end-1, 2:end-1]
                +
                g1_n[1:end-2, 1:end-2]
                +
                g1_n[3:end, 3:end]
                -
                g1_n[2:end-1, 1:end-2]
                -
                g1_n[1:end-2, 2:end-1]
                -
                g1_n[3:end, 2:end-1]
                -
                g1_n[2:end-1, 3:end]
            )
        )

        u_n = u_n_next
        g1_n = g1_n_next
        g2_n = g2_n_next

        next!(decomposition_progress)
    end

    g1_pad::Array{Float64,2} = pad_array(g1_n)
    g2_pad::Array{Float64,2} = pad_array(g2_n)
    g1_x::Array{Float64,2} = zeros(size(g1_pad)) # dg1/dx
    g2_y::Array{Float64,2} = zeros(size(g2_pad)) # dg2/dy
    @. g1_x[2:end-1, 2:end-1] = (g1_pad[3:end, 2:end-1] - g1_pad[1:end-2, 2:end-1]) / 2.0
    @. g2_y[2:end-1, 2:end-1] = (g2_pad[2:end-1, 3:end] - g2_pad[2:end-1, 1:end-2]) / 2.0

    g1_x = g1_x[2:end-1, 2:end-1]
    g2_y = g2_y[2:end-1, 2:end-1]

    u::Array{Float64,2} = u_n
    v::Array{Float64,2} = g1_x + g2_y

    u_n_x = ((u_n[3:end, 2:end-1] - u_n[1:end-2, 2:end-1]) / 2.0)
    u_n_y = ((u_n[2:end-1, 3:end] - u_n[2:end-1, 1:end-2]) / 2.0)

    return (u, v, c1, c2, c3, c4, u_n_x, u_n_y)
end

end