% Graph2 Paper2
clear; clc; close all;

% Input signal
N = 10000; 
gamma = 4;

LEF_min = 0.5; 
LEF_mode = 0.8; 
LEF_max = 1.2;

PLM_min = 80;   
PLM_mode = 94;  
PLM_max = 120;  

SLM_min = 5;    
SLM_mode = 15;  
SLM_max = 40;   

%% 3. Using PERT Beta Distributions
% Helper function for PERT sampling
draw_pert = @(a, b, c, n) pert_sample(a, b, c, gamma, n);

% Having the max, min and mode
LEF_samples = draw_pert(LEF_min, LEF_mode, LEF_max, N);
PLM_samples = draw_pert(PLM_min, PLM_mode, PLM_max, N);
SLM_samples = draw_pert(SLM_min, SLM_mode, SLM_max, N);


LM_samples = PLM_samples + SLM_samples;
 
ALE_samples = LEF_samples .* LM_samples;

%% 4. Statistical Analysis
mean_ALE   = mean(ALE_samples);
std_ALE    = std(ALE_samples);
p95_ALE    = prctile(ALE_samples, 95); % 95th Percentile (Value at Risk)
p50_ALE    = median(ALE_samples);

fprintf('================ Monte Carlo FAIR Results ================\n');
fprintf('Mean Expected Annual Loss (ALE):  $%6.2f Million\n', mean_ALE);
fprintf('Median (50th Percentile) Loss:     $%6.2f Million\n', p50_ALE);
fprintf('95th Percentile (VaR / Max Risk): $%6.2f Million\n', p95_ALE);
fprintf('Standard Deviation:               $%6.2f Million\n', std_ALE);
fprintf('==========================================================\n');

%% 5. Visualization
figure('Color', [1 1 1]);


histogram(ALE_samples, 50, 'Normalization', 'pdf', 'FaceColor', [0.2 0.4 0.6], 'EdgeColor', 'none');
hold on;

% Kernel Density Estimation
[f, x] = ksdensity(ALE_samples);
plot(x, f, 'r-', 'LineWidth', 2.5);


xline(mean_ALE, '--k', sprintf(' Mean: $%.1fM', mean_ALE), 'LineWidth', 2, 'LabelOrientation', 'aligned');
xline(p95_ALE, '--m', sprintf(' 95th Pct: $%.1fM', p95_ALE), 'LineWidth', 2, 'LabelOrientation', 'aligned');

title('MGM Resorts Cyber Event: FAIR Monte Carlo Loss Distribution (N = 10,000)');
xlabel('Annual Loss Exposure (ALE) [$ Millions USD]');
ylabel('Probability Density');
grid on;
legend('Simulated Iterations', 'Probability Density Function (PDF)', 'Location', 'northeast');



%%% These are from equation -5,6, and 7

function samples = pert_sample(a, b, c, g, n)
    % a: Min, b: Mode, c: Max, g: Shape Parameter (default 4)
    mu = (a + g*b + c) / (g + 2);
    
    % Beta parameters (alpha and beta)
    if mu == b
        alpha = g/2 + 1;
        beta_param = g/2 + 1;
    else
        alpha = ((mu - a) * (2*b - a - c)) / ((b - mu) * (c - a));
        beta_param = alpha * (c - mu) / (mu - a);
    end
    
    % Beta distributed random variables and scale to [a, c]
    r = betarnd(alpha, beta_param, [n, 1]);
    samples = a + r .* (c - a);
end
