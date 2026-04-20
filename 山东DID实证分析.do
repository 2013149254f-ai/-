
clear all
set more off
capture log close

import excel "C:\Users\Administrator\Desktop\山东DID中文.xlsx", ///
    sheet("完整面板数据") cellrange(A4:AJ3200) clear
* 按列字母顺序批量重命名（共36列：A-AJ）
rename (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE AF AG AH AI AJ) ///
       (county_name county_id year treat pilot_year post did rel_year ///
        digital_lit ln_digital_lit infra_index digital_econ human_cap high_hc did_hc ///
        elderly_ratio gdp_pc urban_rate fiscal_agri industry_upg telecom finance_dev farmer_inc ///
        lead3 lead2 event0 lag1 lag2 lag3plus sim_flag cx1 cx2 cx3 cx4 cx5 cx6)

* 确保数值型
destring county_id year treat post did rel_year ///
    digital_lit ln_digital_lit infra_index digital_econ human_cap high_hc did_hc ///
    elderly_ratio gdp_pc urban_rate fiscal_agri industry_upg telecom finance_dev farmer_inc ///
    lead3 lead2 event0 lag1 lag2 lag3plus cx1 cx2 cx3 cx4 cx5 cx6, replace ignore(",")

* 设置面板结构
xtset county_id year

* 控制变量组合（6个）
global controls cx1 cx2 cx3 cx4 cx5 cx6

* ── 1. 描述性统计 ─────────────────────────────────────────
eststo clear
estpost summarize digital_lit infra_index digital_econ human_cap ///
    elderly_ratio gdp_pc urban_rate fiscal_agri industry_upg telecom finance_dev farmer_inc

esttab using "C:\Users\Administrator\Desktop\描述性统计.rtf", ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3)) count(fmt(0))") ///
    label title("表1 描述性统计") replace

/*===========================================================
  一、主效应检验（H1）
  模型：双向固定效应 DID
  digital_lit_it = β0 + β1·did_it + 控制变量 + α_i + γ_t + ε_it
===========================================================*/

* 基准回归（不含控制变量）
eststo m1: xtreg digital_lit did, fe robust

* 加入控制变量
eststo m2: xtreg digital_lit did $controls, fe robust

* 被解释变量取对数（稳健性）
eststo m3: xtreg ln_digital_lit did $controls, fe robust

* 输出主效应表
esttab m1 m2 m3 using "C:\Users\Administrator\Desktop\主效应DID.rtf", ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(did $controls) ///
    title("表2 主效应DID回归结果（H1）") ///
    mtitles("基准" "加控制变量" "对数被解释变量") ///
    stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) ///
    replace

/*===========================================================
  二、平行趋势检验（事件研究法）
  以政策前1期（前1期）为基准组，估计各期系数
  lead3 lead2 [前1期=基准] event0 lag1 lag2 lag3plus
===========================================================*/

* 事件研究回归
eststo es: xtreg digital_lit lead3 lead2 event0 lag1 lag2 lag3plus ///
    $controls, fe robust

* 输出系数表
esttab es using "C:\Users\Administrator\Desktop\平行趋势检验.rtf", ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(lead3 lead2 event0 lag1 lag2 lag3plus) ///
    title("表3 平行趋势检验（事件研究法）") ///
    mtitles("事件研究") ///
    stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) ///
    replace

* 绘制事件研究图
coefplot es, keep(lead3 lead2 event0 lag1 lag2 lag3plus) ///
    vertical recast(connected) ///
    yline(0, lcolor(gray) lpattern(dash)) ///
    xline(3, lcolor(red) lpattern(dash)) ///
    xlabel(1 "前3期" 2 "前2期" 3 "前1期(基准)" 4 "当期" 5 "滞后1期" 6 "滞后2期" 7 "滞后3期+") ///
    xtitle("相对政策时点") ytitle("系数估计值") ///
    title("图1 平行趋势检验（事件研究法）") ///
    ciopts(recast(rcap)) ///
    graphregion(color(white))
graph export "C:\Users\Administrator\Desktop\平行趋势图.png", replace width(1200)

/*===========================================================
  三、机制检验
  采用逐步中介法（Baron & Kenny）+ 双向固定效应
  路径1（H2）：数字乡村建设 → 数字基础设施 → 数字素养
  路径2（H3）：数字乡村建设 → 数字经济 → 数字素养
===========================================================*/

* ── 机制1：数字基础设施（H2）──────────────────────────
* 第一步：did → infra_index（政策对中介变量的影响）
eststo mech1_s1: xtreg infra_index did $controls, fe robust

* 第二步：did + infra_index → digital_lit（加入中介变量后主效应变化）
eststo mech1_s2: xtreg digital_lit did infra_index $controls, fe robust

* ── 机制2：数字经济（H3）────────────────────────────────
* 第一步：did → digital_econ
eststo mech2_s1: xtreg digital_econ did $controls, fe robust

