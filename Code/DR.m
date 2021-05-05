function [Best_mdo, Best_ms, dr] = DR(mdo, xgd, wind_pen, solar_pen, hydro_pen, init, mpopt, day, hour, DR_index, dr)

define_constants;

mpc = mdo.mpc;
nb = size(mpc.bus, 1); nl = size(mpc.branch, 1); ng = size(mpc.gen, 1);
nt = 24;

start_day = 1; end_day = 365;
start_hour = 1+(start_day-1)*nt; end_hour = end_day*nt;
NumSearchSpace = 20;
nDRb = dr.nDRb;
DR_condition = dr.original_LMPs(DR_index);
original_LMPs = dr.original_LMPs;

%% Obtain original_demand
for time = 1:length(DR_index)
    DR_hour = DR_index(time);
    original_demand = mdo.flow(DR_hour).mpc.bus(:,PD);
    %DR_hour(time) = DR_index(time);
    %original_demand_hour(time,:) = mdo.flow(time).mpc.bus(:,PD);
end

%% Obtain all demand in the library
load('nodal_load_hourly.mat');
for hour = start_hour:end_hour
    DR_distance(hour,:) = [hour,sum(abs(original_demand - nodal_load_hourly(hour,:)'))];
end

%% Sort out L1 distance vector in ascending order
sorted_distance = sortrows(DR_distance,2);

SearchSpaceHistory = zeros(NumSearchSpace,(2+nDRb));
%% Using the ascending order vector, solve rundcopf again
%% until it matches a termination condition for DR market

mdo_all = [];
ms_all = [];
reduced_MW_all = zeros(NumSearchSpace,nDRb);
DR_Bus_I_all = zeros(NumSearchSpace,nDRb);
DR_success = 0;
for hour = 1:NumSearchSpace
    hour_index = sorted_distance(hour,1);   % get index of hour
    comparing_hour_demand = nodal_load_hourly(hour_index,:)';

    diff = [mpc.bus(:,BUS_I), abs(original_demand - comparing_hour_demand)]; % [bus_index, demand_diff]
    sorted_diff = sortrows(diff,2);     % Sort by Column 2 (which is demand diff)
    sorted_diff = flipud(sorted_diff);  % Sort in descending order
    DR_BUS_I = sorted_diff(1:nDRb,1);   % Find DR Buses which has largest differences in demand
    DR_BUS_I = sort(DR_BUS_I);

    % Iteratively increase DR reduction amount
    for k = 0.80:0.05:0.95
        reduced_original_demand = original_demand;
        reduced_original_demand(2000) = reduced_original_demand(2000)*0.8;
        reduced_original_demand(DR_BUS_I) = reduced_original_demand(DR_BUS_I) * k;

        % Place in the original nodal load instead of zonal load
        for time = 1:nt
            nodal_load(time,:) = mdo.flow(time).mpc.bus(:,PD);
        end

        % Replace reduced original load to DR_hour
        nodal_load(DR_hour,:) = reduced_original_demand';
        disp(['Solving Daily SCEDR day = ', num2str(day) , ', hour = ', num2str(DR_index),', Search History = ', num2str(hour) ,' with k = ', num2str(k)]);
        [mdo, ms] = daily_SCEDR(mpc, xgd, nodal_load, wind_pen, solar_pen, hydro_pen, init, mpopt);

        if mdo.QP.exitflag == 1
            LMPs_all = zeros(nb, nt);
            for t = 1:nt
                LMPs_all(:,t) = mdo.flow(t).mpc.bus(:,LAM_P);
            end

            LMP.avg = mean(LMPs_all,1);
            LMP.max = max(LMPs_all,[],1);
            LMP.min = min(LMPs_all,[],1);

            if LMP.avg(DR_index) < DR_condition
                DR_Bus_I_all(hour,:) = DR_BUS_I;
                reduced_MW_all(hour,:) = original_demand(DR_BUS_I) - reduced_original_demand(DR_BUS_I);
                Best_mdo = mdo;
                Best_ms = ms;
                SearchSpaceHistory(hour,1) = k;
                SearchSpaceHistory(hour,2) = sum(original_demand - reduced_original_demand);
                SearchSpaceHistory(hour,3:end) = DR_BUS_I;
                dr.DR_Indicator(DR_index) = 1;
            else
                break;
            end
        else
            break;
        end
    end
end

return
