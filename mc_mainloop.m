% set up an array for the photons, 
% x, y, z, roll, pitch, weight, received
% 0, 0, 0, 0   , 0    , 1     , 1
% 1, 2, 3, 4   , 5    , 6     , 7

% index from origin, 0 theta (angle between x and y), 0 phi (angle between
% x and z) along x-axis
clear all
clc
[cdf_scatter,angle] = generate_scatter(0.924);

num_photons = 1e6;
scattering_events = 15;
n_water = 1.33;                     % index of refraction of water

photon = zeros(num_photons,7);
photon(:,6) = ones(num_photons,1);  % set weights to one
photon(:,7) = ones(num_photons,1);  % set all active
totaldist = zeros(num_photons,1);   % record total distance traveled by each photon
rec_dist = zeros(num_photons,1);    % total distance photon traveld at point of reception
rec_loc = zeros(num_photons,2);     % location of the received photon on the z,y rec. plane
total_rec_packets = 0;              % Total number of packets to cross detector
total_rec_power = 0;                % Total power to cross detector


% c = 0.5;                            % attenuation coefficient in m^-1
% a = 0.07;                           % absorption coefficient in m^-1
% harbor water
c = 2.190;
a = 0.366;
% % coastal water
% c = 0.22 + 0.179;
% a = 0.179;
% % Clear water
% c = 0.0374 + 0.114;
% a = 0.114;

inv_c = 1/c;
inv_b = 1/(c-a);

i = 0;

h = waitbar(0.0,'Please wait...','CreateCancelBtn','stop=true; delete(h); clear h');  
set(h,'Name','optional window name');  

% receiver_x = 3;                     % X position of the receiver (in meters)
receiver_x = 9*inv_c;                     % X position of the receiver (in meters)

receiver_y = 0;                     % Y position of the receiver (in meters)
receiver_z = 0;                     % Z position of the receiver(in meters)
aperture = 0.1;                       % Diameter of aperture (in meters)
receiver_y_min = receiver_y - aperture/2;
receiver_y_max = receiver_y + aperture/2;
receiver_z_min = receiver_z - aperture/2;
receiver_z_max = receiver_z + aperture/2;
fov = pi/2;                           % Field of view (in radians)
half_fov = fov/2;
rec_radius = aperture / 2;

cp = receiver_x + (aperture/2)/tan(half_fov);    % point of receiver FOV 'cone' on the x-axis - different from focal point

init_angle = atan(receiver_y/receiver_x)       % Point transmitter at receiver
photon(:,4) = init_angle;
init_angle2 = atan(receiver_z/receiver_x)       % Point transmitter at receiver
photon(:,5) = init_angle2;


tic;

for j = 1:scattering_events
    rand_array = rand(num_photons,3);    % generate a matrix for each photon with rand propogation, roll, and pitch
                                            
    waitbar(j/scattering_events,h,['Scattering event ' num2str(j)]);  
    
    % iterate over every single photon to calculate new position and
    % whether it was received or not.
    for i = 1:num_photons
        
        % if photon hasn't been received
        if (photon(i,7) == 1)
        
             r = -inv_b*log(rand_array(i,1));     % randomly generate optical path length      

           %Generate scattering angle from beam spread function
           % Using the "find" command, the two lookups were taking 60% of
           % the processing time. Write my own lookup. 
%            theta = angle(find(rand_array(i,2) <= cdf_scatter,1));
            k = 1;
            while rand_array(i,2) > cdf_scatter(k)
                k = k+1;
            end
            theta = angle(k);

%             phi = angle(find(rand_array(i,3) <= cdf_scatter,1));
            k = 1;
            while rand_array(i,3) > cdf_scatter(k)
                k = k+1;
            end
            phi = angle(k);
           

    %         % Generate generic  spread
    %         theta = 0.25*pi*rand - 0.125*pi;
    %         phi = 0.25*pi*rand - 0.125*pi;

%             %No scattering
%             theta = 0;
%             phi = 0;

            % Optimize the cartesion coordinate calculation -
            % duplicate funtion calls
            % calculate new position of photon based on scattering length and
            % (previous) propagation direction
