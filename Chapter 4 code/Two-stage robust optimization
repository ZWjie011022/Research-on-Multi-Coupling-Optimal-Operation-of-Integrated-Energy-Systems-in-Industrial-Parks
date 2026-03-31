clear; clc;
% =========================================================================
% 园区综合能源系统两阶段鲁棒运行优化 (TSRO) —— C&CG 算法 (无碳排放版)
% 升级版：日前定状态，实时调功率
% 修正版：引入风光实际调度变量解耦运维成本，纯经济驱动
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

% 鲁棒参数
delta_max = 0.10; Gamma_wind = 0.6; Gamma_pv = 0.6; 
P_pv_max = V_pv * PV_unit_pred; P_wind_max = V_wind * W_unit_pred;


%% 2. 第一阶段变量 (日前确定)
P_E_sl_in = sdpvar(24,1); P_E_sl_out = sdpvar(24,1); P_E_cut = sdpvar(24,1);
P_H_sl_in = sdpvar(24,1); P_H_sl_out = sdpvar(24,1); P_H_cut = sdpvar(24,1);
P_C_sl_in = sdpvar(24,1); P_C_sl_out = sdpvar(24,1); P_C_cut = sdpvar(24,1);
P_DC_delay1 = sdpvar(24,1); P_DC_delay2 = sdpvar(24,1); Load_DC_opt = sdpvar(24,1);

% 储能与氢耦合变量的状态 0/1 变量
U_ES_ch = binvar(24,1); U_ES_dis = binvar(24,1); 
U_HS_ch = binvar(24,1); U_HS_dis = binvar(24,1); 

alpha_obj = sdpvar(1,1);

% 第一阶段成本 (需求响应补贴)
Cost_1st_DR = sum(c_shift_E*P_E_sl_in + c_cut_E*P_E_cut) + sum(c_shift_H*P_H_sl_in + c_cut_H*P_H_cut) + sum(c_shift_C*P_C_sl_in + c_cut_C*P_C_cut) + sum(c_shift_DC*(P_DC_delay1 + P_DC_delay2));
Cost_1st = Cost_1st_DR;

% 第一阶段约束
First_Constraints = [
    0 <= P_E_sl_in <= alpha_shift*Load_E, 0 <= P_E_sl_out <= alpha_shift*Load_E, 0 <= P_E_cut <= beta_cut*Load_E, sum(P_E_sl_in) == sum(P_E_sl_out),
    0 <= P_H_sl_in <= alpha_shift*Load_H, 0 <= P_H_sl_out <= alpha_shift*Load_H, 0 <= P_H_cut <= beta_cut*Load_H, sum(P_H_sl_in) == sum(P_H_sl_out),
    0 <= P_C_sl_in <= alpha_shift*Load_C, 0 <= P_C_sl_out <= alpha_shift*Load_C, 0 <= P_C_cut <= beta_cut*Load_C, sum(P_C_sl_in) == sum(P_C_sl_out),
    0 <= P_DC_delay1, 0 <= P_DC_delay2, (P_DC_delay1 + P_DC_delay2) <= 0.30 * Load_DC,
    Load_DC_opt(1) == Load_DC(1) - P_DC_delay1(1) - P_DC_delay2(1) + P_DC_delay1(24) + P_DC_delay2(23),
    Load_DC_opt(2) == Load_DC(2) - P_DC_delay1(2) - P_DC_delay2(2) + P_DC_delay1(1) + P_DC_delay2(24)
];
for t = 3:24
    First_Constraints = [First_Constraints, Load_DC_opt(t) == Load_DC(t) - P_DC_delay1(t) - P_DC_delay2(t) + P_DC_delay1(t-1) + P_DC_delay2(t-2)];
end
First_Constraints = [First_Constraints,
    U_ES_ch + U_ES_dis <= 1, U_HS_ch + U_HS_dis <= 1
];

