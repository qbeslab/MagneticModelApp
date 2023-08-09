global agent;

load("coastlines");
ax = worldmap("world");
p = plotm(coastlat, coastlon);
p.Clipping = 'off';  % prevent map clipping when zoomed in

DrawQuiverPlot();
addlistener(agent, 'GoalChanged', @DrawQuiverPlot);

function DrawQuiverPlot(~, ~)
    global magmodel agent q;

    % % very coarse
    % latitudes = -82:8:82;
    % longitudes = -180:16:180;

    % % coarse
    % latitudes = -86:4:86;
    % longitudes = -180:8:180;

    % fine
    latitudes = -88:2:88;
    longitudes = -180:4:180;

    % % very fine
    % latitudes = -89:1:89;
    % longitudes = -180:2:180;

    % % extremely fine
    % latitudes = -89.5:0.5:89.5;
    % longitudes = -180:1:180;

    goal_I = agent.goal_I_INCL;
    goal_F = agent.goal_F_TOTAL;

    [lon, lat] = meshgrid(longitudes, latitudes);
    dlat = nan(size(lat));
    dlon = nan(size(lon));

    for i = 1:length(latitudes)
        for j = 1:length(longitudes)
            [~, ~, ~, ~, ~, I, F] = magmodel.EvaluateModel(latitudes(i), longitudes(j));
            perceived_dir = agent.ComputeDirection(goal_I, goal_F, I, F);
            dlat(i, j) = perceived_dir(1);
            dlon(i, j) = perceived_dir(2);
        end
    end

    delete(q)  % clear existing quiver plot
    q = quiverm(lat,lon,dlat,dlon);
    q(1).Clipping = 'off';  % prevent arrow clipping when zoomed in
    q(2).Clipping = 'off';  % prevent arrow clipping when zoomed in
end
