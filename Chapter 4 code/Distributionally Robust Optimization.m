clear; clc;
% =========================================================================
% [测试版] 园区综合能源系统 数据驱动两阶段分布鲁棒优化 (DD-DRO)
% 修改说明：强行将储能(ES/HS)充放电 0-1 状态作为一阶段日前决策变量
% 目的：测试在海量场景下是否会引发 C&CG 算法的可行性死锁 (Infeasible)
% =========================================================================

%% ======= §0  CSV → .mat 预处理（省略，假定已存在）=======
mat_file = 'DRO_Autumn_Data.mat';
if ~isfile(mat_file)
    error('请确保 DRO_Autumn_Data.mat 文件在当前目录下！');
else
    fprintf('✅ 读取 %s\n', mat_file);
end

%% ======= §1  基础数据准备（秋季典型日）=======
Load_E  = [3080.5,2620.2,2460.8,2390.6,2530.3,2580.7,2660.5,3080.4,3220.6,3960.8,...
           4150.3,4120.9,3980.5,4450.6,4280.2,4830.8,5410.4,5680.7,6150.6,5260.3,...
           5350.8,4580.5,4280.2,3280.7]';
Load_H  = [5180.5,4980.2,4780.8,4380.6,4520.3,4880.5,8180.2,7180.8,5950.5,4180.3,...
           3080.6,2450.2,2080.8,1980.5,2120.3,3050.6,3980.5,5150.8,6250.2,7380.5,...
           7680.8,7980.3,6850.6,5980.2]';
Load_C  = [180.5,120.3,80.6,60.2,90.5,250.8,380.4,620.6,980.3,1780.5,...
           2580.8,3080.3,3380.6,3420.2,2950.5,2480.8,1680.3,1080.6,580.2,380.5,...
           280.8,220.3,180.6,150.5]';
Load_DC = 1.25*[645.8,715.4,662.0,779.0,1036.6,875.7,875.0,757.3,873.6,818.2,...
           1112.4,1135.5,979.3,1149.7,1123.3,746.5,971.1,672.8,678.1,703.2,...
           1087.4,986.7,739.7,1021.9]';
T_out   = [7.2,6.5,6.0,5.7,6.1,7.5,9.3,11.6,13.8,15.5,16.7,17.4,...
           17.8,18.1,17.4,15.9,13.9,11.7,10.0,8.8,8.1,7.7,7.4,7.2]';
price   = [0.29,0.29,0.29,0.29,0.29,0.29,0.6,0.6,0.95,0.95,0.95,0.6,...
           0.6,0.6,0.95,0.95,0.95,0.95,0.95,0.95,0.95,0.6,0.29,0.29]';

W_unit_pred  = [0.502, 0.456, 0.389, 0.351, 0.358, 0.408, 0.416, 0.356, 0.477, 0.387, 0.202, 0.080, 0.017, 0.001, 0.000, 0.000, 0.000, 0.010, 0.073, 0.305, 0.428, 0.377, 0.316, 0.354]';
PV_unit_pred = [0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.048, 0.168, 0.357, 0.564, 0.674, 0.677, 0.656, 0.634, 0.556, 0.444, 0.298, 0.141, 0.000, 0.000, 0.000, 0.000, 0.000]';


V_pv = 16000; V_wind = 18000; V_ES = 5500; V_HS = 14000; 
V_EL = 2000;  V_HFC = 1000; V_EB = 11000; V_EC = 2500; V_AC = 1200;
P_grid_max=10000;
yita_ES=0.9; yita_HS=0.9; yita_EB=0.95; yita_EL=0.6;
yita_EC=3.89; yita_AC=0.8; yita_HFC_total=0.9;
K_pv=0.04; K_wind=0.091; K_ES_om=0.08; K_HS_om=0.016; K_HFC_om=0.033;
K_EB=0.05; K_EL=0.016; K_EC=0.1; K_AC=0.015;
c_shift_E=0.15; c_cut_E=0.30; c_shift_H=0.10; c_cut_H=0.30;
c_shift_C=0.10; c_cut_C=0.20; c_shift_DC=0.20;
alpha_shift=0.15; beta_cut=0.05;

P_pv_max   = V_pv   * PV_unit_pred;   
P_wind_max = V_wind * W_unit_pred;    

%% ======= §2  秋季历史场景集生成 =======
raw = load(mat_file);
if isfield(raw, 'PV_mat')
    All_PV_unit   = raw.PV_mat;
    All_Wind_unit = raw.Wind_mat;
else
    All_PV_unit   = raw.Scenarios_PV_unit;
    All_Wind_unit = raw.Scenarios_W_unit;
end
N_s_total = size(All_Wind_unit, 2);  
N_s = min(50, N_s_total);            

hist_wind_mean = mean(All_Wind_unit,  2);   
hist_pv_mean   = mean(All_PV_unit,    2);   
Scenarios_wind = zeros(24, N_s);
Scenarios_pv   = zeros(24, N_s);
for s = 1:N_s-1
    ratio_w  = All_Wind_unit(:,s) ./ max(hist_wind_mean, 0.005);
    ratio_pv = All_PV_unit(:,s)   ./ max(hist_pv_mean,   0.005);
    Scenarios_wind(:,s) = max(0, min(P_wind_max .* ratio_w,  V_wind));
    Scenarios_pv(:,s)   = max(0, min(P_pv_max   .* ratio_pv, V_pv));
end
Scenarios_wind(:,N_s) = P_wind_max;
Scenarios_pv(:,N_s)   = P_pv_max;
p0_vec = ones(N_s,1) / N_s;

%% ======= §3  DRO 核心参数设置 =======
kappa_W          = 0.3;
sigma_pv_total   = sum(P_pv_max)   * 0.10;
sigma_wind_total = sum(P_wind_max) * 0.10;
epsilon_W        = kappa_W * (sigma_pv_total + sigma_wind_total) / sqrt(N_s);

%% ======= §4  场景间 L1 传输距离矩阵预计算 =======
TransCost = zeros(N_s, N_s);
for i = 1:N_s
    for j = 1:N_s
        TransCost(i,j) = sum(abs(Scenarios_pv(:,j)   - Scenarios_pv(:,i))) + ...
                         sum(abs(Scenarios_wind(:,j) - Scenarios_wind(:,i)));
    end
end

%% ======= §5  第一阶段决策变量定义 =======
% 【【核心修改】：将储能充放电状态强行拉回第一阶段】
U_ES_ch = binvar(24,1); U_ES_dis = binvar(24,1); 
U_HS_ch = binvar(24,1); U_HS_dis = binvar(24,1); 

