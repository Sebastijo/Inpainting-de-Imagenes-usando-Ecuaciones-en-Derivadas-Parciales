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
main_dir = Path(__file__).resolve().parent.parent.parent
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

# Incluir los archivos de inpainting estructural de Julia
Main.include(str(inpainting_structure_path))

# Importamos los modulos de inpainting de Julia
structure = Main.inpainting_structure


def ST_decomposition(
    img: np.ndarray, K: float = 0.04, dt: float = 1 / 45, max_iters: int = 2000
) -> tuple[np.ndarray, np.ndarray]:
    """
    Función que realiza la descomposición de una imagen en estructura y textura.
    Se basa en la obtención de la estructura mediante difusión Perona-Malik.

    Args:
        img (np.ndarray): Imagen a descomponer.
        max_iters (int, optional): Número de iteraciones. Defaults to 300.
        dt (float, optional): Paso de tiempo. Defaults to 1/20.

    Returns:
        tuple[np.ndarray, np.ndarray]: Retorna la imagen de estructura y textura.

    Asserts:
        isinstance(img, np.ndarray): Se asegura que la imagen sea un np.ndarray.
        img.ndim == 3: Se asegura que la imagen sea a color.
        max_iters >= 0: Se asegura que el número de iteraciones sea mayor o igual a 0.
        dt > 0: Se asegura que el paso de tiempo sea mayor a 0.
    """
    assert isinstance(img, np.ndarray), "La imagen debe ser un np.ndarray."
    assert img.ndim == 3, "La imagen debe ser a color."
    assert max_iters >= 0, "El número de iteraciones debe ser mayor o igual a 0."
    assert dt > 0, "El paso de tiempo debe ser mayor a 0."

    b_channel, g_channel, r_channel = cv2.split(img)
    channels = {"R": r_channel, "G": g_channel, "B": b_channel}

    structure_result = {"R": None, "G": None, "B": None}
    texture_result = {"R": None, "G": None, "B": None}
    for channel in channels:
        f = channels[channel] / 255.0
        u = f.copy()
        for n in tqdm(range(max_iters), desc=f"Decomposing {channel} channel"):
            u = structure.anisotropic_iteration(u, K=K, dt=dt)
        structure_result[channel] = u
        texture_result[channel] = f - u

    Estructura = cv2.merge(
        [structure_result["B"], structure_result["G"], structure_result["R"]]
    )
    Textura = cv2.merge([texture_result["B"], texture_result["G"], texture_result["R"]])

    return Estructura, Textura


if __name__ == "__main__":

    # Test image
    img_path = img_dir_path / "New_lena.jpg"
    img = cv2.imread(img_path)

    # Realizamos la descomposición de la imagen
    u, v = ST_decomposition(img)

    cv2.imwrite(str(restored_dir_path / "New_lena_estructura.jpg"), u * 255.0)
    cv2.imwrite(str(restored_dir_path / "New_lena_textura.jpg"), (v + 0.5) * 255.0)

    # Mostramos la imagen resultante
    cv2.imshow("Structure", u)
    cv2.imshow("Texture", v + 0.5)

    cv2.waitKey(0)
    cv2.destroyAllWindows()
