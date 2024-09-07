# Inpainting de Imágenes

![Ecce Homo/Mono](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/cbc0347c-de99-46e5-bbfb-18ba5ad2d922)


## Nuestro Objetivo

Nuestro objetivo es crear un proyecto que permita realizar inpainting de imagenes con herramientas de Análisis Numérico de Ecuaciones en Derivadas Parciales. El inpainting consiste en reconstruir partes 
faltantes de imagenes a partir de la información sí disponible de la imagen. Nuestro *approach* será dividir la imagen en dos imágenes, una conteniendo la textura y otra conteniendo la estructura, y luego
completar las imagenes por separado. Para completar las imagenes, en el caso de la estructura, se modela como un problema de Dirichlet en la parte faltante de la imagen, para la textura, se aplica un de
síntesis de texturas. Para la separación se utiliza difusión Perona-Malik (*a.k.a.* anisotrópica).

## Lo Que Hemos Implementado

Hemos logrado implementar un porgrama que recibe una imagen a color (RGB) y permite seleccionar la zona a restaurar. Separando la imagen en cada uno de sus canales RGB y cada uno de esto canales en textura y estructura, se logra restaurar cada una de las 6 imágenes resultantes para luego combinarlas en una sola imagen restaurada.

## Cómo Funciona

En adelante, una función de imagen será una función que toma valores en un rectángulo de $\mathbb{R}^2$ y entrega valores en $[0, 1]$. En una imagen en blanco y negro, esto se puede interpretar como una asignación de luz donde 0 es negro y 1 es blanco.
Una imagen RGB sería entonces un objeto de la forma $(u_R, u_G, u_B)$ donde cada $u_i$ es una función de imagen. Todos los procesos se realizan en cada uno de estos canales RGB de manera independiente.

### Difusión Anisotrópica (Perona-Malik)

Comenzamos presentando una herramienta fundamental para esta tarea: la difusión anisotrópica. Se quiere reducir el ruido de una imagen manteniendo sus bordes: suavizar la imagen sin alterar los bordes de las figuras contenidas en ella. Para esto, se propone la siguiente ecuación [1].

$$\frac{\partial I}{\partial t} = \text{div}\left( g\left(\|\nabla I\|\right) \nabla I \right),$$

donde $I$ es la función de imagen, $\nabla$ y $\text{div}$ son el gradiente y la divergencia respectivamente, y $g$ es una función (suficientemente regular) de conductividad que debe ser no-negativa, monótona decreciente que cumple $g(0) = 1$.
En nuestro caso, usamos la función $g(x) = \text{exp}\left(-\frac{x^2}{K^2}\right)$, donde $K$ es la constante de difusión. El objetivo de esto es suavizar la imagen en las partes donde el gradiente es cercano a $0$, preservando así la forma de la figura. La imagen suavizada será la solución de esta ecuación en *steady state*.

#### Resultado de Difusión Anisotrópica

El esquema numérico implementado es el presentado en [1].

Usamos la siguiente imagen como condición inicial.

