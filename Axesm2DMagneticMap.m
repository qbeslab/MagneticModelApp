global agent latitudes longitudes lat lon samples dlatI dlonI dlatF dlonF projection stability q m start goal position trajectory;

% % very coarse
% latitudes = -82:8:82;
% longitudes = -180:16:180;

% % coarse
% latitudes = -86:4:86;
% longitudes = -180:8:180;

% % fine
% latitudes = -88:2:88;
% longitudes = -180:4:180;

% very fine
latitudes = -89:1:89;
longitudes = -180:2:180;

% % extremely fine
% latitudes = -89.5:0.5:89.5;
% longitudes = -180:1:180;

% % ultra fine
% latitudes = -89.75:0.25:89.75;
% longitudes = -180:0.5:180;

[lon, lat] = meshgrid(longitudes, latitudes);

s = nan(length(latitudes), length(longitudes));
samples = struct(I_INCL=s, F_TOTAL=s);

for i = 1:length(latitudes)
    for j = 1:length(longitudes)
        [~, ~, ~, ~, ~, I, F] = magmodel.EvaluateModel(latitudes(i), longitudes(j));
        samples.I_INCL (i, j) = I;
        samples.F_TOTAL(i, j) = F;
    end
end

[dlonI, dlatI] = gradient(samples.I_INCL);
[dlonF, dlatF] = gradient(samples.F_TOTAL);

orthogonality = nan(length(latitudes), length(longitudes));
for i = 1:length(latitudes)
    for j = 1:length(longitudes)
        dI = [dlatI(i, j); dlonI(i, j)];
        dF = [dlatF(i, j); dlonF(i, j)];
        angle = acosd(dot(dI, dF)/(norm(dI) * norm(dF)));
        if angle > 90
            % result will be between 0 and 90 degrees
            angle = 180 - angle;
        end
        orthogonality(i, j) = angle;
    end
end

fig = figure;
% ax = worldmap("world");
% projection = "robinson";
% projection = "mercator";
% projection = "ortho";  % 2D projection of 3D globe
projection = "globe";
ax = axesm( ...
    MapProjection=projection, ...
    Frame='on' ...
    ... Grid='on', ParallelLabel='on', MeridianLabel='on', ...
    ... MapLatLimit=[-80 80] ...
    );

load("coastlines");
p = plotm(coastlat, coastlon, 'b');
p.Clipping = 'off';  % prevent map clipping when zoomed in

% darken the background and hide some axes elements
fig.Color = 'k';
ax.Clipping = 'off';
ax.Visible = 'off';

if projection == "globe"
    % move the initial camera to the agent
    % camtargm(0, 0, 0);
    % camposm(0, 0, 1);
    camtargm(agent.trajectory_lat(end), agent.trajectory_lon(end), 0);
    camposm(agent.trajectory_lat(end), agent.trajectory_lon(end), 1);
end

% % plot an opaque terrain mesh
% R = georefpostings([-90, 90], [-180, 180], [180, 360]);
% Z = zeros(R.RasterSize);
% meshm(Z, R, FaceColor='w');  % first plot an opaque white mesh
% load("topo60c.mat");
% m = geoshow(topo60c, topo60cR, DisplayType="texturemap");  % second plot the terrain mesh
% demcmap(topo60c);
% alpha(m, 0.6);  % make the terrain mesh transparent the white mesh behind it to lighten the colors

% % plot orthogonality as a color map
% R = georefpostings([min(latitudes), max(latitudes)], [min(longitudes), max(longitudes)], [length(latitudes), length(longitudes)]);
% m = meshm(orthogonality, R);

% plot goal stability as a color map
DrawStabilityMesh();
addlistener(agent, "GoalChanged", @DrawStabilityMesh);
addlistener(agent, "NavigationChanged", @DrawStabilityMesh);

% plot inclination and intensity contours
DrawContours();

% plot inclination and intensity gradient vectors
% DrawInclinationGradient();
% DrawIntensityGradient();

% % plot perceived direction flow vectors
% q = DrawQuiverPlot();
% addlistener(agent, "GoalChanged", @DrawQuiverPlot);
% addlistener(agent, "NavigationChanged", @DrawQuiverPlot);

start = DrawStartMarker();
addlistener(agent, "StartChanged", @DrawStartMarker);

goal = DrawGoalMarker();
addlistener(agent, "GoalChanged", @DrawGoalMarker);

position = DrawPositionMarker();
addlistener(agent, "TrajectoryChanged", @DrawPositionMarker);

trajectory = DrawTrajectory();
addlistener(agent, "TrajectoryChanged", @DrawTrajectory);

