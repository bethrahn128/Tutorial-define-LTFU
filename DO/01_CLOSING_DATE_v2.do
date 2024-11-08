
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
* VALIDATE COMPLETENESS OF DATA IN ALL TABLES FROM START OF ANALYSIS TO REPORTED CLOSING DATE. 
* IF NECESSARY CORRECT REPORTED CLOSING DATE   
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

***Correct close date*******************************************************
				
		***Patient table 
			use $tables/pat, clear
			
			*N
				count
				global N = `r(N)'
				di $N
			
			*List closing_dates
				bysort programme: list programme close_d if _n ==1
			
			*Browse data 
				list if id =="A_0001"
				
			*Drop dates before 2004 and after current date (dataset only includes patients who started ART after in 2004 or later. Follow-up starts at ART initiation)
				drop if haart_d < d(01/01/2004)
				drop if haart_d > $cdate & haart_d !=. 
				
			*Time since previous patient data recorded: last_info date - one earlier date
				bysort programme (haart_d): gen temp = haart_d-haart_d[_n-1]
				label var temp "Time b/t next visits"
				
			*Outliers if > 15 days later than the previous one
				gen temp1 =1 if temp > 15 & temp !=.
				label var temp1 "Outlier"
				
			*Outliers if four previous entries together are > 25 days later than previous one
				bysort programme (haart_d): replace temp1 =1 if (temp + temp[_n-1] + temp[_n-2] + temp[_n-3]) > 25 & (temp + temp[_n-1]) !=.	
				
			*Calculate corrected close date without without outliers
				bysort programme: egen my_close_d = max(haart_d) if temp1 !=1
				format my_close_d %td
				label var my_close_d "max last_visit no outliers"	
				
			*Ensure corrected close date is before provided close date
				replace my_close_d = close_d if my_close_d > close_d
				assert my_close_d <= close_d	
				
			*Keep one record per programme
				collapse (median)close_d = close_d (median)my_close_pat = my_close_d, by(programme)
							
			save $clean/pat_close, replace
			
			
		***ART table
			use $tables/art, clear
									
			*Generate programme
				gen programme = "Program_" + substr(id, 1, 1)	

			*Browse data 
				list if id =="A_0001", sepby(id)

			*Date
				rename art_sd date
				lab var date "ART start date"
				
			*Drop dates before 2004 and after current date
				drop if date < d(01/01/2004)
				drop if date > $cdate & date !=. 
				
			*Time since previous patient data recorded: last_info date - one earlier date
				bysort programme (date): gen temp = date-date[_n-1]
				label var temp "Time b/t next visits"
				
			*Outliers if > 15 days later than the previous one
				gen temp1 =1 if temp > 15 & temp !=.
				label var temp1 "Outlier"
				
			*Outliers if four previous entries together are > 25 days later than previous one
				bysort programme (date): replace temp1 =1 if (temp + temp[_n-1] + temp[_n-2] + temp[_n-3]) > 25 & (temp + temp[_n-1]) !=.	
				
			*Calculate corrected close date without without outliers
				bysort programme: egen my_close_d = max(date) if temp1 !=1
				format my_close_d %td
				label var my_close_d "max last_visit no outliers"	
				
			*Ensure corrected close date is before provided close date
				replace my_close_d = close_d if my_close_d > close_d
				assert my_close_d <= close_d	
				
			*Keep one record per programme
				collapse (median)my_close_art = my_close_d (median)close_d = close_d, by(programme)

		save $clean/art_close, replace


		***VIS, CD4, RNA tables
			foreach tab in rna cd4 vis {

			use $tables/`tab', clear
									
			*Generate programme
				gen programme = "Program_" + substr(id, 1, 1)	

			*Browse data 
				list if id =="A_0001", sepby(id)

			*Date
				rename `tab'_dmy date
				lab var date "ART start date"
				
			*Drop dates before 2004 and after current date
				drop if date < d(01/01/2004)
				drop if date > $cdate & date !=. 
				
			*Time since previous patient data recorded: last_info date - one earlier date
				bysort programme (date): gen temp = date-date[_n-1]
				label var temp "Time b/t next visits"
				
			*Outliers if > 15 days later than the previous one
				gen temp1 =1 if temp > 15 & temp !=.
				label var temp1 "Outlier"
				
			*Outliers if four previous entries together are > 25 days later than previous one
				bysort programme (date): replace temp1 =1 if (temp + temp[_n-1] + temp[_n-2] + temp[_n-3]) > 25 & (temp + temp[_n-1]) !=.	
				
			*Calculate corrected close date without without outliers
				bysort programme: egen my_close_d = max(date) if temp1 !=1
				format my_close_d %td
				label var my_close_d "max last_visit no outliers"	
				
			*Ensure corrected close date is before provided close date
				replace my_close_d = close_d if my_close_d > close_d
				assert my_close_d <= close_d	
		
			*Keep one record per programme
				collapse (median)my_close_`tab' = my_close_d (median)close_d = close_d, by(programme)
	
			save $clean/`tab'_close, replace
			}
		
		***Merge minimum corrected close dates for all tables
			use $clean/pat_close, clear
			foreach tab in art vis cd4 rna {
			mmerge programme using $clean/`tab'_close, unmatched(master) ukeep(my_close_`tab')
			drop _merge
			}			
			*Keep the minimum my_close_d for pat, vis, art 
			egen my_close_d =rowmin(my_close_pat my_close_art my_close_vis)
			format my_close_d %td		
			save $clean/my_close_d, replace
			
		//Programme "B"/////////////////////////////////		
			*Minimum corrected close date by table			
				*Patient table 	// 21jun2015						
				*ART table 		// 13jul2015					
				*VIS table 		// 30jul2015				
				*CD4 table 		// 15jun2015						
				*RNA table 		// 01sept2015
				
			*Minimum corrected close date across pat, art, vis tables
				*-> 21Jun2015
						
					
