# 06_DEFINE_OUTCOMES
In do-file “06_DEFINE_OUTCOMES” we define ART outcomes for patients according to the six LTF scenarios defined in the previous do-file. ART outcomes are retained in care, transferred out, LTF, and dead. Outcomes are mutually exclusive. Dead and transfer out always supersede retention in care and LTF. Patients not LTF, transferred out, or dead are classified as retained in care. 
We further calculate the date patients exit the survival analyses. Patients exit the analyses after a maximum of 10 years of follow-up or when they stop being at risk for LTF (i.e. depending on time window used in the LTF definition 90, 180, or 365 days before database closure, respectively). 


