classdef GeoGlobe3DMagneticMap < AbstractMagneticMap
    %GEOGLOBE3DMAGNETICMAP Class for managing a 3D GeographicGlobe plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    methods
        function InitializeAxes(obj, varargin)
            %INITIALIZEAXES Initialize GeographicGlobe

            [parent, ~] = obj.PopArg(varargin, "Parent", []);
            if isempty(parent)
                parent = obj.gcuif;
            end

            obj.ax = geoglobe(parent, Basemap="colorterrain", Terrain="none");  % Terrain="none" flattens terrain so it does not occlude contours and trajectories
            campos(obj.ax, 0, 0, 1e7);  % manually setting a camera position right away bypasses camera animation, speeding up initial plotting
            % obj.ax.Position = [0 0 1 1];
            hold(obj.ax);
        end

        function line = AddLine(obj, lat, lon, linespec, varargin)
            %ADDLINE Plot a line or markers on the map
            [zorder, varargin] = obj.PopArg(varargin, "ZOrder", 1);
            line = geoplot3(obj.ax, lat, lon, [], linespec, varargin{:});
            line.UserData.ZOrder = zorder;  % used for graphics layering
        end

        function [new_lat, new_lon] = CleanLatLon(~, lat, lon)
            %CLEANLATLON No cleaning necessary on 3D plots, so do nothing
            new_lat = lat;
            new_lon = lon;
        end

        function LockCamera(obj)
            %LOCKCAMERA Prevent auto camera adjustments when plot update
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

            disp("Camera locked until manually adjusted");
        end

        function CenterCameraOnAgent(obj, height)
            %CENTERCAMERAONAGENT Move the camera to the latest agent position
            if nargin < 2
                height = 7e6;  % meters above reference ellipsoid
            end
            campos(obj.ax, obj.agent.trajectory_lat(end), wrapTo180(obj.agent.trajectory_lon(end)), height);
            camheading(obj.ax, 0);
            campitch(obj.ax, -90);
            camroll(obj.ax, 0);

            drawnow;  % force figure to update immediately
        end

        function SetAgentStartToCamPos(obj)
            %SETAGENTSTARTTOCAMPOS Set the agent start position to the current camera latitude and longitude
            obj.LockCamera;
            [lat, lon, ~] = campos(obj.ax);
            obj.agent.SetStart(lat, lon);
        end

        function SetAgentGoalToCamPos(obj)
            %SETAGENTGOALTOCAMPOS Set the agent goal to the current camera latitude and longitude
            obj.LockCamera;
            [lat, lon, ~] = campos(obj.ax);
            obj.agent.SetGoal(lat, lon);
        end

        function h = gcuif(~)
            %GCUIF Get handle to current uifigure
            %   Equivalent to gcf in that an existing uifigure will be used
            %   preferentially over creating a new one

            % search for an existing uifigure
            figs = findall(groot, "Type", "figure");
            for i = 1:numel(figs)
                if matlab.ui.internal.isUIFigure(figs(i))
                    % return the found uifigure
                    h = figs(i);
                    return
                end
            end

            % no existing uifigure found, so create one
            h = uifigure();
        end
    end
end