Load_E_DR = Load_E + P_E_sl_in - P_E_sl_out - P_E_cut;
Load_H_DR = Load_H + P_H_sl_in - P_H_sl_out - P_H_cut;
Load_C_DR = Load_C + P_C_sl_in - P_C_sl_out - P_C_cut;
Load_DC_waste_opt = 0.59 * Load_DC_opt;


%% 3. C&CG 算法初始化
max_iter = 20; LB = -inf; UB = inf; epsilon_tol = 5e-4; K = 1; 
u_wind_scenarios = P_wind_max; u_pv_scenarios = P_pv_max;
history_LB = []; history_UB = []; history_GAP = [];

ops_sol = sdpsettings('solver', 'gurobi', 'gurobi.NonConvex', 2, 'verbose', 0);
ops_kkt = sdpsettings('kkt.dualbounds', 0, 'verbose', 0);

disp('🚀 启动两阶段鲁棒优化 C&CG 求解...');

for iter = 1:max_iter
    fprintf('\n========== 第 %d 次 C&CG 迭代 ==========\n', iter);
    
    % =========================================================================
    % 【主问题 MP】
    % =========================================================================
    MP_Constraints = First_Constraints;
    for k = 1:K
        p_es_ch_k = sdpvar(24,1); p_es_dis_k = sdpvar(24,1); es_soc_k = sdpvar(24,1);
        p_hs_ch_k = sdpvar(24,1); p_hs_dis_k = sdpvar(24,1); hs_soc_k = sdpvar(24,1);
        p_el_k = sdpvar(24,1); p_hfc_e_k = sdpvar(24,1); p_hfc_h_k = sdpvar(24,1);
        p_grid_k = sdpvar(24,1); p_eb_k = sdpvar(24,1); p_ec_k = sdpvar(24,1);
        p_ac_h_k = sdpvar(24,1); p_ac_dc_k = sdpvar(24,1); p_ac_cool_k = sdpvar(24,1); p_ac_dccool_k = sdpvar(24,1);
        p_ec_cool_k = sdpvar(24,1); p_ec_dc_k = sdpvar(24,1); t_in_k = sdpvar(24,1); 
        
        p_pv_k = sdpvar(24,1); p_wind_k = sdpvar(24,1);
        u_p = u_pv_scenarios(:,k); u_w = u_wind_scenarios(:,k);
        
        MP_Constraints = [MP_Constraints,
            0 <= p_pv_k <= u_p, 0 <= p_wind_k <= u_w, 
            0 <= p_es_ch_k <= U_ES_ch .* 0.5 .* V_ES, 0 <= p_es_dis_k <= U_ES_dis .* 0.5 .* V_ES,
            es_soc_k(2:24) == es_soc_k(1:23) + p_es_ch_k(2:24)*yita_ES - p_es_dis_k(2:24)/yita_ES,
            es_soc_k(1) == 0.3*V_ES + p_es_ch_k(1)*yita_ES - p_es_dis_k(1)/yita_ES, es_soc_k(24) == 0.3*V_ES, 0.1*V_ES <= es_soc_k <= 0.9*V_ES,
            
            0 <= p_hs_ch_k <= U_HS_ch .* 10^6, 0 <= p_hs_dis_k <= U_HS_dis .* 10^6,
            p_el_k == p_hs_ch_k / yita_EL, p_el_k <= V_EL,
            hs_soc_k(2:24) == hs_soc_k(1:23) + p_hs_ch_k(2:24)*yita_HS - p_hs_dis_k(2:24)/yita_HS,
            hs_soc_k(1) == 0.5*V_HS + p_hs_ch_k(1)*yita_HS - p_hs_dis_k(1)/yita_HS, hs_soc_k(24) == 0.5*V_HS, 0.05*V_HS <= hs_soc_k <= 0.95*V_HS,
            
            p_hfc_e_k + p_hfc_h_k <= yita_HFC_total * p_hs_dis_k, p_hfc_e_k >= 0.7 * p_hfc_h_k, p_hfc_e_k <= 2 * p_hfc_h_k, p_hfc_e_k <= V_HFC,
            
            0<=p_grid_k<=P_grid_max, 0<=p_eb_k<=V_EB, 0<=p_ec_k<=V_EC,
            p_ac_h_k>=0, p_ac_dc_k>=0, p_ac_dc_k<=Load_DC_waste_opt, p_ac_cool_k>=0, p_ac_dccool_k>=0, p_ec_cool_k>=0, p_ec_dc_k>=0,
            p_ac_h_k + p_ac_dc_k <= V_AC, p_ec_k*yita_EC == p_ec_cool_k + p_ec_dc_k, p_ac_cool_k + p_ac_dccool_k == yita_AC*(p_ac_dc_k + p_ac_h_k),
            t_in_k(2:24) == t_in_k(1:23)*exp(-1) + (0.04*(Load_DC_waste_opt(1:23) - p_ac_dc_k(1:23) - p_ec_dc_k(1:23) - p_ac_dccool_k(1:23)) + T_out(1:23))*(1-exp(-1)),
            t_in_k(1) == t_in_k(24)*exp(-1) + (0.04*(Load_DC_waste_opt(24) - p_ac_dc_k(24) - p_ec_dc_k(24) - p_ac_dccool_k(24)) + T_out(24))*(1-exp(-1)),
            17.78 <= t_in_k <= 27.22,
            p_ec_cool_k + p_ac_cool_k >= Load_C_DR,
            p_eb_k*yita_EB + p_hfc_h_k >= Load_H_DR + p_ac_h_k,
            p_grid_k + p_pv_k + p_wind_k + p_es_dis_k + p_hfc_e_k >= Load_E_DR + Load_DC_opt + p_es_ch_k + p_el_k + p_eb_k + p_ec_k
        ];
        
        Cost_Uncertainty_k = sum(K_wind*p_wind_k + K_pv*p_pv_k);
        Cost_om_SP_k = sum(K_ES_om*p_es_dis_k + K_HS_om*p_hs_dis_k + K_HFC_om*(p_hfc_e_k+p_hfc_h_k)) + sum(K_EL*p_el_k*yita_EL + K_EB*p_eb_k*yita_EB + K_EC*p_ec_k*yita_EC + K_AC*(p_ac_dc_k+p_ac_cool_k));
        Cost_2nd_k = sum(price .* p_grid_k) + Cost_Uncertainty_k + Cost_om_SP_k;
        MP_Constraints = [MP_Constraints, alpha_obj >= Cost_2nd_k];
    end
    
    sol_MP = optimize(MP_Constraints, Cost_1st + alpha_obj, ops_sol);
    if sol_MP.problem ~= 0, error('主问题求解失败，请检查 binvar 状态互斥或容量约束！'); end
    LB = max(LB, value(Cost_1st + alpha_obj));
    history_LB = [history_LB, LB]; 
    
    U_ES_ch_star = value(U_ES_ch); U_ES_dis_star = value(U_ES_dis); 
    U_HS_ch_star = value(U_HS_ch); U_HS_dis_star = value(U_HS_dis);
    L_E_DR_star = value(Load_E_DR); L_H_DR_star = value(Load_H_DR); L_C_DR_star = value(Load_C_DR);
    L_DC_opt_star = value(Load_DC_opt); L_DC_waste_opt_star = value(Load_DC_waste_opt);
    fprintf('▶ 主问题求解完毕，当前下界 LB = %.2f\n', LB);
    
    % =========================================================================
    % 【子问题 SP】
    % =========================================================================
    z_pv = sdpvar(24,1); z_wind = sdpvar(24,1);
    u_pv = P_pv_max .* (1 - delta_max * z_pv); u_wind = P_wind_max .* (1 - delta_max * z_wind);
    U_Constraints = [0 <= z_pv <= 1, 0 <= z_wind <= 1, sum(z_pv) <= Gamma_pv / delta_max, sum(z_wind) <= Gamma_wind / delta_max];
    
    p_es_ch_sp = sdpvar(24,1); p_es_dis_sp = sdpvar(24,1); es_soc_sp = sdpvar(24,1);
    p_hs_ch_sp = sdpvar(24,1); p_hs_dis_sp = sdpvar(24,1); hs_soc_sp = sdpvar(24,1);
    p_el_sp = sdpvar(24,1); p_hfc_e_sp = sdpvar(24,1); p_hfc_h_sp = sdpvar(24,1);
    p_grid_sp = sdpvar(24,1); p_eb_sp = sdpvar(24,1); p_ec_sp = sdpvar(24,1);
    p_ac_h_sp = sdpvar(24,1); p_ac_dc_sp = sdpvar(24,1); p_ac_cool_sp = sdpvar(24,1); p_ac_dccool_sp = sdpvar(24,1);
    p_ec_cool_sp = sdpvar(24,1); p_ec_dc_sp = sdpvar(24,1); t_in_sp = sdpvar(24,1); 
    
    p_pv_sp = sdpvar(24,1); p_wind_sp = sdpvar(24,1);

    Inner_Constraints = [
        0 <= p_pv_sp <= u_pv, 0 <= p_wind_sp <= u_wind, 
        0 <= p_es_ch_sp <= U_ES_ch_star .* 0.5 .* V_ES, 0 <= p_es_dis_sp <= U_ES_dis_star .* 0.5 .* V_ES,
        es_soc_sp(2:24) == es_soc_sp(1:23) + p_es_ch_sp(2:24)*yita_ES - p_es_dis_sp(2:24)/yita_ES,
        es_soc_sp(1) == 0.3*V_ES + p_es_ch_sp(1)*yita_ES - p_es_dis_sp(1)/yita_ES, es_soc_sp(24) == 0.3*V_ES, 0.1*V_ES <= es_soc_sp <= 0.9*V_ES,
        
        0 <= p_hs_ch_sp <= U_HS_ch_star .* 10^6, 0 <= p_hs_dis_sp <= U_HS_dis_star .* 10^6,
        p_el_sp == p_hs_ch_sp / yita_EL, p_el_sp <= V_EL,
        hs_soc_sp(2:24) == hs_soc_sp(1:23) + p_hs_ch_sp(2:24)*yita_HS - p_hs_dis_sp(2:24)/yita_HS,
        hs_soc_sp(1) == 0.5*V_HS + p_hs_ch_sp(1)*yita_HS - p_hs_dis_sp(1)/yita_HS, hs_soc_sp(24) == 0.5*V_HS, 0.05*V_HS <= hs_soc_sp <= 0.95*V_HS,
        p_hfc_e_sp + p_hfc_h_sp <= yita_HFC_total * p_hs_dis_sp, p_hfc_e_sp >= 0.7 * p_hfc_h_sp, p_hfc_e_sp <= 2 * p_hfc_h_sp, p_hfc_e_sp <= V_HFC,
        
        0<=p_grid_sp<=P_grid_max, 0<=p_eb_sp<=V_EB, 0<=p_ec_sp<=V_EC,
        p_ac_h_sp>=0, p_ac_dc_sp>=0, p_ac_dc_sp<=L_DC_waste_opt_star, p_ac_cool_sp>=0, p_ac_dccool_sp>=0, p_ec_cool_sp>=0, p_ec_dc_sp>=0,
        p_ac_h_sp + p_ac_dc_sp <= V_AC, p_ec_sp*yita_EC == p_ec_cool_sp + p_ec_dc_sp, p_ac_cool_sp + p_ac_dccool_sp == yita_AC*(p_ac_dc_sp + p_ac_h_sp),
        t_in_sp(2:24) == t_in_sp(1:23)*exp(-1) + (0.04*(L_DC_waste_opt_star(1:23) - p_ac_dc_sp(1:23) - p_ec_dc_sp(1:23) - p_ac_dccool_sp(1:23)) + T_out(1:23))*(1-exp(-1)),
        t_in_sp(1) == t_in_sp(24)*exp(-1) + (0.04*(L_DC_waste_opt_star(24) - p_ac_dc_sp(24) - p_ec_dc_sp(24) - p_ac_dccool_sp(24)) + T_out(24))*(1-exp(-1)),
        17.78 <= t_in_sp <= 27.22,
        p_ec_cool_sp + p_ac_cool_sp >= L_C_DR_star,
        p_eb_sp*yita_EB + p_hfc_h_sp >= L_H_DR_star + p_ac_h_sp,
        p_grid_sp + p_pv_sp + p_wind_sp + p_es_dis_sp + p_hfc_e_sp >= L_E_DR_star + L_DC_opt_star + p_es_ch_sp + p_el_sp + p_eb_sp + p_ec_sp
    ];
    
    Cost_Uncertainty_sp = sum(K_wind*p_wind_sp + K_pv*p_pv_sp);
    Cost_om_SP_sp = sum(K_ES_om*p_es_dis_sp + K_HS_om*p_hs_dis_sp + K_HFC_om*(p_hfc_e_sp+p_hfc_h_sp)) + sum(K_EL*p_el_sp*yita_EL + K_EB*p_eb_sp*yita_EB + K_EC*p_ec_sp*yita_EC + K_AC*(p_ac_dc_sp+p_ac_cool_sp));
    
    Inner_Obj = sum(price .* p_grid_sp) + Cost_Uncertainty_sp + Cost_om_SP_sp;
    
    [KKT_Constraints, ~] = kkt(Inner_Constraints, Inner_Obj, [z_pv; z_wind], ops_kkt);
    sol_SP = optimize([U_Constraints, KKT_Constraints], -Inner_Obj, ops_sol); 
    
    if sol_SP.problem ~= 0, error('子问题 KKT 推导失败，请检查模型连续性！'); end
    worst_pv = value(u_pv); worst_wind = value(u_wind);
    
    Current_Inner_MinCost = value(Inner_Obj); 
    UB = min(UB, value(Cost_1st) + Current_Inner_MinCost);
    history_UB = [history_UB, UB]; 
    gap = abs(UB - LB) / UB;
    history_GAP = [history_GAP, gap]; 

    fprintf('▶ 子问题求解完毕，当前上界 UB = %.2f\n', UB);
    fprintf('>>> 当前迭代 Gap = %.6f %%\n', gap * 100); 
    
    if gap <= epsilon_tol, disp('✅ TSRO 模型成功收敛！'); break;
    else K = K + 1; u_wind_scenarios(:, K) = worst_wind; u_pv_scenarios(:, K) = worst_pv; end
