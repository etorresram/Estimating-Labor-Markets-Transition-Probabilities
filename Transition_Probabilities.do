clear all
set memory 1400M 
set more off

**************************************************************************************
***  Estimating Labor Markets Transition Probabilities in Brazil using the PNADC   ***
**************************************************************************************

* Author: Eric Torres
* E-mail: etorresram@gmail.com



global dict= "D:\Transiciones\data_orig\PNADc"
global data_orig = "D:\Transiciones\data_orig\PNADc\in"
global data_final = "D:\Transiciones\data_orig\PNADc\out"



* Converting dictionaries from txt to dta
*****************************************

    foreach x in 01 02 03 04 {
	    forvalues i = 2012/2022{
	    
	    cap noi infile using "$dict\dict_pnadc.txt", using ("$data_orig\PNADC_`x'`i'.txt") clear
		cap noi save "$data_orig\PNADC_`x'`i'.dta", replace
}	
}


* Creating houseold and individual Ids
***************************************

    foreach x in 01 02 03 04 {
	    forvalues i = 2012/2022{
			
			cap noi use "$data_orig\PNADC_`x'`i'.dta", clear
			cap noi egen hous_id = concat(UPA V1008 V1014), format(%14.0g)
			cap noi destring hous_id, replace
			cap noi egen ind_id = concat(UPA V1008 V1014 V2003), format(%16.0g)
			cap noi destring ind_id, replace
			cap noi save "$data_orig\a_PNADC_`x'`i'.dta", replace
}	
}


* Append all databases
***********************

use "$data_orig\PNADC_012012.dta", clear
    foreach x in 01 02 03 04 {
	    forvalues i = 2012/2022{
			cap noi append using "$data_orig\a_PNADC_`x'`i'.dta", force
			cap noi save "$data_orig\PNADC_panel_v1.dta", replace
}	
}
drop if Ano==2012 & Trimestre==1 /*The first quarter of 2012 was repeated*/
append using "$data_orig\a_PNADC_012012.dta", force
sort Ano Trimestre UF Capital RM_RIDE UPA Estrato V1008 V1014
save "$data_orig\PNADC_panel_v1.dta", replace


* Dividing panels
********************

forvalues i = 1/10 {
	use "$data_orig\PNADC_panel_v1.dta", clear
	keep if V1014==`i'
	save "$data_orig\PNADC_panel_`i'.dta", replace
	
}


/*_______________________________________________________________________*/
/*___Applying the panel identification with the Ribas e Soares method____*/
/*_______________________________________________________________________*/

* https://repositorio.ipea.gov.br/bitstream/11058/1522/1/TD_1348.pdf

