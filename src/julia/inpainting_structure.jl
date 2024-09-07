module inpainting_structure

export structural_inpainting, anisotropic_iteration

using Base.Filesystem
# Agregamos la ubicación del entorno de Julia al path
main_dir = dirname(dirname(dirname(@__FILE__)))
push!(LOAD_PATH, main_dir)

include("./dilatador.jl")
using FileIO
using ProgressMeter
using LinearAlgebra
using .dilatador

"""
anisotropic_iteration(
	I_0::Array{Float64, 2};
	K::Float64 = 0.09,
	dt::Float64 = 1/20,
	)::Array{Float64, 2}

Función que recibe una imagen en forma de array y aplica una iteración del algoritmo de difusión
anisotrópica presentado en el siguiente artículo:

P. Perona and J. Malik *Scale-space and edge detection using
anisotropic diffusion*. IEEE-PAMI 12, pp. 629-639, 1990.

y sugerido en el siguiente artículo:

M. Bertalmio, G. Sapiro, V. Caselles, and C. Ballester, “Image
inpainting,” in *Comput. Graph. (SIGGRAPH 2000)*, July 2000, pp.
417–424.

que consiste en una implementación de diferencias finitas para resolver la Ecuación de Difusión
Anisotrópica

∂I/∂t = div(g(‖∇I‖) ∇I)

donde I es la función de imágen, ∇ y div son el gradiente y la divergencia respectivamente, y g
es una función (suficientemente regular) de conductividad que debe ser no-negativa, monótona
decreciente que cumple g(0)=1. En este caso, usaremos la función g(x) = exp(-x^2/K^2), donde K es
la constante de difusión.

# Arguments
- `I_0::Array{Float64, 2}`: imagen en forma de array.
- `K::Float64`: constante de difusión: mientras más cercana a 0, más se preservan los bordes (default: 0.1).
- `dt::Float64`: tamaño de paso (default: 1/50).

# Returns
- `Array{Float64, 2}`: imagen después de una iteración de difusión anisotrópica.

# Raises
- `ArgumentError`: si `dt` no está entre 0 y 1/4.

"""
function anisotropic_iteration(
    I_0::Array{Float64,2};
    K::Float64=0.05,
    dt::Float64=1 / 5,
)::Array{Float64,2}

    if !(0 < dt < 1 / 4)
        throw(ArgumentError("dt debe estar entre 0 y 1/4"))
    end

    # Inicializamos el siguiente I_n
    In_siguiente = copy(I_0)
    In = copy(I_0)

    function g(x::Float64)::Float64
        return exp(-x^2 / K^2)
    end

    for (i, j) in Iterators.product(1:size(In, 1), 1:size(In, 2))

        # N-> Norte, S-> Sur, E-> Este, O-> Oeste

        # Ecuación 8
        # Diferencias a los vecinos más cercanos
        DNIn = In[max(i - 1, 1), j] - In[i, j]
        DSIn = In[min(i + 1, size(In, 1)), j] - In[i, j]
        DEIn = In[i, min(j + 1, size(In, 2))] - In[i, j]
        DOIn = In[i, max(j - 1, 1)] - In[i, j]

        # Ecuación 10
        # Coeficientes de conducción (aproximados)
        cNn = g(abs(DNIn))
        cSn = g(abs(DSIn))
        cEn = g(abs(DEIn))
        cOn = g(abs(DOIn))

        # Ecuación 7
        # Discretisación de 4 vecinos cercanos de Laplaceano
        L = cNn * DNIn + cSn * DSIn + cEn * DEIn + cOn * DOIn
        In_siguiente[i, j] = In[i, j] + dt * L
    end
    In = copy(In_siguiente)
    return In
end

