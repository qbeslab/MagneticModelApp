classdef MagneticModel < handle
    %MAGNETICMODEL Class for storing magnetic model samples
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Aerospace Toolbox
    %   - getContourLineCoordinates (from MathWorks File Exchange)

    properties
        model_func function_handle
        version string
        decimal_year double
        height double
        sample_latitudes (:,1) double
        sample_longitudes (:,1) double
        samples struct
        contour_levels struct
        contour_tables struct
    end

    methods
        function obj = MagneticModel()
            %MAGNETICMODEL Construct an instance of this class

            obj.model_func = @wrldmagm; obj.version = "2020";  % faster, lesser temporal scope
            % obj.model_func = @igrfmagm; obj.version = "13";  % slower, greater temporal scope
            obj.decimal_year = decyear("2020-01-01");
            obj.height = 0;  % altitude in meters

            obj.sample_latitudes = -89.5:0.5:89.5;
            obj.sample_longitudes = -180:1:180;
            s = nan(length(obj.sample_latitudes), length(obj.sample_longitudes));
            % obj.samples = struct( ...
            %     X_NORTH=s, Y_EAST=s, Z_DOWN=s, ...
            %     H_HORIZ=s, D_DECL=s, I_INCL=s, ...
            %     F_TOTAL=s);
            obj.samples = struct( ...
                I_INCL=s, ...
                F_TOTAL=s);

            obj.contour_levels = struct( ...
                I_INCL = -90:5:90, ... degrees
                F_TOTAL = 0:1000:70000 ... nanotesla
                );
            obj.contour_tables = struct( ...
                I_INCL=table, ...
                F_TOTAL=table);

            obj.PopulateSamples();
            obj.ComputeContours();
        end

        function [X, Y, Z, H, D, I, F] = EvaluateModel(obj, lat, lon)
            %EVALUATEMODEL Evaluate the magnetic field at given coords
            %   Outputs in nanotesla and degrees
            [XYZ, H, D, I, F] = obj.model_func(obj.height, lat, lon, obj.decimal_year, obj.version);
            X = XYZ(1);
            Y = XYZ(2);
            Z = XYZ(3);
        end

        function PopulateSamples(obj)
            %POPULATESAMPLES Collect samples of magnetic field properties at all coords
            for i = 1:length(obj.sample_latitudes)
                for j = 1:length(obj.sample_longitudes)
                    % [X, Y, Z, H, D, I, F] = obj.EvaluateModel(obj.sample_latitudes(i), obj.sample_longitudes(j));
                    [~, ~, ~, ~, ~, I, F] = obj.EvaluateModel(obj.sample_latitudes(i), obj.sample_longitudes(j));
                    % obj.samples.X_NORTH(i, j) = X;
                    % obj.samples.Y_EAST (i, j) = Y;
                    % obj.samples.Z_DOWN (i, j) = Z;
                    % obj.samples.H_HORIZ(i, j) = H;
                    % obj.samples.D_DECL (i, j) = D;
                    obj.samples.I_INCL (i, j) = I;
                    obj.samples.F_TOTAL(i, j) = F;
                end
            end
        end

        function ComputeContours(obj)
            %COMPUTECONTOURS Compute magnetic field property contours
            contour_names = fieldnames(obj.contour_levels);
            for i = 1:length(contour_names)
                param = contour_names{i};
                contour_matrix = contourc(obj.sample_longitudes, obj.sample_latitudes, obj.samples.(param), obj.contour_levels.(param)); 
                obj.contour_tables.(param) = getContourLineCoordinates(contour_matrix);
            end
        end
    end
end
