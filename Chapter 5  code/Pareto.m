clear; clc;
% =========================================================================
% 园区综合能源系统两阶段鲁棒多目标优化 (MO-TSRO)
% 算法：ε-约束法 + C&CG 算法
% -----------------------------------------------------------------------
% 目标1 (f1): 系统综合运行成本（元）
% 目标2 (f2): 四维需求响应灵活性指数（电/热/冷/DC 平方和，权重 1:1:1:1）
%
%   f_E  = 100 * Σ_t [(P_E,sl,in^t + P_E,sl,out^t + P_E,cut^t) / L_E^max]²
%   f_H  = 100 * Σ_t [(P_H,sl,in^t + P_H,sl,out^t + P_H,cut^t) / L_H^max]²
%   f_C  = 100 * Σ_t [(P_C,sl,in^t + P_C,sl,out^t + P_C,cut^t) / L_C^max]²
%   f_DC = 100 * Σ_t [(P_DC,delay1^t + P_DC,delay2^t)           / L_DC^max]²
%   f2   = f_E + f_H + f_C + f_DC
%
% ε-约束策略：对每个 ε ∈ {ε_1,...,ε_N}，求解：
%   min  f1  s.t.  f2 ≤ ε，以及原有 TSRO 约束
% 通过 C&CG 算法处理第二阶段鲁棒对称不确定性
% =========================================================================

%% =========================================================================
%  第0节：基础数据准备（与原版完全一致）
% =========================================================================
Load_E  = [3080.5,2620.2,2460.8,2390.6,2530.3,2580.7,2660.5,3080.4,...
           3220.6,3960.8,4150.3,4120.9,3980.5,4450.6,4280.2,4830.8,...
           5410.4,5680.7,6150.6,5260.3,5350.8,4580.5,4280.2,3280.7]';
Load_H  = [5180.5,4980.2,4780.8,4380.6,4520.3,4880.5,8180.2,7180.8,...
           5950.5,4180.3,3080.6,2450.2,2080.8,1980.5,2120.3,3050.6,...
           3980.5,5150.8,6250.2,7380.5,7680.8,7980.3,6850.6,5980.2]';
Load_C  = [180.5,120.3,80.6,60.2,90.5,250.8,380.4,620.6,980.3,...
           1780.5,2580.8,3080.3,3380.6,3420.2,2950.5,2480.8,1680.3,...
           1080.6,580.2,380.5,280.8,220.3,180.6,150.5]';
Load_DC = 1.25*[645.8,715.4,662.0,779.0,1036.6,875.7,875.0,757.3,873.6,...
           818.2,1112.4,1135.5,979.3,1149.7,1123.3,746.5,971.1,...
           672.8,678.1,703.2,1087.4,986.7,739.7,1021.9]';

T_out  = [7.2,6.5,6.0,5.7,6.1,7.5,9.3,11.6,13.8,15.5,16.7,17.4,...
          17.8,18.1,17.4,15.9,13.9,11.7,10.0,8.8,8.1,7.7,7.4,7.2]';
price  = [0.29,0.29,0.29,0.29,0.29,0.29,0.6,0.6,0.95,0.95,0.95,...
          0.6,0.6,0.6,0.95,0.95,0.95,0.95,0.95,0.95,0.95,0.6,0.29,0.29]';
W_unit_pred  = [0.502,0.456,0.389,0.351,0.358,0.408,0.416,0.356,...
                0.477,0.387,0.202,0.080,0.017,0.001,0.000,0.000,...
                0.000,0.010,0.073,0.305,0.428,0.377,0.316,0.354]';
PV_unit_pred = [0.000,0.000,0.000,0.000,0.000,0.000,0.000,0.048,...
                0.168,0.357,0.564,0.674,0.677,0.656,0.634,0.556,...
                0.444,0.298,0.141,0.000,0.000,0.000,0.000,0.000]';

% 设备容量及效率
V_pv = 16000; V_wind = 18000; V_ES = 5500; V_HS = 14000; 
V_EL = 2000;  V_HFC = 1000; V_EB = 11000; V_EC = 2500; V_AC = 1200;
P_grid_max = 10000;

% 效率
yita_ES=0.9; yita_HS=0.9; yita_EB=0.95; yita_EL=0.6;
yita_EC=3.89; yita_AC=0.8; yita_HFC_total=0.9;

% 运维成本系数
K_pv=0.04; K_wind=0.091; K_EB=0.05; K_EL=0.016;
K_EC=0.1;  K_AC=0.015;   K_ES_om=0.08; K_HS_om=0.016; K_HFC_om=0.033;

% 需求响应参数
c_shift_E=0.15; c_cut_E=0.30; c_shift_H=0.10; c_cut_H=0.20;
c_shift_C=0.10; c_cut_C=0.20; c_shift_DC=0.20;
alpha_shift=0.15; beta_cut=0.05;

