# MagneticModelApp

This repository holds code that performs simulations and generates figures published in

> Gill, J. P., & Taylor, B. K. (2024). Navigation by Magnetic Signatures in a Realistic Model of Earth's Magnetic Field. Bioinspiration & Biomimetics.

For the version of the code used at time of publication, see the [Gill-and-Taylor-2024-Bioinspir-Biomim](https://github.com/qbeslab/MagneticModelApp/tree/Gill-and-Taylor-2024-Bioinspir-Biomim) branch of the repository.

## Requirements

Requires MATLAB R2021a or later.

Required add-ons (use MATLAB's Add-On Explorer to install):
- Aerospace Toolbox
- Mapping Toolbox
- getContourLineCoordinates (from MathWorks File Exchange)

Optional add-ons (use MATLAB's Add-On Explorer to install):
- MATLAB Basemap Data - colorterrain (install for offline use)
- Parallel Computing Toolbox (install for potential speed gains)

Example scripts:
- RunAxesmFigure
- RunMagneticModelApp

## Instructions

To generate the publication figures, run the MATLAB live script named "Figures.mlx".

To run the simulation interactively, run the MATLAB script named "[RunAxesmFigure.m](RunAxesmFigure.m)".

The agent is controlled by directly setting its parameter matrix, e.g., `agent.A = [1, 0; 0, 1]`, and with these commands:
- `agent.SetStart`, without arguments (an interactive targeting reticule will appear), or with arguments `lat, lon` specifying the precise start location
- `agent.SetGoal`, without arguments (an interactive targeting reticule will appear), or with arguments `lat, lon` specifying the precise goal location
- `agent.Step`, without arguments (one step will be taken), or with argument `n` specifying the number of steps
- `agent.Reset`, which clears the trajectory and resets the agent to the start
- `agent.Run`, which performs a reset and takes steps until a terminating condition is reached

Try these commands to see their effects on the map:
- `g.SetLevelCurves(level_curves_type)`, where `level_curves_type` is one of
    - `"contours"`
    - `"none"`
    - `"nullclines"`
    - `"parallelgradients"`
- `g.SetSurfaceMesh(surface_mesh_type)`, where `surface_mesh_type` is one of
    - `"orthogonality"`
    - `"stability"`
    - `"terrain"`
    - `"topography"`
- `g.SetVectorField(vector_field_type)`, where `vector_field_type` is one of
    - `"flow"`
    - `"gradients"`
    - `"none"`
