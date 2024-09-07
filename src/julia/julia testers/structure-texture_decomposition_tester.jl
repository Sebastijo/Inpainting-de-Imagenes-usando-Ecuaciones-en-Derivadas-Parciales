using ..structure_texture_decomposition

using Images
using Statistics

const main_dir = dirname(dirname(dirname(dirname(@__FILE__))))
const img_dir_path::String = joinpath(main_dir, "Images")
const decomposition_dir_path::String = joinpath(img_dir_path, "decompositions")

const img_name::String = "barbara.jpg"
const dot_index::Int = findlast(==('.'), img_name)
const name_part::String = img_name[1:dot_index-1]
const extension_part::String = img_name[dot_index:end]

const test_img_path::String = joinpath(img_dir_path, img_name)

# Cargamos la imágen en blanco y negro
f = Float64.(Gray.(load(test_img_path)))

@time u, v, c1, c2, c3, c4, u_n_x, u_n_y = ST_decomposition(f; max_iters=100, p=1, lamb = 0.2, mu = 0.01, epsilon = 1e-1, ajuste = 0.0)

img_path_structure = name_part * "_structure" * extension_part
save_path_structure = joinpath(decomposition_dir_path, img_path_structure)
ispath(decomposition_dir_path) || mkdir(decomposition_dir_path)
save(save_path_structure, Gray.(u))
println("Estructure disponible en $(save_path_structure)")

uv::Array{Float64,2} = u + v
img_path_mixed = name_part * "_mixed" * extension_part
save_path_mixed = joinpath(decomposition_dir_path, img_path_mixed)
ispath(decomposition_dir_path) || mkdir(decomposition_dir_path)
save(save_path_mixed, Gray.(uv))
println("Mezcla disponible en $(save_path_mixed)")

img_path_texture = name_part * "_texture" * extension_part
save_path_texture = joinpath(decomposition_dir_path, img_path_texture)
ispath(decomposition_dir_path) || mkdir(decomposition_dir_path)
save(save_path_texture, Gray.(v .+ mean(f)))
println("Textura disponible en $(save_path_texture)")

println()

println("v + promedio de f")
println(minimum(v .+ mean(f)))
println(maximum(v .+ mean(f)))