% 鲁棒参数
delta_max=0.1; Gamma_wind=0.6; Gamma_pv=0.6;
P_pv_max   = V_pv  * PV_unit_pred;
P_wind_max = V_wind * W_unit_pred;

% 求解器设置
ops_sol = sdpsettings('solver','gurobi','gurobi.NonConvex',2,'verbose',0);
ops_kkt = sdpsettings('kkt.dualbounds',0,'verbose',0);

%% =========================================================================
%  第1节：f2 归一化参数（四维）
% =========================================================================
L_E_max  = max(Load_E);    % 电负荷最大值，用于归一化
L_H_max  = max(Load_H);    % 热负荷最大值
L_C_max  = max(Load_C);    % 冷负荷最大值
L_DC_max = max(Load_DC);   % DC负荷最大值

fprintf('=============================================================\n');
fprintf(' 多目标两阶段鲁棒优化 (MO-TSRO)  |  ε-约束法帕累托搜索\n');
fprintf('=============================================================\n');
fprintf(' 归一化基准: L_E_max=%.0f  L_H_max=%.0f  L_C_max=%.0f  L_DC_max=%.0f\n',...
    L_E_max,L_H_max,L_C_max,L_DC_max);

%% =========================================================================
%  第2节：ε 网格规划
%  策略：先跑无约束TSRO得到 f2_ub；再跑纯最小化f2得到 f2_lb
%  然后在 [f2_lb, f2_ub] 上均匀撒点
% =========================================================================
n_pareto    = 8;     % 帕累托网格内部点数（不含两端点）
max_iter_CG = 30;    % C&CG 最大迭代次数
epsilon_tol = 5e-4;  % C&CG 收敛阈值

% 存储结果
pareto_f1   = nan(n_pareto+2, 1);  % 行 = 帕累托点（含两端点）
pareto_f2   = nan(n_pareto+2, 1);
pareto_eps  = nan(n_pareto+2, 1);
conv_history = cell(n_pareto+2, 1); % 存各点C&CG收敛记录

%% =========================================================================
%  第3节：主循环 —— 先两端点，再内部网格
%  run_mode: 0 = 无ε约束(求f1最小)，1 = 纯最小化f2，2 = 给定ε约束
% =========================================================================
run_sequence = [0, 1, zeros(1, n_pareto)];  % 0=f1opt, 1=f2opt, 2...=grid
% 真正的 ε 值在跑完端点后填充
eps_grid_vals = nan(1, n_pareto);  % 内部 ε 值（后面填充）

