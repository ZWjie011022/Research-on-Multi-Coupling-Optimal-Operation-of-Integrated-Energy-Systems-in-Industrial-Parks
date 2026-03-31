clear; clc;
% =========================================================================
% 园区综合能源系统 - 数据驱动分布鲁棒优化 (DRO)
% 核心方法：蒙特卡洛模拟 + 1-范数模糊集 + 单层对偶转化 (Extensive Form)
% =========================================================================

%% 1. 基础数据准备 (秋季典型日)
Load_E = [3080.5, 2620.2, 2460.8, 2390.6, 2530.3, 2580.7, 2660.5, 3080.4, 3220.6, 3960.8, 4150.3, 4120.9, 3980.5, 4450.6, 4280.2, 4830.8, 5410.4, 5680.7, 6150.6, 5260.3, 5350.8, 4580.5, 4280.2, 3280.7]';
Load_H = [5180.5, 4980.2, 4780.8, 4380.6, 4520.3, 4880.5, 8180.2, 7180.8, 5950.5, 4180.3, 3080.6, 2450.2, 2080.8, 1980.5, 2120.3, 3050.6, 3980.5, 5150.8, 6250.2, 7380.5, 7680.8, 7980.3, 6850.6, 5980.2]';
Load_C = [180.5, 120.3, 80.6, 60.2, 90.5, 250.8, 380.4, 620.6, 980.3, 1780.5, 2580.8, 3080.3, 3380.6, 3420.2, 2950.5, 2480.8, 1680.3, 1080.6, 580.2, 380.5, 280.8, 220.3, 180.6, 150.5]';
Load_DC = 1.25*[645.8 715.4 662.0 779.0 1036.6 875.7 875.0 757.3 873.6 818.2 1112.4 1135.5 979.3 1149.7 1123.3 746.5 971.1 672.8 678.1 703.2 1087.4 986.7 739.7 1021.9]';

T_out = [7.2, 6.5, 6.0, 5.7, 6.1, 7.5, 9.3, 11.6, 13.8, 15.5, 16.7, 17.4, 17.8, 18.1, 17.4, 15.9, 13.9, 11.7, 10.0, 8.8, 8.1, 7.7, 7.4, 7.2]';
price = [0.29, 0.29, 0.29, 0.29, 0.29, 0.29, 0.6, 0.6, 0.95, 0.95, 0.95, 0.6, 0.6, 0.6, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.6, 0.29, 0.29]';
W_unit_pred  = [0.502, 0.456, 0.389, 0.351, 0.358, 0.408, 0.416, 0.356, 0.477, 0.387, 0.202, 0.080, 0.017, 0.001, 0.000, 0.000, 0.000, 0.010, 0.073, 0.305, 0.428, 0.377, 0.316, 0.354]';
PV_unit_pred = [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.048, 0.168, 0.357, 0.564, 0.674, 0.677, 0.656, 0.634, 0.556, 0.444, 0.298, 0.141, 0.000, 0.000, 0.000, 0.000, 0.000]';

% 设备容量及效率
V_pv = 16000; V_wind = 18000; V_ES = 5500; V_HS = 14000; 
V_EL = 2000;  V_HFC = 1000; V_EB = 11000; V_EC = 2500; V_AC = 1200;
P_grid_max = 10000; 
yita_ES=0.9; yita_HS=0.9; yita_EB=0.95; yita_EL=0.6; yita_EC=3.89; yita_AC=0.8; yita_HFC_total = 0.9;

% 运维成本系数
K_pv=0.04; K_wind=0.091; K_EB=0.05; K_EL=0.016; K_EC=0.1; K_AC=0.015;
K_ES_om=0.08; K_HS_om=0.016; K_HFC_om=0.033; 

% 需求响应参数
c_shift_E = 0.15; c_cut_E = 0.30; c_shift_H = 0.10; c_cut_H = 0.20;
c_shift_C = 0.10; c_cut_C = 0.20; c_shift_DC = 0.2;
alpha_shift = 0.15; beta_cut = 0.05; 

