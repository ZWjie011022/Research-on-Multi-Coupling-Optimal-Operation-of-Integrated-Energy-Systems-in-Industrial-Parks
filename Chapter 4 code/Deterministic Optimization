clear; clc;
% =========================================================================
% 园区综合能源系统 单日确定性运行优化 (秋季典型日 - 无碳排放版)
% 特色包含：
% 1. 电、热、冷综合需求响应 (平移 + 削减)
% 2. 数据中心 (DC) 虚拟储能与精细化温控
% 3. 氢能系统与电热灵活耦合 (HFC动态电热比)
% 4. 纯经济驱动，剔除碳交易机制
% =========================================================================

%% 1. 基础数据准备 (秋季典型日)
Load_E = [3080.5, 2620.2, 2460.8, 2390.6, 2530.3, 2580.7, 2660.5, 3080.4, 3220.6, 3960.8, 4150.3, 4120.9, 3980.5, 4450.6, 4280.2, 4830.8, 5410.4, 5680.7, 6150.6, 5260.3, 5350.8, 4580.5, 4280.2, 3280.7]';
Load_H = [5180.5, 4980.2, 4780.8, 4380.6, 4520.3, 4880.5, 8180.2, 7180.8, 5950.5, 4180.3, 3080.6, 2450.2, 2080.8, 1980.5, 2120.3, 3050.6, 3980.5, 5150.8, 6250.2, 7380.5, 7680.8, 7980.3, 6850.6, 5980.2]';
Load_C = [180.5, 120.3, 80.6, 60.2, 90.5, 250.8, 380.4, 620.6, 980.3, 1780.5, 2580.8, 3080.3, 3380.6, 3420.2, 2950.5, 2480.8, 1680.3, 1080.6, 580.2, 380.5, 280.8, 220.3, 180.6, 150.5]';

% 数据中心负荷与气象数据
Load_DC = 1.25*[645.8 715.4 662.0 779.0 1036.6 875.7 875.0 757.3 873.6 818.2 1112.4 1135.5 979.3 1149.7 1123.3 746.5 971.1 672.8 678.1 703.2 1087.4 986.7 739.7 1021.9]';
Load_DC_waste = 0.59 * Load_DC;

% =========================================================================
% 【宁夏中卫真实气象数据 (秋季)】
% =========================================================================
T_out = [7.2, 6.5, 6.0, 5.7, 6.1, 7.5, 9.3, 11.6, 13.8, 15.5, 16.7, 17.4, 17.8, 18.1, 17.4, 15.9, 13.9, 11.7, 10.0, 8.8, 8.1, 7.7, 7.4, 7.2]';
W_unit_pred  = [0.502, 0.456, 0.389, 0.351, 0.358, 0.408, 0.416, 0.356, 0.477, 0.387, 0.202, 0.080, 0.017, 0.001, 0.000, 0.000, 0.000, 0.010, 0.073, 0.305, 0.428, 0.377, 0.316, 0.354]';
PV_unit_pred = [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.048, 0.168, 0.357, 0.564, 0.674, 0.677, 0.656, 0.634, 0.556, 0.444, 0.298, 0.141, 0.000, 0.000, 0.000, 0.000, 0.000]';

price = [0.29, 0.29, 0.29, 0.29, 0.29, 0.29, 0.6, 0.6, 0.95, 0.95, 0.95, 0.6, 0.6, 0.6, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.6, 0.29, 0.29]';

% =========================================================================
% ★ 容量配置结果 (提取自完全体模型的最优解) ★
% =========================================================================
V_pv = 16000; V_wind = 18000; V_ES = 5500; V_HS = 14000; 
V_EL = 2000;  V_HFC = 1000; V_EB = 11000; V_EC = 2500; V_AC = 1200;

% 设备参数设定
yita_ES=0.9; yita_HS=0.9; yita_EB=0.95; yita_EL=0.6; yita_EC=3.89; yita_AC=0.8;
yita_HFC_total = 0.9; % HFC 灵活电热比总效率

K_pv=0.04; K_wind=0.091; K_ES=0.08; K_HS=0.016; K_EB=0.05; K_EL=0.016; K_HFC=0.033; K_EC=0.1; K_AC=0.015;

% 预测出力边界
P_pv_max = V_pv * PV_unit_pred;
P_wind_max = V_wind * W_unit_pred;

% 电网交互上限约束 (可根据实际情况调整)
P_grid_max = 10000; 

%% 2. 变量定义
% 系统运行变量
P_grid = sdpvar(24,1); P_pv = sdpvar(24,1); P_wind = sdpvar(24,1);
P_ES_ch = sdpvar(24,1); P_ES_dis = sdpvar(24,1); ES = sdpvar(24,1);
P_HS_ch = sdpvar(24,1); P_HS_dis = sdpvar(24,1); HS = sdpvar(24,1);
U_ES_char = binvar(24,1); U_HS_char = binvar(24,1); 

