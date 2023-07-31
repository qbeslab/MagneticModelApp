% Required add-ons (use MATLAB's Add-On Explorer to install):
%   - Aerospace Toolbox
%   - Mapping Toolbox
%   - getContourLineCoordinates (from MathWorks File Exchange)
% Optional add-ons (use MATLAB's Add-On Explorer to install):
%   - MATLAB Basemap Data - colorterrain (install for offline use)

close all;
clear;

magmodel = MagneticModel();
agent = Agent(magmodel);
magmap = MagneticMap(magmodel, agent);
