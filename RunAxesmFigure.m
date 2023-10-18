% Required add-ons (use MATLAB's Add-On Explorer to install):
%   - Aerospace Toolbox
%   - Mapping Toolbox
%   - getContourLineCoordinates (from MathWorks File Exchange)
% Optional add-ons (use MATLAB's Add-On Explorer to install):
%   - Parallel Computing Toolbox (install for potential speed gains)

close all;
clear;

load_from_file = true;
if load_from_file && exist("magmodel.mat", "file")
    load("magmodel.mat");
else
    % sample_resolution = 8;  % very coarse
    % sample_resolution = 4;  % coarse
    % sample_resolution = 2;  % medium
    sample_resolution = 1;  % fine
    % sample_resolution = 0.5;  % very fine
    % sample_resolution = 0.25;  % ultra fine
    magmodel = MagneticModel(sample_resolution);
    save("magmodel.mat", "magmodel");
end

verbose = 'on';
agent = Agent(magmodel, verbose);

projection = "globe";
% projection = "robinson";
% projection = "mercator";
g = Axesm3DMagneticMap(magmodel, agent, Projection=projection);
