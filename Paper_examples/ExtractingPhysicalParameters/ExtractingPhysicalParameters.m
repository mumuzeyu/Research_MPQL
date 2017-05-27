% This is a sumulation using the matrices from the paper
% "Extracting Physical Parameters of Mechanical Models From 
% Identified State-Space Representation" by M. De Angelis et al.
%-----------------------------------------------------------------
clear all;
close all

n = 8; %number of states (degrees of freedom)
m = 1; %number of inputs (we are assuming single input)

massMatrix = eye(8)*100;
stiffnessMatrix = [27071.1 0 0 0 -10000.0 0 -3535.5 -3535.5;
                   0 17071.1 0 -10000.0 0 0 -3535.5 -3535.5;
                   0 0 27071.1 0 -3535.5 3535.5 -10000.0 0;
                   0 -10000.0 0 17071.1 3535.5 -3535.5 0 0;
                   -10000.0 0 -3535.5 3535.5 27071.1 0 0 0;
                   0 0 3535.5 -3535.5 0 17071.1 0 -10000.0;
                   -3535.5 -3535.5 -10000.0 0 0 0 27071.1 0;
                   -3535.5 -3535.5 0 0 0 -10000.0 0 17071.1];
 dampingMatrix = [136.4 0 0 0 -50.0 0 -17.7 -17.7;
                  0 86.4 0 -50.0 0 0 -17.7 -17.7;
                  0 0 136.4 0 -17.7 17.7 -50.0 0;
                  0 -50.0 0 86.4 17.7 -17.7 0 0;
                  -50.0 0 -17.7 17.7 136.4 0 0 0;
                  0 0 17.7 -17.7 0 86.4 0 -50.0;
                  -17.7 -17.7 -50.0 0 0 0 136.4 0;
                  -17.7 -17.7 0 0 0 -50.0 0 86.4];
 dampingMatrix = zeros(n,n);
               
%---System Dynamic---
Ac = [zeros(n,n), eye(n);
      -inv(massMatrix)*stiffnessMatrix -inv(massMatrix)*dampingMatrix];
Bf =  zeros(n,m);
Bf(1,1) = 1; %assuming single input
Bc = [zeros(n,m);
      inv(massMatrix)*Bf];
Cc = eye(1,2*n); % n-output 
Dc = 0; % direct transition matrix
Q = eye(2*n); 
R = 1*1e-4;
gamma = 1; % discount factor
r = 5; % prediction horizon
dt = 0.05; % sampling delta using ~6 * highest frequency of the system
[A,B] = c2d(Ac, Bc, dt); % discrete system dynamic
%--------------------

%--- Checking for controlibility ---
Co = ctrb(A,B);
if rank(Co) == 2*n 
    disp('System is controlable')
else
    disp('System is not controllable')
end
%-----------------------------------

%---- Use to decide on the sampling frequency dt ---
if(0)
    subplot(2,1,1)
    impulse(Ac,Bc, Cc, Dc) % Continuous Impulse Response
    title('continuous')
    subplot(2,1,2)
    dimpulse(A,B,Cc,Dc);
    title('discrete')
    maxFreqAc = max(imag(eig(Ac)))/(2*pi);
    idealSampleRate = 1/(6*maxFreqAc)
end
%----------------------------------------------------

%------------Simulation Run Flags--------------------
runContinuousLQR = true;
runDiscreteLQR =   true;
runMPC =           true;
runImplicitMPQL =  true;
%----------------------------------------------------

%------------Simulation Variables--------------------
Time = 0:dt:50;
U = zeros(size(Time)); %single input
X0 = [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]';
%----------------------------------------------------

%--------------Continuous-Time LQR-----------------------
if(runContinuousLQR)
% Open-Loop Simulation (continuous)
sys_ol = ss(Ac,Bc,Cc,Dc);

