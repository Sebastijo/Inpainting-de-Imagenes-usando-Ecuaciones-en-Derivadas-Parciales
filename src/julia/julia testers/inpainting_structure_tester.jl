using ..inpainting_structure

using Images
using FileIO

main_dir = dirname(dirname(dirname(dirname(@__FILE__))))
img_dir_path = joinpath(main_dir, "Images")
restored_dir_path = joinpath(img_dir_path, "restored")
restored_dir_path = joinpath(restored_dir_path, "Structure")
mask_dir_path = joinpath(img_dir_path, "masks")
img_path = joinpath(img_dir_path, "Mickey.jpg")
Omega_path = joinpath(mask_dir_path, "Mickey_mask.jpg")

img = load(img_path)

# Extraemos los canales de la imagen
red_channel = red.(img)
green_channel = green.(img)
blue_channel = blue.(img)

# Transformamos la imagen en un array
channels = [Float64.(red_channel), Float64.(green_channel), Float64.(blue_channel)]

# Cargamos el Omega en blanco y negro
Omega_image = Gray.(load(Omega_path))
# Preservamos los pixeles obscuros
Omega = Float64.(Omega_image)

for i in 1:3
	println("Channel $i")
	channels[i] = structural_inpainting(
		channels[i], Omega; dilatacion=1, anisotropic_iters=1, max_iters=30000, difussion=0.1, dt_ani=1/45, dt=0.08 # difussion=0.05
	)
end

# Combine the channels back into a single image
I_R = colorview(RGB, channels[1], channels[2], channels[3])

# Guardamos la imagen restaurada
save_path = joinpath(restored_dir_path, "Restored_jump.jpg")
ispath(restored_dir_path) || mkdir(restored_dir_path)
save(save_path, I_R)
println("Imagen restaurada disponible en $(save_path)")
