// Set footer text

let footer_lines = [
	"do i have \"retro swag\" yet?",
	"now *that's* what i call ash taylor.",
	"i wrote this website in like three hours, and yet here i am, adding footer gags.",
	"I Can't Believe It's Not MS Paint Adventures!",
	"*really* banking on my bizarre sense of humor landing with potential employers.",
	"who needs a web framework when you have HTML, CSS and ADHD?",
	"those are some top-tier CHORDIOIDs you got there.",
	"really digging the Web 1.0 aesthetic lately. hard to tell, i know.",
]

document.getElementById("footer-text").innerHTML = "<i>\"" + footer_lines[Math.floor(Math.random()*footer_lines.length)] + "\"</i>"