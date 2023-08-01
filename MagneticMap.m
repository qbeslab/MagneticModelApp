classdef MagneticMap < handle
    %MAGNETICMAP Class for managing an app with 2D and 3D magnetic maps
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    properties
        magmodel
        agent
        app
        g2D
        g3D
        markers2D
        markers3D
        trajectory2D
        trajectory3D
    end
    
    methods
        function obj = MagneticMap(magmodel, agent)
            %MAGNETICMAP Construct an instance of this class

            obj.magmodel = magmodel;

            obj.InitializeApp();
            obj.AddContourPlots();
            obj.AddAgent(agent);
            obj.agent.Step(300);
            obj.Center3DCameraOnAgent();

            % % add interactivity
            % %    TODO adding these listeners tends to make the delete
            % %    method's attempt to close the app fail
            % % obj.g2D.ButtonDownFcn = @obj.ReportEvent;
            % obj.g2D.ButtonDownFcn = @obj.PrintCoords2D;
            % % obj.g2D.ButtonDownFcn = @obj.AskAgentToStep;
            % % obj.g3D.ButtonDownFcn = @obj.ReportEvent;  % TODO not working
        end

        function delete(obj)
            %DELETE Clean up app when this object is deleted
            %   TODO this stops working when key/mouse press listeners are
            %   active
            if class(obj.app) == "matlab.ui.Figure" && isvalid(obj.app)
                % "close all" does not work on uifigure app windows
                close(obj.app);
            end
        end

        function InitializeApp(obj)
            %INITIALIZEAPP Initialize the multi-panel app with 2D and 3D maps
            
            obj.app = uifigure(Position=[100 100 1200 600], WindowStyle="alwaysontop");  % laptop only
            % obj.app = uifigure(Position=[100 100 1600 800], WindowStyle="alwaysontop");  % monitor only
            % obj.app = uifigure(Position=[1920 265 1535 785]);  % dual monitors
            ug = uigridlayout(obj.app, [1,2]);
            p1 = uipanel(ug, Title="2D");
            p2 = uipanel(ug, Title="3D");
            % basemap = "darkwater";
            % basemap = "grayterrain";
            basemap = "colorterrain";
            % basemap = "bluegreen";
            
            obj.g2D = geoaxes(p1, Basemap=basemap);
            obj.g2D.InnerPosition = obj.g2D.OuterPosition;
            geolimits(obj.g2D, [-70, 70], [-180, 180]);  % aspect ratio constraints often override this
            
            obj.g3D = geoglobe(p2, Basemap=basemap, Terrain="none");  % Terrain="none" flattens terrain so it does not occlude contours and trajectories
            % g3D.Position = [0 0 1 1];

            hold(obj.g2D);
            hold(obj.g3D);

            % % add basemap picker to 2D map, and ensure changing either basemap updates both
            % %    TODO adding these listeners tends to make the delete
            % %    method's attempt to close the app fail
            % addToolbarMapButton(axtoolbar(obj.g2D, "default"));
            % addlistener(obj.g2D, 'Basemap', 'PostSet', @obj.SyncBaseMaps);
            % addlistener(obj.g3D, 'Basemap', 'PostSet', @obj.SyncBaseMaps);

            % add keyboard shortcuts
            %    TODO auto closing of the app stops working when key/mouse
            %    press listeners are active
            obj.app.KeyPressFcn = @obj.ProcessKeyPress;
        end

        function AddContourPlots(obj)
            %ADDCONTOURPLOTS Add magnetic property contours to maps

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
                            if level == 0
                                linewidth = 3;  % magnetic equator
                            else
                                if mod(level, 30) == 0
                                    linewidth = 2;  % multiples of 30 degrees
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

                    % plot 2D contour line
                    geoplot(obj.g2D, ...
                        contour_lat, contour_lon, ...
                        '-', LineWidth=linewidth, Color=color);

                    % plot 3D contour line
                    geoplot3(obj.g3D, ...
                        contour_lat, contour_lon, [], ...
                        '-', LineWidth=linewidth, Color=color);
                end
            end
        end

        function AddAgent(obj, agent)
            %ADDAGENT Add trajectory of an agent to maps

            obj.agent = agent;
            
            linewidth = 2;
            color = "magenta";
            
            % plot 2D trajectory
            %    TODO this breaks if the trajectory wraps across the
            %    east/west edges of the map
            obj.trajectory2D = geoplot(obj.g2D, ...
                obj.agent.trajectory_lat, obj.agent.trajectory_lon, ...
                '-', LineWidth=linewidth, Color=color, Marker='none', MarkerSize=2);

            % plot 3D trajectory
            obj.trajectory3D = geoplot3(obj.g3D, ...
                obj.agent.trajectory_lat, obj.agent.trajectory_lon, [], ...
                '-', LineWidth=linewidth, Color=color, Marker='none', MarkerSize=2);

            % plot 2D markers for agent start and goal
            obj.markers2D{1} = geoplot(obj.g2D, obj.agent.start_lat, obj.agent.start_lon, 'bo', MarkerSize=8, LineWidth=2);
            obj.markers2D{2} = geoplot(obj.g2D, obj.agent.goal_lat, obj.agent.goal_lon, 'go', MarkerSize=8, LineWidth=2);
            obj.markers2D{3} = geoplot(obj.g2D, obj.agent.trajectory_lat(end), obj.agent.trajectory_lon(end), 'mo', MarkerSize=8, LineWidth=2);

            % plot 3D markers for agent start and goal
            obj.markers3D{1} = geoplot3(obj.g3D, obj.agent.start_lat, obj.agent.start_lon, [], 'bo', MarkerSize=8, LineWidth=2);
            obj.markers3D{2} = geoplot3(obj.g3D, obj.agent.goal_lat, obj.agent.goal_lon, [], 'go', MarkerSize=8, LineWidth=2);
            obj.markers3D{3} = geoplot3(obj.g3D, obj.agent.trajectory_lat(end), obj.agent.trajectory_lon(end), [], 'mo', MarkerSize=8, LineWidth=2);

            % update plots when agent changes
            addlistener(obj.agent, 'StartChanged', @obj.UpdateAgentStart);
            addlistener(obj.agent, 'GoalChanged', @obj.UpdateAgentGoal);
            addlistener(obj.agent, 'TrajectoryChanged', @obj.UpdateAgentTrajectory);
        end

        function ToggleAgentTrajectoryMarkers(obj)
            %TOGGLEAGENTTRAJECTORYMARKERS Toggle the display of markers for every trajectory step
            if obj.trajectory2D.Marker == "none"
                obj.trajectory2D.Marker = 'o';
            else
                obj.trajectory2D.Marker = 'none';
            end
            if obj.trajectory3D.Marker == "none"
                obj.trajectory3D.Marker = 'o';
            else
                obj.trajectory3D.Marker = 'none';
            end
        end

        function Lock3DCamera(obj)
            %LOCK3DCAMERA Prevent auto 3D camera adjustments when plots update
            %   If the camera is moved using the mouse, auto camera
            %   adjustments will resume, and this method should be run
            %   again to stop them.

            % % BUG this manual method does not really work as the docs say it should
            % campos(obj.g3D, "manual");
            % camheading(obj.g3D, "manual");
            % campitch(obj.g3D, "manual");
            % camroll(obj.g3D, "manual");

            % this works better
            [lat, lon, height] = campos(obj.g3D);
            heading = camheading(obj.g3D); 
            pitch = campitch(obj.g3D);
            roll = camroll(obj.g3D);
            campos(obj.g3D, lat, lon, height);
            camheading(obj.g3D, heading);
            campitch(obj.g3D, pitch);
            camroll(obj.g3D, roll);
            
            disp("3D camera locked until manually adjusted");
        end

        function Center3DCameraOnAgent(obj, height)
            %CENTER3DONAGENT Move the 3D camera to the latest agent position
            if nargin < 2
                height = 7e6;  % meters above reference ellipsoid
            end
            campos(obj.g3D, obj.agent.trajectory_lat(end), obj.agent.trajectory_lon(end), height);
            camheading(obj.g3D, 0);
            campitch(obj.g3D, -90);
            camroll(obj.g3D, 0);
        end

        function SetAgentStartTo3DCamPos(obj)
            %SETAGENTSTARTTO3DCAMPOS Set the agent start position to the current 3D camera latitude and longitude
            obj.Lock3DCamera;
            [lat, lon, ~] = campos(obj.g3D);
            obj.agent.SetStart(lat, lon);
        end

        function SetAgentGoalTo3DCamPos(obj)
            %SETAGENTGOALTO3DCAMPOS Set the agent goal to the current 3D camera latitude and longitude
            obj.Lock3DCamera;
            [lat, lon, ~] = campos(obj.g3D);
            obj.agent.SetGoal(lat, lon);
        end

        function UpdateAgentStart(obj, ~, ~)
            %UPDATEAGENTSTARTANDGOAL Update markers for agent start

            obj.markers2D{1}.LatitudeData = obj.agent.start_lat;
            obj.markers2D{1}.LongitudeData = obj.agent.start_lon;

            obj.markers3D{1}.LatitudeData = obj.agent.start_lat;
            obj.markers3D{1}.LongitudeData = obj.agent.start_lon;
        end

        function UpdateAgentGoal(obj, ~, ~)
            %UPDATEAGENTSTARTANDGOAL Update markers for agent goal

            obj.markers2D{2}.LatitudeData = obj.agent.goal_lat;
            obj.markers2D{2}.LongitudeData = obj.agent.goal_lon;

            obj.markers3D{2}.LatitudeData = obj.agent.goal_lat;
            obj.markers3D{2}.LongitudeData = obj.agent.goal_lon;
        end

        function UpdateAgentTrajectory(obj, ~, ~)
            %UPDATEAGENTTRAJECTORY Update plots/markers of agent trajectory and current position

            obj.trajectory2D.LatitudeData = obj.agent.trajectory_lat;
            obj.trajectory2D.LongitudeData = obj.agent.trajectory_lon;
            obj.markers2D{3}.LatitudeData = obj.agent.trajectory_lat(end);
            obj.markers2D{3}.LongitudeData = obj.agent.trajectory_lon(end);

            obj.trajectory3D.LatitudeData = obj.agent.trajectory_lat;
            obj.trajectory3D.LongitudeData = obj.agent.trajectory_lon;
            obj.markers3D{3}.LatitudeData = obj.agent.trajectory_lat(end);
            obj.markers3D{3}.LongitudeData = obj.agent.trajectory_lon(end);

            % obj.Center3DCameraOnAgent();
        end

        function ProcessKeyPress(obj, ~, event)
            %PROCESSKEYPRESS Process keyboard shortcuts
            switch event.Key
                case 'c'
                    obj.Center3DCameraOnAgent();
                case 'g'
                    obj.SetAgentGoalTo3DCamPos();
                case 'l'
                    obj.Lock3DCamera();
                case 'm'
                    obj.ToggleAgentTrajectoryMarkers();
                case 'r'
                    obj.agent.Reset();
                case 's'
                    obj.SetAgentStartTo3DCamPos();
                case '1'
                    obj.agent.Step(1);
                case '2'
                    obj.agent.Step(10);
                case '3'
                    obj.agent.Step(100);
                case '4'
                    obj.agent.Step(1000);
                case '5'
                    obj.agent.Step(10000);
            end
        end

        % function SyncBaseMaps(obj, ~, event)
        %     %SYNCBASEMAPS Update the 2D and 3D basemaps to be the same
        %     if event.AffectedObject == obj.g2D
        %         geobasemap(obj.g3D, obj.g2D.Basemap);
        %     else
        %         geobasemap(obj.g2D, obj.g3D.Basemap);
        %     end
        % end
        % 
        % function ReportEvent(~, src, event)
        %     disp(src);
        %     disp(event);
        % end
        % 
        % function PrintCoords2D(obj, ~, event)
        %     %PRINTCOORDS2D Print the coords of a click on the 2D map
        %     lat = event.IntersectionPoint(1);
        %     lon = event.IntersectionPoint(2);
        %     disp(['Latitude: ', char(string(lat)), '  Longitude: ', char(string(lon))]);
        % 
        %     % [lat, lon] = inputm;  % TODO not working
        %     % disp(['Latitude: ', char(string(lat)), '  Longitude: ', char(string(lon))]);
        % end
        %
        % function AskAgentToStep(obj, ~, ~)
        %     obj.agent.Step();
        % end
    end
end
