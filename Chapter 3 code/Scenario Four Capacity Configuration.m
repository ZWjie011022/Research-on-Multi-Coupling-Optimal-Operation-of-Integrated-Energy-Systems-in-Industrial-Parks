clear; clc;
% =========================================================================
% 园区综合能源系统 4典型日 全年容量优化配置模型（对照场景：无氢储能）
% 列 1: 春季 (91天)  列 2: 夏季 (91天)
% 列 3: 秋季 (91天)  列 4: 冬季 (92天)
%
% 【核心逻辑】：
% 1. 强制锁定氢能设备（电解槽、储氢、燃料电池）为0。
% 2. 优化完全不考虑碳排放与碳交易成本，纯经济驱动。
% 3. 引入真实风光出力数据，允许配置风光和短时电储能。
% =========================================================================

%% 1. 基础数据输入与矩阵拼接
% 天数权重
days = [91, 91, 91, 92];

% =========================================================================
%【负荷数据部分：春夏秋冬】
% =========================================================================
P_eletric_summer = [3109.1, 2694.8, 2669.3, 2694.8, 2866.9, 2694.8, 2624.7, 3179.3, 3568.1, 4492.4, 4836.7, 5346.6, 4760.2, 5251.0, 5200.0, 5295.6, 6194.4, 5786.5, 6634.3, 5225.5, 5416.7, 4639.0, 4473.3, 3153.8]';
P_cool_summer    = [2900.9, 2427.1, 2331.4, 2305.9, 1942.6, 2376.1, 2937.0, 3549.0, 4613.5, 5372.1, 8119.6, 9432.7, 10650.3, 10382.6, 9770.6, 8412.8, 8094.1, 6564.2, 5907.6, 5710.0, 4983.3, 4250.2, 3886.8, 3498.0]';
P_hot_summer     = [68.5, 164.1, 189.6, 94.0, 68.5, 68.5, 0.0, 17.5, 285.2, 17.5, 138.6, 508.3, 94.0, 189.6, 68.5, 215.1, 189.6, 406.3, 68.5, 310.7, 215.1, 215.1, 215.1, 0.0]';

P_eletric_winter = [2943, 2440, 2296, 2126, 1912, 2076, 2459, 2748, 2893, 2969, 2799, 2723, 2969, 3251, 3182, 4163, 4622, 5390, 5484, 5151, 5100, 4597, 3950, 3421]';
P_cool_winter    = [0, 0, 0, 0, 0, 13, 88, 233, 516, 900, 1334, 1547, 1793, 1717, 1478, 1120, 617, 277, 88, 13, 0, 0, 13, 13]';
P_hot_winter     = [7980, 7792, 7572, 6999, 7119, 7503, 7452, 7264, 6899, 6251, 5704, 5176, 4956, 4811, 4836, 5585, 6232, 7861, 8987, 10383, 10911, 11653, 9924, 8823]';

P_eletric_spring = [2780.5, 2380.2, 2210.8, 2150.6, 2280.3, 2350.7, 2430.5, 2890.4, 2980.6, 3720.8, 3880.3, 3850.9, 3720.5, 4120.6, 3940.2, 4530.8, 5020.4, 5350.7, 5780.6, 4960.3, 5040.8, 4280.5, 3960.2, 2990.7]';
P_cool_spring    = [0, 0, 0, 0, 0, 0, 0, 120.5, 350.8, 680.3, 1150.6, 1680.2, 2050.5, 2120.8, 1820.3, 1380.6, 850.2, 380.5, 150.8, 60.3, 0, 0, 0, 0]';
P_hot_spring     = [3680.5, 3480.2, 3280.8, 3050.6, 3180.3, 3580.5, 5180.2, 4680.8, 3850.5, 2980.3, 2280.6, 1750.2, 1480.8, 1380.5, 1450.3, 2050.6, 2750.5, 3650.8, 4250.2, 4980.5, 5120.8, 4850.3, 4250.6, 3880.2]';

