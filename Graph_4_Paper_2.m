%%% Paper-2-Graph_4
clear; clc; close all;

%Input Parameter
T = 100;                  
dt = 1;                  
time = 0:dt:T;
N = length(time);


lambda_0 = 50;            % Noise EPS
lambda_A = 30;            
lambda_1 = lambda_0 + lambda_A; % Elevated EPS


P_d = 0.90;               % True Positive Rate / Sensitivity
P_fp = 0.03;              % False Positive Rate / Noise Floor

% Stackelberg Game Parameters (These are estimate values)
C_D = 15;                 % Operational Containment cost
P_E = 0.739;              % CVSS v3.1 Exploitability Probability (This was calculated using equation 1 and 2
E_L_FAIR = 92.58;         % Expected FAIR Loss

% Calculate mu^*
mu_star = C_D / (P_E * E_L_FAIR); % From equation 17


attack_start = 35;
attack_end = 75;


pi_0 = 0.02;             
mu = zeros(1, N);
mu(1) = pi_0;

EPS_observed = zeros(1, N);
action_triggered = zeros(1, N); 

rng(42); 

for t = 1:N-1
    currentTime = time(t);
    
    % These if-else is to determine when to use what value of lambda
    if currentTime >= attack_start && currentTime <= attack_end
        current_lambda = lambda_1; % Active Attack State (\theta_1)
    else
        current_lambda = lambda_0; % Normal Noise State (\theta_0)
    end
    
    % Generate Poisson log event with matlab built in 
    EPS_observed(t) = poissrnd(current_lambda * dt);
    
    % Evaluate z_t with EPS
    if EPS_observed(t) > poissinv(0.95, lambda_0 * dt)
        z_t = 1; % Alert Fired
    else
        z_t = 0; % Quiet State
    end
    
    % If_else for updating  Step
    if z_t == 1
        num = P_d * mu(t);
        den = (P_d * mu(t)) + (P_fp * (1 - mu(t)));
    else
        num = (1 - P_d) * mu(t);
        den = ((1 - P_d) * mu(t)) + ((1 - P_fp) * (1 - mu(t)));
    end
    
    
    mu(t+1) = num / den;
    
    
    if mu(t+1) >= mu_star
        action_triggered(t+1) = 1; % Trigger Automated Containment
    else
        action_triggered(t+1) = 0; % Keep Passive Operational Posture
    end
end
EPS_observed(N) = poissrnd(lambda_0 * dt);


figure('Color', [1 1 1], 'Position', [100 100 800 600]);


subplot(2,1,1);
bar(time, EPS_observed, 'FaceColor', [0.4 0.6 0.8], 'EdgeColor', 'none');
hold on;
yline(lambda_0, '--k', 'Baseline Noise (\lambda_0 = 50 EPS)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
yline(lambda_1, '--r', 'Attack Signature (\lambda_1 = 80 EPS)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
xregion(attack_start, attack_end, 'FaceColor', [1 0.8 0.8], 'FaceAlpha', 0.4);
ylabel('Ingested Telemetry [EPS]');
title('A. Dynamic SIEM Ingestion Stream (Events Per Second)');
grid on;
legend('Observed EPS', 'Location', 'northeast');


subplot(2,1,2);
plot(time, mu, 'b-', 'LineWidth', 2.5);
hold on;
xline_obj = yline(mu_star, '--m', sprintf(' Stackelberg Threshold \\mu^* = %.3f', mu_star), ...
    'LineWidth', 2, 'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', 'bottom');
xregion(attack_start, attack_end, 'FaceColor', [1 0.8 0.8], 'FaceAlpha', 0.4);

trigger_idx = find(action_triggered == 1, 1, 'first');
if ~isempty(trigger_idx)
    plot(time(trigger_idx), mu(trigger_idx), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    text(time(trigger_idx) + 2, mu(trigger_idx) - 0.08, ...
        sprintf('Automated Containment Triggered (t = %ds)', time(trigger_idx)), ...
        'FontWeight', 'bold', 'Color', 'r');
end

xlabel('Time [Seconds]');
ylabel('Posterior Attack Belief \mu(t)');
title('B. Dynamic Bayesian State Updating & Automated Game Control Execution');
ylim([0 1.05]);
grid on;
legend('Posterior Belief \mu(t)', 'Critical Decision Threshold', 'Location', 'northwest');