end

%% =========================================================================
% 4. 终局确定性核算 (提取全局最优变量)
% =========================================================================
disp('正在进行最恶劣场景下的最终调度核算...');

f_p_es_ch = sdpvar(24,1); f_p_es_dis = sdpvar(24,1); f_es_soc = sdpvar(24,1);
f_p_hs_ch = sdpvar(24,1); f_p_hs_dis = sdpvar(24,1); f_hs_soc = sdpvar(24,1);
f_p_el = sdpvar(24,1); f_p_hfc_e = sdpvar(24,1); f_p_hfc_h = sdpvar(24,1);
f_p_grid = sdpvar(24,1); f_p_eb = sdpvar(24,1); f_p_ec = sdpvar(24,1);
f_ac_h = sdpvar(24,1); f_ac_dc = sdpvar(24,1); f_ac_cool = sdpvar(24,1); f_ac_dccool = sdpvar(24,1);
f_ec_cool = sdpvar(24,1); f_ec_dc = sdpvar(24,1); f_t_in = sdpvar(24,1);

f_p_pv = sdpvar(24,1); f_p_wind = sdpvar(24,1);

Final_Constraints = [
    0 <= f_p_pv <= worst_pv, 0 <= f_p_wind <= worst_wind, 
    0 <= f_p_es_ch <= U_ES_ch_star .* 0.5 .* V_ES, 0 <= f_p_es_dis <= U_ES_dis_star .* 0.5 .* V_ES,
    f_es_soc(2:24) == f_es_soc(1:23) + f_p_es_ch(2:24)*yita_ES - f_p_es_dis(2:24)/yita_ES,
    f_es_soc(1) == 0.3*V_ES + f_p_es_ch(1)*yita_ES - f_p_es_dis(1)/yita_ES, f_es_soc(24) == 0.3*V_ES, 0.1*V_ES <= f_es_soc <= 0.9*V_ES,
    
    0 <= f_p_hs_ch <= U_HS_ch_star .* 10^6, 0 <= f_p_hs_dis <= U_HS_dis_star .* 10^6,
    f_p_el == f_p_hs_ch / yita_EL, f_p_el <= V_EL,
    f_hs_soc(2:24) == f_hs_soc(1:23) + f_p_hs_ch(2:24)*yita_HS - f_p_hs_dis(2:24)/yita_HS,
    f_hs_soc(1) == 0.5*V_HS + f_p_hs_ch(1)*yita_HS - f_p_hs_dis(1)/yita_HS, f_hs_soc(24) == 0.5*V_HS, 0.05*V_HS <= f_hs_soc <= 0.95*V_HS,
    f_p_hfc_e + f_p_hfc_h <= yita_HFC_total * f_p_hs_dis, f_p_hfc_e >= 0.7 * f_p_hfc_h, f_p_hfc_e <= 2 * f_p_hfc_h, f_p_hfc_e <= V_HFC,
    
    0<=f_p_grid<=P_grid_max, 0<=f_p_eb<=V_EB, 0<=f_p_ec<=V_EC,
    f_ac_h>=0, f_ac_dc>=0, f_ac_dc<=L_DC_waste_opt_star, f_ac_cool>=0, f_ac_dccool>=0, f_ec_cool>=0, f_ec_dc>=0,
    f_ac_h + f_ac_dc <= V_AC, f_p_ec*yita_EC == f_ec_cool + f_ec_dc, f_ac_cool + f_ac_dccool == yita_AC*(f_ac_dc + f_ac_h),
    
    f_t_in(2:24) == f_t_in(1:23)*exp(-1) + (0.04*(L_DC_waste_opt_star(1:23) - f_ac_dc(1:23) - f_ec_dc(1:23) - f_ac_dccool(1:23)) + T_out(1:23))*(1-exp(-1)),
    f_t_in(1) == f_t_in(24)*exp(-1) + (0.04*(L_DC_waste_opt_star(24) - f_ac_dc(24) - f_ec_dc(24) - f_ac_dccool(24)) + T_out(24))*(1-exp(-1)),
    17.78 <= f_t_in <= 27.22,
    
    f_ec_cool + f_ac_cool >= L_C_DR_star,
    f_p_eb*yita_EB + f_p_hfc_h >= L_H_DR_star + f_ac_h,
    
    f_p_grid + f_p_pv + f_p_wind + f_p_es_dis + f_p_hfc_e >= L_E_DR_star + L_DC_opt_star + f_p_es_ch + f_p_el + f_p_eb + f_p_ec
];