"""
inpaint_iteration(
	In::Array{Float64, 2},
	Omega::BitMatrix,
	dt::Float64,
	eps::Float64,
	)::Array{Float64, 2}

Función que recibe una imagen en forma de array, un mask Omega y aplica una iteración del algoritmo
de inpainting presentado en el siguiente artículo:

M. Bertalmio, G. Sapiro, V. Caselles, and C. Ballester, “Image
inpainting,” in *Comput. Graph. (SIGGRAPH 2000)*, July 2000, pp.
417–424.

que consiste en una implementación de diferencias finitas para resolver la Ecuación de Inpainting

∂I/∂t = ∇(ΔI)⋅∇ᵀI

en Omega, donde I es la función de imágen, ∇ y ∇ᵀ son el gradiente y el transpuesto del gradiente
respectivamente, y Δ es el Laplaciano.

# Arguments
- `In::Array{Float64, 2}`: imagen en forma de array.
- `Omega::BitMatrix`: mask con los pixeles a restaur.
- `dt::Float64`: tamaño de paso.
- `eps::Float64`: regularizador para evitar divisiones por cero.

# Returns
- `Array{Float64, 2}`: imagen después de una iteración de inpainting.
"""
function inpaint_iteration(
    In::Array{Float64,2},
    Omega::BitMatrix,
    dt::Float64,
    eps::Float64,
)::Array{Float64,2}
    # Inicializamos el siguiente I_n
    In_siguiente = copy(In)

    # Ecuación 8
    function L(I, i, j)
        Inxx = I[max(i - 1, 1), j] - 2 * I[i, j] + I[min(i + 1, size(I, 1)), j]
        Inyy = I[i, max(j - 1, 1)] - 2 * I[i, j] + I[i, min(j + 1, size(I, 2))]
        return Inxx + Inyy
    end

    # Iteramos sobre los pixeles
    for (i, j) in Iterators.product(1:size(In, 1), 1:size(In, 2))
        # Revisamos si el pixel está en el Omega
        if Omega[i, j]
            # Ecuación 7
            dLn = [
                L(In, min(i + 1, size(In, 1)), j) - L(In, max(i - 1, 1), j),
                L(In, i, min(j + 1, size(In, 2))) - L(In, i, max(j - 1, 1)),
            ]

            # Ecuación 9
            Inx = (In[min(i + 1, size(In, 1)), j] - In[max(i - 1, 1), j]) / 2
            Iny = (In[i, min(j + 1, size(In, 2))] - In[i, max(j - 1, 1)]) / 2
            Nn = [-Iny, Inx]
            norm_Nn = sqrt(Nn[1]^2 + Nn[2]^2 + eps)
            Nn_normalized = Nn / norm_Nn
            # Ecuación 10
            bn = dot(dLn, Nn_normalized)

            # Ecuación 11
            Inxbm = min(In[i, j] - In[max(i - 1, 1), j], 0)
            InxbM = max(In[i, j] - In[max(i - 1, 1), j], 0)
            Inxfm = min(In[min(i + 1, size(In, 1)), j] - In[i, j], 0)
            InxfM = max(In[min(i + 1, size(In, 1)), j] - In[i, j], 0)
            Inybm = min(In[i, j] - In[i, max(j - 1, 1)], 0)
            InybM = max(In[i, j] - In[i, max(j - 1, 1)], 0)
            Inyfm = min(In[i, min(j + 1, size(In, 2))] - In[i, j], 0)
            InyfM = max(In[i, min(j + 1, size(In, 2))] - In[i, j], 0)
            norm_grad_In_positive = sqrt(
                Inxbm^2 + InxfM^2 + Inybm^2 + InyfM^2,
            )
            norm_grad_In_negative = sqrt(
                InxbM^2 + Inxfm^2 + InybM^2 + Inyfm^2,
            )
            norm_grad_In = (
                bn > 0 ? norm_grad_In_positive : norm_grad_In_negative
            )

            # Ecuación 6
            Int = dot(dLn, Nn_normalized) * norm_grad_In

            # Ecuación 5
            In_siguiente[i, j] = In[i, j] + dt * Int

        end
    end
    In = copy(In_siguiente)
    return In
end