P_E_sl_in=sdpvar(24,1); P_E_sl_out=sdpvar(24,1); P_E_cut=sdpvar(24,1);
P_H_sl_in=sdpvar(24,1); P_H_sl_out=sdpvar(24,1); P_H_cut=sdpvar(24,1);
P_C_sl_in=sdpvar(24,1); P_C_sl_out=sdpvar(24,1); P_C_cut=sdpvar(24,1);
P_DC_delay1=sdpvar(24,1); P_DC_delay2=sdpvar(24,1); Load_DC_opt=sdpvar(24,1);

lambda_w = sdpvar(1,1);
alpha_s  = sdpvar(N_s,1);

Cost_1st_DR = sum(c_shift_E*P_E_sl_in + c_cut_E*P_E_cut) + ...
              sum(c_shift_H*P_H_sl_in + c_cut_H*P_H_cut) + ...
              sum(c_shift_C*P_C_sl_in + c_cut_C*P_C_cut) + ...
              sum(c_shift_DC*(P_DC_delay1 + P_DC_delay2));

% 【添加了一阶段储能状态的互斥约束】
First_Constraints = [
    0<=P_E_sl_in<=alpha_shift*Load_E, 0<=P_E_sl_out<=alpha_shift*Load_E,
    0<=P_E_cut<=beta_cut*Load_E, sum(P_E_sl_in)==sum(P_E_sl_out),
    0<=P_H_sl_in<=alpha_shift*Load_H, 0<=P_H_sl_out<=alpha_shift*Load_H,
    0<=P_H_cut<=beta_cut*Load_H, sum(P_H_sl_in)==sum(P_H_sl_out),
    0<=P_C_sl_in<=alpha_shift*Load_C, 0<=P_C_sl_out<=alpha_shift*Load_C,
    0<=P_C_cut<=beta_cut*Load_C, sum(P_C_sl_in)==sum(P_C_sl_out),
    0<=P_DC_delay1, 0<=P_DC_delay2, (P_DC_delay1+P_DC_delay2)<=0.30*Load_DC,
    Load_DC_opt(1)==Load_DC(1)-P_DC_delay1(1)-P_DC_delay2(1)+P_DC_delay1(24)+P_DC_delay2(23),
    Load_DC_opt(2)==Load_DC(2)-P_DC_delay1(2)-P_DC_delay2(2)+P_DC_delay1(1)+P_DC_delay2(24),
    U_ES_ch + U_ES_dis <= 1, U_HS_ch + U_HS_dis <= 1  % 充放电互斥
];
for t = 3:24
    First_Constraints = [First_Constraints, ...
        Load_DC_opt(t)==Load_DC(t)-P_DC_delay1(t)-P_DC_delay2(t)+P_DC_delay1(t-1)+P_DC_delay2(t-2)];
end

Load_E_DR = Load_E + P_E_sl_in - P_E_sl_out - P_E_cut;
Load_H_DR = Load_H + P_H_sl_in - P_H_sl_out - P_H_cut;
Load_C_DR = Load_C + P_C_sl_in - P_C_sl_out - P_C_cut;
Load_DC_waste_opt = 0.59 * Load_DC_opt;

ops_sol = sdpsettings('solver','gurobi','gurobi.NonConvex',2,'verbose',0);
ops_lp  = sdpsettings('solver','gurobi','verbose',0);

%% ======= §6  C&CG 主迭代 =======
max_iter=20; LB=-inf; UB=inf; epsilon_tol=5e-4;
history_LB=[]; history_UB=[]; history_GAP=[];

active_cuts = cell(N_s,1);
for i = 1:N_s, active_cuts{i} = i; end

sp_pv=sdpvar(24,1); sp_wind=sdpvar(24,1);
sp_es_ch=sdpvar(24,1); sp_es_dis=sdpvar(24,1); sp_es_soc=sdpvar(24,1);
sp_hs_ch=sdpvar(24,1); sp_hs_dis=sdpvar(24,1); sp_hs_soc=sdpvar(24,1);
sp_el=sdpvar(24,1); sp_hfc_e=sdpvar(24,1); sp_hfc_h=sdpvar(24,1);
sp_grid=sdpvar(24,1); sp_eb=sdpvar(24,1); sp_ec=sdpvar(24,1);
sp_ac_h=sdpvar(24,1); sp_ac_dc=sdpvar(24,1); sp_ac_cool=sdpvar(24,1);
sp_ac_dccool=sdpvar(24,1); sp_ec_cool=sdpvar(24,1); sp_ec_dc=sdpvar(24,1);
sp_tin=sdpvar(24,1);

fprintf('\n🚀 启动 DD-DRO C&CG 迭代（测试一阶段包含0-1储能状态）...\n');

