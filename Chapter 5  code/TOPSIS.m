% =========================================================================
% MO-TSRO 帕累托前沿最优点评价与可视化 (完美缝合版)
% 核心：TOPSIS双极小决策 + Archive无损提取 + SCI级全景可视化
% =========================================================================

%% =========================================================================
%  Step 1: TOPSIS 法评价帕累托前沿(这个也是前置步骤，就是使用你用相应评价法的出来的最佳折衷解再来运行这个代码)
% =========================================================================
fprintf('\n============================================================\n');
fprintf('  Step 1: TOPSIS 多属性决策 —— 寻找最优折衷帕累托点\n');
fprintf('============================================================\n');

% 前置安全检查：确保有效点存在
valid_mask = ~isnan(pareto_f1);
f1_valid = pareto_f1(valid_mask);
f2_valid = pareto_f2(valid_mask);
abs_idx_list = find(valid_mask); % 记录在原始 pareto_f1 中的绝对索引

n_pts = length(f1_valid);

% ---------- 1.1 构建决策矩阵 X（n × 2）----------
X = [f1_valid, f2_valid];   % n×2

% ---------- 1.2 向量归一化（消除量纲差异）----------
norms = sqrt(sum(X.^2, 1));     
R = X ./ norms;                  

% ---------- 1.3 赋权（等权重，w1=w2=0.5）----------
w = [0.5, 0.5];
V_mat = R .* w;                  

% ---------- 1.4 【修复】：确定正理想解 A+ 与负理想解 A- ----------
% f1 (成本) 是 cost 型：越小越好
% f2 (体验恶化度) 也是 cost 型：越小越好！
A_pos = [min(V_mat(:,1)), min(V_mat(:,2))];   % 正理想解 (双极小)
A_neg = [max(V_mat(:,1)), max(V_mat(:,2))];   % 负理想解 (双极大)

% ---------- 1.5 计算各点到正/负理想解的欧氏距离 ----------
D_pos = sqrt(sum((V_mat - A_pos).^2, 2));   
D_neg = sqrt(sum((V_mat - A_neg).^2, 2));   

% ---------- 1.6 计算相对贴近度 Ci ----------
C_score = D_neg ./ (D_pos + D_neg);

% ---------- 1.7 输出评价结果 ----------
[C_sorted, sort_C] = sort(C_score, 'descend');
fprintf('\n  %-6s %-14s %-14s %-12s\n', '排名', 'f1(万元)', 'f2(DR恶化度)', 'TOPSIS贴近度');
fprintf('  %-6s %-14s %-14s %-12s\n', '----', '--------', '------------', '------------');
for i = 1:n_pts
    rel_idx = sort_C(i);
    marker = '';
    if i == 1, marker = '  ← ★最优折衷点'; end
    fprintf('  %-6d %-14.4f %-14.6f %-12.6f%s\n', ...
        i, f1_valid(rel_idx)/1e4, f2_valid(rel_idx), C_score(rel_idx), marker);
end

% ---------- 1.8 确定最优点并提取对应 Archive ----------
best_rel_idx = sort_C(1);           
best_abs_idx = abs_idx_list(best_rel_idx); % 映射回全量存档的绝对索引

best_f1    = f1_valid(best_rel_idx);
best_f2    = f2_valid(best_rel_idx);
best_eps   = pareto_eps(best_abs_idx);  
best_score = C_score(best_rel_idx);
best_arc   = Archive{best_abs_idx}; % 【核心】：直接提取无损归档的第一阶段变量

fprintf('\n  ✅ TOPSIS最优折衷点:\n');
fprintf('     f1 = %.4f 万元\n', best_f1/1e4);
fprintf('     f2 = %.6f （DR恶化度，越小越好）\n', best_f2);
fprintf('     TOPSIS贴近度 = %.6f\n', best_score);

%% =========================================================================
%  Step 2: 提取归档数据，进行第二阶段终局确定性核算 (耗时 0.1秒)
% =========================================================================
fprintf('\n============================================================\n');
fprintf('  Step 2: 从 Archive 提取数据并核算终局调度\n');
fprintf('============================================================\n');
yalmip('clear');