for outer_idx = 1 : (n_pareto + 2)

    run_mode = run_sequence(outer_idx);
    
    if outer_idx == 1
        fprintf('\n\n★★★ [端点1/2] 最小化 f1（无ε约束）—— 原始TSRO ★★★\n');
        current_eps = inf;
    elseif outer_idx == 2
        fprintf('\n\n★★★ [端点2/2] 最小化 f2（纯DR最省模式）★★★\n');
        current_eps = 0;  % 不用于f2最小化，而是用 run_mode=1 标记
    else
        g = outer_idx - 2;  % 1..n_pareto
        current_eps = eps_grid_vals(g);
        fprintf('\n\n★★★ [帕累托网格点 %d/%d]  ε = %.4f ★★★\n', g, n_pareto, current_eps);
    end

    % =====================================================================
    %  定义第一阶段变量（每次外层循环重新定义，确保YALMIP干净）
    % =====================================================================
    yalmip('clear');  % <--- 必须加上这一句，极其关键！！！
    
    P_E_sl_in  = sdpvar(24,1); P_E_sl_out = sdpvar(24,1); P_E_cut  = sdpvar(24,1);
    P_H_sl_in  = sdpvar(24,1); P_H_sl_out = sdpvar(24,1); P_H_cut  = sdpvar(24,1);
    P_C_sl_in  = sdpvar(24,1); P_C_sl_out = sdpvar(24,1); P_C_cut  = sdpvar(24,1);
    P_DC_delay1 = sdpvar(24,1); P_DC_delay2 = sdpvar(24,1); Load_DC_opt = sdpvar(24,1);
    U_ES_ch = binvar(24,1); U_ES_dis = binvar(24,1);
    U_HS_ch = binvar(24,1); U_HS_dis = binvar(24,1);
    alpha_obj = sdpvar(1,1);

    % ---------------------------------------------------------------
    %  f1 的第一阶段分量（DR补贴成本）
    % ---------------------------------------------------------------
    Cost_1st_DR = sum(c_shift_E*P_E_sl_in + c_cut_E*P_E_cut) ...
                + sum(c_shift_H*P_H_sl_in + c_cut_H*P_H_cut) ...
                + sum(c_shift_C*P_C_sl_in + c_cut_C*P_C_cut) ...
                + sum(c_shift_DC*(P_DC_delay1 + P_DC_delay2));
    Cost_1st = Cost_1st_DR;

    % ---------------------------------------------------------------
    %  f2：四维需求响应灵活性指数（凸二次型，仅含第一阶段变量）
    %      权重 1:1:1:1
    % ---------------------------------------------------------------
    f_E  = 100 * sum(((P_E_sl_in  + P_E_sl_out  + P_E_cut)  / L_E_max ).^2);
    f_H  = 100 * sum(((P_H_sl_in  + P_H_sl_out  + P_H_cut)  / L_H_max ).^2);
    f_C  = 100 * sum(((P_C_sl_in  + P_C_sl_out  + P_C_cut)  / L_C_max ).^2);
    f_DC = 100 * sum(((P_DC_delay1 + P_DC_delay2)            / L_DC_max).^2);
    f2_expr = f_E + f_H + f_C + f_DC;  % 总DR灵活性指数

    % ---------------------------------------------------------------
    %  第一阶段约束（与原版一致）
    % ---------------------------------------------------------------
    First_Constraints = [...
        0 <= P_E_sl_in  <= alpha_shift*Load_E,  ...
        0 <= P_E_sl_out <= alpha_shift*Load_E,  ...
        0 <= P_E_cut    <= beta_cut*Load_E,     ...
        sum(P_E_sl_in)  == sum(P_E_sl_out),     ...
        0 <= P_H_sl_in  <= alpha_shift*Load_H,  ...
        0 <= P_H_sl_out <= alpha_shift*Load_H,  ...
        0 <= P_H_cut    <= beta_cut*Load_H,     ...
        sum(P_H_sl_in)  == sum(P_H_sl_out),     ...
        0 <= P_C_sl_in  <= alpha_shift*Load_C,  ...
        0 <= P_C_sl_out <= alpha_shift*Load_C,  ...
        0 <= P_C_cut    <= beta_cut*Load_C,     ...
        sum(P_C_sl_in)  == sum(P_C_sl_out),     ...
        0 <= P_DC_delay1, 0 <= P_DC_delay2,     ...
        (P_DC_delay1 + P_DC_delay2) <= 0.30*Load_DC, ...
        Load_DC_opt(1) == Load_DC(1) - P_DC_delay1(1) - P_DC_delay2(1) ...
                        + P_DC_delay1(24) + P_DC_delay2(23), ...
        Load_DC_opt(2) == Load_DC(2) - P_DC_delay1(2) - P_DC_delay2(2) ...
                        + P_DC_delay1(1)  + P_DC_delay2(24), ...
        U_ES_ch + U_ES_dis <= 1, ...
        U_HS_ch + U_HS_dis <= 1  ...
    ];
    for t = 3:24
        First_Constraints = [First_Constraints, ...
            Load_DC_opt(t) == Load_DC(t) - P_DC_delay1(t) - P_DC_delay2(t) ...
                            + P_DC_delay1(t-1) + P_DC_delay2(t-2)];
    end

    % ---------------------------------------------------------------
    %  若 run_mode == 1（左端点：f2最小化模式）
    %  Step1: 先用单目标QP求出 f2 的理论下界 f2_min
    %  Step2: 将 epsilon 设为 f2_min + 1e-4（数值容差，防止边界不可行）
    %  Step3: 以此 epsilon 走完完整 C&CG，得到左端点的真实 f1 值
    %  ⚠️ 绝对不能 continue 跳过 C&CG！否则左端点 f1 永远是 NaN。
    % ---------------------------------------------------------------
    if run_mode == 1
        % --- Step1: 纯 QP 求 f2 下界（仅第一阶段变量，无需C&CG）---
        sol_f2min = optimize(First_Constraints, f2_expr, ops_sol);
        if sol_f2min.problem ~= 0
            warning('f2最小化 QP 求解失败！跳过此端点。');
            continue;  % 这里 continue 是安全的，因为QP本身就失败了
        end
        f2_lb_val = value(f2_expr);
        fprintf('  [Step1] f2_min（理论下界）= %.6f\n', f2_lb_val);

        % --- Step2: 生成内部 ε 网格（趁此时 f2_ub 已知）---
        f2_ub_val = pareto_f2(1);  % 端点①（f1最优）时记录的 f2 值
        eps_grid_vals = linspace(f2_lb_val, f2_ub_val, n_pareto + 2);
        eps_grid_vals = eps_grid_vals(2:end-1);  % 去掉两端点，保留内部
        fprintf('  [Step2] ε 网格生成: [%.4f, %.4f, ..., %.4f]\n', ...
            eps_grid_vals(1), eps_grid_vals(2), eps_grid_vals(end));

        % --- Step3: 以 f2_min + 容差 作为本端点的 epsilon ---
        % 加 1e-4 的原因：若直接令 eps = f2_min，数值误差会让 f2_expr <= f2_min
        % 的约束恰好在可行域边界，C&CG 的 MP 极易报不可行。
        current_eps = f2_lb_val + 1e-4;
        pareto_eps(outer_idx) = current_eps;
        fprintf('  [Step3] 左端点 ε = f2_min + 1e-4 = %.6f，开始 C&CG...\n', current_eps);
        % ⬇️ 不 continue，直接落入下方 C&CG 流程
    end

    % ---------------------------------------------------------------
    %  ε-约束：若 current_eps < inf，则添加 f2 <= current_eps
    %  （run_mode==0 时 current_eps=inf，即无约束原始TSRO）
    % ---------------------------------------------------------------
    if isfinite(current_eps)
        Eps_Constraint = [f2_expr <= current_eps];
    else
        Eps_Constraint = [];
    end

    % =====================================================================
    %  C&CG 主循环（与原版结构完全相同，添加ε约束入MP）
    % =====================================================================
    K = 1; LB = -inf; UB = inf;
    u_wind_sc = P_wind_max; u_pv_sc = P_pv_max;
    h_LB = []; h_UB = []; h_GAP = [];

    Load_E_DR = Load_E + P_E_sl_in - P_E_sl_out - P_E_cut;
    Load_H_DR = Load_H + P_H_sl_in - P_H_sl_out - P_H_cut;
    Load_C_DR = Load_C + P_C_sl_in - P_C_sl_out - P_C_cut;
    Load_DC_waste_opt = 0.59 * Load_DC_opt;

    for iter = 1:max_iter_CG

        % ==============================================================
        %  主问题 (MP)：min f1 + α，加入 ε 约束
        % ==============================================================
        MP_Con = [First_Constraints, Eps_Constraint];

        for k = 1:K
            p_es_ch_k = sdpvar(24,1); p_es_dis_k = sdpvar(24,1); es_soc_k = sdpvar(24,1);
            p_hs_ch_k = sdpvar(24,1); p_hs_dis_k = sdpvar(24,1); hs_soc_k = sdpvar(24,1);
            p_el_k = sdpvar(24,1); p_hfc_e_k = sdpvar(24,1); p_hfc_h_k = sdpvar(24,1);
            p_grid_k = sdpvar(24,1); p_eb_k = sdpvar(24,1); p_ec_k = sdpvar(24,1);
            p_ac_h_k = sdpvar(24,1); p_ac_dc_k = sdpvar(24,1);
            p_ac_cool_k = sdpvar(24,1); p_ac_dccool_k = sdpvar(24,1);
            p_ec_cool_k = sdpvar(24,1); p_ec_dc_k = sdpvar(24,1); t_in_k = sdpvar(24,1);
            p_pv_k = sdpvar(24,1); p_wind_k = sdpvar(24,1);
            u_p = u_pv_sc(:,k); u_w = u_wind_sc(:,k);

            % 第二阶段调度可行性约束（场景 k）
            MP_Con = [MP_Con, ...
                0<=p_pv_k<=u_p, 0<=p_wind_k<=u_w, ...
                0<=p_es_ch_k<=U_ES_ch.*0.5.*V_ES, 0<=p_es_dis_k<=U_ES_dis.*0.5.*V_ES, ...
                es_soc_k(2:24)==es_soc_k(1:23)+p_es_ch_k(2:24)*yita_ES-p_es_dis_k(2:24)/yita_ES,...
                es_soc_k(1)==0.3*V_ES+p_es_ch_k(1)*yita_ES-p_es_dis_k(1)/yita_ES,...
                es_soc_k(24)==0.3*V_ES, 0.1*V_ES<=es_soc_k<=0.9*V_ES, ...
                0<=p_hs_ch_k<=U_HS_ch.*1e6, 0<=p_hs_dis_k<=U_HS_dis.*1e6,...
                p_el_k==p_hs_ch_k/yita_EL, p_el_k<=V_EL,...
                hs_soc_k(2:24)==hs_soc_k(1:23)+p_hs_ch_k(2:24)*yita_HS-p_hs_dis_k(2:24)/yita_HS,...
                hs_soc_k(1)==0.5*V_HS+p_hs_ch_k(1)*yita_HS-p_hs_dis_k(1)/yita_HS,...
                hs_soc_k(24)==0.5*V_HS, 0.05*V_HS<=hs_soc_k<=0.95*V_HS,...
                p_hfc_e_k+p_hfc_h_k<=yita_HFC_total*p_hs_dis_k,...
                p_hfc_e_k>=0.7*p_hfc_h_k, p_hfc_e_k<=2*p_hfc_h_k, p_hfc_e_k<=V_HFC,...
                0<=p_grid_k<=P_grid_max, 0<=p_eb_k<=V_EB, 0<=p_ec_k<=V_EC,...
                p_ac_h_k>=0, p_ac_dc_k>=0, p_ac_dc_k<=Load_DC_waste_opt,...
                p_ac_cool_k>=0, p_ac_dccool_k>=0, p_ec_cool_k>=0, p_ec_dc_k>=0,...
                p_ac_h_k+p_ac_dc_k<=V_AC,...
                p_ec_k*yita_EC==p_ec_cool_k+p_ec_dc_k,...
                p_ac_cool_k+p_ac_dccool_k==yita_AC*(p_ac_dc_k+p_ac_h_k),...
                t_in_k(2:24)==t_in_k(1:23)*exp(-1)+(0.04*(Load_DC_waste_opt(1:23)...
                    -p_ac_dc_k(1:23)-p_ec_dc_k(1:23)-p_ac_dccool_k(1:23))+T_out(1:23))*(1-exp(-1)),...
                t_in_k(1)==t_in_k(24)*exp(-1)+(0.04*(Load_DC_waste_opt(24)...
                    -p_ac_dc_k(24)-p_ec_dc_k(24)-p_ac_dccool_k(24))+T_out(24))*(1-exp(-1)),...
                17.78<=t_in_k<=27.22,...
                p_ec_cool_k+p_ac_cool_k>=Load_C_DR,...
                p_eb_k*yita_EB+p_hfc_h_k>=Load_H_DR+p_ac_h_k,...
                p_grid_k+p_pv_k+p_wind_k+p_es_dis_k+p_hfc_e_k>=...
                    Load_E_DR+Load_DC_opt+p_es_ch_k+p_el_k+p_eb_k+p_ec_k];

            Cost_2nd_k = sum(price.*p_grid_k) ...
                + sum(K_wind*p_wind_k + K_pv*p_pv_k) ...
                + sum(K_ES_om*p_es_dis_k + K_HS_om*p_hs_dis_k ...
                      + K_HFC_om*(p_hfc_e_k+p_hfc_h_k)) ...
                + sum(K_EL*p_el_k*yita_EL + K_EB*p_eb_k*yita_EB ...
                      + K_EC*p_ec_k*yita_EC + K_AC*(p_ac_dc_k+p_ac_cool_k));
            MP_Con = [MP_Con, alpha_obj >= Cost_2nd_k];
        end

        % 求解主问题
        sol_MP = optimize(MP_Con, Cost_1st + alpha_obj, ops_sol);
        if sol_MP.problem ~= 0
            warning('[MP] 求解失败 (iter=%d, eps_idx=%d), problem=%d', iter, outer_idx, sol_MP.problem);
            break;
        end
        LB = max(LB, value(Cost_1st + alpha_obj));
        h_LB(end+1) = LB;

        % 提取第一阶段最优解（固定到子问题）
        U_ES_ch_s = value(U_ES_ch); U_ES_dis_s = value(U_ES_dis);
        U_HS_ch_s = value(U_HS_ch); U_HS_dis_s = value(U_HS_dis);
        L_E_DR_s  = value(Load_E_DR); L_H_DR_s = value(Load_H_DR);
        L_C_DR_s  = value(Load_C_DR); L_DC_s   = value(Load_DC_opt);
        L_DC_w_s  = value(Load_DC_waste_opt);

        fprintf('  [iter %02d] LB=%.2f\n', iter, LB);

        % ==============================================================
        %  子问题 (SP)：KKT 求最恶劣场景
        % ==============================================================
        z_pv = sdpvar(24,1); z_wind = sdpvar(24,1);
        u_pv_sp = P_pv_max.*(1 - delta_max*z_pv);
        u_wind_sp = P_wind_max.*(1 - delta_max*z_wind);
        U_Con = [0<=z_pv<=1, 0<=z_wind<=1, ...
                 sum(z_pv)<=Gamma_pv/delta_max, sum(z_wind)<=Gamma_wind/delta_max];

        p_es_ch_sp=sdpvar(24,1); p_es_dis_sp=sdpvar(24,1); es_soc_sp=sdpvar(24,1);
        p_hs_ch_sp=sdpvar(24,1); p_hs_dis_sp=sdpvar(24,1); hs_soc_sp=sdpvar(24,1);
        p_el_sp=sdpvar(24,1); p_hfc_e_sp=sdpvar(24,1); p_hfc_h_sp=sdpvar(24,1);
        p_grid_sp=sdpvar(24,1); p_eb_sp=sdpvar(24,1); p_ec_sp=sdpvar(24,1);
        p_ac_h_sp=sdpvar(24,1); p_ac_dc_sp=sdpvar(24,1);
        p_ac_cool_sp=sdpvar(24,1); p_ac_dccool_sp=sdpvar(24,1);
        p_ec_cool_sp=sdpvar(24,1); p_ec_dc_sp=sdpvar(24,1); t_in_sp=sdpvar(24,1);
        p_pv_sp=sdpvar(24,1); p_wind_sp=sdpvar(24,1);

        Inner_Con = [...
            0<=p_pv_sp<=u_pv_sp, 0<=p_wind_sp<=u_wind_sp,...
            0<=p_es_ch_sp<=U_ES_ch_s.*0.5.*V_ES, 0<=p_es_dis_sp<=U_ES_dis_s.*0.5.*V_ES,...
            es_soc_sp(2:24)==es_soc_sp(1:23)+p_es_ch_sp(2:24)*yita_ES-p_es_dis_sp(2:24)/yita_ES,...
            es_soc_sp(1)==0.3*V_ES+p_es_ch_sp(1)*yita_ES-p_es_dis_sp(1)/yita_ES,...
            es_soc_sp(24)==0.3*V_ES, 0.1*V_ES<=es_soc_sp<=0.9*V_ES,...
            0<=p_hs_ch_sp<=U_HS_ch_s.*1e6, 0<=p_hs_dis_sp<=U_HS_dis_s.*1e6,...
            p_el_sp==p_hs_ch_sp/yita_EL, p_el_sp<=V_EL,...
            hs_soc_sp(2:24)==hs_soc_sp(1:23)+p_hs_ch_sp(2:24)*yita_HS-p_hs_dis_sp(2:24)/yita_HS,...
            hs_soc_sp(1)==0.5*V_HS+p_hs_ch_sp(1)*yita_HS-p_hs_dis_sp(1)/yita_HS,...
            hs_soc_sp(24)==0.5*V_HS, 0.05*V_HS<=hs_soc_sp<=0.95*V_HS,...
            p_hfc_e_sp+p_hfc_h_sp<=yita_HFC_total*p_hs_dis_sp,...
            p_hfc_e_sp>=0.7*p_hfc_h_sp, p_hfc_e_sp<=2*p_hfc_h_sp, p_hfc_e_sp<=V_HFC,...
            0<=p_grid_sp<=P_grid_max, 0<=p_eb_sp<=V_EB, 0<=p_ec_sp<=V_EC,...
            p_ac_h_sp>=0, p_ac_dc_sp>=0, p_ac_dc_sp<=L_DC_w_s,...
            p_ac_cool_sp>=0, p_ac_dccool_sp>=0, p_ec_cool_sp>=0, p_ec_dc_sp>=0,...
            p_ac_h_sp+p_ac_dc_sp<=V_AC,...
            p_ec_sp*yita_EC==p_ec_cool_sp+p_ec_dc_sp,...
            p_ac_cool_sp+p_ac_dccool_sp==yita_AC*(p_ac_dc_sp+p_ac_h_sp),...
            t_in_sp(2:24)==t_in_sp(1:23)*exp(-1)+(0.04*(L_DC_w_s(1:23)...
                -p_ac_dc_sp(1:23)-p_ec_dc_sp(1:23)-p_ac_dccool_sp(1:23))+T_out(1:23))*(1-exp(-1)),...
            t_in_sp(1)==t_in_sp(24)*exp(-1)+(0.04*(L_DC_w_s(24)...
                -p_ac_dc_sp(24)-p_ec_dc_sp(24)-p_ac_dccool_sp(24))+T_out(24))*(1-exp(-1)),...
            17.78<=t_in_sp<=27.22,...
            p_ec_cool_sp+p_ac_cool_sp>=L_C_DR_s,...
            p_eb_sp*yita_EB+p_hfc_h_sp>=L_H_DR_s+p_ac_h_sp,...
            p_grid_sp+p_pv_sp+p_wind_sp+p_es_dis_sp+p_hfc_e_sp>=...
                L_E_DR_s+L_DC_s+p_es_ch_sp+p_el_sp+p_eb_sp+p_ec_sp];

        Inner_Obj = sum(price.*p_grid_sp) ...
            + sum(K_wind*p_wind_sp + K_pv*p_pv_sp) ...
            + sum(K_ES_om*p_es_dis_sp + K_HS_om*p_hs_dis_sp ...
                  + K_HFC_om*(p_hfc_e_sp+p_hfc_h_sp)) ...
            + sum(K_EL*p_el_sp*yita_EL + K_EB*p_eb_sp*yita_EB ...
                  + K_EC*p_ec_sp*yita_EC + K_AC*(p_ac_dc_sp+p_ac_cool_sp));

        [KKT_Con, ~] = kkt(Inner_Con, Inner_Obj, [z_pv; z_wind], ops_kkt);
        sol_SP = optimize([U_Con, KKT_Con], -Inner_Obj, ops_sol);
        if sol_SP.problem ~= 0
            warning('[SP] KKT 推导失败 (iter=%d)', iter);
            break;
        end

        worst_pv   = value(u_pv_sp);
        worst_wind = value(u_wind_sp);
        UB = min(UB, value(Cost_1st) + value(Inner_Obj));
        h_UB(end+1) = UB;
        gap = abs(UB-LB)/max(abs(UB),1e-8);
        h_GAP(end+1) = gap;
        fprintf('  [iter %02d] UB=%.2f  Gap=%.6f%%\n', iter, UB, gap*100);

        if gap <= epsilon_tol
            fprintf('  ✅ C&CG 收敛！(Gap=%.6f%%, iter=%d)\n', gap*100, iter);
            break;
        else
            K = K+1;
            u_wind_sc(:,K) = worst_wind;
            u_pv_sc(:,K)   = worst_pv;
        end
    end % C&CG loop

    % 保存此帕累托点的结果
    pareto_f1(outer_idx)  = LB;
    pareto_f2(outer_idx)  = value(f2_expr);
    pareto_eps(outer_idx) = current_eps;
    conv_history{outer_idx} = struct('LB', h_LB, 'UB', h_UB, 'GAP', h_GAP);

    fprintf('  ★ 帕累托点记录: f1=%.2f  f2=%.6f\n', pareto_f1(outer_idx), pareto_f2(outer_idx));

    % 端点1完成后，触发端点2（f2最小化）
    if outer_idx == 1
        fprintf('\n  [信息] f2_ub（成本最优时的f2值）= %.6f\n', pareto_f2(1));
    end