* 第二步：did + digital_econ → digital_lit
eststo mech2_s2: xtreg digital_lit did digital_econ $controls, fe robust

* 输出机制检验表
esttab mech1_s1 mech1_s2 mech2_s1 mech2_s2 ///
    using "C:\Users\Administrator\Desktop\机制检验.rtf", ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(did infra_index digital_econ) ///
    title("表4 机制检验结果（H2、H3）") ///
    mtitles("基础设施(第一步)" "基础设施(第二步)" "数字经济(第一步)" "数字经济(第二步)") ///
    stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) ///
    replace

/*===========================================================
  四、异质性检验（H4）
  高人力资本 vs 低人力资本分组
  方法1：分组回归
  方法2：交互项回归（did × high_hc）
===========================================================*/

* ── 方法1：分组回归 ──────────────────────────────────────
* 低人力资本组
eststo het_low: xtreg digital_lit did $controls if high_hc == 0, fe robust

* 高人力资本组
eststo het_high: xtreg digital_lit did $controls if high_hc == 1, fe robust

* ── 方法2：交互项回归 ────────────────────────────────────
* did_hc = did × high_hc（数据中已有该变量）
eststo het_inter: xtreg digital_lit did high_hc did_hc $controls, fe robust

* 输出异质性检验表
esttab het_low het_high het_inter ///
    using "C:\Users\Administrator\Desktop\异质性检验.rtf", ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(did high_hc did_hc) ///
    title("表5 异质性检验结果（H4）") ///
    mtitles("低人力资本组" "高人力资本组" "交互项回归") ///
    stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) ///
    replace

/*===========================================================
  五、稳健性检验
  5.1 安慰剂检验（随机分配处理组）
  5.2 排除直辖市/省会（历下区等核心城区）
  5.3 替换被解释变量为对数形式
===========================================================*/

* ── 5.1 安慰剂检验 ───────────────────────────────────────
* 在县级层面随机重新分配处理组，保持处理组总数不变
set seed 12345
local placebo_n = 500
matrix placebo_coef = J(`placebo_n', 1, .)

* 获取县级唯一ID列表
preserve
keep county_id treat
duplicates drop county_id, force
tempfile county_treat
save `county_treat'
restore

forvalues i = 1/`placebo_n' {
    preserve
    * 在县级层面随机打乱处理组标签
    merge m:1 county_id using `county_treat', keepusing(treat) nogen update
    * 生成随机排序并重新分配
    tempvar rand_order
    gen `rand_order' = runiform()
    sort `rand_order'
    * 保持处理组数量不变，随机重新分配给不同县
    gen rand_treat = treat[_n]   // 打乱后重新赋值
    * 按county_id排序恢复面板结构
    sort county_id year
    gen rand_did = rand_treat * post
    quietly xtreg digital_lit rand_did $controls, fe robust
    matrix placebo_coef[`i', 1] = _b[rand_did]
    restore
}

* 将安慰剂系数转为变量并绘图
svmat placebo_coef, names(pc)
quietly xtreg digital_lit did $controls, fe robust
local true_coef = _b[did]

twoway (histogram pc1, bin(40) color(ltblue) freq) ///
    (pci 0 `true_coef' 50 `true_coef', lcolor(red) lwidth(medthick)), ///
    legend(order(1 "安慰剂系数分布" 2 "真实DID系数")) ///
    xtitle("系数估计值") ytitle("频次") ///
    title("图2 安慰剂检验（500次随机模拟）") ///
    graphregion(color(white))
graph export "C:\Users\Administrator\Desktop\安慰剂检验.png", replace width(1200)
drop pc1

* ── 5.2 排除省会/核心城区（历下区、市中区等济南主城区）────
* 济南主城区编码前缀：3701
eststo robust1: xtreg digital_lit did $controls ///
    if !inrange(county_id, 370102, 370115), fe robust

* ── 5.3 对数被解释变量（已在主效应m3中呈现，此处单独输出）──
eststo robust2: xtreg ln_digital_lit did $controls, fe robust

esttab robust1 robust2 using "C:\Users\Administrator\Desktop\稳健性检验.rtf", ///
    b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(did) ///
    title("表6 稳健性检验") ///
    mtitles("排除省会城区" "对数被解释变量") ///
    stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) ///
    replace

/*===========================================================
  完成提示
===========================================================*/
di as result "======================================"
di as result " 所有实证分析已完成，结果文件保存至桌面："
di as result "  描述性统计.rtf"
di as result "  主效应DID.rtf"
di as result "  平行趋势检验.rtf  /  平行趋势图.png"
di as result "  机制检验.rtf"
di as result "  异质性检验.rtf"
di as result "  稳健性检验.rtf  /  安慰剂检验.png"
di as result "======================================"
