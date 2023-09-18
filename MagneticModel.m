classdef MagneticModel < handle
    %MAGNETICMODEL Class for storing magnetic model samples
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Aerospace Toolbox
    %   - getContourLineCoordinates (from MathWorks File Exchange)
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - Parallel Computing Toolbox (install for potential speed gains)

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

            obj.contour_levels = struct( ...
                I_INCL = -90:5:90, ... degrees
                F_TOTAL = 0:1:70 ... microtesla
                );

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
            %COLLECTSAMPLES Collect samples of magnetic field properties at all coords

            lat = obj.sample_latitudes;
            lon = obj.sample_longitudes;
            f = @obj.EvaluateModel;

            s = nan(length(lat), length(lon));
            % X_NORTH = s;
            % Y_EAST = s;
            % Z_DOWN = s;
            % H_HORIZ = s;
            % D_DECL = s;
            I_INCL = s;
            F_TOTAL = s;

            imax = length(lat);
            jmax = length(lon);
            parfor i = 1:imax
                for j = 1:jmax
                    % [X, Y, Z, H, D, I, F] = f(lat(i), lon(j));
                    [~, ~, ~, ~, ~, I, F] = f(lat(i), lon(j));
                    % X_NORTH(i, j) = X;
                    % Y_EAST (i, j) = Y;
                    % Z_DOWN (i, j) = Z;
                    % H_HORIZ(i, j) = H;
                    % D_DECL (i, j) = D;
                    I_INCL (i, j) = I;
                    F_TOTAL(i, j) = F;
                end
            end

            % obj.samples = struct( ...
            %     X_NORTH=X_NORTH, Y_EAST=Y_EAST, Z_DOWN=Z_DOWN, ...
            %     H_HORIZ=H_HORIZ, D_DECL=D_DECL, I_INCL=I_INCL, ...
            %     F_TOTAL=F_TOTAL);
            obj.samples = struct( ...
                I_INCL=I_INCL, ...
                F_TOTAL=F_TOTAL);
        end

        function ComputeContours(obj)
            %COMPUTECONTOURS Compute magnetic field property contours

            cont_tables = struct( ...
                I_INCL=table, ...
                F_TOTAL=table);

            contour_names = fieldnames(obj.contour_levels);
            for i = 1:length(contour_names)
                param = contour_names{i};
                contour_matrix = contourc(obj.sample_longitudes, obj.sample_latitudes, obj.samples.(param), obj.contour_levels.(param)); 
                cont_tables.(param) = getContourLineCoordinates(contour_matrix);
            end

            obj.contour_tables = cont_tables;
        end

        function ComputeGradients(obj)
            %COMPUTEGRADIENTS Compute magnetic field property gradients

            lat = obj.sample_latitudes;
            lon = obj.sample_longitudes;
            f = @obj.EstimateGradients;

            s = nan(2, length(lat), length(lon));
            dI_INCL = s;
            dF_TOTAL = s;

            imax = length(lat);
            jmax = length(lon);
            parfor i = 1:imax
                for j = 1:jmax
                    [dFdx, dFdy, dIdx, dIdy] = f(lat(i), lon(j));
                    dF_TOTAL(:, i, j) = [dFdx, dFdy];
                    dI_INCL(:, i, j) = [dIdx, dIdy];
                end
            end

            obj.sample_gradients = struct( ...
                I_INCL=dI_INCL, ...
                F_TOTAL=dF_TOTAL);
        end

        function ComputeOrthogonality(obj)
            %COMPUTEORTHOGONALITY Compute the angle in degrees between gradient vectors for inclination and intensity

            lat = obj.sample_latitudes;
            lon = obj.sample_longitudes;
            dI_INCL = obj.sample_gradients.I_INCL;
            dF_TOTAL = obj.sample_gradients.F_TOTAL;

            orthogonality = nan(length(lat), length(lon));

            imax = length(lat);
            jmax = length(lon);
            parfor i = 1:imax
                for j = 1:jmax
                    dI = dI_INCL(:, i, j);
                    dF = dF_TOTAL(:, i, j);
                    angle = acosd(dot(dI, dF)/(norm(dI) * norm(dF)));
                    if angle > 90
                        % result will be between 0 and 90 degrees
                        angle = 180 - angle;
                    end
                    orthogonality(i, j) = angle;
                end
            end

            obj.sample_orthogonality = orthogonality;
        end
    end
end
