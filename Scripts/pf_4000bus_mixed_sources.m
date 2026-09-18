%% PF_4000BUS_MIXED_SOURCES
% Sparse power-flow framework for a large network with a mixture of
% grid-following inverter-based resources (IBRs) and synchronous generators.
%
% IMPORTANT:
%   1) The network created below is a synthetic demonstration network.
%      Replace createDemoCase() with your actual bus, branch, and device data.
%   2) This uses a sparse Newton-Raphson solver rather than finite-difference
%      fsolve. For ~4000 buses, a dense fsolve formulation is generally too slow.
%   3) Sign convention: positive P/Q = injection into the AC network;
%      negative P/Q = load consumption.

clear; close all; clc;

% User settings
nbus     = 4000;
Sbase_MVA = 100;
f_Hz      = 60;
Vfreeze   = 0.8;
Vref      = 1.05;
ImaxIBR   = 1.2;
QmaxSG    = 1.0;
QminSG    = -1.0;

pfTol       = 1e-8;
pfMaxIter   = 40;
outerTol    = 1e-4;
outerMaxIter = 50;
relaxation  = 0.5;

% Build or import the network
% bus columns:
%   1 bus number
%   2 type: 1=PQ, 2=PV, 3=slack
%   3 Vm initial/setpoint (pu)
%   4 Va initial (deg)
%   5 Pload (pu)
%   6 Qload (pu)
%
% branch columns:
%   1 from bus, 2 to bus, 3 Rpu, 4 Xpu, 5 Bpu total, 6 tap
%
% dev columns:
%   1 bus, 2 type: 1=IBR, 2=SG
%   3 Pref/Pg (pu), 4 Qref/Qg initial (pu)
%   5 Vset (pu), 6 Qmin, 7 Qmax, 8 Imax
[bus, branch, dev] = createDemoCase(nbus, QminSG, QmaxSG, ImaxIBR);

% Build sparse Ybus
Ybus = makeYbusSparse(nbus, branch);

% Optional fault shunt
fault.on   = true;
fault.bus  = round(nbus/2);
fault.Rpu  = 0.02;
fault.Xpu  = 0.05;

if fault.on
    Ybus(fault.bus, fault.bus) = Ybus(fault.bus, fault.bus) + ...
        1/(fault.Rpu + 1j*fault.Xpu);
end

% Prefault solution (fault removed)
YbusPre = makeYbusSparse(nbus, branch);
[PspecPre, QspecPre, busTypePre, VsetPre] = assembleInjections(bus, dev);

[VmPre, VaPre, PcalcPre, QcalcPre, infoPre] = sparsePowerFlowNR( ...
    YbusPre, PspecPre, QspecPre, busTypePre, VsetPre, ...
    deg2rad(bus(:,4)), pfTol, pfMaxIter, true, dev);

if ~infoPre.converged
    warning('Prefault power flow did not converge.');
end

Vprefault = VmPre;

% Faulted solution with outer IBR iteration
[Pspec, Qspec, busType, Vset] = assembleInjections(bus, dev);

% Initial IBR outputs are their references.
ibrRows = find(dev(:,2) == 1);
Pibr = dev(ibrRows,3);
Qibr = dev(ibrRows,4);

Vm = VmPre;
Va = VaPre;

for outer = 1:outerMaxIter
    Pold = Pibr;
    Qold = Qibr;

    % Update specified IBR injections.
    for k = 1:numel(ibrRows)
        row = ibrRows(k);
        b = dev(row,1);
        Pspec(b) = Pibr(k) - bus(b,5);
        Qspec(b) = Qibr(k) - bus(b,6);
    end

    [Vm, Va, Pcalc, Qcalc, info] = sparsePowerFlowNR( ...
        Ybus, Pspec, Qspec, busType, Vset, Va, ...
        pfTol, pfMaxIter, true, dev);

    if ~info.converged
        warning('Inner power flow failed at outer iteration %d.', outer);
        break;
    end

    % Re-evaluate IBR output at solved terminal voltage.
    for k = 1:numel(ibrRows)
        row = ibrRows(k);
        b = dev(row,1);
        Pref = dev(row,3);
        Qref = dev(row,4);
        Imax = dev(row,8);

        [~, ~, Pnew, Qnew] = INVmodelLarge( ...
            Vm(b), Vfreeze, Vprefault(b), Vref, Pref, Qref, Imax);

        Pibr(k) = relaxation*Pnew + (1-relaxation)*Pold(k);
        Qibr(k) = relaxation*Qnew + (1-relaxation)*Qold(k);
    end

    err = max([abs(Pibr-Pold); abs(Qibr-Qold)]);
    fprintf('Outer iteration %2d: max IBR change = %.3e pu\n', outer, err);

    if err < outerTol
        break;
    end