for iter = 1:max_iter
    fprintf('\n╔════════ 第 %2d 次迭代 ════════╗\n', iter);
    
    MP_Constraints = [First_Constraints, lambda_w >= 0];
    for i = 1:N_s
        for k_cut = 1:length(active_cuts{i})
            j = active_cuts{i}(k_cut);
            xi_pv_j   = Scenarios_pv(:,j);
            xi_wind_j = Scenarios_wind(:,j);
            c_ij      = TransCost(i,j);
            
            p_pv_ij=sdpvar(24,1); p_wind_ij=sdpvar(24,1);
            p_es_ch_ij=sdpvar(24,1); p_es_dis_ij=sdpvar(24,1); es_soc_ij=sdpvar(24,1);
            p_hs_ch_ij=sdpvar(24,1); p_hs_dis_ij=sdpvar(24,1); hs_soc_ij=sdpvar(24,1);
            p_el_ij=sdpvar(24,1); p_hfc_e_ij=sdpvar(24,1); p_hfc_h_ij=sdpvar(24,1);
            p_grid_ij=sdpvar(24,1); p_eb_ij=sdpvar(24,1); p_ec_ij=sdpvar(24,1);
            p_ac_h_ij=sdpvar(24,1); p_ac_dc_ij=sdpvar(24,1); p_ac_cool_ij=sdpvar(24,1);
            p_ac_dccool_ij=sdpvar(24,1); p_ec_cool_ij=sdpvar(24,1); p_ec_dc_ij=sdpvar(24,1);
            t_in_ij=sdpvar(24,1);
            
            % 【【核心修改】：这里加上了 U_ES_ch 等一阶段 0-1 变量对连续功率的硬约束】
            C2_ij = [
                0<=p_pv_ij<=xi_pv_j, 0<=p_wind_ij<=xi_wind_j,
                0<=p_es_ch_ij <= U_ES_ch .* 0.5 .* V_ES, 
                0<=p_es_dis_ij <= U_ES_dis .* 0.5 .* V_ES,
                es_soc_ij(2:24)==es_soc_ij(1:23)+p_es_ch_ij(2:24)*yita_ES-p_es_dis_ij(2:24)/yita_ES,
                es_soc_ij(1)==0.3*V_ES+p_es_ch_ij(1)*yita_ES-p_es_dis_ij(1)/yita_ES,
                es_soc_ij(24)==0.3*V_ES, 0.1*V_ES<=es_soc_ij<=0.9*V_ES,
                
                0<=p_hs_ch_ij <= U_HS_ch .* 1e6, 
                0<=p_hs_dis_ij <= U_HS_dis .* 1e6,
                p_el_ij==p_hs_ch_ij/yita_EL, p_el_ij<=V_EL,
                hs_soc_ij(2:24)==hs_soc_ij(1:23)+p_hs_ch_ij(2:24)*yita_HS-p_hs_dis_ij(2:24)/yita_HS,
                hs_soc_ij(1)==0.5*V_HS+p_hs_ch_ij(1)*yita_HS-p_hs_dis_ij(1)/yita_HS,
                hs_soc_ij(24)==0.5*V_HS, 0.05*V_HS<=hs_soc_ij<=0.95*V_HS,
                
                p_hfc_e_ij+p_hfc_h_ij<=yita_HFC_total*p_hs_dis_ij,
                p_hfc_e_ij>=0.7*p_hfc_h_ij, p_hfc_e_ij<=2*p_hfc_h_ij, p_hfc_e_ij<=V_HFC,
                
                0<=p_grid_ij<=P_grid_max, 0<=p_eb_ij<=V_EB, 0<=p_ec_ij<=V_EC,
                p_ac_h_ij>=0, p_ac_dc_ij>=0, p_ac_dc_ij<=Load_DC_waste_opt,
                p_ac_cool_ij>=0, p_ac_dccool_ij>=0, p_ec_cool_ij>=0, p_ec_dc_ij>=0,
                p_ac_h_ij+p_ac_dc_ij<=V_AC,
                p_ec_ij*yita_EC==p_ec_cool_ij+p_ec_dc_ij,
                p_ac_cool_ij+p_ac_dccool_ij==yita_AC*(p_ac_dc_ij+p_ac_h_ij),
                
                t_in_ij(2:24)==t_in_ij(1:23)*exp(-1)+(0.04*(Load_DC_waste_opt(1:23)-p_ac_dc_ij(1:23)-p_ec_dc_ij(1:23)-p_ac_dccool_ij(1:23))+T_out(1:23))*(1-exp(-1)),
                t_in_ij(1)==t_in_ij(24)*exp(-1)+(0.04*(Load_DC_waste_opt(24)-p_ac_dc_ij(24)-p_ec_dc_ij(24)-p_ac_dccool_ij(24))+T_out(24))*(1-exp(-1)),
                17.78<=t_in_ij<=27.22,
                
                p_ec_cool_ij+p_ac_cool_ij>=Load_C_DR,
                p_eb_ij*yita_EB+p_hfc_h_ij>=Load_H_DR+p_ac_h_ij,
                p_grid_ij+p_pv_ij+p_wind_ij+p_es_dis_ij+p_hfc_e_ij >= ...
                    Load_E_DR+Load_DC_opt+p_es_ch_ij+p_el_ij+p_eb_ij+p_ec_ij
            ];
            
            Cost_2nd_ij = sum(price.*p_grid_ij) + ...
                sum(K_wind*p_wind_ij + K_pv*p_pv_ij) + ...
                sum(K_ES_om*p_es_dis_ij + K_HS_om*p_hs_dis_ij + K_HFC_om*(p_hfc_e_ij+p_hfc_h_ij)) + ...
                sum(K_EL*p_el_ij*yita_EL + K_EB*p_eb_ij*yita_EB + ...
                    K_EC*p_ec_ij*yita_EC + K_AC*(p_ac_dc_ij+p_ac_cool_ij));
            
            MP_Constraints = [MP_Constraints, C2_ij, ...
                alpha_s(i) >= Cost_2nd_ij - lambda_w*c_ij];
        end
    end
    
    DRO_Obj = Cost_1st_DR + epsilon_W*lambda_w + (1/N_s)*sum(alpha_s);
    sol_MP = optimize(MP_Constraints, DRO_Obj, ops_sol);
    if sol_MP.problem ~= 0
        error('💥 主问题求解失败（迭代%d），很可能因为刚性 0-1 变量导致各场景冲突死锁！', iter);
    end
    
    LB = max(LB, value(DRO_Obj));
    history_LB = [history_LB, LB];
    
    L_E_DR_star   = value(Load_E_DR);
    L_H_DR_star   = value(Load_H_DR);
    L_C_DR_star   = value(Load_C_DR);
    L_DC_opt_star  = value(Load_DC_opt);
    L_DC_waste_star = value(Load_DC_waste_opt);
    lambda_w_star = value(lambda_w);
    alpha_s_star  = value(alpha_s);
    
    % 【提取并锁定一阶段的储能 0-1 状态，传给子问题】
    U_ES_ch_star = value(U_ES_ch); U_ES_dis_star = value(U_ES_dis);
    U_HS_ch_star = value(U_HS_ch); U_HS_dis_star = value(U_HS_dis);
    
    fprintf('  主问题 → LB = %.2f 元  (λ_w* = %.4f)\n', LB, lambda_w_star);
    
    %% 子问题 SP
    Q_values = zeros(N_s, 1);
    for j = 1:N_s
        xi_pv_j   = Scenarios_pv(:,j);
        xi_wind_j = Scenarios_wind(:,j);
        
        % 【【核心修改】：子问题中用主问题确定的 _star 状态限制充放电边界】
        SP_C = [
            0<=sp_pv<=xi_pv_j, 0<=sp_wind<=xi_wind_j,
            0<=sp_es_ch <= U_ES_ch_star .* 0.5 .* V_ES, 
            0<=sp_es_dis <= U_ES_dis_star .* 0.5 .* V_ES,
            sp_es_soc(2:24)==sp_es_soc(1:23)+sp_es_ch(2:24)*yita_ES-sp_es_dis(2:24)/yita_ES,
            sp_es_soc(1)==0.3*V_ES+sp_es_ch(1)*yita_ES-sp_es_dis(1)/yita_ES,
            sp_es_soc(24)==0.3*V_ES, 0.1*V_ES<=sp_es_soc<=0.9*V_ES,
            
            0<=sp_hs_ch <= U_HS_ch_star .* 1e6, 
            0<=sp_hs_dis <= U_HS_dis_star .* 1e6,
            sp_el==sp_hs_ch/yita_EL, sp_el<=V_EL,
            sp_hs_soc(2:24)==sp_hs_soc(1:23)+sp_hs_ch(2:24)*yita_HS-sp_hs_dis(2:24)/yita_HS,
            sp_hs_soc(1)==0.5*V_HS+sp_hs_ch(1)*yita_HS-sp_hs_dis(1)/yita_HS,
            sp_hs_soc(24)==0.5*V_HS, 0.05*V_HS<=sp_hs_soc<=0.95*V_HS,
            
            sp_hfc_e+sp_hfc_h<=yita_HFC_total*sp_hs_dis,
            sp_hfc_e>=0.7*sp_hfc_h, sp_hfc_e<=2*sp_hfc_h, sp_hfc_e<=V_HFC,
            
            0<=sp_grid<=P_grid_max, 0<=sp_eb<=V_EB, 0<=sp_ec<=V_EC,
            sp_ac_h>=0, sp_ac_dc>=0, sp_ac_dc<=L_DC_waste_star,
            sp_ac_cool>=0, sp_ac_dccool>=0, sp_ec_cool>=0, sp_ec_dc>=0,
            sp_ac_h+sp_ac_dc<=V_AC,
            sp_ec*yita_EC==sp_ec_cool+sp_ec_dc,
            sp_ac_cool+sp_ac_dccool==yita_AC*(sp_ac_dc+sp_ac_h),
            
            sp_tin(2:24)==sp_tin(1:23)*exp(-1)+(0.04*(L_DC_waste_star(1:23)-sp_ac_dc(1:23)-sp_ec_dc(1:23)-sp_ac_dccool(1:23))+T_out(1:23))*(1-exp(-1)),
            sp_tin(1)==sp_tin(24)*exp(-1)+(0.04*(L_DC_waste_star(24)-sp_ac_dc(24)-sp_ec_dc(24)-sp_ac_dccool(24))+T_out(24))*(1-exp(-1)),
            17.78<=sp_tin<=27.22,
            
            sp_ec_cool+sp_ac_cool>=L_C_DR_star,
            sp_eb*yita_EB+sp_hfc_h>=L_H_DR_star+sp_ac_h,
            sp_grid+sp_pv+sp_wind+sp_es_dis+sp_hfc_e >= ...
                L_E_DR_star+L_DC_opt_star+sp_es_ch+sp_el+sp_eb+sp_ec
        ];
        
        SP_Obj_j = sum(price.*sp_grid) + sum(K_wind*sp_wind+K_pv*sp_pv) + ...
            sum(K_ES_om*sp_es_dis+K_HS_om*sp_hs_dis+K_HFC_om*(sp_hfc_e+sp_hfc_h)) + ...
            sum(K_EL*sp_el*yita_EL+K_EB*sp_eb*yita_EB+K_EC*sp_ec*yita_EC+K_AC*(sp_ac_dc+sp_ac_cool));
        
        sol_j = optimize(SP_C, SP_Obj_j, ops_lp);
        if sol_j.problem == 0
            Q_values(j) = value(SP_Obj_j);
        else
            Q_values(j) = 1e8; % 如果某个场景无解，给予极大惩罚
        end
    end
    
    fprintf('  场景评估：Q_min=%.0f, Q_max=%.0f, Q_mean=%.0f 元\n', ...
        min(Q_values), max(Q_values), mean(Q_values));
    if max(Q_values) > 1e7
        fprintf('  ⚠️ 警告：存在子问题无法求解的场景（Infeasible），说明一阶段 0-1 变量过于刚性！\n');
    end
    
    %% 跨场景违约割检查
    new_cuts = 0;
    for i = 1:N_s
        penalized_Q = Q_values - lambda_w_star * TransCost(i,:)';
        [max_val, j_star] = max(penalized_Q);
        violation = max_val - alpha_s_star(i);
        if violation > 1.0 && ~ismember(j_star, active_cuts{i})
            active_cuts{i} = [active_cuts{i}, j_star];
            new_cuts = new_cuts + 1;
            fprintf('  [跨场景割] α_%d ≥ Q_%d - λ·c_{%d,%d}  违约=%.1f元\n', ...
                i, j_star, i, j_star, violation);
        end
    end
    
    %% 上界计算
    worst_exp_sum = 0;
    for i = 1:N_s
        penalized_Q = Q_values - lambda_w_star * TransCost(i,:)';
        worst_exp_sum = worst_exp_sum + max(penalized_Q);
    end
    UB_current = value(Cost_1st_DR) + epsilon_W*lambda_w_star + (1/N_s)*worst_exp_sum;
    UB = min(UB, UB_current);
    history_UB = [history_UB, UB];
    gap = abs(UB - LB) / max(abs(UB), 1e-6);
    history_GAP = [history_GAP, gap];
    fprintf('  子问题 → UB=%.2f 元,  Gap=%.4f%%,  新增割=%d\n', UB, gap*100, new_cuts);
    
    if (new_cuts == 0) || (gap <= epsilon_tol)
        fprintf('\n✅ C&CG 收敛！最终 Gap = %.4f%%\n', gap*100);
        break;
    end