%             new_x = r*cos(photon(i,5) + phi)*cos(photon(i,4) + theta);
%             new_y = r*cos(photon(i,5) + phi)*sin(photon(i,4) + theta);
%             new_z = r*cos(photon(i,4) + theta)*sin(photon(i,5) + phi);

            % find new position based on PREVIOUS direction of motion. This
            % takes care of the initial condition problem where photons
            % were scattered immediately on the first iteration.
            new_x = r*cos(photon(i,5))*cos(photon(i,4));
            new_y = r*cos(photon(i,5))*sin(photon(i,4));
            new_z = r*cos(photon(i,4))*sin(photon(i,5));

       
            % if the photon is in the detectors FOV, has the correct
            % acceptance angle, and is to the left of it
            if (abs(atan((photon(i,2)-receiver_y)/(cp - photon(i,1)))) < half_fov ...
                    && abs(atan((photon(i,3)-receiver_z)/(cp - photon(i,1)))) < half_fov ...
                    && abs(photon(i,4)) <= half_fov ...
                    && abs(photon(i,5)) <= half_fov ...
                    && photon(i,1) <= receiver_x)

           
                % x distance to receiver plane
                x_dist_rec_intersection = receiver_x - photon(i,1);
                % y distance to receiver plane
                y_dist_rec_intersection = x_dist_rec_intersection*tan(photon(i,4));
                % z distance to receiver plane
                z_dist_rec_intersection = x_dist_rec_intersection*tan(photon(i,5));
              

                % euclidian distance to the reciever plane
                dist_to_rec = sqrt((x_dist_rec_intersection)^2 + (y_dist_rec_intersection)^2 + (z_dist_rec_intersection)^2);

                % if the movement vector intersects the receiver plane
                %if ((photon(i,1) > receiver_x) && (photon(i,2) - y_dist_rec_intersection) <= receiver_y_max) && (photon(i,2) - y_dist_rec_intersection >= receiver_y_min) && (photon(i,3) - z_dist_rec_intersection <= receiver_z_max) && (photon(i,3) - z_dist_rec_intersection >= receiver_z_min)
                if ((dist_to_rec < r)...
                        && (sqrt(((photon(i,3) + z_dist_rec_intersection) - receiver_z)^2 + ...
                        ((photon(i,2) + y_dist_rec_intersection) - receiver_y)^2) < rec_radius))
%                         && ((photon(i,2) + y_dist_rec_intersection) <= receiver_y_max)...   % can probably remove these conditions, since we already check the acceptance angle
%                         && ((photon(i,2) + y_dist_rec_intersection) >= receiver_y_min)...
%                         && ((photon(i,3) + z_dist_rec_intersection) <= receiver_z_max)...
%                         && ((photon(i,3) + z_dist_rec_intersection) >= receiver_z_min))
                    
                    rec_loc(i,1) = photon(i,2) + y_dist_rec_intersection;   % y-axis location of reception
                    rec_loc(i,2) = photon(i,3) + z_dist_rec_intersection;    % z-axis location of reception                    
                    
                    total_rec_packets = total_rec_packets + 1;
                    total_rec_power = total_rec_power + photon(i,6)*exp(-dist_to_rec*a);                    
                    rec_dist(i) = totaldist(i)+ dist_to_rec;
                    photon(i,7) = 0;
                    
                    % update the total distance the photon has traveled 
                    totaldist(i) = totaldist(i) + dist_to_rec;
                    
                else % if the photon didn't move into the detector, reduce its power & move it
                    photon(i,6) = photon(i,6)*exp(-r*a); 
                    % move to new x position
                    photon(i,1) = photon(i,1) + new_x;                                   
                    % move to new y position
                    photon(i,2) = photon(i,2) + new_y;                                 
                    % move to new z position
                    photon(i,3) = photon(i,3) + new_z;
                    
                    
                    % set new theta angle
                    photon(i,4) = photon(i,4) + theta;
                    % set new phi angle
                    photon(i,5) = photon(i,5) + phi;   
                
                    
                    % update the total distance the photon has traveled 
                    totaldist(i) = totaldist(i) + r;
                end

            else                % if the photon isn't in the receiver FOV cone
                % set new x position
                photon(i,1) = photon(i,1) + new_x;                                   
                % set new y position
                photon(i,2) = photon(i,2) + new_y;                                 
                % set new z position
                photon(i,3) = photon(i,3) + new_z;
                % update weight
                photon(i,6) = photon(i,6)*exp(-r*a);
                

                % set new theta angle
                photon(i,4) = photon(i,4) + theta;
                % set new phi angle
                photon(i,5) = photon(i,5) + phi;   
                
                
                % update the total distance the photon has traveled 
                totaldist(i) = totaldist(i) + r;
            end
        end
    end