P_EL = sdpvar(24,1); P_HFC_e = sdpvar(24,1); P_HFC_h = sdpvar(24,1);
P_EB = sdpvar(24,1); P_EC = sdpvar(24,1); P_EC_cool = sdpvar(24,1); P_EC_DC = sdpvar(24,1);
P_AC_h = sdpvar(24,1); P_AC_DC = sdpvar(24,1); P_AC_cool = sdpvar(24,1); P_AC_DCcool = sdpvar(24,1);
T_in = sdpvar(24,1);

% 综合需求响应 (IDR) 变量
P_E_sl_in = sdpvar(24,1); P_E_sl_out = sdpvar(24,1); P_E_cut = sdpvar(24,1);
P_H_sl_in = sdpvar(24,1); P_H_sl_out = sdpvar(24,1); P_H_cut = sdpvar(24,1);
P_C_sl_in = sdpvar(24,1); P_C_sl_out = sdpvar(24,1); P_C_cut = sdpvar(24,1);

% 需求响应补偿价格 (元/kWh)
c_shift_E = 0.15; c_cut_E = 0.30;
c_shift_H = 0.10; c_cut_H = 0.20;
c_shift_C = 0.10; c_cut_C = 0.20;

% 响应比例上限
alpha_shift = 0.15; % 最大可平移比例 15%
beta_cut    = 0.05; % 最大可削减比例 5%

%% 3. 约束条件
C = [];

% (1) 需求响应 (IDR) 约束
C = [C, ...
    0 <= P_E_sl_in <= alpha_shift * Load_E, 0 <= P_E_sl_out <= alpha_shift * Load_E, 0 <= P_E_cut <= beta_cut * Load_E,
    0 <= P_H_sl_in <= alpha_shift * Load_H, 0 <= P_H_sl_out <= alpha_shift * Load_H, 0 <= P_H_cut <= beta_cut * Load_H,
    0 <= P_C_sl_in <= alpha_shift * Load_C, 0 <= P_C_sl_out <= alpha_shift * Load_C, 0 <= P_C_cut <= beta_cut * Load_C,
    sum(P_E_sl_in) == sum(P_E_sl_out), % 平移负荷总量守恒
    sum(P_H_sl_in) == sum(P_H_sl_out),
    sum(P_C_sl_in) == sum(P_C_sl_out)
];

% 响应后的实际负荷
Load_E_DR = Load_E + P_E_sl_in - P_E_sl_out - P_E_cut;
Load_H_DR = Load_H + P_H_sl_in - P_H_sl_out - P_H_cut;
Load_C_DR = Load_C + P_C_sl_in - P_C_sl_out - P_C_cut;

% (2) 基础设备约束
C = [C, ...
    0 <= P_grid <= P_grid_max, 
    0 <= P_pv <= P_pv_max, 0 <= P_wind <= P_wind_max,
    0 <= P_EB <= V_EB, 0 <= P_EC <= V_EC, 0 <= P_EL <= V_EL,
    0 <= P_AC_h, 0 <= P_AC_DC <= Load_DC_waste, 0 <= P_AC_cool, 0 <= P_AC_DCcool,
    0 <= P_EC_cool, 0 <= P_EC_DC,
    P_AC_h + P_AC_DC <= V_AC,
    P_EC * yita_EC == P_EC_cool + P_EC_DC, 
    P_AC_cool + P_AC_DCcool == yita_AC * (P_AC_DC + P_AC_h)
];

% 燃料电池出力映射 【核心修改：对齐完全体灵活电热比逻辑】
C = [C, ...
    P_HFC_e + P_HFC_h <= yita_HFC_total * P_HS_dis, ...
    P_HFC_e >= 0.7 * P_HFC_h, ...
    P_HFC_e <= 2 * P_HFC_h, ...
    P_HFC_e <= V_HFC
];

% (3) 储能系统约束 (电储能)
C = [C, ...
    0 <= P_ES_ch <= U_ES_char * 0.5 * V_ES, 
    0 <= P_ES_dis <= (1 - U_ES_char) * 0.5 * V_ES,
    ES(2:24) == ES(1:23) + P_ES_ch(2:24)*yita_ES - P_ES_dis(2:24)/yita_ES,
    ES(1) == 0.3*V_ES + P_ES_ch(1)*yita_ES - P_ES_dis(1)/yita_ES, ES(24) == 0.3*V_ES,
    0.1*V_ES <= ES <= 0.9*V_ES
];

