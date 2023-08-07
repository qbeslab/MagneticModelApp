classdef GeoAxes2DPlot < AbstractMagneticMap
    %GEOAXES2DPLOT Class for managing a 2D GeographicAxes plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    methods
        function obj = GeoAxes2DPlot(magmodel, agent, parent)
            %GEOAXES2DPLOT Construct an instance of this class
            if nargin == 2
                parent = gcf;
            end
            obj@AbstractMagneticMap(magmodel, agent, parent);
        end

        function InitializeAxes(obj, parent)
            %INITIALIZEAXES Initialize GeographicAxes
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
            line = geoplot(obj.ax, lat, lon, linespec, varargin{:});
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

