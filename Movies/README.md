# **Instrucciones Para la Animación del Proceso**

El proceso comienza con una imagen dañada: `barbara_danhada.png`. El video debería comenzar con esta imágen.
Luego, esta imágen se descompone en *estructura* y *textura*. Los frames de este proceso se encuentran en las ccarpetas
`anisotropic_frames`, para la obtención de la estructura, y `anisotropic_reminder_frames`, para la obtención de la textura.

Luego, se restaura la estructura y la textura por separado. Los frames de reconstrucción de estructura se encuentran en 
`structural_frames` y los frames de las reconstrucción de textura se encuentran en la carpeta `texture_frames`.

Finalmente, el resultado de ambas restauraciones (el último frame de las carpetas `structural_frames` y `texture_frames`)
se junta en una sola imagen; `barbara_restaurada.jpg`.

La imagen original, de ser necesaria, se encuentra en el archivo `barbara.jpg`.