Cost_1st_DR_star = value(Cost_1st_DR);
Final_Cost = sum(price .* f_p_grid) + sum(K_wind*f_p_wind + K_pv*f_p_pv) + ...
    sum(K_ES_om*f_p_es_dis + K_HS_om*f_p_hs_dis + K_HFC_om*(f_p_hfc_e+f_p_hfc_h)) + ...
    sum(K_EL*f_p_el*yita_EL + K_EB*f_p_eb*yita_EB + K_EC*f_p_ec*yita_EC + K_AC*(f_ac_dc+f_ac_cool)) + ...
    Cost_1st_DR_star;

optimize(Final_Constraints, Final_Cost, ops_sol);
disp('✅ 终局数据提取完毕，开始生成可视化图像...');


%% =========================================================================
% 5. 绘图模块
% =========================================================================
t = 1:24; c_blue = [0.000, 0.447, 0.741]; c_orange = [0.850, 0.325, 0.098];
c_yellow = [0.929, 0.694, 0.125]; c_cyan = [0.301, 0.745, 0.933];

% --- 图1：收敛过程图 ---
iter_axis = 1:length(history_LB);
figure('Color', 'w', 'Position', [100, 100, 950, 600], 'Name', 'TSRO-C&CG收敛分析');
subplot(2,1,1);
plot(iter_axis, history_UB, '-s', 'Color', c_orange, 'LineWidth', 2.5); hold on;
plot(iter_axis, history_LB, '-o', 'Color', c_blue, 'LineWidth', 2.5); grid on;
title('综合运行成本上下界趋同过程'); ylabel('运行成本 / 元'); legend('上界 UB', '下界 LB');
subplot(2,1,2);
plot(iter_axis, history_GAP * 100, '-^', 'Color', 'r', 'LineWidth', 2); grid on;
yline(epsilon_tol * 100, '--r'); 
title('C&CG 算法收敛 Gap 下降'); ylabel('Gap / %'); xlabel('迭代次数'); legend('当前Gap', '收敛门槛');