P_eletric_autumn = [3080.5, 2620.2, 2460.8, 2390.6, 2530.3, 2580.7, 2660.5, 3080.4, 3220.6, 3960.8, 4150.3, 4120.9, 3980.5, 4450.6, 4280.2, 4830.8, 5410.4, 5680.7, 6150.6, 5260.3, 5350.8, 4580.5, 4280.2, 3280.7]';
P_cool_autumn    = [180.5, 120.3, 80.6, 60.2, 90.5, 250.8, 380.4, 620.6, 980.3, 1780.5, 2580.8, 3080.3, 3380.6, 3420.2, 2950.5, 2480.8, 1680.3, 1080.6, 580.2, 380.5, 280.8, 220.3, 180.6, 150.5]';
P_hot_autumn     = [5180.5, 4980.2, 4780.8, 4380.6, 4520.3, 4880.5, 8180.2, 7180.8, 5950.5, 4180.3, 3080.6, 2450.2, 2080.8, 1980.5, 2120.3, 3050.6, 3980.5, 5150.8, 6250.2, 7380.5, 7680.8, 7980.3, 6850.6, 5980.2]';

Load_E = [P_eletric_spring, P_eletric_summer, P_eletric_autumn, P_eletric_winter];
Load_C = [P_cool_spring,    P_cool_summer,    P_cool_autumn,    P_cool_winter];
Load_H = [P_hot_spring,     P_hot_summer,     P_hot_autumn,     P_hot_winter];

P_DC_base = 1.25*[645.8, 715.4, 662.0, 779.0, 1036.6, 875.7, 875.0, 757.3, 873.6, 818.2, 1112.4, 1135.5, 979.3, 1149.7, 1123.3, 746.5, 971.1, 672.8, 678.1, 703.2, 1087.4, 986.7, 739.7, 1021.9]';
Load_DC       = repmat(P_DC_base, 1, 4);
Load_DC_waste = 0.59 * Load_DC;

% =========================================================================
% 【宁夏中卫真实风光数据】
% =========================================================================
W_unit_spring = [0.515, 0.513, 0.496, 0.484, 0.533, 0.568, 0.555, 0.411, 0.148, 0.068, 0.134, 0.167, 0.129, 0.086, 0.062, 0.058, 0.066, 0.091, 0.189, 0.354, 0.492, 0.537, 0.462, 0.370]';
W_unit_summer = [0.237, 0.256, 0.262, 0.302, 0.319, 0.230, 0.151, 0.086, 0.037, 0.028, 0.021, 0.050, 0.116, 0.178, 0.227, 0.255, 0.254, 0.256, 0.242, 0.233, 0.213, 0.122, 0.045, 0.012]';
W_unit_autumn = [0.502, 0.456, 0.389, 0.351, 0.358, 0.408, 0.416, 0.356, 0.477, 0.387, 0.202, 0.080, 0.017, 0.001, 0.000, 0.000, 0.000, 0.010, 0.073, 0.305, 0.428, 0.377, 0.316, 0.354]';
W_unit_winter = [0.288, 0.239, 0.210, 0.132, 0.127, 0.160, 0.175, 0.227, 0.215, 0.201, 0.173, 0.168, 0.181, 0.195, 0.177, 0.141, 0.121, 0.111, 0.123, 0.107, 0.083, 0.053, 0.052, 0.133]';
Wind_unit = [W_unit_spring, W_unit_summer, W_unit_autumn, W_unit_winter];

