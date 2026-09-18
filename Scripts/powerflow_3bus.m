clear all; close all;

Vfreeze = 0.8;
Vref = 1.05;
Imax = 1.2;
Rfault = 0.5/144;
Xfault = 2*pi*60*0.005/144;
Zfault = Rfault + Xfault;

% Calculate no fault bus
disp("No fault 3 bus")
Pref1 = 0.8; Qref1 = 0.2;
Pref2 = 0.5; Qref2 = 0.2;

tol = 0.001;
not_tol = true;
P1 = Pref1; Q1 = Qref1;
P2 = Pref2; Q2 = Qref2;
while not_tol 
    [Vmag, delta, Pcalc, Qcalc] = pf_3bus(P1,Q1,P2,Q2, false);
    Vprefault1 = Vmag(2);
    Vprefault2 = Vmag(4);
    [Imag1, Iphase1, P1, Q1] = INVmodel(Vmag(2), Vfreeze, Vprefault1, Vref, Pref1, Qref1, Imax);
    [Imag2, Iphase2, P2, Q2] = INVmodel(Vmag(4), Vfreeze, Vprefault2, Vref, Pref2, Qref2, Imax);
    if abs(P1 - Pcalc(2)) < tol && abs(P2 - Pcalc(4)) < tol && abs(Q1 - Qcalc(2)) < tol && abs(Q2 - Qcalc(4)) < tol
        not_tol = false;
    end
end
Q1real = Q1 - Imag1.^2*0.1;
Q2real = Q2 - Imag2.^2*0.1;
Isc = (Pcalc(1).^2 + Qcalc(1).^2).^0.5./Vmag(1);
Ifault = (Pcalc(3).^2 + Qcalc(3).^2).^0.5./Vmag(3);

% Display final result
result_prefault = table( ...
        (1:4)', ...
        Vmag, ...
        rad2deg(delta), ...
        Pcalc, ...
        [Qcalc(1); Q1real; Qcalc(3); Q2real], ...
        [Isc; Imag1; Ifault; Imag2],...
        'VariableNames', ...
        {'Bus','V_pu','Angle_deg','P_pu','Q_pu', 'I_pu'});

% Iterative approach using model
% Powerflow during fault
disp("Yes fault 3 bus")
not_tol = true;
P1 = Pref1; Q1 = Qref1;
P2 = Pref2; Q2 = Qref2;
while not_tol 
    [Vmag, delta, Pcalc, Qcalc] = pf_3bus(P1,Q1,P2,Q2, true);
    [Imag1, Iphase1, P1, Q1] = INVmodel(Vmag(2), Vfreeze, Vprefault1, Vref, Pref1, Qref1, Imax);
    [Imag2, Iphase2, P2, Q2] = INVmodel(Vmag(4), Vfreeze, Vprefault2, Vref, Pref2, Qref2, Imax);
    
    if abs(P1 - Pcalc(2)) < tol && abs(P2 - Pcalc(4)) < tol && abs(Q1 - Qcalc(2)) < tol && abs(Q2 - Qcalc(4)) < tol
        not_tol = false;
    end
end

Q1real = Q1 - Imag1.^2*0.1;
Q2real = Q2 - Imag2.^2*0.1;
Isc = (Pcalc(1).^2 + Qcalc(1).^2).^0.5./Vmag(1);
Ifault = Vmag(3)/Zfault;

% Display final result
result_fault = table( ...
        (1:4)', ...
        Vmag, ...
        rad2deg(delta), ...
        Pcalc, ...
        [Qcalc(1); Q1real; Qcalc(3); Q2real], ...
        [Isc; Imag1; Ifault; Imag2],...
        'VariableNames', ...
        {'Bus','V_pu','Angle_deg','P_pu','Q_pu', 'I_pu'});

disp("Prefault Results")
disp(result_prefault)
disp("Postfault Results")
disp(result_fault)

disp("Powerflow Terminated")
disp(" ")

