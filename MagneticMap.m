classdef MagneticMap < handle
    %MAGNETICMAP Class for managing an app with 2D and 3D magnetic maps
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    %   - getContourLineCoordinates (from MathWorks File Exchange)
    
    properties
        magmodel
        agent
        contour_levels
        contour_tables
        app
        g2D
        g3D
        trajectory2D
        trajectory3D
    end
    
    methods
        function obj = MagneticMap(magmodel, agent)
            %MAGNETICMAP Construct an instance of this class

            obj.magmodel = magmodel;
            obj.contour_levels = struct( ...
                I_INCL = -90:10:90, ... degrees
                F_TOTAL = 0:2000:70000 ... nanotesla
                );

            obj.ComputeContours(magmodel);
            obj.InitializeApp();
            obj.AddContourPlots();
            obj.AddAgent(agent);
            obj.agent.Step(300);
            obj.Center3DOnAgent();

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
            if class(obj.app) == "matlab.ui.Figure" && isvalid(obj.app)
                % "close all" does not work on uifigure app windows
                close(obj.app);
            end
        end
        
        function ComputeContours(obj, magmodel)
            %COMPUTECONTOURS Compute the magnetic field property contours
            for param_string = ["I_INCL", "F_TOTAL"]
                contour_matrix = contourc(magmodel.longitudes, magmodel.latitudes, magmodel.samples.(param_string), obj.contour_levels.(param_string)); 
                obj.contour_tables.(param_string) = getContourLineCoordinates(contour_matrix);
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
            campos(obj.g3D, 0, 0, 1e7);  % explicitly setting camera position seems to prevent geoplot3 from moving the camera before user interaction
            % g3D.Position = [0 0 1 1];

            % % add basemap picker to 2D map, and ensure changing either basemap updates both
            % %    TODO adding these listeners tends to make the delete
            % %    method's attempt to close the app fail
            % addToolbarMapButton(axtoolbar(obj.g2D, "default"));
            % addlistener(obj.g2D, 'Basemap', 'PostSet', @obj.SyncBaseMaps);
            % addlistener(obj.g3D, 'Basemap', 'PostSet', @obj.SyncBaseMaps);

            hold(obj.g2D);
            hold(obj.g3D);
        end

        function AddContourPlots(obj)
            %ADDCONTOURPLOTS Add magnetic property contours to maps

            % interpm_maxdiff = 0.1;  % degrees (or nan to skip contour interpolation)
            interpm_maxdiff = nan;  % degrees (or nan to skip contour interpolation)

            % add contours
            for param_string = ["I_INCL", "F_TOTAL"]
                contour_table = obj.contour_tables.(param_string);
                nContours = max(contour_table.Group);

                % plot each contour level one at a time
                for i = 1:nContours
                    gidx = contour_table.Group == i;
                    level = unique(contour_table.Level(gidx));

                    % set line width
                    linewidth = 0.5;  % default
                    switch param_string
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
                    switch param_string
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
                '-', LineWidth=linewidth, Color=color);

            % plot 3D trajectory
            obj.trajectory3D = geoplot3(obj.g3D, ...
                obj.agent.trajectory_lat, obj.agent.trajectory_lon, [], ...
                '-', LineWidth=linewidth, Color=color);

            % addlistener(obj.agent, 'trajectory_lat', 'PostSet', @obj.UpdateTrajectory);
            addlistener(obj.agent, 'trajectory_lon', 'PostSet', @obj.UpdateTrajectory);
        end

        function UpdateTrajectory(obj, ~, ~)
            %UPDATETRAJECTORY Update plots of agent trajectory
            %   TODO sometimes plot will try to redraw when lat but not lon
            %   has been updated -- workaround: listen for lon change
            %   but not lat change
            obj.trajectory2D.LatitudeData = obj.agent.trajectory_lat;
            obj.trajectory2D.LongitudeData = obj.agent.trajectory_lon;
            obj.trajectory3D.LatitudeData = obj.agent.trajectory_lat;
            obj.trajectory3D.LongitudeData = obj.agent.trajectory_lon;

            % obj.Center3DOnAgent();
        end

        function Center3DOnAgent(obj)
            %CENTER3DONAGENT Move the 3D camera to the latest agent position
            campos(obj.g3D, obj.agent.trajectory_lat(end), obj.agent.trajectory_lon(end), 1e7);
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