PV_unit_spring = [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.184, 0.403, 0.499, 0.556, 0.655, 0.738, 0.748, 0.696, 0.605, 0.498, 0.300, 0.094, 0.000, 0.000, 0.000, 0.000, 0.000]';
PV_unit_summer = [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.101, 0.293, 0.346, 0.382, 0.509, 0.614, 0.582, 0.570, 0.556, 0.548, 0.538, 0.405, 0.278, 0.110, 0.000, 0.000, 0.000, 0.000]';
PV_unit_autumn = [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.048, 0.168, 0.357, 0.564, 0.674, 0.677, 0.656, 0.634, 0.556, 0.444, 0.298, 0.141, 0.000, 0.000, 0.000, 0.000, 0.000]';
PV_unit_winter = [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.310, 0.563, 0.696, 0.763, 0.739, 0.655, 0.604, 0.634, 0.513, 0.179, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000]';
PV_unit = [PV_unit_spring, PV_unit_summer, PV_unit_autumn, PV_unit_winter];
T_out_spring = [11.5, 10.8, 10.2, 9.9, 10.5, 12.1, 14.0, 16.2, 18.5, 20.3, 21.8, 22.9, 23.5, 24.1, 23.8, 22.3, 20.4, 18.2, 16.5, 14.8, 13.6, 12.8, 12.2, 11.8]';
T_out_summer = [25.857, 24.176, 24.176, 25.409, 28.908, 29.767, 32.407, 33.515, 34.636, 35.383, 35.520, 35.520, 36.391, 37.686, 34.636, 35.532, 33.727, 31.436, 31.050, 30.190, 29.767, 27.750, 25.969, 24.774]';
T_out_autumn = [7.2, 6.5, 6.0, 5.7, 6.1, 7.5, 9.3, 11.6, 13.8, 15.5, 16.7, 17.4, 17.8, 18.1, 17.4, 15.9, 13.9, 11.7, 10.0, 8.8, 8.1, 7.7, 7.4, 7.2]';
T_out_winter = [2.038, 1.689, 1.839, 1.814, 2.212, 2.661, 2.922, 3.184, 3.644, 4.005, 4.404, 4.603, 4.939, 5.188, 4.752, 4.379, 3.856, 3.395, 3.246, 2.188, 2.188, 2.175, 1.739, 1.366]';
T_out = [T_out_spring, T_out_summer, T_out_autumn, T_out_winter];
price = [0.29, 0.29, 0.29, 0.29, 0.29, 0.29, 0.60, 0.60, 0.95, 0.95, 0.95, 0.60, 0.60, 0.60, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.60, 0.29, 0.29]';

%% 2. 离散化设备选型
Unit_pv   = 100;    Unit_wind = 1000;   Unit_ES   = 500;    
Unit_HS   = 1000;   Unit_EL   = 500;    Unit_HFC  = 200;    
Unit_EB   = 1000;   Unit_EC   = 500;    Unit_AC   = 200;    

% =========================================================================
% 【核心修改点：强制无氢储能场景】
% =========================================================================
N_pv   = intvar(1,1);
N_wind = intvar(1,1);
N_ES   = intvar(1,1);
N_HS   = 0;          % 强制锁定储氢系统为 0
N_EL   = 0;          % 强制锁定电解槽为 0
N_HFC  = 0;          % 强制锁定燃料电池为 0
N_EB   = intvar(1,1); N_EC   = intvar(1,1); N_AC  = intvar(1,1);

V_pv  = N_pv  * Unit_pv;   V_wind = N_wind * Unit_wind;
V_ES  = N_ES  * Unit_ES;   V_HS   = N_HS   * Unit_HS;
V_EL  = N_EL  * Unit_EL;   V_HFC  = N_HFC  * Unit_HFC;
V_EB  = N_EB  * Unit_EB;   V_EC   = N_EC   * Unit_EC;
V_AC  = N_AC  * Unit_AC;

%% 3. 运行变量
P_ES_ch  = sdpvar(24,4); P_ES_dis = sdpvar(24,4); ES       = sdpvar(24,4);
P_HS_ch  = sdpvar(24,4); P_HS_dis = sdpvar(24,4); HS       = sdpvar(24,4);
P_EL     = sdpvar(24,4); P_HFC_e  = sdpvar(24,4); P_HFC_h  = sdpvar(24,4);
P_EB     = sdpvar(24,4); P_EC     = sdpvar(24,4);
P_EC_DC  = sdpvar(24,4); P_EC_cool = sdpvar(24,4);
P_AC_DC  = sdpvar(24,4); P_AC_h   = sdpvar(24,4);
P_AC_DCcool = sdpvar(24,4); P_AC_cool = sdpvar(24,4);
P_grid   = sdpvar(24,4); P_pv     = sdpvar(24,4); P_wind   = sdpvar(24,4);
T_in     = sdpvar(24,4);
U_ES_char = binvar(24,4); U_HS_char = binvar(24,4);

