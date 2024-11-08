	
	***STATA Version 14.1
	
	/////////////////////////////////////////////////////////////////////////////////////////////////
	*RUN FIRST
	/////////////////////////////////////////////////////////////////////////////////////////////////
		
		*file paths		
			global dd "O:/Elizabeth/IeDEA-WHO_Collaboration/IeDEA-WHO_Collaboration_2017/LTFU_Tutorial/RETENTION_TUTORIAL_v0.3"  // <- define file paths here 
			global source "$dd/SOURCE_DATA"
			global clean "$dd/SIMULATED_DATA/CLEAN"
			global tables "$dd/SIMULATED_DATA/INPUT_TABLES"
			global temp "$dd/SIMULATED_DATA/TEMP"
			global fig = "$dd/FIGURES"
			
		*global macro for current date
			global cdate date("$S_DATE" , "DMY")
			
		*Global macro with number of patients  
			use $tables/pat, clear
			count
			global N = `r(N)'
			di $N
						
		*install user-written packages
			capture ssc install catplot
			capture ssc install mmerge
			capture ssc install unique
			capture ssc install stcompet
			capture net install dm79.pkg
			
			
	