end
disp('由于是可行性测试，省略后续绘图步骤...');



%% ======= §7  终局核算（最恶劣场景下的最优调度提取）=======
fprintf('\n正在进行终局核算...\n');
final_worst_sum = zeros(N_s,1);
for i = 1:N_s
    penalized_Q = Q_values - lambda_w_star * TransCost(i,:)';
    final_worst_sum(i) = max(penalized_Q);
end
[~, rep_i] = max(final_worst_sum);
penalized_for_rep = Q_values - lambda_w_star * TransCost(rep_i,:)';
[~, worst_j] = max(penalized_for_rep);
worst_pv   = Scenarios_pv(:, worst_j);
worst_wind = Scenarios_wind(:, worst_j);
fprintf('代表场景 i=%d，最恶劣出力场景 j=%d，Q_j=%.0f 元\n', rep_i, worst_j, Q_values(worst_j));

f_p_pv=sdpvar(24,1); f_p_wind=sdpvar(24,1);
f_es_ch=sdpvar(24,1); f_es_dis=sdpvar(24,1); f_es_soc=sdpvar(24,1);
f_hs_ch=sdpvar(24,1); f_hs_dis=sdpvar(24,1); f_hs_soc=sdpvar(24,1);
f_el=sdpvar(24,1); f_hfc_e=sdpvar(24,1); f_hfc_h=sdpvar(24,1);
f_grid=sdpvar(24,1); f_eb=sdpvar(24,1); f_ec=sdpvar(24,1);
f_ac_h=sdpvar(24,1); f_ac_dc=sdpvar(24,1); f_ac_cool=sdpvar(24,1);
f_ac_dccool=sdpvar(24,1); f_ec_cool=sdpvar(24,1); f_ec_dc=sdpvar(24,1);
f_tin=sdpvar(24,1);

