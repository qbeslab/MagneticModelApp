classdef MagneticModel < handle
    %MAGNETICMODEL Class for storing magnetic model samples
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Aerospace Toolbox
    %   - getContourLineCoordinates (from MathWorks File Exchange)

    properties
        model_func
        version
        decimal_year
        height
        latitudes
        longitudes
        param_idxs
        param_names
        samples
        contour_levels
        contour_names
        contour_tables
    end

    methods
        function obj = MagneticModel()
            %MAGNETICMODEL Construct an instance of this class

            obj.model_func = @wrldmagm; obj.version = "2020";  % faster, lesser temporal scope
            % obj.model_func = @igrfmagm; obj.version = 13;  % slower, greater temporal scope
            obj.decimal_year = decyear("2020-01-01");
            obj.height = 0;  % altitude in meters
            obj.latitudes = -89.5:0.5:89.5;
            obj.longitudes = -180:1:180;

            obj.param_idxs = struct(X_NORTH=1, Y_EAST=2, Z_DOWN=3, H_HORIZ=4, D_DECL=5, I_INCL=6, F_TOTAL=7);
            % obj.param_idxs = struct(I_INCL=1, F_TOTAL=2);
            obj.param_names = fieldnames(obj.param_idxs);

            obj.contour_levels = struct( ...
                I_INCL = -90:10:90, ... degrees
                F_TOTAL = 0:2000:70000 ... nanotesla
                );
            obj.contour_names = fieldnames(obj.contour_levels);

            obj.PopulateSamples();
            obj.ComputeContours();
        end

        function [XYZ, H, D, I, F] = EvaluateModel(obj, lat, lon)
            %EVALUATEMODEL Evaluate the magnetic field at given coords
            %   Outputs in nanotesla and degrees
            [XYZ, H, D, I, F] = obj.model_func(obj.height, lat, lon, obj.decimal_year, obj.version);
        end

        function PopulateSamples(obj)
            %POPULATESAMPLES Collect samples of magnetic field properties at all coords
            for i = length(obj.latitudes):-1:1
                for j = length(obj.longitudes):-1:1
                    [XYZ, H, D, I, F] = obj.EvaluateModel(obj.latitudes(i), obj.longitudes(j));
                    results = [reshape(XYZ, 1, 3), H, D, I, F];
                    % results = [I, F];
                    for k = 1:length(obj.param_names)
                        param = obj.param_names{k};
                        obj.samples.(param)(i, j) = results(k);
                    end
                end
            end
        end

        function ComputeContours(obj)
            %COMPUTECONTOURS Compute magnetic field property contours
            for i = 1:length(obj.contour_names)
                param = obj.contour_names{i};
                contour_matrix = contourc(obj.longitudes, obj.latitudes, obj.samples.(param), obj.contour_levels.(param)); 
                obj.contour_tables.(param) = getContourLineCoordinates(contour_matrix);
            end
        end
    end
end