***Plot original and corrected close dates***************************************************
		
***Frequency plot for dates over time 

	use $tables/pat, clear

		*Merge corrected close dates
			mmerge programme using $clean/my_close_d, unmatched(master) ukeep(my_close_d)
			drop _merge
		
		*global macros for x-range of plot 
			global min = d(01/01/2004)
			global max = $cdate			
			
		*loop over programs and plot dates
			levelsof programme
			foreach prog in `r(levels)' {
				di "`prog'"
				preserve 
				keep if programme == "`prog'"
				local close_d = close_d
				local my_close_d = my_close_d
				spikeplot haart_d, ///
				xlab($min (1095) $max) ///
				xline(`close_d') ///
				xline(`my_close_d', lpatter(dash)) /// 
				subtitle("PATIENT TABLE") ///
				name("`prog'_pat", replace)
				restore
			}
		
***ART table 
	use $tables/art, clear		
							
	*Generate programme
		gen programme = "Program_" + substr(id, 1, 1)	
		
	*Merge corrected close dates
		mmerge programme using $clean/my_close_d, unmatched(master) ukeep(my_close_d)
		drop _merge
	
	*Browse data 
		list if id =="A_0001", sepby(id)
	
	*Date
		rename art_sd date
		lab var date "ART start date"
		
	*Drop dates before 2004 and after current date
		drop if date < d(01/01/2004)
		drop if date > $cdate & date !=. 
	
	***Frequency plot for dates over time 
			
		*loop over programs and plot dates
			levelsof programme
			foreach prog in `r(levels)' {
				di "`prog'"
				preserve 
				keep if programme == "`prog'"
				local close_d = close_d
				local my_close_d = my_close_d
				spikeplot date, ///
				xlab($min (1095) $max) ///
				xline(`close_d') ///
				xline(`my_close_d', lpatter(dash)) /// 
				subtitle("ART TABLE") ///
				name("`prog'_art", replace)
				restore
			}			
		