end % outer (ε grid) loop

%% =========================================================================
%  第4节：清理并排序帕累托前沿数据
% =========================================================================
% 去除 NaN 和 run_mode==1 的占位行
valid_idx = ~isnan(pareto_f1) & ~isnan(pareto_f2);
pf1 = pareto_f1(valid_idx);
pf2 = pareto_f2(valid_idx);

% 按 f2 升序排列
[pf2_sorted, sort_idx] = sort(pf2);
pf1_sorted = pf1(sort_idx);

fprintf('\n\n=============================================================\n');
fprintf('  帕累托前沿汇总（共 %d 个非支配点）\n', length(pf1_sorted));
fprintf('  %-12s  %-12s\n', 'f1 (成本/元)', 'f2 (DR灵活性)');
fprintf('  ---------------------------------\n');
for i = 1:length(pf1_sorted)
    fprintf('  %-12.2f  %-12.6f\n', pf1_sorted(i), pf2_sorted(i));
end
fprintf('=============================================================\n');

%% =========================================================================
%  第5节：可视化
% =========================================================================
c_blue   = [0.000, 0.447, 0.741];
c_orange = [0.850, 0.325, 0.098];
c_green  = [0.466, 0.674, 0.188];
c_red    = [0.850, 0.100, 0.100];
c_purple = [0.494, 0.184, 0.556];
c_gray   = [0.5, 0.5, 0.5];

