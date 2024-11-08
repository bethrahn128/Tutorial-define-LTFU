
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
* CREATE CLINIC ENCOUNTERS TABLE -> TABLE WITH ALL POSSIBLE DATES INDICATING THAT A PATIENT WAS SEEN AT THE FACILITY  
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				
	***Patient table 
		use $tables/pat, clear
		
		*N
			count
		
		*Browse data 
			list if id =="A_0001"
			list if id =="A_0015", sepby(id)
			
		*Define global macro with all dates from the patient table that reliably indicate that a patient was seen at the clinic.
			global dates "haart_d " // <- add dates if there are more in your data 
			
		*Clean 
			keep id $dates 
			list if id =="A_0001"
			
		*Rename 
			local j = 1 
			foreach var in $dates {
				rename `var' enc_sd`j'
				local j = `j' + 1 
			}
			list if id =="A_0001"
		
		*Reshape data to long table. Each encounter date is one row
			list if id =="A_0001"
			reshape long enc_sd, i(id) j(j)
			list if id =="A_0001"
			list if id =="A_0015"
			
		*Clean 
			drop j
	
	***Add dates from long tables 

		*List
			list if id =="A_0001", sepby(id)
	
		*RNA: add lab dates from RNA table 
			append using $tables/rna, keep(id rna_dmy)
			replace enc_sd = rna_dmy if enc_sd ==. 
			drop rna_dmy 
			sort id enc_sd
			list if id =="A_0001", sepby(id)
			list if id =="A_0015"
			
		*CD4: add lab dates from CD4 table 
			append using $tables/cd4, keep(id cd4_dmy)
			replace enc_sd = cd4_dmy if enc_sd ==. 
			drop cd4_dmy 
			sort id enc_sd
			list if id =="A_0001", sepby(id)
		
		*ART_sd: add ART start dates from ART table  
			append using $tables/art, keep(id art_sd)
			replace enc_sd = art_sd if enc_sd ==. 
			drop art_sd 
			sort id enc_sd
			list if id =="A_0001", sepby(id)
			
		*VIS table: add visit dates from visits table 
			append using $tables/vis, keep(id vis_dmy)
			replace enc_sd = vis_dmy if enc_sd ==. 
			drop vis_dmy
			sort id enc_sd
			list if id =="A_0001", sepby(id)
			list if id =="A_0015"
			
		*Drop duplicates: ensure that enc_sd is unique for id 
			bysort id enc_sd: keep if _n==1
			
		*Drop records with missing enc_sd
			drop if enc_sd ==. 
			
		*List 
			sort id enc_sd
			list if id =="A_0001", sepby(id)
		
		*label enc_sd
			label var enc_sd "Patient was seen at clinic"
			
		*merge corrected closing date 
			gen programme = "Program_" + substr(id, 1, 1)
			mmerge programme using $clean/my_close_d, unmatched(master) ukeep(my_close_d)
			assert _merge ==3
			drop _merge
			assert my_close_d !=.
			list if id =="A_0015"
			
		*drop encounters after closing
			drop if enc_sd > my_close_d
			
		*drop encounters before scale up of ART 
			drop if enc_sd < d(01/01/2004) 
			
		*drop encounters before start of ART
			mmerge id using $tables/pat, unmatched(master) ukeep(haart_d)
			assert inlist(_merge, 2, 3)
			drop if haart_d ==. // pre ART patients 
			drop if enc_sd < haart_d // pre ART follow-up 
				
		*N 
			unique id
			
		*Clean
			drop _merge
			
		*List output for patient A_0015
			list if id =="A_0015"
		
		*Save 
			save $clean/enc1, replace
	
	***Frequency plot for dates over time 
							
			*loop over programs and plot dates
				levelsof programme
				foreach prog in `r(levels)' {
					di "`prog'"
					preserve 
					keep if programme == "`prog'"
					local my_close_d = my_close_d
					spikeplot enc_sd, ///
					xlab($min (1095) $max) ///
					xline(`my_close_d') ///
					subtitle("ENCOUNTERS TABLE: `prog'") ///
					name("`prog'_enc", replace)
					graph export $fig/Closing_date/ENC_my_closing_`prog'.wmf, as(wmf)  replace
					restore
				}		
				
	***Combine plots 
					graph combine Program_A_enc Program_B_enc Program_C_enc, col(1) ///
					scheme(s1color) ysize(15) xsize(5) imargin(vsmall)   
					graph export $fig/Closing_date/ENC_my_closing.wmf, as(wmf)  replace
												
	***Ensure that each patient is in the enc table 
		bysort id: keep if _n ==1
		keep id 
		mmerge id using $tables/pat, ukeep(haart_d)
		assert _merge ==3
	
