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
    img: np.ndarray,
    K: float = 0.04,
    dt: float = 1 / 45,
    max_iters: int = 2000,
    anim_duration: float = 10.0,
) -> tuple[np.ndarray, np.ndarray, list[np.ndarray]]:
    """
    Función que realiza la descomposición de una imagen en estructura y textura.
    Se basa en la obtención de la estructura mediante difusión Perona-Malik.

    Args:
        img (np.ndarray): Imagen a descomponer.
        K (float, optional): Coeficiente de difusión. Defaults to 0.04.
        dt (float, optional): Paso de tiempo. Defaults to 1/45.
        max_iters (int, optional): Número de iteraciones. Defaults to 300.
        anim_duration (float, optional): Duración de la animación. Defaults to 10.0.


    Returns:
        np.ndarray: Estructura de la imagen.
        np.ndarray: Textura de la imagen.
        list[np.ndarray]: Lista de frames de la animación.


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

    anisotropic_frames_np: dict[str, list[np.ndarray]] = {
        color: [channels[color]] for color in channels
    }

    storing_ratio = max_iters // (anim_duration * 24)
    for channel in channels:
        f = channels[channel] / 255.0
        u = f.copy()
        for n in tqdm(range(max_iters), desc=f"Decomposing {channel} channel"):
            u = structure.anisotropic_iteration(u, K=K, dt=dt)

            if n % storing_ratio == 0:
                anisotropic_frames_np[channel].append(u.copy())

        structure_result[channel] = u
        texture_result[channel] = f - u

    Frames = [
        cv2.merge(
            [
                anisotropic_frames_np["B"][i],
                anisotropic_frames_np["G"][i],
                anisotropic_frames_np["R"][i],
            ]
        )
        for i in range(len(anisotropic_frames_np["R"]))
    ]

    Estructura = cv2.merge(
        [structure_result["B"], structure_result["G"], structure_result["R"]]
    )
    Textura = cv2.merge([texture_result["B"], texture_result["G"], texture_result["R"]])

    return Estructura, Textura, Frames


if __name__ == "__main__":

    # Test image
    img_path = img_dir_path / "New_lena.jpg"
    img = cv2.imread(img_path)

    # Realizamos la descomposición de la imagen
    u, v, frames = ST_decomposition(img)

    cv2.imwrite(str(restored_dir_path / "New_lena_estructura.jpg"), u * 255.0)
    cv2.imwrite(str(restored_dir_path / "New_lena_textura.jpg"), (v + 0.5) * 255.0)

    # Mostramos la imagen resultante
    cv2.imshow("Structure", u)
    cv2.imshow("Texture", v + 0.5)

    cv2.waitKey(0)
    cv2.destroyAllWindows()