yita_ES=0.9; yita_HS=0.9; yita_EB=0.85; yita_EL=0.6;
yita_HFC_e=0.6; yita_HFC_h=0.3; yita_EC=3.89; yita_AC=0.8;
K_pv=0.04; K_wind=0.091; K_ES=0.08;  K_HS=0.016;
K_EB=0.05; K_EL=0.016;  K_HFC=0.033; K_EC=0.1; K_AC=0.015; c_pun = 0.6;

bank_rate=0.08;
year_pv=20; year_wind=20; year_EC=10; year_EB=10;
year_EL=10; year_HFC=10; year_ES=15; year_HS=10; year_AC=10;

CRF = @(r,n) r*(1+r)^n/((1+r)^n-1);
Inv_pv   = 3200 * CRF(bank_rate, year_pv); Inv_wind = 4000 * CRF(bank_rate, year_wind);
Inv_HS   =  506 * CRF(bank_rate, year_HS); Inv_ES   = 1800 * CRF(bank_rate, year_ES);
Inv_EB   = 1000 * CRF(bank_rate, year_EB); Inv_EL   = 1500 * CRF(bank_rate, year_EL);
Inv_HFC  = 2700 * CRF(bank_rate, year_HFC);Inv_EC   =  950 * CRF(bank_rate, year_EC);
Inv_AC   =  756 * CRF(bank_rate, year_AC);

%% 4. 系统约束
constraint = [V_pv>=0, V_wind>=0, V_ES>=0, V_HS>=0, V_EL>=0, V_HFC>=0, V_EB>=0, V_EC>=0, V_AC>=0];
P_wind_max = V_wind * Wind_unit; P_pv_max   = V_pv   * PV_unit;   

