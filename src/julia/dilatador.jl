"""
El siguiente código fue realizado en su totalidad con ChatGPT 3.5 mediante el promt:
-----------------
In Julia, create a function that, given a BitMatrix, it returns the dialated BitMatrix,
that is, every True values bleeds it's truth to it's neighbours in all directions (including corners). Example

0 0 0 0
0 0 1 0
0 0 0 0
0 0 0 0

->

0 1 1 1
0 1 1 1
0 1 1 1
0 0 0 0

using Images dilate function is cheating, obvioulsy. Don't use the Images library
-----------------
esta función rsulta equivalente a la función dialate de la librería Images, por su dificil compatibilidad
con PyJulia, evitamos usarla por completo en los paquetes no testers (cf. src>julia>julia testers).
"""

module dilatador

export dilate_bitmatrix

"""
    dilate_bitmatrix(matrix::BitMatrix)

Dilate a binary matrix by setting each cell to true if it's true or any neighbor is true.
The neighbors are the 8 cells around the current cell (top, bottom, left, right, top-left, top-right, bottom-left, bottom-right).

# Arguments
- `matrix::BitMatrix`: The binary matrix to dilate.

# Returns
- `BitMatrix`: The dilated binary matrix.

"""
function dilate_bitmatrix(matrix::BitMatrix)
    nrows, ncols = size(matrix)
    dilated_matrix = falses(nrows, ncols)
    
    for i in 1:nrows
        for j in 1:ncols
            # Set current cell to true if it's true or any neighbor is true
            if matrix[i, j] || 
                (i > 1 && matrix[i-1, j]) ||            # Top
                (i < nrows && matrix[i+1, j]) ||        # Bottom
                (j > 1 && matrix[i, j-1]) ||            # Left
                (j < ncols && matrix[i, j+1]) ||        # Right
                (i > 1 && j > 1 && matrix[i-1, j-1]) || # Top Left
                (i > 1 && j < ncols && matrix[i-1, j+1]) ||  # Top Right
                (i < nrows && j > 1 && matrix[i+1, j-1]) ||  # Bottom Left
                (i < nrows && j < ncols && matrix[i+1, j+1])   # Bottom Right
                dilated_matrix[i, j] = true
            end
        end
    end
    
    return dilated_matrix
end
end