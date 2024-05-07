


program beep_me 
version 9 
args n_beeps 
if missing("`n_beeps'") {
	local n_beeps = 3
}
forvalues n=1/`n_beeps' {
	beep 
	sleep 1000
}
shell pause
end 