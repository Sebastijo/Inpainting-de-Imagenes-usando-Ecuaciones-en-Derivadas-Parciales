# Inpainting de Imágenes

![Ecce Homo/Mono](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/cbc0347c-de99-46e5-bbfb-18ba5ad2d922)


## Nuestro Objetivo

Nuestro objetivo es crear un proyecto que permita realizar inpainting de imagenes con herramientas de Análisis Numérico de Ecuaciones en Derivadas Parciales. El inpainting consiste en reconstruir partes 
faltantes de imagenes a partir de la información sí disponible de la imagen. Nuestro approach será dividir la imagen en dos imágenes, una conteniendo la textura y otra conteniendo la estructura, y luego
completar las imagenes por separado. Para completar las imagenes, en el caso de la estructura, se modela como un problema de Dirichlet en la parte faltante de la imagen, para la textura, se aplica un de
síntesis de texturas. Para la separación se utiliza minimización de variación total, el cual queda caracterizado mediante una EDP.

## Lo Que Hemos Implementado

Hasta ahora, hemos implementado un proceso que realiza inpainting de estructura, un proceso que realiza inpainting de textura (solamente imágenes en blanco y negro) y un proceso que separa las imágenes
en textura-estructura. Además se implementó una interfaz de usuario que permite seleccionar fácilmente el área para realizar el inpainting.

## Cómo Funciona

En adelante, una función de imagen será una función que toma valores en un rectángulo de $\mathbb{R}^2$ y entrega valores en $[0, 1]$. En una imagen en blanco y negro, esto se puede interpretar como una asignación de luz donde 0 es negro y 1 es blanco.
Una imagen RGB sería entonces un objeto de la forma $(u_R, u_G, u_B)$ donde cada $u_i$ es una función de imagen. Todos los procesos se realizan en cada uno de estos canales RGB de manera independiente.

### Descomposición Textura-Estructura

Se toma como punto de partida el modelo propuesto por [3]: Asumiendo una imagen $f \in L^2(\mathbb{R}^2)$ (se refleja una imagen infinitas veces para teselar el plano), se quiere descomponer tal que $f = u + v$,
donde $u$ capture la estructura y $v$ la textura (y el ruido) con $u \in \text{BV}(\mathbb{R}^2)$. Para esto se resuelve

$$
\inf_u \left( E(u) = \int |\nabla u| + \lambda \|v\|_*, f = u + v \right)
$$

donde $\|\bullet\|_*$ es el ínfimo de todas las normas $L^\infty$ de las funciones $|g|$ donde $g = g_1 \times g_2$ y $|g(x,y)| = \sqrt{g_1(x,y)^2 + g_2(x,y)^2}$ que cumplen $v = \partial_x g_1 + \partial_y g_2$ con $g_1, g_2 \in L^\infty(\mathbb{R}^2)$.
(se demuestra además que \(v\) siempre se puede descomponer de la manera recién mencionada).

Con el objetivo de resolver este problema variacional, [4] propone la siguiente aproximación:

$$
\inf_{u, g_1, g_2} \left( G_p(u, g_1, g_2) = \int |\nabla u| + \lambda \int |f - u - \partial_x g_1 - \partial_y g_2|  dx dy + \mu \left[ \int \left( \sqrt{g_1^2 + g_2^2} \right)^p \, dx \, dy \right]^{1/p} \right),
$$

con $\lambda, \mu > 0$ son parámetros y $p \to \infty$ (en un sentido formal).

Minimizando de manera formal la energía recién mencionada, se obtienen las siguientes ecuaciones de Euler-Lagrange

$$
\begin{align*} u &= f - \partial_x g_1 - \partial_y g_2 + \frac{1}{2\lambda} \text{div}\left( \frac{\nabla u}{|\nabla u|} \right),\\
\mu (\|\sqrt{g_1^2 + g_2^2}\|)^{1-p} (\sqrt{g_1^2 + g_2^2})^{p-2} g_1 &= 2\lambda \left( \partial_x (u - f) + \partial_{xx} g_1 + \partial_{xy} g_2 \right),\\
\mu (\|\sqrt{g_1^2 + g_2^2}\|)^{1-p} (\sqrt{g_1^2 + g_2^2})^{p-2} g_2 &= 2\lambda \left( \partial_y (u - f) + \partial_{xy} g_1 + \partial_{yy} g_2 \right). \end{align*}
$$

donde $\sqrt{g_1^2 + g_2^2}$ en la segunda y tercera ecuación están dentro de la norma $p$.


En el caso de dominio finito, se asocian las siguientes condiciones de borde

$$
\begin{align*}
\frac{\nabla u}{|\nabla u|} &= 0,\\
(f-u-\partial_x g_1 - \partial_y g_2)n_x &= 0,\\
(f - u - \partial_x g_1 - \partial_y g_2)n_y &= 0.
\end{align*}
$$

la descomposición final es entonces

$$
f \approx u + \underbrace{\partial_x g_1 + \partial_y g_2}_{v}.
$$

#### Resultado de Descomposición Textura-Estructura

Como es estandard en procesamiento de imágenes, utilizamos la imagen Barbara como imagen test ($f$):

