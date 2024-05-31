// Project: Inventor Relocation
// Creation Date: 10/02/2024
// Last Update: 10/02/2024
// Author: Laura Arnemann 
// Goal: Cleaning the assignee data to drop all government patents 

clear

forvalues i = 5/12 {
	append using "C:/Users/laura/Desktop/data/Patent_Data/Temp/assignee/assignee_`i'm.dta"
}

gen corp_assg = 0 
replace corp_assg = 1 if type == 2 
bysort assignee_id: egen max_corp_assg = max(corp_assg)
duplicates drop assignee_id, force
keep max_corp_assg assignee_id 

save "${TEMP}/corporate_assignees.dta", replace 