% --- 图2：最恶劣自然风光边界 ---
figure('Color', 'w', 'Position', [150, 150, 900, 600], 'Name', '风光鲁棒边界');
subplot(2,1,1); hold on;
plot(t, P_wind_max, '--', 'Color', c_cyan, 'LineWidth', 1.5);
plot(t, worst_wind, '-^', 'Color', c_blue, 'LineWidth', 2, 'MarkerFaceColor', 'w');
ylabel('功率/kW'); xlim([1 24]); grid on; title('风电日前预测与最恶劣寻优'); legend('日前预测', '最恶劣场景');
subplot(2,1,2); hold on;
plot(t, P_pv_max, '--', 'Color', c_yellow, 'LineWidth', 1.5);
plot(t, worst_pv, '-s', 'Color', c_orange, 'LineWidth', 2, 'MarkerFaceColor', 'w');
ylabel('功率/kW'); xlabel('时段/h'); xlim([1 24]); grid on; title('光伏日前预测与最恶劣寻优');

% --- 图3：最恶劣场景下系统精细化功率平衡 ---
figure('Color', 'w', 'Position', [200, 200, 1200, 800], 'Name', '功率平衡');
subplot(2,2,1);
Supply_E = [value(f_p_grid), value(f_p_pv), value(f_p_wind), value(f_p_es_dis), value(f_p_hfc_e)];
Consume_E = [-value(f_p_es_ch), -value(f_p_ec), -value(f_p_el), -value(f_p_eb)];
bar(t, Supply_E, 0.8, 'stacked', 'EdgeColor', 'none'); hold on; bar(t, Consume_E, 0.8, 'stacked', 'EdgeColor', 'none');
plot(t, L_E_DR_star + L_DC_opt_star, 'k-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
title('电功率互联平衡'); xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); grid on;
legend('购电','光伏(实发)','风电(实发)','储能放电','氢产电','储能充电','电制冷','电解槽','电锅炉','总电负荷','Location','southoutside','NumColumns',5);

