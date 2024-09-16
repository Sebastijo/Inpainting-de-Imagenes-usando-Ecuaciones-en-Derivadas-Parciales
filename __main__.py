"""
Created on Tue Jun 12 00:23:00 2024
El objetivo de este script es el de ralizar el inpainting de una imagen mediante métodos de EDPN.
Este proyecto consituye el proyecto final del ramo Análisis Numérico de Ecuaciones en Derivadas Parciales
de la escuela de Ingeniería de la Universidad de Chile.
"""

import cv2  # Trabajar con imágenes
import numpy as np  # numpy
import julia  # Para importar funciones de Julia
from julia import Main  # Para importar funciones de Julia
from pathlib import Path  # Para trabajar con rutas de archivos
import os

try:  # Importamos la librería para crear barras de carga
    from tqdm import tqdm

    tqdm_is_available = True
except:
    tqdm_is_available = False
print("tqdm disponible:", tqdm_is_available)


# Definimos paths importantes:
# Carpeta principal del directorio
main_dir = Path(__file__).resolve().parent
# Carpeta de movies
movies_dir = main_dir / "Movies"
# Carpeta de imágenes
img_dir_path = main_dir / "Images"
# Carpeta de máscaras
mask_dir_path = img_dir_path / "masks"
# Carpeta de restored
restored_dir_path = img_dir_path / "restored"
# Carpeta src
src_path = main_dir / "src"
# Carpeta de Julia
julia_path = src_path / "julia"
# Carpeta de inpainting estructural de Julia
inpainting_structure_path = julia_path / "inpainting_structure.jl"
# Carpeta de inpainting textura de Julia
inpainting_texture_path = julia_path / "inpainting_texture.jl"

# Importamos modulos propios:
# Módulo para seleccionar una parte de la imagen
from src.python.masker import mask_image
from src.python.Structure_Texture_decomposition import ST_decomposition

# Incluir los archivos de inpainting estructural de Julia
Main.include(str(inpainting_structure_path))
Main.include(str(inpainting_texture_path))
# Importamos los modulos de inpainting de Julia
structure = Main.inpainting_structure
texture = Main.inpainting_texture


def list_of_frames_to_folder(frames: list[np.array], folder_path: Path) -> None:
    """
    Función que guarda una lista de frames en una carpeta.

    Args:
        frames (list[np.array]): Lista de frames.
        folder_path (Path): Ruta de la carpeta donde guardar los frames.

    Returns:
        None
    """
    os.makedirs(folder_path, exist_ok=True)

    # Get the number of digits for padding
    num_frames = len(frames)
    num_digits = len(str(num_frames))

    for i, frame in enumerate(frames):
        # Ensure frame is in uint8 format
        frame_uint8 = (
            (frame * 255).astype(np.uint8)
            if frame.max() <= 1
            else frame.astype(np.uint8)
        )

        # Format filename with leading zeros
        filename = f"frame_{i+1:0{num_digits}}.png"

        # Save the image
        cv2.imwrite(os.path.join(folder_path, filename), frame_uint8)


def inpaint(img_path: Path, anim_duration: float = 10.0) -> np.array:
    """
    Función que realiza el inpainting de una imagen.
    Entrega un np.array con la imagen restaurada y, además,
    guarda la imagen en la carpeta Images>restored.
    Permite seleccionar el área a restaurar dinámicamente.

    Args:
        img_path (Path): Ruta de la imagen a restaurar.
        anim_duration (float): Duración de la animación.


    Returns:
        np.array: Imagen restaurada.

    """
    # Crear la máscara de la imagen
    img, mask = mask_image(img_path)

    cv2.imwrite(str(img_dir_path / f"{img_path.stem}_danada.jpg"), img)

    K = 0.06
    difussion = K
    dt_ani = 1 / 45
    struct, text, anisotropic_frames = ST_decomposition(
        img, K=K, dt=dt_ani, anim_duration=anim_duration, max_iters=2000
    )
    text = text + 0.5

    list_of_frames_to_folder(anisotropic_frames, movies_dir / "anisotropic_frames")

    cv2.imwrite(
        str(img_dir_path / f"{img_path.stem}_danada_estructura.jpg"), struct * 255.0
    )
    cv2.imwrite(str(img_dir_path / f"{img_path.stem}_danada_textura.jpg"), text * 255.0)

    # Transformamos el mask en formato blanco y negro
    mask = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY) / 255.0

    # Separamos la imágen en sus canales RGB
    b_channel_struct, g_channel_struct, r_channel_struct = cv2.split(struct)
    channels_struct = {
        "R": r_channel_struct,
        "G": g_channel_struct,
        "B": b_channel_struct,
    }

    structural_frames_dict: dict[str, list[np.array]] = {
        color: None for color in channels_struct
    }
    # Inpainting de cada canal
    for color in channels_struct:
        print()
        print(f"Realizando inpainting de estructura para el color {color}")
        channels_struct[color], frames = structure.structural_inpainting(
            channels_struct[color],
            mask,
            anisotropic_iters=1,
            dt=0.3, #0.545 seems alright
            dilatacion=1,
            difussion=K,
            dt_ani=dt_ani,
            max_iters=30000,
        )

        structural_frames_dict[color] = frames

    structural_frames = [
        cv2.merge(
            [
                structural_frames_dict["B"][i],
                structural_frames_dict["G"][i],
                structural_frames_dict["R"][i],
            ]
        )
        for i in range(len(structural_frames_dict["R"]))
    ]

    list_of_frames_to_folder(structural_frames, movies_dir / "structural_frames")

    struct = cv2.merge(
        (channels_struct["B"], channels_struct["G"], channels_struct["R"])
    )

    cv2.imwrite(
        str(img_dir_path / f"{img_path.stem}_restaurada_estructura.jpg"), struct * 255.0
    )

    # Separamos la imágen en sus canales RGB
    b_channel_text, g_channel_text, r_channel_text = cv2.split(text)
    channels_text = {"R": r_channel_text, "G": g_channel_text, "B": b_channel_text}

    print()
    print(f"Realizando inpainting de textura")
    channels_text["R"], channels_text["G"], channels_text["B"], texture_frames = (
        texture.texture_inpainting(
            channels_text["R"],
            channels_text["G"],
            channels_text["B"],
            mask,
            block_size0=8, # 8 seems good enough
            acceptable_error0=1.1 # suggeste by paper
        )
    )

    list_of_frames_to_folder(texture_frames, movies_dir / "texture_frames")

    text = cv2.merge((channels_text["B"], channels_text["G"], channels_text["R"]))

    cv2.imwrite(
        str(img_dir_path / f"{img_path.stem}_restaurada_textura.jpg"), text * 255.0
    )

    cv2.imshow("Structure", struct)
    cv2.imshow("Texture", text)
    text = text - 0.5
    restaurada = struct + text
    cv2.imshow("Restaurada", restaurada)

    cv2.imwrite(
        str(img_dir_path / f"{img_path.stem}_restaurada.jpg"), restaurada * 255.0
    )

    esc = False
    while not esc:
        if cv2.waitKey(1) == 27:
            cv2.destroyAllWindows()
            esc = True

    return img


example_img = img_dir_path / "barbara.jpg"
inpaint(example_img)
