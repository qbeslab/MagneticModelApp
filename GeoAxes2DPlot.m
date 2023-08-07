classdef GeoAxes2DPlot < handle
    %GEOAXES2DPLOT Class for managing a 2D GeographicAxes plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - MATLAB Basemap Data - colorterrain (install for offline use)
    
    properties
        magmodel MagneticModel
        agent Agent
        ax matlab.graphics.axis.GeographicAxes
        trajectory matlab.graphics.chart.primitive.Line
        markers (3,1) matlab.graphics.chart.primitive.Line
    end
    
    methods
        function obj = GeoAxes2DPlot(magmodel, agent, parent)
            %GEOAXES2DPLOT Construct an instance of this class
            if nargin == 2
                parent = gcf;
            end
            obj.magmodel = magmodel;
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
                    datatiplabel = param.replace('_', '\_');  % default
                    datatipformat = 'auto';  % default
                    switch param
                        case "I_INCL"
                            datatiplabel = "Inclination";
                            datatipformat = 'degrees';
                        case "F_TOTAL"
                            datatiplabel = "Intensity";
                            datatipformat = '%g nT';
                    end

                    % plot contour line
                    line = geoplot(obj.ax, ...
                        contour_lat, contour_lon, ...
                        '-', LineWidth=linewidth, Color=color, ...
                        Tag=tag, UserData=datatipvalues ...
                        );
                    line.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow(datatiplabel, 'UserData', datatipformat);
                end
            end
        end

        function AddAgent(obj, agent)
            %ADDAGENT Add trajectory of an agent to maps

            obj.agent = agent;
            
            linewidth = 2;
            color = "magenta";
            
            % plot trajectory
            %   coords are wrapped here since otherwise the 2D plot would
            %   draw the trajectory off screen when longitude is outside
            %   [-180, 180] (3D plot does not need this correction)
            [new_lat, new_lon] = obj.Wrap2DTrajectoryAroundLon180(obj.agent.trajectory_lat, obj.agent.trajectory_lon);
            obj.trajectory = geoplot(obj.ax, ...
                new_lat, new_lon, ...
                '-', LineWidth=linewidth, Color=color, Marker='none', MarkerSize=2);

            % plot markers for agent start, goal, and current position
            obj.markers(1) = geoplot(obj.ax, obj.agent.start_lat, obj.agent.start_lon, 'bo', MarkerSize=8, LineWidth=2);
            obj.markers(2) = geoplot(obj.ax, obj.agent.goal_lat, obj.agent.goal_lon, 'go', MarkerSize=8, LineWidth=2);
            obj.markers(3) = geoplot(obj.ax, obj.agent.trajectory_lat(end), wrapTo180(obj.agent.trajectory_lon(end)), 'mo', MarkerSize=8, LineWidth=2);

            % update plots when agent changes
            addlistener(obj.agent, 'StartChanged', @obj.UpdateAgentStart);
            addlistener(obj.agent, 'GoalChanged', @obj.UpdateAgentGoal);
            addlistener(obj.agent, 'TrajectoryChanged', @obj.UpdateAgentTrajectory);
        end

        function [new_lat, new_lon] = Wrap2DTrajectoryAroundLon180(~, lat, lon)
            %WRAP2DTRAJECTORYAROUNDLON180 Wrap longitude values to [-180, 180] and insert NaNs to prevent plotting jumps
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

        function ToggleAgentTrajectoryMarkers(obj)
            %TOGGLEAGENTTRAJECTORYMARKERS Toggle the display of markers for every trajectory step
            if obj.trajectory.Marker == "none"
                obj.trajectory.Marker = 'o';
            else
                obj.trajectory.Marker = 'none';
            end

            drawnow;  % force figure to update immediately
        end

        function UpdateAgentStart(obj, ~, ~)
            %UPDATEAGENTSTART Update marker for agent start

            obj.markers(1).LatitudeData = obj.agent.start_lat;
            obj.markers(1).LongitudeData = obj.agent.start_lon;

            drawnow;  % force figure to update immediately
        end

        function UpdateAgentGoal(obj, ~, ~)
            %UPDATEAGENTGOAL Update marker for agent goal

            obj.markers(2).LatitudeData = obj.agent.goal_lat;
            obj.markers(2).LongitudeData = obj.agent.goal_lon;

            drawnow;  % force figure to update immediately
        end

        function UpdateAgentTrajectory(obj, ~, ~)
            %UPDATEAGENTTRAJECTORY Update plots/markers of agent trajectory and current position

            % coords are wrapped here since otherwise the 2D plot would
            % draw the trajectory off screen when longitude is outside
            % [-180, 180] (3D plot does not need this correction)
            [new_lat, new_lon] = obj.Wrap2DTrajectoryAroundLon180(obj.agent.trajectory_lat, obj.agent.trajectory_lon);
            obj.trajectory.LatitudeData = new_lat;
            obj.trajectory.LongitudeData = new_lon;
            obj.markers(3).LatitudeData = new_lat(end);
            obj.markers(3).LongitudeData = new_lon(end);

            drawnow;  % force figure to update immediately
        end
    end
end