![bungee_input](https://github.com/user-attachments/assets/61d28f5c-740e-419f-b22b-f9155642fc53)


Obteniendo el siguiente resultado para $K=0.05$

![bungee1](https://github.com/user-attachments/assets/da9a200a-d2cc-4821-8ae0-b4f8b2966786)


y el siguiente resultado para $K = 0.1$

![bungee2](https://github.com/user-attachments/assets/1bbe72e1-3c80-4d20-ab4a-a01d3b59d294)

#### Comentario Sobre Los Resultados
Los resultados son buenos. Se logra eliminar los detalles de la imagen y es posible cuantificar esto mediante un cambio en la constante $K$ de difusión. Es posbile alcanzar una imagen tipo *cartoon*.

### Separación Estructura-Textura

Para el método a implementar, es necesario separar la textura y la estructura. Para esto, utilizamos la difusión Perona-Malik para obtener una imagen *cartoon* (que corresponde a la estructura) y luego, restandole esta esta imagen a la imagen original, rescatamos la textura. Con esto se cumple la propiedad $f = u + v$ donde $f$ es la imagen original y $u$, $v$ la estructura y textura respectivamente.

#### Resultados de Separación Textura-Estructura

Utilizamos una versión más actualizada y más ética de Lenna como *input*.

![new_lenna](https://github.com/user-attachments/assets/ea25903a-2d53-4c53-8ebe-650fc38cd40f)

Realizando Perona-Malik con $300$ iteraciones (*cf.* [1]) y $K=0.8$, se obtiene la estructura y textura (respectivamente).

![amooth_lenna1](https://github.com/user-attachments/assets/59e1b4c9-bdf3-4efe-8a91-c489ded58804)
![noisy_lenna1](https://github.com/user-attachments/assets/9b17dcd7-33b0-4b7a-a1f7-a08f333bbf2d)

Realizando Perona-Malik con $3000$ iteraciones (*cf.* [1]) y $K=0.05$, se obtiene la estructura y textura (respectivamente).

![smooth_lenna2](https://github.com/user-attachments/assets/7534f134-a788-4a2c-88b0-dbe6214641bd)
![noisy_lenna2](https://github.com/user-attachments/assets/1af94a1f-3046-480c-8ab6-e07c548c6a6d)

### Inpainting de estructura

Primero, con el objetivo de reducir el ruido de la imagen, se realiza un pre-procesamiento de la imagen resolviendo la ecuación de difusión anisotrópica [1,2]

Luego se realiza el inpainting estructural, que se realiza mediante la solución de la ecuación [2]

$$ \frac{\partial I}{\partial t} = \nabla (\Delta I) \cdot (\nabla I)^{\perp}, $$

donde $\Omega$ es la zona por restaurar, $I$ es la función de imagen, $\nabla$ y $\nabla^\perp$ son el gradiente y el gradiente rotado en 90 grados respectivamente, y $\Delta$ es el Laplaciano.
El objetivo es arrastrar la información de los bordes siguiendo la dirección en la que el gradiente es pequeño (perpendicular al gradiente) para así seguir las curvas y preservar la estructura.

Ambas ecuaciones son solucionadas con diferencias finitas, esto permite, en el paso de inpainting, mezclar iteraciones de inpainting con iteraciones de difusión para así eliminar ruido y suavizar los resultados del inpainting (esto muestra una mejora
considerable al proceso). Las iteraciones estándar que utilizamos son de 2 iteraciones de difusión anisotrópica por cada 15 de inpainting estructural.

#### Resultados

Acá un ejemplo de lo que se logró con 10000 iteraciones de inpainting estructural (mezclado con difusión anisotrópica en proporción 2:15) y 3000 iteraciones de difusión anisotrópica como pre-procesamiento.
Esto se realizó para cada uno de los 3 canales de RGB con lo que la cantidad de iteraciones se triplica. El proceso total tomó alrededor de 10 minutos en un Lenovo IdeaPad3 16GB RAM, Ryzen 7, implementando las partes de alto costo computacional en Julia.

La imagen original que utilizamos es:

![Imagen Original](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/5986a3b1-9174-4a59-bf9e-a01dc39bde56)

La imagen dañada (con el $\Omega$) es:

![Imagen Dañada](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/a3362bd4-203a-4ca7-bb04-ae5494d76495)

su restauración mediante inpainting es:

![Imagen Restaurada](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/0fe12bf2-5ca9-49ff-bc7d-96e34901b50f)

#### Comentario Sobre Los Resultados

Los resultados fueron relativamente buenos, con el problema de que la foto se suavizó demasiado. El proceso de inpainting que estamos realizando es local (solo modifica la imagen donde está dañada),
con lo que el problema es la difusión anisotrópica; esto no es un problema una vez separemos la textura de la estructura antes de realizar el proceso.

### Inpainting Texturado

Esta es la únia herramienta del proyecto que no se basa en EDP. Se define una textura como un patron infinito en 2 dimensiones. Un ejemplo de patrón, es una mesa infinita cubierta completamente de manzanas, incluso la misma superficie de la mesa, por si sola, sería una textura. Para iniciar, planteamos la solución presentada en [5] para el problema de sintesis de textura. 

#### *Image Quilting*

El problema de síntesis de textura consiste en, a partir de una muestra de una textura (un parche de textura finito), lograr recontruir lo textura original. La solución propuesta en [5] tiene el nomrbe de *Image Quilting*.

El *Image Quilting* consiste en dividir la muestra inicial en bloques de $n\times n$ pixeles y elegir uno al azar como punto de partida. Luego, en orden *raster scan*, se van agregando nuevos bloques de la muestra inicial hasta generar tanta textura como se desea. Un nuevo bloque agregado, queda superpuesto con el bloque de su izquierda y con el de arriba en los bordes (a continuación se mencona porque). La forma de elegir los bloques de textura que se agregan y la forma de agregarlos, queda resumida a continuación:
1. Se recorre la muestra y se guardan todos los bloques de la muestra que tengan un error (más sobre esto adelante) bajo $\varepsilon$ en los bordes que se sobreponen con el bloque de la izquierda y el de arriba.
2. De los bloques guardados en el paso anterior, se elije uno al azar y se agrega tal que los bordes queden superpuestos con el bloque de la izquierda y con el de arriba.
3. Se genera un corte de error mínimo (más sobre esto a continuación) a lo largo de la intersección de los bloques.
La siguiente imagen sacada del paper original [5] resume este proceso (en la imagen (a) se muestra que pasa si simplemente elegimos bloques al azar, en la imagen (b), que pasa si elegimos los bloques como se muestra en el paso 1. y 2. de la lista anterior, en la imagen (c) se muestra el resultado de incorporar, además, el paso 3. de la lista anterior).

![image_quilting](https://github.com/user-attachments/assets/d9cb90f2-3a88-4a18-8f4b-243f0f85fe9e)

En el paso 2. de la lista anterior, el error de solapamiento (que tanto difieren los bloques en los bordes) se cuantifica mediante

#### Inpainting Texturado

El inpainting de texturas se logra mediante la aplicación de *Image Quilting* a las partes faltantes de la imagen, utilizando como muestra lo que sí está presente en la imagen.

## Contribuyendo

Si deseas contribuir a este proyecto, por favor sigue las siguientes instrucciones:

1. Haz un fork del repositorio.
2. Crea una nueva rama (`git checkout -b feature/AmazingFeature`).
3. Realiza tus cambios (`git commit -m 'Add some AmazingFeature'`).
4. Sube los cambios a tu rama (`git push origin feature/AmazingFeature`).
5. Abre un Pull Request.
    
## Licencia

Este proyecto está bajo la Licencia Apache 2.0. Para más detalles, consulta el archivo [LICENSE](LICENSE).

## Contacto

Sebastian P. Pincheira - [sebastian.pincheira@ug.uchile.cl](mailto:sebastian.pincheira@ug.uchile.cl)

Francisco Maldonado

## Referencias

1. P. Perona and J. Malik, *Scale-space and edge detection using anisotropic diffusion*. IEEE-PAMI 12, pp. 629-639, 1990.
2. M. Bertalmio, G. Sapiro, V. Caselles, and C. Ballester, “Image inpainting,” in *Comput. Graph. (SIGGRAPH 2000)*, July 2000, pp. 417–424.
3. Aubert, G., and Vese, L. (1997). A variational method in image recovery. SIAM J. Numer. Anal. 34(5), 1948–1979.
4. L. Vese and S. Osher, “Modeling Textures with Total Variation Minimization and Oscillating Patterns in Image Processing,”, vol. 02-19, UCLA CAM Rep., May 2002.
5. A. A. Efros and W. T. Freeman, "Image Quilting for Texture Synthesis and Transfer," in *Comput. Graph. (SIGGRAPH 2001)*, Aug. 2001, pp. 341–346.

