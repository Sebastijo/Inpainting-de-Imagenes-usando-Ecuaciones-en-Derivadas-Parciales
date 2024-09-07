module inpainting_texture_old

export texture_inpainting

using Base.Filesystem
# Agregamos la ubicación del entorno de Julia al path
main_dir = dirname(dirname(dirname(@__FILE__)))
push!(LOAD_PATH, main_dir)

using FileIO
using ProgressMeter

"""
texture_inpainting(
I0::Array{Float64, 2};
Omega0::Array{Float64, 2},
block_size0::Int64 = 0,
)::Array{Float64, 2}

Función principal del programa. Recibe una imagen en forma de array y
aplica inpainting por sintésis de textura, basándose en el siguiente artículo:

A. A. Efros and W. Freeman, “Image quilting for texture synthesis and
transfer,” presented at the Proc. SIGGRAPH, 2001.

Sólo actualizando los bloques que interseptan Omega, usando sólo bloques que no
interseptan Omega.

Si el bloque se sale, es desplazado para quedar dentro de la imagen, siendo
la zona de solape dependiente a este desplazamiento en caso de ocurrir.

# Arguments
- `I0::Array{Float64, 2}`: imagen en forma de array.
- `Omega0::Array{Float64, 2}`: máscara de pixeles a preservar.
- `block_size0::Int64`: tamaño de los bloques a usar (default: 1/6 de la imagen).

# Returns
- `Array{Float64, 2}`: imagen restaurada.
"""
function texture_inpainting(
    I0::Array{Float64,2},
    Omega0::Array{Float64,2};
    block_size0::Int=Int64(floor(size(I0, 1) / 6)),
)::Array{Float64,2}
    global I = I0
    global I_orig = copy(I) #Es para reparar los bloques a la derecha y abajo del hoyo
    global Omega = Omega0 .> 0.5
    if size(Omega) != size(I)
        throw(ArgumentError(
            "Omega y img deben tener la misma cantidad de pixeles."
        ))
    end

    # Establecemos los valores de la imagen que estén en el Omega como 0.5
    I[Omega] .= 0


    if block_size0 == 0 #En el paper se indica que un buen tamaño es 1/6 de la imagen
        block_size0 = div(minimum(size(I)), 6)
    end

    global block_size = block_size0
    global overlap_size = div(block_size, 3)


    upper, left = false, false
    I_height, I_width = size(I)
    # Cuantos bloques caben en ancho y largo, permitiendo que el último sobresalga
    n_rows = div(I_height, block_size - overlap_size) + (%(I_height, block_size) == 0 ? 0 : 1)
    n_cols = div(I_width, block_size - overlap_size) + (%(I_width, block_size) == 0 ? 0 : 1)

    function block_to_coor(i_block, j_block)
        #coordenadas a partir de la posición del bloque
        i = (i_block - 1) * (block_size - overlap_size) + 1
        j = (j_block - 1) * (block_size - overlap_size) + 1

        # Si sobresale
        if i + block_size > I_height
            i = I_height - block_size + 1
        end
        if j + block_size > I_width
            j = I_width - block_size + 1
        end
        return i, j
    end

    println()
    println("Applying texture inpainting...")
    texture_progress = Progress(n_rows * n_cols + 1, 1, "Texture")
    for (i_block, j_block) in Iterators.product(1:n_rows, 1:n_cols)
        next!(texture_progress)
        if (i_block, j_block) == (1, 1) # El primero no se puede reparar
            continue
        end
        i, j = block_to_coor(i_block, j_block)

        #Si el bloque contiene parte de omega, lo trabajamos
        if any(Omega[i:i+block_size-1, j:j+block_size-1])
            synthesize_block(i, j)
        else
            if i_block != 1
                i_prev_block = block_to_coor(i_block - 1, j_block)[1]
                #Si el bloque de arriba fue sintetizado
                if any(Omega[i_prev_block:i_prev_block+block_size-1, j:j+block_size-1])
                    cut_up(i, j)
                end
            end
            if j_block != 1
                j_prev_block = block_to_coor(i_block, j_block - 1)[2]
                #Si el bloque de la izq fue sintetizado
                if any(Omega[i:i+block_size-1, j_prev_block:j_prev_block+block_size-1])
                    cut_left(i, j)
                end
            end

        end
    end
    return I
end