foreach x in 1 2 3 4 5 6 7 8 9 10 {
	
	use "$data_orig\PNADC_panel_`x'.dta", clear
	

	   gen painel =.
		/*Ribas and Soares Algorithm*/
		****************************************************************
		* Panel variables
		****************************************************************
		*defining the first interview
		egen id_dom = group(UPA V1008 V1014)
		egen id_chefe=  group(UPA V1008 V1014 V2005)
		replace id_chefe=. if V2005~=1
		sort id_chefe id_dom Ano Trimestre
		bysort id_chefe: gen n_p_aux = _n
		replace n_p_aux=. if V2005~=1
		bysort id_dom Ano Trimestre: egen n_p = mean(n_p_aux)
		tab n_p, m
		
		* Identification variable of the person in the panel
		g p201 = V2003 if n_p == 1 /* defined based on the 1st interview */
		* Variables that identify the matching
		g back = . /* with a previous interview */
		g forw = . /* with a subsequent interview */
		
		****************************************************************
		* Matching - 1st loop
		****************************************************************
		* Matching for each pair of interviews at a time
		forvalues i = 1/4 {
			****************************************************************
			* Standard matching - if the birth date is correct
			****************************************************************
			* Sorting each individual by interview period (quarter)
			sort UF UPA V1008 V1014 V2007 V2008 V20081 V20082 Ano Trimestre V2003 	
			* Loop to search for the same person in a previous position
			loc j = 1 /* j determines the previous position in the dataset */
			loc stop = 0 /* if stop=1, the loop stops */
			loc count = 0
			while `stop' == 0 {
				loc lastcount = `count'
				count if p201 == . & n_p == `i'+1 /* unmatched observations */
				loc count = r(N)
				if `count' == `lastcount' {
				* Stop if the loop is no longer matching
					loc stop = 1
				}
				else {
					if r(N) != 0 {
						* Capturing the p201 identification from the previous observation
						replace p201 = p201[_n - `j'] if /*
							household identification
							*/ UF == UF[_n - `j'] & ///
							UPA == UPA[_n - `j'] & ///
							V1008 == V1008[_n - `j'] & ///
							V1014 == V1014[_n - `j'] & /*
							differences between periods */ n_p == `i'+1 & n_p[_n - `j'] == `i' /*
							exclude already matched */ & p201 ==. & forw[_n - `j'] != 1 & /*
							Individual characteristics: Sex */ V2007 == V2007[_n - `j'] & /*
							Day of birth */ V2008 == V2008[_n - `j'] & /*
							Month of birth */ V20081 == V20081[_n - `j'] & /*
							Year of birth */ V20082 == V20082[_n - `j'] & /*
							Observed information */ V2008!=99 & V20081!=99 & V20082!=9999
						* matching identification for the one ahead
						replace forw = 1 if UF == UF[_n + `j'] & ///
							UPA == UPA[_n + `j'] & ///
							V1008 == V1008[_n + `j'] & ///
							V1014 == V1014[_n + `j'] & ///
							p201 == p201[_n + `j'] & ///
							n_p == `i' & n_p[_n + `j']==`i'+1 ///
							& forw != 1
						loc j = `j' + 1 /* moving to the next observation */
					}
					else {
						* Stop if there are no observations to match
						loc stop = 1
					}
				}
			}
			* Recoding matching identification variables
			replace back = p201 !=. if n_p == `i'+1
			replace forw = 0 if forw != 1 & n_p == `i'
		
	
			****************************************************************
			* Advanced matching
			****************************************************************
			* If sex and birth year do not match
			* Isolating already matched observations
			tempvar aux
			g `aux' = (forw==1 & (n_p==1 | back==1)) | (back==1 & n_p==5)
			* Sorting each individual by interview quarter
			sort `aux' UF UPA V1008 V1014 V2007 V2008 V20081 V2003 Ano Trimestre 
			* Loop to search for the same person in a previous position
			loc j = 1 /* j determines the previous position in the dataset */
			loc stop = 0 /* if stop=1, the loop stops */
			loc count = 0
			while `stop' == 0 {
				loc lastcount = `count'
				count if p201 == . & n_p == `i'+1 /* unmatched observations */
				loc count = r(N)
				if `count' == `lastcount' {
				* Stop if the loop is no longer matching
					loc stop = 1
				}
				else {
					if r(N) != 0 {
						* Capturing the p201 identification from the previous observation
						replace p201 = p201[_n - `j'] if /*
							household identification
							*/ UF == UF[_n - `j'] & ///
							UPA == UPA[_n - `j'] & ///
							V1008 == V1008[_n - `j'] & ///
							V1014 == V1014[_n - `j'] & /*
							difference between periods */ n_p == `i'+1 & n_p[_n - `j'] == `i' /*
							exclude already matched */ & p201 ==. & forw[_n - `j'] != 1 & /*
							Individual characteristics: Day of birth */ V2008 == V2008[_n - `j'] & /*
							Month of birth */ V20081 == V20081[_n - `j'] & /*
							Same order number */ V2003 == V2003[_n - `j'] & /*
							Observed information */ V2008!=99 & V20081!=99
						* matching identification for the one ahead
						replace forw = 1 if UF == UF[_n + `j'] & ///
							UPA == UPA[_n + `j'] & ///
							V1008 == V1008[_n + `j'] & ///
							V1014 == V1014[_n + `j'] & ///
							p201 == p201[_n + `j'] & ///
							n_p == `i' & n_p[_n + `j']==`i'+1 ///
							& forw != 1
						loc j = `j' + 1 /* moving to the next observation */
					}

					else {
						* Stop if there are no observations to match
						loc stop = 1
					}
				}
			}
			****************************************************************
			* Advanced matching
			****************************************************************
			* Only for heads, spouses, and adult children
			tempvar ager aux
			* Function for error in the presumed age
			g `ager' = cond(V2009>=25 & V2009<999, exp(V2009/30), 2)
			* Isolating already matched observations
			g `aux' = (forw==1 & (n_p==1 | back==1)) | (back==1 & n_p==5)
			* Sorting each family by interview period (quarter)
			sort `aux' UF UPA V1008 V1014 V2007 Ano Trimestre V2009 VD3004 V2003 
			* Loop to search for the same person in a previous position
			loc j = 1
			loc stop = 0
			loc count = 0
			while `stop' == 0 {
				loc lastcount = `count'
				count if p201==. & n_p==`i'+1 & ///
				(V2005<=3 | (V2005==4 & V2009>=25 ///
				& V2009<999)) /* unmatched observations */
				loc count = r(N)
				if `count' == `lastcount' {
					loc stop = 1
				}
				else {
					if r(N) != 0 {
						replace p201 = p201[_n - `j'] if /*
							household identification
							*/ UF == UF[_n - `j'] & ///
							UPA == UPA[_n - `j'] & ///
							V1008 == V1008[_n - `j'] & ///
							V1014 == V1014[_n - `j'] & /*
							difference between periods */ n_p == `i'+1 & n_p[_n - `j'] == `i' /*
							exclude already matched */ & p201 ==. & forw[_n - `j'] != 1 & /*
							Individual characteristics: Sex */ V2007 == V2007[_n - `j'] & /*
							Age difference */ abs(V2009 - V2009[_n - `j'])<=`ager' & /*
							Observed age */ V2009!=999 & /*
							If head or spouse */ ((V2005<=3 & V2005[_n - `j']<=3) | /*
							or child older than 25 */ (V2009>=25 & V2009[_n - `j']>=25 & ///
							V2005==4 & V2005[_n - `j']==4)) & /*
							Up to 4 days error in the date */ ((abs(V2008 - V2008[_n - `j'])<=4 & /*
							Up to 2 months error in the date*/ abs(V20081 - V20081[_n - `j'])<=2 & /*
							Observed information */ V2008!=99 & V20081!=99) /*
							or */ | /*
							1 cycle of error in education*/ (abs(VD3004 - VD3004[_n - `j'])<=1 /*
							and */ & /*
							Up to 2 months error in the date*/ ((abs(V20081 - V20081[_n - `j'])<=2 & /*
							Observed information */ V20081!=99 & /*
							Information not observed */ (V2008==99 | V2008[_n-`j']==99)) /*
							or */ | /*
							Up to 4 days error in the date */ (abs(V2008 - V2008[_n - `j'])<=4 & /*
							Observed information */ V2008!=99 & /*
							Information not observed */ (V20081==99 | V20081[_n - `j']==99)) /*
							or */ | /*
							information not observed */ ((V2008==99 | V2008[_n - `j']==99) & ///
							(V20081==99 | V20081[_n - `j']==99))))
						replace forw = 1 if UF == UF[_n + `j'] & ///
							UPA == UPA[_n + `j'] & ///
							V1008 == V1008[_n + `j'] & ///
							V1014 == V1014[_n + `j'] & ///
							p201 == p201[_n + `j'] & ///
							n_p == `i' & n_p[_n + `j']==`i'+1 ///
							& forw != 1
						loc j = `j' + 1
					}
					else {
						loc stop = 1
					}
				}
			}
			replace back = p201 !=. if n_p == `i'+1
			replace forw = 0 if forw != 1 & n_p == `i'
		
			****************************************************************
			* Advanced matching
			****************************************************************
			* Only in households where someone has already been matched
			* Number of people matched in the household
			tempvar dom
			bys Ano Trimestre UF UPA V1008 V1014: egen `dom' = sum(back)
			* Loop with the matching criteria
			foreach w in /*same age*/ "0" /*age error = 1*/ "1" /*
			age error = 2*/ "2" /*age error = f(age)*/ "`ager'" /*
			2xf(age)*/ "2*`ager' & V2009>=25" {
			* Isolating already matched observations
				tempvar aux
				g `aux' = (forw==1 & (n_p==1 | back==1)) | ///
				(back==1 & n_p==5) | (`dom'==0 & n_p==`i'+1)
				sort `aux' UF UPA V1008 V1014 V2007 Ano Trimestre V2009 ///
				VD3004 V2003
				loc j = 1
				loc stop = 0
				loc count = 0
				while `stop' == 0 {
					loc lastcount = `count'
					count if p201 == . & n_p == `i'+1 & `dom'>0 & `dom'!=.
					loc count = r(N)
					if `count' == `lastcount' {
						loc stop = 1
					}
					else {
						if r(N) != 0 {
							replace p201 = p201[_n - `j'] if /*
								household identification
								*/ UF == UF[_n - `j'] & ///
								UPA == UPA[_n - `j'] & ///
								V1008 == V1008[_n - `j'] & ///
								V1014 == V1014[_n - `j'] & /*
								difference between periods */ n_p == `i'+1 & n_p[_n-`j'] == `i' /*
								exclude already matched */ & p201 ==. & forw[_n - `j'] != 1 & /*
								already matched in the household*/ `dom' > 0 & `dom'!=. & /*
								Individual characteristics: Sex */ V2007 == V2007[_n - `j'] & /*
								Criteria change with the loop */ ((abs(V2009-V2009[_n - `j'])<=`w' & /*
								if the observed age */ V2009!=999) /*
								otherwise */ | /*
								Same education level */ (VD3004==VD3004[_n - `j'] & /*
								Same household condition */ V2005==V2005[_n - `j'] & /*
								Age not observed */ (V2009==999 | V2009[_n - `j']==999)))
							replace forw = 1 if UF == UF[_n + `j'] & ///
								UPA == UPA[_n + `j'] & ///
								V1008 == V1008[_n + `j'] & ///
								V1014 == V1014[_n + `j'] & ///
								p201 == p201[_n + `j'] & ///
								n_p ==`i' & n_p[_n+`j']==`i'+1 ///
								& forw != 1
							loc j = `j' + 1
						}
						else {
							loc stop = 1
						}
					}
				}
			}
			replace back = p201 !=. if n_p == `i'+1
			replace forw = 0 if forw != 1 & n_p == `i'
			* Identification for those who were absent in the last interview
			replace p201 = `i'00 + V2003 if p201 == . & n_p == `i'+1
		}
	
		****************************************************************
		* Recover those who left and returned to the panel - 2nd loop
		****************************************************************
		* Temporary variable identifying the matching ahead
		tempvar fill
		g `fill' = forw
		* Retrospective loop by interview
		foreach i in 4 3 2 1 {
			tempvar ncode1 ncode2 aux max ager
			* Function for error in the presumed age
			g `ager' = cond(V2009>=25 & V2009<999, exp(V2009/30), 2)
			* Variable that preserves the old number
			bys UF UPA V1008 V1014 p201: g `ncode1' = p201
			* Isolating matched observations
			g `aux' = ((`fill'==1 & (n_p==1 | back==1)) | (back==1 & n_p==5))
			* Variable identifying the next interview
			bys UF UPA V1008 V1014 p201: egen `max' = max(n_p)
			sort `aux' UF UPA V1008 V1014 V2007 n_p V2003 p201
			loc j = 1
			loc stop = 0
			loc count = 0
			while `stop' == 0 {
				loc lastcount = `count'
				count if p201>`i'00 & p201<`i'99 & back==0
				loc count = r(N)
				if `count' == `lastcount' {
					loc stop = 1
				}
				else {
					if r(N) != 0 {
						replace p201 = p201[_n - `j'] if /*
							household identification
							*/ UF == UF[_n - `j'] & ///
							UPA == UPA[_n - `j'] & ///
							V1008 == V1008[_n - `j'] & ///
							V1014 == V1014[_n - `j'] & /*
							Who entered interview i*/ p201>`i'00 & p201<`i'99 & /*
							not matched */ back==0 & `fill'[_n - `j']!=1 & /*
							One interview difference*/ `max'[_n - `j']<`i' & ///
							p201[_n - `j']<`i'00-100 & /*
							Sex */ V2007 == V2007[_n - `j'] & /*
							Age difference */ ((abs(V2009 - V2009[_n - `j'])<=`ager' & /*
							Observed age */ V2009!=999 & /*
							Up to 4 days error in the date */ ((abs(V2008 - V2008[_n - `j'])<=4 & /*
							Up to 2 months error in the date*/ abs(V20081 - V20081[_n - `j'])<=2 & /*
							Observed information */ V2008!=99 & V20081!=99) /*
							or */ | /*
							1 cycle of error in education*/ (abs(VD3004 - VD3004[_n - `j'])<=1 /*
							and */ & /*
							Up to 2 months error in the date*/ ((abs(V20081 - V20081[_n - `j'])<=2 & /*
							Observed information */ V20081!=99 & /*
							Information not observed */ (V2008==99 | V2008[_n - `j']==99)) /*
							or */ | /*
							Up to 4 days error in the date */ (abs(V2008 - V2008[_n - `j'])<=4 & /*
							Observed information */ V2008!=99 & /*
							Information not observed */ (V20081==99 | V20081[_n - `j']==99)) /*
							or */ | /*
							nothing observed */ ((V2008==99 | V2008[_n - `j']==99) & ///
							(V20081==99 | V20081[_n - `j']==99))))
						* matching identification for the one ahead
						replace `fill' = 1 if UF == UF[_n + `j'] & ///
							UPA == UPA[_n + `j'] & ///
							V1008 == V1008[_n + `j'] & ///
							V1014 == V1014[_n + `j'] & ///
							p201 == p201[_n + `j'] & ///
							`fill' == 0 & `max'<`i' & ///
							(n_p[_n + `j'] - n_p)>=2
						loc j = `j' + 1
					}
					else {
						loc stop = 1
					}
				}
			}
			* Equalizing the number of those who were the same
			bys UF UPA V1008 V1014 `ncode1': egen `ncode2' = min(p201)
			replace p201 = `ncode2'
		}
	tempvar a b c d
	tostring UF, g(`a')
	tostring UPA, g(`b') format(%09.0f)
	tostring V1008, g(`c') format(%03.0f)
	tostring p201, g(`d') format(%03.0f)
	egen idind = concat(V1014 `a' `b' `c' `d')
	replace idind = "" if p201 ==.
	*replace idind = "" if V2008==99 | V20081==99 | V20082==9999
	lab var idind "identificacao do individuo"
	drop __* back forw hous_id ind_id id_dom id_chefe n_p_aux n_p p201
	
	save "$data_orig\PNADC_panel_`x'_rs.dta", replace

	}

	
	
use "$data_orig\PNADC_panel_1_rs.dta", replace
foreach x in 2 3 4 5 6 7 8 9 {
    append using "$data_orig\PNADC_panel_`x'_rs.dta", force
	save "$data_orig\PNADC_panel_v1_rs.dta", replace
}
	
sort Ano Trimestre UF Capital RM_RIDE UPA Estrato V1008 V1014	
save "$data_orig\PNADC_panel_v1_rs.dta", replace
	
	

foreach x in pea npea ocu desoc empleado empleador cpropia familiar emp_privado emp_domestico emp_publico empleador2 cpropia2 familiar2 com_carteira sim_carteira {
    gen `x'=.
}
	
gen seqnum=_n
rename seqnum n 

gen grupos=.
replace grupos=1 if n>=1 & n<=8548311
replace grupos=2 if n>=8548312 & n<=9678114
replace grupos=3 if n>=9678115
save, replace

foreach x in 1 2 3 {
    use "$data_orig\PNADC_panel_v1_rs.dta", clear
	keep if grupos==`x'
	save "$data_orig\PNADC_panel_v1_grupo`x'_rs.dta", replace	
}

	
	
***********************************************************
****    Harmonizing labor and education variables     *****
***********************************************************
	
	
***********	
* GROUP 1 *
***********
*From January 2012 to September 2015

use "$data_orig\PNADC_panel_v1_grupo1_rs.dta", clear


* Labor *  
gen pea=1 if (V2009>=14 & V4009!=.) | (V2009>=04 & V4009==. & V4071==1 & V4072>=1 & V4072<=10 & V4077==1) | (V2009>=14 & V4009==. & V4071==1 & V4072==11 & V4073==1 & V4074==1 & V4077==1) | (V2009>=014 & V4009==. & V4071==2 & V4073==1 & V4074==1 & V4077==1)		

gen npea=1 if V2009>=14 & V4009==. & ((V4071==2 & V4073==2) | (V4071==2 & V4073==1 & V4074!=1) | (V4071==2 & V4073==1 & V4074==1 & V4077==2) | (V4071==1 & V4072>=1 & V4072<=10 & V4077==2) | (V4071==1 & V4072==11 & V4073==2) | (V4071==1 & V4072==11 & V4073==1 & V4074!=1) | (V4071==1 & V4072==11 & V4073==1 & V4074==1 & V4077==2))	
	
gen ocu=1 if V2009>=14 & V4009!=.	
gen desoc=1 if V2009>=14 & V4009==. & ((V4071==1 & V4072>=1 & V4072<=10 & V4077==1) | (V4071==1 & V4072==11 & V4073==1 & V4074==1 & V4077==1) | (V4071==2 & V4073==1 & V4074==1 & V4077==1))

gen empleado=1 if V2009>=14 & V4009!=. & V4012>=1 & V4012<=4 
gen empleador=1 if V2009>=14 & V4009!=. & V4012==5
gen cpropia=1 if V2009>=14 & V4009!=. & V4012==6
gen familiar=1 if V2009>=14 & V4009!=. & V4012==7

gen emp_privado=1 if V2009>=14 & V4009!=. & V4012==3
gen emp_domestico=1 if V2009>=14 & V4009!=. & V4012==1
gen emp_publico=1 if V2009>=14 & V4009!=. & (V4012==4 | V4012==2)
gen empleador2=1 if V2009>=14 & V4009!=. & V4012==5
gen cpropia2=1 if V2009>=14 & V4009!=. & V4012==6
gen familiar2=1 if V2009>=14 & V4009!=. & V4012==7

gen com_carteira=1 if V2009>=14 & V4009!=. & V4012==3 & V4029==1
gen sim_carteira=1 if V2009>=14 & V4009!=. & V4012==3 & V4029==2

gen com_carteira_dom=1 if V2009>=14 & V4009!=. & V4012==1 & V4029==1
gen sim_carteira_dom=1 if V2009>=14 & V4009!=. & V4012==1 & V4029==2




* Education *
gen aedu_ci=0 if ((V3002==2 & V3008==2) | (V3003>=1 & V3003<=2) | (V3003==3 & V3004==2 & V3005==2) | (V3003==3 & V3004==2 & V3006==1) | ((V3009>=1 & V3009<=2) & V3014==2) | (V3009==5 & V3010==2 & V3011==2 & V3014==2) | (V3009==5 & V3010==2 & V3012==2))
replace aedu_ci=1 if ((V3003==3 & V3004==1 & V3005==2) | (V3003==3 & V3004==1 & V3006==1) | (V3003==3 & V3004==2 & V3006==2) | (V3003==4 & V3005==2) | (V3003==4 & V3006==1) | ((V3009>=1 & V3009<=2) & V3014==1) | ((V3009==3 | V3009==6) & V3012==2) | (V3009==5 & V3010==1 & V3011==2 & V3014==2) | (V3009==5 & V3010==1 & V3012==2) | (V3009==5 & V3010==2 & V3013==1) | (V3009==6 & V3011==2 & V3014==2))
replace aedu_ci=2 if ((V3003==3 & V3004==1 & V3006==2) | (V3003==3 & V3004==2 & V3006==3) | (V3003==4 & V3006==2) | ((V3009==3 | V3009==6) & V3013==1) | (V3009==5 & V3010==1 & V3013==1) | (V3009==5 & V3010==2 & V3013==2))
replace aedu_ci=3 if ((V3003==3 & V3004==1 & V3006==3) | (V3003==3 & V3004==2 & V3006==4) | (V3003==4 & V3006==3) | ((V3009==3 | V3009==6) & V3013==2) | (V3009==5 & V3010==1 & V3013==2) | (V3009==5 & V3010==2 & V3013==3))
replace aedu_ci=4 if ((V3003==3 & V3004==1 & V3006==4) | (V3003==3 & V3004==2 & V3006==5) | (V3003==4 & V3006==4) | ((V3009==3 | V3009==6) & V3013==3) | (V3009==5 & V3010==1 & V3013==3) | (V3009==5 & V3010==2 & V3013==4))
replace aedu_ci=5 if ((V3003==3 & V3004==1 & V3006==5) | (V3003==3 & V3004==2 & V3006==6) | (V3003==4 & V3006==5) | ((V3009==3 | V3009==6) & V3013==4) | (V3009==4 & V3011==2 & V3014==2) | (V3009==4 & V3012==2) | (V3009==5 & V3010==1 & V3013==4) | (V3009==5 & V3010==2 & V3013==5))
replace aedu_ci=6 if ((V3003==3 & V3004==1 & V3006==6) | (V3003==3 & V3004==2 & V3006==7) | (V3003==4 & V3006==6) | ((V3009==3 | V3009==6) & V3013==5) | (V3009==4 & V3013==1) | (V3009==5 & V3010==1 & V3013==5) | (V3009==5 & V3010==2 & V3013==6))
replace aedu_ci=7 if ((V3003==3 & V3004==1 & V3006==7) | (V3003==3 & V3004==2 & V3006==8) | (V3003==4 & V3006==7) | ((V3009==3 | V3009==6) & V3013==6) | (V3009==4 & V3013==2) | (V3009==5 & V3010==1 & V3013==6) | (V3009==5 & V3010==2 & V3013==7))
replace aedu_ci=8 if ((V3003==3 & V3004==1 & V3006==8) | (V3003==3 & V3004==2 & V3006==9) | (V3003==4 & V3006==8) | (V3009==4 & V3013==3) | (V3009==5 & V3010==1 & V3013==7) | (V3009==5 & V3010==2 & V3013==8) | (V3009==6 & V3013==7))
replace aedu_ci=9 if (((V3003>=5 & V3003<=6) & V3005==2) | ((V3003>=5 & V3003<=6) & V3006==1) | ((V3009>=4 & V3009<=6) & V3011==2 & V3014==1) | (V3009==4 & V3013==4) | (V3009==5 & V3010==1 & V3013==8) | (V3009==5 & V3010==2 & V3013==9) | (V3009==6 & V3013==8) | ((V3009>=7 & V3009<=9) & V3011==2 & V3014==2) | ((V3009>=7 & V3009<=9) & V3012==2))
replace aedu_ci=10 if (((V3003>=5 & V3003<=6) & V3006==2) | (V3009==4 & V3013==5) | ((V3009>=7 & V3009<=9) & V3013==1))
replace aedu_ci=11 if (((V3003>=5 & V3003<=6) & V3006==3) | ((V3009>=7 & V3009<=9) & V3013==2))
replace aedu_ci=12 if ((V3003==5 & V3006==4) | (V3003==7 & V3006==1 & V3007==2) | ((V3009>=7 & V3009<=9) & V3011==2 & V3014==1) | ((V3009>=7 & V3009<=9) & V3013==3) | (V3009==10 & V3012==2))
replace aedu_ci=13 if ((V3003==7 & V3006==2 & V3007==2) | ((V3009>=7 & V3009<=8) & V3013==4) | (V3009==10 & V3013==1))
replace aedu_ci=14 if ((V3003==7 & (V3006>=1 & V3006<=3) & V3007==1 & V3013==2) | (V3003==7 & V3006==3 & V3007==2) | (V3009==10 & V3013==2))
replace aedu_ci=15 if ((V3003==7 & (V3006>=1 & V3006<=4) & V3007==1 & V3013==3) | (V3003==7 & V3006==4 & V3007==1 & (V3013>=2 & V3013<=3)) | (V3003==7 & V3006==4 & V3007==2) | (V3009==10 & V3013==3))
replace aedu_ci=16 if ((V3003==7 & (V3006>=1 & V3006<=4) & V3007==1 & (V3013>=4 & V3013<=6)) | (V3003==7 & (V3006>=5 & V3006<=6)) | (V3003>=8 & V3003<=9) | (V3009==10 & (V3013>=4 & V3013<=6)) | (V3009>=11 & V3009<=12))

save "$data_orig\PNADC_panel_v1_grupo1_rs.dta", replace
    		

			
	
	
***********	
* GROUP 2 *
***********
*From October 2015 to March 2016

use "$data_orig\PNADC_panel_v1_grupo2_rs.dta", clear

* Labor *
gen pea=1 if (V2009>=14 & V4009!=.) | (V2009>=14 & V4009==. & V4071==1 & V4072A>=1 & V4072A<=8 & V4077==1) | (V2009>=14 & V4009==. & V4071==1 & V4072A==9 & V4073==1 & V4074A==1 & V4077==1 ) | (V2009>=14 & V4009==. & V4071==2 & V4073==1 & V4074A==1 & V4077==1)	

gen npea=1 if V2009>=14 & V4009==. & ((V4071==2 & V4073==2) | (V4071==2 & V4073==1 & V4074A!= 1) | (V4071==2 & V4073==1 & V4074A==1 & V4077==2) | (V4071==1 & V4072A>=1 & V4072A<=8 & V4077==2 ) | (V4071==1 & V4072A==9 & V4073==2 ) | (V4071==1 & V4072A==9 & V4073==1 & V4074A!=1 ) | (V4071==1 & V4072A==9 & V4073==1 & V4074A==1 & V4077==2))

gen ocu=1 if V2009>=14 & V4009!=.

gen desoc=1 if V2009>=14 & V4009==. & ((V4071==1 & (V4072A>=1 & V4072A<=8) & V4077==1) | (V4071==1 & V4072A==9 & V4073==1 & V4074A==1 & V4077==1) | (V4071==2 & V4073==1 & V4074A==1 & V4077==1))	

gen empleado=1 if V2009>=14 & V4009!=. & V4012>=1 & V4012<=4 
gen empleador=1 if V2009>=14 & V4009!=. & V4012==5
gen cpropia=1 if V2009>=14 & V4009!=. & V4012==6
gen familiar=1 if V2009>=14 & V4009!=. & V4012==7

gen emp_privado=1 if V2009>=14 & V4009!=. & V4012==3
gen emp_domestico=1 if V2009>=14 & V4009!=. & V4012==1
gen emp_publico=1 if V2009>=14 & V4009!=. & (V4012==4 | V4012==2)
gen empleador2=1 if V2009>=14 & V4009!=. & V4012==5
gen cpropia2=1 if V2009>=14 & V4009!=. & V4012==6
gen familiar2=1 if V2009>=14 & V4009!=. & V4012==7
	
gen com_carteira=1 if V2009>=14 & V4009!=. & V4012==3 & V4029==1
gen sim_carteira=1 if V2009>=14 & V4009!=. & V4012==3 & V4029==2

gen com_carteira_dom=1 if V2009>=14 & V4009!=. & V4012==1 & V4029==1
gen sim_carteira_dom=1 if V2009>=14 & V4009!=. & V4012==1 & V4029==2




* Education *
gen aedu_ci=0 if ((V3002==2 & V3008==2)| (V3003A>=1 & V3003A<=3) | (V3003A==4 & V3004==2 & (V3006==1 | V3006==13)) | (V3009A>=1 & V3009A<=2) | ((V3009A>=3 & V3009A<=4) & V3014==2) | (V3009A==7 & V3010==2 & V3012==2) | (V3009A==7 & V3010==2 & V3012==3 & V3014==2)) 
replace aedu_ci=1 if ((V3003A==4 & V3004==1 & (V3006==1 | V3006==13)) | (V3003A==4 & V3004==2 & V3006==2) | (V3003A==5 & (V3006==1 | V3006==13)) | ((V3009A>=3 & V3009A<=4) & V3014==1) | ((V3009A==5 | V3009A==8) & V3012==2) | (V3009A==7 & V3010==1 & V3012==2) | (V3009A==7 & V3010==1 & V3012==3 & V3014==2) | (V3009A==7 & V3010==2 & V3013==1) | (V3009A==8 & V3012==3 & V3014==2)) 
replace aedu_ci=2 if ((V3003A==4 & V3004==1 & V3006==2) | (V3003A==4 & V3004==2 & V3006==3) | (V3003A==5 & V3006==2) | ((V3009A==5 | V3009A==8) & V3013==1) | (V3009A==7 & V3010==1 & V3013==1) | (V3009A==7 & V3010==2 & V3013==2))
replace aedu_ci=3 if ((V3003A==4 & V3004==1 & V3006==3) | (V3003A==4 & V3004==2 & V3006==4) | (V3003A==5 & V3006==3) | ((V3009A==5 | V3009A==8) & V3013==2) | (V3009A==7 & V3010==1 & V3013==2) | (V3009A==7 & V3010==2 & V3013==3)) 
replace aedu_ci=4 if ((V3003A==4 & V3004==1 & V3006==4) | (V3003A==4 & V3004==2 & V3006==5) | (V3003A==5 & V3006==4) | ((V3009A==5 | V3009A==8) & V3013==3) | (V3009A==7 & V3010==1 & V3013==3) | (V3009A==7 & V3010==2 & V3013==4)) 
replace aedu_ci=5 if ((V3003A==4 & V3004==1 & V3006==5) | (V3003A==4 & V3004==2 & V3006==6) | (V3003A==5 & V3006==5) | ((V3009A==5 | V3009A==8) & V3013==4) | (V3009A==6 & V3012==2) | (V3009A==6 & V3012==3 & V3014==2) | (V3009A==7 & V3010==1 & V3013==4) | (V3009A==7 & V3010==2 & V3013==5))
replace aedu_ci=6 if ((V3003A==4 & V3004==1 & V3006==6) | (V3003A==4 & V3004==2 & V3006==7) | (V3003A==5 & V3006==6) | ((V3009A==5 | V3009A==8) & V3013==5) | (V3009A==6 & V3013==1) | (V3009A==7 & V3010==1 & V3013==5) | (V3009A==7 & V3010==2 & V3013==6)) 
replace aedu_ci=7 if ((V3003A==4 & V3004==1 & V3006==7) | (V3003A==4 & V3004==2 & V3006==8) | (V3003A==5 & V3006==7) | ((V3009A==5 | V3009A==8) & V3013==06) | (V3009A==6 & V3013==2) | (V3009A==7 & V3010==1 & V3013==6) | (V3009A==7 & V3010==2 & V3013==7)) 
replace aedu_ci=8 if ((V3003A==4 & V3004==1 & V3006==8) | (V3003A==4 & V3004==2 & V3006==9) | (V3003A==5 & V3006==8) | (V3009A==6 & V3013==3) | (V3009A==7 & V3010==1 & V3013==7) | (V3009A==7 & V3010==2 & V3013==8) | (V3009A==8 & V3013==7)) 
replace aedu_ci=9 if (((V3003A>=6 & V3003A<=7) & (V3006==1 | V3006==13)) | (V3009A==6 & V3012==3 & V3014==1) | ((V3009A>=6 & V3009A<=8) & V3012==3 & V3014==1) | (V3009A==6 & V3013==4) | (V3009A==7 & V3010==1 & V3013==8) | (V3009A==7 & V3010==2 & V3013==9) | (V3009A==8 & V3013==8) | ((V3009A>=9 & V3009A<=11) & V3012==2) | ((V3009A>=9 & V3009A<=11) & V3012==3 & V3014==2)) 
replace aedu_ci=10 if (((V3003A>=6 & V3003A<=7) & V3006==2) | (V3009A==6 & V3013==5) | ((V3009A>=9 & V3009A<=11) & V3013==1)) 
replace aedu_ci=11 if (((V3003A>=6 & V3003A<=7) & V3006==3) | ((V3009A>=9 & V3009A<=11) & V3013==2))
replace aedu_ci=12 if ((V3003A==6 & V3006==4) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=2) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==1 & V3007==2) | ((V3009A>=9 & V3009A<=11) & V3012==3 & V3014==1) | ((V3009A>=9 & V3009A<=11) & V3013==3) | (V3009A==12 & V3012==2) | (V3009A==12 & V3011A==1 & V3013==1))
replace aedu_ci=13 if ((V3003A==8 & V3005A==1 & (V3006>=3 & V3006<=4) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==2 & V3007==2) | ((V3009A>=9 & V3009A<=10) & V3013==4) | (V3009A==12 & V3011A==1 & (V3013>=2 & V3013<=3)) | (V3009A==12 & 2<=V3011A<=3 & V3013==1))
replace aedu_ci=14 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=6) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=6) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=3) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=3) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==2) | (V3003A==8 & V3005A==1 & (V3006>=5 & V3006<=6) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==3 & V3007==2) | (V3009A==12 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & V3013==2))
replace aedu_ci=15 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==3) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==3) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=7)) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=2 & V3013<=3)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=7)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=2 & V3013<=3)) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==2) | (V3009A==12 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & V3013==3))
replace aedu_ci=16 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3003A==8 & V3005A==1 & (V3006>=9 & V3006<=12)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=5 & V3006<=6)) | (V3003A>=9 & V3003A<=11) | (V3009A==12 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3009A>=13 & V3009A<=15))

save "$data_orig\PNADC_panel_v1_grupo2_rs.dta", replace






***********	
* GROUP 3 *
***********

use "$data_orig\PNADC_panel_v1_grupo3_rs.dta", clear

* From April 2016

* Labor *
gen pea=1 if (V2009>=14 & V4009!=.) | (V2009>=14 & V4009==. & ((V4071==1 & V4072A>=1 & V4072A<=8 & V4077==1) | (((V4071==1 & V4072A==9) | V4071==2) & V4073==1 & V4074A==1 & (V4075A==1 | (V4075A==2 & V4075A1>=1 & V4075A1<=3)) & V4077==1)))	

gen npea=1 if V2009>=14 & V4009==. & ((V4071==2 & V4073==2) | (V4071==2 & V4073==1 & V4074A!=1) | (V4071==2 & V4073==1 & V4074A==1 & (V4075A==1 | (V4075A==2 &  V4075A1>=1 & V4075A1<=3)) & V4077==2 ) | (V4071==2 & V4073==1 & V4074A==1 & ( (V4075A==2 & V4075A1>3) | (V4075A==3)))) | (V4071==1 & V4072A>=1 & V4072A<=8 & V4077==2) | (V4071==1 & V4072A==9 & V4073==2 ) | (V4071==1 & V4072A==9 & V4073==1 & V4074A!=1) | (V4071==1 & V4072A==9 & V4073==1 & V4074A==1 & ( (V4075A==2 & V4075A1>3) | (V4075A==3))) | (V4071==1 & V4072A==9 & V4073==1 & V4074A==1 & (V4075A==1 | (V4075A==2 & V4075A1>=1 & V4075A1<=3) & V4077==2))

gen ocu=1 if V2009>=14 & V4009!=.

gen desoc=1 if V2009>=14 & V4009==. & ((V4071==1 & V4072A>=1 & V4072A<=8 & V4077==1) | (V4071==1 & V4072A== 9 & V4073==1 & V4074A==1 & (V4075A==1 | (V4075A==2 & V4075A1>=1 & V4075A1<=3)) & V4077==1) | (V4071==2 & V4073==1 & V4074A==1 & (V4075A== 1 | (V4075A==2 & V4075A1>=1 & V4075A1<=3)) & V4077==1))

gen empleado=1 if V2009>=14 & V4009!=. & V4012>=1 & V4012<=4 
gen empleador=1 if V2009>=14 & V4009!=. & V4012==5
gen cpropia=1 if V2009>=14 & V4009!=. & V4012==6
gen familiar=1 if V2009>=14 & V4009!=. & V4012==7

gen emp_privado=1 if V2009>=14 & V4009!=. & V4012==3
gen emp_domestico=1 if V2009>=14 & V4009!=. & V4012==1
gen emp_publico=1 if V2009>=14 & V4009!=. & (V4012==4 | V4012==2)
gen empleador2=1 if V2009>=14 & V4009!=. & V4012==5
gen cpropia2=1 if V2009>=14 & V4009!=. & V4012==6
gen familiar2=1 if V2009>=14 & V4009!=. & V4012==7

gen com_carteira=1 if V2009>=14 & V4009!=. & V4012==3 & V4029==1
gen sim_carteira=1 if V2009>=14 & V4009!=. & V4012==3 & V4029==2

gen com_carteira_dom=1 if V2009>=14 & V4009!=. & V4012==1 & V4029==1
gen sim_carteira_dom=1 if V2009>=14 & V4009!=. & V4012==1 & V4029==2



* Education *
gen aedu_ci=.


* Before 2018
replace aedu_ci=0 if ((V3002==2 & V3008==2)| (V3003A>=1 & V3003A<=3) | (V3003A==4 & V3004==2 & (V3006==1 | V3006==13)) | (V3009A>=1 & V3009A<=2) | ((V3009A>=3 & V3009A<=4) & V3014==2) | (V3009A==7 & V3010==2 & V3012==2) | (V3009A==7 & V3010==2 & V3012==3 & V3014==2)) & Ano<2018 
replace aedu_ci=1 if ((V3003A==4 & V3004==1 & (V3006==1 | V3006==13)) | (V3003A==4 & V3004==2 & V3006==2) | (V3003A==5 & (V3006==1 | V3006==13)) | ((V3009A>=3 & V3009A<=4) & V3014==1) | ((V3009A==5 | V3009A==8) & V3012==2) | (V3009A==7 & V3010==1 & V3012==2) | (V3009A==7 & V3010==1 & V3012==3 & V3014==2) | (V3009A==7 & V3010==2 & V3013==1) | (V3009A==8 & V3012==3 & V3014==2)) & Ano<2018  
replace aedu_ci=2 if ((V3003A==4 & V3004==1 & V3006==2) | (V3003A==4 & V3004==2 & V3006==3) | (V3003A==5 & V3006==2) | ((V3009A==5 | V3009A==8) & V3013==1) | (V3009A==7 & V3010==1 & V3013==1) | (V3009A==7 & V3010==2 & V3013==2)) & Ano<2018 
replace aedu_ci=3 if ((V3003A==4 & V3004==1 & V3006==3) | (V3003A==4 & V3004==2 & V3006==4) | (V3003A==5 & V3006==3) | ((V3009A==5 | V3009A==8) & V3013==2) | (V3009A==7 & V3010==1 & V3013==2) | (V3009A==7 & V3010==2 & V3013==3)) & Ano<2018  
replace aedu_ci=4 if ((V3003A==4 & V3004==1 & V3006==4) | (V3003A==4 & V3004==2 & V3006==5) | (V3003A==5 & V3006==4) | ((V3009A==5 | V3009A==8) & V3013==3) | (V3009A==7 & V3010==1 & V3013==3) | (V3009A==7 & V3010==2 & V3013==4)) & Ano<2018  
replace aedu_ci=5 if ((V3003A==4 & V3004==1 & V3006==5) | (V3003A==4 & V3004==2 & V3006==6) | (V3003A==5 & V3006==5) | ((V3009A==5 | V3009A==8) & V3013==4) | (V3009A==6 & V3012==2) | (V3009A==6 & V3012==3 & V3014==2) | (V3009A==7 & V3010==1 & V3013==4) | (V3009A==7 & V3010==2 & V3013==5)) & Ano<2018 
replace aedu_ci=6 if ((V3003A==4 & V3004==1 & V3006==6) | (V3003A==4 & V3004==2 & V3006==7) | (V3003A==5 & V3006==6) | ((V3009A==5 | V3009A==8) & V3013==5) | (V3009A==6 & V3013==1) | (V3009A==7 & V3010==1 & V3013==5) | (V3009A==7 & V3010==2 & V3013==6)) & Ano<2018  
replace aedu_ci=7 if ((V3003A==4 & V3004==1 & V3006==7) | (V3003A==4 & V3004==2 & V3006==8) | (V3003A==5 & V3006==7) | ((V3009A==5 | V3009A==8) & V3013==06) | (V3009A==6 & V3013==2) | (V3009A==7 & V3010==1 & V3013==6) | (V3009A==7 & V3010==2 & V3013==7)) & Ano<2018  
replace aedu_ci=8 if ((V3003A==4 & V3004==1 & V3006==8) | (V3003A==4 & V3004==2 & V3006==9) | (V3003A==5 & V3006==8) | (V3009A==6 & V3013==3) | (V3009A==7 & V3010==1 & V3013==7) | (V3009A==7 & V3010==2 & V3013==8) | (V3009A==8 & V3013==7)) & Ano<2018  
replace aedu_ci=9 if (((V3003A>=6 & V3003A<=7) & (V3006==1 | V3006==13)) | (V3009A==6 & V3012==3 & V3014==1) | ((V3009A>=6 & V3009A<=8) & V3012==3 & V3014==1) | (V3009A==6 & V3013==4) | (V3009A==7 & V3010==1 & V3013==8) | (V3009A==7 & V3010==2 & V3013==9) | (V3009A==8 & V3013==8) | ((V3009A>=9 & V3009A<=11) & V3012==2) | ((V3009A>=9 & V3009A<=11) & V3012==3 & V3014==2)) & Ano<2018  
replace aedu_ci=10 if (((V3003A>=6 & V3003A<=7) & V3006==2) | (V3009A==6 & V3013==5) | ((V3009A>=9 & V3009A<=11) & V3013==1)) & Ano<2018 
replace aedu_ci=11 if (((V3003A>=6 & V3003A<=7) & V3006==3) | ((V3009A>=9 & V3009A<=11) & V3013==2)) & Ano<2018 
replace aedu_ci=12 if ((V3003A==6 & V3006==4) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=2) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==1 & V3007==2) | ((V3009A>=9 & V3009A<=11) & V3012==3 & V3014==1) | ((V3009A>=9 & V3009A<=11) & V3013==3) | (V3009A==12 & V3012==2) | (V3009A==12 & V3011A==1 & V3013==1)) & Ano<2018 
replace aedu_ci=13 if ((V3003A==8 & V3005A==1 & (V3006>=3 & V3006<=4) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==2 & V3007==2) | ((V3009A>=9 & V3009A<=10) & V3013==4) | (V3009A==12 & V3011A==1 & (V3013>=2 & V3013<=3)) | (V3009A==12 & 2<=V3011A<=3 & V3013==1)) & Ano<2018 
replace aedu_ci=14 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=6) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=6) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=3) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=3) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==2) | (V3003A==8 & V3005A==1 & (V3006>=5 & V3006<=6) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==3 & V3007==2) | (V3009A==12 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & V3013==2)) & Ano<2018 
replace aedu_ci=15 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==3) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==3) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=7)) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=2 & V3013<=3)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=7)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=2 & V3013<=3)) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==2) | (V3009A==12 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & V3013==3)) & Ano<2018 
replace aedu_ci=16 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3003A==8 & V3005A==1 & (V3006>=9 & V3006<=12)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=5 & V3006<=6)) | (V3003A>=9 & V3003A<=11) | (V3009A==12 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3009A>=13 & V3009A<=15)) & Ano<2018 


* After 2018    
replace aedu_ci=0 if ((V3002==2 & V3008==2) | (V3003A>=1 & V3003A<=3) | (V3003A==4 & V3006==1) | (V3003A==4 & V3006==13 & V3006A==1) | (V3009A>=1 & V3009A<=2) | ((V3009A>=3 & V3009A<=4) & V3014==2) | (V3009A==7 & V3010==2 & V3012==2) | (V3009A==7 & V3010==2 & V3012==3 & V3013A==1 & V3013B==2)) & Ano>=2018 
replace aedu_ci=1 if ((V3003A==4 & V3006==2) | (V3003A==5 & V3006==1) | (V3003A==5 & V3006==13 & V3006A==1) | ((V3009A>=3 & V3009A<=4) & V3014==1) | ((V3009A==5 | V3009A==8) & V3012==2) | (V3009A==7 & V3010==1 & V3012==2) | (V3009A==7 & V3010==1 & V3012==3 & V3013A==1 & V3013B==2) | (V3009A==7 & V3010==2 & V3013==1) | (V3009A==8 & V3012==3 & V3013A==1 & V3013B==2)) & Ano>=2018 
replace aedu_ci=2 if ((V3003A==4 & V3006==3) | (V3003A==5 & V3006==2) | ((V3009A==5 | V3009A==8) & V3013==1) | (V3009A==7 & V3010==1 & V3013==1) | (V3009A==7 & V3010==2 & V3013==2)) & Ano>=2018 
replace aedu_ci=3 if ((V3003A==4 & V3006==4) | (V3003A==5 & V3006==3) | ((V3009A==5 | V3009A==8) & V3013==2) | (V3009A==7 & V3010==1 & V3013==2) | (V3009A==7 & V3010==2 & V3013==3)) & Ano>=2018
replace aedu_ci=4 if ((V3003A==4 & V3006==5) | (V3003A==5 & V3006==4) | ((V3009A==5 | V3009A==8) & V3013==3) | (V3009A==7 & V3010==1 & V3013==3) | (V3009A==7 & V3010==2 & V3013==4)) & Ano>=2018
replace aedu_ci=5 if ((V3003A==4 & V3006==6) | (V3003A==5 & V3006==5) | ((V3003A>=4 & V3003A<=5) & V3006==13 & V3006A==2) | ((V3009A==5 | V3009A==8) & V3013==4) | (V3009A==6 & V3012==2) | (V3009A==6 & V3012==3 & V3014==2) | ((V3009A>=7 & V3009A<=8) & V3012==3 & V3013A==1 & V3013B==1) | ((V3009A>=7 & V3009A<=8) & V3012==3 & V3013A==2 & V3014==2) | (V3009A==7 & V3010==1 & V3013==4) | (V3009A==7 & V3010==2 & V3013==5)) & Ano>=2018
replace aedu_ci=6 if ((V3003A==4 & V3006==7) | (V3003A==5 & V3006==6) | ((V3009A==5 | V3009A==8) & V3013==5) | (V3009A==6 & V3013==1) | (V3009A==7 & V3010==1 & V3013==5) | (V3009A==7 & V3010==2 & V3013==6)) & Ano>=2018
replace aedu_ci=7 if ((V3003A==4 & V3006==8) | (V3003A==5 & V3006==7) | ((V3009A==5 | V3009A==8) & V3013==6) | (V3009A==6 & V3013==2) | (V3009A==7 & V3010==1 & V3013==6) | (V3009A==7 & V3010==2 & V3013==7)) & Ano>=2018
replace aedu_ci=8 if ((V3003A==4 & V3006==9) | (V3003A==5 & V3006==8) | (V3009A==6 & V3013==3) | (V3009A==7 & V3010==1 & V3013==7) | (V3009A==7 & V3010==2 & V3013==8) | (V3009A==8 & V3013==7)) & Ano>=2018
replace aedu_ci=9 if (((V3003A>=6 & V3003A<=7) & (V3006==1 | V3006==13)) | (V3009A==6 & V3012==3 & V3014==1) | (V3009A==6 & V3013==4) | ((V3009A>=7 & V3009A<=8) & V3012==3 & V3013A==2 & V3014==1) | (V3009A==7 & V3010==1 & V3013==8) | (V3009A==7 & V3010==2 & V3013==9) | (V3009A==8 & V3013==8) | ((V3009A>=9 & V3009A<=11) & V3012==2) | ((V3009A>=9 & V3009A<=11)  & V3012==3 & V3014==2)) & Ano>=2018
replace aedu_ci=10 if (((V3003A>=6 & V3003A<=7) & V3006==2) | (V3009A==6 & V3013==5) | ((V3009A>=9 & V3009A<=11) & V3013==1)) & Ano>=2018
replace aedu_ci=11 if (((V3003A>=6 & V3003A<=7) & V3006==3) | ((V3009A>=9 & V3009A<=11) & V3013==2)) & Ano>=2018
replace aedu_ci=12 if ((V3003A==6 & V3006==4) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=2) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==1 & V3007==2) | ((V3009A>=9 & V3009A<=11) & V3012==3 & V3014==1) | ((V3009A>=9 & V3009A<=11) & V3013==3) | (V3009A==12 & V3012==2) | (V3009A==12 & V3011A==1 & V3013==1)) & Ano>=2018
replace aedu_ci=13 if ((V3003A==8 & V3005A==1 & (V3006>=3 & V3006<=4) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==2 & V3007==2) | ((V3009A>=9 & V3009A<=10) & V3013==4) | (V3009A==12 & V3011A==1 & (V3013>=2 & V3013<=3)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & V3013==1))  & Ano>=2018
replace aedu_ci=14 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=6) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=6) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=3) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=3) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==2) | (V3003A==8 & V3005A==1 & (V3006>=5 & V3006<=6) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==3 & V3007==2) | (V3009A==12 & V3011A==1 & (V3013>=4 & V3013<=5)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & V3013==2))  & Ano>=2018
replace aedu_ci=15 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==3) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & (V3011A>=2 & V3011A<=3) & V3013==3) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=7)) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=2 & V3013<=3)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==1 & V3011A==1 & (V3013>=4 & V3013<=7)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=2 & V3013<=3)) | (V3003A==8 & V3005A==1 & (V3006>=7 & V3006<=8) & V3007==2) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & V3006==4 & V3007==2) | (V3009A==12 & V3011A==1 & (V3013>=6 & V3013<=7)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & V3013==3)) & Ano>=2018

replace aedu_ci=16 if ((V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3003A==8 & V3005A==1 & (V3006>=1 & V3006<=8) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=1 & V3006<=4) & V3007==1 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | ((V3003A==8 & V3005A==1 & (V3006>=9 & V3006<=12)) | (V3003A==8 & (V3005A>=2 & V3005A<=3) & (V3006>=5 & V3006<=6)) | (V3003A>=9 & V3003A<=11) | (V3009A==12 & V3011A==1 & (V3013>=8 & V3013<=12)) | (V3009A==12 & (V3011A>=2 & V3011A<=3) & (V3013>=4 & V3013<=6)) | (V3009A>=13 & V3009A<=15)))	 & Ano>=2018
	

save "$data_orig\PNADC_panel_v1_grupo3_rs.dta", replace







* Append all data

use "$data_orig\PNADC_panel_v1_grupo1_rs.dta", clear
foreach x in 2 3 {
    append using "$data_orig\PNADC_panel_v1_grupo`x'_rs.dta", force
	save "$data_orig\PNADC_panel_v2_rs.dta", replace
}



use "$data_orig\PNADC_panel_v2_rs.dta", clear

rename Ano ano
*egen idind2 = group(idind)

* Education groups *
gen edu_group=.
replace edu_group=1 if aedu_ci>=0 & aedu_ci<=8
replace edu_group=2 if aedu_ci>=9 & aedu_ci<=13
replace edu_group=3 if aedu_ci>=14 & aedu_ci!=.


* ----------------------- LABOR SECTOR: 
* preliminary definitions

  gen inactivo=1      if npea==1                                     /* ensure that no one is left out */
  gen ocupado=1       if ocu==1                                       /* employed */
  gen desocupado=1    if desoc==1                                      /* unemployed */
  gen asalariado=1    if emp_privado==1 | emp_domestico==1                        /* salaried workers includes domestic worker */
  gen independiente=1 if empleador==1 | cpropia==1                          /* SELF-EMPLOYED + EMPLOYER */
  gen cotiza1=1       if com_carteira==1 | com_carteira_dom==1      /* if contributing to social security in main activity */
* gen cotiza2=1       if v432==1                                    /* if contributing to social security in secondary activity */
  gen seguro=1        if cotiza1==1 & asalariado==1                /* convention: formal if contributing to any */
  gen publico=1       if emp_publico==1                            /* public employed */ 
  gen domestico=1     if emp_domestico==1                        /* domestic workers */
  gen noremunerado=1  if familiar==1                      /* includes others category */


* various labor sectors (for transitions)

  gen laborsec=1      if inactivo==1                                          /* inactive */
  replace laborsec=2  if desocupado==1                                        /* unemployed */
  replace laborsec=3  if ocupado==1 & asalariado==1 & seguro==1 & publico!=1  /* formal private salaried worker */
  replace laborsec=4  if ocupado==1 & asalariado==1 & seguro!=1 & publico!=1  /* informal private salaried worker */
  replace laborsec=5  if ocupado==1 & publico==1              /* public salaried worker */
  replace laborsec=6  if ocupado==1 & independiente==1                        /* independent */
  replace laborsec=7  if ocupado==1 & noremunerado==1                         /* unpaid family worker */
  label define laborsec 1"Inactivo" 2"Desempleado" 3"Asalariado formal" 4"Asalariado informal" 5"Asalariado público" 6"Independiente" 7"TFNR"
  label values laborsec laborsec


* Formal-informal labor sectors (for transitions)

gen laborsec2=1 if ocupado==1 & asalariado==1 & seguro==1 & publico!=1 
replace laborsec2=2 if ocupado==1 & asalariado==1 & seguro!=1 & publico!=1
label define laborsec2 1"Asalariado formal" 2"Asalariado informal"
label values laborsec2 laborsec2
  
save "$data_orig\PNADC_panel_v3_rs.dta", replace

*************************


use "$data_orig\PNADC_panel_v3_rs.dta", clear

*14-64 years old
keep if V2009>=14 & V2009<=64
keep ano Trimestre idind laborsec laborsec2 V2007 V2009 V1028 edu_group

save "$data_orig\PNADC_panel_v4_rs.dta", replace

*************************


use  "$data_orig\PNADC_panel_v4_rs.dta", clear
rename Trimestre trim
rename V2007 sexo
rename V2009 edad
rename V1028 peso

egen id=group(idind)
egen trim2=group(ano trim)

duplicates report id ano trim
duplicates report id trim2
duplicates tag id ano trim, gen(rep2)
tab rep2
drop if rep2>0  
order id, after(idind)
drop rep2

* Generating ids for biannual panels
gen panel_1=1 if ano==2012 | ano==2013
gen panel_2=1 if ano==2013 | ano==2014
gen panel_3=1 if ano==2014 | ano==2015
gen panel_4=1 if ano==2015 | ano==2016
gen panel_5=1 if ano==2016 | ano==2017
gen panel_6=1 if ano==2017 | ano==2018
gen panel_7=1 if ano==2018 | ano==2019
gen panel_8=1 if ano==2019 | ano==2020
gen panel_9=1 if ano==2020 | ano==2021
gen panel_10=1 if ano==2021 | ano==2022

tsset id trim2

sort id trim2
by id: generate laborsec1year=f4.laborsec
label var laborsec1year "Sectores laborales a 1 anio"

sort id trim2
by id: generate laborsec21year=f4.laborsec2
label var laborsec21year "Sectores laborales formal/informal"
save "$data_orig\PNADC_panel_v5_rs.dta", replace

********************************

 * TRANSITIONS  *
 ****************


foreach x in 1 2 3 4 5 6 7 8 9 10 {
	forvalues i=1/4 {
		use "$data_orig\PNADC_panel_v5_rs.dta", clear  
		cap noi keep if panel_`x'==1
		cap noi keep if trim==`i'
		
		cap noi tab laborsec laborsec1year
		cap noi tabout laborsec laborsec1year [iw=peso] using "$data_final\transiciones_anual_PNADC_`x'_`i'.xls", append c(row) clab(%) f(2c) dpc h1("Population 15-64 years old")
		
	}	
}
 
 
 
 
 
