%% 2. 改进的蒙特卡洛场景生成 (消除零点截断偏差)
N_scen = 50; % 适当增加场景数以稳定期望值
rng(2026);   

P_pv_pred = V_pv * PV_unit_pred; 
P_wind_pred = V_wind * W_unit_pred;

u_wind_scen = zeros(24, N_scen);
u_pv_scen = zeros(24, N_scen);

for s = 1:N_scen
    % 改进逻辑：误差与预测值本身成正比。如果预测为0，则绝对没有误差(夜间无光伏)。
    % 这样可以保证生成的场景均值严格对齐原始预测值。
    error_wind = 0.10 * P_wind_pred .* randn(24,1); 
    error_pv = 0.10 * P_pv_pred .* randn(24,1);     
    
    w = P_wind_pred + error_wind;
    p = P_pv_pred + error_pv;
    
    % 截断依然需要，但因为0点没有波动，所以不会再产生正向偏误
    u_wind_scen(:,s) = max(0, min(V_wind, w));
    u_pv_scen(:,s) = max(0, min(V_pv, p));
end

% DRO 模糊集参数
theta = 2.2; % 将模糊半径调小，先观察退化为随机规划(SP)时的基准成本
q_0 = ones(N_scen, 1) / N_scen;


%% 3. 第一阶段变量 (日前确定)
P_E_sl_in = sdpvar(24,1); P_E_sl_out = sdpvar(24,1); P_E_cut = sdpvar(24,1);
P_H_sl_in = sdpvar(24,1); P_H_sl_out = sdpvar(24,1); P_H_cut = sdpvar(24,1);
P_C_sl_in = sdpvar(24,1); P_C_sl_out = sdpvar(24,1); P_C_cut = sdpvar(24,1);
P_DC_delay1 = sdpvar(24,1); P_DC_delay2 = sdpvar(24,1); Load_DC_opt = sdpvar(24,1);

U_ES_ch = binvar(24,1); U_ES_dis = binvar(24,1); 
U_HS_ch = binvar(24,1); U_HS_dis = binvar(24,1); 

Cost_1st_DR = sum(c_shift_E*P_E_sl_in + c_cut_E*P_E_cut) + sum(c_shift_H*P_H_sl_in + c_cut_H*P_H_cut) + ...
              sum(c_shift_C*P_C_sl_in + c_cut_C*P_C_cut) + sum(c_shift_DC*(P_DC_delay1 + P_DC_delay2));

Constraints = [
    0 <= P_E_sl_in <= alpha_shift*Load_E, 0 <= P_E_sl_out <= alpha_shift*Load_E, 0 <= P_E_cut <= beta_cut*Load_E, sum(P_E_sl_in) == sum(P_E_sl_out),
    0 <= P_H_sl_in <= alpha_shift*Load_H, 0 <= P_H_sl_out <= alpha_shift*Load_H, 0 <= P_H_cut <= beta_cut*Load_H, sum(P_H_sl_in) == sum(P_H_sl_out),
    0 <= P_C_sl_in <= alpha_shift*Load_C, 0 <= P_C_sl_out <= alpha_shift*Load_C, 0 <= P_C_cut <= beta_cut*Load_C, sum(P_C_sl_in) == sum(P_C_sl_out),
    0 <= P_DC_delay1, 0 <= P_DC_delay2, (P_DC_delay1 + P_DC_delay2) <= 0.30 * Load_DC,
    Load_DC_opt(1) == Load_DC(1) - P_DC_delay1(1) - P_DC_delay2(1) + P_DC_delay1(24) + P_DC_delay2(23),
    Load_DC_opt(2) == Load_DC(2) - P_DC_delay1(2) - P_DC_delay2(2) + P_DC_delay1(1) + P_DC_delay2(24)
];
for t = 3:24
    Constraints = [Constraints, Load_DC_opt(t) == Load_DC(t) - P_DC_delay1(t) - P_DC_delay2(t) + P_DC_delay1(t-1) + P_DC_delay2(t-2)];
