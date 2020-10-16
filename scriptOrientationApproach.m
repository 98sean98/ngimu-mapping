clc
clear
close all;

% import data
sessionData = importSession('TrackingSession');

time = sessionData.(sessionData.deviceNames{1}).matrix.time;
% acceleration = sessionData.(sessionData.deviceNames(1)).linear.vector;
rotMRaw = sessionData.(sessionData.deviceNames{1}).matrix.matrix;
frequency = 400; % Hz

sampleSize = length(time);

rotM = zeros(3, 3, sampleSize);

for index = 1 : sampleSize
  rotM(:, :, index) = rotMRaw(:, :, index)';
end

% use complementary filter to fuse accelerometer and gyroscope data to obtain rotation matrices

% remove first and last few seconds of data
timeCutoff = [5 5]; % cut off first few and last few seconds of data
rowIndexCutOff = [0 0];

for rowIndex = 1 : sampleSize
  if (time(rowIndex) < timeCutoff(1))
    rowIndexCutOff(1) = rowIndexCutOff(1) + 1;
  elseif (time(rowIndex) > (time(end) - timeCutoff(2)))
    rowIndexCutOff(2) = rowIndex;
    break;
  endif
end

for rowIndex = 1: rowIndexCutOff(1)
  time(1) = [];
  rotM(:, :, 1) = [];
end

for rowIndex = rowIndexCutOff(2): sampleSize
  time(end) = [];
  rotM(:, :, end) = [];
end

sampleSize = length(time);
for rowIndex = 1 : sampleSize
  time(rowIndex) = time(rowIndex) - timeCutoff(1);
end

% calculate discrete travel distance from linear acceleration
acceleration(1 : sampleSize, 1) = 0.01;
velocity = zeros(sampleSize);
t = 1 / frequency;

for index = 1 : sampleSize
  v1 = velocity(index);
  a = acceleration(index);
  v2 = v1 + a * t;
  
  if (index < sampleSize)
    velocity(index + 1) = v2;
  endif
end

distance = zeros(sampleSize);

for index = 1 : sampleSize
  v1 = velocity(index);
  
  if (index == sampleSize)
    v2 = 0;
  else
    v2 = velocity(index + 1);
  endif
  
  d = 0.5 * (v1 + v2) * t;
  
  if (d < 0)
    distance(index) = 0;
  else
    distance(index) = d;
  endif
end

% obtain rotation matrix for bias correction
stationaryRowIndexCutOff = 1000;
stationaryRotM = rotM(:, :, 1 : stationaryRowIndexCutOff);
meanStationaryRotM = mean(stationaryRotM, 3)
biasCorrectionRotM = inverse(meanStationaryRotM)

% use rotation matrices to propogate position data
position = zeros(sampleSize, 3);

for index = 1 : sampleSize
  p1 = position(index, :)';
  d = distance(index);
  
  R = rotM(:, :, index);
  
  aggregateRotM = biasCorrectionRotM * R;
  
  travelVector = aggregateRotM * [d 0 0]';
  
  p2 = p1 + travelVector;
  
  if (index < sampleSize)
    position(index + 1, :) = p2';
  endif
end

% flip position y-axis along y = 0
position(:, 2) = - position(:, 2);

% rotate position data from body frame to earth frame

% plot data
accelerationData = horzcat(acceleration, zeros(sampleSize, 2));
velocityData = horzcat(velocity, zeros(sampleSize, 2));
plotData(time, accelerationData, velocityData, position);