for d = 1:4
    constraint = [constraint, ...
        0<=P_EB(:,d), P_EB(:,d)<=V_EB, 0<=P_EL(:,d), P_EL(:,d)<=V_EL, 0<=P_EC(:,d), P_EC(:,d)<=V_EC, ...
        P_grid(:,d)>=0, P_EC_cool(:,d)>=0, P_EC_DC(:,d)>=0, P_AC_DC(:,d)>=0, P_AC_h(:,d)>=0, ...
        P_AC_DCcool(:,d)>=0, P_AC_cool(:,d)>=0, P_AC_cool(:,d) + P_AC_DCcool(:,d) <= V_AC, ...
        P_HFC_e(:,d) <= V_HFC, P_HFC_e(:,d)>=0, P_HFC_h(:,d)>=0, ...
        P_EC(:,d)*yita_EC == P_EC_cool(:,d) + P_EC_DC(:,d), P_AC_cool(:,d) + P_AC_DCcool(:,d) == yita_AC*(P_AC_DC(:,d) + P_AC_h(:,d)), ...
        P_AC_DC(:,d) <= Load_DC_waste(:,d)];

    constraint = [constraint, ...
        0<=P_ES_ch(:,d),  P_ES_ch(:,d) <= U_ES_char(:,d)*1e6, P_ES_ch(:,d) <=0.5*V_ES, ...
        0<=P_ES_dis(:,d), P_ES_dis(:,d)<= (1-U_ES_char(:,d))*1e6, P_ES_dis(:,d)<=0.5*V_ES, ...
        ES(2:24,d) == ES(1:23,d) + P_ES_ch(2:24,d)*yita_ES - P_ES_dis(2:24,d)/yita_ES, ...
        ES(1,d) == 0.3*V_ES + P_ES_ch(1,d)*yita_ES - P_ES_dis(1,d)/yita_ES, 0.1*V_ES <= ES(:,d), ES(:,d) <= 0.9*V_ES];

    % 由于氢储能设备已锁定为 0，这里的约束其实是强制 P_HS_ch 和 P_HS_dis 为 0，保留约束以防报错
    constraint = [constraint, ...
        0<=P_HS_ch(:,d),  P_HS_ch(:,d) <= U_HS_char(:,d)*1e6, 0<=P_HS_dis(:,d), P_HS_dis(:,d)<= (1-U_HS_char(:,d))*1e6, ...
        HS(2:24,d) == HS(1:23,d) + P_HS_ch(2:24,d)*yita_HS - P_HS_dis(2:24,d)/yita_HS, ...
        HS(1,d) == 0.3*V_HS + P_HS_ch(1,d)*yita_HS - P_HS_dis(1,d)/yita_HS, 0.05*V_HS <= HS(:,d), HS(:,d) <= 0.95*V_HS];

    constraint = [constraint, ...
        Load_C(:,d) <= P_EC_cool(:,d) + P_AC_cool(:,d), P_EB(:,d)*yita_EB + P_HFC_h(:,d) >= Load_H(:,d) + P_AC_h(:,d), ...
        P_EL(:,d)*yita_EL   == P_HS_ch(:,d), P_HS_dis(:,d)*yita_HFC_h == P_HFC_h(:,d), P_HS_dis(:,d)*yita_HFC_e == P_HFC_e(:,d), ...
        P_grid(:,d) + P_pv(:,d) + P_wind(:,d) - P_ES_ch(:,d) + P_ES_dis(:,d) - P_EC(:,d) - P_EL(:,d) + P_HFC_e(:,d) - P_EB(:,d) >= Load_E(:,d) + Load_DC(:,d), ...
        0<=P_pv(:,d), P_pv(:,d)<= P_pv_max(:,d), 0<=P_wind(:,d), P_wind(:,d)<= P_wind_max(:,d)];

    constraint = [constraint, ...
        T_in(2:24,d) == T_in(1:23,d)*exp(-1) + (0.04*(Load_DC_waste(1:23,d) - P_AC_DC(1:23,d) - P_EC_DC(1:23,d) - P_AC_DCcool(1:23,d)) + T_out(1:23,d)) * (1-exp(-1)), ...
        T_in(1,d) == T_in(24,d)*exp(-1) + (0.04*(Load_DC_waste(24,d) - P_AC_DC(24,d) - P_EC_DC(24,d) - P_AC_DCcool(24,d)) + T_out(24,d)) * (1-exp(-1)), ...
        17.78 <= T_in(:,d), T_in(:,d) <= 27.22];
end

%% 5. 目标函数（纯经济成本，不含碳）
C_cur = 0; C_grid = 0; C_op = 0;
for d = 1:4
    daily_cur  = sum(c_pun * (P_wind_max(:,d) - P_wind(:,d) + P_pv_max(:,d) - P_pv(:,d)));
    daily_grid = sum(price .* P_grid(:,d));
    daily_op   = sum(K_wind*P_wind_max(:,d) + K_pv*P_pv_max(:,d) + K_ES*P_ES_dis(:,d) + K_HS*P_HS_dis(:,d) + K_EB*P_EB(:,d)*yita_EB + K_EL*P_EL(:,d)*yita_EL + K_HFC*(P_HFC_e(:,d)+P_HFC_h(:,d)) + K_EC*P_EC(:,d)*yita_EC + K_AC*(P_AC_DC(:,d)+P_AC_cool(:,d)));
    C_cur  = C_cur  + days(d) * daily_cur;
    C_grid = C_grid + days(d) * daily_grid;
    C_op   = C_op   + days(d) * daily_op;
end

C_inv = V_pv*Inv_pv + V_wind*Inv_wind + V_HS*Inv_HS + V_ES*Inv_ES + V_EL*Inv_EL + V_EB*Inv_EB + V_HFC*Inv_HFC + V_EC*Inv_EC + V_AC*Inv_AC;

% 【注意】目标函数中不加 C_CO2，只追求经济最优
obj = C_cur + C_grid + C_op + C_inv;

