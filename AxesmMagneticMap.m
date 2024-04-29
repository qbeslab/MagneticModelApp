classdef AxesmMagneticMap < AbstractMagneticMap
    %AXESMMAGNETICMAP Class for managing an axesm-based plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox
    % Optional add-ons (use MATLAB's Add-On Explorer to install):
    %   - Parallel Computing Toolbox (install for potential speed gains)

    properties
        projection
        coastline_plot
        R
        lat_mesh
        lon_mesh
        stability
        surface_mesh
        surface_mesh_type
        vector_field
        vector_field_type
        vector_field_downsample_factor double = 5
        vector_field_gradients_scale double = 0.5
    end
    
    methods
        function InitializeAxes(obj, varargin)
            %INITIALIZEAXES Initialize axesm-based map

            [parent, varargin] = obj.PopArg(varargin, "Parent", []);
            if isempty(parent)
                parent = gcf;
            end

            % [obj.projection, ~] = obj.PopArg(varargin, "Projection", "globe");
            [obj.projection, ~] = obj.PopArg(varargin, "Projection", "robinson");
            % [obj.projection, ~] = obj.PopArg(varargin, "Projection", "mercator");
            
            % create a hidden figure to temporarily hold the axesm-based map 
            % - parenthood of the axesm-based map must be transferred after
            %   creation, since axesm() has no parameter for specifying a
            %   parent
            tempf = figure(Visible='off');

            obj.colors.surface_mesh.terrain.land = "#D2E9B8";  % muted green
            obj.colors.surface_mesh.terrain.ocean = "#9DD7EE";  % muted blue
            
            % obj.colors.surface_mesh.terrain.land = 'w';  % white
            % obj.colors.surface_mesh.terrain.ocean = "#DDDDDD";  % light gray

            switch obj.projection
                case "mercator"
                    maplatlim = [-75.5, 75.5];
                otherwise
                    maplatlim = [];
            end

            obj.ax = axesm( ...
                MapProjection=obj.projection, ...
                Frame='off', MapLatLimit=maplatlim ...
                ... Grid='on', ParallelLabel='on', MeridianLabel='on' ...
                );
            obj.ax.ButtonDownFcn = '';  % disable default binding to uimaptbx

            % raise the frame to the top (drawn in 2D only)
            frame = findobj(obj.ax.Children, "Tag", "Frame");
            if ~isempty(frame)
                frame.UserData.ZOrder = 20;
            end

            % hold(obj.ax);

            % move the camera to the origin
            obj.SetCameraPosition(0, 0);

            % transfer parenthood of the axesm-based map to the specified parent
            obj.ax.Parent = parent;
            delete(tempf);

            load("coastlines", "coastlat", "coastlon");
            obj.coastline_plot = obj.AddLine(coastlat, coastlon, 'b', Tag="Coastlines", LineWidth=1, ZOrder=1);
            obj.coastline_plot.ButtonDownFcn = '';  % disable default binding to uimaptbx
            
            % darken the background and hide some axes elements
            if class(obj.ax.Parent) == "matlab.ui.Figure"
                % does not work for uipanels
                obj.ax.Parent.Color = 'k';
            else
                if class(obj.ax.Parent) == "matlab.ui.container.Panel"
                    obj.ax.Parent.BackgroundColor = 'k';
                    obj.ax.Parent.ForegroundColor = 'w';
                end
            end
            obj.ax.Color = 'k';
            obj.ax.XColor = 'w';
            obj.ax.YColor = 'w';
            obj.ax.ZColor = 'w';
            % obj.ax.Visible = 'off';
            obj.ax.Clipping = 'off';

            obj.R = georefpostings([-90, 90], [-180, 180], obj.magmodel.sample_resolution, obj.magmodel.sample_resolution);
            [obj.lat_mesh, obj.lon_mesh] = obj.R.geographicGrid();

            % obj.SetSurfaceMesh("terrain");
            % obj.SetSurfaceMesh("topography");
            % obj.SetSurfaceMesh("orthogonality");
            obj.SetSurfaceMesh("stability");

            obj.SetVectorField("none");
            % obj.SetVectorField("flow");
            % obj.SetVectorField("gradients");

            addlistener(obj.agent, "NavigationChanged", @obj.DrawStabilityMesh);
            addlistener(obj.agent, "NavigationChanged", @obj.DrawFlowVectorFieldPlot);
            addlistener(obj.agent, "GoalChanged", @obj.DrawFlowVectorFieldPlot);
            % addlistener(obj.agent, "VelocitiesChanged", @obj.DrawFlowVectorFieldPlot);
        end

        function line = AddLine(obj, lat, lon, linespec, varargin)
            %ADDLINE Plot a line or markers on the map
            [zorder, varargin] = obj.PopArg(varargin, "ZOrder", 1);
            line = plotm(lat, lon, linespec, varargin{:}, Parent=obj.ax);
            line.UserData.ZOrder = zorder;  % used for graphics layering
            line.ButtonDownFcn = '';  % disable default binding to uimaptbx
        end

        function [new_lat, new_lon] = CleanLatLon(~, lat, lon)
            %CLEANLATLON No cleaning necessary on axesm-based plots, so do nothing
            new_lat = lat;
            new_lon = lon;
        end

        function UpdateAgentStart(obj, ~, ~)
            %UPDATEAGENTSTART Update marker for agent start

            delete(obj.start);  % clear existing start marker
            obj.start = obj.AddLine(obj.agent.start_lat, obj.agent.start_lon, 'o', Tag="Agent Start", Color=obj.colors.agent.start, MarkerSize=8, LineWidth=2, ZOrder=11);
            obj.start.ButtonDownFcn = '';  % disable default binding to uimaptbx

            % update graphics layering
            obj.SortZStack();
        end

        function UpdateAgentGoal(obj, ~, ~)
            %UPDATEAGENTGOAL Update marker for agent goal

            delete(obj.goal);  % clear existing goal marker
            obj.goal = obj.AddLine(obj.agent.goal_lat, obj.agent.goal_lon, 'o', Tag="Agent Goal", Color=obj.colors.agent.goal, MarkerSize=8, LineWidth=2, ZOrder=12);
            obj.goal.ButtonDownFcn = '';  % disable default binding to uimaptbx

            % update graphics layering
            obj.SortZStack();
        end

        function UpdateAgentTrajectory(obj, ~, ~)
            %UPDATEAGENTTRAJECTORY Update plots/markers of agent trajectory and current position

            % coords are cleaned up here since otherwise some 2D plots would
            % draw the trajectory off screen when longitude is outside
            % [-180, 180] (3D plot does not need this correction)
            [new_lat, new_lon] = obj.CleanLatLon(obj.agent.trajectory_lat, obj.agent.trajectory_lon);

            delete(obj.trajectory);  % clear existing trajectory
            obj.trajectory = obj.AddLine(new_lat, new_lon, '-', Tag="Agent Trajectory", Color=obj.colors.agent.trajectory, MarkerSize=2, LineWidth=2, ZOrder=10);
            obj.trajectory.ButtonDownFcn = '';  % disable default binding to uimaptbx

            delete(obj.position);  % clear existing position marker
            obj.position = obj.AddLine(new_lat(end), new_lon(end), 'o', Tag="Agent Position", Color=obj.colors.agent.position, MarkerSize=8, LineWidth=2, ZOrder=13);
            obj.position.ButtonDownFcn = '';  % disable default binding to uimaptbx

            % update graphics layering
            obj.SortZStack();
        end

        function SetSurfaceMesh(obj, surface_mesh_type)
            %SETSURFACEMESH ...

            delete(obj.surface_mesh);
            obj.surface_mesh_type = surface_mesh_type;
            switch obj.surface_mesh_type
                case "terrain"
                    % plot green land and blue ocean
                    % - note that zdata for the ocean is set to a negative
                    %   value so that it will not clip through the land;
                    %   this workaround results in a noticable gap between
                    %   land and ocean when the 3D globe projection is used
                    load("coastlines", "coastlat", "coastlon");
                    Z = zeros(obj.R.RasterSize);
                    obj.surface_mesh = meshm(Z, obj.R, [], -0.04, Parent=obj.ax, Tag='Ocean', FaceColor=obj.colors.surface_mesh.terrain.ocean);
                    obj.surface_mesh(2) = geoshow(coastlat, coastlon, Parent=obj.ax, Tag="Land", DisplayType='polygon', FaceColor=obj.colors.surface_mesh.terrain.land, LineStyle='none');
                    obj.surface_mesh(1).UserData.ZOrder = -0.1;
                    obj.surface_mesh(2).UserData.ZOrder = 0;
                    obj.surface_mesh(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                    obj.surface_mesh(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
                    obj.coastline_plot.Color = 'none';

                    % update graphics layering
                    obj.SortZStack();

                case "topography"
                    % plot a terrain mesh
                    load("topo.mat", "topo", "topolatlim", "topolonlim");
                    ref = georefcells(topolatlim, topolonlim, size(topo));
                    obj.surface_mesh = geoshow(topo, ref, Parent=obj.ax, Tag="Terrain", DisplayType="texturemap");
                    obj.surface_mesh.UserData.ZOrder = 0;
                    obj.surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                    [cm, cl] = demcmap(topo);
                    cm = 1 - (1 - cm) * 0.5;  % lighten the colormap
                    colormap(obj.ax, cm);
                    clim(obj.ax, cl);
                    obj.coastline_plot.Color = 'w';

                    % update graphics layering
                    obj.SortZStack();
            
                case "orthogonality"
                    % plot orthogonality as a color map
                    orthogonality = abs(asind(sind(obj.magmodel.sample_orthogonality)));  % map [-180, 180] to [0, 90]
                    obj.surface_mesh = meshm(orthogonality, obj.R, Parent=obj.ax, Tag="Orthogonality");
                    obj.surface_mesh.UserData.ZOrder = 0;
                    obj.surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                    colormap(obj.ax, "default");
                    clim(obj.ax, [0, 90]);
                    obj.coastline_plot.Color = 'w';

                    % update graphics layering
                    obj.SortZStack();

                case "stability"
                    % plot goal stability as a color map
                    obj.DrawStabilityMesh();
                    obj.coastline_plot.Color = '#333333';  % dark gray
            end
        end

        function SetVectorField(obj, vector_field_type, downsample_factor, gradients_scale)
            %SETVECTORFIELD ...

            obj.vector_field_type = vector_field_type;
            if nargin >= 3
                obj.vector_field_downsample_factor = downsample_factor;
            end
            if nargin == 4
                obj.vector_field_gradients_scale = gradients_scale;
            end
            switch obj.vector_field_type
                case "none"
                    % clear the vector field
                    delete(obj.vector_field); obj.vector_field = [];

                case "flow"
                    % plot arrows showing the paths that the agent would take
                    obj.DrawFlowVectorFieldPlot();

                case "gradients"
                    % plot two sets of arrows showing the gradients of the inclination and intensity
                    obj.DrawIFGradients();
            end
        end

        function CalculateStability(obj)
            %CALCULATESTABILITY ...

            lat = obj.magmodel.sample_latitudes;
            lon = obj.magmodel.sample_longitudes;
            dF = obj.magmodel.sample_gradients.F_TOTAL;
            dI = obj.magmodel.sample_gradients.I_INCL;
            D = obj.magmodel.samples.D_DECL;
            a = obj.agent;
            f = @a.ComputeEigenvalues;

            stab = nan(length(lat), length(lon));

            imax = length(lat);
            jmax = length(lon);
            parfor i = 1:imax
                for j = 1:jmax
                    ev = f(dF(:, i, j), dI(:, i, j), D(i, j));
                    evreal = real(ev);
                    evimag = imag(ev);
                    % is_unstable = evreal(1) > 0 || evreal(2) > 0;
                    is_unstable = evreal(1) > 1e-12 || evreal(2) > 1e-12;
                    % is_degenerate = evreal(1) == 0 || evreal(2) == 0;
                    is_degenerate = abs(evreal(1)) < 1e-12 || abs(evreal(2)) < 1e-12;
                    has_rotation = evimag(1) ~= 0 || evimag(2) ~= 0;

                    if is_unstable
                        % at least one eigenvalue real-part is positive: unstable (repelling)
                        if has_rotation
                            % spiral source
                            stab(i,j) = 0.75;  % light green with summer colormap
                        else
                            % unstable node
                            stab(i, j) = 1;  % yellow with summer colormap
                        end
                    else
                        % both eigenvalue real-parts are non-positive: stable (attracting) or neutrally stable
                        if is_degenerate
                            % at least one eigenvalue real-part is zero (or very close): neutrally stable
                            stab(i, j) = 0.5;
                        else
                            % both eigenvalue real-parts are negative: stable (attracting)
                            if has_rotation
                                % spiral sink
                                stab(i,j) = 0.25;  % medium green with summer colormap
                            else
                                % stable node
                                stab(i, j) = 0;  % dark green with summer colormap
                            end
                        end
                    end
                end
            end

            obj.stability = stab;
        end

        function DrawStabilityMesh(obj, ~, ~)
            %DRAWSTABILITYMESH ...

            if obj.surface_mesh_type == "stability"
                obj.CalculateStability();
                delete(obj.surface_mesh);
                obj.surface_mesh = meshm(obj.stability, obj.R, Parent=obj.ax, Tag="Stability");
                obj.surface_mesh.UserData.ZOrder = 0;
                obj.surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                clim(obj.ax, [0, 1]);

                % discretize and tweak the colormap for colorbar
                cm = colormap(obj.ax, "summer");
                cm = [cm(1, :); ...
                      cm(round(256 * 0.25), :); ...
                      [0.8, 0.8, 0.8]; ...
                      cm(round(256 * 0.75), :); ...
                      cm(end, :)];
                colormap(obj.ax, cm);

                % if obj.projection ~= "globe"
                %     alpha(surface_mesh, 0.3);
                % end
                
                % update graphics layering
                obj.SortZStack();
            end
        end

        function DrawFlowVectorFieldPlot(obj, ~, ~)
            %...
        
            if obj.vector_field_type == "flow"
                % temporarily change the axesm-based map's parent to a hidden figure
                % - this is necessary when the original parent is a
                %   uifigure/uipanel because quiverm does not support drawing
                %   to anything other than a figure (unlike plotm, meshm, etc.,
                %   which work as long as Parent is passed as a param)
                parent = obj.ax.Parent;
                tempf = figure(Visible='off');
                obj.ax.Parent = tempf;

                delete(obj.vector_field); obj.vector_field = [];

                obj.agent.ComputeVelocities();

                dlon = squeeze(obj.agent.sample_velocities(1, :, :));
                dlat = squeeze(obj.agent.sample_velocities(2, :, :));
            
                obj.vector_field = quiverm( ...
                    obj.lat_mesh(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    obj.lon_mesh(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    dlat(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    dlon(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end) ...
                    );
                color = "#444444";
                obj.vector_field(1).Color = color;
                obj.vector_field(2).Color = color;
                obj.vector_field(1).Tag = "Flow (Arrow Shafts)";
                obj.vector_field(2).Tag = "Flow (Arrow Heads)";
                obj.vector_field(1).UserData.ZOrder = 3;
                obj.vector_field(2).UserData.ZOrder = 3;
                obj.vector_field(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                obj.vector_field(2).ButtonDownFcn = '';  % disable default binding to uimaptbx

                % update graphics layering
                obj.SortZStack();

                % restore the original parent of the axesm-based map
                obj.ax.Parent = parent;
                delete(tempf);
            end
        end

        function DrawIFGradients(obj)
            %...

            if obj.vector_field_type == "gradients"
                % temporarily change the axesm-based map's parent to a hidden figure
                % - this is necessary when the original parent is a
                %   uifigure/uipanel because quiverm does not support drawing
                %   to anything other than a figure (unlike plotm, meshm, etc.,
                %   which work as long as Parent is passed as a param)
                parent = obj.ax.Parent;
                tempf = figure(Visible='off');
                obj.ax.Parent = tempf;

                delete(obj.vector_field); obj.vector_field = [];

                % by scaling the gradients manually here and passing 0 to
                % quiverm's scale parameter, we ensures inclination and
                % intensity gradients are on an identical custom scale
                dIdx = obj.vector_field_gradients_scale * squeeze(obj.magmodel.sample_gradients.I_INCL(1, :, :));
                dIdy = obj.vector_field_gradients_scale * squeeze(obj.magmodel.sample_gradients.I_INCL(2, :, :));
                dFdx = obj.vector_field_gradients_scale * squeeze(obj.magmodel.sample_gradients.F_TOTAL(1, :, :));
                dFdy = obj.vector_field_gradients_scale * squeeze(obj.magmodel.sample_gradients.F_TOTAL(2, :, :));

                % draw inclination gradient
                h = quiverm( ...
                    obj.lat_mesh(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    obj.lon_mesh(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    dIdy(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    dIdx(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    '-', 0);
                color = "#EEEEEE";
                h(1).Color = color;
                h(2).Color = color;
                h(1).Tag = "Inclination Gradient (Arrow Shafts)";
                h(2).Tag = "Inclination Gradient (Arrow Heads)";
                h(1).UserData.ZOrder = 3;
                h(2).UserData.ZOrder = 3;
                h(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                h(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
                obj.vector_field(1) = h(1);
                obj.vector_field(2) = h(2);
    
                % draw intensity gradient
                h = quiverm( ...
                    obj.lat_mesh(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    obj.lon_mesh(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    dFdy(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    dFdx(1:obj.vector_field_downsample_factor:end, 1:obj.vector_field_downsample_factor:end), ...
                    '-', 0);
                color = "#444444";
                h(1).Color = color;
                h(2).Color = color;
                h(1).Tag = "Intensity Gradient (Arrow Shafts)";
                h(2).Tag = "Intensity Gradient (Arrow Heads)";
                h(1).UserData.ZOrder = 3;
                h(2).UserData.ZOrder = 3;
                h(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                h(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
                obj.vector_field(3) = h(1);
                obj.vector_field(4) = h(2);

                % update graphics layering
                obj.SortZStack();

                % restore the original parent of the axesm-based map
                obj.ax.Parent = parent;
                delete(tempf);
            end
        end

        function SetCameraPosition(obj, lat, lon)
            %SETCAMERAPOSITION Move the camera to a given coordinate

            % temporarily change the axesm-based map's parent to a hidden figure
            % - this is necessary when the original parent is a
            %   uifigure/uipanel because the camera functions do not support drawing
            %   to anything other than a figure (unlike plotm, meshm, etc.,
            %   which work as long as Parent is passed as a param)
            parent = obj.ax.Parent;
            tempf = figure(Visible='off');
            obj.ax.Parent = tempf;

            camtargm(lat, lon, 0);
            camposm(lat, lon, 1);

            % restore the original parent of the axesm-based map
            obj.ax.Parent = parent;
            delete(tempf);
        end

        function CenterCameraOnAgent(obj)
            %CENTERCAMERAONAGENT Move the camera to the latest agent position
            obj.SetCameraPosition(obj.agent.trajectory_lat(end), obj.agent.trajectory_lon(end));
        end

        function setm(obj, varargin)
            %SETM Wrapper for Mapping Toolbox's setm that preserves ZOrder data
            %  Without this, the direct use of the Mapping Toolbox's setm
            %  will copy most plot elements without copying UserData,
            %  thereby erasing most ZOrder data.

            % store the current zorders
            zorders = nan(1, length(obj.ax.Children));
            for i = 1:length(obj.ax.Children)
                try
                    zorders(i) = obj.ax.Children(i).UserData.ZOrder;
                catch
                    zorders(i) = 1;  % default
                end
            end

            % execute setm, which will erase most zorders
            setm(obj.ax, varargin{:});

            % restore the original zorders
            for i = 1:length(obj.ax.Children)
                obj.ax.Children(i).UserData.ZOrder = zorders(i);
            end
        end
    end
end

