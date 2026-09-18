close all; clear all;
% Read data
data_drop1 = readtable("PSCAD_auto_summary\Vdrop_10-06-26_1pu.csv");
data_drop2 = readtable("PSCAD_auto_summary\Vdrop_11-06-26_09pu.csv");
data_drop3 = readtable("PSCAD_auto_summary\Vdrop_12-06-26_11pu.csv");
% data_drop1 = readtable("PSCAD_auto_summary\Vdrop_15-07-26_1pu.csv");
% data_drop2 = readtable("PSCAD_auto_summary\Vdrop_16-07-26_09pu.csv");
% data_drop3 = readtable("PSCAD_auto_summary\Vdrop_17-07-26_11pu.csv");
data_drop = [data_drop1;data_drop2;data_drop3];

% Assign variable
P_rated_drop = data_drop{:,1};
Q_rated_drop = data_drop{:,2};
V_mag_rated_drop = data_drop{:,3};
V_theta_rated_drop = data_drop{:,4};
I_max_tail_drop = data_drop{:,5};
I_min_tail_drop = data_drop{:,6};
I_avg_tail_drop = data_drop{:,7};
Iphase_max_tail_drop = data_drop{:,8};
Iphase_min_tail_drop = data_drop{:,9};
Iphase_avg_tail_drop = data_drop{:,10};
I1_rms_tail_drop = data_drop{:,11};
I2_rms_tail_drop = data_drop{:,12};
I3_rms_tail_drop = data_drop{:,13};
V1_rms_tail_drop = data_drop{:,14};
V2_rms_tail_drop = data_drop{:,15};
V3_rms_tail_drop = data_drop{:,16};
V_avg_head = data_drop{:,17};
Vphase_avg_tail_drop = data_drop{:,18};
P_avg_tail_drop = data_drop{:,19};
Q_avg_tail_drop = data_drop{:,20};
V1_inv_tail_drop = data_drop{:,21};
V2_inv_tail_drop = data_drop{:,22};
V3_inv_tail_drop = data_drop{:,23};
I1_inv_tail_drop = data_drop{:,24};
I2_inv_tail_drop = data_drop{:,25};
I3_inv_tail_drop = data_drop{:,26};

% Calculation I and compared to measured I
% Define data and constants in pu
Sbase = 0.25; % MW
Fbase = 60; Wbase = 2*pi*Fbase; Fcr = Fbase*70;
Vdc = 1.4*0.5;
Vmax = 1.15;
Vmin = 0.2;
INVVbase = 0.65; % kV
INVVbase_LNpk = 0.65*sqrt(2)/sqrt(3);
INVZbase = INVVbase^2/Sbase;
INVLbase = INVZbase/(2*pi*Fbase);
Lbase = 0.2; % pu
Lfilter = INVLbase*0.5;
Cfilter_pu = Wbase*INVZbase/(Fcr*0.4*2*pi)^2/INVLbase/Lbase/0.5;
Freq_pll_pu = 1;
Vref = 1.05;
Kpq = 0.5; Kpp = 0.5; Kdrp = 30; DVS_gain = 0.25;

V1_inv_tail_drop = V1_inv_tail_drop.*sqrt(3)./INVVbase; % from line to ground to line-line in pu
Vprefault = V_avg_head./INVVbase;
Iphase_prefault = Vphase_avg_tail_drop;
Iphase_meas = wrapToPi(Iphase_avg_tail_drop);
Vfreeze = 0.8; % pu
cut_off = 0.3; % pu
Ibase = Sbase/INVVbase/sqrt(3); % kA
I1_inv_tail_drop = I1_inv_tail_drop./Ibase; % pu
I_max = 1.2; % pu
P_rated = P_rated_drop./100; % pu
Q_rated = Q_rated_drop./100; % pu
S_rated = (P_rated.^2 + Q_rated.^2).^0.5; % pu
P_calc = P_rated_drop./100; % pu
Q_calc = Q_rated_drop./100; % pu
Iprefault = S_rated./Vprefault;
Vfreeze_index = (V1_inv_tail_drop <= Vfreeze);

