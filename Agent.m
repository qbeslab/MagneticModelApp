classdef Agent < handle
    %AGENT Class for implementing a navigating agent
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox

    properties
        magmodel MagneticModel
        start_lat double
        start_lon double
        goal_lat double
        goal_lon double
        trajectory_lat (:,1) double
        trajectory_lon (:,1) double
        start_I_INCL double
        start_F_TOTAL double
        goal_I_INCL double
        goal_F_TOTAL double
        current_I_INCL double
        current_F_TOTAL double
        A (2,2) double = [1, 0; 0, 1]  % TODO scale properly
        speed double = 1/10  % TODO scale properly
    end
    
    events
        StartChanged
        GoalChanged
        TrajectoryChanged
        NavigationChanged
    end
    
    methods
        function obj = Agent(magmodel)
            %AGENT Construct an instance of this class

            obj.magmodel = magmodel;
            % obj.SetStart(41.5015, -81.6072);  % Cleveland
            obj.SetStart(-5.2367, -35.4049);  % Brazil coast
            obj.SetGoal(-7.923, -14.407);  % Ascension Island
            % obj.SetGoal(9, -80);  % Panama

            % % spiral source
            % obj.SetStart(15, -45);
            % obj.SetGoal(16.25, -56.68);

            obj.Reset();
        end

        function SetStart(obj, lat, lon)
            %SETSTART Set the starting position of the agent
            obj.start_lat = lat;
            obj.start_lon = lon;

            [~, ~, ~, ~, ~, I, F] = obj.magmodel.EvaluateModel(obj.start_lat, obj.start_lon);
            obj.start_I_INCL = I;
            obj.start_F_TOTAL = F;

            disp('=== START SET ===')
            disp(['Latitude: ', char(string(obj.start_lat)), '  Longitude: ', char(string(obj.start_lon))]);
            disp(['Inclination: ', char(string(round(obj.start_I_INCL, 2))), '°  Intensity: ', char(string(round(obj.start_F_TOTAL, 2))), ' μT']);

            notify(obj, "StartChanged");
        end

        function SetGoal(obj, lat, lon)
            %SETGOAL Set the goal position for the agent
            obj.goal_lat = lat;
            obj.goal_lon = lon;

            [~, ~, ~, ~, ~, I, F] = obj.magmodel.EvaluateModel(obj.goal_lat, obj.goal_lon);
            obj.goal_I_INCL = I;
            obj.goal_F_TOTAL = F;

            disp('=== GOAL SET ===')
            disp(['Latitude: ', char(string(obj.goal_lat)), '  Longitude: ', char(string(obj.goal_lon))]);
            disp(['Inclination: ', char(string(round(obj.goal_I_INCL, 2))), '°  Intensity: ', char(string(round(obj.goal_F_TOTAL, 2))), ' μT']);

            notify(obj, "GoalChanged");
        end

        function set.A(obj, A)
            %SET.A Set the matrix used for navigation
            obj.A = A;
            notify(obj, "NavigationChanged");
        end

        function Reset(obj)
            %RESET Reset trajectory to initial conditions
            obj.trajectory_lat = obj.start_lat;
            obj.trajectory_lon = obj.start_lon;
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
                perceived_dir = obj.ComputeDirection();
                % disp(['perceived_dir: ', obj.ApproxDirectionString(perceived_dir), ' [', char(string(perceived_dir(1))), ', ', char(string(perceived_dir(2))), ']']);
    
                new_lon = obj.trajectory_lon(end) + perceived_dir(1) * obj.speed;
                new_lat = obj.trajectory_lat(end) + perceived_dir(2) * obj.speed;

                if abs(new_lat) > 90
                    disp("aborting: crossed polar singularity");
                    break
                end
    
                obj.trajectory_lat = [obj.trajectory_lat; new_lat];
                obj.trajectory_lon = [obj.trajectory_lon; new_lon];
                % [obj.trajectory_lat, obj.trajectory_lon] = interpm(obj.trajectory_lat, obj.trajectory_lon, 1, 'gc');
    
                [~, ~, ~, ~, ~, I, F] = obj.magmodel.EvaluateModel(new_lat, new_lon);
                obj.current_I_INCL = I;
                obj.current_F_TOTAL = F;
            end

            notify(obj, "TrajectoryChanged");
        end

        function perceived_dir = ComputeDirection(obj, goal_I_INCL, goal_F_TOTAL, current_I_INCL, current_F_TOTAL)
            %COMPUTEDIRECTION Calculate the perceived direction of the goal
            if nargin == 1
                goal_I_INCL = obj.goal_I_INCL;
                goal_F_TOTAL = obj.goal_F_TOTAL;
                current_I_INCL = obj.current_I_INCL;
                current_F_TOTAL = obj.current_F_TOTAL;
            end
            perceived_dir = obj.A * [goal_F_TOTAL-current_F_TOTAL; ...
                                     goal_I_INCL-current_I_INCL];
            perceived_dir = perceived_dir/norm(perceived_dir);  % TODO scale properly
        end

        function dir_string = ApproxDirectionString(~, perceived_dir)
            %APPROXDIRECTIONSTRING Convert a perceived direction vector to an approximate string representation
            angle = atan2d(perceived_dir(1), perceived_dir(2));
            angle = round(angle/22.5)*22.5;
            switch angle
                case 0
                    dir_string = 'E';
                case 22.5
                    dir_string = 'ENE';
                case 45
                    dir_string = 'NE';
                case 67.5
                    dir_string = 'NNE';
                case 90
                    dir_string = 'N';
                case 112.5
                    dir_string = 'NNW';
                case 135
                    dir_string = 'NW';
                case 157.5
                    dir_string = 'WNW';
                case 180
                    dir_string = 'W';
                case -180
                    dir_string = 'W';
                case -157.5
                    dir_string = 'WSW';
                case -135
                    dir_string = 'SW';
                case -112.5
                    dir_string = 'SSW';
                case -90
                    dir_string = 'S';
                case -67.5
                    dir_string = 'SSE';
                case -45
                    dir_string = 'SE';
                case -22.5
                    dir_string = 'ESE';
            end
        end
    end
end