function q = DrawQuiverPlot(~, ~)
    global agent latitudes longitudes lat lon samples q;

    goal_I = agent.goal_I_INCL;
    goal_F = agent.goal_F_TOTAL;

    dlat = nan(size(lat));
    dlon = nan(size(lon));

    for i = 1:length(latitudes)
        for j = 1:length(longitudes)
            I = samples.I_INCL(i, j);
            F = samples.F_TOTAL(i, j);
            perceived_dir = agent.ComputeDirection(goal_I, goal_F, I, F);
            dlon(i, j) = perceived_dir(1);
            dlat(i, j) = perceived_dir(2);
        end
    end

    delete(q)  % clear existing quiver plot
    q = quiverm(lat, lon, dlat, dlon);
    color = "#444444";
    q(1).Color = color;
    q(2).Color = color;
    q(1).Clipping = 'off';  % prevent arrow clipping when zoomed in
    q(2).Clipping = 'off';  % prevent arrow clipping when zoomed in
end

function start = DrawStartMarker(~, ~)
    global agent start;

    delete(start)  % clear existing start marker
    start = plotm(agent.start_lat, agent.start_lon, 'bo', MarkerSize=8, LineWidth=2);
    start.Clipping = 'off';
end

function goal = DrawGoalMarker(~, ~)
    global agent goal;

    delete(goal)  % clear existing goal marker
    goal = plotm(agent.goal_lat, agent.goal_lon, 'go', MarkerSize=8, LineWidth=2);
    goal.Clipping = 'off';
end

function position = DrawPositionMarker(~, ~)
    global agent position;

    delete(position)  % clear existing position marker
    position = plotm(agent.trajectory_lat(end), agent.trajectory_lon(end), 'mo', MarkerSize=8, LineWidth=2);
    position.Clipping = 'off';
end

function trajectory = DrawTrajectory(~, ~)
    global agent trajectory;

    delete(trajectory)  % clear existing trajectory
    trajectory = plotm(agent.trajectory_lat, agent.trajectory_lon, '-', LineWidth=2, Color='m', Marker='none', MarkerSize=2);
    trajectory.Clipping = 'off';
end

function DrawContours()
    global magmodel;

    % interpm_maxdiff = 0.1;  % degrees (or nan to skip contour interpolation)
    interpm_maxdiff = nan;  % degrees (or nan to skip contour interpolation)

    % add contours
    for param = ["I_INCL", "F_TOTAL"]
        contour_table = magmodel.contour_tables.(param);
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
            line = plotm( ...
                contour_lat, contour_lon, ...
                '-', LineWidth=linewidth, Color=color, ...
                Tag=tag, UserData=datatipvalues ...
                );
            line.Clipping = 'off';
            if isprop(line, "DataTipTemplate")
                % add tooltips if the axes support them
                line.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow(datatiplabel, 'UserData', datatipformat);
            end
        end
    end
end

function q = DrawInclinationGradient()
    global lat lon dlatI dlonI q;

    % delete(q)  % clear existing quiver plot
    q = quiverm(lat, lon, dlatI, dlonI);
    color = "#EEEEEE";
    q(1).Color = color;
    q(2).Color = color;
    q(1).Clipping = 'off';  % prevent arrow clipping when zoomed in
    q(2).Clipping = 'off';  % prevent arrow clipping when zoomed in
end

function q = DrawIntensityGradient()
    global lat lon dlatF dlonF q;

    % delete(q)  % clear existing quiver plot
    q = quiverm(lat, lon, dlatF, dlonF);
    color = "#444444";
    q(1).Color = color;
    q(2).Color = color;
    q(1).Clipping = 'off';  % prevent arrow clipping when zoomed in
    q(2).Clipping = 'off';  % prevent arrow clipping when zoomed in
end

function m = DrawStabilityMesh(~, ~)
    global agent projection latitudes longitudes dlatI dlonI dlatF dlonF stability m;

    stability = nan(length(latitudes), length(longitudes));
    for i = 1:length(latitudes)
        for j = 1:length(longitudes)
            jacobian = -agent.A * [dlonI(i, j), dlatI(i, j); dlonF(i, j)/100, dlatF(i, j)/100];  % divide dF by 100 because of agent's perceived direction scaling
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
                    stability(i,j) = 0.75;  % light green with summer colormap
                else
                    % unstable node
                    stability(i, j) = 1;  % yellow with summer colormap
                end
            else
                % both eigenvalue real-parts are non-positive: stable (attracting) or neutrally stable
                if is_neutrally_stable
                    % both eigenvalue real-parts are zero (or very close): neutrally stable
                    stability(i, j) = 0.5;
                else
                    % both eigenvalue real-parts are positive: stable (attracting)
                    if has_rotation
                        % spiral sink
                        stability(i,j) = 0.25;  % medium green with summer colormap
                    else
                        % stable node
                        stability(i, j) = 0;  % dark green with summer colormap
                    end
                end
            end
        end
    end
    
    delete(m);  % clear existing mesh
    R = georefpostings([min(latitudes), max(latitudes)], [min(longitudes), max(longitudes)], [length(latitudes), length(longitudes)]);
    m = meshm(stability, R);
    m.Clipping = 'off';
    colormap("summer");
    % if projection ~= "globe"
    %     alpha(0.3);
    % end
end
