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
Vfreeze_near = 0.6;
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
Vfreeze_near_index = (V1_inv_tail_drop <= Vfreeze) & (V1_inv_tail_drop >= Vfreeze_near);

% Define error function for P, Q in function of Vtheta
P_calc(Vfreeze_index) = P_rated(Vfreeze_index).*(V1_inv_tail_drop(Vfreeze_index)./Vprefault(Vfreeze_index)).^0.8;

% Define Q below V_freeze
kQ = 0.25 + 0.175.*Q_rated(Vfreeze_index);
Q_calc(Vfreeze_index) = V1_inv_tail_drop(Vfreeze_index)./Vref.*Q_rated(Vfreeze_index) + ...
    V1_inv_tail_drop(Vfreeze_index).*(kQ.*(Vprefault(Vfreeze_index) - V1_inv_tail_drop(Vfreeze_index)));

S_calc = (P_calc.^2 + Q_calc.^2).^0.5;
I_calc = (P_calc.^2 + Q_calc.^2).^0.5./(V1_inv_tail_drop);
Iphase_calc = P_calc.*0 - 1/2*pi - pi/6;
P_calc_0 = (P_calc ~= 0);
Iphase_calc(P_calc_0) = wrapToPi(-1*atan2(Q_calc(P_calc_0),P_calc(P_calc_0)) - pi/6);
w_V = @(x) max(min(((Vfreeze - V1_inv_tail_drop(Vfreeze_index))./(Vfreeze - 0.1)).^x(1),1),0);
%Iphase_calc(Vfreeze_index) = (1-w_V(1.6)).*Iphase_calc(Vfreeze_index) + w_V(1.6)*(-2*pi/3);

Vphase_fault = P_calc.*0 - 1/2*pi;
Vphase_fault(P_calc_0) = wrapToPi(-1*atan2(Q_calc(P_calc_0),P_calc(P_calc_0)));

% Fit line for V < 0.2 pu in mag and in phase
PQ_comb = unique([P_rated_drop(:), Q_rated_drop(:)], 'rows');
for k = 1:size(PQ_comb,1)
    Pk = PQ_comb(k,1);
    Qk = PQ_comb(k,2);
    idx_group = (P_rated_drop == Pk) & (Q_rated_drop == Qk);
    %I_calc(idx_group) = low_V_I_fit(V1_inv_tail_drop(idx_group), I_calc(idx_group), cut_off, Vfreeze);
    %Iphase_calc(idx_group) = low_V_I_fit(V1_inv_tail_drop(idx_group), Iphase_calc(idx_group), cut_off, Vfreeze);
end
I_avg_drop_lim = I_calc > I_max;
I_calc(I_avg_drop_lim) = I_max;

% Find out for which conditions the data diverges
disp("Printing conditions current magnitude for calc drop difference")
total = 0;
fail_count = 0;
fail_index = [];
index = (V_theta_rated_drop < 65) & (V_theta_rated_drop > -65);
for i = 1:size(I_avg_tail_drop)
    if (index(i) == 0)
        continue;
    end
    total = total + 1;
    if abs(I1_inv_tail_drop(i) - I_calc(i)) > 0.12
        %&& ((V1_inv_tail_drop(i) >= 0.2 && V1_inv_tail_drop(i) <= 0.7) || V1_inv_tail_drop(i) >= 0.9)
        fail_count = fail_count + 1;
        fail_index = [fail_index;0];
        fprintf('- Pref = %.2f, Qref = %.2f, Vref= %.2f, Theta_drop = %.2f, Theta_ref = %.2f, Ireal = %.2f, Icalc = %.2f, Ipre = %.2f, Preal = %0.4f, Qreal = %0.4f, Pcalc = %0.4f, Qcalc = %0.4f\n', ...
            P_rated_drop(i), Q_rated_drop(i), V1_inv_tail_drop(i), V_theta_rated_drop(i), Vphase_fault(i)*180/pi, I1_inv_tail_drop(i), I_calc(i), Iprefault(i), P_avg_tail_drop(i),Q_avg_tail_drop(i),P_calc(i),Q_calc(i));
    else
        fail_index = [fail_index;1];
    end
end