end
Constraints = [Constraints, U_ES_ch + U_ES_dis <= 1, U_HS_ch + U_HS_dis <= 1];

Load_E_DR = Load_E + P_E_sl_in - P_E_sl_out - P_E_cut;
Load_H_DR = Load_H + P_H_sl_in - P_H_sl_out - P_H_cut;
Load_C_DR = Load_C + P_C_sl_in - P_C_sl_out - P_C_cut;
Load_DC_waste_opt = 0.59 * Load_DC_opt;

%% 4. 分布鲁棒对偶转化 (定义每个场景的第二阶段变量)
% DRO 对偶变量
lambda_dro = sdpvar(1,1);
mu_dro = sdpvar(1,1);
alpha_plus = sdpvar(N_scen, 1);
alpha_minus = sdpvar(N_scen, 1);

Constraints = [Constraints, mu_dro >= 0, alpha_plus >= 0, alpha_minus >= 0];

% 构建二维矩阵变量存储每个场景的决策: size = [24, N_scen]
p_es_ch = sdpvar(24, N_scen); p_es_dis = sdpvar(24, N_scen); es_soc = sdpvar(24, N_scen);
p_hs_ch = sdpvar(24, N_scen); p_hs_dis = sdpvar(24, N_scen); hs_soc = sdpvar(24, N_scen);
p_el = sdpvar(24, N_scen); p_hfc_e = sdpvar(24, N_scen); p_hfc_h = sdpvar(24, N_scen);
p_grid = sdpvar(24, N_scen); p_eb = sdpvar(24, N_scen); p_ec = sdpvar(24, N_scen);
p_ac_h = sdpvar(24, N_scen); p_ac_dc = sdpvar(24, N_scen); p_ac_cool = sdpvar(24, N_scen); p_ac_dccool = sdpvar(24, N_scen);
p_ec_cool = sdpvar(24, N_scen); p_ec_dc = sdpvar(24, N_scen); t_in = sdpvar(24, N_scen); 
p_pv = sdpvar(24, N_scen); p_wind = sdpvar(24, N_scen);

Cost_2nd_array = sdpvar(N_scen, 1);

