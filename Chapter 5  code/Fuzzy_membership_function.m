clear; clc;
% =========================================================================
% 园区综合能源系统两阶段鲁棒多目标优化 (MO-TSRO)
% 核心架构：ε-约束法 + C&CG + 模糊隶属度决策 (最优折衷点提取) + SCI级可视化
% =========================================================================

%% =========================================================================
%  第0节：基础数据准备 (与原版保持一致)
% =========================================================================
Load_E  = [3080.5,2620.2,2460.8,2390.6,2530.3,2580.7,2660.5,3080.4,3220.6,3960.8,4150.3,4120.9,3980.5,4450.6,4280.2,4830.8,5410.4,5680.7,6150.6,5260.3,5350.8,4580.5,4280.2,3280.7]';
Load_H  = [5180.5,4980.2,4780.8,4380.6,4520.3,4880.5,8180.2,7180.8,5950.5,4180.3,3080.6,2450.2,2080.8,1980.5,2120.3,3050.6,3980.5,5150.8,6250.2,7380.5,7680.8,7980.3,6850.6,5980.2]';
Load_C  = [180.5,120.3,80.6,60.2,90.5,250.8,380.4,620.6,980.3,1780.5,2580.8,3080.3,3380.6,3420.2,2950.5,2480.8,1680.3,1080.6,580.2,380.5,280.8,220.3,180.6,150.5]';
Load_DC = 1.25*[645.8,715.4,662.0,779.0,1036.6,875.7,875.0,757.3,873.6,818.2,1112.4,1135.5,979.3,1149.7,1123.3,746.5,971.1,672.8,678.1,703.2,1087.4,986.7,739.7,1021.9]';
T_out  = [7.2,6.5,6.0,5.7,6.1,7.5,9.3,11.6,13.8,15.5,16.7,17.4,17.8,18.1,17.4,15.9,13.9,11.7,10.0,8.8,8.1,7.7,7.4,7.2]';
price  = [0.29,0.29,0.29,0.29,0.29,0.29,0.6,0.6,0.95,0.95,0.95,0.6,0.6,0.6,0.95,0.95,0.95,0.95,0.95,0.95,0.95,0.6,0.29,0.29]';
W_unit_pred  = [0.502,0.456,0.389,0.351,0.358,0.408,0.416,0.356,0.477,0.387,0.202,0.080,0.017,0.001,0.000,0.000,0.000,0.010,0.073,0.305,0.428,0.377,0.316,0.354]';
PV_unit_pred = [0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.048,0.168,0.357,0.564,0.674,0.677,0.656,0.634,0.556,0.444,0.298,0.141,0.000,0.000,0.000,0.000,0.000]';

% 设备容量及效率
V_pv = 16000; V_wind = 18000; V_ES = 5500; V_HS = 14000; 
V_EL = 2000;  V_HFC = 1000; V_EB = 11000; V_EC = 2500; V_AC = 1200;
P_grid_max = 10000;

yita_ES=0.9; yita_HS=0.9; yita_EB=0.95; yita_EL=0.6; yita_EC=3.89; yita_AC=0.8; yita_HFC_total=0.9;
K_pv=0.04; K_wind=0.091; K_EB=0.05; K_EL=0.016; K_EC=0.1; K_AC=0.015; K_ES_om=0.08; K_HS_om=0.016; K_HFC_om=0.033;
c_shift_E=0.15; c_cut_E=0.30; c_shift_H=0.10; c_cut_H=0.20; c_shift_C=0.10; c_cut_C=0.20; c_shift_DC=0.20;
alpha_shift=0.15; beta_cut=0.05; delta_max=0.1; Gamma_wind=0.6; Gamma_pv=0.6;

P_pv_max = V_pv * PV_unit_pred; P_wind_max = V_wind * W_unit_pred;
L_E_max = max(Load_E); L_H_max = max(Load_H); L_C_max = max(Load_C); L_DC_max = max(Load_DC);

ops_sol = sdpsettings('solver','gurobi','gurobi.NonConvex',2,'verbose',0);
ops_kkt = sdpsettings('kkt.dualbounds',0,'verbose',0);

%% =========================================================================
%  第1节：ε 网格规划与数据存档器初始化
% =========================================================================
n_pareto    = 6;     % 帕累托网格点数 
max_iter_CG = 15;    % C&CG 迭代次数
epsilon_tol = 1e-3; 

pareto_f1   = nan(n_pareto+2, 1);
pareto_f2   = nan(n_pareto+2, 1);
pareto_eps  = nan(n_pareto+2, 1);
Archive     = cell(n_pareto+2, 1); % 【核心】：存档器，保存每个点的最优调度变量

run_sequence = [0, 1, zeros(1, n_pareto)]; 
eps_grid_vals = nan(1, n_pareto);  

fprintf('=============================================================\n');
fprintf(' 启动 MO-TSRO 帕累托前沿计算...\n');

