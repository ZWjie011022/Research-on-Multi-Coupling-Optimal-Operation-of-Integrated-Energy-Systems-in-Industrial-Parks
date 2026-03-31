clear; clc;
% =========================================================================
% 园区综合能源系统 4典型日 全年容量优化配置模型（对照组：纯经济驱动完全体）
% 列 1: 春季 (91天)  列 2: 夏季 (91天)
% 列 3: 秋季 (91天)  列 4: 冬季 (91天)
%
% 【核心逻辑】：
%   - 允许配置所有设备（包含风光、电储能、长时氢储能）
%   - 植入宁夏中卫真实极化风光出力数据
%   - 优化完全不考虑碳排放与碳交易成本，只追求纯经济最优
%   - 氢燃料电池（HFC）电热效率之和固定为0.9，电热比在[0.25, 4.0]内灵活调节
% =========================================================================

%% 1. 基础数据输入与矩阵拼接
% 天数权重
days = [91, 91, 91, 92];

% =========================================================================
%【第一部分：夏季与冬季——沿用原始实测数据】
% =========================================================================
% 夏季电热冷负荷
P_eletric_summer = [3109.1, 2694.8, 2669.3, 2694.8, 2866.9, 2694.8, 2624.7, ...
                    3179.3, 3568.1, 4492.4, 4836.7, 5346.6, 4760.2, 5251.0, ...
                    5200.0, 5295.6, 6194.4, 5786.5, 6634.3, 5225.5, 5416.7, ...
                    4639.0, 4473.3, 3153.8]';
P_cool_summer    = [2900.9, 2427.1, 2331.4, 2305.9, 1942.6, 2376.1, 2937.0, ...
                    3549.0, 4613.5, 5372.1, 8119.6, 9432.7, 10650.3, 10382.6, ...
                    9770.6, 8412.8, 8094.1, 6564.2, 5907.6, 5710.0, 4983.3, ...
                    4250.2, 3886.8, 3498.0]';
P_hot_summer     = [68.5, 164.1, 189.6, 94.0, 68.5, 68.5, 0.0, 17.5, 285.2, ...
                    17.5, 138.6, 508.3, 94.0, 189.6, 68.5, 215.1, 189.6, 406.3, ...
                    68.5, 310.7, 215.1, 215.1, 215.1, 0.0]';

% 冬季电热冷负荷
P_eletric_winter = [2943, 2440, 2296, 2126, 1912, 2076, 2459, 2748, 2893, 2969, ...
                    2799, 2723, 2969, 3251, 3182, 4163, 4622, 5390, 5484, 5151, ...
                    5100, 4597, 3950, 3421]';
P_cool_winter    = [0, 0, 0, 0, 0, 13, 88, 233, 516, 900, 1334, 1547, 1793, ...
                    1717, 1478, 1120, 617, 277, 88, 13, 0, 0, 13, 13]';
P_hot_winter     = [7980, 7792, 7572, 6999, 7119, 7503, 7452, 7264, 6899, 6251, ...
                    5704, 5176, 4956, 4811, 4836, 5585, 6232, 7861, 8987, 10383, ...
                    10911, 11653, 9924, 8823]';

% =========================================================================
%【第二部分：春季——独立模拟数据】
% =========================================================================
P_eletric_spring = [2780.5, 2380.2, 2210.8, 2150.6, 2280.3, 2350.7, 2430.5, ...
                    2890.4, 2980.6, 3720.8, 3880.3, 3850.9, 3720.5, 4120.6, ...
                    3940.2, 4530.8, 5020.4, 5350.7, 5780.6, 4960.3, 5040.8, ...
                    4280.5, 3960.2, 2990.7]';

P_cool_spring    = [0, 0, 0, 0, 0, 0, 0, 120.5, 350.8, 680.3, 1150.6, 1680.2, ...
                    2050.5, 2120.8, 1820.3, 1380.6, 850.2, 380.5, 150.8, 60.3, ...
                    0, 0, 0, 0]';

P_hot_spring     = [3680.5, 3480.2, 3280.8, 3050.6, 3180.3, 3580.5, 5180.2, ...
                    4680.8, 3850.5, 2980.3, 2280.6, 1750.2, 1480.8, 1380.5, ...
                    1450.3, 2050.6, 2750.5, 3650.8, 4250.2, 4980.5, 5120.8, ...
                    4850.3, 4250.6, 3880.2]';