disp('🚀 正在构建 DRO 单层对偶模型...');
for s = 1:N_scen
    % 提取第 s 个场景的变量和参数
    u_p = u_pv_scen(:, s); u_w = u_wind_scen(:, s);
    p_es_ch_s = p_es_ch(:,s); p_es_dis_s = p_es_dis(:,s); es_soc_s = es_soc(:,s);
    p_hs_ch_s = p_hs_ch(:,s); p_hs_dis_s = p_hs_dis(:,s); hs_soc_s = hs_soc(:,s);
    p_el_s = p_el(:,s); p_hfc_e_s = p_hfc_e(:,s); p_hfc_h_s = p_hfc_h(:,s);
    p_grid_s = p_grid(:,s); p_eb_s = p_eb(:,s); p_ec_s = p_ec(:,s);
    p_ac_h_s = p_ac_h(:,s); p_ac_dc_s = p_ac_dc(:,s); p_ac_cool_s = p_ac_cool(:,s); p_ac_dccool_s = p_ac_dccool(:,s);
    p_ec_cool_s = p_ec_cool(:,s); p_ec_dc_s = p_ec_dc(:,s); t_in_s = t_in(:,s);
    p_pv_s = p_pv(:,s); p_wind_s = p_wind(:,s);
    
    % 添加第 s 个场景的运行物理约束
    Constraints = [Constraints,
        0 <= p_pv_s <= u_p, 0 <= p_wind_s <= u_w, 
        0 <= p_es_ch_s <= U_ES_ch .* 0.5 .* V_ES, 0 <= p_es_dis_s <= U_ES_dis .* 0.5 .* V_ES,
        es_soc_s(2:24) == es_soc_s(1:23) + p_es_ch_s(2:24)*yita_ES - p_es_dis_s(2:24)/yita_ES,
        es_soc_s(1) == 0.3*V_ES + p_es_ch_s(1)*yita_ES - p_es_dis_s(1)/yita_ES, es_soc_s(24) == 0.3*V_ES, 0.1*V_ES <= es_soc_s <= 0.9*V_ES,
        
        0 <= p_hs_ch_s <= U_HS_ch .* 10^6, 0 <= p_hs_dis_s <= U_HS_dis .* 10^6,
        p_el_s == p_hs_ch_s / yita_EL, p_el_s <= V_EL,
        hs_soc_s(2:24) == hs_soc_s(1:23) + p_hs_ch_s(2:24)*yita_HS - p_hs_dis_s(2:24)/yita_HS,
        hs_soc_s(1) == 0.5*V_HS + p_hs_ch_s(1)*yita_HS - p_hs_dis_s(1)/yita_HS, hs_soc_s(24) == 0.5*V_HS, 0.05*V_HS <= hs_soc_s <= 0.95*V_HS,
        
        p_hfc_e_s + p_hfc_h_s <= yita_HFC_total * p_hs_dis_s, p_hfc_e_s >= 0.7 * p_hfc_h_s, p_hfc_e_s <= 2 * p_hfc_h_s, p_hfc_e_s <= V_HFC,
        
        0<=p_grid_s<=P_grid_max, 0<=p_eb_s<=V_EB, 0<=p_ec_s<=V_EC,
        p_ac_h_s>=0, p_ac_dc_s>=0, p_ac_dc_s<=Load_DC_waste_opt, p_ac_cool_s>=0, p_ac_dccool_s>=0, p_ec_cool_s>=0, p_ec_dc_s>=0,
        p_ac_h_s + p_ac_dc_s <= V_AC, p_ec_s*yita_EC == p_ec_cool_s + p_ec_dc_s, p_ac_cool_s + p_ac_dccool_s == yita_AC*(p_ac_dc_s + p_ac_h_s),
        t_in_s(2:24) == t_in_s(1:23)*exp(-1) + (0.04*(Load_DC_waste_opt(1:23) - p_ac_dc_s(1:23) - p_ec_dc_s(1:23) - p_ac_dccool_s(1:23)) + T_out(1:23))*(1-exp(-1)),
        t_in_s(1) == t_in_s(24)*exp(-1) + (0.04*(Load_DC_waste_opt(24) - p_ac_dc_s(24) - p_ec_dc_s(24) - p_ac_dccool_s(24)) + T_out(24))*(1-exp(-1)),
        17.78 <= t_in_s <= 27.22,
        
        p_ec_cool_s + p_ac_cool_s >= Load_C_DR,
        p_eb_s*yita_EB + p_hfc_h_s >= Load_H_DR + p_ac_h_s,
        p_grid_s + p_pv_s + p_wind_s + p_es_dis_s + p_hfc_e_s >= Load_E_DR + Load_DC_opt + p_es_ch_s + p_el_s + p_eb_s + p_ec_s
    ];
    
    % 第 s 个场景的运维及惩罚成本
    Cost_Uncertainty_s = sum(K_wind*p_wind_s + K_pv*p_pv_s);
    Cost_om_SP_s = sum(K_ES_om*p_es_dis_s + K_HS_om*p_hs_dis_s + K_HFC_om*(p_hfc_e_s+p_hfc_h_s)) + sum(K_EL*p_el_s*yita_EL + K_EB*p_eb_s*yita_EB + K_EC*p_ec_s*yita_EC + K_AC*(p_ac_dc_s+p_ac_cool_s));
    Cost_2nd_s = sum(price .* p_grid_s) + Cost_Uncertainty_s + Cost_om_SP_s;
    
    Constraints = [Constraints, Cost_2nd_array(s) == Cost_2nd_s];
    
    % ================= 核心：DRO 概率分布的最恶劣对偶约束 =================
    Constraints = [Constraints,
        lambda_dro + alpha_plus(s) - alpha_minus(s) >= Cost_2nd_s,
        alpha_plus(s) + alpha_minus(s) <= mu_dro
    ];
