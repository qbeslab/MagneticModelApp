classdef Agent < handle
    %AGENT Class for implementing a navigating agent
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox

    properties
        magmodel
        start_I_INCL
        start_F_TOTAL
        goal_I_INCL
        goal_F_TOTAL
        current_I_INCL
        current_F_TOTAL
    end
    
    properties (SetObservable)
        start_lat
        start_lon
        goal_lat
        goal_lon
        trajectory_lat
        trajectory_lon
    end
    
    methods
        function obj = Agent(magmodel)
            %AGENT Construct an instance of this class

            obj.magmodel = magmodel;
            % obj.SetStart(41.5015, -81.6072);  % Cleveland
            obj.SetStart(-5.2367, -35.4049);  % Brazil coast
            obj.SetGoal(-7.923, -14.407);  % Ascension Island
            obj.Reset();
        end

        function SetStart(obj, lat, lon)
            %SETSTART Set the starting position of the agent
            obj.start_lat = lat;
            obj.start_lon = lon;

            [~, ~, ~, I, F] = obj.magmodel.EvaluateModel(obj.start_lat, obj.start_lon);
            obj.start_I_INCL = I;
            obj.start_F_TOTAL = F;

            disp('=== START SET ===')
            disp(['Latitude: ', char(string(obj.start_lat)), '  Longitude: ', char(string(obj.start_lon))]);
            disp(['Inclination: ', char(string(round(obj.start_I_INCL, 2))), '°  Intensity: ', char(string(round(obj.start_F_TOTAL, 2))), ' nT']);
        end

        function SetGoal(obj, lat, lon)
            %SETGOAL Set the goal position for the agent
            obj.goal_lat = lat;
            obj.goal_lon = lon;

            [~, ~, ~, I, F] = obj.magmodel.EvaluateModel(obj.goal_lat, obj.goal_lon);
            obj.goal_I_INCL = I;
            obj.goal_F_TOTAL = F;

            disp('=== GOAL SET ===')
            disp(['Latitude: ', char(string(obj.goal_lat)), '  Longitude: ', char(string(obj.goal_lon))]);
            disp(['Inclination: ', char(string(round(obj.goal_I_INCL, 2))), '°  Intensity: ', char(string(round(obj.goal_F_TOTAL, 2))), ' nT']);
        end

        function Reset(obj)
            %RESET Reset trajectory to initial conditions
            obj.trajectory_lat = obj.start_lat;
            obj.trajectory_lon = obj.start_lon;
            obj.current_I_INCL = obj.start_I_INCL;
            obj.current_F_TOTAL = obj.start_F_TOTAL;
        end
        
        function Step(obj, n)
            %STEP Take n steps (default 1) and append points to the trajectory

            if nargin < 2
                n = 1;
            end

            for i = 1:n    
                perceived_dir = [(obj.goal_I_INCL-obj.current_I_INCL); ...
                                 (obj.goal_F_TOTAL-obj.current_F_TOTAL)/100];  % TODO scale properly
                % disp(['perceived_dir: [', char(string(perceived_dir(1))), ', ', char(string(perceived_dir(2))), ']']);
                perceived_dir = perceived_dir/norm(perceived_dir);  % TODO scale properly
    
                % new_lat = obj.trajectory_lat(end) - 1;
                % new_lon = obj.trajectory_lon(end) + 1;
                new_lat = obj.trajectory_lat(end) + perceived_dir(1)/10;  % TODO scale properly
                new_lon = obj.trajectory_lon(end) + perceived_dir(2)/10;  % TODO scale properly
    
                obj.trajectory_lat = [obj.trajectory_lat; new_lat];
                obj.trajectory_lon = [obj.trajectory_lon; new_lon];
                % [obj.trajectory_lat, obj.trajectory_lon] = interpm(obj.trajectory_lat, obj.trajectory_lon, 1, 'gc');
    
                [~, ~, ~, I, F] = obj.magmodel.EvaluateModel(new_lat, new_lon);
                obj.current_I_INCL = I;
                obj.current_F_TOTAL = F;
            end
        end
    end
end
