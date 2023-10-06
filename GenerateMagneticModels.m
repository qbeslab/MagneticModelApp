% Required add-ons (use MATLAB's Add-On Explorer to install):
%   - Aerospace Toolbox
%   - getContourLineCoordinates (from MathWorks File Exchange)
% Optional add-ons (use MATLAB's Add-On Explorer to install):
%   - Parallel Computing Toolbox (install for potential speed gains)

overwrite_files = false;

sample_resolution = 1;

years = 1900:2025;

n = length(years);
w = waitbar(0, ['Generating magnetic models for ', num2str(n), ' dates...']);

for i = 1:n
    year = years(i);
    datestr = [num2str(year), '-01-01'];
    filename = ['magmodels/magmodel-IGRF-res-' num2str(sample_resolution), '-year-', num2str(year), '.mat'];
    clear magmodel;
    if overwrite_files || ~exist(filename, "file")
        magmodel = MagneticModel(sample_resolution, datestr, "IGRF");
        save(filename, "magmodel");
    end
    disp(['Completed ', num2str(year)]);
    waitbar(i/n, w);
end
delete(w);