Final_C = [
    0<=f_p_pv<=worst_pv, 0<=f_p_wind<=worst_wind,
    0<=f_es_ch<=0.5*V_ES, 0<=f_es_dis<=0.5*V_ES,
    f_es_soc(2:24)==f_es_soc(1:23)+f_es_ch(2:24)*yita_ES-f_es_dis(2:24)/yita_ES,
    f_es_soc(1)==0.3*V_ES+f_es_ch(1)*yita_ES-f_es_dis(1)/yita_ES,
    f_es_soc(24)==0.3*V_ES, 0.1*V_ES<=f_es_soc<=0.9*V_ES,
    
    0<=f_hs_ch<=1e6, 0<=f_hs_dis<=1e6,
    f_el==f_hs_ch/yita_EL, f_el<=V_EL,
    f_hs_soc(2:24)==f_hs_soc(1:23)+f_hs_ch(2:24)*yita_HS-f_hs_dis(2:24)/yita_HS,
    f_hs_soc(1)==0.5*V_HS+f_hs_ch(1)*yita_HS-f_hs_dis(1)/yita_HS,
    f_hs_soc(24)==0.5*V_HS, 0.05*V_HS<=f_hs_soc<=0.95*V_HS,
    
    f_hfc_e+f_hfc_h<=yita_HFC_total*f_hs_dis,
    f_hfc_e>=0.7*f_hfc_h, f_hfc_e<=2*f_hfc_h, f_hfc_e<=V_HFC,
    
    0<=f_grid<=P_grid_max, 0<=f_eb<=V_EB, 0<=f_ec<=V_EC,
    f_ac_h>=0, f_ac_dc>=0, f_ac_dc<=L_DC_waste_star,
    f_ac_cool>=0, f_ac_dccool>=0, f_ec_cool>=0, f_ec_dc>=0,
    f_ac_h+f_ac_dc<=V_AC, f_ec*yita_EC==f_ec_cool+f_ec_dc,
    f_ac_cool+f_ac_dccool==yita_AC*(f_ac_dc+f_ac_h),
    
    f_tin(2:24)==f_tin(1:23)*exp(-1)+(0.04*(L_DC_waste_star(1:23)-f_ac_dc(1:23)-f_ec_dc(1:23)-f_ac_dccool(1:23))+T_out(1:23))*(1-exp(-1)),
    f_tin(1)==f_tin(24)*exp(-1)+(0.04*(L_DC_waste_star(24)-f_ac_dc(24)-f_ec_dc(24)-f_ac_dccool(24))+T_out(24))*(1-exp(-1)),
    17.78<=f_tin<=27.22,
    
    f_ec_cool+f_ac_cool>=L_C_DR_star,
    f_eb*yita_EB+f_hfc_h>=L_H_DR_star+f_ac_h,
    f_grid+f_p_pv+f_p_wind+f_es_dis+f_hfc_e >= ...
        L_E_DR_star+L_DC_opt_star+f_es_ch+f_el+f_eb+f_ec
];
Final_Cost = sum(price.*f_grid) + sum(K_wind*f_p_wind+K_pv*f_p_pv) + ...
    sum(K_ES_om*f_es_dis+K_HS_om*f_hs_dis+K_HFC_om*(f_hfc_e+f_hfc_h)) + ...
    sum(K_EL*f_el*yita_EL+K_EB*f_eb*yita_EB+K_EC*f_ec*yita_EC+K_AC*(f_ac_dc+f_ac_cool)) + ...
    value(Cost_1st_DR);
optimize(Final_C, Final_Cost, ops_lp);
fprintf('✅ 终局核算完毕\n');

%% ======= §8  最恶劣概率分布求解 =======
fprintf('正在求解最恶劣概率分布 P*...\n');
pi_mat   = sdpvar(N_s, N_s, 'full');
p_star_v = sdpvar(N_s, 1);
optimize([pi_mat>=0, sum(pi_mat,2)==p0_vec, ...
          p_star_v==sum(pi_mat,1)', ...
          sum(sum(pi_mat.*TransCost))<=epsilon_W], ...
         -sum(p_star_v.*Q_values), ops_lp);
p_star_val = max(0, value(p_star_v));
p_star_val = p_star_val / sum(p_star_val);

%% ======= §9  结果汇总打印 =======
fprintf('\n╔══════════════════════════════════════════════════╗\n');
fprintf('║        秋季 DD-DRO 最终结果汇总（无碳交易）     ║\n');
fprintf('║  数据来源：Renewables.ninja 2019秋（9-11月）    ║\n');
fprintf('║  位置    ：37.50°N, 105.19°E（中卫）           ║\n');
fprintf('║  场景数   N_s     = %d 天                       ║\n', N_s);
fprintf('║  Wasserstein ε   = %.0f kW                    ║\n', epsilon_W);
fprintf('║  DRO最优值(LB)  = %.2f 元                 ║\n', LB);
fprintf('║  DRO上界  (UB)  = %.2f 元                 ║\n', UB);
fprintf('║  最终 Gap        = %.4f%%                   ║\n', history_GAP(end)*100);
fprintf('║  λ_w*（鲁棒价格）= %.4f                    ║\n', lambda_w_star);
fprintf('║  最恶劣场景编号  = %d                          ║\n', worst_j);
fprintf('║  一阶段DR成本    = %.2f 元                ║\n', value(Cost_1st_DR));
fprintf('║  Wasserstein溢价 = %.2f 元                ║\n', epsilon_W*lambda_w_star);
fprintf('║  二阶段期望成本  = %.2f 元                ║\n', (1/N_s)*sum(Q_values));
fprintf('╚══════════════════════════════════════════════════╝\n');

% === (下面保留你原有的绘图模块即可，数据逻辑已完全打通) ===

%% ======= §10  可视化绘图模块 =======
t_ax = 1:24;
iter_ax = 1:length(history_LB);

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

% ── 图1：C&CG 收敛过程 ──────────────────────────────────────────────────
figure('Color','w','Position',[50,50,1000,580],'Name','图1_DRO收敛过程');
sgtitle('秋季 DD-DRO（无碳交易）：C&CG 迭代收敛过程','FontSize',14,'FontWeight','bold');

subplot(2,1,1);
fill([iter_ax,fliplr(iter_ax)],[history_UB,fliplr(history_LB)], ...
    c_orange,'FaceAlpha',0.12,'EdgeColor','none'); hold on;
plot(iter_ax,history_UB,'-s','Color',c_orange,'LineWidth',2.5,'MarkerSize',9,'MarkerFaceColor','w');
plot(iter_ax,history_LB,'-o','Color',c_blue,  'LineWidth',2.5,'MarkerSize',9,'MarkerFaceColor','w');
for k=1:length(iter_ax)
    plot([iter_ax(k),iter_ax(k)],[history_LB(k),history_UB(k)],':', ...
        'Color',[0.6,0.6,0.6],'LineWidth',1.2);