% =========================================================================
%【第三部分：秋季——独立模拟数据】
% =========================================================================
P_eletric_autumn = [3080.5, 2620.2, 2460.8, 2390.6, 2530.3, 2580.7, 2660.5, ...
                    3080.4, 3220.6, 3960.8, 4150.3, 4120.9, 3980.5, 4450.6, ...
                    4280.2, 4830.8, 5410.4, 5680.7, 6150.6, 5260.3, 5350.8, ...
                    4580.5, 4280.2, 3280.7]';

P_cool_autumn    = [180.5, 120.3, 80.6, 60.2, 90.5, 250.8, 380.4, 620.6, ...
                    980.3, 1780.5, 2580.8, 3080.3, 3380.6, 3420.2, 2950.5, ...
                    2480.8, 1680.3, 1080.6, 580.2, 380.5, 280.8, 220.3, ...
                    180.6, 150.5]';

P_hot_autumn     = [5180.5, 4980.2, 4780.8, 4380.6, 4520.3, 4880.5, 8180.2, ...
                    7180.8, 5950.5, 4180.3, 3080.6, 2450.2, 2080.8, 1980.5, ...
                    2120.3, 3050.6, 3980.5, 5150.8, 6250.2, 7380.5, 7680.8, ...
                    7980.3, 6850.6, 5980.2]';

% =========================================================================
%【第四部分：拼接四季负荷矩阵】
% =========================================================================
Load_E = [P_eletric_spring, P_eletric_summer, P_eletric_autumn, P_eletric_winter];
Load_C = [P_cool_spring,    P_cool_summer,    P_cool_autumn,    P_cool_winter];
Load_H = [P_hot_spring,     P_hot_summer,     P_hot_autumn,     P_hot_winter];

% =========================================================================
%【第五部分：数据中心负荷与余热（全年恒定）】
% =========================================================================
P_DC_base = 1.25*[645.8, 715.4, 662.0, 779.0, 1036.6, 875.7, 875.0, 757.3, 873.6, ...
             818.2, 1112.4, 1135.5, 979.3, 1149.7, 1123.3, 746.5, 971.1, 672.8, ...
             678.1, 703.2, 1087.4, 986.7, 739.7, 1021.9]';
Load_DC       = repmat(P_DC_base, 1, 4);
Load_DC_waste = 0.59 * Load_DC;

% =========================================================================
%【第六部分：风光单位出力（宁夏中卫真实聚类数据）】
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

% =========================================================================
%【第七部分：室外温度（四季独立）】
% =========================================================================
T_out_spring = [11.5, 10.8, 10.2, 9.9, 10.5, 12.1, 14.0, 16.2, 18.5, 20.3, ...
                21.8, 22.9, 23.5, 24.1, 23.8, 22.3, 20.4, 18.2, 16.5, 14.8, ...
                13.6, 12.8, 12.2, 11.8]';

T_out_summer = [25.857, 24.176, 24.176, 25.409, 28.908, 29.767, 32.407, 33.515, ...
                34.636, 35.383, 35.520, 35.520, 36.391, 37.686, 34.636, 35.532, ...
                33.727, 31.436, 31.050, 30.190, 29.767, 27.750, 25.969, 24.774]';

T_out_autumn = [7.2, 6.5, 6.0, 5.7, 6.1, 7.5, 9.3, 11.6, 13.8, 15.5, 16.7, ...
                17.4, 17.8, 18.1, 17.4, 15.9, 13.9, 11.7, 10.0, 8.8, 8.1, ...
                7.7, 7.4, 7.2]';

T_out_winter = [2.038, 1.689, 1.839, 1.814, 2.212, 2.661, 2.922, 3.184, 3.644, ...
                4.005, 4.404, 4.603, 4.939, 5.188, 4.752, 4.379, 3.856, 3.395, ...
                3.246, 2.188, 2.188, 2.175, 1.739, 1.366]';

T_out = [T_out_spring, T_out_summer, T_out_autumn, T_out_winter];

% =========================================================================
%【第八部分：电价参数（全年统一）】
% =========================================================================
price = [0.29, 0.29, 0.29, 0.29, 0.29, 0.29, 0.60, 0.60, 0.95, 0.95, 0.95, ...
         0.60, 0.60, 0.60, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.60, ...
         0.29, 0.29]';