% Find voltages in 3bus system
function [Vmag, delta, Pcalc, Qcalc] = pf_3bus( ...
    P1, Q1, P2, Q2, fault_on)

    % System base
    Sbase = 100e6;
    Vbase = 120e3;
    f = 60;

    Zbase = Vbase^2 / Sbase;

    % Reactive limits of Bus 1 source
    Q1max = 2.0;
    Q1min = -2.0;

    % Line inductances
    L13 = 0.015;
    L23 = 0.015;
    L14 = 0.030;
    L24 = 0.030;

    % Convert physical inductance to pu reactance
    X13 = 2*pi*f*L13 / Zbase;
    X23 = 2*pi*f*L23 / Zbase;
    X14 = 2*pi*f*L14 / Zbase;
    X24 = 2*pi*f*L24 / Zbase;

    % Branch admittances
    y13 = 1 / (1j*X13);
    y23 = 1 / (1j*X23);
    y14 = 1 / (1j*X14);
    y24 = 1 / (1j*X24);

    % Fault impedance at Bus 3
    Rf_ohm = 0.5;
    Lf = 0.005;

    Rf_pu = Rf_ohm / Zbase;
    Xf_pu = 2*pi*f*Lf / Zbase;

    if fault_on
        yf = 1 / (Rf_pu + 1j*Xf_pu);
    else
        yf = 0;
    end

    % Construct Ybus
    Ybus = zeros(4,4);

    Ybus(1,1) = y13 + y14;
    Ybus(2,2) = y23 + y24;
    Ybus(3,3) = y13 + y23 + yf;
    Ybus(4,4) = y14 + y24;

    Ybus(1,3) = -y13;
    Ybus(3,1) = -y13;

    Ybus(2,3) = -y23;
    Ybus(3,2) = -y23;

    Ybus(1,4) = -y14;
    Ybus(4,1) = -y14;

    Ybus(2,4) = -y24;
    Ybus(4,2) = -y24;

    % Specified bus injections
    % Positive means generation/injection
    Pspec = zeros(4,1);
    Qspec = zeros(4,1);

    % Bus 2 PV farm
    Pspec(2) = P1;
    Qspec(2) = Q1;

    % Bus 3 has no scheduled injection
    Pspec(3) = 0;
    Qspec(3) = 0;

    % Bus 4 PV farm
    Pspec(4) = P2;
    Qspec(4) = Q2;

    % Bus 1 angle reference
    delta1 = 0;
    V1set = 1.0;

    options = optimoptions( ...
        'fsolve', ...
        'Display', 'off', ...
        'FunctionTolerance', 1e-10, ...
        'StepTolerance', 1e-10, ...
        'OptimalityTolerance', 1e-10, ...
        'MaxIterations', 500, ...
        'MaxFunctionEvaluations', 5000);

    % Stage 1: ordinary slack-bus solution
    % x = [delta2 delta3 delta4 V2 V3 V4]

    x0 = [
        0.02;
        0.01;
        0.02;
        1.00;
        1.00;
        1.00
    ];

    fun1 = @(x) powerFlowMismatch( ...
        x, Ybus, Pspec, Qspec, V1set, delta1);

    [xsol, ~, exitflag, output] = fsolve(fun1, x0, options);

    if exitflag <= 0
        warning("Initial power flow did not converge: %s", ...
            output.message);
    end

    delta = [
        delta1;
        xsol(1);
        xsol(2);
        xsol(3)
    ];

    Vmag = [
        V1set;
        xsol(4);
        xsol(5);
        xsol(6)
    ];

    V = Vmag .* exp(1j.*delta);

    Ibus = Ybus * V;
    Sbus = V .* conj(Ibus);

    Pcalc = real(Sbus);
    Qcalc = imag(Sbus);

    % Stage 2: enforce Bus 1 Q limit
    if Qcalc(1) > Q1max
        Qlimit = Q1max;

        fprintf( ...
            "Bus 1 Q = %.4f pu exceeds Qmax. " + ...
            "Re-solving with Q1 = %.4f pu.\n", ...
            Qcalc(1), Qlimit);

        limitActive = true;

    elseif Qcalc(1) < Q1min
        Qlimit = Q1min;

        fprintf( ...
            "Bus 1 Q = %.4f pu is below Qmin. " + ...
            "Re-solving with Q1 = %.4f pu.\n", ...
            Qcalc(1), Qlimit);

        limitActive = true;

    else
        limitActive = false;
    end

    if limitActive
        QspecLimited = Qspec;
        QspecLimited(1) = Qlimit;

        % Unknown vector:
        % xlim = [delta2 delta3 delta4 V1 V2 V3 V4]
        %
        % Bus 1 active power remains free and balances the system.
        % Bus 1 Q is fixed at its limit.
        % Bus 1 voltage magnitude is now allowed to change.

        x0lim = [
            delta(2);
            delta(3);
            delta(4);
            Vmag(1);
            Vmag(2);
            Vmag(3);
            Vmag(4)
        ];

        fun2 = @(x) powerFlowMismatchQlimited( ...
            x, Ybus, Pspec, QspecLimited, delta1);

        [xlim, ~, exitflag2, output2] = ...
            fsolve(fun2, x0lim, options);

        if exitflag2 <= 0
            warning( ...
                "Q-limited power flow did not converge: %s", ...
                output2.message);
        end

        delta = [
            delta1;
            xlim(1);
            xlim(2);
            xlim(3)
        ];

        Vmag = [
            xlim(4);
            xlim(5);
            xlim(6);
            xlim(7)
        ];

        V = Vmag .* exp(1j.*delta);

        Ibus = Ybus * V;
        Sbus = V .* conj(Ibus);

        Pcalc = real(Sbus);
        Qcalc = imag(Sbus);
    end

    % Display final result
    result = table( ...
        (1:4)', ...
        Vmag, ...
        rad2deg(delta), ...
        Pcalc, ...
        Qcalc, ...
        'VariableNames', ...
        {'Bus','V_pu','Angle_deg','P_pu','Q_pu'});

    disp(result);
