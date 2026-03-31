import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ================= 1. 全局字体与排版核心设置 =================
# 设置宋体和 Times New Roman，完美适配大论文
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']
plt.rcParams['axes.unicode_minus'] = False

# 【关键修改】全局字号设为 26，对应 Word 缩放后的 10.5pt (五号字)
plt.rcParams['font.size'] = 16
# 图例稍微小一号，防止占据过大空间
plt.rcParams['legend.fontsize'] = 16
# 标题字号再大一号
plt.rcParams['axes.titlesize'] = 18
# =========================================================

# ================= 2. 莫兰迪/高级灰 配色大全 =================
c_grid = '#FDC68A'
c_pv = '#98D294'
c_wind = '#BEB8DA'
c_es_d = '#8DD3C7'
c_hfc = '#FFFFB3'
c_es_c = '#80B1D3'
c_el = '#FB8072'
c_eb = '#D9D9D9'
c_ec = '#BC80BD'
c_load = '#000000'

c_eb_h = '#E59866'
c_hfc_h = '#F8C471'
c_ac_h = '#F1948A'
c_ec_c = '#5DADE2'
c_ac_c = '#76D7C4'

# ================= 3. 读取数据 =================
df = pd.read_excel('Scenario6_Results.xlsx')
hours_24 = np.arange(1, 25)
hours_96 = np.arange(1, 97)

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# ================= 4. 绘制并保存图一：2x2 电功率平衡图 =================
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# 【关键修改】画布比例调整为 16x12，给四格大字号留出足够空间
fig_e, axes = plt.subplots(2, 2, figsize=(16, 12), dpi=300)
seasons = ['春季典型日', '夏季典型日', '秋季典型日', '冬季典型日']