for outer_idx = 1 : (n_pareto + 2)
    run_mode = run_sequence(outer_idx);
    if outer_idx == 1
        current_eps = inf;
    elseif outer_idx == 2
        current_eps = 0; 
    else
        g = outer_idx - 2; 
        current_eps = eps_grid_vals(g);
    end
    
    % 【极其关键】：防止内存溢出，每次循环清空临时变量模型
    yalmip('clear'); 
    
    P_E_sl_in = sdpvar(24,1); P_E_sl_out = sdpvar(24,1); P_E_cut = sdpvar(24,1);
    P_H_sl_in = sdpvar(24,1); P_H_sl_out = sdpvar(24,1); P_H_cut = sdpvar(24,1);
    P_C_sl_in = sdpvar(24,1); P_C_sl_out = sdpvar(24,1); P_C_cut = sdpvar(24,1);
    P_DC_delay1 = sdpvar(24,1); P_DC_delay2 = sdpvar(24,1); Load_DC_opt = sdpvar(24,1);
    U_ES_ch = binvar(24,1); U_ES_dis = binvar(24,1);
    U_HS_ch = binvar(24,1); U_HS_dis = binvar(24,1);
    alpha_obj = sdpvar(1,1);

    Cost_1st_DR = sum(c_shift_E*P_E_sl_in + c_cut_E*P_E_cut) + sum(c_shift_H*P_H_sl_in + c_cut_H*P_H_cut) + ...
                  sum(c_shift_C*P_C_sl_in + c_cut_C*P_C_cut) + sum(c_shift_DC*(P_DC_delay1 + P_DC_delay2));
    
    f_E  = 100 * sum(((P_E_sl_in  + P_E_sl_out  + P_E_cut)  / L_E_max ).^2);
    f_H  = 100 * sum(((P_H_sl_in  + P_H_sl_out  + P_H_cut)  / L_H_max ).^2);
    f_C  = 100 * sum(((P_C_sl_in  + P_C_sl_out  + P_C_cut)  / L_C_max ).^2);
    f_DC = 100 * sum(((P_DC_delay1 + P_DC_delay2)           / L_DC_max).^2);
    f2_expr = f_E + f_H + f_C + f_DC;  

    First_Constraints = [
        0<=P_E_sl_in<=alpha_shift*Load_E, 0<=P_E_sl_out<=alpha_shift*Load_E, 0<=P_E_cut<=beta_cut*Load_E, sum(P_E_sl_in)==sum(P_E_sl_out),
        0<=P_H_sl_in<=alpha_shift*Load_H, 0<=P_H_sl_out<=alpha_shift*Load_H, 0<=P_H_cut<=beta_cut*Load_H, sum(P_H_sl_in)==sum(P_H_sl_out),
        0<=P_C_sl_in<=alpha_shift*Load_C, 0<=P_C_sl_out<=alpha_shift*Load_C, 0<=P_C_cut<=beta_cut*Load_C, sum(P_C_sl_in)==sum(P_C_sl_out),
        0<=P_DC_delay1, 0<=P_DC_delay2, (P_DC_delay1 + P_DC_delay2) <= 0.30*Load_DC,
        Load_DC_opt(1) == Load_DC(1) - P_DC_delay1(1) - P_DC_delay2(1) + P_DC_delay1(24) + P_DC_delay2(23),
        Load_DC_opt(2) == Load_DC(2) - P_DC_delay1(2) - P_DC_delay2(2) + P_DC_delay1(1) + P_DC_delay2(24),
        U_ES_ch + U_ES_dis <= 1, U_HS_ch + U_HS_dis <= 1
    ];
    for t = 3:24, First_Constraints = [First_Constraints, Load_DC_opt(t) == Load_DC(t) - P_DC_delay1(t) - P_DC_delay2(t) + P_DC_delay1(t-1) + P_DC_delay2(t-2)]; end

    if run_mode == 1
        sol_f2min = optimize(First_Constraints, f2_expr, ops_sol);
        f2_lb_val = value(f2_expr);
        eps_grid_vals = linspace(f2_lb_val, pareto_f2(1), n_pareto + 2);
        eps_grid_vals = eps_grid_vals(2:end-1);  
        current_eps = f2_lb_val + 1e-4;
        pareto_eps(outer_idx) = current_eps;
    end

    if isfinite(current_eps), Eps_Constraint = [f2_expr <= current_eps]; else, Eps_Constraint = []; end

    % --- C&CG 算法求解 ---
    K = 1; LB = -inf; UB = inf; u_wind_sc = P_wind_max; u_pv_sc = P_pv_max;
    Load_E_DR = Load_E + P_E_sl_in - P_E_sl_out - P_E_cut; Load_H_DR = Load_H + P_H_sl_in - P_H_sl_out - P_H_cut;
    Load_C_DR = Load_C + P_C_sl_in - P_C_sl_out - P_C_cut; Load_DC_waste_opt = 0.59 * Load_DC_opt;
    
    for iter = 1:max_iter_CG
        MP_Con = [First_Constraints, Eps_Constraint];
        for k = 1:K
            p_es_ch_k=sdpvar(24,1); p_es_dis_k=sdpvar(24,1); es_soc_k=sdpvar(24,1); p_hs_ch_k=sdpvar(24,1); p_hs_dis_k=sdpvar(24,1); hs_soc_k=sdpvar(24,1);
            p_el_k=sdpvar(24,1); p_hfc_e_k=sdpvar(24,1); p_hfc_h_k=sdpvar(24,1); p_grid_k=sdpvar(24,1); p_eb_k=sdpvar(24,1); p_ec_k=sdpvar(24,1);
            p_ac_h_k=sdpvar(24,1); p_ac_dc_k=sdpvar(24,1); p_ac_cool_k=sdpvar(24,1); p_ac_dccool_k=sdpvar(24,1); p_ec_cool_k=sdpvar(24,1); p_ec_dc_k=sdpvar(24,1); t_in_k=sdpvar(24,1);
            p_pv_k=sdpvar(24,1); p_wind_k=sdpvar(24,1); u_p=u_pv_sc(:,k); u_w=u_wind_sc(:,k);
            
            MP_Con = [MP_Con, 0<=p_pv_k<=u_p, 0<=p_wind_k<=u_w, 0<=p_es_ch_k<=U_ES_ch.*0.5.*V_ES, 0<=p_es_dis_k<=U_ES_dis.*0.5.*V_ES,
                es_soc_k(2:24)==es_soc_k(1:23)+p_es_ch_k(2:24)*yita_ES-p_es_dis_k(2:24)/yita_ES, es_soc_k(1)==0.3*V_ES+p_es_ch_k(1)*yita_ES-p_es_dis_k(1)/yita_ES, es_soc_k(24)==0.3*V_ES, 0.1*V_ES<=es_soc_k<=0.9*V_ES, 
                0<=p_hs_ch_k<=U_HS_ch.*1e6, 0<=p_hs_dis_k<=U_HS_dis.*1e6, p_el_k==p_hs_ch_k/yita_EL, p_el_k<=V_EL,
                hs_soc_k(2:24)==hs_soc_k(1:23)+p_hs_ch_k(2:24)*yita_HS-p_hs_dis_k(2:24)/yita_HS, hs_soc_k(1)==0.5*V_HS+p_hs_ch_k(1)*yita_HS-p_hs_dis_k(1)/yita_HS, hs_soc_k(24)==0.5*V_HS, 0.05*V_HS<=hs_soc_k<=0.95*V_HS,
                p_hfc_e_k+p_hfc_h_k<=yita_HFC_total*p_hs_dis_k, p_hfc_e_k>=0.7*p_hfc_h_k, p_hfc_e_k<=2*p_hfc_h_k, p_hfc_e_k<=V_HFC,
                0<=p_grid_k<=P_grid_max, 0<=p_eb_k<=V_EB, 0<=p_ec_k<=V_EC, p_ac_h_k>=0, p_ac_dc_k>=0, p_ac_dc_k<=Load_DC_waste_opt, p_ac_cool_k>=0, p_ac_dccool_k>=0, p_ec_cool_k>=0, p_ec_dc_k>=0,
                p_ac_h_k+p_ac_dc_k<=V_AC, p_ec_k*yita_EC==p_ec_cool_k+p_ec_dc_k, p_ac_cool_k+p_ac_dccool_k==yita_AC*(p_ac_dc_k+p_ac_h_k),
                t_in_k(2:24)==t_in_k(1:23)*exp(-1)+(0.04*(Load_DC_waste_opt(1:23)-p_ac_dc_k(1:23)-p_ec_dc_k(1:23)-p_ac_dccool_k(1:23))+T_out(1:23))*(1-exp(-1)),
                t_in_k(1)==t_in_k(24)*exp(-1)+(0.04*(Load_DC_waste_opt(24)-p_ac_dc_k(24)-p_ec_dc_k(24)-p_ac_dccool_k(24))+T_out(24))*(1-exp(-1)),
                17.78<=t_in_k<=27.22, p_ec_cool_k+p_ac_cool_k>=Load_C_DR, p_eb_k*yita_EB+p_hfc_h_k>=Load_H_DR+p_ac_h_k,
                p_grid_k+p_pv_k+p_wind_k+p_es_dis_k+p_hfc_e_k>=Load_E_DR+Load_DC_opt+p_es_ch_k+p_el_k+p_eb_k+p_ec_k];
            Cost_2nd_k = sum(price.*p_grid_k) + sum(K_wind*p_wind_k + K_pv*p_pv_k) + sum(K_ES_om*p_es_dis_k + K_HS_om*p_hs_dis_k + K_HFC_om*(p_hfc_e_k+p_hfc_h_k)) + sum(K_EL*p_el_k*yita_EL + K_EB*p_eb_k*yita_EB + K_EC*p_ec_k*yita_EC + K_AC*(p_ac_dc_k+p_ac_cool_k));
            MP_Con = [MP_Con, alpha_obj >= Cost_2nd_k];
        end
        sol_MP = optimize(MP_Con, Cost_1st_DR + alpha_obj, ops_sol);
        if sol_MP.problem ~= 0, break; end
        LB = max(LB, value(Cost_1st_DR + alpha_obj));
        
        U_ES_ch_s = value(U_ES_ch); U_ES_dis_s = value(U_ES_dis); U_HS_ch_s = value(U_HS_ch); U_HS_dis_s = value(U_HS_dis);
        L_E_DR_s = value(Load_E_DR); L_H_DR_s = value(Load_H_DR); L_C_DR_s = value(Load_C_DR);
        L_DC_s = value(Load_DC_opt); L_DC_w_s = value(Load_DC_waste_opt);
        
        z_pv = sdpvar(24,1); z_wind = sdpvar(24,1); u_pv_sp = P_pv_max.*(1 - delta_max*z_pv); u_wind_sp = P_wind_max.*(1 - delta_max*z_wind);
        U_Con = [0<=z_pv<=1, 0<=z_wind<=1, sum(z_pv)<=Gamma_pv/delta_max, sum(z_wind)<=Gamma_wind/delta_max];
        p_es_ch_sp=sdpvar(24,1); p_es_dis_sp=sdpvar(24,1); es_soc_sp=sdpvar(24,1); p_hs_ch_sp=sdpvar(24,1); p_hs_dis_sp=sdpvar(24,1); hs_soc_sp=sdpvar(24,1);
        p_el_sp=sdpvar(24,1); p_hfc_e_sp=sdpvar(24,1); p_hfc_h_sp=sdpvar(24,1); p_grid_sp=sdpvar(24,1); p_eb_sp=sdpvar(24,1); p_ec_sp=sdpvar(24,1);
        p_ac_h_sp=sdpvar(24,1); p_ac_dc_sp=sdpvar(24,1); p_ac_cool_sp=sdpvar(24,1); p_ac_dccool_sp=sdpvar(24,1); p_ec_cool_sp=sdpvar(24,1); p_ec_dc_sp=sdpvar(24,1); t_in_sp=sdpvar(24,1); p_pv_sp=sdpvar(24,1); p_wind_sp=sdpvar(24,1);
        
        Inner_Con = [ 0<=p_pv_sp<=u_pv_sp, 0<=p_wind_sp<=u_wind_sp, 0<=p_es_ch_sp<=U_ES_ch_s.*0.5.*V_ES, 0<=p_es_dis_sp<=U_ES_dis_s.*0.5.*V_ES,
            es_soc_sp(2:24)==es_soc_sp(1:23)+p_es_ch_sp(2:24)*yita_ES-p_es_dis_sp(2:24)/yita_ES, es_soc_sp(1)==0.3*V_ES+p_es_ch_sp(1)*yita_ES-p_es_dis_sp(1)/yita_ES, es_soc_sp(24)==0.3*V_ES, 0.1*V_ES<=es_soc_sp<=0.9*V_ES,
            0<=p_hs_ch_sp<=U_HS_ch_s.*1e6, 0<=p_hs_dis_sp<=U_HS_dis_s.*1e6, p_el_sp==p_hs_ch_sp/yita_EL, p_el_sp<=V_EL,
            hs_soc_sp(2:24)==hs_soc_sp(1:23)+p_hs_ch_sp(2:24)*yita_HS-p_hs_dis_sp(2:24)/yita_HS, hs_soc_sp(1)==0.5*V_HS+p_hs_ch_sp(1)*yita_HS-p_hs_dis_sp(1)/yita_HS, hs_soc_sp(24)==0.5*V_HS, 0.05*V_HS<=hs_soc_sp<=0.95*V_HS,
            p_hfc_e_sp+p_hfc_h_sp<=yita_HFC_total*p_hs_dis_sp, p_hfc_e_sp>=0.7*p_hfc_h_sp, p_hfc_e_sp<=2*p_hfc_h_sp, p_hfc_e_sp<=V_HFC,
            0<=p_grid_sp<=P_grid_max, 0<=p_eb_sp<=V_EB, 0<=p_ec_sp<=V_EC, p_ac_h_sp>=0, p_ac_dc_sp>=0, p_ac_dc_sp<=L_DC_w_s, p_ac_cool_sp>=0, p_ac_dccool_sp>=0, p_ec_cool_sp>=0, p_ec_dc_sp>=0,
            p_ac_h_sp+p_ac_dc_sp<=V_AC, p_ec_sp*yita_EC==p_ec_cool_sp+p_ec_dc_sp, p_ac_cool_sp+p_ac_dccool_sp==yita_AC*(p_ac_dc_sp+p_ac_h_sp),
            t_in_sp(2:24)==t_in_sp(1:23)*exp(-1)+(0.04*(L_DC_w_s(1:23)-p_ac_dc_sp(1:23)-p_ec_dc_sp(1:23)-p_ac_dccool_sp(1:23))+T_out(1:23))*(1-exp(-1)),
            t_in_sp(1)==t_in_sp(24)*exp(-1)+(0.04*(L_DC_w_s(24)-p_ac_dc_sp(24)-p_ec_dc_sp(24)-p_ac_dccool_sp(24))+T_out(24))*(1-exp(-1)),
            17.78<=t_in_sp<=27.22, p_ec_cool_sp+p_ac_cool_sp>=L_C_DR_s, p_eb_sp*yita_EB+p_hfc_h_sp>=L_H_DR_s+p_ac_h_sp,
            p_grid_sp+p_pv_sp+p_wind_sp+p_es_dis_sp+p_hfc_e_sp>=L_E_DR_s+L_DC_s+p_es_ch_sp+p_el_sp+p_eb_sp+p_ec_sp ];
        Inner_Obj = sum(price.*p_grid_sp) + sum(K_wind*p_wind_sp + K_pv*p_pv_sp) + sum(K_ES_om*p_es_dis_sp + K_HS_om*p_hs_dis_sp + K_HFC_om*(p_hfc_e_sp+p_hfc_h_sp)) + sum(K_EL*p_el_sp*yita_EL + K_EB*p_eb_sp*yita_EB + K_EC*p_ec_sp*yita_EC + K_AC*(p_ac_dc_sp+p_ac_cool_sp));
        
        [KKT_Con, ~] = kkt(Inner_Con, Inner_Obj, [z_pv; z_wind], ops_kkt);
        sol_SP = optimize([U_Con, KKT_Con], -Inner_Obj, ops_sol);
        if sol_SP.problem ~= 0, break; end
        
        worst_pv = value(u_pv_sp); worst_wind = value(u_wind_sp);
        UB = min(UB, value(Cost_1st_DR) + value(Inner_Obj));
        gap = abs(UB-LB)/max(abs(UB),1e-8);
        if gap <= epsilon_tol, break; else, K = K+1; u_wind_sc(:,K) = worst_wind; u_pv_sc(:,K) = worst_pv; end
    end
    
    if ~isnan(UB)
        pareto_f1(outer_idx) = LB; pareto_f2(outer_idx) = value(f2_expr); pareto_eps(outer_idx) = current_eps;
        fprintf('  ✅ 成功探出帕累托点 %d：f1=%.2f，f2=%.4f\n', outer_idx, pareto_f1(outer_idx), pareto_f2(outer_idx));
        
        % 将这个点对应的 1st Stage 变量归档
        Archive{outer_idx}.P_E_sl_in = value(P_E_sl_in); Archive{outer_idx}.P_E_sl_out = value(P_E_sl_out); Archive{outer_idx}.P_E_cut = value(P_E_cut);
        Archive{outer_idx}.P_H_sl_in = value(P_H_sl_in); Archive{outer_idx}.P_H_sl_out = value(P_H_sl_out); Archive{outer_idx}.P_H_cut = value(P_H_cut);
        Archive{outer_idx}.P_C_sl_in = value(P_C_sl_in); Archive{outer_idx}.P_C_sl_out = value(P_C_sl_out); Archive{outer_idx}.P_C_cut = value(P_C_cut);
        Archive{outer_idx}.P_DC_delay1 = value(P_DC_delay1); Archive{outer_idx}.P_DC_delay2 = value(P_DC_delay2); Archive{outer_idx}.Load_DC_opt = value(Load_DC_opt);
        Archive{outer_idx}.U_ES_ch = value(U_ES_ch); Archive{outer_idx}.U_ES_dis = value(U_ES_dis); 
        Archive{outer_idx}.U_HS_ch = value(U_HS_ch); Archive{outer_idx}.U_HS_dis = value(U_HS_dis);
        Archive{outer_idx}.Load_E_DR = value(Load_E_DR); Archive{outer_idx}.Load_H_DR = value(Load_H_DR); Archive{outer_idx}.Load_C_DR = value(Load_C_DR);
        Archive{outer_idx}.worst_pv = worst_pv; Archive{outer_idx}.worst_wind = worst_wind;
    end
