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
from src.python.Structure_Texture_decomposition import ST_decomposition

# Incluir los archivos de inpainting estructural de Julia
Main.include(str(inpainting_structure_path))
Main.include(str(inpainting_texture_path))
# Importamos los modulos de inpainting de Julia
structure = Main.inpainting_structure
texture = Main.inpainting_texture


def inpaint(img_path: Path) -> np.array:
    """
    Función que realiza el inpainting de una imagen.
    Entrega un np.array con la imagen restaurada y, además,
    guarda la imagen en la carpeta Images>restored.
    Permite seleccionar el área a restaurar dinámicamente.

    Args:
        img_path (Path): Ruta de la imagen a restaurar.

    Returns:
        np.array: Imagen restaurada.

    """
    # Crear la máscara de la imagen
    img, mask = mask_image(img_path)

    cv2.imwrite(str(img_dir_path / f"{img_path.stem}_danada.jpg"), img)

    K = 0.06
    difussion = K
    dt_ani = 1 / 45
    struct, text = ST_decomposition(img, K=K, dt=dt_ani, max_iters=3500)
    text = text + 0.5

    cv2.imwrite(str(img_dir_path / f"{img_path.stem}_danada_estructura.jpg"), struct * 255.0)
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
    # Inpainting de cada canal
    for color in channels_struct:
        print()
        print(f"Realizando inpainting de estructura para el color {color}")
        channels_struct[color] = structure.structural_inpainting(
            channels_struct[color],
            mask,
            max_iters=30000,
            anisotropic_iters=1,
            dt=0.545,
            dilatacion=1,
            difussion=K,
            dt_ani=dt_ani,
        )

    struct = cv2.merge(
        (channels_struct["B"], channels_struct["G"], channels_struct["R"])
    )

    cv2.imwrite(str(img_dir_path / f"{img_path.stem}_restaurada_estructura.jpg"), struct * 255.0)

    # Separamos la imágen en sus canales RGB
    b_channel_text, g_channel_text, r_channel_text = cv2.split(text)
    channels_text = {"R": r_channel_text, "G": g_channel_text, "B": b_channel_text}

    print()
    print(f"Realizando inpainting de textura")
    channels_text["R"], channels_text["G"], channels_text["B"] = (
        texture.texture_inpainting(
            channels_text["R"],
            channels_text["G"],
            channels_text["B"],
            mask,
            block_size0=8,
        )
    )

    text = cv2.merge((channels_text["B"], channels_text["G"], channels_text["R"]))

    cv2.imwrite(str(img_dir_path / f"{img_path.stem}_restaurada_textura.jpg"), text * 255.0)

    cv2.imshow("Structure", struct)
    cv2.imshow("Texture", text)
    text = text - 0.5
    restaurada = struct + text
    cv2.imshow("Restaurada", restaurada)

    cv2.imwrite(str(img_dir_path / f"{img_path.stem}_restaurada.jpg"), restaurada * 255.0)

    esc = False
    while not esc:
        if cv2.waitKey(1) == 27:
            cv2.destroyAllWindows()
            esc = True

    return img


example_img = img_dir_path / "barbara.jpg"
inpaint(example_img)
