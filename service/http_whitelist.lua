local url = {}

url.ALLOWED_PATTERNS = {
	--Game URLs
	"asset://.*",
	"data:.*",

	--Common URLs
	".*imgur%.com.*",
	".*google%.com.*",
	".*github%.com.*",
	".*pastebin%.com.*",
	".*steamcommunity%.com/sharedfiles/filedetails/.*",
}

function url.isWhitelisted(url)
	return true
	--[[
	for _, pattern in ipairs(urls.ALLOWED_PATTERNS) do
	    if string.match(url, pattern) then
	        return true
	    end
	end
	return false
	]]
end

return url