end

%% =========================================================================
%  第2节：模糊隶属度函数法 (Fuzzy Membership Function) 评价挑选最优折衷点
% =========================================================================
valid_mask = ~isnan(pareto_f1);
idx_list = find(valid_mask);
f1_valid = pareto_f1(valid_mask);
f2_valid = pareto_f2(valid_mask);

f1_max = max(f1_valid); f1_min = min(f1_valid);
f2_max = max(f2_valid); f2_min = min(f2_valid);

% 【核心物理意义纠正】：f1 和 f2 均为"越小越好（Cost 型）"的指标！
% 运营商希望 f1 (成本) 越小越好，用户希望 f2 (体验恶化度) 越小越好。
% 因此，当前值越接近 min，满意度 mu 应该越接近 1。
mu_1 = (f1_max - f1_valid) ./ (f1_max - f1_min);
mu_2 = (f2_max - f2_valid) ./ (f2_max - f2_min);
mu_total = mu_1 + mu_2;

% 挑选综合满意度最高的最优解
[~, best_rel_idx] = max(mu_total);
best_abs_idx = idx_list(best_rel_idx);
best_arc = Archive{best_abs_idx};

fprintf('\n=============================================================\n');
fprintf(' 🏅 模糊决策完成！最优折衷点为第 %d 个有效点：\n', best_rel_idx);
fprintf('    最优成本 f1 = %.2f 元\n', f1_valid(best_rel_idx));
fprintf('    最优体验恶化度 f2 = %.4f\n', f2_valid(best_rel_idx));
fprintf('=============================================================\n');