% 储能系统约束 (日内氢储能)
C = [C, ...
    P_EL == P_HS_ch / yita_EL,
    0 <= P_HS_ch <= U_HS_char * 10^6, 
    0 <= P_HS_dis <= (1 - U_HS_char) * 10^6,
    HS(2:24) == HS(1:23) + P_HS_ch(2:24)*yita_HS - P_HS_dis(2:24)/yita_HS,
    HS(1) == 0.5*V_HS + P_HS_ch(1)*yita_HS - P_HS_dis(1)/yita_HS, HS(24) == 0.5*V_HS, % 日内模型首末SOC一致
    0.05*V_HS <= HS <= 0.95*V_HS
];

% (4) 数据中心 (DC) 热力学温控约束
C = [C, ...
    T_in(2:24) == T_in(1:23)*exp(-1) + (0.04*(Load_DC_waste(1:23) - P_AC_DC(1:23) - P_EC_DC(1:23) - P_AC_DCcool(1:23)) + T_out(1:23))*(1-exp(-1)),
    T_in(1) == T_in(24)*exp(-1) + (0.04*(Load_DC_waste(24) - P_AC_DC(24) - P_EC_DC(24) - P_AC_DCcool(24)) + T_out(24))*(1-exp(-1)),
    17.78 <= T_in <= 27.22
];

% (5) 功率平衡约束 【核心修改：放宽为 >=，允许合理弃风弃光】
C = [C, ...
    % 电平衡
    P_grid + P_pv + P_wind + P_ES_dis + P_HFC_e >= Load_E_DR + Load_DC + P_ES_ch + P_EL + P_EB + P_EC,
    % 热平衡
    P_EB*yita_EB + P_HFC_h >= Load_H_DR + P_AC_h,
    % 冷平衡
    P_EC_cool + P_AC_cool >= Load_C_DR
];


%% 4. 目标函数设定 (纯经济优化)
% 1. 购电成本
Cost_grid = sum(price .* P_grid);
% 2. 运维成本
Cost_om = sum(K_wind*P_wind_max + K_pv*P_pv_max + K_ES*P_ES_dis + K_HS*P_HS_dis + K_EB*P_EB*yita_EB + K_EL*P_EL*yita_EL + K_HFC*(P_HFC_e+P_HFC_h) + K_EC*P_EC*yita_EC + K_AC*(P_AC_DC+P_AC_cool));
% 3. 需求响应补偿成本
Cost_DR = sum(c_shift_E*P_E_sl_in + c_cut_E*P_E_cut) + ...
          sum(c_shift_H*P_H_sl_in + c_cut_H*P_H_cut) + ...
          sum(c_shift_C*P_C_sl_in + c_cut_C*P_C_cut);

% 总目标函数
Objective = Cost_grid + Cost_om + Cost_DR;

%% 5. 求解模型
ops = sdpsettings('solver','gurobi','verbose', 0);
sol = optimize(C, Objective, ops);

if sol.problem == 0
    fprintf('\n========== 运行优化求解成功 ==========\n');
    fprintf('日总运行成本: %.2f 元\n', value(Objective));
    fprintf('  |- 主网购电成本: %.2f 元\n', value(Cost_grid));
    fprintf('  |- 设备运维成本: %.2f 元\n', value(Cost_om));
    fprintf('  |- 需求响应补偿: %.2f 元\n', value(Cost_DR));
    
    % 计算弃风弃光
    curtail_pv = sum(P_pv_max - value(P_pv));
    curtail_wind = sum(P_wind_max - value(P_wind));
    fprintf('\n========== 新能源消纳 ==========\n');
    fprintf('  |- 弃光量: %.2f kWh\n', curtail_pv);
    fprintf('  |- 弃风量: %.2f kWh\n', curtail_wind);
else
    disp('优化求解失败，请检查约束！');
end

%% 7. 四维全息综合需求响应分析 (完整平移+削减+延迟版，SCI出版级风格)
t = 1:24;
figure('Color', 'w', 'Position', [50, 50, 1400, 450], 'Name', '四维全息综合需求响应分析');

% =========================================================================
% 学术论文风格配色 (SCI风格)
% =========================================================================
c_blue   = [0.00 0.45 0.74];
c_red    = [0.85 0.33 0.10];
c_orange = [0.93 0.69 0.13];
c_green  = [0.47 0.67 0.19];
c_cyan   = [0.30 0.75 0.93];
c_yellow = [0.95 0.85 0.25];
c_purple = [0.49 0.18 0.56];