end

% 单层模型目标函数 = 第一阶段成本 + DRO对偶推导后的第二阶段最恶劣期望成本
DRO_Objective = Cost_1st_DR + lambda_dro + theta * mu_dro + sum(q_0 .* (alpha_plus - alpha_minus));

%% 5. 一键求解
ops_sol = sdpsettings('solver', 'gurobi', 'verbose', 2, 'gurobi.MIPGap', 1e-4);
disp('开始调用 Gurobi 求解单层 DRO 模型...');
sol = optimize(Constraints, DRO_Objective, ops_sol);

if sol.problem ~= 0
    error('求解失败，请检查约束冲突或 Gurobi 状态！');
end

% 提取结果：寻找带来最大成本的最恶劣场景，用于绘图展示
Cost_2nd_val = value(Cost_2nd_array);
[~, worst_s] = max(Cost_2nd_val);
fprintf('✅ 求解成功！最恶劣成本出现在场景 %d\n', worst_s);
fprintf('总运行成本 (DRO): %.2f 元\n', value(DRO_Objective));

% 提取日前确定性变量
L_E_DR_star = value(Load_E_DR); L_H_DR_star = value(Load_H_DR); L_C_DR_star = value(Load_C_DR);
L_DC_opt_star = value(Load_DC_opt);

%% 6. 绘图模块 (展示蒙特卡洛场景与 DRO 最恶劣场景调度)
t = 1:24; c_blue = [0.000, 0.447, 0.741]; c_orange = [0.850, 0.325, 0.098];

% --- 图1：蒙特卡洛风光场景展示 ---
figure('Color', 'w', 'Position', [100, 100, 900, 600], 'Name', 'DRO蒙特卡洛风光场景');
subplot(2,1,1); hold on;
for s = 1:N_scen, plot(t, u_wind_scen(:,s), 'Color', [0.7 0.7 0.7 0.5], 'LineWidth', 1); end
plot(t, P_wind_pred, '--', 'Color', 'k', 'LineWidth', 2);
plot(t, u_wind_scen(:, worst_s), '-o', 'Color', c_blue, 'LineWidth', 2, 'MarkerFaceColor','w');
ylabel('功率/kW'); xlim([1 24]); grid on; title('风电蒙特卡洛场景 (灰) 与 最恶劣分布场景 (蓝)');
legend('蒙特卡洛场景', '日前预测', 'DRO定位最恶劣场景');

subplot(2,1,2); hold on;
for s = 1:N_scen, plot(t, u_pv_scen(:,s), 'Color', [0.7 0.7 0.7 0.5], 'LineWidth', 1); end
plot(t, P_pv_pred, '--', 'Color', 'k', 'LineWidth', 2);
plot(t, u_pv_scen(:, worst_s), '-s', 'Color', c_orange, 'LineWidth', 2, 'MarkerFaceColor','w');
ylabel('功率/kW'); xlabel('时段/h'); xlim([1 24]); grid on; title('光伏蒙特卡洛场景 (灰) 与 最恶劣分布场景 (橙)');