%% =========================================================================
%  第3节：提取该最优点的全天数据并进行最后一次确定性核算 
% =========================================================================
% 定义出图用的 2nd stage 变量
f_p_grid = sdpvar(24,1); f_p_pv = sdpvar(24,1); f_p_wind = sdpvar(24,1);
f_p_es_ch = sdpvar(24,1); f_p_es_dis = sdpvar(24,1); f_es_soc = sdpvar(24,1);
f_p_hs_ch = sdpvar(24,1); f_p_hs_dis = sdpvar(24,1); f_hs_soc = sdpvar(24,1);
f_p_el = sdpvar(24,1); f_p_hfc_e = sdpvar(24,1); f_p_hfc_h = sdpvar(24,1);
f_p_eb = sdpvar(24,1); f_p_ec = sdpvar(24,1);
f_ac_h = sdpvar(24,1); f_ac_dc = sdpvar(24,1); f_ac_cool = sdpvar(24,1); f_ac_dccool = sdpvar(24,1);
f_ec_cool = sdpvar(24,1); f_ec_dc = sdpvar(24,1); f_t_in = sdpvar(24,1);

L_DC_w_s = 0.59 * best_arc.Load_DC_opt;

Final_Con = [
    0<=f_p_pv<=best_arc.worst_pv, 0<=f_p_wind<=best_arc.worst_wind, 
    0<=f_p_es_ch<=best_arc.U_ES_ch.*0.5.*V_ES, 0<=f_p_es_dis<=best_arc.U_ES_dis.*0.5.*V_ES,
    f_es_soc(2:24)==f_es_soc(1:23)+f_p_es_ch(2:24)*yita_ES-f_p_es_dis(2:24)/yita_ES, f_es_soc(1)==0.3*V_ES+f_p_es_ch(1)*yita_ES-f_p_es_dis(1)/yita_ES, f_es_soc(24)==0.3*V_ES, 0.1*V_ES<=f_es_soc<=0.9*V_ES,
    0<=f_p_hs_ch<=best_arc.U_HS_ch.*1e6, 0<=f_p_hs_dis<=best_arc.U_HS_dis.*1e6, f_p_el==f_p_hs_ch/yita_EL, f_p_el<=V_EL,
    f_hs_soc(2:24)==f_hs_soc(1:23)+f_p_hs_ch(2:24)*yita_HS-f_p_hs_dis(2:24)/yita_HS, f_hs_soc(1)==0.5*V_HS+f_p_hs_ch(1)*yita_HS-f_p_hs_dis(1)/yita_HS, f_hs_soc(24)==0.5*V_HS, 0.05*V_HS<=f_hs_soc<=0.95*V_HS,
    f_p_hfc_e+f_p_hfc_h<=yita_HFC_total*f_p_hs_dis, f_p_hfc_e>=0.7*f_p_hfc_h, f_p_hfc_e<=2*f_p_hfc_h, f_p_hfc_e<=V_HFC,
    0<=f_p_grid<=P_grid_max, 0<=f_p_eb<=V_EB, 0<=f_p_ec<=V_EC, f_ac_h>=0, f_ac_dc>=0, f_ac_dc<=L_DC_w_s, f_ac_cool>=0, f_ac_dccool>=0, f_ec_cool>=0, f_ec_dc>=0,
    f_ac_h+f_ac_dc<=V_AC, f_p_ec*yita_EC==f_ec_cool+f_ec_dc, f_ac_cool+f_ac_dccool==yita_AC*(f_ac_dc+f_ac_h),
    f_t_in(2:24)==f_t_in(1:23)*exp(-1)+(0.04*(L_DC_w_s(1:23)-f_ac_dc(1:23)-f_ec_dc(1:23)-f_ac_dccool(1:23))+T_out(1:23))*(1-exp(-1)),
    f_t_in(1)==f_t_in(24)*exp(-1)+(0.04*(L_DC_w_s(24)-f_ac_dc(24)-f_ec_dc(24)-f_ac_dccool(24))+T_out(24))*(1-exp(-1)),
    17.78<=f_t_in<=27.22, f_ec_cool+f_ac_cool>=best_arc.Load_C_DR, f_p_eb*yita_EB+f_p_hfc_h>=best_arc.Load_H_DR+f_ac_h,
    f_p_grid+f_p_pv+f_p_wind+f_p_es_dis+f_p_hfc_e>=best_arc.Load_E_DR+best_arc.Load_DC_opt+f_p_es_ch+f_p_el+f_p_eb+f_p_ec
];

