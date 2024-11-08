											
//////////////////////////////////////////////////////////////////
*** PLOT ART OUTCOMES FOR WHO DEFINITION OF LOSS TO FOLLOW-UP
//////////////////////////////////////////////////////////////////
			
	/// WHO DEFINITION 

		*Table with outcomes 		
			use $clean/pat_outcomes, clear 
			
		*Elig
			drop if drop ==1 // transferred before start of ART
			drop if fup_r90_days < 1 // never at risk of LTF 
			
		*St-set
			stset out_r90_d, failure(out_r90 == 11 41) origin(haart_d) exit(time exit_90_d)
		
		*Checks 
		
			*Assert that all patients are in analysis 
				assert _st ==1
			
			*RIC 
				assert _d ==0 if out_r90 == 50
				assert (_t == last_vis-haart_d) | (_t == last_vis-haart_d+1) | (_t == 3650) | (_t == my_close_d - 90 - haart_d) if out_r90 ==50
				
			*Death 
				assert (_t == death_d - haart_d) | (_t == death_d - haart_d+1)  if out_r90 == 11 & death_d < exit_90_d
				
			*Transfer
				assert (_t == transfer_d - haart_d) | (_t == transfer_d - haart_d+1)  if out_r90 == 31 & transfer_d < exit_90_d
				
			*LTF 
				assert (_t == last_vis - haart_d) | (_t == last_vis - haart_d+1) if out_r90 == 41 & last_vis < exit_90_d
									
			*Event after exit -> not failure  
				assert (_t == exit_90_d - haart_d) & _d ==0 if inlist(out_r90, 11, 41) & death_d > exit_90_d & death_d !=. 
			
		*Kaplan-Meier for RIC // outcome coding: 50 "RIC", 31 "TransOut", 41 "LTF", 11 "Dead" 
			
			*Stset (scale  in months)
				stset out_r90_d, failure(out_r90 == 11 41) origin(haart_d) exit(time exit_90_d) scale(30.416667)
																
			*Survival curve 
				sts gen km = s
				sort _t
				
			*Plot saved KM estimates 
				twoway line km _t, c(J) ///
				xtitle("Time from ART initiation (years)") ///
				ytitle("Cumulative survival probability") ///
				xlabel(0 "0" 12 "1" 24 "2" 36 "3" 48 "4" 60 "5" 72 "6" 84 "7" 96 "8" 108 "9" 120 "10") ///
				ylab(0(0.25)1) ///
				scheme(s1color) /// 
				graphregion(margin(small)) ///
				title("Kaplan-Meier estimates for RIC") ///
				name(RIC, replace)
		
		*Cumulative incidence for LTF and death 
													
			*St set (failure LTF, death is competing event specified in compet1(11))
				stset out_r90_d, failure(out_r90 == 41) origin(haart_d) exit(time exit_90_d) scale(30.416667)
													
			*Estimate cumulative incidence of LTF (event) adjusted for competing event death 
				stcompet ci=ci, compet1(11) // competing event death
											
			*Generate and plot cumulative incidence funtions 
				
				*LTF
					
					*Generate and fill in missings 
						sort _t
						gen cil = ci if out_r90==41
						replace cil = cil[_n-1] if missing(cil)
						replace cil = 0 if missing(cil)
					
					*Plot 
						twoway line cil _t, c(J) sort ///
						xtitle("Time from ART initiation (years)") ///
						ytitle("Cumulative probability") ///
						title("Cumulative incidence of loss to follow-up") ylabel(0(0.25)1) ///
						xlabel(0 "0" 12 "1" 24 "2" 36 "3" 48 "4" 60 "5" 72 "6" 84 "7" 96 "8" 108 "9" 120 "10") ///
						ylab(0(0.25)1) ///
						scheme(s1color) /// 
						graphregion(margin(small)) ///
						name(LTF, replace)
								
				*Death 
					
					*Gen and fill in missings 
						sort _t
						gen cid = ci if out_r90==11
						replace cid = cid[_n-1] if missing(cid)
						replace cid = 0 if missing(cid)
					
					*Plot 				
						twoway line cid _t, c(J) sort ///
						xtitle("Time from ART initiation (years)") ///
						ytitle("Cumulative probability") ///
						title("Cumulative incidence of mortality") ylabel(0(0.25)1) ///
						xlabel(0 "0" 12 "1" 24 "2" 36 "3" 48 "4" 60 "5" 72 "6" 84 "7" 96 "8" 108 "9" 120 "10") ///
						ylab(0(0.25)1) ///
						scheme(s1color) /// 
						graphregion(margin(small)) ///
						name(Death, replace)
															
				*Add dummy observation to ensure that plot starts at time 0 
					expand 2 in -1 // new observation is at the end
					replace _d = . in -1
					replace _t = 0 in -1
					replace km = 1 in -1
					replace cil = 0 in -1
					replace cid = 0 in -1
					
			*Generate boundaries for stacked area plot 
				sort _t
				gen b0 = 0
				gen dead = (b0 + km + cid)
				gen ltf = (b0 + km + cid + cil)
				
			*CI in Percent 
				foreach var in b0 dead ltf km {
					replace `var' = `var'*100
				}
				
			*Stacked cumulatvie incidences should be close to 100
				list _t ltf
				spikeplot ltf
				sum ltf
												
			*Save dataset with estimates 
				save "$temp/Area_plot_r90", replace
			
			
			*Area plot
				twoway	rarea b0 km _t, color("90 180 172") c(J) /// /* RIC */
						||	rarea km dead _t, color("245 245 245") c(J) /// /* dead */
						||	rarea dead ltf _t, color("216 179 101") c(J) /// /* LTF */
						xtitle("Time from ART initiation (years)") ///
						ytitle("Cumulative incidence (%)") ///
						xlabel(0 "0" 12 "1" 24 "2" 36 "3" 48 "4" 60 "5" 72 "6" 84 "7" 96 "8" 108 "9" 120 "10") ylabel(0(25)100) ///
						scheme(s1color) /// 
						graphregion(margin(small)) ///
						legend(label(1 "Retention in care")) legend(label(2 "Death")) ///
						legend(label(3 "Loss to follow-up")) ///
						legend(cols(1)) ///
						legend(order(3 2 1)) ///
						legend(ring(0) position(8) bmargin(medium)) ///
						graphregion(margin(small)) ///
						name(Outcomes_r90, replace)
										
			*Export graph			
				graph export $fig/ART_OUTCOMES/Area_plot_r90.png, replace 
	
	
												
