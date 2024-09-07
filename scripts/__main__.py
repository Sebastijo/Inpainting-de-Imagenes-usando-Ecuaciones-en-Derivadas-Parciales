"""
Created on Tue Jun 12 00:23:00 2024
El objetivo de este script es el de ralizar el inpainting de una imagen mediante métodos de EDPN.
Este proyecto consituye el proyecto final del ramo Análisis Numérico de Ecuaciones en Derivadas Parciales
de la escuela de Ingeniería de la Universidad de Chile.
"""

import cv2  # Trabajar con imágenes
import numpy as np  # numpy
# import julia  # Para importar funciones de Julia
from julia import Main  # Para importar funciones de Julia
from pathlib import Path  # Para trabajar con rutas de archivos

try:  # Importamos la librería para crear barras de carga
    from tqdm import tqdm

    tqdm_is_available = True
except:
    tqdm_is_available = False
print("tqdm disponible:", tqdm_is_available)


# Definimos paths importantes:
# Carpeta principal del directorio
main_dir = Path(__file__).resolve().parent
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

# Incluir los archivos de inpainting estructural de Julia
Main.include(str(inpainting_structure_path))
Main.include(str(inpainting_texture_path))
# Importamos los modulos de inpainting de Julia
structure = Main.inpainting_structure
texture = Main.inpainting_texture


def inpaint(img_path: Path, method: str = "structure") -> np.array:
    """
    Función que realiza el inpainting de una imagen.
    Entrega un np.array con la imagen restaurada y, además,
    guarda la imagen en la carpeta Images>restored.
    Permite seleccionar el área a restaurar dinámicamente.

    Args:
        img_path (Path): Ruta de la imagen a restaurar.
        method (str, optional): Método de inpainting a realizar. Puede ser "structure" o "texture". Defaults to "structure".

    Returns:
        np.array: Imagen restaurada.

    """
    # Crear la máscara de la imagen
    img, mask = mask_image(img_path)

    # Transformamos el mask en formato blanco y negro
    mask = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY) / 255.0

    # Separamos la imágen en sus canales RGB
    b_channel, g_channel, r_channel = cv2.split(img)
    channels = {"R": r_channel, "G": g_channel, "B": b_channel}

    # Inpainting de textura requiere los canales simultaneamente
    if method == "texture":
        channels_tuple = texture.texture_inpainting(
                r_channel/1.0, g_channel/1.0, b_channel/1.0, mask
                )
        channels["R"] = channels_tuple[0]
        channels["G"] = channels_tuple[1]
        channels["B"] = channels_tuple[2]
    # Inpainting de estructura los puede trabajar por separado
    else:
        for color in tqdm(channels):
            channels[color] = channels[color] / 255.0
            channels[color] = structure.structural_inpainting(
                channels[color],
                mask,
                dt=0.8,
                max_iters=10000,
                difussion=0.007,
            )

    img = cv2.merge((channels["B"], channels["G"], channels["R"]))

    global restored_dir_path
    if method == "structure":
        restored_dir_path = restored_dir_path / "Structure"
    else:
        restored_dir_path = restored_dir_path / "Texture"

    restored_path = restored_dir_path / f"{img_path.stem}_restored.jpg"
    cv2.imwrite(restored_path, img)

    return img


example_img = img_dir_path / "lizard.jpg"
inpaint(example_img, "texture")
