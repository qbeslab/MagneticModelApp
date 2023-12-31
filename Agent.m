classdef Agent < handle
    %AGENT Class for implementing a navigating agent
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - Parallel Computing Toolbox (install for potential speed gains)

    properties
        magmodel MagneticModel
        verbose matlab.lang.OnOffSwitchState
        start_lat double
        start_lon double
        goal_lat double
        goal_lon double
        trajectory_lat (:,1) double
        trajectory_lon (:,1) double
        start_D_DECL double
        start_I_INCL double
        start_F_TOTAL double
        goal_D_DECL double
        goal_I_INCL double
        goal_F_TOTAL double
        current_D_DECL double
        current_I_INCL double
        current_F_TOTAL double
        A (2,2) double = [1, 0; 0, 1]  % TODO scale properly
        use_magnetic_north matlab.lang.OnOffSwitchState = 'off'
        max_speed double = 1/10  % TODO scale properly
        time_step double = 1
        sample_velocities (:,:,:) double
    end
    
    events
        StartChanged
        GoalChanged
        TrajectoryChanged
        NavigationChanged
        VelocitiesChanged
    end
    
    methods
        function obj = Agent(magmodel, verbose)
            %AGENT Construct an instance of this class

            obj.magmodel = magmodel;
            if nargin == 2
                obj.verbose = verbose;
            else
                obj.verbose = 'off';  % default
            end

            % obj.SetStart(41.5015, -81.6072);  % Cleveland
            obj.SetStart(-5.2367, -35.4049);  % Brazil coast
            obj.SetGoal(-7.923, -14.407);  % Ascension Island
            % obj.SetGoal(9, -80);  % Panama

            % % spiral source
            % obj.SetStart(15, -45);
            % obj.SetGoal(16.25, -56.68);

            obj.Reset();

            obj.ComputeVelocities();
            % addlistener(obj, "NavigationChanged", @obj.ComputeVelocities);
            % addlistener(obj, "GoalChanged", @obj.ComputeVelocities);
        end

        function SetStart(obj, lat, lon)
            %SETSTART Set the starting position of the agent

            if nargin < 2
                % capture [lat, lon] with a mouse click
                % - only works for axesm-based 2D maps in non-app figures
                [lat, lon] = inputm(1);
            elseif nargin < 3 && length(lat) == 2
                % assume [lat, lon] were passed as an array
                lon = lat(2);
                lat = lat(1);
            end

            obj.start_lat = lat;
            obj.start_lon = lon;

            [~, ~, ~, ~, D, I, F] = obj.magmodel.EvaluateModel(obj.start_lat, obj.start_lon);
            obj.start_D_DECL = D;
            obj.start_I_INCL = I;
            obj.start_F_TOTAL = F;

            if obj.verbose
                disp('=== START SET ===')
                disp(['Latitude: ', char(string(obj.start_lat)), '  Longitude: ', char(string(obj.start_lon))]);
                disp(['Inclination: ', char(string(round(obj.start_I_INCL, 2))), '°  Intensity: ', char(string(round(obj.start_F_TOTAL, 2))), ' μT']);
            end

            notify(obj, "StartChanged");
        end

        function SetGoal(obj, lat, lon)
            %SETGOAL Set the goal position for the agent

            if nargin < 2
                % capture [lat, lon] with a mouse click
                % - only works for axesm-based 2D maps in non-app figures
                [lat, lon] = inputm(1);
            elseif nargin < 3 && length(lat) == 2
                % assume [lat, lon] were passed as an array
                lon = lat(2);
                lat = lat(1);
            end

            obj.goal_lat = lat;
            obj.goal_lon = lon;

            [~, ~, ~, ~, D, I, F] = obj.magmodel.EvaluateModel(obj.goal_lat, obj.goal_lon);
            obj.goal_D_DECL = D;
            obj.goal_I_INCL = I;
            obj.goal_F_TOTAL = F;

            if obj.verbose
                [dFdx, dFdy, dIdx, dIdy] = obj.magmodel.EstimateGradients(obj.goal_lat, obj.goal_lon);
                ev = obj.ComputeEigenvalues([dFdx, dFdy], [dIdx, dIdy], D);
                disp('=== GOAL SET ===')
                disp(['Latitude: ', char(string(obj.goal_lat)), '  Longitude: ', char(string(obj.goal_lon))]);
                disp(['Inclination: ', char(string(round(obj.goal_I_INCL, 2))), '°  Intensity: ', char(string(round(obj.goal_F_TOTAL, 2))), ' μT']);
                disp(['Eigenvalues (with current A and use_magnetic_north setting): ', num2str(ev(1)), ', ', num2str(ev(2))]);
            end

            notify(obj, "GoalChanged");
        end

        function set.A(obj, A)
            %SET.A Set the matrix used for navigation
            obj.A = A;
            notify(obj, "NavigationChanged");
        end

        function set.use_magnetic_north(obj, use_magnetic_north)
            %SET.USE_MAGNETIC_NORTH Set the use_magnetic_north flag, which
            % controls whether headings are calculated relative to true
            % north or magnetic north.
            obj.use_magnetic_north = use_magnetic_north;
            notify(obj, "NavigationChanged");
        end

        function Reset(obj)
            %RESET Reset trajectory to initial conditions
            obj.trajectory_lat = obj.start_lat;
            obj.trajectory_lon = obj.start_lon;
            obj.current_D_DECL = obj.start_D_DECL;
            obj.current_I_INCL = obj.start_I_INCL;
            obj.current_F_TOTAL = obj.start_F_TOTAL;

            notify(obj, "TrajectoryChanged");
        end

        function Step(obj, n)
            %STEP Take n steps (default 1) and append points to the trajectory

            if nargin < 2
                n = 1;
            end

            for i = 1:n
                velocity = obj.ComputeVelocity();
                % disp(['velocity: ', obj.ApproxBearingString(obj.Bearing(velocity)), ' [', char(string(velocity(1))), ', ', char(string(velocity(2))), ']']);
    
                new_lon = obj.trajectory_lon(end) + velocity(1) * obj.time_step;
                new_lat = obj.trajectory_lat(end) + velocity(2) * obj.time_step;

                if abs(new_lat) > 90
                    disp("aborting: crossed polar singularity");
                    break
                end
    
                obj.trajectory_lat = [obj.trajectory_lat; new_lat];
                obj.trajectory_lon = [obj.trajectory_lon; new_lon];
                % [obj.trajectory_lat, obj.trajectory_lon] = interpm(obj.trajectory_lat, obj.trajectory_lon, 1, 'gc');
    
                [~, ~, ~, ~, D, I, F] = obj.magmodel.EvaluateModel(new_lat, new_lon);
                obj.current_D_DECL = D;
                obj.current_I_INCL = I;
                obj.current_F_TOTAL = F;
            end

            notify(obj, "TrajectoryChanged");
        end

        function Run(obj, max_steps)
            %STEP Reset and step until an equilibrium or max steps is reached

            if nargin < 2
                % simulation will stop if this many steps are taken
                max_steps = 10000;
            end

            obj.Reset();

            % simulation will stop if the velocity drops below this value
            velocity_threshold = obj.max_speed / 100;

            steps_taken = 0;
            while true
                if steps_taken >= max_steps
                    % disp("terminating: max steps reached");
                    break
                end

                velocity = obj.ComputeVelocity();
                % disp(['velocity: ', obj.ApproxBearingString(obj.Bearing(velocity)), ' [', char(string(velocity(1))), ', ', char(string(velocity(2))), ']']);
                if norm(velocity) < velocity_threshold
                    % disp(['terminating: velocity dropped below threshold after ', num2str(steps_taken), '/', num2str(max_steps), ' steps (equilibrium possibly reached)']);
                    break
                end
    
                new_lon = obj.trajectory_lon(end) + velocity(1) * obj.time_step;
                new_lat = obj.trajectory_lat(end) + velocity(2) * obj.time_step;

                if abs(new_lat) > 90
                    disp("aborting: crossed polar singularity");
                    break
                end
    
                obj.trajectory_lat = [obj.trajectory_lat; new_lat];
                obj.trajectory_lon = [obj.trajectory_lon; new_lon];
                % [obj.trajectory_lat, obj.trajectory_lon] = interpm(obj.trajectory_lat, obj.trajectory_lon, 1, 'gc');
    
                [~, ~, ~, ~, D, I, F] = obj.magmodel.EvaluateModel(new_lat, new_lon);
                obj.current_D_DECL = D;
                obj.current_I_INCL = I;
                obj.current_F_TOTAL = F;

                steps_taken = steps_taken + 1;
            end

            notify(obj, "TrajectoryChanged");
        end

        function velocity = ComputeVelocity(obj, goal_I_INCL, goal_F_TOTAL, current_I_INCL, current_F_TOTAL, current_D_DECL)
            %COMPUTEVELOCITY Calculate the agent's velocity
            if nargin == 1
                goal_I_INCL = obj.goal_I_INCL;
                goal_F_TOTAL = obj.goal_F_TOTAL;
                current_I_INCL = obj.current_I_INCL;
                current_F_TOTAL = obj.current_F_TOTAL;
                current_D_DECL = obj.current_D_DECL;
            end
            if ~obj.use_magnetic_north
                rotation_matrix = [1, 0;
                                   0, 1];
            else
                % TODO: See WMM2020 Technical Report on grid variation/
                % grivation for corrections near the poles
                rotation_matrix = [cosd(-current_D_DECL), -sind(-current_D_DECL);
                                   sind(-current_D_DECL),  cosd(-current_D_DECL)];
            end
            velocity = rotation_matrix * obj.A * [goal_F_TOTAL-current_F_TOTAL;
                                                  goal_I_INCL-current_I_INCL];
            if norm(velocity) > obj.max_speed
                % limit the agent's speed to a maximum value
                velocity = obj.max_speed * velocity/norm(velocity);
            end
        end

        function ev = ComputeEigenvalues(obj, dF, dI, D)
            %COMPUTEEIGENVALUES Compute the eigenvalues of the linearized velocity in a location with the given magnetic field property gradients.

            dFdx = dF(1);
            dFdy = dF(2);
            dIdx = dI(1);
            dIdy = dI(2);

            % % find eigenvalues numerically
            % % - when eigenvalues should be exactly zero, error accumulated
            % %   with the numerical approach can sometimes result in
            % %   non-zero values, especially when agent.A is large, which is
            % %   problematic for stability classification
            % if ~obj.use_magnetic_north
            %     jacobian = -obj.A * [dFdx, dFdy; dIdx, dIdy];
            % else
            %     rotation_matrix = [cosd(-D), -sind(-D);
            %                        sind(-D),  cosd(-D)];
            %     jacobian = -rotation_matrix * obj.A * [dFdx, dFdy; dIdx, dIdy];
            % end
            % ev = eig(jacobian);

            % find eigenvalues formulaically, with matrix multiplication
            % - this approach seems to reliably compute eigenvalues that
            %   should be exactly zero (e.g., when detJ is zero)
            if ~obj.use_magnetic_north
                jacobian = -obj.A * [dFdx, dFdy; dIdx, dIdy];
            else
                rotation_matrix = [cosd(-D), -sind(-D);
                                   sind(-D),  cosd(-D)];
                jacobian = -rotation_matrix * obj.A * [dFdx, dFdy; dIdx, dIdy];
            end
            trJ = trace(jacobian);
            detJ = det(jacobian);
            ev = [(trJ - sqrt(trJ^2 - 4 * detJ)) / 2;
                  (trJ + sqrt(trJ^2 - 4 * detJ)) / 2];

            % % find eigenvalues formulaically, without matrix multiplication
            % % - this seems to be entirely equivalent to using the build-in
            % %   trace and det functions
            % a = obj.A(1, 1);
            % b = obj.A(1, 2);
            % c = obj.A(2, 1);
            % d = obj.A(2, 2);
            % if ~obj.use_magnetic_north
            %     trJ = -(a * dFdx + b * dIdx + c * dFdy + d * dIdy);
            %     detJ = (a * d - b * c) * (dFdx * dIdy - dFdy * dIdx);
            % else
            %     trJ = -((a*cosd(D) + c*sind(D)) * dFdx + ...
            %             (b*cosd(D) + d*sind(D)) * dIdx + ...
            %             (c*cosd(D) - a*sind(D)) * dFdy + ...
            %             (d*cosd(D) - b*sind(D)) * dIdy);
            %     detJ = (cosd(D)^2 + sind(D)^2) * (a * d - b * c) * (dFdx * dIdy - dFdy * dIdx);
            % end
            % ev = [(trJ - sqrt(trJ^2 - 4 * detJ)) / 2;
            %       (trJ + sqrt(trJ^2 - 4 * detJ)) / 2];

            % %------------------------------------------------------------
            % % compare numerically and formulaically computed eigenvalues
            % % - when eigenvalues should be exactly zero, error accumulated
            % %   with the numerical approach can sometimes result in
            % %   non-zero values, especially when agent.A is large, which is
            % %   problematic for stability classification
            % jacobian = -obj.A * [dFdx, dFdy; dIdx, dIdy];
            % ev1 = eig(jacobian);
            % a = obj.A(1, 1);
            % b = obj.A(1, 2);
            % c = obj.A(2, 1);
            % d = obj.A(2, 2);
            % trJ = -(a * dFdx + b * dIdx + c * dFdy + d * dIdy);
            % detJ = (a * d - b * c) * (dFdx * dIdy - dFdy * dIdx);
            % ev2 = [(trJ - sqrt(trJ^2 - 4 * detJ)) / 2;
            %        (trJ + sqrt(trJ^2 - 4 * detJ)) / 2];
            % format long;
            % if norm(sort(ev1) - sort(ev2)) > 1e-15
            %     disp("significant deviation found:");
            %     disp([sort(ev1), sort(ev2)]);
            %     disp(norm(sort(ev1) - sort(ev2)));
            % end
            % %------------------------------------------------------------
        end

        function ComputeVelocities(obj, ~, ~)
            %COMPUTEVELOCITIES Calculate what the agent's velocity would be at all sample locations

            goal_I = obj.goal_I_INCL;
            goal_F = obj.goal_F_TOTAL;

            lat = obj.magmodel.sample_latitudes;
            lon = obj.magmodel.sample_longitudes;

            D_DECL = obj.magmodel.samples.D_DECL;
            I_INCL = obj.magmodel.samples.I_INCL;
            F_TOTAL = obj.magmodel.samples.F_TOTAL;
            f = @obj.ComputeVelocity;

            velocities = nan(2, length(lat), length(lon));

            % sample velocities globally
            imax = length(lat);
            jmax = length(lon);
            parfor i = 1:imax
                for j = 1:jmax
                    D = D_DECL(i, j);
                    I = I_INCL(i, j);
                    F = F_TOTAL(i, j);
                    velocities(:, i, j) = f(goal_I, goal_F, I, F, D);
                end
            end

            obj.sample_velocities = velocities;
            notify(obj, "VelocitiesChanged");
        end

        function bearing = Bearing(~, velocity)
            %BEARING Convert a velocity vector to an angle measured in degrees clockwise from north
            bearing = mod(90 - atan2d(velocity(2), velocity(1)), 360);
        end

        function bearing_string = ApproxBearingString(~, bearing)
            %APPROXBEARINGSTRING Convert a bearing to an approximate string representation
            bearing = round(bearing/22.5)*22.5;
            switch bearing
                case 0
                    bearing_string = 'N';
                case 22.5
                    bearing_string = 'NNE';
                case 45
                    bearing_string = 'NE';
                case 67.5
                    bearing_string = 'ENE';
                case 90
                    bearing_string = 'E';
                case 112.5
                    bearing_string = 'ESE';
                case 135
                    bearing_string = 'SE';
                case 157.5
                    bearing_string = 'SSE';
                case 180
                    bearing_string = 'S';
                case 202.5
                    bearing_string = 'SSW';
                case 225
                    bearing_string = 'SW';
                case 247.5
                    bearing_string = 'WSW';
                case 270
                    bearing_string = 'W';
                case 292.5
                    bearing_string = 'WNW';
                case 315
                    bearing_string = 'NW';
                case 337.5
                    bearing_string = 'NNW';
                case 360
                    bearing_string = 'N';
            end
        end
    end
end