"""
Le realiza el corte de error mínimo al bloque por arriba, sin cambiar el bloque.
"""
function cut_up(i, j)
    #se toma el bloque del original, sino la solapa de block es igual a la de upper_block
    #pues se sobrescribió al arreglar el upper_block
    block = I_orig[i:i+block_size-1, j:j+block_size-1]
    upper_i = i - (block_size - overlap_size)
    upper_block = I[upper_i:upper_i+block_size-1, j:j+block_size-1]
    cut_mask = minimum_cut_mask(block, 0, upper_block)
    cutted_block = block .* cut_mask
    #reemplazamos el bloque, con el nuevo bloque cortado arriba
    I[i:i+block_size-1, j:j+block_size-1] = I[i:i+block_size-1, j:j+block_size-1] .* (.~cut_mask)
    I[i:i+block_size-1, j:j+block_size-1] = I[i:i+block_size-1, j:j+block_size-1] .+ cutted_block
end
"""
Le realiza el corte de error mínimo al bloque por la izq, sin cambiar el bloque.
"""
function cut_left(i, j)
    #se toma el bloque del original, sino la solapa de block es igual a la de left_block
    #pues se sobrescribió al arreglar el left_block
    block = I_orig[i:i+block_size-1, j:j+block_size-1]
    left_j = j - (block_size - overlap_size)
    #I[i: i + block_size - 1, left_j: left_j + block_size - 1] .=1
    left_block = I[i:i+block_size-1, left_j:left_j+block_size-1]
    cut_mask = minimum_cut_mask(block, left_block, 0)
    cutted_block = block .* cut_mask
    #reemplazamos el bloque, con el nuevo bloque cortado arriba
    I[i:i+block_size-1, j:j+block_size-1] = I[i:i+block_size-1, j:j+block_size-1] .* (.~cut_mask)
    I[i:i+block_size-1, j:j+block_size-1] = I[i:i+block_size-1, j:j+block_size-1] .+ cutted_block
end

"""
synthesize_block(i,j) reconstruye el bloque dado por las coordenadas i,j usando el 
algoritmo dado por el paper.

Toma el bloque de encima, el de la izquierda o ambos, según corresponda y escoge
un bloque sin omega que satisfaga un umbral de error respecto a los bordes con estos
bloques (new_block). Luego calcula el corte de error mínimo para este nuevo bloque
respecto a los bloques de encima e izquierda y parchea el bloque en i,j con este nuevo
bloque.
"""
function synthesize_block(i, j)
    #inpainting_block = I[i: i + block_size - 1, j: j + block_size - 1] 

    #left
    if j != 1
        left = true
        left_j = j - (block_size - overlap_size)
        left_block = I[i:i+block_size-1, left_j:left_j+block_size-1]
    end
    #upper
    if i != 1
        upper = true
        upper_i = i - (block_size - overlap_size)
        upper_block = I[upper_i:upper_i+block_size-1, j:j+block_size-1]
    end
    new_block = search_block(
        left ? left_block : 0,
        upper ? upper_block : 0,
    )
    cut_mask = minimum_cut_mask(new_block, left_block, upper_block)
    cutted_new_block = new_block .* cut_mask
    #reemplazamos el bloque a inpaintear dentro del corte, con el nuevo bloque cortado
    I[i:i+block_size-1, j:j+block_size-1] = I[i:i+block_size-1, j:j+block_size-1] .* (.~cut_mask)
    I[i:i+block_size-1, j:j+block_size-1] = I[i:i+block_size-1, j:j+block_size-1] .+ cutted_new_block
end



"""
search_block recorre todos los bloques que no interceptan Omega, y calcula el error respecto a los solapes
del bloque a inpaintear llamando a  get_error.
Guarda los errores con las posiciones de los bloques, selecciona todos los que cumplan el umbral y de estos
elige uno aleatoriamente.
"""
function search_block(left_block, upper_block)
    I_height, I_width = size(I)

    # Cuantos bloques caben en ancho y largo, permitiendo que el último sobresalga
    n_rows = div(I_height, block_size - overlap_size) + (%(I_height, block_size) == 0 ? 0 : 1)
    n_cols = div(I_width, block_size - overlap_size) + (%(I_width, block_size) == 0 ? 0 : 1)

    candidates = Dict{Float64,Tuple{Int32,Int32}}()
    for (i_block, j_block) in Iterators.product(1:n_rows, 1:n_cols)
        #coordenadas a partir de la posición del bloque
        i = (i_block - 1) * (block_size - overlap_size) + 1
        j = (j_block - 1) * (block_size - overlap_size) + 1

        # Si sobresale
        if i + block_size > I_height
            i = I_height - block_size + 1
        end
        if j + block_size > I_width
            j = I_width - block_size + 1
        end

        #Si no contiene pixeles de la máscara lo evaluamos con get_error y agregamos a candidatos
        if !any(Omega[i:i+block_size-1, j:j+block_size-1])
            candidates[get_error(i, j, left_block, upper_block)] = (i, j)
        end
    end

    # Escogemos los candidatos con error dentro de un 0.1 veces el error del mejor candidato
    # (recomendación del paper)
    min_error = minimum(keys(candidates))
    margin = 1.1 * min_error
    best_candidates = [candidates[key] for key in filter(n -> n <= margin, keys(candidates))]
    i, j = rand(best_candidates)
    new_block = I[i:i+block_size-1, j:j+block_size-1]

    return new_block