%% 6. 求解与数据打印
ops = sdpsettings('solver', 'gurobi', 'verbose', 0);
sol = optimize(constraint, obj, ops);

if sol.problem ~= 0
    warning('警告：优化未能成功求解！请检查约束冲突。');
else
    disp('===================================================');
    disp('恭喜，[纯经济驱动-强制无氢储能场景] 优化成功求解！');
    disp('===================================================');
    fprintf('\n[最优装机容量]\n');
    fprintf('  光伏装机:   %8.1f kW  (%d 台)\n', value(V_pv),   value(N_pv));
    fprintf('  风电装机:   %8.1f kW  (%d 台)\n', value(V_wind), value(N_wind));
    fprintf('  电储能:     %8.1f kW  (%d 舱)\n', value(V_ES),   value(N_ES));
    fprintf('  储氢系统:   %8.1f kWh (%d 组) (强行设为0)\n', value(V_HS),   value(N_HS));
    fprintf('  电解槽:     %8.1f kW  (%d 台) (强行设为0)\n', value(V_EL),   value(N_EL));
    fprintf('  燃料电池:   %8.1f kW  (%d 台) (强行设为0)\n', value(V_HFC),  value(N_HFC));
    fprintf('  电锅炉:     %8.1f kW  (%d 台)\n', value(V_EB),   value(N_EB));
    fprintf('  电制冷机:   %8.1f kW  (%d 台)\n', value(V_EC),   value(N_EC));
    fprintf('  吸收制冷:   %8.1f kW  (%d 台)\n', value(V_AC),   value(N_AC));
    
    fprintf('\n[系统总费用核算]\n');
    fprintf('  纯经济运行费用: %.2f 万元\n', value(obj)/1e4);
    disp('===================================================');
end

%% =========================================================================
% ★ 绘图：全年四季连续电功率平衡 & 温控动态 ★
% =========================================================================
t_all = 1:96;
p_grid_all   = value(P_grid);   p_grid_all   = p_grid_all(:);
p_pv_all     = value(P_pv);     p_pv_all     = p_pv_all(:);
p_wind_all   = value(P_wind);   p_wind_all   = p_wind_all(:);
p_es_dis_all = value(P_ES_dis); p_es_dis_all = p_es_dis_all(:);
p_hfc_e_all  = value(P_HFC_e);  p_hfc_e_all  = p_hfc_e_all(:); % 此项应全为0
p_es_ch_all  = value(P_ES_ch);  p_es_ch_all  = p_es_ch_all(:);
p_ec_all     = value(P_EC);     p_ec_all     = p_ec_all(:);
p_el_all     = value(P_EL);     p_el_all     = p_el_all(:); % 此项应全为0
p_eb_all     = value(P_EB);     p_eb_all     = p_eb_all(:);

Load_E_all = Load_E(:) + Load_DC(:);

figure('Color', 'w', 'Position', [50, 50, 1100, 400]);
Supply_all = [p_grid_all, p_pv_all, p_wind_all, p_es_dis_all, p_hfc_e_all];
Consume_all = [-p_es_ch_all, -p_ec_all, -p_el_all, -p_eb_all];