[Yo,~,~] = lsim(sys_ol, U, Time, X0);
figure(1);
subplot(2,1,1);
plot(Time,Yo);
title('Open-Loop Simulation LQR (continuous-time)');

% Closed-Loop Simulation Using LQR (continuous)
K = -lqr(sys_ol, Q, R);        %LQR gain
Ac_cl = Ac+Bc*K;               %closed-Loop system dynamics matrix
sys_cl = ss(Ac_cl,Bc,Cc,Dc);

[Yc,~,~] = lsim(sys_cl, U, Time, X0);
subplot(2,1,2)
plot(Time,Yc);
title('Close-Loop Simulation LQR (continuous-time)');
end
%-----------------------------------------------------

%--------------Discrete-Time LQR-----------------------
if(runDiscreteLQR)
[A,B] = c2d(Ac, Bc, dt);

%Open_Loop Simulation Using LQR (discrete)
[Y,~]=dlsim(A,B,Cc,Dc,U,X0);
figure(2);
subplot(3,1,1);
plot(Time,Y);
title('Open-Loop Simulation LQR (discrete-time)');

%Closed_Loop Simulation Using LQR (discrete)
Kd = -dlqr(A,B,Q,R);
[X_hist, U_hist] = simulate(A,B,Kd,X0,length(Time));
subplot(3,1,2);
plot(Time,Cc*X_hist);
title('Closed-Loop Simulation LQR (discrete-time)');

%Closed-Loop control signal
subplot(3,1,3);
plot(Time(1,1:end-1), U_hist);
title('Control Signal (input) LQR (discrete-time)');
end
%------------------------------------------------------

%-------------------------MPC----------------------------
if(runMPC)
    [A,B] = c2d(Ac, Bc, dt);
    [n,m] = size(B);
    r = 100;
    gamma = 1;
    S = calculateAnalyticalS(A,B,r,gamma,Q,R);
    Sxu = S(1:n, n+1:n+r*m);
    Suu = S(n+1:n+r*m,n+1:n+r*m);
    G = -pinv(Suu)*Sxu';
    GL = G(1:m,:);
    A_cl = A+B*GL;

    %Open_Loop Simulation Using LQR (discrete)
    [Y,~]=dlsim(A,B,Cc,Dc,U,X0);
    figure(3);
    subplot(3,1,1);
    plot(Time,Y);
    title('Open-Loop simulation MPC (discrete-time)');

    %Closed_Loop Simulation Using LQR (discrete)
    [X_hist, U_hist] = simulate(A,B,GL,X0,length(Time));
    subplot(3,1,2);
    plot(Time,Cc*X_hist)
    title(['Closed-Loop simulation MPC (discrete-time) with r=',num2str(r)]);
    
    %Closed-Loop control signal
    subplot(3,1,3);
    plot(Time(1,1:end-1), U_hist)
    title('Control Signal (input) MPC (discrete-time)');
end
%--------------------------------------------------------

%--------------------MPQL(implicit)----------------------
if(runImplicitMPQL)
    [A,B] = c2d(Ac, Bc, dt);
    r = 100;
    gamma = 1;
    input_vals = [-50000:10000:50000,-10000:1000:10000,-1000:100:1000,-100:10:100];
    numIter = length(Time);
    [X_hist, U_hist] = implicitMPQL(A,B,Q,R,r,gamma,X0,input_vals, numIter, false);
    
    %Open_Loop Simulation
    [Y,X]=dlsim(A,B,Cc,Dc,U,X0);
    figure(4);
    subplot(3,1,1);
    plot(Time,Y);
    title('Open-Loop simulation MPQL (discrete-time)'); 
    %Closed_Loop Simulation
    subplot(3,1,2);
    plot(Time,Cc*X_hist(:,1:end-1))
    title(['Closed-Loop simulation MPQL (discrete-time) with r=', num2str(r)]);
    %Control signal
    subplot(3,1,3);
    plot(Time, U_hist);
    title('Control Input');
end
%---------------------------------------------------------