% Define P and Q below V_freeze
% Variables to fit: alpha
%P_rated(Vfreeze_index).*(V1_inv_tail_drop(Vfreeze_index)./Vprefault(Vfreeze_index)).^0.8;
modelP = @(x) P_rated(Vfreeze_index).*(V1_inv_tail_drop(Vfreeze_index)./Vprefault(Vfreeze_index)).^(x(1));
modelQ = @(x) (V1_inv_tail_drop(Vfreeze_index)./Vref.*Q_rated(Vfreeze_index) + ...
    V1_inv_tail_drop(Vfreeze_index).*((x(3)+x(4).*Q_rated(Vfreeze_index)).*(Vprefault(Vfreeze_index) - V1_inv_tail_drop(Vfreeze_index))));

modelP = @(x) P_rated(Vfreeze_index).*(V1_inv_tail_drop(Vfreeze_index)./Vprefault(Vfreeze_index)) + ...
    (x(1)+x(2).*P_rated(Vfreeze_index)).*Vprefault(Vfreeze_index).*V1_inv_tail_drop(Vfreeze_index);

% Calculate P and Q
modelI = @(x) min(I_max, (modelP(x).^2 + modelQ(x).^2).^0.5./(V1_inv_tail_drop(Vfreeze_index)));

% P_calc = modelP(0.8);
% Q_calc = modelP([0 0 0.25 0.175]);
% Iphase_calc = P_calc.*0 - 1/2*pi - pi/6;
% P_calc_0 = (P_calc ~= 0);
% Iphase_calc(P_calc_0) = wrapToPi(-1*atan2(Q_calc(P_calc_0),P_calc(P_calc_0)) - pi/6);
% w_V = @(x) max(min(((Vfreeze - V1_inv_tail_drop(Vfreeze_index))./(Vfreeze - 0.1)).^x(1),1),0);
% modelIphase = @(x) (1-w_V(x(1))).*Iphase_calc + w_V(x(1))*(-2*pi/3);

%cost = @(x) sum(((I_pu - modelI(x))).^2);
cost = @(x) sum(min((I_avg_tail_drop(Vfreeze_index) - modelI(x)).^2,0.1));
%cost = @(x) sum(min(sqrt((Iphase_meas(Vfreeze_index) - modelIphase(x)).^2),pi/6));

% Initial guess

% x0 = [0.04, 1.185, -0.108, 0.555, 0.034,...
%       0.04, 1.185, -0.108, 0.555, 0.034];
%x0 = [0.1, 0.1, 0.7, 0.5, 0.5, 0, 1]; % for P
%x0 = [0.1 , 0.05, 0.5, 1, 0.7, 0.1, 0.8, 0, 0, -0.02]; %for Q
x0 = [0.168, 0.125, 0.25, 0.175];

% Bounds
%lb = [-inf,-inf];
%ub = [inf, inf];

lb = [-inf,-inf,-inf,-inf,-inf,-inf, -inf, -inf];
ub = [inf,inf,inf,inf,inf,inf,inf, inf];

% Optimization settings
options = optimoptions('fmincon',...
    'Display','iter',...
    'MaxFunctionEvaluations',1e5,...
    'MaxIterations',5000);

% Solve
x_opt = fmincon(cost,x0,[],[],[],[],lb,ub,[],options);
x_opt

% modelP = @(x) (x(1).*P_calc(V_mag_freeze_index) + x(2)).*real((V1_inv_tail_drop(V_mag_freeze_index) + x(3)).^x(4)) + x(5);
% modelQ = @(x) ((Q_calc(V_mag_freeze_index) + x(1))./(x(2))).*real((V1_inv_tail_drop(V_mag_freeze_index) + x(3)).^x(4)) + x(5)*Q_calc(V_mag_freeze_index) + x(6);