end

"""
minimum_cut calcula el corte de frontera de menor error, y entrega una máscara 
correspondiente
"""
function minimum_cut_mask(new_block, left_block, upper_block)
    mask = .~BitArray(zero(new_block))
    if left_block != 0
        #Obtenemos la superficie de error
        left_ov1 = new_block[:, 1:overlap_size]
        left_ov2 = left_block[:, end-(overlap_size-1):end]
        e = (left_ov2 - left_ov1) .^ 2

        #Construimos E, error acumulado para todo trayecto
        E = zero(e)
        E[1, :] = e[1, :]
        for (i, j) in Iterators.product(2:size(e)[1], 1:size(e)[2])
            if j == 1
                E[i, j] = e[i, j] + minimum(E[i-1, j:j+1])
            elseif j == size(e)[2]
                E[i, j] = e[i, j] + minimum(E[i-1, j-1:j])
            else
                E[i, j] = e[i, j] + minimum(E[i-1, j-1:j+1])
            end
        end

        #Obtenemos el corte de error mínimo
        cut = Vector{Tuple{Int32,Int32}}()
        push!(cut, (size(e)[1], argmin(E[end, :])))
        for i in size(e)[1]:-1:2
            j = cut[end][2]
            if j == 1
                new_j = argmin(E[i-1, j:j+1])
            elseif j == size(e)[2]
                new_j = argmin(E[i-1, j-1:j])
            else
                new_j = argmin(E[i-1, j-1:j+1])
            end
            push!(cut, (i - 1, new_j))
        end

        #Actualizamos la máscara con el corte
        for (i, j) in cut
            mask[i, 1:j] .= 0
        end
    end
    if upper_block != 0
        #Obtenemos la superficie de error
        upper_ov1 = new_block[1:overlap_size, :]
        upper_ov2 = upper_block[end-(overlap_size-1):end, :]
        e = (upper_ov2 - upper_ov1) .^ 2

        #Construimos E, error acumulado para todo trayecto
        E = zero(e)
        E[:, 1] = e[:, 1]
        for (i, j) in Iterators.product(1:size(e)[1], 2:size(e)[2])
            if i == 1
                E[i, j] = e[i, j] + minimum(E[i:i+1, j])
            elseif i == size(e)[1]
                E[i, j] = e[i, j] + minimum(E[i-1:i, j])
            else
                E[i, j] = e[i, j] + minimum(E[i-1:i+1, j])
            end
        end

        #Obtenemos el corte de error mínimo
        cut = Vector{Tuple{Int32,Int32}}()
        push!(cut, (argmin(E[:, end]), size(e)[1]))
        for j in size(e)[2]:-1:2
            i = cut[end][1]
            if i == 1
                new_i = argmin(E[i:i+1, j])
            elseif i == size(e)[1]
                new_i = argmin(E[i-1:i, j])
            else
                new_i = argmin(E[i-1:i+1, j])
            end
            push!(cut, (new_i, j - 1))
        end

        #Actualizamos la máscara con el corte
        for (i, j) in cut
            mask[1:i, j] .= 0
        end
    end
    return mask
end



"""
get_error calcula el error asociado al bloque ubicado en la posición i,j respecto
a los bloques superiores e izq.
"""
function get_error(i, j, left_block, upper_block)
    candidate_block = I[i:i+block_size-1, j:j+block_size-1]

    error = 0
    if left_block != 0
        left_ov1 = candidate_block[:, 1:overlap_size]
        left_ov2 = left_block[:, end-(overlap_size-1):end]
        error += distance(left_ov1, left_ov2)
    end
    if upper_block != 0
        upper_ov1 = candidate_block[1:overlap_size, :]
        upper_ov2 = upper_block[end-(overlap_size-1):end, :]
        error += distance(upper_ov1, upper_ov2)
    end

    return error
end

"""
Calcula alguna medida de distancia entre matrices,
en este caso para ver el error en los solapes.
"""
function distance(matrix1, matrix2)::Float64
    if size(matrix1) != size(matrix2)
        throw(ArgumentError(
            "Ambas matrices deben tener igual tamaño"
        ))
    end
    mse = sum((matrix1 .- matrix2) .^ 2) / length(matrix1)
    return mse
end

end