fprintf('Fail percent = %.2f\n', fail_count/total*100);
fprintf('mean P error = %0.6f\n', mean((P_avg_tail_drop(index) - P_calc(index)).^2));
fprintf('mean Q error = %0.6f\n', mean((Q_avg_tail_drop(index) - Q_calc(index)).^2));
fprintf('mean I error = %0.6f\n', mean((I1_inv_tail_drop(index) - I_calc(index)).^2));
fprintf('mean Iphase error = %0.6f\n', sqrt(mean((Iphase_meas(V1_inv_tail_drop>0 & index) - Iphase_calc(V1_inv_tail_drop>0 & index)).^2))*180/pi);



% Plot P vs V
figure
hold on
xlabel 'Vrms (PU)'
ylabel 'P (PU)'
title(sprintf('Preal at terminal vs V at terminal'))
for i = 1:3
    if i == 1
        index = 1:1/3*size(V1_inv_tail_drop);
    elseif i == 2
        index = 1/3*size(V1_inv_tail_drop):2/3*size(V1_inv_tail_drop);
    else
        index = 2/3*size(V1_inv_tail_drop):size(V1_inv_tail_drop);
    end
    input_1 = V1_inv_tail_drop(index);
    input_2 = P_avg_tail_drop(index);
    plot(input_1(P_rated(index) == 0.9), input_2(P_rated(index) == 0.9),'.',"DisplayName",sprintf('Vprefault = %0.1f',0.8+0.1*i))
end
legend('Location','northwest')
xlim([0 1.3])
ylim([-0.1 1.1])


% Plot P vs V
figure
hold on
xlabel 'Vrms (PU)'
ylabel 'P (PU)'
title(sprintf('Preal at terminal vs V at terminal'))
for i = 1:11
    plot(V1_inv_tail_drop(P_rated_drop==(i-1)*10), P_avg_tail_drop(P_rated_drop==(i-1)*10),'.',"DisplayName",sprintf('P rated = %0.2f',(i-1)*10))
end
legend('Location','northwest')
xlim([0 1.3])
ylim([-0.1 1.1])

% Plot P vs V
figure
hold on
xlabel 'Vrms (PU)'
ylabel 'P (PU)'
title(sprintf('Pcalc at terminal vs V at terminal'))
for i = 1:11
    plot(V1_inv_tail_drop(P_rated_drop==(i-1)*10), P_calc(P_rated_drop==(i-1)*10),'.',"DisplayName",sprintf('P rated = %0.2f',(i-1)*10))
end
legend('Location','northwest')
ylim([-0.1 1.1])
xlim([0 1.3])

% Plot Q vs V
figure
hold on
xlabel 'Vrms (PU)'
ylabel 'Q (PU)'
title(sprintf('Qreal at terminal vs V at terminal'))
legend('Location','northwest')
for i = 1:11
    plot(V1_inv_tail_drop(Q_rated_drop==(i-1)*10), Q_avg_tail_drop(Q_rated_drop==(i-1)*10),'.',"DisplayName",sprintf('Q rated = %0.2f',(i-1)*10))
end
ylim([-0.1 1.1])
xlim([0 1.3])

% Plot Q vs V
figure
hold on
xlabel 'Vrms (PU)'
ylabel 'Q (PU)'
title(sprintf('Qcalc at terminal vs V at terminal'))
legend('Location','northwest')
for i = 1:11
    plot(V1_inv_tail_drop(Q_rated_drop==(i-1)*10), Q_calc(Q_rated_drop==(i-1)*10),'.',"DisplayName",sprintf('Q rated = %0.2f',(i-1)*10))
end
ylim([-0.1 1.1])
xlim([0 1.3])

S_type = unique(S_rated);

% Plot S meas vs V
figure
hold on
xlabel 'Vrms (PU)'
ylabel 'S (PU)'
title(sprintf('Smeas at terminal vs V at terminal'))
legend('Location','northwest')
for i = 1:8
    plot(V1_inv_tail_drop(S_rated==S_type(i)), (P_avg_tail_drop(S_rated==S_type(i)).^2 + Q_avg_tail_drop(S_rated==S_type(i)).^2).^0.5,'.',"DisplayName",sprintf('S rated = %0.2f',S_type(i)*100))
end
ylim([-0.1 1.1])
xlim([0 1.3])

% Plot S calc vs V
figure
hold on
xlabel 'Vrms (PU)'
ylabel 'S (PU)'
title(sprintf('Scalc at terminal vs V at terminal'))
legend('Location','northwest')
for i = 1:8
    plot(V1_inv_tail_drop(S_rated==S_type(i)), S_calc(S_rated==S_type(i)),'.',"DisplayName",sprintf('S rated = %0.2f',S_type(i)*100))
end
ylim([-0.1 1.1])
xlim([0 1.3])