%     figure(1)
%     subplot(3,3,j)
%     scatter(photon(:,1),photon(:,2),50,log10(photon(:,6)),'.')
%     xlim([-15 50]);
%     ylim([-25 25]);
% %     xlabel('x-axis (m)')
% %     xlabel('y-axis (m)')
end

total_time = toc;
minutes_to_run = total_time/60


rec_loc_final = ones(total_rec_packets,2);
j = 1;
for i = 1:num_photons
    if (photon(i,7) == 0)
       rec_loc_final(j,:) = rec_loc(i,:);
       j = j +1;
    end
end

figure(8)                   % plot 3D histogram of photons on RX plane
hist3(rec_loc_final)
set(gcf,'renderer','opengl');
set(get(gca,'child'),'FaceColor','interp','CDataMode','auto');

j = 1;
total_rec_dist = zeros(total_rec_packets,1);
for i = 1:num_photons
    
   if (photon(i,7) == 0)
       total_rec_dist(j) = totaldist(i);
       j = j + 1;       
   end
end

total_rec_power
total_rec_packets

close(h)

figure(10)                              % Plot histogram of time-of-arrival vs. power
[N,X] = hist(total_rec_dist,100);
pwr_rx_hist = N.*exp(-a.*X);
stem(X/(3e8/n_water),pwr_rx_hist/total_rec_power)   
xlabel('Time of arrival (sec)')
ylabel('Percentage of power')

distance_delta = max(X) - min(X);
time_delta = distance_delta/(3e8/n_water);
T = mean(X(2:end) - X(1:end-1))/(3e8/n_water); % Effective "sampling rate" of the histogram
bandwidth = 1/T;                                % Normalized frequency in Hz

 figure(7)
freqz(N/total_rec_packets,[1],512,bandwidth)      %% plot a frequency response from the histogram data

% figure(9)                           %% Scatter plot of photons on RX plane
% scatter(rec_loc(:,1),rec_loc(:,2))

% figure(1)
% scatter(photon(:,1),photon(:,2),50,log10(photon(:,6)),'.')
% xlim([-20 150]);
% ylim([-120 120]);
% xlabel('x-axis (m)')
% xlabel('y-axis (m)')
% 
% figure(4)
% scatter3(photon(:,1),photon(:,2),photon(:,3),50,log10(photon(:,6)),'.')

% % Draw the box representing the receiver
% line([receiver_x receiver_x],[receiver_y_min receiver_y_min],[receiver_z_max receiver_z_min],'LineWidth',4)   % |
% line([receiver_x receiver_x],[receiver_y_min receiver_y_max],[receiver_z_max receiver_z_max],'LineWidth',4)   % -
% line([receiver_x receiver_x],[receiver_y_max receiver_y_max],[receiver_z_max receiver_z_min],'LineWidth',4)   %  |
% line([receiver_x receiver_x],[receiver_y_min receiver_y_max],[receiver_z_min receiver_z_min],'LineWidth',4)   % _
% xlabel('x-axis (m)')
% ylabel('y-axis (m)')
% zlabel('z-axis (m)')

% figure(3);
% hist(photon(:,1),max(photon(:,1)));


% figure(2)
% hist(totaldist,20);
% figure(3)
% hist(photon(:,4),20)
findfigs

sprintf('Simulation on DATE with %d photons, %d scattering events.', num_photons, scattering_events)
sprintf('C = %d (1/m), A = %d (1/m). FOV = %d (radians). Aperture = %d (m).',c,a,fov,aperture)
sprintf('Receiver at %d, %d, %d (meters)',receiver_x, receiver_y, receiver_z)
sprintf('Travel distance delta %d (m). Time of arrival delta %d (sec)', distance_delta, time_delta)
sprintf('Time delta between histogram bins: %d (sec), %d (Hz)',T,bandwidth)