end

% Final device-current verification
V = Vm .* exp(1j*Va);
Ibus = Ybus*V;

ImagDev = zeros(size(dev,1),1);
IangDev = zeros(size(dev,1),1);

for k = 1:size(dev,1)
    b = dev(k,1);

    if dev(k,2) == 1
        local = find(ibrRows == k, 1);
        Pdev = Pibr(local);
        Qdev = Qibr(local);
    else
        % For SGs, use solved net bus injection plus local load.
        Pdev = Pcalc(b) + bus(b,5);
        Qdev = Qcalc(b) + bus(b,6);
    end

    Idev = conj((Pdev + 1j*Qdev)/V(b));
    ImagDev(k) = abs(Idev);
    IangDev(k) = angle(Idev);
end

% Report
fprintf('\nFinal status\n');
fprintf('Converged: %d\n', info.converged);
fprintf('Inner iterations: %d\n', info.iterations);
fprintf('Minimum voltage: %.4f pu at bus %d\n', min(Vm), find(Vm==min(Vm),1));
fprintf('Maximum voltage: %.4f pu at bus %d\n', max(Vm), find(Vm==max(Vm),1));
fprintf('Maximum bus current injection: %.4f pu\n', max(abs(Ibus)));

resultBus = table((1:nbus)', Vm, rad2deg(Va), Pcalc, Qcalc, abs(Ibus), ...
    'VariableNames', {'Bus','V_pu','Angle_deg','P_pu','Q_pu','Iinj_pu'});

resultDev = table(dev(:,1), dev(:,2), ImagDev, rad2deg(IangDev), ...
    'VariableNames', {'Bus','DeviceType','I_pu','CurrentAngle_deg'});

writetable(resultBus, 'pf_4000bus_bus_results.csv');
writetable(resultDev, 'pf_4000bus_device_results.csv');

fprintf('Results written to pf_4000bus_bus_results.csv and pf_4000bus_device_results.csv\n');

% ------------------------------------------------------------------------
function [bus, branch, dev] = createDemoCase(nbus, QminSG, QmaxSG, ImaxIBR)
% Create a connected synthetic test case.
% Replace this function with readtable/readmatrix for a real network.

    rng(7);

    bus = zeros(nbus,6);
    bus(:,1) = (1:nbus)';
    bus(:,2) = 1;                 % default PQ
    bus(:,3) = 1.0;
    bus(:,4) = 0;

    % Moderate random loads.
    bus(:,5) = 0.0005 + 0.0015*rand(nbus,1);
    bus(:,6) = 0.2*bus(:,5);

    % Slack bus.
    bus(1,2) = 3;
    bus(1,3) = 1.0;
    bus(1,5:6) = 0;

    % Start with a radial backbone to guarantee connectivity.
    from = (1:nbus-1)';
    to   = (2:nbus)';
    R = 0.002 + 0.004*rand(nbus-1,1);
    X = 0.02  + 0.04*rand(nbus-1,1);
    B = zeros(nbus-1,1);
    tap = ones(nbus-1,1);
    branch = [from to R X B tap];

    % Add extra random ties for meshing.
    ntie = round(0.15*nbus);
    fbus = randi([1 nbus-2], ntie, 1);
    tbus = min(nbus, fbus + randi([2 50],ntie,1));
    keep = fbus ~= tbus;
    fbus = fbus(keep); tbus = tbus(keep);
    Rtie = 0.003 + 0.005*rand(numel(fbus),1);
    Xtie = 0.03  + 0.05*rand(numel(fbus),1);
    branch = [branch; fbus tbus Rtie Xtie zeros(numel(fbus),1) ones(numel(fbus),1)];

    % Device placement: roughly 8% IBR and 2% SG.
    available = (2:nbus)';
    available = available(randperm(numel(available)));
    nIBR = max(1, round(0.08*nbus));
    nSG  = max(1, round(0.02*nbus));

    ibrBus = available(1:nIBR);
    sgBus  = available(nIBR+1:nIBR+nSG);

    % Convert SG buses to PV buses. Slack stays bus 1.
    bus(sgBus,2) = 2;
    bus(sgBus,3) = 1.0;

    dev = zeros(nIBR+nSG+1,8);

    % Slack synchronous source at bus 1.
    dev(1,:) = [1 2 0 0 1.0 QminSG QmaxSG 3.0];

    % IBRs: PQ-controlled in prefault power flow.
    for k = 1:nIBR
        dev(1+k,:) = [ibrBus(k) 1 0.006 0.001 1.0 -0.005 0.005 ImaxIBR];
    end

    % SGs: PV buses with Q limits.
    for k = 1:nSG
        dev(1+nIBR+k,:) = [sgBus(k) 2 0.012 0.0 1.0 QminSG QmaxSG 2.0];
    end