%% 2. 离散化设备选型
Unit_pv   = 100;    Unit_wind = 1000;   Unit_ES   = 500;    
Unit_HS   = 1000;   Unit_EL   = 500;    Unit_HFC  = 200;    
Unit_EB   = 1000;   Unit_EC   = 500;    Unit_AC   = 200;    

N_pv  = intvar(1,1); N_wind = intvar(1,1); N_ES  = intvar(1,1);
N_HS  = intvar(1,1); N_EL   = intvar(1,1); N_HFC = intvar(1,1);
N_EB  = intvar(1,1); N_EC   = intvar(1,1); N_AC  = intvar(1,1);

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

% 效率参数
yita_ES=0.9; yita_HS=0.9; yita_EB=0.85; yita_EL=0.6;
yita_EC=3.89; yita_AC=0.8;

% 【HFC灵活电热比改造】
yita_HFC_total = 0.9;  % 电效率 + 热效率总和固定为 0.9

K_pv=0.04; K_wind=0.091; K_ES=0.08;  K_HS=0.016;
K_EB=0.05; K_EL=0.016;  K_HFC=0.033; K_EC=0.1; K_AC=0.015;
c_pun = 0.6; 

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
constraint = [];
constraint = [constraint, ...
    V_pv>=0, V_wind>=0, V_ES>=0, V_HS>=0, V_EL>=0, ...
    V_HFC>=0, V_EB>=0, V_EC>=0, V_AC>=0];

P_wind_max = V_wind * Wind_unit; 
P_pv_max   = V_pv   * PV_unit;  

for d = 1:4
    constraint = [constraint, ...
        0<=P_EB(:,d), P_EB(:,d)<=V_EB, 0<=P_EL(:,d), P_EL(:,d)<=V_EL, 0<=P_EC(:,d), P_EC(:,d)<=V_EC, ...
        P_grid(:,d)>=0, P_EC_cool(:,d)>=0, P_EC_DC(:,d)>=0, ...
        P_AC_DC(:,d)>=0, P_AC_h(:,d)>=0, P_AC_DCcool(:,d)>=0, P_AC_cool(:,d)>=0, ...
        P_AC_cool(:,d) + P_AC_DCcool(:,d) <= V_AC, ...
        P_HFC_e(:,d) <= V_HFC, P_HFC_e(:,d)>=0, P_HFC_h(:,d)>=0, ...
        P_EC(:,d)*yita_EC == P_EC_cool(:,d) + P_EC_DC(:,d), ...
        P_AC_cool(:,d) + P_AC_DCcool(:,d) == yita_AC*(P_AC_DC(:,d) + P_AC_h(:,d)), ...
        P_AC_DC(:,d) <= Load_DC_waste(:,d)];

    % 燃料电池【核心修改：电热比可调逻辑】
    constraint = [constraint, ...
        % 1. 总效率约束：电能输出 + 热能输出 == 0.9 * 消耗的氢能(储氢放能)
        P_HFC_e(:,d) + P_HFC_h(:,d) == yita_HFC_total * P_HS_dis(:,d), ...
        
        P_HFC_e(:,d) >= 0.7 * P_HFC_h(:,d), ...
        P_HFC_e(:,d) <= 2 * P_HFC_h(:,d)];

    constraint = [constraint, ...
        0<=P_ES_ch(:,d),  P_ES_ch(:,d) <= U_ES_char(:,d)*1e6, P_ES_ch(:,d) <=0.5*V_ES, ...
        0<=P_ES_dis(:,d), P_ES_dis(:,d)<= (1-U_ES_char(:,d))*1e6, P_ES_dis(:,d)<=0.5*V_ES, ...
        ES(2:24,d) == ES(1:23,d) + P_ES_ch(2:24,d)*yita_ES - P_ES_dis(2:24,d)/yita_ES, ...
        ES(1,d) == 0.3*V_ES + P_ES_ch(1,d)*yita_ES - P_ES_dis(1,d)/yita_ES, ...
        0.1*V_ES <= ES(:,d), ES(:,d) <= 0.9*V_ES];

    constraint = [constraint, ...
        0<=P_HS_ch(:,d),  P_HS_ch(:,d) <= U_HS_char(:,d)*1e6, ...
        0<=P_HS_dis(:,d), P_HS_dis(:,d)<= (1-U_HS_char(:,d))*1e6, ...
        HS(2:24,d) == HS(1:23,d) + P_HS_ch(2:24,d)*yita_HS - P_HS_dis(2:24,d)/yita_HS, ...
        HS(1,d) == 0.3*V_HS + P_HS_ch(1,d)*yita_HS - P_HS_dis(1,d)/yita_HS, ...
        0.05*V_HS <= HS(:,d), HS(:,d) <= 0.95*V_HS];

    constraint = [constraint, ...
        Load_C(:,d) <= P_EC_cool(:,d) + P_AC_cool(:,d), ...
        P_EB(:,d)*yita_EB + P_HFC_h(:,d) >= Load_H(:,d) + P_AC_h(:,d), ... % HFC发热
        P_EL(:,d)*yita_EL   == P_HS_ch(:,d), ...
        P_grid(:,d) + P_pv(:,d) + P_wind(:,d) - P_ES_ch(:,d) + P_ES_dis(:,d) ...
            - P_EC(:,d) - P_EL(:,d) + P_HFC_e(:,d) - P_EB(:,d) >= Load_E(:,d) + Load_DC(:,d), ... % HFC发电
        0<=P_pv(:,d),   P_pv(:,d)  <= P_pv_max(:,d), ...
        0<=P_wind(:,d), P_wind(:,d)<= P_wind_max(:,d)];

    constraint = [constraint, ...
        T_in(2:24,d) == T_in(1:23,d)*exp(-1) + ...
            (0.04*(Load_DC_waste(1:23,d) - P_AC_DC(1:23,d) - P_EC_DC(1:23,d) - P_AC_DCcool(1:23,d)) ...
            + T_out(1:23,d)) * (1-exp(-1)), ...
        T_in(1,d) == T_in(24,d)*exp(-1) + ...
            (0.04*(Load_DC_waste(24,d) - P_AC_DC(24,d) - P_EC_DC(24,d) - P_AC_DCcool(24,d)) ...
            + T_out(24,d)) * (1-exp(-1)), ...
        17.78 <= T_in(:,d), T_in(:,d) <= 27.22];