![barbara_original](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/f25d2374-51c1-4f63-aa0e-c5ce28416ee5)

La textura de la imagen obtenida es ($v + \text{mean}(f)$, se translada para poder visualizar):

![Barbara_texture](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/749d7051-ba83-4bdf-a869-2aeb866567eb)

y la estructura es ($u$):

![Barbara_structure](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/427cff3b-40b9-4f87-8096-78ef8bdf4a2f)

La suma de la estructura y la textura (que tienen el objetivo de recuperar la imagen original) es $(u + v)$

![Barbara_mixed](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/c42b5882-421a-44c2-80bf-26e3420a34c1)

#### Comentario Sobre Los Resultados
Se alcanza un resultado similar a los presentes en [4] aun que los resultados serían mejores si $v$ capturace más textura. Hay
detalles que se pierden en el proceso. Elegir mejor los parámetros es necesario. Más pruebas son necesarias con imágenes a color.

### Inpainting de estructura

Primero, con el objetivo de reducir el ruido de la imagen, se realiza un pre-procesamiento de la imagen resolviendo la ecuación de difusión anisotrópica [1]

$$\frac{\partial I}{\partial t} = \text{div}\left( g\left(\|\nabla I\|\right) \nabla I \right),$$

donde $I$ es la función de imagen, $\nabla$ y $\text{div}$ son el gradiente y la divergencia respectivamente, y $g$ es una función (suficientemente regular) de conductividad que debe ser no-negativa, monótona decreciente que cumple $g(0) = 1$.
En nuestro caso, usamos la función $g(x) = \text{exp}\left(-\frac{x^2}{K^2}\right)$, donde $K$ es la constante de difusión. El objetivo de esto es suavizar la imagen en las partes donde el gradiente es cercano a $0$, preservando así la forma de la figura.

Luego se realiza el inpainting estructural, que se realiza mediante la solución de la ecuación [2]

$$ \frac{\partial I}{\partial t} = \nabla (\Delta I) \cdot (\nabla I)^{\perp}, $$

donde $\Omega$ es la zona por restaurar, $I$ es la función de imagen, $\nabla$ y $\nabla^\perp$ son el gradiente y el gradiente rotado en 90 grados respectivamente, y $\Delta$ es el Laplaciano.
El objetivo es arrastrar la información de los bordes siguiendo la dirección en la que el gradiente es pequeño (perpendicular al gradiente) para así seguir las curvas y preservar la estructura.

Ambas ecuaciones son solucionadas con diferencias finitas, esto permite, en el paso de inpainting, mezclar iteraciones de inpainting con iteraciones de difusión para así eliminar ruido y suavizar los resultados del inpainting (esto muestra una mejora
considerable al proceso). Las iteraciones estándar que utilizamos son de 2 iteraciones de difusión anisotrópica por cada 15 de inpainting estructural.

#### Resultados

Acá un ejemplo de lo que se logró con 10000 iteraciones de inpainting estructural (mezclado con difusión anisotrópica en proporción 2:15) y 3000 iteraciones de difusión anisotrópica como pre-procesamiento.
Esto se realizó para cada uno de los 3 canales de RGB con lo que la cantidad de iteraciones se triplica. El proceso total tomó alrededor de 10 minutos en un Lenovo IdeaPad3 16GB RAM, Ryzen 7, implementando las partes de alto costo computacional en Julia.
(Usé mi foto de perfil de Microsoft porque estoy en un PC nuevo y es la única que tenía, los resultados fueron buenos así que voy a usarla como ejemplo. Más adelante esta imagen será remplazada).

La imagen original que utilizamos es:

![Imagen Original](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/5986a3b1-9174-4a59-bf9e-a01dc39bde56)

La imagen dañada (con el $\Omega$) es:

![Imagen Dañada](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/a3362bd4-203a-4ca7-bb04-ae5494d76495)

su restauración mediante inpainting es:

![Imagen Restaurada](https://github.com/Sebastijo/Analisis-Numerico-de-EDPs/assets/144045099/0fe12bf2-5ca9-49ff-bc7d-96e34901b50f)

#### Comentario Sobre Los Resultados

Los resultados fueron relativamente buenos, con el problema de que la foto se suavizó demasiado. El proceso de inpainting que estamos realizando es local (solo modifica la imagen donde está dañada),
con lo que el problema es la difusión anisotrópica. Es necesario ajustar los parámetros para evitar este tipo de resultados. Intentaremos modificar los parámetros de manera dinámica como es sugerido en [1].

Una vez realizado esto, continuaremos con el inpainting de textura. El objetivo final es descomponer la imagen en estructura y textura para aplicar los procesos por separado.

### Inpainting Texturado

[...]

## Próximos Pasos
La siguiente consituye una lista de las cosas que queremos mejorar/implementar.
1. Probar la descomposición con imágenes a color.
2. Mejorar la difusión anisotrópica utilizada en el inpainting de textura.
3. Ajustar los parámetros de la descomposición.
4. Mejorar lso parámetros del inpainting con textura.
5. Generalizar el inpainting con textura para poder manejar imágens a color.
6. Juntar todos los pasos en un solo programa, el objetivo final.

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