***RNA table 
	use $tables/rna, clear
							
	*Generate programme
		gen programme = "Program_" + substr(id, 1, 1)	
		
	*Merge corrected close dates
		mmerge programme using $clean/my_close_d, unmatched(master) ukeep(my_close_d)
		drop _merge

	*Browse data 
		list if id =="A_0001", sepby(id)
	
	*Date
		rename rna_dmy date
		lab var date "Viral load lab date"
		
	*Drop dates before 2004 and after current date
		drop if date < d(01/01/2004)
		drop if date > $cdate & date !=. 
	
	***Frequency plot for dates over time 
						
		*loop over programs and plot dates
			levelsof programme
			foreach prog in `r(levels)' {
				di "`prog'"
				preserve 
				keep if programme == "`prog'"
				local close_d = close_d
				local my_close_d = my_close_d
				spikeplot date, ///
				xlab($min (1095) $max) ///
				xline(`close_d') ///
				xline(`my_close_d', lpatter(dash)) /// 
				subtitle("RNA TABLE") ///
				name("`prog'_rna", replace)
				restore
			}					
		
***CD4 table 
	use $tables/cd4, clear
							
	*Generate programme
		gen programme = "Program_" + substr(id, 1, 1)	
	
	*Merge corrected close dates
		mmerge programme using $clean/my_close_d, unmatched(master) ukeep(my_close_d)
		drop _merge
	
	*Browse data 
		list if id =="A_0001", sepby(id)
	
	*Date
		rename cd4_dmy date
		lab var date "CD4 lab date"
		
	*Drop dates before 2004 and after current date
		drop if date < d(01/01/2004)
		drop if date > $cdate & date !=. 
	
	***Frequency plot for dates over time 
						
		*loop over programs and plot dates
			levelsof programme
			foreach prog in `r(levels)' {
				di "`prog'"
				preserve 
				keep if programme == "`prog'"
				local close_d = close_d
				local my_close_d = my_close_d
				spikeplot date, ///
				xlab($min (1095) $max) ///
				xline(`close_d') ///
				xline(`my_close_d', lpatter(dash)) /// 
				subtitle("CD4 TABLE") ///
				name("`prog'_cd4", replace)
				restore
			}					
	
***VIS table 
	use $tables/vis, clear
							
	*Generate programme
		gen programme = "Program_" + substr(id, 1, 1)	
		
	*Merge corrected close dates
		mmerge programme using $clean/my_close_d, unmatched(master) ukeep(my_close_d)
		drop _merge
	
	*Browse data 
		list if id =="A_0001", sepby(id)
	
	*Date
		rename vis_dmy date
		lab var date "Visit date"
		
	*Drop dates before 2004 and after current date
		drop if date < d(01/01/2004)
		drop if date > $cdate & date !=. 
	
	***Frequency plot for dates over time 
						
		*loop over programs and plot dates
			levelsof programme
			foreach prog in `r(levels)' {
				di "`prog'"
				preserve 
				keep if programme == "`prog'"
				local close_d = close_d
				local my_close_d = my_close_d
				spikeplot date, ///
				xlab($min (1095) $max) ///
				xline(`close_d') ///
				xline(`my_close_d', lpatter(dash)) /// 
				subtitle("VIS TABLE") ///
				name("`prog'_vis", replace)
				restore
			}			
			
			
***Combine plots 
	levelsof programme
	foreach prog in `r(levels)' {
		graph combine `prog'_pat `prog'_art `prog'_vis `prog'_cd4 `prog'_rna, col(1) title("`prog'") name("`prog'", replace) ///
		scheme(s1color) ysize(15) xsize(5) imargin(vsmall)   
		graph export $fig/Closing_date/Closing_`prog'.wmf, as(wmf)  replace
		}
