local taunt = {}

local totable = string.ToTable
local string_sub = string.sub
local string_find = string.find
local string_len = string.len

local function parse(str)
	local ret = {}
	local current_pos = 1

	for i = 1, string_len(str) do
		local start_pos, end_pos = string_find(str, "\n", current_pos, true)
		if not start_pos then
			break
		end
		ret[i] = string_sub(str, current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end

	ret[#ret + 1] = string_sub(str, current_pos)

	return ret
end

taunt.taunts = parse([[
absolute failure
absolute garbage
absolute stomp
absolute trash
absolutely demolished
absolutely rolled
actual npc moment
actually no im not
ai plays better
aim not found
almost had me
already back?
always trash
and you're dead
another clip
another donation
another failed run
another failure
another freebie
another idiot down
another one down
any challenge?
any percent death
anyone else?
are you afk?
are you blind?
are you guessing where i am?
back to lobby
back to spawn
back to spawn buddy
back to spawn dumbass
back to training
bad aim
bad call
bad decision
bad everything
bad life choices
bad movement
bad player detected
bad positioning
bad positioning again
bad timing
barely a fight
beautiful throw
better luck later
better luck tomorrow
big brain play huh
big choke
big fail
big gap
big miss
big mistake
big yawn
blindfolded gameplay
blink and gone
blinked and died
bot behavior
bot detected
bot diff
bot level gameplay
bottom tier player
brain not found
bronze gameplay
call backup
cardboard rank
caught lacking
caught lacking again
caught slipping
caught you
chapter one: you lose
clip that
clown
clowned
clowned again
come back later
come back stronger
complete choke
complete disaster
complete trash
completely destroyed
completely outplayed
content delivered
cornered
definitely not him
delete the game
deleted
demolished
denied
destroyed
destroyed again
did u blink?
did you even try?
did you forget how to play?
did you lag or just bad?
did you lag?
did you miss every shot?
did you panic?
did you try aiming?
did you try?
did your keyboard disconnect?
didnt even break a sweat
didnt learn last time
disappeared
do better
don't leave spawn
donate more kills
down you go
easy as hell
easy clap
easy cleanup
easy farm
easy pickup
easy read
easy target
eat shit
elite level throwing
embarrassing
embarrassing gameplay
erased
even bots play better
fantastic death
farm simulator
flattened
free cleanup
free frag
free fucking kill
free kill
free kill again
free loot
free points
free points again
free respawn
free scoreboard boost
fully deleted
fumbled
get better
get better or quit
get farmed
get fucked
get rolled
getting easier
gg ez
gg go next
gigantic skill gap
gone
gone already
gone instantly
good job dying
great job dying
hard diff
hello??
highlight reel
holy shit you're bad
how are you this bad?
how did you lose that?
how did you miss that
huge L
huge choke
huge mistake
huge skill gap
human target
i blinked and you died
i've fought better bots
idiot play
illegal levels of bad
im farming xp off you
im farming you
im half asleep
im not even trying
im reading you like a book
im starting to feel bad
imagine losing that
instant regret
just sad
just uninstall
just uninstall already
keep boosting me
keep donating kills
keep dying like that
keep feeding
keep helping me
keep lining up
keep panicking
keep practicing
keep trying
keep trying kid
laughably bad
learn nothing huh
learn to aim
learn to aim dumbass
legendary throw
line up please
literal bot
lmao owned
magic trick
makes no difference
massive L
massive skill gap
masterclass feeding
maybe a tutorial helps
maybe aim?
maybe dodge?
maybe gaming isn't for you
maybe gaming isnt for you
maybe move?
maybe next life
maybe next time
maybe practice?
maybe think?
maybe tomorrow
maybe uninstall?
maybe use your eyes
maybe watch a guide
miles apart
missed everything
my kill
my turn again
never had a chance
next attempt failed
next idiot please
next please
next victim
nice choke
nice donation
nice feeding
nice panic
nice strategy genius
nice try
nice try idiot
no chance
no mechanics
nope
not even a challenge
not even close
not even warmup
not really
not today
not worth the ammo
not your day
not your game
nothing changed
now you see them now you dont
npc behavior
npc moment
npc pathing
oops
oops again
or don't
ouch
out of your league
outclassed
outmatched
outplayed
outplayed hard
over already?
owned
owned again
owned so hard
painful gameplay
painful to watch
pathetic
perfect feed
picked the wrong target
plastic rank
please uninstall
poof
practice dummy
practice first
practice mode?
practice more
predictable
predictable again
predictable as hell
predictable play
predictable player
queue again
queue the next one
queue up again
read like a book
read you easily
really stupid
really?
removed
respawn simulator
rolled
rolled again
rolled your ass
rough day?
round three loss
round two loss
same mistake
same play every time
saw that coming
scripted movement
see you in 5 seconds
send better players
send someone better
sent back to spawn
should have ran
sit down
sit down kid
skill gap
skill issue
skill issue detected
skill not found
sleeping?
slow brain moment
slow reaction
slowest reflexes ever
so fucking bad
so predictable
spawn camper food
spawn camper victim
speedrun death
speedrun to respawn
stat padding
stay bad
stay dead
stay down
stay down asshole
stay in spawn
stay mad
still bad
still falling for that?
still not enough
still not working
still terrible
still trash
still waiting for a challenge
still warming up?
stop feeding
stop holding the mouse backwards
straight up garbage
target practice
terminal skill issue
terrible decision
terrible idea
terrible play
terrible push
thanks for that
thanks for the frag
thanks for the highlight
thanks for the kill dumbass
thanks for the montage clip
thanks for the points
thanks for the stat boost
thanks for the stats
that aim hurts
that aim is illegal
that all you got?
that hurt
that hurt to watch
that plan sucked
that reaction time though
that was a disaster
that was a stomp
that was embarrassing
that was fast
that was free
that was free as hell
that was fucking easy
that was painful to watch
that was pathetic
that was quick
that was rough
that was sad
that was sad as hell
that was stupid
that was warmup
that was your move?
that wasn't it
that wasnt it
thats brutal
thats rough
thats the play?
thats tragic
thinking is optional i guess
this is boring
this is getting sad
this is practice right?
this isn't your game
this lobby is free
too clean
too easy
too easy again
too easy kid
too easy today
too fast
too free
too fucking easy
too fucking easy again
too fucking slow
too late now
too predictable
too slow
too slow again
too smart
top tier mistake
total clown
training dummy
training range awaits
trapped
trash
try a different game
try a new strat
try a tutorial
try again
try again kid
try again later
try again moron
try again tomorrow
try aiming next time
try easy mode
try harder
try harder next time
try moving next time
try something new
try turning your monitor on
try uninstalling
tutorial level player
u suck kid
unbelievably bad
unbridgeable gap
uninstall
unlucky
utterly rolled
vanished
wake me up later
wake me when someone good shows up
wake up
wake up next time
waste of a respawn
waste of space
waste of time
way too slow
weak
welcome back to dying
what a joke
what the hell was that
who let you play
who taught you?
who told you that would work?
why stand still
why would you do that?
wiped
wiped off the map
worse every time
worst play i've seen
wrong fight
wrong fight buddy
wrong fight kid
wrong hobby
wrong lobby
wrong move
yawn
yikes
you afk?
you again?
you ain't him
you are farmable
you arent ready
you arent that someone
you blinked
you call that aim?
you died again?
you folded
you folded instantly
you froze
you froze?
you fucking suck
you fumbled hard
you fumbled that
you good?
you got clapped
you got destroyed
you got farmed
you got read
you got wrecked
you hesitated
you just boosted me
you keep trying that
you lasted two seconds
you learned nothing
you lost
you lost again
you lost badly
you make this boring
you make this easy
you make this too easy
you missed everything
you panic?
you play like shit
you really did that twice
you serious right now?
you serious?
you suck
you sure you're playing?
you thought that would win?
you tried
you vs me isnt fair
you walked into it
you walked into that
you walked right into it
you're a free kill
you're awful
you're hopeless
you're my warmup
you're not it
you're target practice
you're terrible
your mistake
zero aim
zero awareness
zero chance
]])

taunt.broTaunts = parse([[
bro about to check settings
bro aiming with his elbow
bro alt+f4 incoming
bro became a statistic
bro blaming gravity
bro blaming hitboxes
bro blaming keyboard
bro blaming lag
bro blaming mouse
bro blaming teammates
bro blaming the chair
bro blaming the patch notes
bro blaming the sun
bro blinked and died
bro boosted my kd
bro buffed my stats
bro calling tech support
bro chose the wrong timeline
bro contacting support
bro contemplating uninstall
bro coping
bro coping hard
bro crit failed
bro delivered himself
bro devastated
bro donated a kill
bro evaporated
bro failed the quicktime event
bro fed the scoreboard
bro filing a complaint
bro flabbergasted
bro folded instantly
bro forgot his mouse
bro forgot the controls
bro forgot the objective
bro gaming on a microwave
bro gonna blame ping
bro got absolutely farmed
bro got any%ed
bro got banished
bro got boxed
bro got clipped
bro got cooked
bro got deleted
bro got diffed
bro got dismantled
bro got erased
bro got farmed
bro got flattened
bro got folded like laundry
bro got fried
bro got gapped
bro got humbled
bro got obliterated
bro got outplayed by an npc
bro got packed up
bro got reality checked
bro got removed from existence
bro got roasted
bro got rolled
bro got sent back to the lobby
bro got sent to the shadow realm
bro got skill checked
bro got speedran
bro got wiped
bro got world record'd
bro in shambles
bro installed today
bro is a walking assist
bro is free loot
bro is free xp
bro lagging in real life
bro learned a lesson
bro lined up perfectly
bro logged in to lose
bro lost the tutorial
bro lost to ai
bro missed the cutscene
bro needs a buff
bro needs a miracle
bro needs a new hobby
bro needs a new keyboard
bro needs a new planet
bro needs a new strat
bro needs a patch
bro needs aim assist
bro needs backup
bro needs dlc
bro opening google
bro perplexed
bro picked the bad ending
bro playing on a steering wheel
bro playing with eyes closed
bro playing with his feet
bro posting on reddit
bro pressed every key except shoot
bro processing defeat
bro queued just to die
bro ragequit internally
bro reconsidering gaming
bro recording the clip
bro reduced to atoms
bro reporting me
bro respawning emotionally
bro rolled a 1
bro running 2 fps
bro said here you go
bro said take the kill
bro searching how to win
bro served himself
bro skipped the tutorial
bro spawned and folded
bro spawned incorrectly
bro staring at the respawn screen
bro still in the menu
bro still loading in
bro stunned
bro submitting a ticket
bro thinking about life
bro thinks this is minecraft
bro thought friendly fire was off
bro thought this was roblox
bro turned into dust
bro turned into particles
bro typing how to aim
bro uninstall speedrun
bro using a potato pc
bro using a trackpad
bro using dial up
bro using powerpoint aim
bro using tilt controls
bro using voice commands
bro vanished
bro volunteered
bro watching a guide after this
bro writing a bug report
]])

taunt.xboxTaunts = parse([[
ur a ****ing noob
what the **** was that
holy **** ur bad
dumb ****
stupid ****
little ***** kid
get ****ed
go **** urself scrub
**** off and uninstall
ur ****ing garbage
absolute ****ing bot
****ing trash tier
u ****ing suck lol
**** ur whole setup
****ing rekt idiot
shut the **** up and get better
u ****** noob
****** scrub
stop being a little *****
u play like a *****
*****
little *****
absolute *****
don't be such a *****
******
****ing ******
ur such a ****** lol
***
dumb ***
stupid ***
brokeasskid
poorassscrub
ugly ***
***hole
ur such an ***hole
****ing ***hole
****sucker
****
eat ****
****ty player
****ty aim
ur ****
ur actual ****
piece of ****
****face
****head
go **** a ***
son of a *****
motherfucker
mother****ing noob
**** ur mom
ur moms a *****
**** u and ur whole family
****ing **** stain
**** eating scrub
]])

taunt.swapTaunts = parse([[
you fucking %s
stupid %s
%s please die in a hole
ur such a %s lol
absolute %s
little %s
dumb %s
pathetic %s
get rekt %s
typical %s
ur a %s and everyone knows it
lmao what a %s
classic %s move
only a %s plays like that
go cry %s
stay mad %s
ez kill on a %s
what a %s lmaooo
reported %s
uninstall %s
holy shit ur a %s
actual %s
certified %s
ur just a %s kid
free kill %s
get owned %s
imagine being a %s
no wonder ur trash ur a %s
log off %s
dashboard %s
rage quit %s
cry about it %s
skill issue %s
git gud %s
go back to tutorial %s
embarrassing %s
put the controller down %s
bot tier %s
ur a walking free kill %s
i feel bad for u %s
genuinely feel sorry for u %s
ur so bad its sad %s
even bots play better than u %s
my little sister could beat u %s
go play singeplayer %s
stick to minecraft %s
u dont belong online %s
get off xbox %s
give ur controller to someone who can play %s
u are the reason this game has a mute button %s
ur the worst player ive ever seen %s
negative kd having %s
hardstuck %s
boosted %s
carried %s
ur team must hate u %s
nobody wants to play with u %s
get clapped %s
get bodied %s
destroyed %s
wrecked %s
obliterated %s
u mad %s
salty %s
mad cuz bad %s
bad cuz mad %s
shut up %s
nobody asked %s
zip it %s
ur opinion means nothing %s
ur trash and u know it %s
just accept ur bad %s
u will never improve %s
ur hardstuck forever %s
same mistakes every game %s
predictable ass %s
slow ass %s
laggy ass %s
broke ass %s
ugly ass %s
dummy %s
goofy %s
goofy ass %s
clown ass %s
ur a clown %s
actual clown %s
u think ur good %s
u thought %s
he thought he was nice lmao %s
delusional %s
cope %s
cope harder %s
ur coping so hard rn %s
touch grass %s
go outside %s
nobody likes u %s
ur friendless %s
ur playing alone because nobody wants u on their team %s
ur the lobby joke %s
everyone is laughing at u %s
ur a meme %s
ur literally a %s
what a fucking %s
holy shit a actual %s
lmaooo ur such a %s
bro is a %s
this guy is a %s lmaooo
we got a %s in the lobby
actual certified %s
verified %s
bonafide %s
grade A %s
world class %s
olympic level %s
professional %s
ur a %s and thats facts
no cap ur a %s
on god ur a %s
swear to god ur a %s
i promise u are a %s
everybody in this lobby knows ur a %s
play better %s
get good %s
get a brain %s
use ur eyes %s
learn to aim %s
learn to play %s
learn the game %s
read the map %s
use ur head %s
think for once %s
try harder %s
dont even try %s
just give up %s
ur not built for this %s
this game isnt for u %s
go back to tutorial %s
ur still in tutorial mode %s
did u just start playing yesterday %s
how long have u been playing and ur still this bad %s
years of practice and ur still a %s
no improvement whatsoever %s
getting worse every game %s
going negative again %s
ur kd is a tragedy %s
ur stats should be illegal %s
delete ur account %s
start a new account and try again %s
ur gamer tag should be xX%sXx
ur gamertag fits u %s
ur mom raised a %s
ur parents failed u %s
ur dad is disappointed in u %s
ur whole family is embarrassed %s
even ur mom thinks ur a %s
go tell ur mom u got rekt %s
ur babysitter plays better than u %s
ur little brother would clap u %s
ur little sister is better than u %s
let ur dad play %s
go to bed kid ur a %s
school night %s
do ur homework %s
ur bedtime was an hour ago %s
does ur mom know ur up this late %s
ur too young to be this bad %s
ur acting like a little kid %s
grow up %s
ur so immature %s
ur gonna look back and cringe %s
get a real controller %s
get a real tv %s
get a real internet connection %s
ur connection is as bad as ur aim %s
wifi warrior %s
ethernet or go home %s
dial up having %s
laggy %s
disconnect already %s
ur router is as broken as ur gameplay %s
ur setup is trash just like u %s
get a real headset %s
ur mic quality is as bad as ur gameplay %s
i cannot believe how bad u are %s
i am genuinely shocked %s
how %s
how are u this bad %s
explain urself %s
what was that %s
what are u doing %s
what is ur problem %s
are u okay %s
are u even trying %s
is ur controller broken %s
are u playing blindfolded %s
are u using ur feet %s
did u sit on ur controller %s
bro forgot how to play %s
bro forgot he was in a game %s
bro thought he was nice %s
bro woke up and chose to be a %s
bro said let me be a %s today
he really said im gonna be a %s
somebody thought this %s could play
not my problem ur a %s
sounds like a u problem %s
cope %s
cope and seethe %s
seethe %s
mald %s
mald harder %s
cry harder %s
tears taste good %s
ur tears are delicious %s
keep crying %s
cry me a river %s
nobody cares %s
nobody asked %s
nobody wants to hear it %s
the lobby doesnt care %s
move on %s
get over it %s
its just a game %s
its just a game and ur still bad at it %s
gg ez %s
too easy %s
free game %s
free lobby %s
free real estate %s
walk in the park %s
i wasnt even trying %s
i was afk and still killed u %s
i had my eyes closed %s
i could beat u left handed %s
i could beat u with a broken controller %s
i will never lose to a %s
i have never lost to a %s and today isnt the day
ur literally my warmup %s
ur my easy lobby %s
thanks for the free kills %s
thanks for feeding %s
keep feeding %s
ur doing great %s keep it up
ur my favorite %s to farm
ill be here all night farming u %s
]])

taunt.swapWords = {
	"bitch",
	"dumbass",
	"stupidshit",
	"crybaby",
	"idiot",
	"screwball",
	"freak",
	"chickenshit",
	"douchebag",
	"moron",
	"fool",
	"jackass",
	"dummy",
	"dipshit",
	"pussy",
}

return taunt
