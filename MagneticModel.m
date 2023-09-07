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
        sample_resolution double
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

            % obj.sample_resolution = 8;  % very coarse
            % obj.sample_resolution = 4;  % coarse
            % obj.sample_resolution = 2;  % medium
            obj.sample_resolution = 1;  % fine
            % obj.sample_resolution = 0.5;  % very fine
            % obj.sample_resolution = 0.25;  % ultra fine

            obj.sample_latitudes = -90:obj.sample_resolution:90;
            obj.sample_longitudes = -180:obj.sample_resolution:180;

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
                F_TOTAL = 0:1:70 ... microtesla
                );
            obj.contour_tables = struct( ...
                I_INCL=table, ...
                F_TOTAL=table);

            obj.PopulateSamples();
            obj.ComputeContours();
        end

        function [X, Y, Z, H, D, I, F] = EvaluateModel(obj, lat, lon)
            %EVALUATEMODEL Evaluate the magnetic field at given coords
            %   Outputs in microtesla and degrees
            [XYZ, H, D, I, F] = obj.model_func(obj.height, lat, lon, obj.decimal_year, obj.version);
            X = XYZ(1);
            Y = XYZ(2);
            Z = XYZ(3);

            % convert intensities from nanotesla to microtesla
            X = X/1000;
            Y = Y/1000;
            Z = Z/1000;
            H = H/1000;
            F = F/1000;
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

        function [dFx, dFy, dIx, dIy] = EstimateGradients(obj, lat, lon, ddeg)
            %ESTIMATEGRADIENTS Estimate the intensity and inclination graditents at a location

            if nargin == 3
                ddeg = 1e-3;
            end

            % sample at location
            [~, ~, ~, ~, ~, I1, F1] = obj.EvaluateModel(lat, lon);

            % sample at a greater longitude (+x, east)
            [~, ~, ~, ~, ~, I2, F2] = obj.EvaluateModel(lat, lon + ddeg);
            dFx = (F2 - F1) / ddeg;
            dIx = (I2 - I1) / ddeg;

            % sample at a greater latitude (+y, north)
            [~, ~, ~, ~, ~, I2, F2] = obj.EvaluateModel(lat + ddeg, lon);
            dFy = (F2 - F1) / ddeg;
            dIy = (I2 - I1) / ddeg;
        end
    end
end