for i in range(4):
    ax = axes[i // 2, i % 2]
    start_idx, end_idx = i * 24, (i + 1) * 24

    pos_data = [df['P_grid'][start_idx:end_idx], df['P_pv'][start_idx:end_idx],
                df['P_wind'][start_idx:end_idx], df['P_ES_dis'][start_idx:end_idx], df['P_HFC_e'][start_idx:end_idx]]
    neg_data = [-df['P_ES_ch'][start_idx:end_idx], -df['P_EL'][start_idx:end_idx],
                -df['P_EB'][start_idx:end_idx], -df['P_EC'][start_idx:end_idx]]

    pos_colors = [c_grid, c_pv, c_wind, c_es_d, c_hfc]
    neg_colors = [c_es_c, c_el, c_eb, c_ec]
    pos_labels = ['电网购电', '光伏出力', '风电出力', '储能放电', '燃料电池发电']
    neg_labels = ['储能充电', '电解槽耗电', '电锅炉耗电', '电制冷耗电']

    bottom_pos = np.zeros(24)
    for j in range(len(pos_data)):
        ax.bar(hours_24, pos_data[j], bottom=bottom_pos, color=pos_colors[j],
               width=0.75, edgecolor='#333333', linewidth=0.8,
               label=pos_labels[j] if i == 0 else "")
        bottom_pos += pos_data[j].values

    bottom_neg = np.zeros(24)
    for j in range(len(neg_data)):
        ax.bar(hours_24, neg_data[j], bottom=bottom_neg, color=neg_colors[j],
               width=0.75, edgecolor='#333333', linewidth=0.8,
               label=neg_labels[j] if i == 0 else "")
        bottom_neg += neg_data[j].values

    # 【关键修改】常规负荷曲线加粗，圆点放大
    ax.plot(hours_24, df['Load_E'][start_idx:end_idx], color=c_load, marker='o',
            markersize=8, markerfacecolor='w', markeredgewidth=2, linewidth=3.5,
            zorder=5, label='常规电负荷' if i == 0 else "")

    # 去除局部 fontsize，继承全局
    ax.set_title(seasons[i], fontweight='bold')
    ax.set_xlim(0, 25)

    # 【关键修改】X 轴刻度间隔调大为 4，防止 26 号大字互相挤压重叠
    ax.set_xticks(np.arange(0, 25, 4))

    ax.tick_params(direction='in', length=6, width=1.5)
    ax.grid(axis='y', linestyle='--', alpha=0.4)

    if i % 2 == 0:
        ax.set_ylabel('电功率 / kW', fontweight='bold')
    if i >= 2:
        ax.set_xlabel('时间 / h', fontweight='bold')

# 【关键修改】调高图例的 Y 轴坐标 (1.06)，防止遮挡顶部的子图标题
fig_e.legend(loc='upper center', ncol=5, bbox_to_anchor=(0.5, 1.06), framealpha=1, edgecolor='#333333')
plt.tight_layout(rect=[0, 0, 1, 0.95])

fig_e.savefig('场景6_电功率平衡图.png', bbox_inches='tight', dpi=300)
print("电功率图已成功保存！")

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# ================= 5. 绘制并保存图二：连续热/冷功率平衡图 =================
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# 保持画布大小不变
fig_hc, (ax_h, ax_c) = plt.subplots(2, 1, figsize=(16, 10), dpi=300)

# ----------------- 子图 1：热功率平衡 -----------------
heat_supply = [df['P_EB'] * 0.95, df['P_HFC_h']]
heat_consume = [-df['P_AC_h']]

ax_h.bar(hours_96, heat_supply[0], color=c_eb_h, width=0.75, edgecolor='#333333', linewidth=0.8, label='电锅炉产热')
ax_h.bar(hours_96, heat_supply[1], bottom=heat_supply[0], color=c_hfc_h, width=0.75, edgecolor='#333333', linewidth=0.8,
         label='燃料电池发热')
ax_h.bar(hours_96, heat_consume[0], color=c_ac_h, width=0.75, edgecolor='#333333', linewidth=0.8, label='吸收制冷抽热')

ax_h.plot(hours_96, df['Load_H'], color=c_load, marker='o', markersize=3, markerfacecolor='w', markeredgewidth=1.5,
          linewidth=1.5, zorder=5, label='常规热负荷')

for x in [24.5, 48.5, 72.5]:
    ax_h.axvline(x, color='k', linestyle='--', alpha=0.6, zorder=0)

ax_h.set_xlim(0, 97)
ax_h.set_xticks(np.arange(0, 97, 12))
ax_h.tick_params(direction='in', length=6, width=1.5)

ax_h.set_ylabel('热功率 / kW', fontweight='bold')
# 【重点修改1：大幅提高标题字号，并增加间距防止与图例重叠】
ax_h.set_title('全年四季连续热功率平衡', fontweight='bold', fontsize=20, pad=20)
ax_h.grid(axis='y', linestyle='--', alpha=0.4)
# 【重点修改2：提高图例字号，并让图例靠上一些，避免挡住曲线】
ax_h.legend(loc='upper right', ncol=4, edgecolor='#333333', fontsize=16, bbox_to_anchor=(1, 0.98))

# ----------------- 子图 2：冷功率平衡 -----------------
cool_supply = [df['P_EC_cool'], df['P_AC_cool']]

ax_c.bar(hours_96, cool_supply[0], color=c_ec_c, width=0.75, edgecolor='#333333', linewidth=0.8, label='电制冷机产冷')
ax_c.bar(hours_96, cool_supply[1], bottom=cool_supply[0], color=c_ac_c, width=0.75, edgecolor='#333333', linewidth=0.8,
         label='吸收式制冷产冷')

ax_c.plot(hours_96, df['Load_C'], color=c_load, marker='o', markersize=3, markerfacecolor='w', markeredgewidth=1.5,
          linewidth=1.5, zorder=5, label='常规冷负荷')

for x in [24.5, 48.5, 72.5]:
    ax_c.axvline(x, color='k', linestyle='--', alpha=0.6, zorder=0)

ax_c.set_xlim(0, 97)
ax_c.set_xticks(np.arange(0, 97, 12))
ax_c.tick_params(direction='in', length=6, width=1.5)

ax_c.set_ylabel('冷功率 / kW', fontweight='bold')
ax_c.set_xlabel('时间 / h', fontweight='bold')
# 【重点修改3：同样大幅提高子图2的标题字号，并增加间距】
ax_c.set_title('全年四季连续冷功率平衡', fontweight='bold', fontsize=20, pad=20)
ax_c.grid(axis='y', linestyle='--', alpha=0.4)
# 【重点修改4：提高图例字号】
ax_c.legend(loc='upper right', ncol=3, edgecolor='#333333', fontsize=16, bbox_to_anchor=(1, 0.98))

# 调整间距，防止热功率X轴标签遮挡冷功率标题
plt.tight_layout(pad=4.0)

fig_hc.savefig('场景6_冷热功率平衡图.png', bbox_inches='tight', dpi=300)
print("冷热功率图已成功保存！")
