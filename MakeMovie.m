% Required add-ons (use MATLAB's Add-On Explorer to install):
%   - Aerospace Toolbox
%   - Mapping Toolbox
%   - getContourLineCoordinates (from MathWorks File Exchange)

%% SETUP

close all;
clear;

load_from_file = true;
if load_from_file && exist("magmodel.mat", "file")
    load("magmodel.mat");
else
    magmodel = MagneticModel();
    save("magmodel.mat", "magmodel");
end

agent = Agent(magmodel);

map = Axesm3DMagneticMap(magmodel, agent);
map.Center3DCameraOnAgent();

%% METHOD 1: EXPORTGRAPHICS (GIF)

agent.Reset();
% centerCameraOnTrajectory(agent, map);
centerCameraBetweenStartAndGoal(agent, map);
drawnow;

filename = "movie.gif";
exportgraphics(gcf, filename);

frames = 30;

for i = 1:frames
    agent.Step(10);
    % centerCameraOnTrajectory(agent, map);
    drawnow;
    exportgraphics(gcf, filename, Append=true);
end

%% METHOD 2: WRITEVIDEO (AVI)

agent.Reset();
% centerCameraOnTrajectory(agent, map);
centerCameraBetweenStartAndGoal(agent, map);
drawnow;

filename = "movie.avi";

frames = 30;
clear M;
M(frames) = struct(cdata=[], colormap=[]);

for i = 1:frames
    agent.Step(10);
    % centerCameraOnTrajectory(agent, map);
    drawnow;
    M(i) = getframe;
end

% % show the movie in matlab now
% figure(2);
% movie(M);

v = VideoWriter("movie.avi");
open(v);
writeVideo(v, M);
close(v);

%% HELPER FUNCTIONS

function centerCameraBetweenStartAndGoal(agent, map)
    clat = mean([agent.start_lat, agent.goal_lat]);
    clon = mean([agent.start_lon, agent.goal_lon]);
    map.Set3DCameraPosition(clat, clon);
end

% function centerCameraOnTrajectory(agent, map)
%     clat = mean(agent.trajectory_lat);
%     clon = mean(agent.trajectory_lon);
%     map.Set3DCameraPosition(clat, clon);
% end
