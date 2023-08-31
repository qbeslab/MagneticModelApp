classdef (Abstract) AbstractMagneticMap < handle
    %ABSTRACTMAGNETICMAP Superclass for magnetic maps
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    
    properties
        magmodel MagneticModel
        agent Agent
        ax
        trajectory
        start
        goal
        position
    end

    methods (Abstract)
        InitializeAxes(obj, parent)
        line = AddLine(obj, lat, lon, linespec, varargin)
        [new_lat, new_lon] = CleanLatLon(obj, lat, lon)
    end
    
    methods
        function obj = AbstractMagneticMap(magmodel, agent, parent)
            %ABSTRACTMAGNETICMAP Construct an instance of this class
            obj.magmodel = magmodel;
            obj.agent = agent;
            obj.InitializeAxes(parent);
            obj.AddContourPlots;
            obj.AddAgentPlots;
        end

        function AddContourPlots(obj)
            %ADDCONTOURPLOTS Add magnetic property contours to map

            interpm_maxdiff = 1;  % degrees (or nan to skip contour interpolation)
            % interpm_maxdiff = nan;  % degrees (or nan to skip contour interpolation)

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
                            if mod(level, 10) == 0
                                linewidth = 2;  % multiples of 10 microtesla
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
                            datatipformat = '%g μT';
                    end

                    % plot contour line
                    line = obj.AddLine( ...
                        contour_lat, contour_lon, ...
                        '-', LineWidth=linewidth, Color=color, ...
                        Tag=tag, UserData=datatipvalues ...
                        );
                    if isprop(line, "DataTipTemplate")
                        % add tooltips if the axes support them
                        line.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow(datatiplabel, 'UserData', datatipformat);
                    end
                end
            end
        end

        function AddAgentPlots(obj)
            %ADDAGENTPLOTS Add agent trajectory and markers to map
            
            linewidth = 2;
            color = "magenta";
            
            % plot trajectory
            %   coords are cleaned up here since otherwise the 2D plot would
            %   draw the trajectory off screen when longitude is outside
            %   [-180, 180] (3D plot does not need this correction)
            [new_lat, new_lon] = obj.CleanLatLon(obj.agent.trajectory_lat, obj.agent.trajectory_lon);
            obj.trajectory = obj.AddLine( ...
                new_lat, new_lon, ...
                '-', Tag="Agent Trajectory", LineWidth=linewidth, Color=color, Marker='none', MarkerSize=2);

            % plot markers for agent start, goal, and current position
            obj.start = obj.AddLine(obj.agent.start_lat, obj.agent.start_lon, 'bo', Tag="Agent Start", MarkerSize=8, LineWidth=2);
            obj.goal = obj.AddLine(obj.agent.goal_lat, obj.agent.goal_lon, 'go', Tag="Agent Goal", MarkerSize=8, LineWidth=2);
            obj.position = obj.AddLine(obj.agent.trajectory_lat(end), wrapTo180(obj.agent.trajectory_lon(end)), 'mo', Tag="Agent Position", MarkerSize=8, LineWidth=2);

            % add tooltips if the axes support them
            if isprop(obj.start, "DataTipTemplate")
                obj.start.DataTipTemplate.DataTipRows = [dataTipTextRow('START', ''); obj.start.DataTipTemplate.DataTipRows];
                obj.start.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Inclination', @(~) obj.agent.start_I_INCL, 'degrees');
                obj.start.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Intensity', @(~) obj.agent.start_F_TOTAL, '%g μT');

                obj.goal.DataTipTemplate.DataTipRows = [dataTipTextRow('GOAL', ''); obj.goal.DataTipTemplate.DataTipRows];
                obj.goal.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Inclination', @(~) obj.agent.goal_I_INCL, 'degrees');
                obj.goal.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Intensity', @(~) obj.agent.goal_F_TOTAL, '%g μT');

                obj.position.DataTipTemplate.DataTipRows = [dataTipTextRow('AGENT', ''); obj.position.DataTipTemplate.DataTipRows];
                obj.position.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Inclination', @(~) obj.agent.current_I_INCL, 'degrees');
                obj.position.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Intensity', @(~) obj.agent.current_F_TOTAL, '%g μT');
            end

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

            % coords are cleaned up here since otherwise the 2D plot would
            % draw the trajectory off screen when longitude is outside
            % [-180, 180] (3D plot does not need this correction)
            [new_lat, new_lon] = obj.CleanLatLon(obj.agent.trajectory_lat, obj.agent.trajectory_lon);
            obj.trajectory.LatitudeData = new_lat;
            obj.trajectory.LongitudeData = new_lon;
            obj.position.LatitudeData = new_lat(end);
            obj.position.LongitudeData = new_lon(end);

            drawnow;  % force figure to update immediately
        end
    end
end

