% Required add-ons (use MATLAB's Add-On Explorer to install):
%   - Aerospace Toolbox
%   - Mapping Toolbox
%   - getContourLineCoordinates (from MathWorks File Exchange)
% Optional add-ons (use MATLAB's Add-On Explorer to install):
%   - MATLAB Basemap Data - colorterrain (install for offline use)

close all;
clear;

global magmodel agent;

load_from_file = true;
if load_from_file && exist("magmodel.mat", "file")
    load("magmodel.mat");
else
    magmodel = MagneticModel();
    save("magmodel.mat", "magmodel");
end

agent = Agent(magmodel);

Axesm2DMagneticMap;

app = MagneticMapApp(magmodel, agent);