b1 = bar(t_all, Supply_all, 1, 'stacked', 'EdgeColor', 'none'); hold on;
b2 = bar(t_all, Consume_all, 1, 'stacked', 'EdgeColor', 'none');
p_load = plot(t_all, Load_E_all, 'k-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'w');

xline(24.5, '--k', 'LineWidth', 1.5); xline(48.5, '--k', 'LineWidth', 1.5); xline(72.5, '--k', 'LineWidth', 1.5);
text(12, max(Load_E_all)*1.2, '春季典型日', 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(36, max(Load_E_all)*1.2, '夏季典型日', 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(60, max(Load_E_all)*1.2, '秋季典型日', 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(84, max(Load_E_all)*1.2, '冬季典型日', 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

xlim([0.5 96.5]); 
ylim_min = min(sum(Consume_all, 2)) * 1.2;
if ylim_min >= 0, ylim_min = -max(Load_E_all)*0.5; end
ylim([ylim_min, max(Load_E_all)*1.5]);

ylabel('电功率 / kW', 'FontSize', 12, 'FontWeight', 'bold');
title('微电网全年四季连续电功率平衡 (无氢储能对照组)', 'FontSize', 14);

legend([b1(1), b1(2), b1(3), b1(4), b1(5), b2(1), b2(2), b2(3), b2(4), p_load], ...
    '电网购电', '光伏出力', '风电出力', '储能放电', '燃料电池', '储能充电', '电制冷机', '电解槽', '电锅炉', '总电负荷', ...
    'Location', 'southoutside', 'NumColumns', 5);

v_es_opt = value(V_ES); 
soc_es_all = value(ES); 
if v_es_opt > 1e-4
    soc_es_all = soc_es_all(:) / v_es_opt; 
else
    soc_es_all = zeros(96,1); 
end

t_in_all = value(T_in); 
t_in_all = t_in_all(:);

figure('Color', 'w', 'Position', [100, 100, 1100, 350]);
yyaxis left; 
plot(t_all, soc_es_all, '-s', 'LineWidth', 1.5, 'Color', '#0072BD', 'MarkerFaceColor', 'w', 'MarkerSize', 4);
ylabel('电储能 SOC (日内循环)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', '#0072BD'); 
ylim([0 1]); 
set(gca, 'YColor', '#0072BD');

yyaxis right; 
plot(t_all, t_in_all, '-^', 'LineWidth', 1.5, 'Color', '#D95319', 'MarkerFaceColor', 'w', 'MarkerSize', 4);
ylabel('数据中心温度 / °C', 'FontSize', 12, 'FontWeight', 'bold', 'Color', '#D95319'); 
ylim([15 30]); 
set(gca, 'YColor', '#D95319');

yline(27.22, '--r', '上限 27.22°C', 'LineWidth', 1, 'LabelHorizontalAlignment', 'left'); 
yline(17.78, '--b', '下限 17.78°C', 'LineWidth', 1, 'LabelHorizontalAlignment', 'left');

xline(24.5, '--k'); xline(48.5, '--k'); xline(72.5, '--k'); 
xlim([1 96]);
xticks(12:24:84);
xticklabels({'春季', '夏季', '秋季', '冬季'});
title('电储能 SOC 与 数据中心温控 四季动作协同 (无氢储能对照组)', 'FontSize', 14);
grid on; set(gca, 'GridLineStyle', ':');

% =========================================================================
% ★ 图8：最优装机容量柱状图 ★
% =========================================================================
Capacities   = [value(V_pv), value(V_wind), value(V_ES), value(V_HS), ...
                value(V_EL), value(V_HFC), value(V_EB), value(V_EC), value(V_AC)];
Device_Names = {'光伏','风电','电储能','氢储能','电解槽','燃料电池','电锅炉','电制冷','吸收制冷'};
colors_cap   = {'#EDB120','#77AC30','#0072BD','#4DBEEE','#D95319','#7E2F8E','#FF8C00','#00BFFF','#32CD32'};

figure('Color','w','Position',[400,300,900,400]);
for i = 1:9
    bar(i, Capacities(i), 0.6, 'FaceColor', colors_cap{i}); hold on;
end
set(gca,'XTick',1:9,'XTickLabel',Device_Names,'FontSize',11,'FontWeight','bold');
ylabel('配置容量 / kW（或kWh）','FontSize',12,'FontWeight','bold');
title('园区综合能源系统最优装机容量（完全体模型）','FontSize',13);
for i = 1:9
    if Capacities(i) > 0
        text(i, Capacities(i)+max(Capacities)*0.01, ...
            num2str(round(Capacities(i)),'%d'), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9,'FontWeight','bold');
    end
end
grid on; box on;

% =========================================================================
% ★ 图9：单日精细化调度图 ★
% =========================================================================
v_es_opt = value(V_ES);
season_names_full = {'春季典型日','夏季典型日','秋季典型日','冬季典型日'};
t24 = 1:24;

for d = 1:4
    p_grid_d = value(P_grid(:,d));   p_pv_d   = value(P_pv(:,d));
    p_wind_d = value(P_wind(:,d));   p_es_dis_d = value(P_ES_dis(:,d));
    p_es_ch_d = value(P_ES_ch(:,d)); p_hfc_e_d = value(P_HFC_e(:,d));
    p_el_d   = value(P_EL(:,d));     p_eb_d    = value(P_EB(:,d));
    p_ec_d   = value(P_EC(:,d));     load_etot_d = Load_E(:,d)+Load_DC(:,d);
    p_hfc_h_d = value(P_HFC_h(:,d)); p_ac_h_d  = value(P_AC_h(:,d));
    p_ec_cool_d = value(P_EC_cool(:,d)); p_ac_cool_d = value(P_AC_cool(:,d));
    soc_d = (v_es_opt > 1e-4) * value(ES(:,d)) / max(v_es_opt, 1);
    t_in_d = value(T_in(:,d));

    figure('Color','w','Position',[80+d*25,80+d*25,1200,820],'Name',season_names_full{d});
    sgtitle([season_names_full{d},' 综合能源系统 24 小时精细调度'], ...
        'FontSize',16,'FontWeight','bold');

    subplot(2,2,1); % 电平衡
    b1_d = bar(t24,[p_grid_d,p_pv_d,p_wind_d,p_es_dis_d,p_hfc_e_d],0.8,'stacked','EdgeColor','none'); hold on;
    b2_d = bar(t24,[-p_es_ch_d,-p_ec_d,-p_el_d,-p_eb_d],0.8,'stacked','EdgeColor','none');
    plot(t24,load_etot_d,'k-o','LineWidth',1.5,'MarkerSize',4,'MarkerFaceColor','w');
    xlim([0.5 24.5]); xticks(2:2:24); grid on; set(gca,'GridLineStyle',':');
    title('电功率平衡','FontSize',12); ylabel('功率/kW');

    subplot(2,2,2); % 热平衡
    bar(t24,[p_eb_d*yita_EB, p_hfc_h_d],0.8,'stacked','EdgeColor','none'); hold on;
    bar(t24,-p_ac_h_d,0.8,'FaceColor','#D95319','EdgeColor','none');
    plot(t24,Load_H(:,d),'r-^','LineWidth',1.5,'MarkerSize',4,'MarkerFaceColor','w');
    xlim([0.5 24.5]); xticks(2:2:24); grid on; set(gca,'GridLineStyle',':');
    title('热功率平衡','FontSize',12); ylabel('功率/kW');

    subplot(2,2,3); % 冷平衡
    bar(t24,[p_ec_cool_d, p_ac_cool_d],0.8,'stacked','EdgeColor','none'); hold on;
    plot(t24,Load_C(:,d),'b-s','LineWidth',1.5,'MarkerSize',4,'MarkerFaceColor','w');
    xlim([0.5 24.5]); xticks(2:2:24); grid on; set(gca,'GridLineStyle',':');
    title('冷功率平衡','FontSize',12); xlabel('时间/h'); ylabel('功率/kW');

    subplot(2,2,4); % SOC + 温控
    yyaxis left;
    plot(t24,soc_d,'-s','LineWidth',1.5,'Color','#0072BD','MarkerFaceColor','w');
    ylabel('电储能SOC','Color','#0072BD'); ylim([0 1]); set(gca,'YColor','#0072BD');
    yyaxis right;
    plot(t24,t_in_d,'-d','LineWidth',1.5,'Color','#D95319','MarkerFaceColor','w');
    ylabel('数据中心温度/°C','Color','#D95319'); ylim([15 30]); set(gca,'YColor','#D95319');
    yline(27.22,'--r'); yline(17.78,'--b');
    xlim([0.5 24.5]); xticks(2:2:24); grid on; set(gca,'GridLineStyle',':');
    title('电储能SOC与数据中心温控','FontSize',12); xlabel('时间/h');
end