end

%% 5. 目标函数（纯经济成本，不含碳）
C_cur = 0; C_grid = 0; C_op = 0;
for d = 1:4
    daily_cur  = sum(c_pun * (P_wind_max(:,d) - P_wind(:,d) + P_pv_max(:,d) - P_pv(:,d)));
    daily_grid = sum(price .* P_grid(:,d));
    daily_op   = sum(K_wind*P_wind_max(:,d) + K_pv*P_pv_max(:,d) + ...
                     K_ES*P_ES_dis(:,d) + K_HS*P_HS_dis(:,d) + ...
                     K_EB*P_EB(:,d)*yita_EB + K_EL*P_EL(:,d)*yita_EL + ...
                     K_HFC*(P_HFC_e(:,d)+P_HFC_h(:,d)) + ...
                     K_EC*P_EC(:,d)*yita_EC + K_AC*(P_AC_DC(:,d)+P_AC_cool(:,d)));
    C_cur  = C_cur  + days(d) * daily_cur;
    C_grid = C_grid + days(d) * daily_grid;
    C_op   = C_op   + days(d) * daily_op;
end

C_inv = V_pv*Inv_pv + V_wind*Inv_wind + V_HS*Inv_HS + V_ES*Inv_ES + ...
        V_EL*Inv_EL + V_EB*Inv_EB + V_HFC*Inv_HFC + V_EC*Inv_EC + V_AC*Inv_AC;
        
obj = C_cur + C_grid + C_op + C_inv;

%% 6. 求解与数据打印
ops = sdpsettings('solver', 'gurobi', 'verbose', 0);
sol = optimize(constraint, obj, ops);

if sol.problem ~= 0
    warning('警告：优化未能成功求解！请检查约束冲突。');
