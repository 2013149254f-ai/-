/*==============================================================
  山东数字乡村DID实证分析 - 复现版
  使用说明：
    只需修改下方第7行的路径，改成你的xlsx文件所在文件夹
    然后全选运行即可
==============================================================*/

global path "C:\Users\你的用户名\Desktop"

/* ---- 以下无需修改 ---------------------------------------- */

clear all
set more off
capture log close
cd "$path"

* 安装依赖包（已安装则跳过）
capture which estout
if _rc ssc install estout, replace
capture which coefplot
if _rc ssc install coefplot, replace

* 导入数据
import excel "山东DID中文.xlsx", sheet("完整面板数据") cellrange(A4:AJ3200) firstrow clear

* 重命名变量
rename (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE AF AG AH AI AJ) (county_name county_id year treat pilot_year post did rel_year digital_lit ln_digital_lit infra_index digital_econ human_cap high_hc did_hc elderly_ratio gdp_pc urban_rate fiscal_agri industry_upg telecom finance_dev farmer_inc lead3 lead2 event0 lag1 lag2 lag3plus sim_flag cx1 cx2 cx3 cx4 cx5 cx6)

* 转为数值型
destring county_id year treat post did rel_year digital_lit ln_digital_lit infra_index digital_econ human_cap high_hc did_hc elderly_ratio gdp_pc urban_rate fiscal_agri industry_upg telecom finance_dev farmer_inc lead3 lead2 event0 lag1 lag2 lag3plus cx1 cx2 cx3 cx4 cx5 cx6, replace ignore(",")

* 设置面板
xtset county_id year
global controls cx1 cx2 cx3 cx4 cx5 cx6

di "数据加载成功，共 `=_N' 条观测值"


/* ===========================================================
   一、描述性统计
=========================================================== */

eststo clear
estpost summarize digital_lit infra_index digital_econ human_cap elderly_ratio gdp_pc urban_rate fiscal_agri industry_upg telecom finance_dev farmer_inc
esttab using "描述性统计.rtf", cells("mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3)) count(fmt(0))") label title("表1 描述性统计") replace
di "描述性统计 完成"


/* ===========================================================
   二、主效应检验（H1）：双向固定效应DID
=========================================================== */

eststo m1: xtreg digital_lit did, fe robust
eststo m2: xtreg digital_lit did $controls, fe robust
eststo m3: xtreg ln_digital_lit did $controls, fe robust

esttab m1 m2 m3 using "主效应DID.rtf", b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(did $controls) title("表2 主效应DID回归结果（H1）") mtitles("基准" "加控制变量" "对数被解释变量") stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) replace
di "主效应检验 完成"


/* ===========================================================
   三、平行趋势检验（事件研究法）
=========================================================== */

eststo es: xtreg digital_lit lead3 lead2 event0 lag1 lag2 lag3plus $controls, fe robust

esttab es using "平行趋势检验.rtf", b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(lead3 lead2 event0 lag1 lag2 lag3plus) title("表3 平行趋势检验") mtitles("事件研究") stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) replace

coefplot es, keep(lead3 lead2 event0 lag1 lag2 lag3plus) vertical recast(connected) yline(0, lcolor(gray) lpattern(dash)) xline(3, lcolor(red) lpattern(dash)) xlabel(1 "前3期" 2 "前2期" 3 "前1期(基准)" 4 "当期" 5 "滞后1期" 6 "滞后2期" 7 "滞后3期+") xtitle("相对政策时点") ytitle("系数估计值") title("图1 平行趋势检验") ciopts(recast(rcap)) graphregion(color(white))
graph export "平行趋势图.png", replace width(1200)
di "平行趋势检验 完成"


/* ===========================================================
   四、机制检验（H2、H3）
=========================================================== */

eststo mech1_s1: xtreg infra_index did $controls, fe robust
eststo mech1_s2: xtreg digital_lit did infra_index $controls, fe robust
eststo mech2_s1: xtreg digital_econ did $controls, fe robust
eststo mech2_s2: xtreg digital_lit did digital_econ $controls, fe robust

esttab mech1_s1 mech1_s2 mech2_s1 mech2_s2 using "机制检验.rtf", b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(did infra_index digital_econ) title("表4 机制检验结果（H2、H3）") mtitles("基础设施(第一步)" "基础设施(第二步)" "数字经济(第一步)" "数字经济(第二步)") stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) replace
di "机制检验 完成"


/* ===========================================================
   五、异质性检验（H4）：高 vs 低人力资本
=========================================================== */

eststo het_low:   xtreg digital_lit did $controls if high_hc==0, fe robust
eststo het_high:  xtreg digital_lit did $controls if high_hc==1, fe robust
eststo het_inter: xtreg digital_lit did high_hc did_hc $controls, fe robust

esttab het_low het_high het_inter using "异质性检验.rtf", b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(did high_hc did_hc) title("表5 异质性检验结果（H4）") mtitles("低人力资本组" "高人力资本组" "交互项回归") stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) replace
di "异质性检验 完成"


/* ===========================================================
   六、稳健性检验
=========================================================== */

* 6.1 安慰剂检验（500次随机模拟）
set seed 12345
matrix placebo_coef = J(500, 1, .)

preserve
keep county_id treat
duplicates drop county_id, force
tempfile county_treat
save `county_treat'
restore

forvalues i = 1/500 {
    preserve
    merge m:1 county_id using `county_treat', keepusing(treat) nogen update
    tempvar rand_order
    gen `rand_order' = runiform()
    sort `rand_order'
    gen rand_treat = treat[_n]
    sort county_id year
    gen rand_did = rand_treat * post
    quietly xtreg digital_lit rand_did $controls, fe robust
    matrix placebo_coef[`i', 1] = _b[rand_did]
    restore
}

svmat placebo_coef, names(pc)
quietly xtreg digital_lit did $controls, fe robust
local true_coef = _b[did]

twoway (histogram pc1, bin(40) color(ltblue) freq) (pci 0 `true_coef' 50 `true_coef', lcolor(red) lwidth(medthick)), legend(order(1 "安慰剂系数分布" 2 "真实DID系数")) xtitle("系数估计值") ytitle("频次") title("图2 安慰剂检验（500次随机模拟）") graphregion(color(white))
graph export "安慰剂检验.png", replace width(1200)
drop pc1

* 6.2 排除济南主城区
eststo robust1: xtreg digital_lit did $controls if !inrange(county_id, 370102, 370115), fe robust

* 6.3 对数被解释变量
eststo robust2: xtreg ln_digital_lit did $controls, fe robust

esttab robust1 robust2 using "稳健性检验.rtf", b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) keep(did) title("表6 稳健性检验") mtitles("排除省会城区" "对数被解释变量") stats(N r2_within, fmt(0 3) labels("观测值" "组内R²")) replace
di "稳健性检验 完成"


/* ===========================================================
   完成
=========================================================== */
di as result "全部分析完成！输出文件已保存至：$path"
di as result "  表格：描述性统计.rtf  主效应DID.rtf  平行趋势检验.rtf  机制检验.rtf  异质性检验.rtf  稳健性检验.rtf"
di as result "  图片：平行趋势图.png  安慰剂检验.png"