end

function Ybus = makeYbusSparse(nbus, branch)
    nl = size(branch,1);
    f = branch(:,1);
    t = branch(:,2);
    r = branch(:,3);
    x = branch(:,4);
    b = branch(:,5);
    tap = branch(:,6);
    tap(tap == 0) = 1;

    y = 1 ./ (r + 1j*x);
    ysh = 1j*b/2;

    Yff = (y + ysh) ./ (tap.^2);
    Yft = -y ./ tap;
    Ytf = -y ./ tap;
    Ytt = y + ysh;

    rows = [f; f; t; t];
    cols = [f; t; f; t];
    vals = [Yff; Yft; Ytf; Ytt];

    Ybus = sparse(rows, cols, vals, nbus, nbus, 4*nl);
end

function [Pspec, Qspec, busType, Vset] = assembleInjections(bus, dev)
    nbus = size(bus,1);
    Pspec = -bus(:,5);
    Qspec = -bus(:,6);
    busType = bus(:,2);
    Vset = bus(:,3);

    for k = 1:size(dev,1)
        b = dev(k,1);
        Pspec(b) = Pspec(b) + dev(k,3);
        Qspec(b) = Qspec(b) + dev(k,4);
        if dev(k,2) == 2 && busType(b) ~= 3
            busType(b) = 2;
            Vset(b) = dev(k,5);
        end
    end
end

function [Vm, Va, Pcalc, Qcalc, info] = sparsePowerFlowNR( ...
    Ybus, Pspec, Qspec, busType, Vset, Va0, tol, maxIter, enforceQlim, dev)
