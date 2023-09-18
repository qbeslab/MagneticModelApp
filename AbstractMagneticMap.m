classdef (Abstract) AbstractMagneticMap < handle
    %ABSTRACTMAGNETICMAP Superclass for magnetic maps
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - Parallel Computing Toolbox (install for potential speed gains)
    
    properties
        magmodel MagneticModel
        agent Agent
        ax
        trajectory
        start
        goal
        position
        level_curves
        level_curves_type
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
            obj.SetLevelCurves("contours");
            % obj.SetLevelCurves("nullclines");
            obj.AddAgentPlots;

            addlistener(obj.agent, "NavigationChanged", @obj.DrawNullclinePlots);
            addlistener(obj.agent, "GoalChanged", @obj.DrawNullclinePlots);
            % addlistener(obj.agent, "VelocitiesChanged", @obj.DrawNullclinePlots);
        end

        function SetLevelCurves(obj, level_curves_type)
            %SETLEVELCURVES ...

            obj.level_curves_type = level_curves_type;
            switch obj.level_curves_type
                case "none"
                    delete(obj.level_curves); obj.level_curves = [];
                case "contours"
                    obj.DrawContourPlots();
                case "nullclines"
                    obj.DrawNullclinePlots();
            end
        end

        function DrawContourPlots(obj)
            %DRAWCONTOURPLOTS Add magnetic property contours to map

            if obj.level_curves_type == "contours"
                delete(obj.level_curves); obj.level_curves = [];

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
    
                        % set zorder
                        zorder = 2;
                        switch param
                            case "I_INCL"
                                zorder = 2.1;
                            case "F_TOTAL"
                                zorder = 2.2;
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
                            Tag=tag, ZOrder=zorder ...
                            );
                        if isprop(line, "DataTipTemplate")
                            % add tooltips if the axes support them
                            line.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow(datatiplabel, datatipvalues, datatipformat);
                        end
                        obj.level_curves(end+1) = line;
                    end
                end
    
                % update graphics layering
                obj.SortZStack();
            end
        end

        function DrawNullclinePlots(obj, ~, ~)
            %DRAWNULLCLINEPLOTS Add velocity nullclines to map

            if obj.level_curves_type == "nullclines"
                delete(obj.level_curves); obj.level_curves = [];

                obj.agent.ComputeVelocities();
                
                interpm_maxdiff = 1;  % degrees (or nan to skip contour interpolation)
                % interpm_maxdiff = nan;  % degrees (or nan to skip contour interpolation)
    
                lat = obj.magmodel.sample_latitudes;
                lon = obj.magmodel.sample_longitudes;
                dlon = squeeze(obj.agent.sample_velocities(1, :, :));
                dlat = squeeze(obj.agent.sample_velocities(2, :, :));
    
                % locate velocity nullclines (velocity contours with level 0)
                dlat_contours = contourc(lon, lat, dlat, -1e6:1e6:1e6);  % contourc won't allow simply [0]
                dlon_contours = contourc(lon, lat, dlon, -1e6:1e6:1e6);  % contourc won't allow simply [0]
                dlat_table = getContourLineCoordinates(dlat_contours);
                dlon_table = getContourLineCoordinates(dlon_contours);
    
                % collect nullcline coordinates
                dlat_x = [];
                dlat_y = [];
                dlon_x = [];
                dlon_y = [];
                for param = ["dlat", "dlon"]
                    switch param
                        case "dlat"
                            contour_table = dlat_table;
                        case "dlon"
                            contour_table = dlon_table;
                    end
                    nContours = max(contour_table.Group);
    
                    % plot each contour level one at a time
                    for i = 1:nContours
                        gidx = contour_table.Group == i;
    
                        % get nullcline coordinates
                        contour_lat = contour_table.Y(gidx);
                        contour_lon = contour_table.X(gidx);
                        if ~isnan(interpm_maxdiff)
                            % interpolate points on the contour line if necessary
                            [contour_lat, contour_lon] = interpm(contour_lat, contour_lon, interpm_maxdiff, 'gc');
                        end

                        % store coordinates for equilibria detection
                        % - nan is appended to each contour line to prevent
                        %   spurious intersection detection at nullcline
                        %   discontinuities
                        switch param
                            case "dlat"
                                dlat_x = [dlat_x; contour_lon; nan];
                                dlat_y = [dlat_y; contour_lat; nan];
                            case "dlon"
                                dlon_x = [dlon_x; contour_lon; nan];
                                dlon_y = [dlon_y; contour_lat; nan];
                        end
                    end
                end

                % plot x-nullcline (E/W-nullcline, dlon=0)
                color = "#444444";  % dark gray
                tag = "Nullcline dlon = 0";
                datatiplabel = "NULLCLINE (E/W speed = 0)";
                line = obj.AddLine( ...
                    dlon_y, dlon_x, ...
                    '-', LineWidth=2, Color=color, ...
                    Tag=tag, ZOrder=2.2 ...
                    );
                if isprop(line, "DataTipTemplate")
                    % add tooltips if the axes support them
                    line.DataTipTemplate.DataTipRows = [dataTipTextRow(datatiplabel, ''); line.DataTipTemplate.DataTipRows];
                end
                obj.level_curves(end+1) = line;

                % plot y-nullcline (N/S nullcline, dlat=0)
                color = "#EEEEEE";  % light gray
                tag = "Nullcline dlat = 0";
                datatiplabel = "NULLCLINE (N/S speed = 0)";
                line = obj.AddLine( ...
                    dlat_y, dlat_x, ...
                    '-', LineWidth=2, Color=color, ...
                    Tag=tag, ZOrder=2.1 ...
                    );
                if isprop(line, "DataTipTemplate")
                    % add tooltips if the axes support them
                    line.DataTipTemplate.DataTipRows = [dataTipTextRow(datatiplabel, ''); line.DataTipTemplate.DataTipRows];
                end
                obj.level_curves(end+1) = line;

                % locate equilibria at the intersections of nullclines
                [intersections_lon, intersections_lat] = polyxpoly(dlat_x, dlat_y, dlon_x, dlon_y);
                % disp("eq pt lat   eq pt lon");
                % disp([intersections_lat, intersections_lon]);
    
                % plot nullclines intersections
                try
                    line = obj.AddLine( ...
                            intersections_lat, intersections_lon, ...
                            'ro', MarkerSize=3, LineWidth=2, ...
                            Tag="Nullclines Intersections", ZOrder=2.3 ...
                        );
                    if isprop(line, "DataTipTemplate")
                        % add tooltips if the axes support them
                        line.DataTipTemplate.DataTipRows = [dataTipTextRow('FIXED POINT', ''); line.DataTipTemplate.DataTipRows];
                    end
                    obj.level_curves(end+1) = line;
                catch
                    % will fail if there are no intersections
                end
    
                % update graphics layering
                obj.SortZStack();
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
                '-', Tag="Agent Trajectory", LineWidth=linewidth, Color=color, Marker='none', MarkerSize=2, ZOrder=10);

            % plot markers for agent start, goal, and current position
            obj.start = obj.AddLine(obj.agent.start_lat, obj.agent.start_lon, 'bo', Tag="Agent Start", MarkerSize=8, LineWidth=2, ZOrder=11);
            obj.goal = obj.AddLine(obj.agent.goal_lat, obj.agent.goal_lon, 'go', Tag="Agent Goal", MarkerSize=8, LineWidth=2, ZOrder=12);
            obj.position = obj.AddLine(obj.agent.trajectory_lat(end), wrapTo180(obj.agent.trajectory_lon(end)), 'mo', Tag="Agent Position", MarkerSize=8, LineWidth=2, ZOrder=13);

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

            % update graphics layering
            obj.SortZStack();
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

        function SortZStack(obj)
            %SORTZSTACK Sort graphics elements according to ZOrder (greater values on top)
            children = obj.ax.Children;
            zorders = nan(length(children), 1);
            for i = 1:length(children)
                if isfield(children(i).UserData, "ZOrder")
                    zorders(i) = children(i).UserData.ZOrder;
                else
                    zorders(i) = 1;  % default
                end
            end
            [~, sortidx] = sort(zorders);
            sortidx = sortidx(end:-1:1);  % reverse to get greatest to smallest ZOrder
            obj.ax.Children = children(sortidx);
            drawnow;  % force figure to update immediately
        end

        function [value, newvarargs] = PopArg(~, varargs, name, default)
            %POPARG Extract one name-value pair from a function varargin

            % convert varargs from a cell array to a struct
            s = struct(varargs{:});

            if isfield(s, name)
                % extract value of named property if it exists
                value = s.(name);

                % remove the name-value pair and convert the struct back to a cell array
                s = rmfield(s, name);
                newvarargs = [fieldnames(s), struct2cell(s)]';
                newvarargs = newvarargs(:)';
            else
                % return default value and original cell array if named property does not exist
                value = default;
                newvarargs = varargs;
            end
        end
    end
end

