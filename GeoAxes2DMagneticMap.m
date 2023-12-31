classdef GeoAxes2DMagneticMap < AbstractMagneticMap
    %GEOAXES2DMAGNETICMAP Class for managing a 2D GeographicAxes plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    methods
        function InitializeAxes(obj, varargin)
            %INITIALIZEAXES Initialize GeographicAxes

            [parent, ~] = obj.PopArg(varargin, "Parent", []);
            if isempty(parent)
                parent = gcf;
            end

            obj.ax = geoaxes(parent, Basemap="colorterrain");
            obj.ax.InnerPosition = obj.ax.OuterPosition;
            geolimits(obj.ax, [-70, 70], [-180, 180]);  % aspect ratio constraints often override this
            try
                % add basemap picker button to uifigure
                addToolbarMapButton(axtoolbar(obj.ax, "default"));
            catch
                % do nothing in normal figure
            end
            hold(obj.ax);
        end

        function line = AddLine(obj, lat, lon, linespec, varargin)
            %ADDLINE Plot a line or markers on the map
            [zorder, varargin] = obj.PopArg(varargin, "ZOrder", 1);
            line = geoplot(obj.ax, lat, lon, linespec, varargin{:});
            line.UserData.ZOrder = zorder;  % used for graphics layering
        end

        function [new_lat, new_lon] = CleanLatLon(~, lat, lon)
            %CLEANLATLON Wrap longitude values to [-180, 180] and insert NaNs to prevent plotting jumps
            new_lon = wrapTo180(lon);
            new_lat = lat;
            jumps = find(abs(diff(new_lon)) > 350);
            if ~isempty(jumps)
                for i = reshape(jumps(end:-1:1), 1, [])
                    new_lon = [new_lon(1:i); nan; new_lon(i+1:end)];
                    new_lat = [new_lat(1:i); nan; new_lat(i+1:end)];
                end
            end
        end
    end
end

