/////////////////////////////////////////////////////////////////////////////////////////////////
***DEFINITION OF LOSS TO FOLLOW-UP (LTF)
/////////////////////////////////////////////////////////////////////////////////////////////////

	***Classify patients lost to follow-up (LTF) according to WHO definition (retrospective definition according to Johnson et al Am J Epi 2014 PMID: 25399412)
		
		/* Definition: Patients more than 90 days late for their next scheduled clinic appointment who did not return to care 
		   during the study period were classified as LTFU on the day of their last visit.  */	
	
		/// Prepare dataset for WHO definition 
		
			*Use dataset with estimated next appointment date 
				use $temp/next_app, clear
				
			*N
				unique id
					
			*List 
				list if id =="A_0001", sepby(id) 
				
			*Checks 
				assert my_close_d !=.
				assert enc_sd !=.
				assert id !=""
				assert enc_sd <= my_close_d
				assert enc_sd > d(01/01/2004)
				assert app_d !=. 
				assert app_d > d(01/01/2004) 
				assert enc_sd == last_vis if last ==1
				assert enc_sd == last_vis if n ==N
				assert app_d > enc_sd 
						
			*Keep only row with last visit 
				list if id =="A_0001", sepby(id)
				keep if last ==1
				count
				assert `r(N)' == $N
						
			*Checks
				assert app_d >= last_visit
				assert enc_sd ==last_visit
				assert app_d !=.
					
			*Days between last appoitment date and closing date 
				gen gap = my_close_d - app_d
				assert gap !=. 	
				sum gap
				
			*Clean 
				drop enc_sd haart_d n N first last
				order id program last_v app_d  my_close_d gap
					
			*List 
				list if id =="A_0001", sepby(id) // LTF 484 days late
				list if id =="A_1425", sepby(id) // No LTF
				list if id =="A_0947", sepby(id) // LTF 90 but not 180
											
			*Save 
				save $temp/LTF_gap_unique, replace
					
				
			/// Save dataset with patients classified as lost to follow-up if they were 90, 180, or 365 days late, respectively. 
						
					*Loop over diffrent thresholds 
						foreach day in 90 180 365 {
						
							*Erase old filse 
								capture erase $temp/LTF_r`day'.dta
								
							*Preserve
								preserve
																
							*generate indicator for id LTF
								gen LTF_r`day'_i = 1 if gap > `day' & gap !=. 
								gen LTF_r`day'_d = last_vis if gap > `day' & gap !=. 
								format LTF_r`day'_d %td
														
							*Keep only id LTF
								keep if LTF_r`day'_i ==1
															
							*Clean 
								keep id LTF_r`day'_d LTF_r`day'_i
								
							*Display 
								di "`day' days gap"
								
							*Checks
								assert id !="" & LTF_r`day'_d !=. & LTF_r`day'_i !=. 
								bysort id LTF_r`day'_d: gen temp = _N				
								assert temp ==1
								drop temp 
								
							*Save dataset with ids LTF
								save $temp/LTF_r`day', replace
								
							*Restore
								restore 
					}		
				
					*Patients classified LTFU according to retrospective definition and 90 days late for last appointment 
						use $temp/LTF_r90, clear 
						list if id =="A_0001", sepby(id) // LTF 484 days late
						list if id =="A_1425", sepby(id) // No LTF
						list if id =="A_0947", sepby(id) // LTF 90 but not 180
								
	***Classify patients LTF of their last visit if they have a gap in care > threshold (prospective definition according to Johnson et al Am J Epi 2014 PMID: 25399412)
	
		*Definition used in time trends analysis with a threshold of 180 days. 

		/// Prepare dataset for prospective definition  
			
			*Use dataset with estimated next appointment date 
				use $temp/next_app, clear
			
			*Duplicate last row for id and write corrected closing date in enc_sd
				expand 2 if last ==1, gen(dummy)
				count if dummy ==1
				assert `r(N)' == $N
				replace enc_sd = my_close_d if dummy ==1 // enc_sd = closing date in duplicated row
				assert enc_sd ==my_close_d if dummy ==1 // check 	
				foreach var in n N first last app_d {  			// overwrite incorrect values in duplicated observation
					replace `var' = . if dummy ==1
				}
			
			*Gap between estimated appointment date and observed visit date or closing date for last visit 
				bysort id (enc_sd dummy): gen gap = enc_sd[_n+1] - app_d // it is important to sort by enc_sd and dummy. Else pat with visit on close_d will habe a missing gap
				assert gap !=. if dummy ==0
				list if id =="A_0001", sepby(id) // LTF on "30may2010" 400 days late
				list if id =="A_4225", sepby(id) // never late
				
					*Negative number means id came earlier than expected 
					*Positive number means id came later than expected 
					*In last visit positive number indicates the number of days the id was not seen in the facility before closing date
			
			*Save 
				save $temp/LTF_gap, replace
				
		
			/// Save dataset with patients classified as lost to follow-up if they were 90, 180, or 365 days late, respectively. 
					
					*Loop over diffrent thresholds 
						foreach day in 90 180 365 {
						
							*Erase old filse 
								capture erase $temp/LTF_p`day'.dta
					
							*preserve 
								preserve 
								
							*generate indicator for id LTF
								gen LTF_p`day'_i = 1 if gap > `day' & gap !=. 
							
							*Keep all dates when id is defined LTF
								keep if LTF_p`day'_i == 1
												
							*Keep first date when a id is LTF
								bysort id (enc_sd): keep if _n ==1
														
							*Define LTF date to last encounter date
								rename enc_sd LTF_p`day'_d
													
							*Clean 
								keep id LTF_p`day'_d LTF_p`day'_i
							
							*Checks
								assert id !="" & LTF_p`day'_d !=. & LTF_p`day'_i !=. 
								bysort id: gen temp = _N				
								assert temp ==1
								drop temp 
								di "`day' days gap"
								
							*Save dataset with ids LTF
								save $temp/LTF_p`day', replace
								
							*Restore
								restore 
					}		

				*List 
					use $temp/LTF_p180, clear
					list if id =="A_0001", sepby(id) // LTF on "28aug2010" 400 days late
					list if id =="A_4225", sepby(id) // never late
				
	***Merge datasets 
			
			*Merge 
				use $temp/LTF_r90, clear 
				mmerge id using $temp/LTF_r180, udrop(id)
				assert inlist(_merge, 1, 3)
				mmerge id using $temp/LTF_r365, udrop(id)
				assert inlist(_merge, 1, 3)
				mmerge id using $temp/LTF_p90, udrop(id)
				assert inlist(_merge, 2, 3)
				mmerge id using $temp/LTF_p180, udrop(id)
				assert inlist(_merge, 1, 3)
				mmerge id using $temp/LTF_p365, udrop(id) 
				assert inlist(_merge, 1, 3)
				drop _merge
					
			*Assert that table is unique for id 		
				bysort id: gen temp =_N
				assert temp ==1
				drop temp
			
			*Save 
				save $clean/LTF, replace
		
	