% 定义作图所需的连续变量
f_p_grid=sdpvar(24,1); f_p_pv=sdpvar(24,1); f_p_wind=sdpvar(24,1);
f_p_es_ch=sdpvar(24,1); f_p_es_dis=sdpvar(24,1); f_es_soc=sdpvar(24,1);
f_p_hs_ch=sdpvar(24,1); f_p_hs_dis=sdpvar(24,1); f_hs_soc=sdpvar(24,1);
f_p_el=sdpvar(24,1); f_p_hfc_e=sdpvar(24,1); f_p_hfc_h=sdpvar(24,1);
f_p_eb=sdpvar(24,1); f_p_ec=sdpvar(24,1);
f_ac_h=sdpvar(24,1); f_ac_dc=sdpvar(24,1); f_ac_cool=sdpvar(24,1); f_ac_dccool=sdpvar(24,1);
f_ec_cool=sdpvar(24,1); f_ec_dc=sdpvar(24,1); f_t_in=sdpvar(24,1);

L_DC_w_s = 0.59 * best_arc.Load_DC_opt;

% 强制约束：在第一阶段变量固定的情况下，面对最恶劣场景求最优调度
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

% 纯二阶运行成本
Final_Cost_2nd = sum(price.*f_p_grid) + sum(K_wind*f_p_wind + K_pv*f_p_pv) + sum(K_ES_om*f_p_es_dis + K_HS_om*f_p_hs_dis + K_HFC_om*(f_p_hfc_e+f_p_hfc_h)) + sum(K_EL*f_p_el*yita_EL + K_EB*f_p_eb*yita_EB + K_EC*f_p_ec*yita_EC + K_AC*(f_ac_dc+f_ac_cool));
optimize(Final_Con, Final_Cost_2nd, ops_sol);

% 提取全部出图所需数值变量
v_p_grid = value(f_p_grid); v_p_pv = value(f_p_pv); v_p_wind = value(f_p_wind);
v_p_es_ch = value(f_p_es_ch); v_p_es_dis = value(f_p_es_dis); v_es_soc = value(f_es_soc);
v_p_hs_ch = value(f_p_hs_ch); v_p_hs_dis = value(f_p_hs_dis); v_hs_soc = value(f_hs_soc);
v_p_el = value(f_p_el); v_p_hfc_e = value(f_p_hfc_e); v_p_hfc_h = value(f_p_hfc_h);
v_p_eb = value(f_p_eb); v_p_ec = value(f_p_ec);
v_ac_h = value(f_ac_h); v_ac_dc = value(f_ac_dc); v_ac_cool = value(f_ac_cool); v_ac_dccool = value(f_ac_dccool);
v_ec_cool = value(f_ec_cool); v_ec_dc = value(f_ec_dc); v_t_in = value(f_t_in);

v_P_E_sl_in = best_arc.P_E_sl_in; v_P_E_sl_out = best_arc.P_E_sl_out; v_P_E_cut = best_arc.P_E_cut;
v_P_H_sl_in = best_arc.P_H_sl_in; v_P_H_sl_out = best_arc.P_H_sl_out; v_P_H_cut = best_arc.P_H_cut;
v_P_C_sl_in = best_arc.P_C_sl_in; v_P_C_sl_out = best_arc.P_C_sl_out; v_P_C_cut = best_arc.P_C_cut;
v_DC_delay1 = best_arc.P_DC_delay1; v_DC_delay2 = best_arc.P_DC_delay2; v_Load_DC_opt = best_arc.Load_DC_opt;
v_Load_E_DR = best_arc.Load_E_DR; v_Load_H_DR = best_arc.Load_H_DR; v_Load_C_DR = best_arc.Load_C_DR;

% 成本分项计算
cost_grid  = sum(price .* v_p_grid); cost_pv    = sum(K_pv  * v_p_pv); cost_wind  = sum(K_wind* v_p_wind);
cost_es    = sum(K_ES_om * v_p_es_dis); cost_hs    = sum(K_HS_om * v_p_hs_dis);
cost_hfc   = sum(K_HFC_om*(v_p_hfc_e + v_p_hfc_h));
cost_el    = sum(K_EL * v_p_el * yita_EL); cost_eb    = sum(K_EB * v_p_eb * yita_EB);
cost_ec    = sum(K_EC * v_p_ec * yita_EC); cost_ac    = sum(K_AC * (v_ac_dc + v_ac_cool));
cost_dr    = sum(c_shift_E*v_P_E_sl_in + c_cut_E*v_P_E_cut) + sum(c_shift_H*v_P_H_sl_in + c_cut_H*v_P_H_cut) + sum(c_shift_C*v_P_C_sl_in + c_cut_C*v_P_C_cut) + sum(c_shift_DC*(v_DC_delay1 + v_DC_delay2));
total_cost = value(Final_Cost_2nd) + cost_dr;

