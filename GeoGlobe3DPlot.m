classdef GeoGlobe3DPlot < handle
    %GEOGLOBE3DPLOT Class for managing a 3D GeographicGlobe plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    properties
        magmodel MagneticModel
        agent Agent
        ax globe.graphics.GeographicGlobe
        trajectory map.graphics.primitive.Line
        start map.graphics.primitive.Line
        goal map.graphics.primitive.Line
        position map.graphics.primitive.Line
    end
    
    methods
        function obj = GeoGlobe3DPlot(magmodel, agent, parent)
            %GEOGLOBE3DPLOT Construct an instance of this class
            if nargin == 2
                parent = uifigure;
            end
            obj.magmodel = magmodel;
            obj.ax = geoglobe(parent, Basemap="colorterrain", Terrain="none");  % Terrain="none" flattens terrain so it does not occlude contours and trajectories
            campos(obj.ax, 0, 0, 1e7);  % manually setting a camera position right away bypasses camera animation, speeding up initial plotting
            % obj.ax.Position = [0 0 1 1];
            hold(obj.ax);

            obj.AddContourPlots;
            obj.AddAgent(agent);
        end

        function AddContourPlots(obj)
            %ADDCONTOURPLOTS Add magnetic property contours to map

            % interpm_maxdiff = 0.1;  % degrees (or nan to skip contour interpolation)
            interpm_maxdiff = nan;  % degrees (or nan to skip contour interpolation)

            % add contours
            for param = ["I_INCL", "F_TOTAL"]
                contour_table = obj.magmodel.contour_tables.(param);
                nContours = max(contour_table.Group);

                % plot each contour level one at a time
                for i = 1:nContours
                    gidx = contour_table.Group == i;
                    level = unique(contour_table.Level(gidx));

                    % set line width
                    linewidth = 0.5;  % default
                    switch param
                        case "I_INCL"
                            if mod(level, 30) == 0
                                linewidth = 3;  % multiples of 30 degrees
                            else
                                if mod(level, 10) == 0
                                    linewidth = 2;  % multiples of 10 degrees
                                end
                            end
                        case "F_TOTAL"
                            if mod(level, 10000) == 0
                                linewidth = 2;  % multiples of 10000 nT
                            end
                    end

                    % set color
                    color = 'k';  % default
                    switch param
                        case "I_INCL"
                            % color = "#02B187";  % green from Taylor (2018)
                            color = "#EEEEEE";  % light gray
                            if level == 0
                                color = '#FF8080';  % light red, magnetic equator
                            end
                        case "F_TOTAL"
                            % color = "#8212B4";  % purple from Taylor (2018)
                            color = "#444444";  % dark gray
                    end

                    % get contour line coordinates
                    contour_lat = contour_table.Y(gidx);
                    contour_lon = contour_table.X(gidx);
                    if ~isnan(interpm_maxdiff)
                        % interpolate points on the contour line if necessary
                        [contour_lat, contour_lon] = interpm(contour_lat, contour_lon, interpm_maxdiff, 'gc');
                    end

                    % prepare data tooltips and other metadata
                    %   note: lines can be accessed later via tags, e.g., findobj(obj.ax, "Tag", "I_INCL = 0")
                    tag = [char(string(param)), ' = ', char(string(level))];
                    datatipvalues = level*ones(size(contour_lat));
                    % datatiplabel = param.replace('_', '\_');  % default
                    % datatipformat = 'auto';  % default
                    % switch param
                    %     case "I_INCL"
                    %         datatiplabel = "Inclination";
                    %         datatipformat = 'degrees';
                    %     case "F_TOTAL"
                    %         datatiplabel = "Intensity";
                    %         datatipformat = '%g nT';
                    % end

                    % plot contour line
                    %   note: 3D globe does not use data tooltips
                    geoplot3(obj.ax, ...
                        contour_lat, contour_lon, [], ...
                        '-', LineWidth=linewidth, Color=color, ...
                        Tag=tag, UserData=datatipvalues ...
                        );
                end
            end
        end

        function AddAgent(obj, agent)
            %ADDAGENT Add trajectory of an agent to maps

            obj.agent = agent;
            
            linewidth = 2;
            color = "magenta";
            
            % plot trajectory
            obj.trajectory = geoplot3(obj.ax, ...
                obj.agent.trajectory_lat, obj.agent.trajectory_lon, [], ...
                '-', LineWidth=linewidth, Color=color, Marker='none', MarkerSize=2);

            % plot markers for agent start, goal, and current position
            obj.start = geoplot3(obj.ax, obj.agent.start_lat, obj.agent.start_lon, [], 'bo', MarkerSize=8, LineWidth=2);
            obj.goal = geoplot3(obj.ax, obj.agent.goal_lat, obj.agent.goal_lon, [], 'go', MarkerSize=8, LineWidth=2);
            obj.position = geoplot3(obj.ax, obj.agent.trajectory_lat(end), obj.agent.trajectory_lon(end), [], 'mo', MarkerSize=8, LineWidth=2);

            % update plots when agent changes
            addlistener(obj.agent, 'StartChanged', @obj.UpdateAgentStart);
            addlistener(obj.agent, 'GoalChanged', @obj.UpdateAgentGoal);
            addlistener(obj.agent, 'TrajectoryChanged', @obj.UpdateAgentTrajectory);
        end

        function ToggleAgentTrajectoryMarkers(obj)
            %TOGGLEAGENTTRAJECTORYMARKERS Toggle the display of markers for every trajectory step
            if obj.trajectory.Marker == "none"
                obj.trajectory.Marker = 'o';
            else
                obj.trajectory.Marker = 'none';
            end

            drawnow;  % force figure to update immediately
        end

        function Lock3DCamera(obj)
            %LOCK3DCAMERA Prevent auto 3D camera adjustments when plot update
            %   If the camera is moved using the mouse, auto camera
            %   adjustments will resume, and this method should be run
            %   again to stop them.

            % % BUG this manual method does not really work as the docs say it should
            % campos(obj.ax, "manual");
            % camheading(obj.ax, "manual");
            % campitch(obj.ax, "manual");
            % camroll(obj.ax, "manual");

            % this works better
            [lat, lon, height] = campos(obj.ax);
            heading = camheading(obj.ax); 
            pitch = campitch(obj.ax);
            roll = camroll(obj.ax);
            campos(obj.ax, lat, lon, height);
            camheading(obj.ax, heading);
            campitch(obj.ax, pitch);
            camroll(obj.ax, roll);

            drawnow;  % force figure to update immediately

            disp("3D camera locked until manually adjusted");
        end

        function Center3DCameraOnAgent(obj, height)
            %CENTER3DCAMERAONAGENT Move the 3D camera to the latest agent position
            if nargin < 2
                height = 7e6;  % meters above reference ellipsoid
            end
            campos(obj.ax, obj.agent.trajectory_lat(end), wrapTo180(obj.agent.trajectory_lon(end)), height);
            camheading(obj.ax, 0);
            campitch(obj.ax, -90);
            camroll(obj.ax, 0);

            drawnow;  % force figure to update immediately
        end

        function SetAgentStartTo3DCamPos(obj)
            %SETAGENTSTARTTO3DCAMPOS Set the agent start position to the current 3D camera latitude and longitude
            obj.Lock3DCamera;
            [lat, lon, ~] = campos(obj.ax);
            obj.agent.SetStart(lat, lon);
        end

        function SetAgentGoalTo3DCamPos(obj)
            %SETAGENTGOALTO3DCAMPOS Set the agent goal to the current 3D camera latitude and longitude
            obj.Lock3DCamera;
            [lat, lon, ~] = campos(obj.ax);
            obj.agent.SetGoal(lat, lon);
        end

        function UpdateAgentStart(obj, ~, ~)
            %UPDATEAGENTSTART Update marker for agent start

            obj.start.LatitudeData = obj.agent.start_lat;
            obj.start.LongitudeData = obj.agent.start_lon;

            drawnow;  % force figure to update immediately
        end

        function UpdateAgentGoal(obj, ~, ~)
            %UPDATEAGENTGOAL Update marker for agent goal

            obj.goal.LatitudeData = obj.agent.goal_lat;
            obj.goal.LongitudeData = obj.agent.goal_lon;

            drawnow;  % force figure to update immediately
        end

        function UpdateAgentTrajectory(obj, ~, ~)
            %UPDATEAGENTTRAJECTORY Update plots/markers of agent trajectory and current position

            obj.trajectory.LatitudeData = obj.agent.trajectory_lat;
            obj.trajectory.LongitudeData = obj.agent.trajectory_lon;
            obj.position.LatitudeData = obj.agent.trajectory_lat(end);
            obj.position.LongitudeData = obj.agent.trajectory_lon(end);

            drawnow;  % force figure to update immediately
        end
    end
end