else
    disp('===================================================');
    disp('恭喜，[纯经济驱动-完全体对照组] 优化成功求解！');
    disp('===================================================');
    fprintf('\n[最优装机容量结果]\n');
    fprintf('  光伏装机:   %8.1f kW  (%d 台)\n', value(V_pv),   value(N_pv));
    fprintf('  风电装机:   %8.1f kW  (%d 台)\n', value(V_wind), value(N_wind));
    fprintf('  电储能:     %8.1f kW  (%d 舱)\n', value(V_ES),   value(N_ES));
    fprintf('  储氢系统:   %8.1f kWh (%d 组)\n', value(V_HS),   value(N_HS));
    fprintf('  电解槽:     %8.1f kW  (%d 台)\n', value(V_EL),   value(N_EL));
    fprintf('  燃料电池:   %8.1f kW  (%d 台)\n', value(V_HFC),  value(N_HFC));
    fprintf('  电锅炉:     %8.1f kW  (%d 台)\n', value(V_EB),   value(N_EB));
    fprintf('  电制冷机:   %8.1f kW  (%d 台)\n', value(V_EC),   value(N_EC));
    fprintf('  吸收制冷:   %8.1f kW  (%d 台)\n', value(V_AC),   value(N_AC));
    
    fprintf('\n[★ 系统费用核算 ★]\n');
    fprintf('  纯经济运行费用: %.2f 万元\n', value(obj)/1e4);
    disp('===================================================');
end

%% =========================================================================
% 全景可视化 (去除碳排后的保留图表)
% =========================================================================
t_all = 1:96;

p_grid_all   = value(P_grid);    p_grid_all   = p_grid_all(:);
p_pv_all     = value(P_pv);      p_pv_all     = p_pv_all(:);
p_wind_all   = value(P_wind);    p_wind_all   = p_wind_all(:);
p_es_dis_all = value(P_ES_dis);  p_es_dis_all = p_es_dis_all(:);
p_hfc_e_all  = value(P_HFC_e);   p_hfc_e_all  = p_hfc_e_all(:);
p_es_ch_all  = value(P_ES_ch);   p_es_ch_all  = p_es_ch_all(:);
p_ec_all     = value(P_EC);      p_ec_all     = p_ec_all(:);
p_el_all     = value(P_EL);      p_el_all     = p_el_all(:);
p_eb_all     = value(P_EB);      p_eb_all     = p_eb_all(:);
Load_E_all   = Load_E(:) + Load_DC(:);

p_ac_h_all   = value(P_AC_h);    p_ac_h_all   = p_ac_h_all(:);
p_hfc_h_all  = value(P_HFC_h);   p_hfc_h_all  = p_hfc_h_all(:);
Load_H_all   = Load_H(:);

p_ec_cool_all = value(P_EC_cool); p_ec_cool_all = p_ec_cool_all(:);
p_ac_cool_all = value(P_AC_cool); p_ac_cool_all = p_ac_cool_all(:);
Load_C_all    = Load_C(:);

p_hs_ch_all  = value(P_HS_ch);   p_hs_ch_all  = p_hs_ch_all(:);
p_hs_dis_all = value(P_HS_dis);  p_hs_dis_all = p_hs_dis_all(:);

% ---- 图1：电功率平衡 ----
figure('Color','w','Position',[50,50,1100,420]);
Supply_all  = [p_grid_all, p_pv_all, p_wind_all, p_es_dis_all, p_hfc_e_all];
Consume_all = [-p_es_ch_all, -p_ec_all, -p_el_all, -p_eb_all];
b1 = bar(t_all, Supply_all,  1, 'stacked', 'EdgeColor','none'); hold on;
b2 = bar(t_all, Consume_all, 1, 'stacked', 'EdgeColor','none');
p_load = plot(t_all, Load_E_all, 'k-o', 'LineWidth',1.5, 'MarkerSize',4, 'MarkerFaceColor','w');
xline(24.5,'--k','LineWidth',1.5); xline(48.5,'--k','LineWidth',1.5); xline(72.5,'--k','LineWidth',1.5);
ymax_e = max(Load_E_all)*1.25;
text(12,ymax_e,'春季典型日','FontSize',13,'FontWeight','bold','HorizontalAlignment','center');
text(36,ymax_e,'夏季典型日','FontSize',13,'FontWeight','bold','HorizontalAlignment','center');
text(60,ymax_e,'秋季典型日','FontSize',13,'FontWeight','bold','HorizontalAlignment','center');
text(84,ymax_e,'冬季典型日','FontSize',13,'FontWeight','bold','HorizontalAlignment','center');
xlim([0.5 96.5]); ylim([-max(Load_E_all)*0.5, max(Load_E_all)*1.55]);
ylabel('电功率 / kW','FontSize',12,'FontWeight','bold');
title('微电网全年四季连续电功率平衡（纯经济基准组）','FontSize',14);
legend([b1(1),b1(2),b1(3),b1(4),b1(5),b2(1),b2(2),b2(3),b2(4),p_load], ...
    '电网购电','光伏出力','风电出力','储能放电','燃料电池', ...
    '储能充电','电制冷','电解槽','电锅炉','总电负荷', ...
    'Location','southoutside','NumColumns',5);