%% =========================================================================
%  Step 3: SCI 级全景可视化
% =========================================================================
c_blue=[0.000,0.447,0.741]; c_orange=[0.850,0.325,0.098]; c_yellow=[0.929,0.694,0.125]; 
c_cyan=[0.301,0.745,0.933]; c_green=[0.466,0.674,0.188]; c_purple=[0.494,0.184,0.556]; 
c_red=[0.850,0.100,0.100]; c_gray=[0.600,0.600,0.600]; t=1:24;

% -------- 图1：TOPSIS 帕累托前沿评价图 --------
figure('Color','w','Position',[50,50,900,580],'Name','TOPSIS帕累托评价'); hold on; grid on; box on;
plot(f2_valid, f1_valid/1e4, '-', 'Color', c_gray, 'LineWidth', 1.5);
scatter(f2_valid, f1_valid/1e4, 160, C_score, 'filled', 'MarkerEdgeColor','w', 'LineWidth',1.2);
colormap(flipud(summer)); cb = colorbar; cb.Label.String = 'TOPSIS 贴近度 C_i'; cb.Label.FontSize = 11;
clim([min(C_score)-0.01, max(C_score)+0.01]);

scatter(best_f2, best_f1/1e4, 280, '^', 'filled', 'MarkerFaceColor', c_red, 'MarkerEdgeColor','w', 'LineWidth',1.5, 'DisplayName', sprintf('TOPSIS最优点'));
text(best_f2+0.002, best_f1/1e4+0.05, sprintf('★最优折衷\nf_1=%.2f万\nf_2=%.4f\nC_i=%.4f', best_f1/1e4, best_f2, best_score), 'FontSize',9,'Color',c_red,'FontWeight','bold','BackgroundColor','w','EdgeColor',c_red);

[~, min_f2_idx] = min(f2_valid); [~, min_f1_idx] = min(f1_valid);
scatter(f2_valid(min_f2_idx), f1_valid(min_f2_idx)/1e4, 200, 's', 'filled', 'MarkerFaceColor', c_green, 'MarkerEdgeColor','w', 'DisplayName', '极致体验端（f_2最小）');
scatter(f2_valid(min_f1_idx), f1_valid(min_f1_idx)/1e4, 200, 'o', 'filled', 'MarkerFaceColor', c_blue, 'MarkerEdgeColor','w', 'DisplayName', '极致成本端（f_1最小）');

xlabel('f_2：四维DR恶化度指数（电+热+冷+DC，越小越好）', 'FontSize',13); ylabel('f_1：系统综合运行成本 / 万元', 'FontSize',13);
title({'MO-TSRO 帕累托前沿 TOPSIS 多属性评价', sprintf('最优折衷点: f_1=%.2f万元  f_2=%.4f  C_i=%.4f', best_f1/1e4, best_f2, best_score)}, 'FontSize',12,'FontWeight','bold');
legend('帕累托连线','','TOPSIS最优点','极致体验端','极致成本端', 'Location','northeast','FontSize',10);

% -------- 图2：电功率平衡 --------
figure('Color','w','Position',[100,100,1100,500],'Name','电功率平衡');
bar(t, [v_p_grid, v_p_pv, v_p_wind, v_p_es_dis, v_p_hfc_e], 0.75, 'stacked', 'EdgeColor','none'); hold on;
bar(t, [-v_p_es_ch, -v_p_ec, -v_p_el, -v_p_eb], 0.75, 'stacked', 'EdgeColor','none');
plot(t, v_Load_E_DR + v_Load_DC_opt, 'k-o', 'LineWidth',2, 'MarkerSize',5, 'MarkerFaceColor','w', 'DisplayName','总电负荷');
xlabel('时间 / h'); ylabel('功率 / kW'); xlim([0.5 24.5]); xticks(1:24); grid on; box on; title('最优折衷点 — 电功率平衡（最恶劣场景）','FontSize',12,'FontWeight','bold');
legend('主网购电','光伏(实发)','风电(实发)','储能放电','燃料电池发电','储能充电','电制冷','电解槽','电锅炉','总电负荷','Location','southoutside','NumColumns',5,'FontSize',9);

