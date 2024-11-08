///////////////////////////////////////////////////////////////////////////////////////
*CALCULATIE NEXT APPOINTMENT DATE 
//////////////////////////////////////////////////////////////////////////////////////
		
	*Use long dataset with visits and gap to next visit
		use $temp/visit_frequency, clear
				
	*List 
		list if id =="A_0111", sepby(id)
	
	*Check
		assert enc_sd !=.
	
	*Merge table with typical appointment schedule (by programme and yoa_cat)
		mmerge programme visit_cat using $clean/appointment_schedule, unmatched(master) udrop(programme visit_cat)
		assert _merge ==3      // ensure correct merge
		foreach var in p50 p25 p95 { 
			assert `var' !=.   // ensure that there are no missings 
		}	
		
	*Sort
		sort id enc_sd
		
	*Overwrite unscheduled visit gaps with plausible estimates 
	
		*Earliest possible next appointment is one month after visit 
			list id enc_sd diff diff_m visit_cat p50 p25 p95 if id =="C_4208", sepby(id)
			replace diff_m = 1 if diff_m ==0
			list id enc_sd diff diff_m visit_cat p50 p25 p95 if id =="C_4208", sepby(id)
				
		*Keep plausible gaps: put to missing if < p25 or > p95 of respective year  
			replace diff_m =. if diff_m < p25
			list id enc_sd visit_cat diff diff_m p95 if id =="C_0827", sepby(id)
			replace diff_m =. if diff_m > p95
			list id enc_sd visit_cat diff diff_m p95 if id =="C_0827", sepby(id)
										
		*Replace missing with plausible gaps for 1st follow-up visit if missing
			replace diff_m = p50 if  diff_m ==. & first ==1
																
	*Carry forward last plausible gap between visits 
		bysort id (enc_sd): replace diff_m = diff_m[_n-1] if diff_m ==. & diff_m[_n-1] !=. & _n != 1
		list id enc_sd visit_cat diff diff_m p95 if id =="C_0827", sepby(id)
	
	*Checks
		assert diff_m !=. 
		assert enc_sd !=.
						
	*Generate next appointment date
		gen int app_d = enc_sd + (diff_m*30) 
		format app_d %td
		label variable app_d "next appointment date"
		assert app_d !=.
		
		list id enc_sd visit_cat diff diff_m p95 app_d if id =="C_0827", sepby(id)
		
	*Clean
		drop visit_cat yoa* ysa* p50 p25 p95 _merge diff diff_m ntl
	
	*Order 
		order id enc_sd app_d programme haart_d last_vis my_close 
		
save $temp/next_app, replace


use $temp/next_app, clear
	
		*Validation: Calculate difference between observed last appointment date and estimated next appointment date (based on next to last appointment date + gap) 
			bysort id (enc_sd): gen error = enc_sd - app_d[_n-1] if last ==1 
			list id enc_sd app_d error if id =="C_0827", sepby(id) // 
			assert error !=. if N > 1 & N !=. & last ==1 // missing for patients with only 1 visit 
			sum error, de 
			assert `r(min)' >= -30
									
		*Error
			recode error (-30/30=0 "-30/+30") (31/90=1 "30/90") (91/180=2 "90/180") (181/max=3 ">180"), generate(error_cat) test
			
			tab error error_cat if error < 190
			tab prog error_cat if last ==1, row
		
		/*
		
					   |               RECODE of error
	 programme |   -30/+30      30/90     90/180       >180 |     Total
	-----------+--------------------------------------------+----------
	 Program_A |     4,171         62        181        190 |     4,604 
			   |     90.60       1.35       3.93       4.13 |    100.00 
	-----------+--------------------------------------------+----------
	 Program_B |     4,324         89         80         69 |     4,562 
			   |     94.78       1.95       1.75       1.51 |    100.00 
	-----------+--------------------------------------------+----------
	 Program_C |     4,524        128        118         93 |     4,863 
			   |     93.03       2.63       2.43       1.91 |    100.00 
	-----------+--------------------------------------------+----------
		 Total |    13,019        279        379        352 |    14,029 
			   |     92.80       1.99       2.70       2.51 |    100.00 
			

		*/
			
		*Y-lable 
			replace program = regexr(programme, "_", " ")
			
		*Graph
			catplot error_cat programme, percent(program) asyvars stack scheme(s1color) ///
			bar(1, color(green)) bar(2, color(orange)) bar(3, color(red)) bar(4, color(green) fintensity(50)) ///
			legend(col(1)) ///
			legend(label(1 "Est. app. date within ±30 days of recorded date"))  ///
			legend(label(2 "Est. app. date 31-90 days before recorded date: possibly false LTF")) /// // -> Patients who come on time are not misclassified as lost to follow-up.
			legend(label(3 "Est. app. date 91-180 days before recorded date: likely false LTF")) /// // -> Patients who come on time would be misclassified as lost to follow-up. 
			legend(label(4 "Est. app. date >180 days before recorded date: likely true LTF")) /// // -> Most likely patients had a long unscheduled treatment interruption. These patients would correctly be classified as lost to follow-up.
			legend(textwidth(160)) ///
			ylab(0(10)100) ///
			ytick(0(5)100)
			
		*Export 
			graph export $fig/NEXT_APPOINTMENT_DATE/Validation.wmf, as(wmf)  replace
			
		*Save Frequencies
			tab progr error_cat, row nofre matcell(prog) 
			clear
			svmat2 prog, names(matcol) rnames(prog)