% --- 图2：DRO 最恶劣场景下的系统功率平衡 (提取 worst_s 的数据) ---
figure('Color', 'w', 'Position', [150, 150, 1200, 800], 'Name', 'DRO最恶劣场景功率平衡');
subplot(2,2,1);
Supply_E = [value(p_grid(:,worst_s)), value(p_pv(:,worst_s)), value(p_wind(:,worst_s)), value(p_es_dis(:,worst_s)), value(p_hfc_e(:,worst_s))];
Consume_E = [-value(p_es_ch(:,worst_s)), -value(p_ec(:,worst_s)), -value(p_el(:,worst_s)), -value(p_eb(:,worst_s))];
bar(t, Supply_E, 0.8, 'stacked', 'EdgeColor', 'none'); hold on; bar(t, Consume_E, 0.8, 'stacked', 'EdgeColor', 'none');
plot(t, L_E_DR_star + L_DC_opt_star, 'k-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
title(['电功率互联平衡 (基于最恶劣场景 ' num2str(worst_s) ')']); xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); grid on;
legend('购电','光伏','风电','储能放电','氢产电','储能充电','电制冷','电解槽','电锅炉','总电负荷','Location','southoutside','NumColumns',5);

subplot(2,2,2);
Supply_H = [value(p_eb(:,worst_s))*yita_EB, value(p_hfc_h(:,worst_s))]; Consume_H = [-value(p_ac_h(:,worst_s))];
bar(t, Supply_H, 0.8, 'stacked', 'EdgeColor', 'none'); hold on; bar(t, Consume_H, 0.8, 'FaceColor', '#D95319', 'EdgeColor', 'none');
plot(t, L_H_DR_star, 'r-^', 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
title('热功率互联平衡'); xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); grid on;

