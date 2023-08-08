classdef GeoGlobe3DMagneticMap < AbstractMagneticMap
    %GEOGLOBE3DMAGNETICMAP Class for managing a 3D GeographicGlobe plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    methods
        function obj = GeoGlobe3DMagneticMap(magmodel, agent, parent)
            %GEOGLOBE3DMAGNETICMAP Construct an instance of this class
            if nargin == 2
                parent = uifigure;
            end
            obj@AbstractMagneticMap(magmodel, agent, parent);
        end

        function InitializeAxes(obj, parent)
            %INITIALIZEAXES Initialize GeographicGlobe
            obj.ax = geoglobe(parent, Basemap="colorterrain", Terrain="none");  % Terrain="none" flattens terrain so it does not occlude contours and trajectories
            campos(obj.ax, 0, 0, 1e7);  % manually setting a camera position right away bypasses camera animation, speeding up initial plotting
            % obj.ax.Position = [0 0 1 1];
            hold(obj.ax);
        end

        function line = AddLine(obj, lat, lon, linespec, varargin)
            %ADDLINE Plot a line or markers on the map
            line = geoplot3(obj.ax, lat, lon, [], linespec, varargin{:});
        end

        function [new_lat, new_lon] = CleanLatLon(~, lat, lon)
            %CLEANLATLON No cleaning necessary on 3D plots, so do nothing
            new_lat = lat;
            new_lon = lon;
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
    end
end

