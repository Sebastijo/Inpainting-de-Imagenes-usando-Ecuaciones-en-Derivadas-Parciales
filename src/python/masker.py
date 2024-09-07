
"""
El siguiente código fue generado en su totalidad con ChatGPT-4o. El promt utilizado fue el siguiente:

----------------------------------------
I made the following question in stack overflow

https://stackoverflow.com/q/78559316/14554601

Titled

Selecting a part of an image in python by drawing on top of it [closed]

The question is about creating a mask by selecting drawing on top of an image using python.
The output should be a separate image with only the drawn part.
One of the comments states

for exactly this, there's a source code example in OpenCV's samples directory. just run it.
samples/python/inpaint.py -- the core of your question is how to make a GUI that lets you
paint with a brush. -- don't expect miracles. the two oldest inpainting algorithms in opencv
are dumb as bricks. I think there are a few "content-aware" ones in another module. 
browse/search the docs. you'll find them. 
- Christoph Rackwitz May 31 at 11:07 

I don't care about the inpainting part, I already coded that myself. I just want to select.
Help me out.
----------------------------------------

Unos pequeños cambios fueron realizados, estos serán señalados con comentarios 
(iniciados con [!!!] para distinguirlos de los comentarios originales de GPT).
"""

import cv2
import numpy as np
from pathlib import Path # [!!!] Mejor manejo de paths

# [!!!] Se agregaron los nombre de nuestras carpetas principales
main_dir = Path(__file__).resolve().parent.parent.parent
img_dir_path = main_dir / "Images"

# Initialize global variables
drawing = False  # True if the mouse is pressed
mode = True  # If True, draw. Press 'm' to toggle to erase.
ix, iy = -1, -1
mask = None
img = None

# Mouse callback function
def draw_circle(event, x, y, flags, param):
    global ix, iy, drawing, mode, mask, img

    if event == cv2.EVENT_LBUTTONDOWN:
        drawing = True
        ix, iy = x, y

    elif event == cv2.EVENT_MOUSEMOVE:
        if drawing:
            if mode:
                cv2.circle(mask, (x, y), 5, (255, 255, 255), -1)
                cv2.circle(img, (x, y), 5, (255, 255, 255), -1)
            else:
                cv2.circle(mask, (x, y), 5, (0, 0, 0), -1)
                cv2.circle(img, (x, y), 5, (0, 0, 0), -1)

    elif event == cv2.EVENT_LBUTTONUP:
        drawing = False
        if mode:
            cv2.circle(mask, (x, y), 5, (255, 255, 255), -1)
            cv2.circle(img, (x, y), 5, (255, 255, 255), -1)
        else:
            cv2.circle(mask, (x, y), 5, (0, 0, 0), -1)
            cv2.circle(img, (x, y), 5, (0, 0, 0), -1)

# [!!!] Lo siguiente simplemente se indentó y se convirtió en una función,
# originalmente el img_path era una constante.
def mask_image(img_path: Path) -> tuple[np.ndarray, np.ndarray]:
    """
    Función que permite seleccionar una parte de una imagen dibujando sobre ella.
    La mascara resultante se guarda en la carpeta masks de la carpeta Images.

    Args:
        img_path (Path): Ruta de la imagen a seleccionar.
    
    Returns:
        tuple[np.ndarray, np.ndarray]: Retorna la imagen original y la imagen con la máscara.
    
    Asserts:
        img_path.exists(): Se asegura que la imagen exista.
        img_path.is_file(): Se asegura que la ruta sea un archivo.
        img_path.suffix in [".jpg", ".jpeg", ".png"]: Se asegura que la imagen sea de un formato válido.
    """
    # [!!!] Se agregaron los asserts para asegurar que la imagen sea válida.
    assert img_path.exists(), f"Could not find image. Path: {img_path}"
    assert img_path.is_file(), f"Path is not a file. Path: {img_path}"
    assert img_path.suffix in [".jpg", ".jpeg", ".png"], f"Invalid file format. Path: {img_path}"

    # [!!!] Se establecen las variables globales necesarias para transformar e código en función.
    global mask, img, mode
    
    # Load the image
    img = cv2.imread(img_path)
    if img is None:
        raise Exception(f"Could not load image. Check the path to your image. Path: {img_path}")

    # Create a black mask of the same size as the image
    mask = np.zeros_like(img)

    # Create a window and bind the function to window
    cv2.namedWindow('image')
    cv2.setMouseCallback('image', draw_circle)

    while True:
        cv2.imshow('image', img)
        k = cv2.waitKey(1) & 0xFF
        if k == ord('m'):
            mode = not mode
        elif k == 27:  # Escape key to exit
            break

    cv2.destroyAllWindows()

    # Apply the mask to the image
    result = cv2.bitwise_and(img, mask)


    # Save or display the result
    cv2.imshow('masked_image', result)
    cv2.waitKey(0)
    cv2.destroyAllWindows()
    mask_path = img_dir_path / "masks" /f"{img_path.stem}_mask.jpg"
    cv2.imwrite(mask_path, result)
    
    return img, result # [!!!] se agregó el return de las imágenes 


# [!!!] Se agregó un if __name__ == "__main__": para poder probar el modulo
if __name__ == "__main__":
    img_path = img_dir_path / "Profile drawing.jpg"
    img, mask = mask_image(img_path)
    cv2.imshow("Original", img)
    cv2.imshow("Mask", mask)
    cv2.waitKey(0)
    cv2.destroyAllWindows()