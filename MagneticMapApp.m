classdef MagneticMapApp < handle
    %MAGNETICMAPAPP Class for managing an app with 2D and 3D magnetic maps
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    properties
        magmodel MagneticModel
        agent Agent
        gui matlab.ui.Figure
        g2D GeoAxes2DMagneticMap
        g3D GeoGlobe3DMagneticMap
        gAxesm Axesm3DMagneticMap
    end
    
    methods
        function obj = MagneticMapApp(magmodel, agent)
            %MAGNETICMAP Construct an instance of this class

            obj.magmodel = magmodel;
            obj.agent = agent;

            obj.gui = uifigure(Position=[100 200 1200 600], Name="MagneticMapApp", WindowStyle="alwaysontop");  % laptop only
            % obj.gui = uifigure(Position=[100 200 1600 800], Name="MagneticMapApp", WindowStyle="alwaysontop");  % monitor only
            % obj.gui = uifigure(Position=[1920 265 1535 785], Name="MagneticMapApp");  % dual monitors
            ug = uigridlayout(obj.gui, [1, 3]);
            p1 = uipanel(ug, Title="GeoAxes2DMagneticMap");
            p2 = uipanel(ug, Title="GeoGlobe3DMagneticMap");
            p3 = uipanel(ug, Title="Axesm3DMagneticMap");

            obj.g2D = GeoAxes2DMagneticMap(magmodel, agent, p1);
            obj.g3D = GeoGlobe3DMagneticMap(magmodel, agent, p2);
            obj.gAxesm = Axesm3DMagneticMap(magmodel, agent, p3);

            % ensure changing either 2D or 3D basemap updates both
            %    TODO adding these listeners tends to make the delete
            %    method's attempt to close the app fail
            addlistener(obj.g2D.ax, 'Basemap', 'PostSet', @obj.SyncBaseMaps);
            addlistener(obj.g3D.ax, 'Basemap', 'PostSet', @obj.SyncBaseMaps);

            % add keyboard shortcuts
            %    TODO auto closing of the app stops working when key/mouse
            %    press listeners are active
            obj.gui.KeyPressFcn = @obj.ProcessKeyPress;

            % advance agent towards goal and then center the 3D camera
            obj.agent.Step(300);
            obj.g3D.Center3DCameraOnAgent();
            obj.gAxesm.Center3DCameraOnAgent();

            % % add interactivity
            % %    TODO adding these listeners tends to make the delete
            % %    method's attempt to close the app fail
            % % obj.g2D.ax.ButtonDownFcn = @obj.ReportEvent;
            % obj.g2D.ax.ButtonDownFcn = @obj.PrintCoords2D;
            % % obj.g3D.ax.ButtonDownFcn = @obj.ReportEvent;  % TODO not working
        end

        function delete(obj)
            %DELETE Clean up app when this object is deleted
            %   TODO this stops working when key/mouse press listeners are
            %   active
            if class(obj.gui) == "matlab.ui.Figure" && isvalid(obj.gui)
                % "close all" does not work on uifigure app windows
                close(obj.gui);
            end
        end

        function ProcessKeyPress(obj, ~, event)
            %PROCESSKEYPRESS Process keyboard shortcuts
            switch event.Key
                case 'c'
                    obj.g3D.Center3DCameraOnAgent();
                case 'g'
                    obj.g3D.SetAgentGoalTo3DCamPos();
                case 'l'
                    obj.g3D.Lock3DCamera();
                case 'm'
                    obj.g2D.ToggleAgentTrajectoryMarkers();
                    obj.g3D.ToggleAgentTrajectoryMarkers();
                case 'r'
                    obj.agent.Reset();
                case 's'
                    obj.g3D.SetAgentStartTo3DCamPos();
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

        function SyncBaseMaps(obj, ~, event)
            %SYNCBASEMAPS Update the 2D and 3D basemaps to be the same
            if event.AffectedObject == obj.g2D.ax
                geobasemap(obj.g3D.ax, obj.g2D.ax.Basemap);
            else
                geobasemap(obj.g2D.ax, obj.g3D.ax.Basemap);
            end
            drawnow;  % force figures to update immediately
        end

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
    end
end