"""
structural_inpainting(
	img::Array{Float64, 2}, 
	Omega::Array{Float64, 2},
	max_iters::Int=3000, 
	dt::Float64=0.1, 
	eps::Float64=1e-7
	dilatacion::Int=0
    difussion::Float64=0.05
    dt_ani::Float64=1 / 20
	) :: Array{Float64 ,2}

Función que recibe el path a una imagen y el path a un mask, en la forma de una inágen con la misma
cantidad de pixeles que la imagen original. La imagen del mask, Omega, debe ser completamente negra
exceptuando los puntos a restaurar, que deben ser absolutamente blancos. max_iters corresponde a la
cantidad de repeticiones que se desea aplicar del algoritmo presentado en el siguiente artículo:

M. Bertalmio, G. Sapiro, V. Caselles, and C. Ballester, “Image
inpainting,” in *Comput. Graph. (SIGGRAPH 2000)*, July 2000, pp.
417-424.

# Arguments
- `img::Array{Float64, 2}`: La imagen a la que se le quiere realizar inpainting.
- `Omega::Array{Float64, 2}`: La imagen que contiene el Omega, debe ser una imágen con las mismas
dimensiones que la imagen original. La zona para realizar el inpainting, Ogema, debe estar en blanco,
todo el resto debe estar en negro.
- `A::Int`: cantidad de iteraciones de inpainting (en un cíclo).
- `B::Int`: cantidad de iteraciones de difusión anisotrópica (en un cíclo).
- `max_iters::Int`: número de interaciones por realizar al algoritmo de inpainting (default: 3000).
- `anisotropic_iters::Int`: número de iteraciones por realizar al algoritmo de difusión anisotrópica (default: 3000).
- `dt::Float64`: velocidad de la eviolución (default: 0.07).
- `eps::Float64`: regularizador para evitar divisiones por cero (default: 1e-7)
- `dilatacion::Int`: dilatación del mask (default: 0) 
- `difussion::Float64` La constante de difusión K de la difusión anisotrópica. Mientras más cercana a 0,
menor difusión (defauls: 0.05)
- `dt_adni::Float64` El paso en el tiempo de la difusión anisotrópica.

# Returns
- `Array{Float64, 2}`: array con la luminocidad de cada pixel.
"""
function structural_inpainting(
    img::Array{Float64,2},
    Omega::Array{Float64,2};
    A::Int=15,
    B::Int=2,
    max_iters::Int=3000,
    anisotropic_iters::Int=500,
    dt::Float64=0.1,
    eps::Float64=1e-8,
    dilatacion::Int=1,
    difussion::Float64=0.05,
    dt_ani::Float64=1 / 20,
)::Array{Float64,2}
    if max_iters < 1
        throw(ArgumentError("max_iters debe ser mayor que 1"))
    end
    I_0 = Float64.(img)
    Omega = Float64.(Omega) .> 0.5

    if size(Omega) != size(I_0)
        throw(ArgumentError(
            "Omega y img deben tener la misma cantida de pixeles.",
        ))
    end

    # Aplicamos difusión anisotrópica (preprocesamos la imágen)
    if anisotropic_iters > 0
        println()
        println("Applying anisotropic difussion...")
        anisotropic_progress = Progress(anisotropic_iters, 1, "Anisotropic")
        for _ in 1:anisotropic_iters
            I_0 = anisotropic_iteration(I_0; K=difussion, dt=dt_ani)
            next!(anisotropic_progress)
        end
    end

    # Establecemos los valores de la imagen que estén en el Omega como 0.5
    I_0[Omega] .= 0.5
    I_0[Omega] .= sum(I_0) / (size(I_0, 1) * size(I_0, 2))

    # Dilatamos el conjunto de inpainting
    for _ in 1:dilatacion
        Omega = dilate_bitmatrix(Omega)
    end

    # Inicializamos las image functions
    In = copy(I_0)

    # Iteramos sobre los tiempos, alternamos ente inpainting y anisotrópica (acorde a A y B)
    println()
    println("Starting inpainting process...")
    inpainting_progress = Progress(max_iters, 1, "Inaptinting")
    for n in 1:max_iters
        if n % (A + B) < A
            In = inpaint_iteration(In, Omega, dt, eps)
        else
            In = anisotropic_iteration(In; K=difussion, dt=dt_ani)
        end

        next!(inpainting_progress)
    end
    I_R = In
    return I_R
end

end