% ---------------------------------------------------------------
%  图1：帕累托前沿（核心成果图）
% ---------------------------------------------------------------
figure('Color','w','Position',[50,50,800,550],'Name','MO-TSRO 帕累托前沿');
hold on; grid on; box on;

% 连接线
plot(pf2_sorted, pf1_sorted/1e4, '-', 'Color', c_gray, 'LineWidth', 1.5);

% 帕累托点
scatter(pf2_sorted, pf1_sorted/1e4, 120, 'filled', ...
    'MarkerFaceColor', c_blue, 'MarkerEdgeColor', 'w', 'LineWidth', 1.5);

% 标注两端点
scatter(pf2_sorted(1),   pf1_sorted(1)/1e4,   180, '^', 'filled', ...
    'MarkerFaceColor', c_green,  'MarkerEdgeColor', 'w', 'DisplayName', 'DR最省端（f2最小）');
scatter(pf2_sorted(end), pf1_sorted(end)/1e4, 180, 's', 'filled', ...
    'MarkerFaceColor', c_orange, 'MarkerEdgeColor', 'w', 'DisplayName', '成本最优端（f1最小）');

% 标注每个点的 f2 值
for i = 1:length(pf2_sorted)
    text(pf2_sorted(i)+0.002, pf1_sorted(i)/1e4+0.03, ...
        sprintf('P%d', i), 'FontSize', 9, 'Color', c_blue);
