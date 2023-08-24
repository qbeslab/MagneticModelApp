classdef Axesm3DMagneticMap < AbstractMagneticMap
    %AXESM3DMAGNETICMAP Class for managing a 3D axesm-based plot of the magnetic environment
    % Required add-ons (use MATLAB's Add-On Explorer to install):
    %   - Mapping Toolbox

    properties
        projection
        coastline_plot
        R
        lat
        lon
        dlatI
        dlonI
        dlatF
        dlonF
        orthogonality
        stability
        surface_mesh
        surface_mesh_type
        vector_field
        vector_field_type
    end
    
    methods
        function obj = Axesm3DMagneticMap(magmodel, agent, parent)
            %AXESM3DMAGNETICMAP Construct an instance of this class
            if nargin == 2
                parent = gcf;
            end
            obj@AbstractMagneticMap(magmodel, agent, parent);
        end
        
        function InitializeAxes(obj, parent)
            %INITIALIZEAXES Initialize 3D axesm-based map
            
            % create a hidden figure to temporarily hold the axesm-based map 
            % - parenthood of the axesm-based map must be transferred after
            %   creation, since axesm() has no parameter for specifying a
            %   parent
            tempf = figure(Visible='off');
            
            obj.projection = "globe";
            obj.ax = axesm( ...
                MapProjection=obj.projection, ...
                Frame='off' ...
                ... Grid='on', ParallelLabel='on', MeridianLabel='on', ...
                ... MapLatLimit=[-80 80] ...
                );
            obj.ax.ButtonDownFcn = '';  % disable default binding to uimaptbx

            % hold(obj.ax);

            % move the camera to the origin
            obj.Set3DCameraPosition(0, 0);

            % transfer parenthood of the axesm-based map to the specified parent
            obj.ax.Parent = parent;
            delete(tempf);

            load("coastlines", "coastlat", "coastlon");
            obj.coastline_plot = plotm(coastlat, coastlon, 'b', Parent=obj.ax);
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
            [obj.lat, obj.lon] = obj.R.geographicGrid();

            [obj.dlonI, obj.dlatI] = gradient(obj.magmodel.samples.I_INCL);
            [obj.dlonF, obj.dlatF] = gradient(obj.magmodel.samples.F_TOTAL);

            % obj.SetMesh("terrain");
            % obj.SetMesh("orthogonality");
            obj.SetSurfaceMesh("stability");
        end

        function line = AddLine(obj, lat, lon, linespec, varargin)
            %ADDLINE Plot a line or markers on the map
            line = plotm(lat, lon, linespec, varargin{:}, Parent=obj.ax);
            line.ButtonDownFcn = '';  % disable default binding to uimaptbx
        end

        function [new_lat, new_lon] = CleanLatLon(~, lat, lon)
            %CLEANLATLON No cleaning necessary on 3D plots, so do nothing
            new_lat = lat;
            new_lon = lon;
        end

        function UpdateAgentStart(obj, ~, ~)
            %UPDATEAGENTSTART Update marker for agent start

            delete(obj.start)  % clear existing start marker
            obj.start = plotm(obj.agent.start_lat, obj.agent.start_lon, 'bo', Parent=obj.ax, MarkerSize=8, LineWidth=2);
            obj.start.ButtonDownFcn = '';  % disable default binding to uimaptbx

            drawnow;  % force figure to update immediately
        end

        function UpdateAgentGoal(obj, ~, ~)
            %UPDATEAGENTGOAL Update marker for agent goal

            delete(obj.goal)  % clear existing goal marker
            obj.goal = plotm(obj.agent.goal_lat, obj.agent.goal_lon, 'go', Parent=obj.ax, MarkerSize=8, LineWidth=2);
            obj.goal.ButtonDownFcn = '';  % disable default binding to uimaptbx

            drawnow;  % force figure to update immediately
        end

        function UpdateAgentTrajectory(obj, ~, ~)
            %UPDATEAGENTTRAJECTORY Update plots/markers of agent trajectory and current position

            % coords are cleaned up here since otherwise the 2D plot would
            % draw the trajectory off screen when longitude is outside
            % [-180, 180] (3D plot does not need this correction)
            [new_lat, new_lon] = obj.CleanLatLon(obj.agent.trajectory_lat, obj.agent.trajectory_lon);

            delete(obj.trajectory)  % clear existing trajectory
            obj.trajectory = plotm(new_lat, new_lon, '-', Parent=obj.ax, LineWidth=2, Color='m', Marker='none', MarkerSize=2);
            obj.trajectory.ButtonDownFcn = '';  % disable default binding to uimaptbx

            delete(obj.position)  % clear existing position marker
            obj.position = plotm(new_lat(end), new_lon(end), 'mo', Parent=obj.ax, MarkerSize=8, LineWidth=2);
            obj.position.ButtonDownFcn = '';  % disable default binding to uimaptbx

            drawnow;  % force figure to update immediately
        end

        function SetSurfaceMesh(obj, surface_mesh_type)
            %SETSURFACEMESH ...

            delete(obj.surface_mesh);
            obj.surface_mesh_type = surface_mesh_type;
            switch obj.surface_mesh_type
                case "terrain"
                    % plot an opaque terrain mesh
                    load("topo60c.mat", "topo60c", "topo60cR");
                    Z = zeros(obj.R.RasterSize);
                    obj.surface_mesh(1) = meshm(Z, obj.R, Parent=obj.ax, FaceColor='w');  % first plot an opaque white mesh
                    obj.surface_mesh(2) = geoshow(topo60c, topo60cR, Parent=obj.ax, DisplayType="texturemap", FaceAlpha=0.6);  % second plot the terrain mesh, made transparent to lighten the colors
                    obj.surface_mesh(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                    obj.surface_mesh(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
                    [cm, cl] = demcmap(topo60c);
                    colormap(obj.ax, cm);
                    clim(obj.ax, cl);
                    obj.coastline_plot.Color = 'b';
            
                case "orthogonality"
                    % plot orthogonality as a color map
                    obj.CalculateOrthogonality();
                    obj.surface_mesh = meshm(obj.orthogonality, obj.R, Parent=obj.ax);
                    obj.surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                    colormap(obj.ax, "default");
                    clim(obj.ax, "auto");
                    obj.coastline_plot.Color = 'w';

                case "stability"
                    % plot goal stability as a color map
                    obj.surface_mesh = obj.DrawStabilityMesh();
                    addlistener(obj.agent, "GoalChanged", @obj.DrawStabilityMesh);
                    addlistener(obj.agent, "NavigationChanged", @obj.DrawStabilityMesh);
                    obj.coastline_plot.Color = 'b';
            end
        end

        function SetVectorField(obj, vector_field_type)
            %SETVECTORFIELD ...

            % temporarily change the axesm-based map's parent to a hidden figure
            % - this is necessary when the original parent is a
            %   uifigure/uipanel because quiverm does not support drawing
            %   to anything other than a figure (unlike plotm, meshm, etc.,
            %   which work as long as Parent is passed as a param)
            parent = obj.ax.Parent;
            tempf = figure(Visible='off');
            obj.ax.Parent = tempf;

            obj.vector_field_type = vector_field_type;
            switch obj.vector_field_type
                case "none"
                    % clear the vector field
                    try
                        delete(obj.vector_field);
                    catch
                        % do nothing if already deleted
                    end

                case "flow"
                    % plot arrows showing the paths that the agent would take
                    obj.DrawPerceivedDirectionVectorFieldPlot();
                    addlistener(obj.agent, "GoalChanged", @obj.DrawPerceivedDirectionVectorFieldPlot);
                    addlistener(obj.agent, "NavigationChanged", @obj.DrawPerceivedDirectionVectorFieldPlot);

                case "gradients"
                    % plot two sets of arrows showing the gradients of the inclination and intensity
                    obj.DrawIFGradients();
            end

            % restore the original parent of the axesm-based map
            obj.ax.Parent = parent;
            delete(tempf);
        end

        function CalculateOrthogonality(obj)
            %CALCULATEORTHOGONALITY ...
            obj.orthogonality = nan(obj.R.RasterSize);
            for i = 1:length(obj.magmodel.sample_latitudes)
                for j = 1:length(obj.magmodel.sample_longitudes)
                    dI = [obj.dlatI(i, j); obj.dlonI(i, j)];
                    dF = [obj.dlatF(i, j); obj.dlonF(i, j)];
                    angle = acosd(dot(dI, dF)/(norm(dI) * norm(dF)));
                    if angle > 90
                        % result will be between 0 and 90 degrees
                        angle = 180 - angle;
                    end
                    obj.orthogonality(i, j) = angle;
                end
            end
        end

        function CalculateStability(obj)
            %CALCULATESTABILITY ...

            obj.stability = nan(obj.R.RasterSize);
            for i = 1:length(obj.magmodel.sample_latitudes)
                for j = 1:length(obj.magmodel.sample_longitudes)
                    jacobian = -obj.agent.A * [obj.dlonF(i, j)/100, obj.dlatF(i, j)/100; obj.dlonI(i, j), obj.dlatI(i, j)];  % divide dF by 100 because of agent's perceived direction scaling
                    ev = eig(jacobian);
                    evreal = real(ev);
                    evimag = imag(ev);
                    tol = 1e-10;
                    is_unstable = evreal(1) > tol || evreal(2) > tol;
                    is_neutrally_stable = abs(evreal(1)) < 0 && abs(evreal(2)) < 0;
                    has_rotation = abs(evimag(1)) > tol || abs(evimag(2)) > tol;
                    if is_unstable
                        % at least one eigenvalue real-part is positive: unstable (repelling)
                        if has_rotation
                            % spiral source
                            obj.stability(i,j) = 0.75;  % light green with summer colormap
                        else
                            % unstable node
                            obj.stability(i, j) = 1;  % yellow with summer colormap
                        end
                    else
                        % both eigenvalue real-parts are non-positive: stable (attracting) or neutrally stable
                        if is_neutrally_stable
                            % both eigenvalue real-parts are zero (or very close): neutrally stable
                            obj.stability(i, j) = 0.5;
                        else
                            % both eigenvalue real-parts are positive: stable (attracting)
                            if has_rotation
                                % spiral sink
                                obj.stability(i,j) = 0.25;  % medium green with summer colormap
                            else
                                % stable node
                                obj.stability(i, j) = 0;  % dark green with summer colormap
                            end
                        end
                    end
                end
            end
        end

        function surface_mesh = DrawStabilityMesh(obj, ~, ~)
            %DRAWSTABILITYMESH ...

            if obj.surface_mesh_type == "stability"
                obj.CalculateStability();
                surface_mesh = meshm(obj.stability, obj.R, Parent=obj.ax);
                surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                colormap(obj.ax, "summer");
                clim(obj.ax, "auto");
                % if obj.projection ~= "globe"
                %     alpha(surface_mesh, 0.3);
                % end
            end
        end

        function DrawPerceivedDirectionVectorFieldPlot(obj, ~, ~)
            %...
        
            if obj.vector_field_type == "flow"
                try
                    delete(obj.vector_field);
                catch
                    % do nothing if already deleted
                end

                goal_I = obj.agent.goal_I_INCL;
                goal_F = obj.agent.goal_F_TOTAL;
            
                dlat = nan(obj.R.RasterSize);
                dlon = nan(obj.R.RasterSize);
            
                for i = 1:length(obj.magmodel.sample_latitudes)
                    for j = 1:length(obj.magmodel.sample_longitudes)
                        I = obj.magmodel.samples.I_INCL(i, j);
                        F = obj.magmodel.samples.F_TOTAL(i, j);
                        perceived_dir = obj.agent.ComputeDirection(goal_I, goal_F, I, F);
                        dlon(i, j) = perceived_dir(1);
                        dlat(i, j) = perceived_dir(2);
                    end
                end
            
                obj.vector_field = quiverm(obj.lat, obj.lon, dlat, dlon);
                color = "#444444";
                obj.vector_field(1).Color = color;
                obj.vector_field(2).Color = color;
                obj.vector_field(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                obj.vector_field(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
            end
        end

        function DrawIFGradients(obj)
            %...

            if obj.vector_field_type == "gradients"
                try
                    delete(obj.vector_field);
                catch
                    % do nothing if already deleted
                end

                % draw inclination gradient
                h = quiverm(obj.lat, obj.lon, obj.dlatI, obj.dlonI);
                color = "#EEEEEE";
                h(1).Color = color;
                h(2).Color = color;
                h(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                h(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
                obj.vector_field(1) = h(1);
                obj.vector_field(2) = h(2);
    
                % draw intensity gradient
                h = quiverm(obj.lat, obj.lon, obj.dlatF, obj.dlonF);
                color = "#444444";
                h(1).Color = color;
                h(2).Color = color;
                h(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
                h(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
                obj.vector_field(3) = h(1);
                obj.vector_field(4) = h(2);
            end
        end

        % function q = DrawInclinationGradient(obj)
        %     %...
        % 
        %     % delete(q)  % clear existing quiver plot
        %     q = quiverm(obj.lat, obj.lon, obj.dlatI, obj.dlonI);
        %     color = "#EEEEEE";
        %     q(1).Color = color;
        %     q(2).Color = color;
        %     q(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
        %     q(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
        % end
        % 
        % function q = DrawIntensityGradient(obj)        
        %     %...
        % 
        %     % delete(q)  % clear existing quiver plot
        %     q = quiverm(obj.lat, obj.lon, obj.dlatF, obj.dlonF);
        %     color = "#444444";
        %     q(1).Color = color;
        %     q(2).Color = color;
        %     q(1).ButtonDownFcn = '';  % disable default binding to uimaptbx
        %     q(2).ButtonDownFcn = '';  % disable default binding to uimaptbx
        % end

        function Set3DCameraPosition(obj, lat, lon)
            %SET3DCAMERAPOSITION Move the 3D camera to a given coordinate

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

        function Center3DCameraOnAgent(obj)
            %CENTER3DCAMERAONAGENT Move the 3D camera to the latest agent position
            obj.Set3DCameraPosition(obj.agent.trajectory_lat(end), obj.agent.trajectory_lon(end));
        end
    end
end

