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
        sample_gradients struct
        sample_orthogonality (:,:) double
        contour_levels struct
        contour_tables struct
    end

    methods
        function obj = MagneticModel(sample_resolution)
            %MAGNETICMODEL Construct an instance of this class

            obj.model_func = @wrldmagm; obj.version = "2020";  % faster, lesser temporal scope
            % obj.model_func = @igrfmagm; obj.version = "13";  % slower, greater temporal scope
            obj.decimal_year = decyear("2020-01-01");
            obj.height = 0;  % altitude in meters

            if nargin == 1
                obj.sample_resolution = sample_resolution;
            else
                % default value
                % obj.sample_resolution = 8;  % very coarse
                % obj.sample_resolution = 4;  % coarse
                % obj.sample_resolution = 2;  % medium
                obj.sample_resolution = 1;  % fine
                % obj.sample_resolution = 0.5;  % very fine
                % obj.sample_resolution = 0.25;  % ultra fine
            end

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

            s = nan(2, length(obj.sample_latitudes), length(obj.sample_longitudes));
            obj.sample_gradients = struct( ...
                I_INCL = s, ...
                F_TOTAL = s);

            obj.sample_orthogonality = nan(length(obj.sample_latitudes), length(obj.sample_longitudes));

            obj.contour_levels = struct( ...
                I_INCL = -90:5:90, ... degrees
                F_TOTAL = 0:1:70 ... microtesla
                );
            obj.contour_tables = struct( ...
                I_INCL=table, ...
                F_TOTAL=table);

            obj.PopulateSamples();
            obj.ComputeContours();
            obj.ComputeGradients();
            obj.ComputeOrthogonality();
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

        function [dFdx, dFdy, dIdx, dIdy] = EstimateGradients(obj, lat, lon, ddeg)
            %ESTIMATEGRADIENTS Estimate the intensity and inclination graditents at a location

            if nargin == 3
                ddeg = 1e-3;
            end

            % sample at location
            [~, ~, ~, ~, ~, I1, F1] = obj.EvaluateModel(lat, lon);

            % sample at a greater longitude (+x, east)
            [~, ~, ~, ~, ~, I2, F2] = obj.EvaluateModel(lat, lon + ddeg);
            dFdx = (F2 - F1) / ddeg;
            dIdx = (I2 - I1) / ddeg;

            % sample at a greater latitude (+y, north)
            [~, ~, ~, ~, ~, I2, F2] = obj.EvaluateModel(lat + ddeg, lon);
            dFdy = (F2 - F1) / ddeg;
            dIdy = (I2 - I1) / ddeg;
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

        function ComputeGradients(obj)
            %COMPUTEGRADIENTS Compute magnetic field property gradients
            for i = 1:length(obj.sample_latitudes)
                for j = 1:length(obj.sample_longitudes)
                    [dFdx, dFdy, dIdx, dIdy] = obj.EstimateGradients(obj.sample_latitudes(i), obj.sample_longitudes(j));
                    obj.sample_gradients.F_TOTAL(:, i, j) = [dFdx, dFdy];
                    obj.sample_gradients.I_INCL(:, i, j) = [dIdx, dIdy];
                end
            end
        end

        function ComputeOrthogonality(obj)
            %COMPUTEORTHOGONALITY Compute the angle in degrees between gradient vectors for inclination and intensity
            for i = 1:length(obj.sample_latitudes)
                for j = 1:length(obj.sample_longitudes)
                    dI = obj.sample_gradients.I_INCL(:, i, j);
                    dF = obj.sample_gradients.F_TOTAL(:, i, j);
                    angle = acosd(dot(dI, dF)/(norm(dI) * norm(dF)));
                    if angle > 90
                        % result will be between 0 and 90 degrees
                        angle = 180 - angle;
                    end
                    obj.sample_orthogonality(i, j) = angle;
                end
            end
        end
    end
end