////////////////////////////////////////////////////////////////////////
*** COMPARE RETENTION IN CARE FOR ALL DEFINITIONS OF LOSS TO FOLLOW-UP
///////////////////////////////////////////////////////////////////////
			
		*Table with outcomes 		
			use $clean/pat_outcomes, clear 
		
		*Loop over definitions
			foreach j in r90 r180 r365 p90 p180 p365 {
			
				*Define local k 
					local k = substr("`j'", 2, . ) 
									
				*Stset (scale  in months)
					stset out_`j'_d, failure(out_`j' == 11 41) origin(haart_d) exit(time exit_`k'_d) scale(30.416667)
																	
				*Survival curve 
					sts gen km_`j' = s
					rename _t t_`j'
					*sort _t
					
			}						
				
		*Plot saved KM estimates 
			twoway 	line km_r90 t_r90, sort c(J) lcolor("66 181 64") lwidth(*1.2) ///
					|| line km_r180 t_r180, sort c(J) lcolor("0 153 180") lwidth(*1.2) ///
					|| line km_r365 t_r365, sort c(J) lcolor("146 94 159") lwidth(*1.2) ///
					|| line km_p90 t_p90, sort c(J) lcolor("66 181 64") lwidth(*1.2) lpattern(dash) ///
					|| line km_p180 t_p180, sort c(J) lcolor("0 153 180") lwidth(*1.2) lpattern(dash) ///
					|| line km_p365 t_p365, sort c(J) color("146 94 159") lwidth(*1.2) lpattern(dash) ///					
					xtitle("Time from ART initiation (years)") ///
					ytitle("Cumulative survival probability") ///
					xlabel(0 "0" 12 "1" 24 "2" 36 "3" 48 "4" 60 "5" 72 "6" 84 "7" 96 "8" 108 "9" 120 "10") ///
					ylab(0(0.25)1) ///
					scheme(s1color) /// 
					title("") ///
					legend(label(1 "90 days")) legend(label(2 "180 days")) legend(label(3 "365 days")) ///
					legend(cols(1)) ///
					legend(order(1 2 3)) ///
					legend(ring(0) position(2) bmargin(medium)) ///
					graphregion(margin(small)) ///
					name(RIC_compare, replace)
	
	
	*Export graph
		graph export $fig/ART_OUTCOMES/LTF_compare.wmf, replace