end

xlabel('f_2：四维DR灵活性指数（电+热+冷+DC）', 'FontSize', 13);
ylabel('f_1：系统综合运行成本 / 万元',           'FontSize', 13);
title('MO-TSRO 帕累托前沿（ε-约束法 + C\&CG）',  'FontSize', 14, 'FontWeight', 'bold');
legend('帕累托前沿连线', '中间非支配点', ...
       'DR最省端（f_2^{min}）', '成本最优端（f_1^{min}）', ...
       'Location', 'northeast', 'FontSize', 10);

% 添加权衡区域注释
annotation('textbox', [0.15 0.15 0.3 0.12], 'String', ...
    {'← DR代价小，成本高', '（鲁棒性较低）'}, ...
    'FitBoxToText','on','EdgeColor','none','Color',c_green,'FontSize',9);
annotation('textbox', [0.60 0.70 0.3 0.12], 'String', ...
    {'DR弹性大，成本低 →', '（调度灵活性高）'}, ...
    'FitBoxToText','on','EdgeColor','none','Color',c_orange,'FontSize',9);

% ---------------------------------------------------------------
%  图2：ε-约束法求解过程（每个点的C&CG收敛曲线）
% ---------------------------------------------------------------
n_valid = sum(valid_idx) - sum(isnan(pareto_f1(2:2)));
% 找到有收敛历史的点（去掉 run_mode==1 的跳过点）
valid_conv = find(valid_idx);

