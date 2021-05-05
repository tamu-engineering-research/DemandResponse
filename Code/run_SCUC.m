clear; clc; close all;

MAIN_OPTION = 'SCUC';

define_constants;
casepath = './';
warning('using the quadratic cost case')
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

nbus = size(mpc.bus,1); nl = size(mpc.branch, 1); ng = size(mpc.gen, 1);
nt = 24; na = 8; 

mpopt = mpoption('out.all',0);
mpopt = mpoption(mpopt,'verbose',3); % to see the intermediate output of GUROBI
mpopt = mpoption(mpopt, 'gurobi.threads', 64);
mpopt = mpoption(mpopt, 'gurobi.opts.timeLimit', 10*60*60); % time-limit = 10*60 minutes
mpopt = mpoption(mpopt,'most.dc_model', 1); % consider DC line flow constraints
mpopt = mpoption(mpopt, 'gurobi.opts.MIPGap', 1e-3); % gap <= 0.1%
mpopt = mpoption(mpopt, 'gurobi.opts.MIPGapAbs', 0);
mpopt = mpoption(mpopt,'gurobi.method',1);
mpopt = mpoption(mpopt, 'most.skip_prices', 0); % must have price computation for UC
mpopt = mpoption(mpopt,'most.uc.run',1); 
result_folder = './SCUC-Results/';

init = [];
start_day = 1; end_day = 365;
for day = start_day:end_day
    disp(['running ',MAIN_OPTION,' for day ',num2str(day)]);
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
    init.commit = mdo.UC.CommitSched(:,end);
    init.dispatch = mdo.results.ExpectedDispatch(:,end);

    assert( (mdo.QP.exitflag == 1) || (mdo.QP.exitflag == -13) ); % successfully solved

    save([result_folder,'24h-',MAIN_OPTION,'-results-day-',num2str(day),'.mat'],'mdo','ms');

end
    