end
grid on; box on; ylabel('DRO 目标值 / 元','FontSize',11);
xlim([1,iter_ax(end)]); xticks(iter_ax);
legend('Gap 区间','最坏分布期望成本 (UB)','日前策略成本下界 (LB)', ...
    'Location','northeast','FontSize',10);
title('a. DRO 上下界趋同过程（含跨场景 Wasserstein 割）','FontSize',12);

subplot(2,1,2);
semilogy(iter_ax,history_GAP*100,'-^','Color',c_red,'LineWidth',2.2, ...
    'MarkerSize',9,'MarkerFaceColor','w'); hold on;
yline(epsilon_tol*100,'--','Color',c_orange,'LineWidth',1.8, ...
    'Label',sprintf('收敛门槛 %.2f%%',epsilon_tol*100), ...
    'LabelHorizontalAlignment','left');
grid on; box on; ylabel('收敛 Gap / %','FontSize',11);
xlabel('C&CG 迭代次数','FontSize',11);
xlim([1,iter_ax(end)]); xticks(iter_ax);
title('b. Gap 对数收敛曲线','FontSize',12);

% ── 图2：Wasserstein 概率质量漂移 P₀ → P* ────────────────────────────
figure('Color','w','Position',[80,80,950,430],'Name','图2_概率分布漂移');
[~,top_idx] = maxk(p_star_val, 3);
b = bar(1:N_s, [p0_vec, p_star_val], 'grouped', 'EdgeColor','none');
b(1).FaceColor = c_cyan;   b(1).FaceAlpha = 0.85;
b(2).FaceColor = c_orange; b(2).FaceAlpha = 0.85;
hold on;
for k=1:length(top_idx)
    xline(top_idx(k),'--','Color',c_red,'LineWidth',1.2,'Alpha',0.6);
end
title('1-Wasserstein 模糊集：概率质量漂移（P_0 \rightarrow P^*）', ...
    'FontSize',13,'FontWeight','bold');
xlabel('秋季历史场景编号（共 50 个）','FontSize',11);
ylabel('场景发生概率','FontSize',11);
legend('均匀经验分布 P_0（1/N）','最恶劣分布 P^*（DRO 求解）', ...
    'Location','northwest','FontSize',10);
grid on; set(gca,'GridLineStyle','--','GridAlpha',0.3);
annotation('textbox',[0.62,0.70,0.27,0.20], ...
    'String',{sprintf('Wasserstein  ε = %.0f kW',epsilon_W), ...
              sprintf('λ_w^* = %.4f',lambda_w_star), ...
              sprintf('N_s = %d 场景',N_s), ...
              sprintf('最恶劣场景 j = %d',worst_j)}, ...
    'FontSize',9.5,'BackgroundColor','w','EdgeColor','k','FitBoxToText','on');

% ── 图3：秋季风光场景簇 + 最恶劣场景 ────────────────────────────────
figure('Color','w','Position',[100,100,1050,620],'Name','图3_风光场景');
sgtitle('秋季 DD-DRO：历史气象场景簇与最恶劣代表场景','FontSize',14,'FontWeight','bold');

subplot(2,1,1); hold on;
for s=1:N_s
    plot(t_ax,Scenarios_wind(:,s)/1000,'-','Color',c_gray,'LineWidth',0.5);
end
for k=1:length(top_idx)
    plot(t_ax,Scenarios_wind(:,top_idx(k))/1000,'-','Color',[c_red,0.5],'LineWidth',1.3);
end
plot(t_ax,P_wind_max/1000,'--','Color',c_cyan,'LineWidth',2.2);
plot(t_ax,worst_wind/1000,'-^','Color',c_blue,'LineWidth',2.5,'MarkerFaceColor','w','MarkerSize',6);
ylabel('风电出力 / MW','FontSize',11); xlim([1,24]); xticks(1:2:24); grid on; box on;
title('a. 风电：50 个秋季历史场景 vs DRO 最恶劣场景','FontSize',11);
legend('历史气象场景','P^* 高概率场景','秋季预测均值','最恶劣场景 (Worst-case)', ...
    'Location','best','FontSize',10);

subplot(2,1,2); hold on;
for s=1:N_s
    plot(t_ax,Scenarios_pv(:,s)/1000,'-','Color',c_gray,'LineWidth',0.5);
end
for k=1:length(top_idx)
    plot(t_ax,Scenarios_pv(:,top_idx(k))/1000,'-','Color',[c_red,0.5],'LineWidth',1.3);
end
plot(t_ax,P_pv_max/1000,'--','Color',c_yellow,'LineWidth',2.2);
plot(t_ax,worst_pv/1000,'-s','Color',c_orange,'LineWidth',2.5,'MarkerFaceColor','w','MarkerSize',6);
ylabel('光伏出力 / MW','FontSize',11); xlabel('调度时段 / h','FontSize',11);
xlim([1,24]); xticks(1:2:24); grid on; box on;
title('b. 光伏：50 个秋季历史场景 vs DRO 最恶劣场景','FontSize',11);
legend('历史气象场景','P^* 高概率场景','秋季预测均值','最恶劣场景 (Worst-case)', ...
    'Location','best','FontSize',10);

% ── 图4：多能协同功率平衡（2×2）────────────────────────────────────
figure('Color','w','Position',[130,130,1250,820],'Name','图4_功率平衡');
sgtitle('DD-DRO 最恶劣分布场景：秋季多能协同功率平衡','FontSize',15,'FontWeight','bold');

subplot(2,2,1);
Supply_E  = [value(f_grid),value(f_p_pv),value(f_p_wind),value(f_es_dis),value(f_hfc_e)];
Consume_E = [-value(f_es_ch),-value(f_ec),-value(f_el),-value(f_eb)];
colors_s  = [c_cyan;c_yellow;c_green;c_purple;c_brown];
colors_c  = [c_blue;c_orange;[0.929,0.694,0.725];c_red];
b_s = bar(t_ax,Supply_E, 0.8,'stacked','EdgeColor','none'); hold on;
b_c = bar(t_ax,Consume_E,0.8,'stacked','EdgeColor','none');
for k=1:5, b_s(k).FaceColor=colors_s(k,:); end
for k=1:4, b_c(k).FaceColor=colors_c(k,:); end
plot(t_ax,L_E_DR_star+L_DC_opt_star,'k-o','LineWidth',1.8,'MarkerFaceColor','w','MarkerSize',4);
title('电功率互联平衡','FontSize',12); xlabel('时间/h'); ylabel('电功率/kW');
xlim([0.5,24.5]); grid on; box on;
legend('主网购电','光伏(实发)','风电(实发)','电储放电','HFC产电', ...
       '电储充电','电制冷耗','电解槽耗','电锅炉耗','总用电负荷', ...
    'Location','southoutside','NumColumns',5,'FontSize',8);