figure('Color','w','Position',[100,100,1100,750],'Name','各帕累托点C&CG收敛过程');
n_plots = min(length(valid_conv), 6);
cols_p = ceil(n_plots/2); rows_p = 2;

for pi = 1:n_plots
    idx = valid_conv(pi);
    if isempty(conv_history{idx}) || ~isstruct(conv_history{idx}), continue; end
    ch = conv_history{idx};
    if isempty(ch.LB), continue; end
    iters = 1:length(ch.LB);

    subplot(rows_p, cols_p, pi);
    yyaxis left;
    plot(iters, ch.UB/1e4, '-s', 'Color', c_orange, 'LineWidth', 2, 'MarkerSize', 6); hold on;
    plot(iters, ch.LB/1e4, '-o', 'Color', c_blue,   'LineWidth', 2, 'MarkerSize', 6);
    ylabel('成本 / 万元'); ylim_r = ylim; grid on;
    yyaxis right;
    plot(iters, ch.GAP*100, '-^', 'Color', c_red, 'LineWidth', 1.5, 'MarkerSize', 5);
    yline(epsilon_tol*100, '--r', 'LineWidth', 1);
    ylabel('Gap / %'); ylim([0, max(ch.GAP)*110]);

    if isnan(pareto_eps(idx))
        ttl = sprintf('无约束（成本最优端）\nf1=%.2f万  f2=%.4f', pareto_f1(idx)/1e4, pareto_f2(idx));
    else
        ttl = sprintf('ε=%.4f\nf1=%.2f万  f2=%.4f', pareto_eps(idx), pareto_f1(idx)/1e4, pareto_f2(idx));
    end
    title(ttl, 'FontSize', 9);
    xlabel('C\&CG 迭代次数');
    yyaxis left; legend('UB', 'LB', 'Gap', '收敛阈值', 'Location', 'northeast', 'FontSize', 7);