% Plot Imeas with V
figure
title(sprintf('Imeas vs V'))
xlabel 'V (PU)'
ylabel 'Imeas (PU)'
hold on
for i = 1:8
    plot(V1_inv_tail_drop(S_rated==S_type(i)), I1_inv_tail_drop(S_rated==S_type(i)),'.',"DisplayName",sprintf('S rated = %0.2f',S_type(i)*100))
end
legend('Location','northeast')
ylim([0 1.3])
xlim([0 1.3])

% Plot Icalc with V
figure
title(sprintf('Icalc vs V'))
xlabel 'V (PU)'
ylabel 'Icalc (PU)'
hold on
for i = 1:8
    plot(V1_inv_tail_drop(S_rated==S_type(i)), I_calc(S_rated==S_type(i)),'.',"DisplayName",sprintf('S rated = %0.2f',S_type(i)*100))
end
legend('Location','northeast')
ylim([0 1.3])
xlim([0 1.3])

% Plot Iphase with V
figure
title(sprintf('Iphase Meas vs V'))
xlabel 'V (PU)'
ylabel 'Iphase Meas (deg)'
hold on
for q = 1:11
    plot(V1_inv_tail_drop(Q_rated_drop==(q-1)*10), ...
        wrapToPi(Iphase_meas(Q_rated_drop==(q-1)*10))*180/pi, ...
        '.',"DisplayName",sprintf('Q rated = %0.2f',(q-1)*10))
end
legend('Location','northwest')
ylim([-180 180])
xlim([0 1.3])

% Plot Iphase with V
figure
title(sprintf('Iphase Calc vs V'))
xlabel 'V (PU)'
ylabel 'Iphase Calc (deg)'
hold on
for q = 1:11
    plot(V1_inv_tail_drop(Q_rated_drop==(q-1)*10), ...
        wrapToPi(Iphase_calc(Q_rated_drop==(q-1)*10))*180/pi, ...
        '.',"DisplayName",sprintf('Q rated = %0.2f',(q-1)*10))
end
legend('Location','northwest')
ylim([-180 180])
xlim([0 1.3])

% % Plot Imeas with V
% figure
% title(sprintf('CiP and CiQ vs V'))
% xlabel 'V (PU)'
% ylabel 'Imeas (PU)'
% hold on
% for i = 1:11
%     plot(V1_inv_tail_drop(Q_rated_drop==(i-1)*10), I1_inv_tail_drop(Q_rated_drop==(i-1)*10).*sin(-Iphase_prefault(Q_rated_drop==(i-1)*10)-pi/6),'.',"DisplayName",sprintf('P rated = %0.2f',(i-1)*10))
% end
% legend('Location','northeast')
% ylim([0 1.3])
% xlim([0 1.3])

function I_calc = low_V_I_fit(V1_inv_tail_drop, I_avg_drop_calc, cut_off, Vfreeze)
    idx_fit = V1_inv_tail_drop > cut_off & V1_inv_tail_drop <= Vfreeze;
    p = polyfit(V1_inv_tail_drop(idx_fit), I_avg_drop_calc(idx_fit), 1);
    idx_low = V1_inv_tail_drop <= cut_off;
    I_calc = I_avg_drop_calc;
    I_calc(idx_low) = polyval(p, V1_inv_tail_drop(idx_low));
end

% Define P, Q below V_freeze
% Iq = min(max(-Q_rated./(Vref), -I_max), I_max);
% Id = min(max(P_rated./(Vref), -(I_max.^2 - Iq.^2).^0.5), (I_max.^2 - Iq.^2).^0.5);
% Iqref = min(max(-Q_rated./Vfreeze + Cfilter_pu*V1_inv_tail_drop, -I_max), I_max);
% Idref = min(max(P_rated./Vfreeze, -(I_max.^2 - Iqref.^2).^0.5), (I_max.^2 - Iqref.^2).^0.5);
% Vd1 = V1_inv_tail_drop + min(max(0.5*(Idref - Id),-0.6),0.6) - Lbase.*0.5.*Iq;
% Vq1 = min(max(0.5*(Iqref - Iq),-0.6),0.6) + Lbase.*0.5.*Id;
% Vmag = (Vd1.^2 + Vq1.^2).^0.5*INVVbase_LNpk/Vdc;
% Vscale = min(max(Vmag, Vmin), Vmax)./Vmag;
% Vd = Vscale.*Vd1; Vq = Vscale.*Vq1; 
% P_calc(Vfreeze_index) = Vd(Vfreeze_index).*Id(Vfreeze_index) + Vq(Vfreeze_index).*(Iq(Vfreeze_index));
% Q_calc(Vfreeze_index) = Vq(Vfreeze_index).*Id(Vfreeze_index) - Vd(Vfreeze_index).*(Iq(Vfreeze_index));

