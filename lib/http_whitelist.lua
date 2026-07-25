-- Domains (and any subdomain of them) allowed through detours/http.c's
-- block-by-default HTTP detour. Add a bare root domain to allow it plus
-- every subdomain, e.g. "githubusercontent.com" also allows
-- raw.githubusercontent.com, gist.githubusercontent.com, etc.
--
-- Ported from antifreeze v1.4.1's service/http_whitelist.lua and collapsed
-- from its per-path Lua patterns down to root domains, since the matching
-- now happens in the compiled C detour (see is_whitelisted in
-- detours/http.c) rather than in Lua — cheaper to check at that layer, but
-- means path-scoped rules like "docs.google.com/uc..." became host-scoped
-- ("google.com" allows any path). Fine for this use case: every entry here
-- is a host you'd trust with any path, not a narrow endpoint.
return {
	"google.com",
	"dropboxusercontent.com",
	"dropbox.com",
	"onedrive.live.com",
	"api.onedrive.com",
	"backblazeb2.com",
	"imgur.com",
	"ibb.co",
	"gyazo.com",
	"pastebin.com",
	"gitlab.com",
	"bitbucket.org",
	"githubusercontent.com",
	"github.com",
	"githack.com",
	"tinypic.com",
	"paste.ee",
	"hastebin.com",
	"puu.sh",
	"steamcommunity.com",
	"steamusercontent.com",
	"steamstatic.com",
	"akamaihd.net",
	"discordapp.com",
	"discordapp.net",
	"redditmedia.com",
	"redd.it",
	"ipfs.io",
	"neocities.org",
	"sndcdn.com",
	"shoutcast.com",
	"ytimg.com",
	"scdn.co",
	"dzcdn.net",
	"cyzon.us",
	"revolt.chat",
	"revoltusercontent.com",
	"michaelbelgium.me",
	"nekoweb.org",
	"statically.io",
}