% ---------------- (1) 电负荷需求响应 ----------------
subplot(1,4,1);
plot(t, Load_E, 'k--', 'LineWidth', 1.5); hold on; 
plot(t, value(Load_E_DR), 'Color', c_blue, 'LineWidth', 2);
% 平移转入（正向）、平移转出（负向）、削减量（负向）
bar(t, value(P_E_sl_in), 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_E_sl_out), 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_E_cut), 'FaceColor', c_red, 'EdgeColor', 'none', 'FaceAlpha', 0.6); % 削减量往下画更直观
title('电负荷需求响应', 'FontSize', 12); 
xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;
legend('原始预测负荷', '优化响应负荷', '负荷转入', '负荷转出', '负荷削减', 'Location','southoutside','NumColumns',2);

% ---------------- (2) 热负荷需求响应 ----------------
subplot(1,4,2);
plot(t, Load_H, 'k--', 'LineWidth', 1.5); hold on; 
plot(t, value(Load_H_DR), 'Color', c_orange, 'LineWidth', 2);
% 平移与削减
bar(t, value(P_H_sl_in), 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_H_sl_out), 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_H_cut), 'FaceColor', c_blue, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('热负荷需求响应', 'FontSize', 12); 
xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;
legend('原始预测负荷', '优化响应负荷', '负荷转入', '负荷转出', '负荷削减', 'Location','southoutside','NumColumns',2);

% ---------------- (3) 冷负荷需求响应 ----------------
subplot(1,4,3);
plot(t, Load_C, 'k--', 'LineWidth', 1.5); hold on; 
plot(t, value(Load_C_DR), 'Color', c_cyan, 'LineWidth', 2);
% 平移与削减
bar(t, value(P_C_sl_in), 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_C_sl_out), 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_C_cut), 'FaceColor', c_purple, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('冷负荷需求响应', 'FontSize', 12); 
xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;
legend('原始预测负荷', '优化响应负荷', '负荷转入', '负荷转出', '负荷削减', 'Location','southoutside','NumColumns',2);


%% 7. 全系统单日精细化功率平衡与温控调度图
figure('Color','w','Position',[100, 100, 1200, 800],'Name','单日精细调度全景图');

% (1) 电功率平衡
subplot(2,2,1);
Supply_E = [value(P_grid), value(P_pv), value(P_wind), value(P_ES_dis), value(P_HFC_e)];
Consume_E = [-value(P_ES_ch), -value(P_EC), -value(P_EL), -value(P_EB)];
bar(t, Supply_E, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
bar(t, Consume_E, 0.8, 'stacked', 'EdgeColor', 'none');
% 这里的电负荷加上了数据中心(DC)负荷
plot(t, value(Load_E_DR) + Load_DC, 'k-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'w');
title('电功率平衡', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); xticks(2:2:24); grid on;
legend('主网购电','光伏','风电','电储放电','燃料电池','电储充电','电制冷','电解槽','电锅炉','总电负荷', ...
    'Location','southoutside','NumColumns',5);

% (2) 热功率平衡
subplot(2,2,2);
Supply_H = [value(P_EB)*yita_EB, value(P_HFC_h)];
Consume_H = [-value(P_AC_h)];
bar(t, Supply_H, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
bar(t, Consume_H, 0.8, 'FaceColor', '#D95319', 'EdgeColor', 'none');
plot(t, value(Load_H_DR), 'r-^', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'w');
title('热功率平衡', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); xticks(2:2:24); grid on;
legend('电锅炉产热','燃料电池发热','吸收制冷抽热','实际热负荷', ...
    'Location','southoutside','NumColumns',4);

% (3) 冷功率平衡
subplot(2,2,3);
Supply_C = [value(P_EC_cool), value(P_AC_cool)];
bar(t, Supply_C, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
plot(t, value(Load_C_DR), 'b-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'w');
title('冷功率平衡', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); xticks(2:2:24); grid on;
legend('电制冷产冷','吸收制冷产冷','实际冷负荷', ...
    'Location','southoutside','NumColumns',3);

% (4) 电储能SOC与数据中心(DC)精细温控
subplot(2,2,4);
yyaxis left;
plot(t, value(ES) / V_ES, '-s', 'LineWidth', 1.5, 'Color', '#0072BD', 'MarkerFaceColor', 'w');
ylabel('电储能 SOC', 'Color', '#0072BD'); ylim([0 1]); set(gca, 'YColor', '#0072BD');
yyaxis right;
plot(t, value(T_in), '-d', 'LineWidth', 1.5, 'Color', '#D95319', 'MarkerFaceColor', 'w');
ylabel('数据中心机房温度 / °C', 'Color', '#D95319'); ylim([15 30]); set(gca, 'YColor', '#D95319');
yline(27.22, '--r', 'T_{max}'); yline(17.78, '--b', 'T_{min}');
title('电储能SOC变化与数据中心精细温控', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); xlim([0.5 24.5]); xticks(2:2:24); grid on;

