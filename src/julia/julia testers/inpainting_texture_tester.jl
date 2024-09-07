using ..inpainting_texture

using Images
using FileIO

main_dir = dirname(dirname(dirname(dirname(@__FILE__))))
img_dir_path = joinpath(main_dir, "Images")
restored_dir_path = joinpath(img_dir_path, "restored")
restored_dir_path = joinpath(restored_dir_path, "Texture")
mask_dir_path = joinpath(img_dir_path, "masks")
mickey_path = joinpath(img_dir_path, "lizard.jpg")
Omega_path = joinpath(mask_dir_path, "lizard_mask.jpg")

# Cargamos la imágen en blanco y negro
img = Gray.(load(mickey_path))

# Transformamos la imagen en un array
I_0 = Float64.(img)

# Cargamos el Omega en blanco y negro
Omega_image = Gray.(load(Omega_path))

# Preservamos los pixeles obscuros
Omega = Float64.(Omega_image)

block_size = Int64(floor(size(I_0, 1) / 6)) # 1/6 de un lado de la imagen, según recomendación del paper.

@time I_R = texture_inpainting(
    I_0, Omega, block_size0 = block_size
)

# Guardamos la imagen restaurada
#I_R = reverse(I_R, dims=1)
img_name, _ = splitext(basename(mickey_path))
save_path = joinpath(restored_dir_path, "$(img_name)_$(block_size)_restored.jpg")
ispath(restored_dir_path) || mkdir(restored_dir_path)
save(save_path, Gray.(I_R))
