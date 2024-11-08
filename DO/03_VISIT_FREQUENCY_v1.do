
////////////////////////////////////////////////////////////////////////////////
*FREQUENCY OF CLINIC VISITS BY PROGRAMME (AFTER ART START)
////////////////////////////////////////////////////////////////////////////////

	*Encounters table
		use $clean/enc1, clear
		
	*N
		unique id
			
	*Check
		drop if enc_sd ==.
	
	*Last visit
		bysort id (enc_sd): egen int last_visit = max(enc_sd) 
		format last_visit %td
		list if id =="A_0001", sepby(id)
		label var last_visit "last visit"
					
	*Gaps between encounters 
		bysort id (enc_sd): gen diff = enc_sd[_n+1] - enc_sd
		list id enc_sd diff if id =="A_0001", sepby(id)
		
	*Gaps between encounters in months
			gen diff_m = round(diff/30)
				
	*Visit number 
		bysort id (enc_sd): gen n = _n
	
	*Number of visits 
		bysort id (enc_sd): gen N = _N
		list id enc_sd diff n N if id =="A_0001", sepby(id)
	
	*First visit 
		gen first = 1 if n ==1
		
	*Last visit 
		gen last = 1 if n == N 
		
	*Next to last visit 
		gen ntl = 1 if n==N-1
		list id enc_sd diff diff_m n N first last ntl if id =="A_0001", sepby(id)
	
	*Year on ART
		gen yoa = ceil((enc_sd - haart_d)/365)
		replace yoa = 1 if yoa ==0
		list id haart_d enc_sd yoa diff diff_m n N first last ntl if id =="A_1235", sepby(id)
				
	*Year on ART cat
		recode yoa (1 = 1 "year 1") (2/max = 2 "year 2+"), gen(yoa_cat) 
		tab yoa yoa_cat, mi
		
	*Year starting ART
		gen ysa = year(haart_d)
		tab ysa, mi
			
	*Year starting ART cat
		recode ysa (min/2011 = 1 "<2012") (2012/max =2 ">2011"), gen(ysa_cat) test
		tab ysa_cat, mi
		
	*Create visit frequency categories
		gen visit_cat =1 if ysa_cat ==1 & yoa_cat ==1
		replace visit_cat =2 if ysa_cat==1 & yoa_cat ==2
		replace visit_cat =3 if ysa_cat ==2 & yoa_cat ==1
		replace visit_cat =4 if ysa_cat ==2 & yoa_cat ==2
		tab visit_cat, mi
	
	*Save 
		save $temp/visit_frequency, replace
		
	*Visit frequency by programme 	
	
		*ART start <2012 & first year on ART (visit_cat ==1)
			levelsof programme 
			foreach prog in `r(levels)' {
				sum diff_m if programme =="`prog'" & visit_cat == 1, de
				spikeplot diff if programme =="`prog'" & visit_cat == 1 & diff < 400 & diff >0, ///
				xlab(0(30)400) xtitle("Days between follow-up visits") scheme(s1color) title("ART start ≤2011, 1st year on ART") subtitle("Median: `r(p50)' mo; 25th percentile: `r(p25)' mo; 95th percentile: `r(p95)' mo")  ///
				name(`prog'_visits_c1, replace)
			}
			
		*ART start <2012 & 2+ years on ART   (visit_cat ==2)
			levelsof programme 
			foreach prog in `r(levels)' {
				sum diff_m if programme =="`prog'" & visit_cat == 2, de
				spikeplot diff if programme =="`prog'" & visit_cat == 2 & diff < 400 & diff >0, ///
				xlab(0(30)400) xtitle("Days between follow-up visits") scheme(s1color) title("ART start ≤2011, 2+ year on ART") subtitle("Median: `r(p50)' mo; 25th percentile: `r(p25)' mo; 95th percentile: `r(p95)' mo")   ///
				name(`prog'_visits_c2, replace)
			}
	
		*ART start >2011 & first year on ART   (visit_cat ==3)
			levelsof programme 
			foreach prog in `r(levels)' {
				sum diff_m if programme =="`prog'" & visit_cat == 3, de
				spikeplot diff if programme =="`prog'" & visit_cat == 3 & diff < 400 & diff >0, ///
				xlab(0(30)400) xtitle("Days between follow-up visits") scheme(s1color) title("ART start ≥2012, 1st year on ART") subtitle("Median: `r(p50)' mo; 25th percentile: `r(p25)' mo; 95th percentile: `r(p95)' mo")  ///
				name(`prog'_visits_c3, replace)
			}
			
		*ART start >2011 & 2+ years on ART  (visit_cat ==4)
			levelsof programme 
			foreach prog in `r(levels)' {
				sum diff_m if programme =="`prog'" & visit_cat == 4, de
				spikeplot diff if programme =="`prog'" & visit_cat == 4 & diff < 400 & diff >0, ///
				xlab(0(30)400) xtitle("Days between follow-up visits") scheme(s1color) title("ART start ≥2012, 2+ years on ART") subtitle("Median: `r(p50)' mo; 25th percentile: `r(p25)' mo; 95th percentile: `r(p95)' mo")  ///
				name(`prog'_visits_c4, replace)
			}
							
	*Combine plots 
		levelsof programme
		foreach prog in `r(levels)' {
			graph combine `prog'_visits_c1 `prog'_visits_c2 `prog'_visits_c3 `prog'_visits_c4, col(1) title("`prog'") name("`prog'", replace) ///
			scheme(s1color) ysize(15) xsize(9) imargin(vsmall)   
			graph export $fig/Visit_frequency/`prog'.png, replace
		}
	 	 
	*Generate table with summary statistics
			
		*Collapse data
			collapse (median)p50=diff_m (p25)p25=diff_m (p95)p95=diff_m, by(programme visit_cat)
			list, sepby(programme)
		
		*Based on visual inspection of frequency plots and knowledge of guidelines and local practices, change summary statistics in necessary 
			
			*Program B: 
				replace p95 = 4 if inlist(visit_cat, 2, 4) & programme =="Program_B"
				list, sepby(programme)		
		
		*Save
			save $clean/appointment_schedule, replace
			
		graph close _all
	