end


% Return the current magnitude and the current phase w.r.t the voltage
% phase
function [Imag,Iphase, P, Q] = INVmodel(Vterminal, Vfreeze, Vprefault, Vref, Prated, Qrated, Imax)
    alphaP = 0.8; kQ = 0.25 + 0.175.*Qrated;
    Pcalc = Prated.*(Vterminal./Vprefault).^alphaP;
    Qcalc = Vterminal./Vref.*Qrated + Vterminal.*kQ.*(Vprefault-Vterminal);
    Pcalc(Vterminal > Vfreeze) = Prated;
    Qcalc(Vterminal > Vfreeze) = Qrated;
    Scalc = (Pcalc.^2 + Qcalc.^2).^0.5;
    Icalc = Scalc./Vterminal;

    Iphase_calc = Pcalc.*0 - 1/2*pi - pi/6;
    Pcalc_0 = (Pcalc ~= 0);
    Iphase_calc(Pcalc_0) = wrapToPi(-1*atan2(Qcalc(Pcalc_0),Pcalc(Pcalc_0)) - pi/6);

    Ilim = Icalc > Imax;
    Icalc(Ilim) = Imax;
    Qcalc(Ilim) = ((Icalc(Ilim).*Vterminal).^2 - Pcalc(Ilim).^2).^0.5;

    Imag = Icalc;
    Iphase = Iphase_calc;
    P = Pcalc;
    Q = Qcalc;
end

function mismatch = powerFlowMismatch( ...
    x, Ybus, Pspec, Qspec, V1, delta1)

    % Unknown vector:
    % x = [delta2 delta3 delta4 V2 V3 V4]

    delta = [
        delta1;
        x(1);
        x(2);
        x(3)
    ];

    Vmag = [
        V1;
        x(4);
        x(5);
        x(6)
    ];

    % Reject nonphysical voltage magnitudes
    if any(Vmag(2:end) <= 0)
        mismatch = 1e3 * ones(6,1);
        return;
    end

    % Complex bus voltages
    V = Vmag .* exp(1j*delta);

    % Nodal currents and injected complex powers
    I = Ybus * V;
    S = V .* conj(I);

    Pcalc = real(S);
    Qcalc = imag(S);

    % Non-slack buses: 2, 3, 4
    pq = 2:4;

    dP = Pspec(pq) - Pcalc(pq);
    dQ = Qspec(pq) - Qcalc(pq);

    mismatch = [
        dP;
        dQ
    ];
end

function mismatch = powerFlowMismatchQlimited( ...
    x, Ybus, Pspec, Qspec, delta1)

    % Bus 1 remains the angle-reference bus, but its voltage
    % magnitude is now unknown.
    %
    % Unknown vector:
    % x = [delta2 delta3 delta4 V1 V2 V3 V4]

    delta = [
        delta1;
        x(1);
        x(2);
        x(3)
    ];

    Vmag = [
        x(4);
        x(5);
        x(6);
        x(7)
    ];

    if any(Vmag <= 0) || any(Vmag > 2.0)
        mismatch = 1e3 .* ones(7,1);
        return;
    end

    V = Vmag .* exp(1j.*delta);

    Ibus = Ybus * V;
    Sbus = V .* conj(Ibus);

    Pcalc = real(Sbus);
    Qcalc = imag(Sbus);

    % Bus 1 active power is not specified.
    % It remains free to balance the system.
    dP = Pspec(2:4) - Pcalc(2:4);

    % Reactive-power equations apply at all four buses.
    % Qspec(1) contains the enforced Bus 1 limit.
    dQ = Qspec(1:4) - Qcalc(1:4);

    mismatch = [
        dP;
        dQ
    ];
end