Final_Obj = sum(price.*f_p_grid) + sum(K_wind*f_p_wind + K_pv*f_p_pv) + sum(K_ES_om*f_p_es_dis + K_HS_om*f_p_hs_dis + K_HFC_om*(f_p_hfc_e+f_p_hfc_h)) + sum(K_EL*f_p_el*yita_EL + K_EB*f_p_eb*yita_EB + K_EC*f_p_ec*yita_EC + K_AC*(f_ac_dc+f_ac_cool));
optimize(Final_Con, Final_Obj, ops_sol);

%% =========================================================================
%  第4节：完全映射出图变量，对接 SCI 级代码格式
% =========================================================================
% 将归档的变量通过赋值，脱离 YALMIP 环境，让你之前写的画图代码无缝起作用
P_E_sl_in = best_arc.P_E_sl_in; P_E_sl_out = best_arc.P_E_sl_out; P_E_cut = best_arc.P_E_cut;
P_H_sl_in = best_arc.P_H_sl_in; P_H_sl_out = best_arc.P_H_sl_out; P_H_cut = best_arc.P_H_cut;
P_C_sl_in = best_arc.P_C_sl_in; P_C_sl_out = best_arc.P_C_sl_out; P_C_cut = best_arc.P_C_cut;
P_DC_delay1 = best_arc.P_DC_delay1; P_DC_delay2 = best_arc.P_DC_delay2; Load_DC_opt = best_arc.Load_DC_opt;
Load_E_DR = best_arc.Load_E_DR; Load_H_DR = best_arc.Load_H_DR; Load_C_DR = best_arc.Load_C_DR;

