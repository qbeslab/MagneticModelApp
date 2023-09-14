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
            % obj.projection = "robinson";
            % obj.projection = "mercator";

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

            % hold(obj.ax);

            % move the camera to the origin
            obj.Set3DCameraPosition(0, 0);

            % transfer parenthood of the axesm-based map to the specified parent
            obj.ax.Parent = parent;
            delete(tempf);

            load("coastlines", "coastlat", "coastlon");
            obj.coastline_plot = obj.AddLine(coastlat, coastlon, 'b', Tag="Coastlines", ZOrder=1);
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

            obj.SetVectorField("none");
            % obj.SetVectorField("flow");
            % obj.SetVectorField("gradients");

            addlistener(obj.agent, "NavigationChanged", @obj.DrawStabilityMesh);
            addlistener(obj.agent, "NavigationChanged", @obj.DrawFlowVectorFieldPlot);
            addlistener(obj.agent, "GoalChanged", @obj.DrawFlowVectorFieldPlot);
        end

        function line = AddLine(obj, lat, lon, linespec, varargin)
            %ADDLINE Plot a line or markers on the map
            [zorder, varargin] = obj.PopArg(varargin, "ZOrder", 1);
            line = plotm(lat, lon, linespec, varargin{:}, Parent=obj.ax);
            line.UserData.ZOrder = zorder;  % used for graphics layering
            line.ButtonDownFcn = '';  % disable default binding to uimaptbx
        end

        function [new_lat, new_lon] = CleanLatLon(~, lat, lon)
            %CLEANLATLON No cleaning necessary on 3D plots, so do nothing
            new_lat = lat;
            new_lon = lon;
        end

        function UpdateAgentStart(obj, ~, ~)
            %UPDATEAGENTSTART Update marker for agent start

            delete(obj.start);  % clear existing start marker
            obj.start = obj.AddLine(obj.agent.start_lat, obj.agent.start_lon, 'bo', Tag="Agent Start", MarkerSize=8, LineWidth=2, ZOrder=11);
            obj.start.ButtonDownFcn = '';  % disable default binding to uimaptbx

            % update graphics layering
            obj.SortZStack();
        end

        function UpdateAgentGoal(obj, ~, ~)
            %UPDATEAGENTGOAL Update marker for agent goal

            delete(obj.goal);  % clear existing goal marker
            obj.goal = obj.AddLine(obj.agent.goal_lat, obj.agent.goal_lon, 'go', Tag="Agent Goal", MarkerSize=8, LineWidth=2, ZOrder=12);
            obj.goal.ButtonDownFcn = '';  % disable default binding to uimaptbx

            % update graphics layering
            obj.SortZStack();
        end

        function UpdateAgentTrajectory(obj, ~, ~)
            %UPDATEAGENTTRAJECTORY Update plots/markers of agent trajectory and current position

            % coords are cleaned up here since otherwise the 2D plot would
            % draw the trajectory off screen when longitude is outside
            % [-180, 180] (3D plot does not need this correction)
            [new_lat, new_lon] = obj.CleanLatLon(obj.agent.trajectory_lat, obj.agent.trajectory_lon);

            delete(obj.trajectory);  % clear existing trajectory
            obj.trajectory = obj.AddLine(new_lat, new_lon, '-', Tag="Agent Trajectory", LineWidth=2, Color='m', Marker='none', MarkerSize=2, ZOrder=10);
            obj.trajectory.ButtonDownFcn = '';  % disable default binding to uimaptbx

            delete(obj.position);  % clear existing position marker
            obj.position = obj.AddLine(new_lat(end), new_lon(end), 'mo', Tag="Agent Position", MarkerSize=8, LineWidth=2, ZOrder=13);
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
                    % plot a terrain mesh
                    load("topo60c.mat", "topo60c", "topo60cR");
                    obj.surface_mesh = geoshow(topo60c, topo60cR, Parent=obj.ax, Tag="Terrain", DisplayType="texturemap");
                    obj.surface_mesh.UserData.ZOrder = 0;
                    obj.surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                    [cm, cl] = demcmap(topo60c);
                    cm = 1 - (1 - cm) * 0.5;  % lighten the colormap
                    colormap(obj.ax, cm);
                    clim(obj.ax, cl);
                    obj.coastline_plot.Color = 'w';

                    % update graphics layering
                    obj.SortZStack();
            
                case "orthogonality"
                    % plot orthogonality as a color map
                    obj.CalculateOrthogonality();
                    obj.surface_mesh = meshm(obj.orthogonality, obj.R, Parent=obj.ax, Tag="Orthogonality");
                    obj.surface_mesh.UserData.ZOrder = 0;
                    obj.surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                    colormap(obj.ax, "default");
                    clim(obj.ax, "auto");
                    obj.coastline_plot.Color = 'w';

                    % update graphics layering
                    obj.SortZStack();

                case "stability"
                    % plot goal stability as a color map
                    obj.DrawStabilityMesh();
                    obj.coastline_plot.Color = 'b';
            end
        end

        function SetVectorField(obj, vector_field_type)
            %SETVECTORFIELD ...

            obj.vector_field_type = vector_field_type;
            switch obj.vector_field_type
                case "none"
                    % clear the vector field
                    delete(obj.vector_field);

                case "flow"
                    % plot arrows showing the paths that the agent would take
                    obj.DrawFlowVectorFieldPlot();

                case "gradients"
                    % plot two sets of arrows showing the gradients of the inclination and intensity
                    obj.DrawIFGradients();
            end
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
                    jacobian = -obj.agent.A * [obj.dlonF(i, j), obj.dlatF(i, j);
                                               obj.dlonI(i, j), obj.dlatI(i, j)];
                    ev = eig(jacobian);
                    evreal = real(ev);
                    evimag = imag(ev);
                    tol = 1e-6;
                    is_unstable = evreal(1) > tol || evreal(2) > tol;
                    is_neutrally_stable = abs(evreal(1)) < tol || abs(evreal(2)) < tol;
                    has_rotation = abs(evimag(1)) > tol || abs(evimag(2)) > tol;

                    % % check analytical form of jacobian eigenvalues
                    % a = obj.agent.A(1, 1);
                    % b = obj.agent.A(1, 2);
                    % c = obj.agent.A(2, 1);
                    % d = obj.agent.A(2, 2);
                    % dFdx = obj.dlonF(i, j);
                    % dFdy = obj.dlatF(i, j);
                    % dIdx = obj.dlonI(i, j);
                    % dIdy = obj.dlatI(i, j);
                    % trJ = -(a * dFdx + b * dIdx + c * dFdy + d * dIdy);
                    % detJ = (a * d - b * c) * (dFdx * dIdy - dFdy * dIdx);
                    % ev2 = [(trJ - sqrt(trJ^2 - 4 * detJ)) / 2;
                    %        (trJ + sqrt(trJ^2 - 4 * detJ)) / 2];
                    % is_unstable2 = trJ > tol || detJ < -tol;
                    % is_neutrally_stable2 = abs(detJ) < tol;
                    % has_rotation2 = trJ^2 < 4 * detJ;
                    % if norm(sort(ev) - sort(ev2)) > 1e-10
                    %     disp("significant deviation found:");
                    %     disp([i, j]);
                    %     disp([sort(ev), sort(ev2)]);
                    %     disp(norm(sort(ev) - sort(ev2)));
                    % end
                    % if is_unstable ~= is_unstable2
                    %     disp("disagreement about stability found:");
                    %     disp([i, j]);
                    %     disp([sort(ev), sort(ev2)]);
                    %     disp([is_unstable, is_unstable2]);
                    %     disp([trJ, detJ]);
                    % end
                    % if is_neutrally_stable ~= is_neutrally_stable2
                    %     disp("disagreement about neutral stability found:");
                    %     disp([i, j]);
                    %     disp([sort(ev), sort(ev2)]);
                    %     disp([is_neutrally_stable, is_neutrally_stable2]);
                    % end
                    % if has_rotation ~= has_rotation2
                    %     disp("disagreement about rotation found:");
                    %     disp([i, j]);
                    %     disp([sort(ev), sort(ev2)]);
                    %     disp([has_rotation, has_rotation2]);
                    % end

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
                            % at least one eigenvalue real-part is zero (or very close): neutrally stable
                            obj.stability(i, j) = 0.5;
                        else
                            % both eigenvalue real-parts are negative: stable (attracting)
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

        function DrawStabilityMesh(obj, ~, ~)
            %DRAWSTABILITYMESH ...

            if obj.surface_mesh_type == "stability"
                obj.CalculateStability();
                delete(obj.surface_mesh);
                obj.surface_mesh = meshm(obj.stability, obj.R, Parent=obj.ax, Tag="Stability");
                obj.surface_mesh.UserData.ZOrder = 0;
                obj.surface_mesh.ButtonDownFcn = '';  % disable default binding to uimaptbx
                colormap(obj.ax, "summer");
                clim(obj.ax, "auto");
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

                delete(obj.vector_field);

                goal_I = obj.agent.goal_I_INCL;
                goal_F = obj.agent.goal_F_TOTAL;
            
                dlat = nan(obj.R.RasterSize);
                dlon = nan(obj.R.RasterSize);
            
                for i = 1:length(obj.magmodel.sample_latitudes)
                    for j = 1:length(obj.magmodel.sample_longitudes)
                        I = obj.magmodel.samples.I_INCL(i, j);
                        F = obj.magmodel.samples.F_TOTAL(i, j);
                        velocity = obj.agent.ComputeVelocity(goal_I, goal_F, I, F);
                        dlon(i, j) = velocity(1);
                        dlat(i, j) = velocity(2);
                    end
                end
            
                obj.vector_field = quiverm(obj.lat, obj.lon, dlat, dlon);
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

                delete(obj.vector_field);

                % by scaling the gradients manually and passing 0 to
                % quiverm's scale parameter, we ensures inclination and
                % intensity gradients are on an identical custom scale
                scale = 0.5;

                % draw inclination gradient
                h = quiverm(obj.lat, obj.lon, obj.dlatI * scale, obj.dlonI * scale, '-', 0);
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
                h = quiverm(obj.lat, obj.lon, obj.dlatF * scale, obj.dlonF * scale, '-', 0);
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

