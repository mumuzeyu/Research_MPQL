% This script is for plotting MPC gains for different predictive horizons
% and compare them to the LQR gains.
%--------------------------------------------------------------------------

clear all;
close all;

%--- System ---
[A,B,Cc,Dc,Q,R,Ac,Bc] = getSystemModel(4);

load('trussmodelforErfan.mat','dt');
[n,m] = size(B);
%--------------

%--- Simulation Variables ---
gamma = 0.7;
r_vals = 10:5:50;
% only the forst five gains
MPC_gains = zeros(5,length(r_vals));
%---------------------------

%------- MPC gains --------
index = 1;
for r=r_vals
    G_MPC = getMPCGain(A,B,Q,R,r,gamma);
    MPC_gains(:,index) = G_MPC(1,1:5);
    index = index+1;
end
MPC_stability = checkStability(G_MPC,A,B)
%---------------------------

%------- LQR gains ---------
N = 300;
G_LQR = discounted_dlqr(A,B,Q,R,N,gamma);
LQR_gains = G_LQR(1,1:5);
LQR_stability = checkStability(G_LQR,A,B)
%---------------------------

%% plots

LQR_plot = plot(r_vals, repmat(LQR_gains', 1,length(r_vals)), 'LineWidth',2.5, 'Color',[0.8,0.4,0.4]);
hold on;
MPC_plot = plot(r_vals, MPC_gains','LineWidth',2.5, 'Color',[0.3,0.3,0.5], 'LineStyle','-.');
hold off;
set(gca,'FontSize',25) %set axis properties
xlabel('Prediction Horizon','FontSize', 30)
ylabel('Gain Values','FontSize', 30)
Leg = legend([LQR_plot(1),MPC_plot(1)],'LQR','MPC');
set(Leg, 'FontSize', 20)
grid on;