subplot(2,2,2);
b_sh=bar(t_ax,[value(f_eb)*yita_EB,value(f_hfc_h)],0.8,'stacked','EdgeColor','none'); hold on;
bar(t_ax,-value(f_ac_h),0.8,'FaceColor','#D95319','EdgeColor','none');
b_sh(1).FaceColor=c_orange; b_sh(2).FaceColor=c_red;
plot(t_ax,L_H_DR_star,'r-^','LineWidth',1.8,'MarkerFaceColor','w','MarkerSize',5);
title('热功率互联平衡','FontSize',12); xlabel('时间/h'); ylabel('热功率/kW');
xlim([0.5,24.5]); grid on; box on;
legend('电锅炉产热','HFC副产热','吸收制冷耗热','净热负荷', ...
    'Location','southoutside','NumColumns',4,'FontSize',9);

subplot(2,2,3);
b_sc=bar(t_ax,[value(f_ec_cool),value(f_ac_cool)],0.8,'stacked','EdgeColor','none'); hold on;
b_sc(1).FaceColor=c_cyan; b_sc(2).FaceColor=c_blue;
plot(t_ax,L_C_DR_star,'b-s','LineWidth',1.8,'MarkerFaceColor','w','MarkerSize',5);
title('冷功率互联平衡','FontSize',12); xlabel('时间/h'); ylabel('冷功率/kW');
xlim([0.5,24.5]); grid on; box on;
legend('电制冷产冷','吸收制冷产冷','净冷负荷', ...
    'Location','southoutside','NumColumns',3,'FontSize',9);

subplot(2,2,4);
yyaxis left;
plot(t_ax,value(f_es_soc)/V_ES,'-s','LineWidth',2,'Color',c_blue,'MarkerFaceColor','w','MarkerSize',6);
ylabel('电储能 SOC','Color',c_blue,'FontSize',10,'FontWeight','bold');
ylim([0,1.05]); set(gca,'YColor',c_blue);
yyaxis right;
plot(t_ax,value(f_tin),'-d','LineWidth',2,'Color',c_orange,'MarkerFaceColor','w','MarkerSize',6);
ylabel('数据中心温度/°C','Color',c_orange,'FontSize',10,'FontWeight','bold');
ylim([15,30]); set(gca,'YColor',c_orange);
yline(27.22,'--r','LineWidth',1.5,'Label','上限 27.22°C','LabelHorizontalAlignment','left');
yline(17.78,'--b','LineWidth',1.5,'Label','下限 17.78°C','LabelHorizontalAlignment','left');
title('储能 SOC 与数据中心热力学温控','FontSize',12);
xlabel('时间/h'); xlim([0.5,24.5]); grid on; box on;

% ── 图5：需求响应结果（四维全息）────────────────────────────────────
figure('Color','w','Position',[50,50,1500,450],'Name','图5_四维全息需求响应');
sgtitle('秋季 DD-DRO：四维全息综合需求响应分析','FontSize',14,'FontWeight','bold');

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

% ── 图6：DRO 成本精细分解 ─────────────────────────────────────────────
figure('Color','w','Position',[200,200,800,470],'Name','图6_成本分解');
Q_grid = sum(price.*value(f_grid));
Q_re   = sum(K_wind*value(f_p_wind) + K_pv*value(f_p_pv));
Q_es   = sum(K_ES_om*value(f_es_dis) + K_HS_om*value(f_hs_dis));
Q_hfc  = sum(K_HFC_om*(value(f_hfc_e)+value(f_hfc_h)));
Q_dev  = sum(K_EL*value(f_el)*yita_EL + K_EB*value(f_eb)*yita_EB + ...
             K_EC*value(f_ec)*yita_EC + K_AC*(value(f_ac_dc)+value(f_ac_cool)));
Q_1st  = value(Cost_1st_DR);
Q_wass = epsilon_W * lambda_w_star;

cost_items  = [Q_1st, Q_wass, Q_grid, Q_re, Q_es, Q_hfc, Q_dev];
label_items = {'一阶段DR成本','Wasserstein溢价','主网购电','可再生运维','储能运维','燃料电池','转换设备'};
colors_bar  = [c_green;c_orange;c_blue;c_yellow;c_purple;c_brown;c_cyan];

b3 = bar(cost_items,0.55,'FaceColor','flat');
for k=1:length(cost_items), b3.CData(k,:)=colors_bar(k,:); end
xticklabels(label_items); xtickangle(20);
ylabel('成本/元','FontSize',11); grid on; box on;
title(sprintf('秋季 DD-DRO 成本分解（N_s=%d, ε=%.0f kW, κ=%.1f）', ...
    N_s,epsilon_W,kappa_W),'FontSize',12,'FontWeight','bold');
text(1:length(cost_items), cost_items+max(cost_items)*0.015, ...
    arrayfun(@(x)sprintf('%.0f',x),cost_items,'UniformOutput',false), ...
    'HorizontalAlignment','center','FontSize',9,'FontWeight','bold');

% ── 图7：κ 鲁棒性敏感分析 ────────────────────────────────────────────
figure('Color','w','Position',[230,230,780,430],'Name','图7_鲁棒性敏感分析');
kappa_range   = [0.05,0.10,0.15,0.20,0.25,0.30,0.40,0.50];
epsilon_range = kappa_range * (sigma_pv_total+sigma_wind_total) / sqrt(N_s);
DRO_approx    = value(Cost_1st_DR) + epsilon_range*lambda_w_star + (1/N_s)*sum(Q_values);

yyaxis left;
plot(kappa_range,DRO_approx,'-o','Color',c_blue,'LineWidth',2.5,'MarkerFaceColor','w','MarkerSize',8);
ylabel('DRO 近似总成本/元','Color',c_blue,'FontSize',10);
set(gca,'YColor',c_blue);
yyaxis right;
plot(kappa_range,epsilon_range,'--s','Color',c_orange,'LineWidth',2,'MarkerFaceColor','w','MarkerSize',7);
ylabel('Wasserstein 半径 ε/kW','Color',c_orange,'FontSize',10);
set(gca,'YColor',c_orange);
xline(kappa_W,'-.k','LineWidth',1.5,'Label',sprintf('当前 κ=%.2f',kappa_W), ...
    'LabelHorizontalAlignment','right');
xlabel('保守性系数 κ','FontSize',11);
title('鲁棒性敏感分析：κ → ε → DRO 成本','FontSize',12,'FontWeight','bold');
legend('DRO 近似总成本','Wasserstein 半径 ε','Location','northwest','FontSize',10);
grid on; box on;

