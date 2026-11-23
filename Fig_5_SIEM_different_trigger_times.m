
%Paper 2 Fig_5
clear; clc; close all;

%% Input data 
T = 100;                       
dt = 1;                         
time = 0:dt:T;
N = length(time);

attack_start = 15;
attack_stop = 75;


lambda_0 = 50;                  % Normal baseline noise 
lambda_1 = 62;                  % Set reconnaissance to a higher value 

C_D = 15;                       %  Isolation Cost 
E_L_FAIR = 92.58;               % Expected Loss 

PE_vec = [0.450, 0.739, 0.920];
scenarios = {'Low Risk P(E)=0.450', 'Baseline P(E)=0.739', 'High Risk P(E)=0.920'};% Different PE values for High, Low and Baselien risk

figure('Color', [1 1 1], 'Position', [100 100 800 800]);

for s = 1:length(PE_vec)
    P_E = PE_vec(s);
    mu_star = C_D / (P_E * E_L_FAIR); % Threshold: 0.360, 0.219, 0.176
    % The mu_star comes from equation_17
    
    
    pi0 = 0.02;
    mu = zeros(1, N);
    mu(1) = pi0;
    
    rng(42); %  seed value
    
    
    for k = 2:N
        t_curr = time(k);
        
        % Poisson arrivals-if-else
        if t_curr >= attack_start && t_curr <= attack_stop
            k_obs = poissrnd(lambda_1 * dt); % Attack stream ( Use this K-obs value with lambda_1 when dealing with attack phase)
        else
            k_obs = poissrnd(lambda_0 * dt); % Baseline stream
        end
        % This comes from the equation 11,14 and 15
        % Poisson Likelihood Ratio
        % L = (lambda_1 / lambda_0)^k * exp(-(lambda_1 - lambda_0))
        L = ((lambda_1 / lambda_0)^k_obs) * exp(-(lambda_1 - lambda_0) * dt);
        
        % Updating the Bayesian Update
        prior = mu(k-1);
        posterior = (L * prior) / (L * prior + (1 - prior));
        
        % Floor prior to prevent deep underflow before attack
        mu(k) = max(posterior, 0.005);
    end
    
    % Find Trigger Point
    trig_idx = find(mu >= mu_star, 1, 'first');
    t_trig = time(trig_idx);
    
    % Graphs 
    subplot(3, 1, s);
    plot(time, mu, 'b-', 'LineWidth', 2.5); hold on;
    yline(mu_star, '--m', sprintf(' Stackelberg Threshold \\mu^* = %.3f', mu_star), ...
        'LineWidth', 1.8, 'LabelHorizontalAlignment', 'left');
    xregion(attack_start, attack_stop, 'FaceColor', [1 0.8 0.8], 'FaceAlpha', 0.3);
    
    if ~isempty(trig_idx)
        plot(t_trig, mu(trig_idx), 'ro', 'MarkerSize', 9, 'MarkerFaceColor', 'r');
        text(t_trig + 2, mu_star - 0.08, ...
            sprintf('Automated Containment Triggered (t = %ds)', t_trig), ...
            'FontWeight', 'bold', 'Color', 'r', 'FontSize', 10);
    end
    
    ylabel('Posterior Belief \mu(t)');
    title(sprintf('%s | \\mu^* = %.3f', scenarios{s}, mu_star));
    ylim([0 1.05]); grid on;
    if s == 3, xlabel('Time [Seconds]'); end
end
