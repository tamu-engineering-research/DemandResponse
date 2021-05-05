clear; clc; close all;

MAIN_OPTION = 'SCEDR';

define_constants;
casepath = './';
warning('using the PWL cost case')
casename = 'case2000_PWL';

mpc = loadcase(casename);
xgd = loadxgendata('xgd_case2000', mpc);

warning('must set wind lower bounds = 0, otw infeasible');
mpc.gen(strcmp(mpc.genfuel,'wind'),PMIN) = 0;
warning('must set solar lower bounds = 0, otw infeasible');
mpc.gen(strcmp(mpc.genfuel,'solar'),PMIN) = 0;

demand = load('texas_2020_demand.mat');
hydro = load('texas_2020_hydro.mat');
wind = load('texas_2020_wind.mat');
solar = load('texas_2020_solar.mat');

nb = size(mpc.bus,1); nl = size(mpc.branch, 1); ng = size(mpc.gen, 1);
nt = 24; na = 8;

%% DR parameters
nDRb = 10; DR_condition = 100;

%% MatPower Options
mpopt = mpoption('out.all',0);
mpopt = mpoption(mpopt,'verbose',3); % to see the intermediate output of GUROBI
mpopt = mpoption(mpopt, 'gurobi.threads', 64);
mpopt = mpoption(mpopt, 'gurobi.opts.timeLimit',20*60*60); % time-limit = 60 minutes
mpopt = mpoption(mpopt,'most.dc_model', 1); % consider DC line flow constraints
mpopt = mpoption(mpopt,'most.uc.run',0); 
mpopt = mpoption(mpopt,'gurobi.method',1); % not using barrier, to avoid suboptimal solution
mpopt = mpoption(mpopt,'gurobi.opts.OptimalityTol',1e-5); % default value is 1e-9
mpopt = mpoption(mpopt,'gurobi.opts.BarConvTol',1e-5); % default value is 1e-9
mpopt = mpoption(mpopt,'gurobi.opts.IntFeasTol',1e-5); % default value is 1e-9

SCUC_result_folder = './SCUC-Results/';
SCED_result_folder = './SCED-Results/';
SCEDR_result_folder = './SCEDR-Results/';

init = [];

start_day = 1; end_day = 365;
for day = start_day:end_day
    disp(['running ',MAIN_OPTION,' for day ',num2str(day)]);

    load([SCUC_result_folder,'24h-SCUC-results-day-',num2str(day),'.mat']);
    CommitSched = mdo.UC.CommitSched;
    xgd.CommitSched = CommitSched;

    indices_t = (1:nt) + (day-1)*nt;
    area_load = demand.area_load(indices_t,:); % nt-by-na matrix

    iwind = find(strcmp(mpc.genfuel,'wind'));
    nwind = length(iwind);
    wind_pen = wind.wind_MW(indices_t,:);

    isolar = find(strcmp(mpc.genfuel,'solar'));
    nsolar = length(isolar);
    solar_pen = solar.solar_MW(indices_t,:);

    ihydro = find(strcmp(mpc.genfuel,'hydro'));
    nhydro = length(ihydro);
    hydro_pen = hydro.hydro_MW(indices_t,:);

    mpc_day = mpc;
    [mdo, ms] = daily_SCUD_SCED(mpc_day, xgd, area_load, wind_pen, solar_pen, hydro_pen, init, mpopt);

    assert( (mdo.QP.exitflag == 1) ); % stop if unsuccessful

    save([SCED_result_folder,'24h-SCED-results-day-',num2str(day),'.mat'],'mdo','ms');

    % Compute LMPs for DR market
    LMPs_all = zeros(nb, nt);
    for t = 1:nt
        LMPs_all(:,t) = mdo.flow(t).mpc.bus(:,LAM_P);
    end

    LMP.avg = mean(LMPs_all,1);
    LMP.max = max(LMPs_all,[],1);
    LMP.min = min(LMPs_all,[],1);
    original_LMPs = LMP.avg;

    % Build DR structure to add to mdo
    dr.DR_Indicator = zeros(24,1);
    dr.reduction = zeros(24,1);
    dr.reduced_MW = zeros(24,nDRb);
    dr.DR_BUS_I = zeros(24,nDRb);
    dr.original_LMPs = original_LMPs';
    dr.DR_condition = DR_condition;
    dr.nDRb = nDRb;

    DRHour = find(LMP.avg > DR_condition)
    if sum(LMP.avg > DR_condition) > 0
        for hour = 1:length(DRHour)
            disp(['Open DR Market day = ', num2str(day), ' and hour = ', num2str(DRHour(hour))]);
            [mdo, ms, dr] = DR(mdo, xgd, wind_pen, solar_pen, hydro_pen, init, mpopt, day, hour, DRHour(hour), dr);
        end
    end

    LMPs_all = zeros(nb, nt);
    for t = 1:nt
        LMPs_all(:,t) = mdo.flow(t).mpc.bus(:,LAM_P);
    end

    LMP2.avg = mean(LMPs_all,1);
    LMP2.max = max(LMPs_all,[],1);
    LMP2.min = min(LMPs_all,[],1);
    [LMP2.max;LMP.max]

    mdo.DR = dr;

    save([SCEDR_result_folder,'24h-SCEDR-results-day-',num2str(day),'.mat'],'mdo','ms');
    init.commit = mdo.UC.CommitSched(:,end);
    init.dispatch = mdo.results.ExpectedDispatch(:,end);
end
