% Required add-ons (use MATLAB's Add-On Explorer to install):
%   - Aerospace Toolbox
%   - Mapping Toolbox
%   - getContourLineCoordinates (from MathWorks File Exchange)

close all;
clear;

magmodel = MagneticModel();
agent = Agent(magmodel);
magmap = MagneticMap(magmodel, agent);