% 将求解的变量映射为出图的名称
P_grid = value(f_p_grid); P_pv = value(f_p_pv); P_wind = value(f_p_wind);
P_ES_dis = value(f_p_es_dis); P_ES_ch = value(f_p_es_ch); ES = value(f_es_soc);
P_HFC_e = value(f_p_hfc_e); P_HFC_h = value(f_p_hfc_h);
P_EB = value(f_p_eb); P_EC = value(f_p_ec); P_EL = value(f_p_el);
P_AC_h = value(f_ac_h); P_AC_DC = value(f_ac_dc); P_AC_cool = value(f_ac_cool); P_AC_DCcool = value(f_ac_dccool);
P_EC_cool = value(f_ec_cool); P_EC_DC = value(f_ec_dc); T_in = value(f_t_in);

%% =========================================================================
%  画图部分 (调用你的出图代码，展示"最优折衷点"的数据)
% =========================================================================
t = 1:24;

% -------- [图1] 全系统单日精细化功率平衡与温控调度图 --------
figure('Color','w','Position',[100, 100, 1200, 800],'Name','最优解精细调度全景图');
subplot(2,2,1);
Supply_E = [P_grid, P_pv, P_wind, P_ES_dis, P_HFC_e];
Consume_E = [-P_ES_ch, -P_EC, -P_EL, -P_EB];
bar(t, Supply_E, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
bar(t, Consume_E, 0.8, 'stacked', 'EdgeColor', 'none');
plot(t, Load_E_DR + Load_DC_opt, 'k-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'w');
title('最优折衷点：电功率平衡', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); xticks(2:2:24); grid on;
legend('主网购电','光伏','风电','电储放电','燃料电池','电储充电','电制冷','电解槽','电锅炉','总电负荷','Location','southoutside','NumColumns',5);

subplot(2,2,2);
Supply_H = [P_EB*yita_EB, P_HFC_h]; Consume_H = [-P_AC_h];
bar(t, Supply_H, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
bar(t, Consume_H, 0.8, 'FaceColor', '#D95319', 'EdgeColor', 'none');
plot(t, Load_H_DR, 'r-^', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'w');
title('最优折衷点：热功率平衡', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); xticks(2:2:24); grid on;
legend('电锅炉产热','燃料电池发热','吸收制冷抽热','实际热负荷', 'Location','southoutside','NumColumns',4);

subplot(2,2,3);
Supply_C = [P_EC_cool, P_AC_cool];
bar(t, Supply_C, 0.8, 'stacked', 'EdgeColor', 'none'); hold on;
plot(t, Load_C_DR, 'b-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'w');
title('最优折衷点：冷功率平衡', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); ylabel('功率/kW'); xlim([0.5 24.5]); xticks(2:2:24); grid on;
legend('电制冷产冷','吸收制冷产冷','实际冷负荷', 'Location','southoutside','NumColumns',3);

subplot(2,2,4);
yyaxis left;
plot(t, ES / V_ES, '-s', 'LineWidth', 1.5, 'Color', '#0072BD', 'MarkerFaceColor', 'w');
ylabel('电储能 SOC', 'Color', '#0072BD'); ylim([0 1]); set(gca, 'YColor', '#0072BD');
yyaxis right;
plot(t, T_in, '-d', 'LineWidth', 1.5, 'Color', '#D95319', 'MarkerFaceColor', 'w');
ylabel('机房温度 / °C', 'Color', '#D95319'); ylim([15 30]); set(gca, 'YColor', '#D95319');
yline(27.22, '--r', 'T_{max}'); yline(17.78, '--b', 'T_{min}');
title('最优折衷点：电储能SOC变化与数据中心精细温控', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间/h'); xlim([0.5 24.5]); xticks(2:2:24); grid on;

% -------- [图2] 四维全息综合需求响应分析 (完整平移+削减+延迟版) --------
figure('Color', 'w', 'Position', [50, 50, 1400, 450], 'Name', '四维全息综合需求响应分析');
c_blue=[0.00 0.45 0.74]; c_red=[0.85 0.33 0.10]; c_orange=[0.93 0.69 0.13]; c_green=[0.47 0.67 0.19]; c_cyan=[0.30 0.75 0.93]; c_yellow=[0.95 0.85 0.25]; c_purple=[0.49 0.18 0.56];

subplot(1,4,1);
plot(t, Load_E, 'k--', 'LineWidth', 1.5); hold on; plot(t, Load_E_DR, 'Color', c_blue, 'LineWidth', 2);
bar(t, P_E_sl_in, 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6); bar(t, -P_E_sl_out, 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6); bar(t, -P_E_cut, 'FaceColor', c_red, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('最优折衷点：电负荷需求响应', 'FontSize', 12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;
legend('原始预测负荷', '优化响应负荷', '负荷转入', '负荷转出', '负荷削减', 'Location','southoutside','NumColumns',2);

subplot(1,4,2);
plot(t, Load_H, 'k--', 'LineWidth', 1.5); hold on; plot(t, Load_H_DR, 'Color', c_orange, 'LineWidth', 2);
bar(t, P_H_sl_in, 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6); bar(t, -P_H_sl_out, 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6); bar(t, -P_H_cut, 'FaceColor', c_blue, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('最优折衷点：热负荷需求响应', 'FontSize', 12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;

subplot(1,4,3);
plot(t, Load_C, 'k--', 'LineWidth', 1.5); hold on; plot(t, Load_C_DR, 'Color', c_cyan, 'LineWidth', 2);
bar(t, P_C_sl_in, 'FaceColor', c_green, 'EdgeColor', 'none', 'FaceAlpha', 0.6); bar(t, -P_C_sl_out, 'FaceColor', c_yellow, 'EdgeColor', 'none', 'FaceAlpha', 0.6); bar(t, -P_C_cut, 'FaceColor', c_purple, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
title('最优折衷点：冷负荷需求响应', 'FontSize', 12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;

subplot(1,4,4); 
yyaxis left;
Shift_out = P_DC_delay1 + P_DC_delay2; Shift_in = Load_DC_opt - Load_DC + Shift_out;
bar(t, Shift_in, 'FaceColor', c_green, 'EdgeColor', 'none', 'BarWidth', 0.6); hold on; bar(t, -Shift_out, 'FaceColor', c_yellow, 'EdgeColor', 'none', 'BarWidth', 0.6);
ylabel('时空延迟转移量 / kW'); ylim([-max(Load_DC)*0.4, max(Load_DC)*0.4]); ax = gca; ax.YColor = 'k'; 
yyaxis right;
plot(t, Load_DC, 'k--', 'LineWidth', 1.5); hold on; plot(t, Load_DC_opt, '-s', 'Color', c_purple, 'LineWidth', 2, 'MarkerFaceColor','w');
ylabel('数据中心算力功率 / kW'); ylim([min(Load_DC)*0.7, max(Load_DC)*1.2]); ax = gca; ax.YColor = 'k';
title('最优折衷点：数据中心延迟响应', 'FontSize', 12); xlabel('时间 / h'); xlim([1 24]); grid on;
legend('算力转入', '算力延迟转出', '原始基础算力', '最终优化算力', 'Location','southoutside','NumColumns',2);