% -------- 图3：热功率与冷功率平衡 --------
figure('Color','w','Position',[100,200,1100,420],'Name','热冷功率平衡');
subplot(1,2,1);
bar(t, [v_p_eb*yita_EB, v_p_hfc_h], 0.75, 'stacked', 'EdgeColor','none'); hold on; bar(t, [-v_ac_h], 0.75, 'FaceColor',c_orange, 'EdgeColor','none');
plot(t, v_Load_H_DR, 'r-^','LineWidth',2,'MarkerSize',5,'MarkerFaceColor','w'); title('热功率平衡', 'FontSize',12,'FontWeight','bold'); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([0.5 24.5]); grid on; box on; legend('电锅炉产热','燃料电池产热','吸收制冷耗热','实际热负荷','Location','southoutside','NumColumns',2,'FontSize',9);
subplot(1,2,2);
bar(t, [v_ec_cool, v_ac_cool], 0.75, 'stacked', 'EdgeColor','none'); hold on; plot(t, v_Load_C_DR, 'b-s','LineWidth',2,'MarkerSize',5,'MarkerFaceColor','w'); title('冷功率平衡', 'FontSize',12,'FontWeight','bold'); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([0.5 24.5]); grid on; box on; legend('电制冷产冷','吸收制冷产冷','实际冷负荷','Location','southoutside','NumColumns',3,'FontSize',9);
sgtitle('最优折衷点 — 热/冷功率平衡', 'FontSize',13,'FontWeight','bold');

% -------- 图4：储能 SOC + 数据中心机房温控 --------
figure('Color','w','Position',[150,150,900,420],'Name','储能SOC与DC温控'); hold on; grid on; box on;
yyaxis left; plot(t, v_es_soc/V_ES, '-s', 'Color',c_blue, 'LineWidth',2, 'MarkerFaceColor','w','MarkerSize',6); ylabel('电储能 SOC', 'Color',c_blue,'FontSize',12); ylim([0 1]); set(gca,'YColor',c_blue); yline(0.1,'--','Color',c_blue,'LineWidth',1,'Alpha',0.5); yline(0.9,'--','Color',c_blue,'LineWidth',1,'Alpha',0.5);
yyaxis right; plot(t, v_t_in, '-d', 'Color',c_orange, 'LineWidth',2, 'MarkerFaceColor','w','MarkerSize',6); yline(27.22,'--r','T_{max}=27.22°C','LineWidth',1.2,'LabelHorizontalAlignment','left'); yline(17.78,'--b','T_{min}=17.78°C','LineWidth',1.2,'LabelHorizontalAlignment','left'); ylabel('机房温度 / °C', 'Color',c_orange,'FontSize',12); ylim([15 30]); set(gca,'YColor',c_orange);
xlabel('时间 / h','FontSize',12); xlim([0.5 24.5]); xticks(1:24); title('最优折衷点 — 储能SOC协同与DC精细温控','FontSize',12,'FontWeight','bold'); legend('电储能SOC','机房温度','Location','northeast','FontSize',10);