% ---- 图2：SOC与数据中心温控 ----
v_es_opt = value(V_ES);
soc_es_all = value(ES);
if v_es_opt > 1e-4
    soc_es_all = soc_es_all(:) / v_es_opt;
else
    soc_es_all = zeros(96,1);
end
t_in_all = value(T_in); t_in_all = t_in_all(:);

figure('Color','w','Position',[100,100,1100,350]);
yyaxis left;
plot(t_all, soc_es_all,'-s','LineWidth',1.5,'Color','#0072BD','MarkerFaceColor','w','MarkerSize',4);
ylabel('电储能 SOC','FontSize',12,'FontWeight','bold','Color','#0072BD'); ylim([0 1]);
set(gca,'YColor','#0072BD');
yyaxis right;
plot(t_all, t_in_all,'-^','LineWidth',1.5,'Color','#D95319','MarkerFaceColor','w','MarkerSize',4);
ylabel('数据中心温度 / °C','FontSize',12,'FontWeight','bold','Color','#D95319'); ylim([15 35]);
set(gca,'YColor','#D95319');
yline(27.22,'--r','LineWidth',1); yline(17.78,'--b','LineWidth',1);
xline(24.5,'--k'); xline(48.5,'--k'); xline(72.5,'--k');
title('电储能与数据中心温控四季动作协同（纯经济基准组）','FontSize',14); xlim([1 96]);

% ---- 图3：热功率平衡 ----
figure('Color','w','Position',[150,150,1100,350]);
Heat_Supply_all  = [p_eb_all*yita_EB, p_hfc_h_all];
Heat_Consume_all = [-p_ac_h_all];
b3 = bar(t_all, Heat_Supply_all, 1,'stacked','EdgeColor','none'); hold on;
b4 = bar(t_all, Heat_Consume_all,1,'FaceColor','#D95319','EdgeColor','none');
p_hot = plot(t_all, Load_H_all,'k-o','LineWidth',1.5,'MarkerSize',4,'MarkerFaceColor','w');
xline(24.5,'--k'); xline(48.5,'--k'); xline(72.5,'--k');
xlim([0.5 96.5]);
ylabel('热功率 / kW','FontSize',12,'FontWeight','bold');
title('微电网全年四季连续热功率平衡（纯经济基准组）','FontSize',14);
legend([b3(1),b3(2),b4,p_hot],'电锅炉产热','燃料电池发热','吸收制冷抽热','常规热负荷', ...
    'Location','southoutside','NumColumns',4);

% ---- 图4：冷功率平衡 ----
figure('Color','w','Position',[200,200,1100,350]);
Cool_Supply_all = [p_ec_cool_all, p_ac_cool_all];
b5 = bar(t_all, Cool_Supply_all,1,'stacked','EdgeColor','none'); hold on;
p_cool = plot(t_all, Load_C_all,'k-o','LineWidth',1.5,'MarkerSize',4,'MarkerFaceColor','w');
xline(24.5,'--k'); xline(48.5,'--k'); xline(72.5,'--k');
xlim([0.5 96.5]);
ylabel('冷功率 / kW','FontSize',12,'FontWeight','bold');
title('微电网全年四季连续冷功率平衡（纯经济基准组）','FontSize',14);
legend([b5(1),b5(2),p_cool],'电制冷机产冷','吸收式制冷产冷','常规冷负荷', ...
    'Location','southoutside','NumColumns',3);

