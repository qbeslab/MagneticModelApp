classdef Agent < handle
    %AGENT Class for implementing a navigating agent
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox

    properties
        magmodel
    end
    
    properties (SetObservable)
        trajectory_lat
        trajectory_lon
    end
    
    methods
        function obj = Agent(magmodel)
            %AGENT Construct an instance of this class

            obj.magmodel = magmodel;
            obj.Reset();
        end

        function Reset(obj)
            %RESET Reset trajectory to initial conditions

            % obj.trajectory_lat = 0;
            % obj.trajectory_lon = 0;

            obj.trajectory_lat = [ 41.5015;  -7.923];
            obj.trajectory_lon = [-81.6072; -14.407];
            [obj.trajectory_lat, obj.trajectory_lon] = interpm(obj.trajectory_lat, obj.trajectory_lon, 1, 'gc');
        end
        
        function Step(obj)
            %STEP Take a step and append points to the trajectory
            
            new_lat = obj.trajectory_lat(end) + 1;
            new_lon = obj.trajectory_lon(end) + 1;
            obj.trajectory_lat = [obj.trajectory_lat; new_lat];
            obj.trajectory_lon = [obj.trajectory_lon; new_lon];
            % [obj.trajectory_lat, obj.trajectory_lon] = interpm(obj.trajectory_lat, obj.trajectory_lon, 1, 'gc');
        end
    end
end