% -------- 图5：四维全息需求响应分析 --------
figure('Color','w','Position',[50,50,1400,420],'Name','四维全息需求响应');
subplot(1,4,1); plot(t, Load_E, 'k--', 'LineWidth',1.5); hold on; plot(t, v_Load_E_DR, 'Color',c_blue, 'LineWidth',2); bar(t, v_P_E_sl_in, 'FaceColor',c_green, 'EdgeColor','none','FaceAlpha',0.65); bar(t, -v_P_E_sl_out, 'FaceColor',c_yellow, 'EdgeColor','none','FaceAlpha',0.65); bar(t, -v_P_E_cut, 'FaceColor',c_red, 'EdgeColor','none','FaceAlpha',0.65); title('电负荷需求响应','FontSize',12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on; legend('原始预测','优化后','负荷转入','负荷转出','负荷削减','Location','southoutside','NumColumns',2,'FontSize',8);
subplot(1,4,2); plot(t, Load_H, 'k--', 'LineWidth',1.5); hold on; plot(t, v_Load_H_DR, 'Color',c_orange, 'LineWidth',2); bar(t, v_P_H_sl_in, 'FaceColor',c_green, 'EdgeColor','none','FaceAlpha',0.65); bar(t, -v_P_H_sl_out, 'FaceColor',c_yellow, 'EdgeColor','none','FaceAlpha',0.65); bar(t, -v_P_H_cut, 'FaceColor',c_blue, 'EdgeColor','none','FaceAlpha',0.65); title('热负荷需求响应','FontSize',12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;
subplot(1,4,3); plot(t, Load_C, 'k--', 'LineWidth',1.5); hold on; plot(t, v_Load_C_DR, 'Color',c_cyan, 'LineWidth',2); bar(t, v_P_C_sl_in, 'FaceColor',c_green, 'EdgeColor','none','FaceAlpha',0.65); bar(t, -v_P_C_sl_out, 'FaceColor',c_yellow, 'EdgeColor','none','FaceAlpha',0.65); bar(t, -v_P_C_cut, 'FaceColor',c_purple, 'EdgeColor','none','FaceAlpha',0.65); title('冷负荷需求响应','FontSize',12); xlabel('时间 / h'); ylabel('功率 / kW'); xlim([1 24]); grid on;
subplot(1,4,4); yyaxis left; bar(t, v_Load_DC_opt - Load_DC + v_DC_delay1 + v_DC_delay2, 'FaceColor',c_green, 'EdgeColor','none','BarWidth',0.6); hold on; bar(t, -(v_DC_delay1 + v_DC_delay2), 'FaceColor',c_yellow, 'EdgeColor','none','BarWidth',0.6); ylabel('延迟转移量 / kW'); ylim([-max(Load_DC)*0.4, max(Load_DC)*0.4]); ax=gca; ax.YColor='k'; yyaxis right; plot(t, Load_DC, 'k--','LineWidth',1.5); hold on; plot(t, v_Load_DC_opt, '-s','Color',c_purple,'LineWidth',2,'MarkerFaceColor','w','MarkerSize',5); ylabel('算力功率 / kW'); ylim([min(Load_DC)*0.7, max(Load_DC)*1.2]); ax=gca; ax.YColor='k'; title('数据中心时序延迟(DCDR)','FontSize',12); xlabel('时间 / h'); xlim([1 24]); grid on; legend('算力转入','延迟转出','原始算力','优化算力','Location','southoutside','NumColumns',2,'FontSize',8);
sgtitle('最优折衷点 — 四维全息综合需求响应分析','FontSize',13,'FontWeight','bold');

% -------- 图6：运行成本分项饼图 + TOPSIS评分雷达对比 --------
figure('Color','w','Position',[200,200,1100,450],'Name','成本分项与TOPSIS评分');
subplot(1,2,1); cost_items = [cost_grid, cost_pv+cost_wind, cost_es+cost_hs, cost_hfc, cost_el, cost_eb, cost_ec+cost_ac, cost_dr]; cost_labels = {'购电成本','风光运维','储能运维','燃料电池','电解槽','电锅炉','制冷设备','DR补贴'}; nz = cost_items > 0.5; pie(cost_items(nz), cost_labels(nz)); title(sprintf('最优折衷点 运行成本分项\n总成本 = %.4f 万元', total_cost/1e4),'FontSize',11,'FontWeight','bold');
subplot(1,2,2); b = bar(1:n_pts, C_score, 0.65, 'FaceColor','flat', 'EdgeColor','w'); for i = 1:n_pts, b.CData(i,:) = c_blue * (C_score(i)/max(C_score)); end; b.CData(best_rel_idx,:) = c_red; hold on; text(best_rel_idx, C_score(best_rel_idx)+0.005, '★', 'FontSize',14,'Color',c_red,'HorizontalAlignment','center'); xlabel('帕累托点编号（按恶化度从低到高）'); ylabel('TOPSIS 贴近度 C_i','FontSize',11); title('各帕累托点 TOPSIS 评分对比','FontSize',11,'FontWeight','bold'); xticks(1:n_pts); xticklabels(arrayfun(@(i) sprintf('P%d',i), 1:n_pts, 'UniformOutput',false)); grid on; box on; ylim([0, max(C_score)*1.15]);
sgtitle('成本分项分析与帕累托点 TOPSIS 综合评价','FontSize',13,'FontWeight','bold');

fprintf('\n✅ 6张 SCI 级高质量可视化图像已生成！\n');