fprintf('\n✅ 全部 7 张图表已生成完毕\n');
fprintf('   图1: C&CG收敛过程    图2: 概率质量漂移\n');
fprintf('   图3: 风光场景簇      图4: 多能功率平衡\n');
fprintf('   图5: 四维需求响应    图6: 成本精细分解\n');
fprintf('   图7: κ鲁棒性敏感分析\n');

% --- 图4：多能协同功率平衡 ---
figure('Color','w','Position',[120,120,1200,800],'Name','功率平衡');
sgtitle('DD-DRO最恶劣分布场景：秋季多能协同功率平衡','FontSize',14,'FontWeight','bold');
subplot(2,2,1);
Supply_E = [value(f_grid), value(f_p_pv), value(f_p_wind), value(f_es_dis), value(f_hfc_e)];
Consume_E = [-value(f_es_ch), -value(f_ec), -value(f_el), -value(f_eb)];
bar(t_ax,Supply_E,0.8,'stacked','EdgeColor','none'); hold on;
bar(t_ax,Consume_E,0.8,'stacked','EdgeColor','none');
plot(t_ax,L_E_DR_star+L_DC_opt_star,'k-o','LineWidth',1.5,'MarkerFaceColor','w','MarkerSize',4);
title('电功率平衡','FontSize',12); xlabel('时间/h'); ylabel('kW'); xlim([0.5,24.5]); grid on;
legend('购电','光伏','风电','储能放','HFC电','储能充','电制冷','电解槽','电锅炉','总电负荷',...
    'Location','southoutside','NumColumns',5,'FontSize',8);
subplot(2,2,2);
bar(t_ax,[value(f_eb)*yita_EB, value(f_hfc_h)],0.8,'stacked','EdgeColor','none'); hold on;
bar(t_ax,-value(f_ac_h),0.8,'FaceColor','#D95319','EdgeColor','none');
plot(t_ax,L_H_DR_star,'r-^','LineWidth',1.5,'MarkerFaceColor','w');
title('热功率平衡','FontSize',12); xlabel('时间/h'); ylabel('kW'); xlim([0.5,24.5]); grid on;
legend('电锅炉','HFC热','吸收制冷热','净热负荷','Location','southoutside','NumColumns',4,'FontSize',8);
subplot(2,2,3);
bar(t_ax,[value(f_ec_cool), value(f_ac_cool)],0.8,'stacked','EdgeColor','none'); hold on;
plot(t_ax,L_C_DR_star,'b-s','LineWidth',1.5,'MarkerFaceColor','w');
title('冷功率平衡','FontSize',12); xlabel('时间/h'); ylabel('kW'); xlim([0.5,24.5]); grid on;
legend('电制冷','吸收制冷','净冷负荷','Location','southoutside','NumColumns',3,'FontSize',8);
subplot(2,2,4); yyaxis left;
plot(t_ax,value(f_es_soc)/V_ES,'-s','LineWidth',1.5,'Color',c_blue,'MarkerFaceColor','w');
ylabel('电储能SOC','Color',c_blue); ylim([0,1]); set(gca,'YColor',c_blue);
yyaxis right;
plot(t_ax,value(f_tin),'-d','LineWidth',1.5,'Color',c_orange,'MarkerFaceColor','w');
ylabel('DC内温/°C','Color',c_orange); ylim([15,30]); set(gca,'YColor',c_orange);
yline(27.22,'--r'); yline(17.78,'--b');
title('储能SOC与数据中心温控','FontSize',12); xlabel('时间/h'); xlim([0.5,24.5]); grid on;

% =========================================================================
%  图8：风光预测误差三维线条图（场景误差结构可视化）
% =========================================================================
figure('Color','w','Position',[120,120,1100,480],'Name','图8_预测误差三维');
sgtitle('秋季场景预测误差三维演化图（相对秋季预测均值）', 'FontSize', 14, 'FontWeight', 'bold');

% 【防报错核心修改】：强制让时间轴、Y轴、Z轴统统变成 24×1 的列向量
t_col = (1:24)'; 

% 补充颜色定义（防止未继承前面的变量）
c_red  = [0.635, 0.078, 0.184];
c_blue = [0.000, 0.447, 0.741];

% ---------------- a. 风电预测误差三维分布 ----------------
subplot(1,2,1); hold on; grid on;
% 确保 P_wind_max 是列向量后计算误差
P_wind_max_col = reshape(P_wind_max, 24, 1);
Wind_Error = Scenarios_wind - repmat(P_wind_max_col, 1, N_s);

colors_w = parula(N_s);
for s = 1:N_s
    % plot3(X, Y, Z) 全部使用 24×1 列向量
    plot3(t_col, ones(24,1)*s, Wind_Error(:,s), 'Color', colors_w(s,:), 'LineWidth', 0.9);
end
% 最恶劣场景高亮
plot3(t_col, ones(24,1)*worst_j, Wind_Error(:,worst_j), '-^', 'Color', c_red, 'LineWidth', 2.5, 'MarkerSize', 6, 'MarkerFaceColor', 'w');

view(-30, 28); box on;
xlabel('时段 / h', 'FontSize', 11);
ylabel('场景编号', 'FontSize', 11);
zlabel('风电预测误差 / kW', 'FontSize', 11);
title('a. 风电预测误差三维分布', 'FontSize', 12);
colormap(gca, parula); cb1 = colorbar; cb1.Label.String = '场景编号';

% ---------------- b. 光伏预测误差三维分布 ----------------
subplot(1,2,2); hold on; grid on;
% 确保 P_pv_max 是列向量后计算误差
P_pv_max_col = reshape(P_pv_max, 24, 1);
PV_Error  = Scenarios_pv - repmat(P_pv_max_col, 1, N_s);

colors_pv = hot(N_s);
for s = 1:N_s
    % plot3(X, Y, Z) 全部使用 24×1 列向量
    plot3(t_col, ones(24,1)*s, PV_Error(:,s), 'Color', colors_pv(s,:), 'LineWidth', 0.9);
end
% 最恶劣场景高亮
plot3(t_col, ones(24,1)*worst_j, PV_Error(:,worst_j), '-s', 'Color', c_blue, 'LineWidth', 2.5, 'MarkerSize', 6, 'MarkerFaceColor', 'w');

view(-30, 28); box on;
xlabel('时段 / h', 'FontSize', 11);
ylabel('场景编号', 'FontSize', 11);
zlabel('光伏预测误差 / kW', 'FontSize', 11);
title('b. 光伏预测误差三维分布', 'FontSize', 12);
colormap(gca, hot); cb2 = colorbar; cb2.Label.String = '场景编号';

fprintf('✅ 图8: 风光预测误差三维演化图 已成功生成！\n');