end
sgtitle('各帕累托点 C\&CG 算法收敛过程对比', 'FontSize', 13, 'FontWeight', 'bold');

% ---------------------------------------------------------------
%  图3：f1、f2 随 ε 变化趋势（权衡曲线）
% ---------------------------------------------------------------
figure('Color','w','Position',[150,150,850,400],'Name','f1-f2权衡趋势');
subplot(1,2,1);
plot(pf2_sorted, pf1_sorted/1e4, 'o-', 'Color', c_blue, 'LineWidth', 2, 'MarkerFaceColor', c_blue);
xlabel('f_2（DR灵活性指数）'); ylabel('f_1（万元）');
title('成本 vs DR灵活性'); grid on; box on;

subplot(1,2,2);
% 柱状图显示各帕累托点的 f_E, f_H, f_C, f_DC 分量（若可获得）
bar_data = pf2_sorted;
bar(1:length(bar_data), bar_data, 'FaceColor', c_purple, 'EdgeColor', 'w', 'FaceAlpha', 0.75);
xlabel('帕累托点编号'); ylabel('f_2 总值');
title('帕累托前沿上 f_2 分布'); grid on; box on;
xticks(1:length(bar_data));
xticklabels(arrayfun(@(i) sprintf('P%d', i), 1:length(bar_data), 'UniformOutput', false));

sgtitle('ε-约束法权衡分析', 'FontSize', 13, 'FontWeight', 'bold');

disp('');
disp('✅ MO-TSRO 帕累托前沿搜索全部完成！');
disp('   图1：帕累托前沿（主要成果）');
disp('   图2：各帕累托点 C&CG 收敛过程');
disp('   图3：f1-f2 权衡趋势分析');


