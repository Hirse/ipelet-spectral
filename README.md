# Spectral Drawing Ipelet
An extension to the [Ipe extensible drawing editor](http://ipe.otfried.org).

![Demo](demo.gif)


## Features
All functionality works on the current selection, treating lines that end at the same location as a node as connecting.
* Show Laplacian Matrix
* Show Degree Matrix
* Show Adjacency Matrix
* Spectral Drawing (see [Limitations](#Limitations))

## Installation
Copy the file `spectral.lua` into one of your Ipelet directories (see `Help -> Show configuration` in Ipe for the locations).

## Limitations
Spectral Drawing uses eigenvectors to provide coordinates for the vertices of a graph. At this point in time, there is no existing algorithm to calculate eigenvectors of a large, sparse, and symmetric matrix in Lua. Pending the implementation of, for example the [Jacobi algorithm](https://en.wikipedia.org/wiki/Jacobi_eigenvalue_algorithm), this Ipelet provides the matrix in MATLAB format and requires the manual input of the second and third eigenvector.