subplot(2,2,3);
Supply_C = [value(p_ec_cool(:,worst_s)), value(p_ac_cool(:,worst_s))];
bar(t, Supply_C, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
plot(t, L_C_DR_star, 'b-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
title('冷功率互联平衡'); xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); grid on;

subplot(2,2,4); yyaxis left;
plot(t, value(es_soc(:,worst_s)) / V_ES, '-s', 'LineWidth', 1.5, 'Color', c_blue, 'MarkerFaceColor', 'w');
ylabel('电储能 SOC', 'Color', c_blue); ylim([0 1]); set(gca, 'YColor', c_blue); 
yyaxis right;
plot(t, value(t_in(:,worst_s)), '-d', 'LineWidth', 1.5, 'Color', c_orange, 'MarkerFaceColor', 'w');
ylabel('DC内温/°C', 'Color', c_orange); ylim([15 30]); set(gca, 'YColor', c_orange);
yline(27.22, '--r'); yline(17.78, '--b');
title('储能协同与DC虚拟储能'); xlabel('时间/h'); xlim([0.5 24.5]); grid on;


% ── 图5：需求响应结果（四维全息）────────────────────────────────────
figure('Color','w','Position',[50,50,1500,450],'Name','图5_四维全息需求响应');
sgtitle('秋季 DD-DRO：四维全息综合需求响应分析','FontSize',14,'FontWeight','bold');
t_ax = 1:24;
% 配色方案（SCI 风格）
c_blue   = [0.000, 0.447, 0.741];
c_orange = [0.850, 0.325, 0.098];
c_yellow = [0.929, 0.694, 0.125];
c_green  = [0.466, 0.674, 0.188];
c_cyan   = [0.301, 0.745, 0.933];
c_red    = [0.635, 0.078, 0.184];
c_purple = [0.494, 0.184, 0.556];
c_gray   = [0.850, 0.850, 0.850];
c_brown  = [0.549, 0.337, 0.294];

subplot(1,4,1);
plot(t_ax,Load_E,'k--','LineWidth',2); hold on;
plot(t_ax,L_E_DR_star,'Color',c_blue,'LineWidth',2.5);
bar(t_ax,value(P_E_sl_in), 'FaceColor',c_green, 'EdgeColor','none','FaceAlpha',0.65);
bar(t_ax,-value(P_E_sl_out),'FaceColor',c_yellow,'EdgeColor','none','FaceAlpha',0.65);
bar(t_ax,-value(P_E_cut),  'FaceColor',c_red,   'EdgeColor','none','FaceAlpha',0.65);
title('电负荷需求响应','FontSize',12,'FontWeight','bold');
xlabel('时间/h','FontSize',10); ylabel('功率/kW','FontSize',10);
xlim([0.5,24.5]); grid on; box on;
legend('原始预测负荷','优化响应负荷','负荷转入','负荷转出','负荷削减', ...
    'Location','southoutside','NumColumns',2,'FontSize',8);

subplot(1,4,2);
plot(t_ax,Load_H,'k--','LineWidth',2); hold on;
plot(t_ax,L_H_DR_star,'Color',c_orange,'LineWidth',2.5);
bar(t_ax,value(P_H_sl_in), 'FaceColor',c_green, 'EdgeColor','none','FaceAlpha',0.65);
bar(t_ax,-value(P_H_sl_out),'FaceColor',c_yellow,'EdgeColor','none','FaceAlpha',0.65);
bar(t_ax,-value(P_H_cut),  'FaceColor',c_blue,  'EdgeColor','none','FaceAlpha',0.65);
title('热负荷需求响应','FontSize',12,'FontWeight','bold');
xlabel('时间/h','FontSize',10); ylabel('功率/kW','FontSize',10);
xlim([0.5,24.5]); grid on; box on;
legend('原始预测负荷','优化响应负荷','负荷转入','负荷转出','负荷削减', ...
    'Location','southoutside','NumColumns',2,'FontSize',8);

subplot(1,4,3);
plot(t_ax,Load_C,'k--','LineWidth',2); hold on;
plot(t_ax,L_C_DR_star,'Color',c_cyan,'LineWidth',2.5);
bar(t_ax,value(P_C_sl_in), 'FaceColor',c_green, 'EdgeColor','none','FaceAlpha',0.65);
bar(t_ax,-value(P_C_sl_out),'FaceColor',c_yellow,'EdgeColor','none','FaceAlpha',0.65);
bar(t_ax,-value(P_C_cut),  'FaceColor',c_purple,'EdgeColor','none','FaceAlpha',0.65);
title('冷负荷需求响应','FontSize',12,'FontWeight','bold');
xlabel('时间/h','FontSize',10); ylabel('功率/kW','FontSize',10);
xlim([0.5,24.5]); grid on; box on;
legend('原始预测负荷','优化响应负荷','负荷转入','负荷转出','负荷削减', ...
    'Location','southoutside','NumColumns',2,'FontSize',8);

subplot(1,4,4);
yyaxis left;
Shift_out = value(P_DC_delay1+P_DC_delay2);
Shift_in  = L_DC_opt_star - Load_DC + Shift_out;
bar(t_ax,Shift_in, 'FaceColor',c_green, 'EdgeColor','none','BarWidth',0.6,'FaceAlpha',0.8); hold on;
bar(t_ax,-Shift_out,'FaceColor',c_yellow,'EdgeColor','none','BarWidth',0.6,'FaceAlpha',0.8);
ylabel('时空延迟转移量/kW','FontSize',10);
ylim([-max(Load_DC)*0.4, max(Load_DC)*0.4]);
ax=gca; ax.YColor=c_blue;
yyaxis right;
plot(t_ax,Load_DC,'k--','LineWidth',2); hold on;
plot(t_ax,L_DC_opt_star,'-s','Color',c_purple,'LineWidth',2.5,'MarkerFaceColor','w','MarkerSize',5);
ylabel('数据中心算力功率/kW','FontSize',10);
ylim([min(Load_DC)*0.6, max(Load_DC)*1.2]);
ax=gca; ax.YColor=c_orange;
title('数据中心延迟响应 (DCDR)','FontSize',12,'FontWeight','bold');
xlabel('时间/h','FontSize',10); xlim([0.5,24.5]); grid on; box on;
legend('算力转入','算力延迟转出','原始基础算力','最终优化算力', ...
    'Location','southoutside','NumColumns',2,'FontSize',8);