% Sparse Newton-Raphson AC power flow with PV-to-PQ switching.

    nbus = numel(Pspec);
    G = real(Ybus);
    B = imag(Ybus);

    slack = find(busType == 3);
    if numel(slack) ~= 1
        error('Exactly one slack bus is required.');
    end

    Vm = Vset;
    Vm(Vm <= 0) = 1.0;
    Va = Va0;

    converged = false;

    for iter = 1:maxIter
        V = Vm .* exp(1j*Va);
        S = V .* conj(Ybus*V);
        Pcalc = real(S);
        Qcalc = imag(S);

        % Enforce SG Q limits by PV-to-PQ conversion.
        if enforceQlim
            sgRows = find(dev(:,2) == 2);
            for kk = 1:numel(sgRows)
                row = sgRows(kk);
                b = dev(row,1);
                if b == slack || busType(b) ~= 2
                    continue;
                end
                Qgen = Qcalc(b); % demo assumes no separate local-load correction here
                if Qgen > dev(row,7)
                    Qspec(b) = dev(row,7);
                    busType(b) = 1;
                elseif Qgen < dev(row,6)
                    Qspec(b) = dev(row,6);
                    busType(b) = 1;
                end
            end
        end

        pv = find(busType == 2);
        pq = find(busType == 1);
        pvpq = [pv; pq];

        dP = Pspec(pvpq) - Pcalc(pvpq);
        dQ = Qspec(pq) - Qcalc(pq);
        mis = [dP; dQ];

        if norm(mis, inf) < tol
            converged = true;
            break;
        end

        % Build sparse Jacobian using standard polar-form derivatives.
        np = numel(pvpq);
        nq = numel(pq);

        % Dense-in-angle formulas are evaluated only at connected entries
        % through sparse Ybus indexing. For clarity this implementation uses
        % sparse assembly loops over buses; for production, vectorize further.
        J11 = spalloc(np,np,10*np);
        J12 = spalloc(np,nq,10*np);
        J21 = spalloc(nq,np,10*nq);
        J22 = spalloc(nq,nq,10*nq);

        mapP = zeros(nbus,1); mapP(pvpq) = 1:np;
        mapQ = zeros(nbus,1); mapQ(pq) = 1:nq;

        for a = 1:np
            i = pvpq(a);
            neigh = find(Ybus(i,:));

            for jj = 1:numel(neigh)
                k = neigh(jj);
                if k == i, continue; end
                th = Va(i)-Va(k);
                Gik = G(i,k); Bik = B(i,k);

                if mapP(k) > 0
                    J11(a,mapP(k)) = Vm(i)*Vm(k)*(Gik*sin(th)-Bik*cos(th));
                end
                if mapQ(k) > 0
                    J12(a,mapQ(k)) = Vm(i)*(Gik*cos(th)+Bik*sin(th));
                end
            end

            J11(a,a) = -Qcalc(i) - B(i,i)*Vm(i)^2;
            if mapQ(i) > 0
                J12(a,mapQ(i)) = Pcalc(i)/Vm(i) + G(i,i)*Vm(i);
            end
        end

        for a = 1:nq
            i = pq(a);
            neigh = find(Ybus(i,:));

            for jj = 1:numel(neigh)
                k = neigh(jj);
                if k == i, continue; end
                th = Va(i)-Va(k);
                Gik = G(i,k); Bik = B(i,k);

                if mapP(k) > 0
                    J21(a,mapP(k)) = -Vm(i)*Vm(k)*(Gik*cos(th)+Bik*sin(th));
                end
                if mapQ(k) > 0
                    J22(a,mapQ(k)) = Vm(i)*(Gik*sin(th)-Bik*cos(th));
                end
            end

            if mapP(i) > 0
                J21(a,mapP(i)) = Pcalc(i) - G(i,i)*Vm(i)^2;
            end
            J22(a,a) = Qcalc(i)/Vm(i) - B(i,i)*Vm(i);
        end

        J = [J11 J12; J21 J22];
        dx = J \ mis;

        Va(pvpq) = Va(pvpq) + dx(1:np);
        Vm(pq)   = Vm(pq)   + dx(np+1:end);
        Vm(pv)   = Vset(pv);

        if any(~isfinite(Vm)) || any(Vm <= 0)
            break;
        end
    end

    V = Vm .* exp(1j*Va);
    S = V .* conj(Ybus*V);
    Pcalc = real(S);
    Qcalc = imag(S);

    info.converged = converged;
    info.iterations = iter;
    info.maxMismatch = norm(mis,inf);
end

function [Imag, Iphase, P, Q] = INVmodelLarge( ...
    Vterminal, Vfreeze, Vprefault, Vref, Prated, Qrated, Imax)
% Scalar physics-informed IBR approximation with consistent current limiting.

    Veps = max(Vterminal, 1e-4);
    alphaP = 0.8;
    kQ = 0.25 + 0.175*Qrated;

    if Vterminal > Vfreeze
        Pcmd = Prated;
        Qcmd = Qrated;
    else
        Pcmd = Prated*(Veps/max(Vprefault,1e-4))^alphaP;
        Qcmd = Veps/Vref*Qrated + Veps*kQ*(Vprefault-Veps);
    end

    Iunlim = hypot(Pcmd,Qcmd)/Veps;
    scale = min(1, Imax/max(Iunlim,1e-12));

    P = scale*Pcmd;
    Q = scale*Qcmd;
    Imag = hypot(P,Q)/Veps;
    Iphase = wrapToPi(-atan2(Q,P));
end