% solve for Pelec, Qelec, Iref, and IL1
% syms Pelec Qelec Iref IL1
% Iref_calc = [];
% IL1_calc = [];
% for i = 1:size(V1_inv_tail_drop)
%     theta = Iphase_prefault(i);
%     Vd = V1_inv_tail_drop(i);
%     eqn1 = (P_rated(i) - Pelec)*Kpp + Cfilter_pu*Qelec/IL1 == Iref*cos(theta);
%     eqn2 = 0.5*(Iref*cos(theta) - IL1*cos(theta)) + Pelec/IL1 + IL1*sin(theta)*Lbase*0.5 == Vd;
%     eqn3 = -((Q_rated(i) - Qelec)*Kpq - Pelec/IL1*DVS_gain) + Cfilter_pu*Pelec/IL1 == Iref*sin(theta);
%     eqn4 = 0.5*(Iref*sin(theta) - IL1*sin(theta)) + Qelec/IL1 + IL1*cos(theta)*Lbase*0.5 == 0;
%     sol = vpasolve([eqn1,eqn2,eqn3,eqn4], [Pelec, Qelec, Iref, IL1], [P_rated(i), Q_rated(i), Iprefault(i), Iprefault(i)]);
%     P_calc(i) = sol.Pelec;
%     Q_calc(i) = sol.Qelec;
%     Iref_calc = [Iref_calc; sol.Iref];
%     IL1_calc = [IL1_calc; sol.IL1];
% end

% Define P, Q below V_freeze
% Iq = min(max(-Q_rated./(V1_inv_tail_drop), -I_max), I_max);
% Id = min(max(P_rated./(V1_inv_tail_drop), -(I_max.^2 - Iq.^2).^0.5), (I_max.^2 - Iq.^2).^0.5);
% Iqref = min(max(-Q_rated./V1_inv_tail_drop, -I_max), I_max);
% Idref = min(max(P_rated./V1_inv_tail_drop, -(I_max.^2 - Iqref.^2).^0.5), (I_max.^2 - Iqref.^2).^0.5);
% Vd1 = V1_inv_tail_drop + min(max(0.5*(Idref - Id),-0.6),0.6) - Lbase.*0.5.*Iq;
% Vq1 = min(max(0.5*(Iqref - Iq),-0.6),0.6) + Lbase.*0.5.*Id;
% Vmag = (Vd1.^2 + Vq1.^2).^0.5*INVVbase_LNpk/Vdc;
% Vscale = min(max(Vmag, Vmin), Vmax)./Vmag;
% Vd = Vscale.*Vd1; Vq = Vscale.*Vq1; 
% P_calc(Vfreeze_index) = Vd(Vfreeze_index).*Id(Vfreeze_index) + Vq(Vfreeze_index).*Iq(Vfreeze_index);
% Q_calc(Vfreeze_index) = Vq(Vfreeze_index).*Id(Vfreeze_index) - Vd(Vfreeze_index).*Iq(Vfreeze_index);

% kq = 0.05;
% P_calc(Vfreeze_index) = P_rated(Vfreeze_index).*((V1_inv_tail_drop(Vfreeze_index)./Vref)).^0.5.*sin(-Iphase_prefault(Vfreeze_index)-pi/6);
% Q_calc(Vfreeze_index) = V1_inv_tail_drop(Vfreeze_index)./Vref.*Q_rated(Vfreeze_index) + ...
%      V1_inv_tail_drop(Vfreeze_index)./Lbase.*(kq.*(Vprefault(Vfreeze_index)*Vref - V1_inv_tail_drop(Vfreeze_index)));
% S_calc = (P_calc.^2 + Q_calc.^2).^0.5;
% I_calc = (P_calc.^2 + Q_calc.^2).^0.5./(V1_inv_tail_drop);

