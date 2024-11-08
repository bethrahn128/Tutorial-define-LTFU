
/////////////////////////////////////////////////////////////////////////////////////////////////
***DEATH & TRANSFER OUT
/////////////////////////////////////////////////////////////////////////////////////////////////
		
	*PAT table
		use $tables/pat, clear
						
	*Merge last visit & closing_date 
		mmerge id using $temp/LTF_gap_unique, unmatched(master) ukeep(last_visit my_close_d)
		assert _merge ==3
		assert last_visit !=. 
		
	*Clean 
		drop close_d _merge
				
	*Checks
		assert last_vis !=. 
		assert my_close_d !=. 
		assert haart_d <= last_vis
		assert last_vis <= my_close_d
		count
		assert `r(N)' ==$N
		
	/// Mortality
							
			*Death_d & Death_y
				tab death_y, mi
				replace death_y = 0 if death_y !=1
				replace death_y = 1 if death_d !=. 
				assert death_d ==. if death_y ==0				
								
			*Death after closing -> patients were alive at closing -> death_y ==0; death_d ==. 
				count if death_d > my_close_d & death_y ==1 & death_d !=. // 4
				assert `r(N)' < 10
				replace death_y = 0 if death_d > my_close_d & death_y ==1 & death_d !=. 
				replace death_d = . if death_d > my_close_d & death_d !=.
								
			*Last visit after death -> last_visit = death_d
				assert last_visit !=. 
				count if last_visit > death_d & last_visit !=. & death_d !=. // *106
				list id last_visit death_d  if last_visit > death_d & last_visit !=. & death_d !=., header(20) sepby(id)
				assert `r(N)' < 107
				replace last_visit = death_d if last_visit > death_d & last_visit !=. & death_d !=. 
								
	/// Transfers
				
			*Transfer_y & transfer_d
				tab transfer_y, mi
				replace transfer_y = 0 if transfer_y !=1
				replace transfer_y = 1 if transfer_d !=. 
				assert transfer_d ==. if transfer_y ==0
				
			*Transferred before haart_start -> drop 
				count if transfer_d < haart_d & haart_d !=. 
				assert `r(N)' < 3
				gen drop = 1 if transfer_d < haart_d & haart_d !=. 
								
			*Transfer after closing -> patients were not transferred -> transfer_d ==.  
				count if transfer_d > my_close_d & transfer_d !=.  // 74
				assert `r(N)' < 85
				replace transfer_d = . if transfer_d > my_close_d & transfer_d !=.
				replace transfer_y = 0 if transfer_d ==.
												
			*Visit after transfer -> censore at at transfer
				count if transfer_d < last_visit & last_visit !=. 
				replace last_visit = transfer_d if transfer_d < last_vis & last_vis !=.
				assert transfer_d >= last_vis if last_vis !=. & transfer_d !=.
	
	/// LTF
		
		*Merge 
			mmerge id using $clean/LTF, unmatched(master) udrop(id)
			assert inlist(_merge, 1, 3)
			drop _merge
		
		*Replace missing with 0 in variables for LTF events 
			foreach j in r90 r180 r365 p90 p180 p365 {
				tab LTF_`j'_i, mi
				replace LTF_`j'_i = 0 if LTF_`j'_i ==. 
				assert LTF_`j'_i !=. 
				tab LTF_`j'_i, mi
			}
				
		*Check consistency of event dates against closing date 
			foreach j in r90 r180 r365 p90 p180 p365 {
				assert death_d < my_close_d if death_d !=.
				assert death_y == 0 if death_d ==. 
				assert transfer_d <= my_close_d if transfer_d !=. 
				assert transfer_y ==0 if transfer_d ==. 
				assert LTF_`j'_i ==1 if LTF_`j'_d < my_close_d
				assert LTF_`j'_i ==0 if LTF_`j'_d > my_close_d | LTF_`j'_d ==. 
			}
				
		*Retained in care (RIC) if not dead, transferred or LTF 
			foreach j in r90 r180 r365 p90 p180 p365 {
				gen RIC_`j'_i = 1
				replace RIC_`j'_i = 0 if (transfer_y ==1) | (death_y ==1) | (LTF_`j'_i ==1)
				tab RIC_`j'_i,  mi
			}
				
	/// Outcome 
		
		*Loop over LTF
			foreach j in r90 r180 r365 p90 p180 p365 {
			
					*Start 
						di "------------- start `j' ------------------"  // 
				
					*Gen outcomes 
						gen out_`j'_d = .
						gen out_`j' = . 
						
					*1. RIC
						replace out_`j'_d = last_visit if RIC_`j'_i ==1
						replace out_`j' = 50 if RIC_`j'_i ==1
						
					*2. LTF
						replace out_`j' = 41 if LTF_`j'_i ==1 
						replace out_`j'_d = LTF_`j'_d if LTF_`j'_i ==1 
					
					*3. Death (death beats LTF) 
						replace out_`j' = 11 if death_y ==1 
						replace out_`j'_d = death_d  if death_y ==1 
					
					*4. Censor patient at transfer (transfer beats LTF and death if earlier) 
						replace out_`j' = 31 if transfer_y ==1 & transfer_d < death_d 
						replace out_`j'_d = transfer_d if transfer_y ==1 
																
					*Checks 
						assert out_`j' !=.
						assert out_`j'_d !=.  
						
					*Patients cannot be LTF if transfer or death occurs 
						assert out_`j'!=41 if transfer_y == 1 | death_y ==1
													
					*Lab 
						lab define out_`j' 50 "RIC" 31 "TransOut" 41 "LTF" 11 "Dead" , replace 
						lab val out_`j' out_`j'
									
					*Tab
						tab out_`j', mi
						
					*Format
						format out_`j'_d %td
						
					*End
						di "------------- end `j' ------------------"  //
					}
					
					
		*Checks
				
			foreach j in r90 r180 r365 p90 p180 p365 {
					
					di "------------- start `j' ------------------"  // 
					
					di "RIC"
					assert out_`j' == 50 if RIC_`j'_i ==1 // RIC
					count if RIC_`j'_i ==1
					di "LTF"
					assert out_`j' != 41 if LTF_`j'_i ==1 & (transfer_y ==1 | death_y ==1 ) // LTF 
					di "Transfer"
					assert out_`j' == 31 if transfer_y ==1 & (death_d > transfer_d) // TO
					di "Death"
					assert out_`j' == 11 if death_y ==1 & (death_d < transfer_d)  // death 
					di "out_d <= my_close_d"
					assert out_`j'_d <= my_close_d if out_`j'_d !=. 
					di "missings"
					assert out_`j'_d !=. 
					assert out_`j'_d !=. 
					
					di "------------- end `j' ------------------"  // 
			}
						
		*Add 1 day for patients with outcome date on start date 
			foreach j in r90 r180 r365 p90 p180 p365 {
				replace out_`j'_d = out_`j'_d + 1 if out_`j'_d == haart_d 
			}
					
	/// Drop ineligible patients 
		
		*Drop patients who started ART start after closing 
			assert haart_d <= my_close_d 	
			drop if haart_d > my_close_d
				
		*Drop pre-ART patients
			assert haart_d !=. 
			drop if haart_d ==.   
	
	/// Exit date for stset 
					
		*Censor after 10 years 
			gen int max_fup = haart_d + 365*10
			format %td max_fup
			count if max_fup < my_close_d

		
		*Censor when patients stop being at risk of LTF (90, 180, or 365 days before database closure)
			foreach x in 90 180 365 { 
				gen int my_close_`x' = my_close_d - `x'
				format %td my_close_`x'
			}
															
		*Generate exit dates (90, 180, or 365 days before database closure or after 10 years of follow-up)
			foreach j in 90 180 365 {
				egen int exit_`j'_d = rowmin(max_fup my_close_`j')
				format exit_`j'_d %td
			}
					
		*Follow-up time  
			foreach j in r90 r180 r365 p90 p180 p365 {
				local k = substr("`j'", 2, . ) 
				di "`k'"
				egen int fup_`j'_d = rowmin(exit_`k'_d out_`j'_d)
				format fup_`j'_d %td
				gen fup_`j'_days = fup_`j'_d - haart_d 
				count if fup_`j'_days < 1
			}
								
	/// Final checks 

			foreach j in r90 r180 r365 p90 p180 p365 {
				local k = substr("`j'", 2, . )
				
				di "------------- start `j' ------------------"   
					
					di "RIC"
					assert fup_`j'_d == last_vis | fup_`j'_d == last_vis + 1 | fup_`j'_d == haart_d + 365*10 | fup_`j'_d == my_close_d - `k' if out_`j' == 50 // RIC 
				
					di "Death"
					assert out_`j'_d == death_d | out_`j'_d == death_d + 1  if out_`j' == 11  // Death 
					
					di "Transfer"
					assert out_`j'_d == transfer_d | out_`j'_d == transfer_d + 1  if out_`j' == 31  // Transfer 
					
					di "LTF"
					assert out_`j'_d == LTF_`j'_d | out_`j'_d == LTF_`j'_d + 1  if (out_`j' == 41 & transfer_y !=1 & death_y !=1)  // LTF
					assert out_r`k'_d == last_vis | out_r`k'_d == last_vis + 1  if (out_r`k' == 41 & transfer_y !=1 & death_y !=1)  // LTF
			
				di "------------- end `j' ------------------"  
			}
				
		
		*List
			list id haart_d max_fup my_close_d out_r90_d out_r90 last_visit transfer_d transfer_y death_y death_d LTF_r90_i LTF_r90_d RIC_r90_i fup_r90_days my_close_d my_close_90 in 250/300, sepby(id) header(20) 
			list id haart_d max_fup my_close_d out_r90_d out_r90 last_visit transfer_d transfer_y death_y death_d LTF_r90_i LTF_r90_d RIC_r90_i fup_r90_days my_close_d my_close_90 if out_r90==11, sepby(id) header(20) 
			
		*Save	
			save $clean/pat_outcomes, replace
				
	