subplot(2,2,2);
Supply_H = [value(f_p_eb)*yita_EB, value(f_p_hfc_h)]; Consume_H = [-value(f_ac_h)];
bar(t, Supply_H, 0.8, 'stacked', 'EdgeColor', 'none'); hold on; bar(t, Consume_H, 0.8, 'FaceColor', '#D95319', 'EdgeColor', 'none');
plot(t, L_H_DR_star, 'r-^', 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
title('热功率互联平衡'); xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); grid on;
legend('电锅炉','氢产热','吸收制冷','净热负荷','Location','southoutside','NumColumns',4);

subplot(2,2,3);
Supply_C = [value(f_ec_cool), value(f_ac_cool)];
bar(t, Supply_C, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
plot(t, L_C_DR_star, 'b-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'w');
title('冷功率互联平衡'); xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); grid on;
legend('电制冷','吸收制冷','净冷负荷','Location','southoutside','NumColumns',3);

subplot(2,2,4); yyaxis left;
plot(t, value(f_es_soc) / V_ES, '-s', 'LineWidth', 1.5, 'Color', c_blue, 'MarkerFaceColor', 'w');
ylabel('电储能 SOC', 'Color', c_blue); ylim([0 1]); set(gca, 'YColor', c_blue); 
yyaxis right;
plot(t, value(f_t_in), '-d', 'LineWidth', 1.5, 'Color', c_orange, 'MarkerFaceColor', 'w');
ylabel('DC内温/°C', 'Color', c_orange); ylim([15 30]); set(gca, 'YColor', c_orange);
yline(27.22, '--r'); yline(17.78, '--b');
title('储能协同与DC虚拟储能'); xlabel('时间/h'); xlim([0.5 24.5]); grid on;

%% =========================================================================
% 6. 核心分析视图 (支持高分辨学术发表导出)
% =========================================================================

% ---------------- 图4：四维全息综合需求响应分析 (完整平移+削减版) ----------------
figure('Color', 'w', 'Position', [50, 50, 1400, 450], 'Name', '四维全息需求响应');

c_purple = [0.49 0.18 0.56]; c_red = [0.85 0.33 0.10]; c_green = [0.47 0.67 0.19];

% (1) 电负荷需求响应
subplot(1,4,1);
plot(t, Load_E, 'k--', 'LineWidth', 1.5); hold on; 
plot(t, L_E_DR_star, 'Color', c_blue, 'LineWidth', 2);
bar(t, value(P_E_sl_in), 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_E_sl_out), 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_E_cut), 'FaceColor', c_red, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('电负荷需求响应', 'FontSize', 12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;
legend('原始预测负荷', '优化响应负荷', '负荷转入', '负荷转出', '负荷削减', 'Location','southoutside','NumColumns',2);

% (2) 热负荷需求响应
subplot(1,4,2);
plot(t, Load_H, 'k--', 'LineWidth', 1.5); hold on; 
plot(t, L_H_DR_star, 'Color', c_orange, 'LineWidth', 2);
bar(t, value(P_H_sl_in), 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_H_sl_out), 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_H_cut), 'FaceColor', c_blue, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('热负荷需求响应', 'FontSize', 12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;

% (3) 冷负荷需求响应
subplot(1,4,3);
plot(t, Load_C, 'k--', 'LineWidth', 1.5); hold on; 
plot(t, L_C_DR_star, 'Color', c_cyan, 'LineWidth', 2);
bar(t, value(P_C_sl_in), 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_C_sl_out), 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(t, -value(P_C_cut), 'FaceColor', c_purple, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('冷负荷需求响应', 'FontSize', 12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;

% (4) 数据中心负荷时序延迟响应
subplot(1,4,4); yyaxis left;
Shift_out = value(P_DC_delay1 + P_DC_delay2); Shift_in = L_DC_opt_star - Load_DC + Shift_out;
bar(t, Shift_in, 'FaceColor', c_green, 'EdgeColor', 'none', 'BarWidth', 0.6); hold on;
bar(t, -Shift_out, 'FaceColor', c_yellow, 'EdgeColor', 'none', 'BarWidth', 0.6);
ylabel('时空延迟转移量 / kW'); ylim([-max(Load_DC)*0.4, max(Load_DC)*0.4]); 
ax = gca; ax.YColor = 'k'; 
yyaxis right;
plot(t, Load_DC, 'k--', 'LineWidth', 1.5); hold on; 
plot(t, L_DC_opt_star, '-s', 'Color', c_purple, 'LineWidth', 2, 'MarkerFaceColor','w');
ylabel('数据中心算力功率 / kW'); ylim([min(Load_DC)*0.7, max(Load_DC)*1.2]);
ax = gca; ax.YColor = 'k';
title('数据中心负荷时序延迟响应 (DCDR)', 'FontSize', 12); xlabel('时间 / h'); xlim([1 24]); grid on;
legend('算力转入', '算力延迟转出', '原始基础算力', '最终优化算力', 'Location','southoutside','NumColumns',2);

