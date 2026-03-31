import numpy as np
import matplotlib.pyplot as plt

# ==========================================
# 0. 全局字体与排版设置 (严格宋体五号字标准)
# ==========================================
# 中文用宋体，英文和数学公式使用 Times New Roman
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.unicode_minus'] = False

# 【核心修改】：全局字号死锁为 10.5pt (五号字)
plt.rcParams['font.size'] = 10.5

# ==========================================
# 1. 嵌入你的真实运行数据
# ==========================================
f1_valid = np.array([5.7964, 6.8543, 6.3311, 6.1789, 6.0710, 5.9866, 5.9211, 5.8747, 5.8435, 5.8174, 5.8003, 5.7954])
f2_valid = np.array([95.873550, 0.000106, 8.715777, 17.431554, 26.147331, 34.863109, 43.578885, 52.294663, 61.010434, 69.726217, 78.441938, 87.157733])
C_score  = np.array([0.093846, 0.906068, 0.896647, 0.815546, 0.727404, 0.638100, 0.548792, 0.459925, 0.371937, 0.285782, 0.203516, 0.131698])
best_idx = 4  # 对应的折中方案

# ==========================================
# 2. 数据处理与排序
# ==========================================
sort_idx = np.argsort(f2_valid)
f2_sorted = f2_valid[sort_idx]
f1_sorted = f1_valid[sort_idx]

min_f2_idx = np.argmin(f2_valid)
min_f1_idx = np.argmin(f1_valid)

# ==========================================
# 3. 开始绘图
# ==========================================
# 【核心修改】：画布物理尺寸锁定在 6.3x4.5 英寸
fig, ax = plt.subplots(figsize=(6.3, 4.5), dpi=300)

# 学术配色
c_line = '#A9A9A9'
c_best = '#FF4500'
c_min_f2 = '#32CD32'
c_min_f1 = '#1E90FF'

ax.grid(linestyle='--', alpha=0.6, color='#CCCCCC')

# 画帕累托前沿连线
ax.plot(f2_sorted, f1_sorted, '-', color=c_line, linewidth=1.5, zorder=1, label='Pareto 前沿连线')

# 画所有候选散点 (散点大小适度缩小以匹配 6.3 英寸画布)
scatter = ax.scatter(f2_valid, f1_valid, c=C_score, cmap='plasma', s=100,
                     edgecolors='white', linewidths=1.0, zorder=2, label='非支配解 (候选方案)')

# Colorbar (去掉局部字号)
cbar = plt.colorbar(scatter, ax=ax, pad=0.02)
cbar.set_label('CRITIC-TOPSIS 贴近度 $C_i$', fontweight='bold')

# 标注 TOPSIS 最优折中解
best_f1 = f1_valid[best_idx]
best_f2 = f2_valid[best_idx]
best_C  = C_score[best_idx]
ax.scatter(best_f2, best_f1, color=c_best, marker='*', s=180,
           edgecolors='black', linewidths=0.8, zorder=4, label='TOPSIS 最优折中解')

# 标注极端点
ax.scatter(f2_valid[min_f2_idx], f1_valid[min_f2_idx], color=c_min_f2, marker='s', s=80, edgecolors='black', zorder=3, label='极致体验端')
ax.scatter(f2_valid[min_f1_idx], f1_valid[min_f1_idx], color=c_min_f1, marker='o', s=80, edgecolors='black', zorder=3, label='极致成本端')

# 为最优解添加注释气泡 (移除 fontsize)
bbox_props = dict(boxstyle="round,pad=0.5", fc="white", ec=c_best, lw=1.0, alpha=0.9)
ax.annotate(f'★ 最优折中方案\n$f_1$ = {best_f1:.4f}\n$f_2$ = {best_f2:.4f}\n$C_i$ = {best_C:.4f}',
            xy=(best_f2, best_f1), xytext=(best_f2 + 12, best_f1 + 0.2),
            fontweight='bold', color=c_best,
            arrowprops=dict(arrowstyle="->", connectionstyle="arc3,rad=-0.1", color=c_best, lw=1.5),
            bbox=bbox_props, zorder=5)

# 为其他点添加标签 (移除 fontsize)
for rank, idx in enumerate(sort_idx):
    if idx != best_idx:
        ax.text(f2_valid[idx] + 1.2, f1_valid[idx] + 0.02, f'P{rank+1}', color='#333333', fontweight='bold', zorder=4)

# ==========================================
# 4. 图表细节修饰
# ==========================================
# 全部继承全局 10.5pt
ax.set_xlabel('$f_2$：多维需求响应恶化度指数', fontweight='bold')
ax.set_ylabel('$f_1$：系统综合运行成本 / 万元', fontweight='bold')

# 图例位置
ax.legend(loc='upper right', framealpha=0.95, edgecolor='#333333', handlelength=1.2)

# 确保边缘文字不被裁掉
plt.tight_layout()
plt.savefig('Pareto_Front_Final.png', dpi=300, bbox_inches='tight')
plt.show()

print("✅ SCI级 Pareto 前沿图已生成！(适配宋体五号字标准)")