% Define P, Q below V_freeze
% k = 0.05;
% S_calc(Vfreeze_index) = S_rated(Vfreeze_index).*((V1_inv_tail_drop(Vfreeze_index))./Vprefault(Vfreeze_index)).^0.5 - Iprefault(Vfreeze_index).^2*Lbase.*0.5;
% for i = 1:1000
%     I_calc = S_calc./(V1_inv_tail_drop);
%     S_calc(Vfreeze_index) = S_rated(Vfreeze_index).*((V1_inv_tail_drop(Vfreeze_index))./Vprefault(Vfreeze_index)).^0.5 - I_calc(Vfreeze_index).^2*Lbase.*0.5;
% end
% P_calc(Vfreeze_index) = S_calc(Vfreeze_index).*cos(-Iphase_prefault(Vfreeze_index)-pi/6);
% Q_calc(Vfreeze_index) = S_calc(Vfreeze_index).*sin(-Iphase_prefault(Vfreeze_index)-pi/6) + k;
% S_calc = (P_calc.^2 + Q_calc.^2).^0.5;
% I_calc = (P_calc.^2 + Q_calc.^2).^0.5./(V1_inv_tail_drop);

% Calculate Iphase
% Iphase_calc = P_calc.*0 - 1/2*pi - pi/6;
% P_calc_0 = (P_calc ~= 0);
% Iphase_calc(P_calc_0) = wrapToPi(-1*atan2(Q_calc(P_calc_0),P_calc(P_calc_0)) - pi/6);

% S_calc(Vfreeze_index) = S_rated(Vfreeze_index).*((V1_inv_tail_drop(Vfreeze_index) - Iprefault(Vfreeze_index)*Lbase.*0.5.*sin(Iphase_prefault(Vfreeze_index)))./Vref).^0.5;
% I_calc = S_calc./(V1_inv_tail_drop);
% S_calc(Vfreeze_index) = S_rated(Vfreeze_index).*(abs(V1_inv_tail_drop(Vfreeze_index) - I_calc(Vfreeze_index)*Lbase.*0.5)./Vref).^0.5;
% I_calc = S_calc./(V1_inv_tail_drop);

%I_calc(Vfreeze_index) = I_calc(Vfreeze_index) - 0.05*Q_rated(Vfreeze_index);

% % Define error function for P, Q in function of Vtheta
% P_calc(Vfreeze_index) = P_rated(Vfreeze_index).*(V1_inv_tail_drop(Vfreeze_index)./Vref).^0.8;
% 
% % Define Q below V_freeze
% k = 0.05;
% Q_calc(Vfreeze_index) = V1_inv_tail_drop(Vfreeze_index)./Vref.*Q_rated(Vfreeze_index) + ...
%     V1_inv_tail_drop(Vfreeze_index)./Lbase.*(k.*(Vref - V1_inv_tail_drop(Vfreeze_index)));

% Variables to fit: P0, Kpl, Vp0, Vp1, alphaP
% Variables to fit: betaP, gammaP, VthetaP0
%P0 = -0.0135; Vp0 = 0.1677; alphaP = 0.4737; 
%betaP = 0.0484; gammaP = -0.1006; VthetaP0 = -1.4767; VthetaP1 = 2.3466;
%Ep = @(V, Vtheta) 1 + betaP.*(1 - V).^2.*sin(Vtheta - VthetaP0) + gammaP.*(V./Vfreeze).^8.*cos(Vtheta - VthetaP1);
% Define P below V_freeze
% P_calc(Vfreeze_index) = P0 + (P_rated(Vfreeze_index) - P0)./Vref.*...
%        abs((V1_inv_tail_drop(Vfreeze_index) - Vp0)./(Vprefault - Vp0)).^alphaP.*...
%        Ep(V1_inv_tail_drop(Vfreeze_index), Ipheta_prefault(Vfreeze_index));

% Variables to fit: Q0, Kql, Vq0, alphaQ
% Variables to fit: betaQ, gammaQ, VthetaQ0
%Q0 = 0.0870; Vq0 = 0.1133; alphaq = 0.6662;
%betaQ = -0.1143; gammaQ = -0.0790; VthetaQ0 = -0.2047; VthetaQ1 = 0.9571;
%Eq = @(V, Vtheta) 1 + betaQ.*(1 - V).^2.*cos(Vtheta - VthetaQ0) + gammaQ.*(V/Vfreeze).^8.*cos(Vtheta - VthetaQ1);
% Define P below V_freeze 
% Q_calc(Vfreeze_index) = Q0 + (Q_rated(Vfreeze_index) - Q0)./(1/Vprefault).*...
%        abs((V1_inv_tail_drop(Vfreeze_index) - Vq0)./(Vprefault - Vq0)).^alphaq.*...
%        Eq(V1_inv_tail_drop(Vfreeze_index), Vtheta(Vfreeze_index));