% ---- 图5：氢能流转 ----
figure('Color','w','Position',[250,250,1100,350]);
b6 = bar(t_all, p_hs_ch_all,  1,'FaceColor','#4DBEEE','EdgeColor','none'); hold on;
b7 = bar(t_all,-p_hs_dis_all, 1,'FaceColor','#7E2F8E','EdgeColor','none');
xline(24.5,'--k'); xline(48.5,'--k'); xline(72.5,'--k');
xlim([0.5 96.5]);
ylabel('氢功率（等效kW）','FontSize',12,'FontWeight','bold');
title('微电网全年四季氢能流转平衡（纯经济基准组）','FontSize',14);
legend([b6,b7],'电解槽制氢储入（充氢）','燃料电池耗氢发热/电（放氢）', ...
    'Location','southoutside','NumColumns',2);
if value(V_HS) <= 1e-4
    text(48,0,'受经济性限制，当前模型未配置氢能设备', ...
        'FontSize',15,'Color','r','HorizontalAlignment','center','FontWeight','bold');
end

% ---- 图6：最优装机容量柱状图 ----
Capacities   = [value(V_pv), value(V_wind), value(V_ES), value(V_HS), value(V_EL), ...
                value(V_HFC), value(V_EB), value(V_EC), value(V_AC)];
Device_Names = {'光伏','风电','电储能','氢储能','电解槽','燃料电池','电锅炉','电制冷','吸收式制冷'};
figure('Color','w','Position',[300,300,800,380]);
bar(1:9, Capacities, 0.6, 'FaceColor','#77AC30');
set(gca,'XTick',1:9,'XTickLabel',Device_Names,'FontSize',11,'FontWeight','bold');
ylabel('配置容量 / kW','FontSize',12,'FontWeight','bold');
title('园区综合能源系统最优设备容量配置（纯经济基准组）','FontSize',14);
for i = 1:9
    text(i, Capacities(i), num2str(round(Capacities(i),1)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',10);
end

%% =========================================================================
% ★ 补充绘图 1：一年四季基础负荷与温度数据全景图（完美比例版） ★
% =========================================================================
season_names = {'春季典型日', '夏季典型日', '秋季典型日', '冬季典型日'};
t_day = 1:24;  

figure('Color', 'w', 'Position', [100, 100, 1200, 800]);

line_width_load = 2;
marker_size_load = 5;
color_elec = [0 0.4470 0.7410];  
color_heat = [0.8500 0.3250 0.0980];  
color_cool = [0.9290 0.6940 0.1250];  
color_temp = [0.4660 0.6740 0.1880];  

for d = 1:4
    subplot(2, 2, d);
    yyaxis left;
    
    p1 = plot(t_day, Load_E(:, d), '-o', 'Color', color_elec, ...
        'LineWidth', line_width_load, 'MarkerSize', marker_size_load, 'MarkerFaceColor', 'w');
    hold on;
    p2 = plot(t_day, Load_H(:, d), '-s', 'Color', color_heat, ...
        'LineWidth', line_width_load, 'MarkerSize', marker_size_load, 'MarkerFaceColor', 'w');
    p3 = plot(t_day, Load_C(:, d), '-^', 'Color', color_cool, ...
        'LineWidth', line_width_load, 'MarkerSize', marker_size_load, 'MarkerFaceColor', 'w');
    
    ylabel('负荷功率 / kW', 'FontSize', 11, 'FontWeight', 'bold');
    set(gca, 'YColor', 'k');  
    
    if d == 1
        ylim([0, 8500]); 
    end
    
    yyaxis right;
    p4 = plot(t_day, T_out(:, d), '-d', 'Color', color_temp, ...
        'LineWidth', line_width_load, 'MarkerSize', marker_size_load, 'MarkerFaceColor', 'w');
    
    ylabel('室外温度 / °C', 'FontSize', 11, 'FontWeight', 'bold');
    set(gca, 'YColor', color_temp);  
    
    title(season_names{d}, 'FontSize', 13, 'FontWeight', 'bold');
    xlabel('时间 / h', 'FontSize', 11, 'FontWeight', 'bold');
    xlim([1 24]);
    set(gca, 'XTick', 0:4:24);  
    grid on;  
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.5);  
    
    if d == 1
        legend([p1, p2, p3, p4], ...
            {'电负荷 (E)', '热负荷 (H)', '冷负荷 (C)', '室外温度 (T_{out})'}, ...
            'Location', 'northwest', 'FontSize', 10); 
    end
end
sgtitle('微电网全年四季基础数据 (负荷与温度) 全景图', 'FontSize', 16, 'FontWeight', 'bold');



