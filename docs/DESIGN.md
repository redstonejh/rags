# RAGS — A Life Sim About Starting From Nothing
*(working title: "RAGS" — everyone starts in rags; riches optional)*

## Context

A single-player life simulation — **Sims × GTA × Second Life** — where every playthrough begins poor, but *how* you're poor is the whole character creation system. Origins work like Project Zomboid character builds: every bonus is paid for with a downside, and big bonuses carry big costs. From there it's a full open-ended life sim: work jobs, make friends, fall in love, raise kids, build a dream house, get mega rich — or rob, attack, and murder your way through a town of fully simulated, persistent NPCs.

**Decisions made:**
- **Engine:** Godot 4.4+ (GDScript), 2D top-down square grid (isometric look is a possible later art swap — architecture is identical)
- **Tone:** Dark comedy — gritty subject matter (addiction, crime, poverty) written with a GTA-style smirk
- **Death:** Permadeath, but **the world persists** — your next character starts in the same town, where NPCs remember your last one. Visit your old character's grave. Meet their widow. Get snubbed by people your last character robbed.
- **Aging:** Full Sims-style life stages for everyone, player included. Combined with persistent-world permadeath this enables **generational play**: die of old age (or a knife) and continue as your grown child — inheriting the house, the money, and the reputation, for better or worse.
- **Developer:** solo, some coding experience, new to game dev — roadmap is built around always-playable incremental milestones.
- **Art:** chunky 32px pixel art (asset-pack friendly; body-sim sprite variants as layers). **Audio:** diegetic radio stations, district-flavored, with a DJ who reads your headlines; silence is the score when you're hiding a body. **Saves:** ironman single-slot by default (death is instant and written to the world); per-world "Tourist Mode" toggle allows manual saves, permanently marked.
- **M0 is already built and committed** (walking skeleton: clock, needs, town generator, fridge, day/night, HUD).

---

## Part 1 — Origin Stories

Every origin answers three questions: **How poor are you?** (cash + housing), **What did your past life give you?** (bonuses), and **What's still chasing you?** (downsides). The bigger the leg-up, the heavier the baggage. Each origin also has a **unique mechanic** — a system only that origin experiences.

Difficulty: ★ (easiest) to ★★★★★ (brutal).

### ★★ The Golden Parachute That Didn't Open — *Fired Corporate Exec*
You had the corner office until the merger. Security walked you out with a box.
- **Start:** $2,400, one month paid on a decent apartment, a very nice suit, a leased car (payments due).
- **Bonuses:** Business & Charisma skills start high. "Old Rolodex" — three wealthy contacts who'll take your calls. Interview bonus for white-collar jobs.
- **Downsides:** **Champagne Taste** — cheap food, cheap furniture, and bus rides drain your Comfort/Mood twice as fast; your needs are calibrated to a life you can no longer afford. **Industry Blacklist** — your old rival badmouths you; top-tier corporate jobs are locked until you clear your name or destroy him. Car repo if you miss two payments.
- **Unique mechanic:** **The Rival.** A specific NPC (your old VP) actively works against you — sabotaging job applications, spreading rumors. Befriend, blackmail, ruin, or kill him to lift the blacklist.

### ★★★★★ Rock Bottom — *The Tweaker*
You live behind the gas station. You know which dumpsters are good. You are, in a very specific way, free.
- **Start:** $7 in change, a shopping cart (mobile mini-storage!), no home, no ID.
- **Bonuses:** **Street Eyes** — pickpocketing, lock-picking, and scavenging skills start high; you can see "scavenge" spots invisible to other origins. **Nothing Left to Lose** — fear/stress penalties from crime are halved. The street community (other homeless NPCs) treats you as family and shares food and tips.
- **Downsides:** **The Need** — full addiction system: a craving meter that tanks Mood, focus, and skill gain when unfed; feeding it costs money and risks overdose, police attention, and worse addiction. Withdrawal is a multi-day debuff gauntlet. **No Papers** — can't take legal jobs, open a bank account, or rent until you rebuild your ID (a questline). Cops search you on sight in nice neighborhoods.
- **Unique mechanic:** **Recovery arc.** Getting clean is a long, mechanically real struggle (relapse triggers: stress, old dealer NPCs, bad days) — but a clean ex-addict permanently gains the strongest willpower stat in the game.

### ★★★ Struck Off — *The Disgraced Doctor*
Twelve years of training. One pill scandal. The license is gone; the hands still remember.
- **Start:** $300, sleeping in your car (a nice car — last thing they couldn't take), medical bag.
- **Bonuses:** Medicine skill maxed. Treat your own injuries and illnesses for free. NPCs who learn you're a doctor trust you faster.
- **Downsides:** **$210,000 in student debt** — wage garnishment takes 25% of all *legal* income, forever, until paid. Practicing medicine legally is permanently locked. Mild pill addiction (lighter version of The Need).
- **Unique mechanic:** **Back-Alley Clinic.** Criminals pay triple for no-questions-asked treatment — gunshot wounds, overdoses. Lucrative, builds underworld reputation, and every patient is a witness who knows what you do.

### ★★★ Fresh Out — *The Ex-Con*
Eight years inside. The world got smartphones; you got a bus ticket and gate money.
- **Start:** $200 gate money, halfway-house bed (curfew: 10 PM), prison-yard physique.
- **Bonuses:** Fighting and Intimidation start high. **Yard Respect** — criminal NPCs trust you immediately; the black market is open from day one. Pain tolerance up.
- **Downsides:** **The Record** — most legal jobs auto-reject you; landlords too. **Parole** — weekly check-ins with your PO; miss one, fail a search, or get spotted committing a crime and you go *back* (jail is a real, playable, time-losing place in this game). **Old Crew** — your former associates show up with a "job." Refusing costs reputation and maybe safety; accepting risks your parole.
- **Unique mechanic:** **Going Straight vs. Going Back.** A visible "Heat vs. Trust" track with your PO. Two years clean ends parole and seals the record. Most players won't make it.

### ★★ Cut Off — *The Trust-Fund Runaway*
Daddy said "marry her or you're cut off." You chose the door. Respect. Also: you have never done laundry.
- **Start:** $800 (your watch, pawned), zero skills in everything practical, gorgeous wardrobe.
- **Bonuses:** Educated (skill books read 2× faster), Etiquette (charisma bonus with wealthy NPCs), genuinely healthy and well-rested for once.
- **Downsides:** **Helpless** — cooking, repair, cleaning start at negative levels; you will burn cereal. **Sheltered** — scam and pickpocket vulnerability; street NPCs read you as a mark instantly. **The Family** — they want you back on their terms; they'll bribe, guilt, and sabotage you into returning.
- **Unique mechanic:** **The Inheritance.** Reconcile with the family (on their terms — arranged marriage, joining the firm) for instant wealth and a lost ending... or build your own life and, if you out-earn your father, get the best confrontation scene in the game.

### ★★★ One More Hand — *The Gambler*
You were up $40K at 2 AM. You remember that part very clearly.
- **Start:** $150, weekly-rate motel room, a lucky coin.
- **Bonuses:** **Luck stat exists for you alone** — small but real bonus on every random roll in the game (crits, finds, close calls). Card-game skill high; the casino and underground tables are a genuine income path.
- **Downsides:** **The Itch** — a compulsion meter: go too long without a bet and Mood crashes and the meter starts forcing bad decisions (auto-betting portions of big windfalls unless you pass a willpower check). **$15,000 to Big Mickey** — a loan shark with a payment schedule and two large employees. Miss payments: beatings, then your stuff, then your kneecaps.
- **Unique mechanic:** **Double or Nothing.** Once per in-game week, any major event can be gambled — a job interview, a paycheck, a police arrest ("bet you can't catch me"). 50/50: dramatically better or dramatically worse outcome.

### ★ Off the Bus — *The Small-Town Transplant*
Population 312 → population 80,000. You have a duffel bag and a cousin's address that turned out to be fake.
- **Start:** $400, hostel bed, sturdy boots.
- **Bonuses:** **Clean Slate** — zero reputation, zero enemies, zero debt; the only origin with no one chasing you. Honest face (+trust with strangers). Hardworking (+10% skill gain on any job).
- **Downsides:** Knows nobody (every relationship starts from zero — no contacts of any kind). Naive (first-time vulnerability to city scams). No starting skills above baseline.
- **Unique mechanic:** None — and that's the point. This is the tutorial-difficulty origin: pure blank slate, lowest highs, highest floor.

### ★★★★ Left Holding Everything — *The Widowed Parent*
The funeral was Tuesday. Daycare doesn't take IOUs. Your daughter still asks when the other parent is coming home.
- **Start:** $350, a rent-overdue apartment, **a 6-year-old child** (fully simulated NPC).
- **Bonuses:** **Someone to Live For** — Mood floor is raised; you cannot bottom out into despair while your kid is okay. Sympathy bonus: NPCs help you more readily, charity options unlocked. Cooking/household skills start solid.
- **Downsides:** **Half your time isn't yours** — school runs, sick days, bedtime; the kid's needs interrupt everything including jobs and heists. Constant money drain. **Child Services** — neglect the kid (or get arrested) and a caseworker NPC starts a file; losing your child is the worst non-death outcome in the game and craters your stats for weeks.
- **Unique mechanic:** **The Kid Grows Up.** Your child ages, develops traits based on how you raised them and *what they witnessed* (yes, including that), and eventually becomes a playable-adjacent ally — or a stranger who doesn't call.

### ★★★ Tin Foil & Duct Tape — *The Prepper*
You weren't wrong that society is fragile. You were just early. The van is paid off, which is more than most people can say.
- **Start:** $90 cash (banks are obviously a trap), a livable van full of gear, tools, and 40 cans of beans.
- **Bonuses:** Survival, repair, and crafting skills high. **The Van** — free mobile housing immune to rent and eviction. Off-grid: can fish, forage, craft, and repair instead of buying.
- **Downsides:** **Paranoid** — social skill capped low until trust is individually earned per NPC (slow); crowds drain Mood. **No Banks** — cash only, ever: you can be robbed of everything, can't take direct-deposit jobs, can't build credit, can't get loans. Cops ticket/tow the van from nice areas.
- **Unique mechanic:** **The Stash Network.** Bury caches around the map — the only origin with theft-proof storage. Other origins keep money in banks; you keep it in a coffee can under a specific tree, and only you know which one.

### ★★ Past Glory — *The Washed-Up Athlete*
You were on a poster. Now your knee predicts the weather and the poster is in a thrift store.
- **Start:** $500, sleeping on a former-fan's couch, one championship ring (pawnable — but should you?).
- **Bonuses:** Fitness and athletics start very high. **Local Legend** — many NPCs recognize you: free drinks, easy first impressions, doors open.
- **Downsides:** **The Knee** — a chronic injury that randomly flares (movement and labor penalties); physical overexertion risks a permanent re-injury. **Recognized** — fame cuts both ways: you cannot commit crimes anonymously ("wait, aren't you—?"), witnesses always identify you, and your failures make the local news.
- **Unique mechanic:** **The Comeback.** A high-risk training arc toward one sanctioned return match. Win: money, restored fame, sponsorships. Lose or re-injure: the knee, and the dream, are done for good.

### ★★★★ The Departed — *The Cult Escapee*
Fourteen years in the Family of the Radiant Dawn. You jumped the fence during morning chant. You can recruit a stranger in four sentences; you cannot name the current president.
- **Start:** $0, a robe, a stolen ceremonial dagger (worth more than you'd think).
- **Bonuses:** **Silver Tongue** — persuasion/manipulation skill very high (you were taught by professionals). Immune to scams and manipulation (you wrote the manual). Meditation: can restore Mood without money.
- **Downsides:** **You Don't Exist** — no birth certificate, no ID, no records; the full no-papers problem plus total cultural illiteracy (fails basic knowledge checks, weird social misfires). **They Want You Back** — cult members appear in town: first friendly, then insistent, then *insistent*.
- **Unique mechanic:** **Deprogram or Inherit.** Rescue other members one by one (each is a deep persuasion challenge using your own skills against the cult)... or use what you know to take the whole thing over. The cult has assets. Just saying.

### ★★★★★ The Blank — *The Amnesiac*
You woke up in the rail yard with a head wound, $63, and a key with no label. The first NPC who saw your face crossed the street.
- **Start:** $63, the clothes you woke up in, one mysterious key.
- **Bonuses:** **Hidden Build** — you secretly have one of the *other* origins' full bonus sets (randomly assigned), discovered through play: maybe your hands know surgery; maybe your fists know prison.
- **Downsides:** You also have that origin's full downside set — and you don't know what it is until it finds you. Debt collectors, cult members, or a parole officer may show up *before* you learn why. All skills display as "???" until used once.
- **Unique mechanic:** **The Investigation.** Piece together who you were from NPC reactions, the key, news archives, and dreams. You may discover you were someone wonderful. You may discover you were the worst person in this design document. You choose whether to become them again.

---

## Part 2 — Trait System (Project Zomboid–style)

On top of an origin, players spend **trait points**. Origins grant 0 points; positive traits cost points; negative traits refund points. Budget must balance to ≤ 0. Origins lock/discount some traits (the Tweaker can't take "Iron Will" but gets "Light Sleeper" free).

**Positive (cost):** examples —
| Trait | Cost | Effect |
|---|---|---|
| Fast Learner | 6 | +30% all skill XP |
| Iron Stomach | 3 | Eat expired/dumpster food safely |
| Smooth Talker | 4 | Better persuasion options in dialogue |
| Night Owl | 2 | No energy penalty midnight–4 AM |
| Handy | 4 | Repair/build quality +1 tier |
| Forgettable Face | 5 | Witnesses 50% less likely to ID you |
| Iron Will | 5 | Resist addiction/compulsion checks |
| Green Thumb | 3 | Grow food at home |

**Negative (refund):** examples —
| Trait | Refund | Effect |
|---|---|---|
| Short Fuse | 4 | Low Mood can force hostile dialogue/attack options |
| Insomniac | 3 | Sleep restores 30% less |
| Allergies | 2 | Random sneeze fits (ruins stealth) |
| Two Left Feet | 3 | Clumsy: drops items, noisy, dance = social damage |
| Sweet Tooth | 2 | Junk food cravings drain money/health |
| Bad Back | 4 | Carry capacity halved |
| Recognizable Laugh | 2 | Any NPC who's heard you laugh can ID you by it |
| Hot-Blooded | 5 | Romance options everywhere, but jealousy events constantly |
| Unlucky | 6 | The Gambler's Luck stat, inverted |

---

## Part 3 — Core Gameplay Systems

1. **Needs:** Hunger, Energy, Hygiene, Fun, Social, plus **Mood** (the master stat, modified by everything). Origin mechanics (The Need, The Itch) are extra need-bars only some characters have.
2. **Skills:** ~12 skills (Cooking, Fitness, Charisma, Business, Medicine, Mechanics, Stealth, Fighting, Marksmanship, Gambling, Crafting, Persuasion) leveled by doing, PZ-style.
3. **Jobs & money:** Legit career ladders (retail → manager → corporate; labor → trades; etc. — each a daily "go to work" loop with on-the-job events) and a **criminal ladder** (pickpocketing → burglary → robbery → contract work). Bills, rent, taxes. Wealth tiers from shelter cot to hilltop mansion.
4. **NPCs:** Every NPC is persistent — has a home, job, schedule, needs (abstracted), relationships, and a **memory** of player interactions. Anyone can be befriended, dated, married, robbed, or killed. Killed NPCs stay dead; their job opens up, their family grieves and *remembers*.
5. **Relationships & family:** Friendship/romance meters per NPC, dating, marriage, kids (who age), in-laws, rivals, enemies. Funerals.
6. **Housing:** Rent or buy any home, grid-based build/furnish mode, furniture affects needs quality (a $30 mattress vs. a $3,000 bed).
7. **Crime & consequences:** Witness system (NPCs who see crimes remember and report — unless persuaded, bribed, or silenced), wanted level, police AI, jail as playable time-loss (with its own social ecosystem), reputation that spreads through NPC social networks via gossip.
8. **Combat:** Simple but lethal melee/ranged. Violence is always available and always has consequences — the murder-hobo path is *valid*, and the entire town will eventually respond like a town would.
9. **Time & aging:** Real clock, day/night, weekly bills, seasonal calendar. Everyone ages through life stages (child → teen → adult → elder). Elders die; kids grow up; the town's population turns over across a long game.
10. **Death & legacy (the signature feature):** Player death is permanent — but the world isn't reset. You "respawn" by creating a *new* character (new origin, new traits — your exec died, now you're a tweaker) into the **same persistent town**, with everything your previous character did still standing:
    - Your old character gets a **grave** (or an unmarked ditch, depending on how they went). Funeral attendance reflects how they lived.
    - **Their family is still there.** Visit your old character's widow, watch their kid grow up raised by someone else, befriend (or get rejected by) your own previous family — they don't know the new you.
    - **The destruction persists.** NPCs your last character killed are still dead — their jobs filled or vacant, their families grieving. Burned bridges stay burned; the shopkeeper your last character robbed is still jumpy.
    - **The good persists too.** The business your last character built is still running. Money/property goes to their heirs — which your new character can try to marry into, steal back, or earn legitimately.
    - The town accumulates **history across all your lives** — the news archive, the graveyard, and NPC gossip become a record of every character you've ever played.
    - Special case: if your dead character had a grown child, you may choose to **play as them** — inheriting the house, the money, and the family reputation ("your mom murdered the mayor").
    - **Walking Away (retirement):** you don't have to die to start over. From the pause menu, "Walk Away" — your character stops being yours and becomes a **full autonomous NPC**. The sim runs their life with everything you built: the job, the house, the spouse, the rap sheet, the addictions. Your next character can meet them — befriend your old self, rob them, watch them thrive or relapse without you at the wheel. (Implementation note: this is nearly free in the architecture — the player record IS an NPCRecord with a controller flag; retirement just flips the flag and assigns a schedule.)
    - **New blood is a fresh stranger:** starting over means full character creation (any origin/class/stats) and arriving as someone the town has never met — the bus, the prison gate, the rail yard, per your origin. But YOU know the town: seek out your old character's family, visit the grave, dig up the stash only you remember, leverage secrets only you know (who really killed the mayor). **Player knowledge is the true inheritance.**

**Design pillars:** (1) Every bonus has a price. (2) NPCs remember — even across your characters. (3) Money is the scoreboard, but Mood is the game. (4) Any path is playable — saint, tycoon, parent, monster. (5) Violence is rare, terrifying, and usually ends with somebody begging.

---

## Part 3.5 — Deep-Design Decisions (approved in Q&A)

### RPG layer: 6 stats + lifestyle drift + levels + skills + perks
Three tiers, D&D-flavored:
- **Stats (STR / DEX / CON / INT / WIS / CHA):** classic point-buy allocation at character creation (origins skew the budget). Then they DRIFT with how you live: stats are trained by passive lifestyle, and **tunneling on one thing pulls others down** — live at the gym and STR climbs while INT sags ("you stopped reading"); grind night classes and INT rises while STR atrophies; plastic surgery buys CHA with cash (with a gone-wrong risk). A balanced life keeps everything level; you can be a jack of all trades, but excelling at one thing always costs somewhere else. Drift is slow (a point every few game-weeks) and always shown to the player ("Your jeans fit differently. STR +1, INT −1").
- **Levels & perks:** all activity feeds character XP → level up → **a perk every 2 levels**. Perks are forks, data-driven (`PerkDef` .tres), and prefer new verbs over numbers ("Silver Tongue: lie with no Mood penalty" vs "Closer: +20% deal outcomes"). The top of the perception tree is "People Reader" (see Reality Check below).
- **Skills:** still learn-by-doing on top (Cooking, Stealth, Persuasion, Streetwise, Mechanics…). Stats gate and accelerate skills (INT = skill XP rate, the Wits role).
- **Origins ARE the classes.** Each origin seeds stats/skills like a D&D class and unlocks an **exclusive perk line** only that backstory can take (the Doctor's surgical perks, the Ex-Con's yard perks, the Cult Escapee's manipulation perks).

### Random Character mode + the Coherence Engine
- **"Deal Me a Life"** button in character creation: generates a coherent whole person — origin, appearance, stats, traits, name, one-line bio ("Doug, 34, former forklift champion, owes everyone money"). Stats are NOT pure random: they're allocated to make sense for the generated person (the buff dockworker rolls high STR, the bookish runaway rolls high INT). **Lock any category and reroll the rest** (keep the origin, spin the stats) until you accept — or play the first deal blind.
- **The Coherence Engine (one table, three jobs):** a single `ArchetypeCorrelation` data table (buff look ↔ high STR, glasses ↔ high INT, suit ↔ wealth, friendly manner ↔ openness…) drives (1) random player generation, (2) generation of all ~200 NPCs, and (3) the Reality Check perception system's guesses. NPCs match their look *because* the same table built them — which is exactly why stereotype-guessing usually works.
- **~10–15% of NPCs are deliberate subversions** — the librarian who boxes, the gangbanger with a philosophy degree. They're what makes Reality Check moments land, and the People Reader perk is how you spot them before the punch gets caught. (Random PCs are never subverted — your own sheet is always truthful; only your reads of OTHERS lie.)

### Body simulation (full)
Weight is a real stat driven by diet. **Fat is a starvation buffer** — a heavy character survives weeks at 0 hunger, a skinny tweaker days — but costs speed, sweat (hygiene drain), and heart-strain risk past a threshold. Muscle (gym, labor jobs) gives carry capacity and fight/intimidation power but raises food costs. The sprite visibly changes. Junk food is cheap and fattening — diet is a poverty mechanic.

### Survival lethality
Needs kill, but scaled by the body sim: starvation burns fat reserves first (telegraphed, multi-day), 0 energy forces collapse (wake up robbed, maybe hospitalized). Death is always foreseeable, never instant.

### Violence: Disco Elysium-scarce guns + the Confrontation system
Guns are RARE and shocking — most violence is fists, bottles, and bats, and **most confrontations end in talking**. Every hostile act (carjack, mugging, break-in, bar fight, getting caught stealing) freezes into a **Confrontation standoff**: both sides pick from fight / flee / beg / threaten / bluff / bribe, resolved by relative stats, weapons shown, relationship, and witnesses. Lose a fight you started and YOU do the begging. NPCs you're beating beg you — mercy/rob/kill is a choice the whole town remembers. A pulled gun ends most standoffs instantly, which is exactly why everyone wants one and almost no one has one.

### The Reality Check system (signature feature #2)
NPCs have TRUE hidden stats. **The UI shows your character's GUESS** — built from appearance stereotypes (buff = strong, glasses = smart, suit = rich, friendly = into you), filtered through your INT/Streetwise and your current state. Drunk, high, or riding a cocky Mood? Displayed odds inflate. Outcomes always resolve against the truth. When reality contradicts the guess hard, a **Reality Check moment** fires: the on-screen odds visibly re-roll and collapse (90% → 0% as the librarian catches your punch), you take an embarrassment Mood hit, and witnesses gossip about it forever ("he swung at the librarian. She put him DOWN"). The unreliable UI is the comedy engine — your character's prejudices and overconfidence are simulated, and the town punishes them. A top-tier perk, **People Reader**, finally shows true stats. Streetwise narrates reads in internal monologue: low skill "He has arms," high skill "Prison tattoos, favors his left knee — walk away."
Carjacking is the flagship gamble: you don't know if anyone's in the car until you open the door, and the guy getting out might be a huge gangbanger whose stats you badly misjudged. Tweaker and Ex-Con start with high Streetwise.

### Substances: real drugs, simulated honestly (à la Schedule I)
Real drug names, ~8 substances, each with distinct REAL effects vs PERCEIVED effects — every substance widens the perceived-vs-real odds gap its own way:
- **Alcohol** — +confidence, −real coordination; the gap = bar fights you can't win. Cheap, legal, everywhere.
- **Weed** — mellow (Mood +, stress −), munchies wreck the food budget, giggle-fits ruin stealth.
- **Meth** — the Tweaker's Need: huge real energy + huge fake confidence, devours body, teeth, and INT over time.
- **Heroin** — bliss (Mood maxed), the hardest addiction track, nodding off in public is a robbery invitation.
- **Cocaine** — rich-district party drug: real energy AND fake competence; expensive enough to be its own poverty spiral; the country club's open secret.
- **Xanax** — calm: erases Nerve/panic checks, slurred dialogue penalty, lethal mixed with alcohol (the game tracks this).
- **LSD** — the perception system goes fully unreliable: NPC reads display as poetry/nonsense; occasional accidental genuine insight.
- **Oxy/pharma opioids** — the Doctor's downfall; stolen from medicine cabinets during burglaries; the respectable addiction.
Tolerance + addiction tracks per substance, prices per district, withdrawal as multi-day debuff gauntlets. Dealing them is the criminal economy's bread and butter; using them is a perception/Mood/body trade the player can feel.

### Health: your body is a save file
Wound types (bruise/cut/fracture/gunshot) heal over real days — badly if untreated: a self-set broken arm heals crooked (permanent DEX penalty) unless a doctor re-breaks it. Scars accumulate and NPCs react. Hospital = great care + crushing bills; back-alley doctor = cheap + risky. **Plastic surgery** buys CHA, removes scars, and at high heat can change your face — witness IDs reset, the ultimate evidence eraser, with a botch risk. **Teeth are tracked**: meth and bar fights cost them, dentures buy CHA back.

### Calendar: fictional holidays with mechanics
GRISTMAS (gift-giving: relationship windfalls, loneliness Mood crashes, retail hell-shift bonus pay) · FOUNDER'S DAY (town fair = pickpocket paradise) · TAX DAY (the audit boss-event for dirty money) · ALL HALLOWS (masks are normal for one night — crime spree night, and the police know it) · ELECTION NIGHT every 2 years. Weekly rhythms: garbage day Thursday (body disposal schedule!), church Sunday, first-of-month rent panic rippling through every poor NPC simultaneously.

### Media: the Gazette + fame/infamy
The Rust Harbor Gazette (paper + phone feed) and a radio DJ narrate the town: your crimes get headlines (anonymous ones get "POLICE BAFFLED"), your business openings get puff pieces, NPC dramas fill page 2. Separate **FAME** (opens doors, kills anonymity — the Athlete starts with it) and **INFAMY** (terrifies witnesses, attracts detectives) meters. The Gazette archive IS the permadeath legacy record — your next character reads about your last one.

### Life Paths: progression that makes sense
The world doesn't hand you a career menu — it enforces **realistic prerequisite chains**, and Paths are the legible map of them. A Path is a discovered checklist in your Journal showing the current blocker ("Cheap apartment requires: ID ✗ · $180 deposit ✓ · no active eviction ✓"). Paths never railroad — they're UI over systemic requirements, and every step is skippable if you find another way (fake ID instead of the records office; lie on the résumé and pray).

**The core paths (each is a `PathDef` .tres chaining generic `RequirementDef`s — has_item / stat ≥ / skill ≥ / money / relationship ≥ / days_clean ≥ / flag):**
- **Getting Off the Street:** shelter intake → the **ID Reconstruction quest** (birth certificate → SSN card → state ID; each step has fees, queues, and opening hours — *bureaucracy as a comedy dungeon*: "Window 3 is closed. Window 3 is always closed.") → shower + presentable clothes → first paycheck → first deposit. The path every T0 origin walks.
- **Recovery (generalizes the Tweaker's arc to all 8 substances):** rock bottom or an **intervention event** (staged by friends/family NPCs who care — being loved has mechanics) → detox: 3–7 days of withdrawal gauntlet → inpatient rehab (28 days, expensive private vs free county *waitlist*) OR white-knuckle cold turkey at home (relapse risk ×3) → weekly meetings (builds a Recovery streak; the church basement, bad coffee) → a **sponsor NPC** (call them when the craving event fires — a real phone-a-friend mechanic) → sobriety chips at 30/90/365 days with permanent willpower bonuses. Relapse triggers stay live forever: stress, the old dealer saying your name, one drink at the office party.
- **Education:** GED night classes → Rust Harbor Community College ($1,200/semester, evening classes that *conflict with work shifts* — the time-budget is the gameplay) → State College degree (unlocks office rung 3+, professional careers) ‖ trade school (cheaper, faster, unlocks Journeyman) ‖ med certs (the existing EMT→Nurse chain). **Student loans** available — the Doctor's $210k is the cautionary tale you can reenact. Campus is a social scene: parties, young-NPC pool, a place the Trust-Fund Kid actually shines.
- **Going Straight (Ex-Con):** parole compliance → 2 years clean → record **expungement** (lawyer $3k + a hearing where your relationships testify — the diner boss who liked you matters) → The Record gate lifts for good.
- **Becoming Real (Cult Escapee):** the You-Don't-Exist version of ID Reconstruction — harder, because first the records office needs proof you were born, and the only proof is *at the compound*.
- **Custody:** the Widowed Parent's Child Services file in reverse — stable housing + income + clean record + caseworker relationship to keep (or win back) your kid.
- **The Club:** social climbing — wealth threshold + a member-sponsor relationship + etiquette + a "donation." Money alone explicitly does not work; that's the joke and the grind.
- **Redemption:** the church path — confession, service, congregation vouching. Slowly launders public *infamy* (not evidence — God forgives; the detective doesn't).

**Mechanics:** paths emit **calendar commitments** (class Tue/Thu 6 PM, meeting Sunday, parole Monday 9 AM) that collide with shifts and each other — life-scheduling pressure IS the mid-game. Every path has a visible dropout/failure state that scars (the family that staged your intervention remembers the relapse). Origins pre-start paths: the Tweaker spawns mid-Recovery-decision, the Ex-Con mid-Going-Straight, the student-aged spawn mid-Education.

### A living town (NPC autonomy + NPC crime)
NPCs walk the same Life Paths you do — the barfly is three meetings into Recovery, the line cook is two semesters from a degree, and you can derail or champion either one. NPCs date, marry, divorce, feud, get promoted, get fired — AND commit crimes. You can witness an NPC mugging and report it, ignore it, or **blackmail the mugger**. NPC criminals compete for turf; NPC victims need the back-alley doctor; the detectives sometimes work cases that have nothing to do with you. The town is a story machine even if you never touch it.

### Politics: the mayor is gameable
An elected mayor NPC sets town policy (police budget = patrol density, tax rate, district cleanup initiatives). Elections every 2 game-years: donate, smear, blackmail, rig — or **run for mayor yourself**, the ultimate late-game status play and dirty-money sink. Murdering the mayor has exactly the consequences you'd expect.

### Work & crime gameplay feel
A mix of time-skip and minigames for both: routine stretches fast-forward, **moments** play out — job shifts fire dilemma popups ("the till is short — rat out Carl / take the fall / pin it on the new guy"), crimes drop into real time with light minigames (lockpick timing, pickpocket timing, stealth approach).

### Dialogue
Stat-gated intent menu with visible odds, Fallout-style: "Persuade 64%: convince him you weren't there." Skills unlock stronger options; failure has real consequences.

### Family pipeline (full, compressed)
Dating → move-in → pregnancy → baby → child → teen → adult. The baby stage is a darkly comic gameplay gauntlet — night feeds wreck energy, daycare costs money, and being a terrible parent writes the kid's adult traits. Stages last days-to-weeks of game time.

### Clothing = status + disguise
Outfits carry a status tier NPCs react to: country club bounces hoodies, landlords judge at the door, suit = interview bonus. Crime layer: janitor uniforms open back doors, ski mask kills witness ID (but wearing one on the street is itself suspicious), bloody clothes are evidence — burn them. The Exec starts with one great suit he can never afford to replace.

### The phone (diegetic hub)
Your phone IS the menu: job-board app, "Plenty of Catfish" dating app, bank, map, texts from NPCs (dealer, mom, parole officer), and a news feed that reports your own crimes back to you. Poverty tiers: no phone → flip phone → smartphone → status-symbol flagship. Dark-web marketplace unlocks via criminal rep.

### Factions (5 joinable, mutually suspicious)
Street gang (crime ladder), the Family of the Radiant Dawn cult, the country-club elite, **the police force** (you can be a cop — including a dirty one), and the homeless community (mutual aid network). Each has rep ranks, perks, exclusive jobs, and enemies; joining one closes doors elsewhere.

### The town: amalgamated cartoon geography (Simpsons Hit & Run style)
Mid-size town, ~150–250 persistent NPCs, every building enterable — and the map is a **compressed caricature of every biome at once**: cross town and you go from desert to alpine snow. Six districts:
- **Desert Flats** — trailer park, truck stop, pawn shop, Big Mickey's lot. The dirt-cheap edge. Tweaker/Prepper country.
- **Alpine Heights** — the rich district is literally UP the mountain: ski lodge, country club, mansions looking down on everyone. The class divide is altitude.
- **Downtown + The Bricks** — dense core: offices, courthouse, police station, casino, dive bars, with the housing projects stitched to its side.
- **The Docks / Swampside** — foggy industrial rot: warehouses, fish plant, smuggling turf, places where bodies go. Gang territory.
- **The Suburbs** — lawns, HOA passive aggression, soccer moms, the most gossip-dense social network in town.
- **The Forest** — woods between districts: hunting, foraging, the Prepper's stash country, shallow graves, and the cult compound somewhere in the trees.

---

## Part 4 — Technical Architecture (Godot 4.4+)

### Folder layout

```
res:// (C:\Users\Biztech\Desktop\game\)
  project.godot
  .gitignore                  # ignore .godot/
  assets/                     # sprites/ tilesets/ audio/ fonts/
  data/                       # ALL game content as .tres resources — adding content = adding files, no code
    origins/  traits/  jobs/  items/  furniture/  schedules/  npc_archetypes/
  scenes/
    main/Main.tscn            # root: world container + UI layer
    world/Town.tscn  world/interiors/   # one scene per building (Apartment01, Diner, PoliceStation…)
    player/Player.tscn
    npc/NPCAgent.tscn         # the visual "puppet" — NOT the NPC itself
    vehicles/Car.tscn
    props/                    # InteractableObject, Door, FurnitureItem
    ui/                       # HUD, CharacterCreation, BuildMode, DialogueBox, InventoryScreen, PauseMenu
  scripts/
    autoload/                 # event_bus, game_clock, content_db, world_state, sim_engine, save_manager, game_flow
    resources/                # origin_def.gd, trait_def.gd, job_def.gd, item_def.gd, furniture_def.gd, schedule_def.gd
    sim/                      # npc_record.gd, needs.gd, memory.gd, relationship.gd, crime_system.gd, economy.gd
    world/  npc/  player/  ui/
```

### Autoload singletons (the only 7 — resist adding more)

| Autoload | Responsibility |
|---|---|
| `EventBus` | Signals only, no state: `hour_passed`, `day_passed`, `crime_committed`, `crime_witnessed`, `money_changed`, `relationship_changed`, `npc_arrived`, `player_entered_location` |
| `GameClock` | Game time, time scale, pause. The **single driver** of all simulation — nothing simulates in `_process(delta)` |
| `ContentDB` | Scans `data/**` at startup, indexes every `.tres` by string id. Read-only definitions |
| `WorldState` | ALL mutable sim state: every `NPCRecord`, player record, economy, property/furniture, wanted level. **This is what gets saved** |
| `SimEngine` | Abstract NPC tick + embodiment manager (spawns/despawns puppets) |
| `SaveManager` | Versioned JSON saves of WorldState + clock to `user://saves/` |
| `GameFlow` | Scene transitions (menu → char creation → world; interiors), new-game setup |

### The four load-bearing patterns

1. **Data/View separation (most important decision in the project).** An NPC is an `NPCRecord` (plain data: needs, money, home, job, schedule, current location, relationships, capped memory list, flags) that *always* exists in `WorldState`. An `NPCAgent` (`CharacterBody2D` scene) is a disposable puppet spawned only when visible. The record is the single source of truth — this one pattern solves performance, save/load, and off-screen simulation at once. Same pattern for furniture.

2. **Custom `Resource` (.tres) files for content; JSON for saves.** `class_name` Resource scripts with `@export` vars give Inspector editing and drag-drop refs. Crucially, origin mechanics activate via **tags on the OriginDef** read by generic subsystems (`tags: ["addiction", "no_papers"]`) — never `if origin == "tweaker"` scattered through code. The Amnesiac literally just gets a random other origin's tag set, hidden.

3. **String IDs everywhere** (`"npc_0042"`, `"loc_diner"`) — never node references. Makes saves and the LOD boundary trivial.

4. **Simulation on GameClock ticks, never `_process` delta.** Fast-forward = bigger tick batches.

### System → Godot mapping (highlights)

- **Town:** `TileMapLayer` nodes (4.3+; not deprecated `TileMap`) — Ground/Roads/Props(Y-sort)/Overhead; physics + nav painted on the TileSet.
- **Interiors:** separate scene per building, loaded via `Door` (`Area2D`) — natural LOD boundary.
- **Pathfinding:** `NavigationRegion2D` baked from tiles + `NavigationAgent2D` on embodied NPCs only. Abstract NPCs "travel" by timer on a location graph — no pathfinding.
- **Smart objects (The Sims' real trick):** `InteractableObject` (`Area2D`) advertises which needs it satisfies (`bed → sleep/energy`). NPC brains pick the best advertiser nearby. Cheap and powerful.
- **Money:** int cents, never floats.
- **Dialogue:** menu-driven first (chat/compliment/insult/ask out/threaten/gift → relationship deltas); adopt the Dialogic addon later if branching dialogue is wanted.
- **Witnesses:** crime fires `EventBus.crime_committed`; embodied NPCs in radius get a line-of-sight raycast check; witnesses gain a `Memory`. Off-screen crime spreads via **gossip ticks** (co-located NPCs share salient memories hourly).
- **Build mode:** ghost sprite snapped via `local_to_map()`, occupancy dictionary, placements stored as data in `WorldState` and spawned on interior load.
- **Day/night:** `CanvasModulate` tinted by hour via a Gradient.
- **Driving:** rotate-and-thrust `CharacterBody2D` — fast-travel-with-steering, not GTA physics.

### NPC simulation at scale (the LOD design)

- **Tier 0 — Abstract (all ~200 NPCs, default):** `SimEngine` ticks every 10 game minutes, staggered ~20 NPCs/frame. Coarse need decay, schedule evaluation, abstract travel timers, wage credits, statistical need satisfaction ("home overnight → energy refills"), relationship drift, memory aging. No nodes, no physics — trivially cheap.
- **Tier 1 — Embodied:** spawned when player shares their location. Player in the diner → embody NPCs whose `current_location_id == "loc_diner"`. On the exterior → embody NPCs within ~1.5 screens (despawn at 2.0 — hysteresis prevents thrash). Cap ~25–30 embodied, prioritized by relationship to player. Abstract NPCs arriving at the player's location spawn at the door — "the cook shows up at 8:55" reads as completely alive.
- Only embodied NPCs witness crimes directly (they're the only ones present); gossip handles the rest.

### Save/load

Versioned JSON in `user://saves/`. Save **only** WorldState + GameClock + player record — definitions are never saved, just string ids. Every record class implements `to_dict()`/`from_dict()` (never `store_var` with objects). `save_version` + migration chain + `dict.get(field, default)`. Load = wipe and rebuild from data. Write `.tmp` then rename; keep a `.bak`. **Build save/load from M1 onward and test it every milestone — bolted-on saves are the classic sim-game project-killer.** The persistent-world permadeath feature falls out of this design for free: death just creates a new player record in the same WorldState.

---

## Part 5 — Prototype Roadmap

Ordered to de-risk the two hardest systems first: abstract↔embodied NPC sim, and saving a mutable world. Sizes relative (M0 ≈ a weekend); each milestone ends **playable with a working save**.

| # | Milestone | Size | Playable test |
|---|---|---|---|
| **M0** ✅ | **Walking skeleton** — DONE: tilemap town, player, GameClock + EventBus, day/night, hunger/energy, HUD, fridge | 1 | Walk, get hungry, eat, watch the sun set ✅ |
| **M1** | **Data pipeline + character creation** — ContentDB; OriginDef/TraitDef/PerkDef/ItemDef resources; creation flow: origin (class) picker → 6-stat D&D point-buy → PZ-style trait budget; **"Deal Me a Life" random mode with lock-and-reroll** (Coherence Engine v1 — the ArchetypeCorrelation table that later drives NPC gen + perception); first SaveManager pass (ironman single slot) | 2.5 | Two builds feel mechanically different; random characters make sense as people; quit/reload works |
| **M2** | **Living NPCs (the big de-risk)** — NPCRecord + personality stats (bravery/greed/civic duty/kindness/chattiness/jealousy/vice + quirks), schedules, SimEngine abstract tick, 3 interiors + doors, NPCAgent puppets + nav, location-based LOD, **F3 debug overlay**, scale 10 → 200 and profile | 3 | Watch diner staff arrive at 8 AM; follow an NPC home; reload mid-day, world resumes |
| **M3** | **Survival economy** — JobDefs (ladder rungs 1–2, all four ladders), shifts → paychecks with dilemma events, shops, inventory, weekly bills/eviction, body sim v1 (weight/fitness from diet), phone v1 (job board, bank), dirty/clean cash split, loan shark, origin hooks v1, **RequirementDef engine + Journal UI + first Life Path (Getting Off the Street / ID quest)** | 3 | Survive a week as a dishwasher; get fat on the dollar menu; conquer Window 3 at the records office |
| **M4** | **Social + perception** — stat-gated dialogue with VISIBLE PERCEIVED odds (Reality Check v1), Streetwise reads, relationship values, Memory + salience, gossip propagation, NPC↔NPC drift, dating, embarrassment events | 2.5 | Swing on someone you misread; watch 90% become 0%; hear about it from a stranger two days later |
| **M5** | **Confrontation + crime + police** — universal standoff system (fight/flee/beg/threaten/bluff/bribe), scarce-weapon combat, crime catalog, CrimeCase/Evidence/witness pipeline, wanted stars, cop brains, jail v1, fence, carjack-gamble v1 | 3 | Try to carjack the wrong car; survive by begging; rob the shop with vs. without witnesses |
| **M6** | **Housing + status** — full housing curve (T0–T5), credit, build/furnish mode, furniture feeds needs, clothing-as-status/disguise system, home quality → mood | 2.5 | Buy the cheap apartment, furnish it, get bounced from the country club for the hoodie |
| **M7** | **Body, substances, family, aging** — persistent wounds/scars/teeth, hospitals + plastic surgery, full 8-drug catalog with tolerance/addiction, **Recovery + Education + Going Straight paths** (calendar commitments colliding with shifts), marriage → pregnancy → baby gauntlet → kid traits, life stages + aging, death → legacy (new character, heir, or Walk Away), vehicles + driving | 4 | Get clean the hard way; live a whole life badly; die; read your own obituary as your kid |
| **M8** | **The living town** — NPC crime + autonomous life events, 5 factions, mayor + elections, the Gazette + fame/infamy + radio DJ, businesses + laundering, murder/bodies/detectives, town fear, holiday calendar, stat drift, remaining origins/perks as data, balance | 4+ | Do nothing for a week and watch the town generate its own news; then run for mayor on dirty money |

Total ≈ 24 units — realistically a 1–2 year solo hobby arc, with a genuinely playable life-sim from M3 onward and each milestone shippable as a dev build.

**Scope guard:** only 3 buildings until M5, ~12 origins shipped incrementally (Off the Bus, Fired Exec, and Tweaker first — they span the difficulty range and exercise the most systems). Content-before-systems is the solo-dev death spiral; the data-driven design means content scales cheaply later.

### Beginner pitfalls to avoid (Godot, this genre)

1. One always-alive scene per NPC — the #1 scaling mistake; use records (Part 4).
2. Simulating in `_process(delta)` — breaks under pause/fast-forward.
3. Starting isometric — fight Y-sort/nav/diamond-grid math from day one for no gain; go top-down square, swap art later.
4. Bolting save/load on at the end.
5. Mutating shared Resources at runtime (defs are read-only; runtime state lives in records).
6. Old-tutorial `TileMap` instead of `TileMapLayer`; hand-placed StaticBody2Ds instead of TileSet physics.
7. Hardcoded node paths — use EventBus / "signal up, call down."
8. Float money.
9. `NavigationAgent2D` foot-guns: set `target_position` once per destination, not every frame; skip avoidance until needed.
10. No git / committing `.godot/`.
11. Skipping the F3 debug overlay — you cannot balance a 200-NPC sim by walking around in real time.

## Part 6 — Economy & Progression (detailed design)

**Calibration:** 1 game day = 24 real minutes at 1×. Monday is bill day. Money is int cents in code; dollars below.

### 6.1 Wealth curve — six housing tiers (`HousingDef` .tres)
| Tier | Housing | Cost | Gate |
|---|---|---|---|
| T0 | Street / shelter cot | free (10 PM curfew, theft risk, hygiene cap) | none |
| T1 | Weekly motel | $120/wk | cash only, no ID needed |
| T2 | Cheap apartment ("the Bricks") | $90/wk + $180 deposit | ID, no active eviction |
| T3 | Decent apartment | $200/wk + $400 deposit | ID + 4 wks employment OR 8 wks clean rent |
| T4 | House | $400/wk rent or buy $90k (20% down) | credit ≥ 50 to buy |
| T5 | Mansion $750k / penthouse $1,500/wk | cash or 30% down | bank relationship, clean money |

**The deliberate poverty trap:** the motel costs MORE per week than the apartment — but the apartment needs $180 up front plus ID. Being poor is expensive; that's the tutorial lesson of the whole economy. Eviction: miss Monday rent → 3-day grace → locked out, deposit gone, belongings held 7 days. The landlord remembers.

### 6.2 Cost of living
Food/day: dumpster $0 (15% sickness, 0% w/ Iron Stomach) → fast food $12 → groceries $7 (needs kitchen + Cooking 1) → restaurant $30 → fine dining $80 (only food satisfying Champagne Taste). Transport: walk free / bus $2 a ride / $800 beater (8%/wk breakdown) / $6k decent / $45k luxury (charisma bonus, theft magnet). Utilities $15–150/wk by tier; unpaid → power off, fridge food spoils. Weekly lifestyle totals: street ~$25 → motel life ~$220 → cheap-apt life ~$175 → decent ~$330 → house ~$680 → mansion ~$1,250.

### 6.3 Legit careers — 4 ladders × 5 rungs (`JobDef` fields: ladder, rung, wage/shift, hours, skill reqs, boss-relationship req, min shifts, event table)
Anchors: entry ≈ $9/hr, mid ≈ $20/hr, high ≈ $40/hr, top ≈ $80/hr.
- **Food Service:** Dishwasher $54/6h → Line Cook $84 → Shift Manager $136 (till-skim crime hook) → Head Chef $200 → Restaurant GM $280 (unlocks buying the diner at a discount). No ID friction at rung 1 — the canonical first job.
- **Office/Corporate:** Data Entry $64/8h → Assistant $96 → Account Manager $176 (embezzlement opportunity) → Dept Head $320 → Regional VP $640 (blocked by the Exec's Blacklist until resolved). VP = mansion in ~5 game-years — the "slow legit" path.
- **Trades/Labor:** Day Laborer $60 CASH NO ID (the Tweaker/Ex-Con on-ramp; limited slots, be there by 7 AM) → Warehouse $88 → Apprentice $144 → Journeyman $240 (license costs $300 + exam) → Master Contractor $400.
- **Medical:** Janitor $66 → Orderly $104 (clean record req) → EMT $168 ($400 cert) → Nurse $288 ($3k program) → Physician Assistant $480 (spotless record). Permanently locked for the Disgraced Doctor — whose Back-Alley Clinic shadow-mirrors it.

### 6.4 Criminal income (2–4× legit hourly at equal tier, with ruin-risk)
| Crime | Expected | Catch math | Sentence |
|---|---|---|---|
| Pickpocket | $9 poor district / $45 rich, ~10 min | 25% − 3.5%×Stealth (floor 5%) | fine / 1–3 days |
| Shoplift + fence | item value × 40% (50% at fence rel 60) | 20% − 2.5%×Stealth, cameras in nice stores | fine 2× / 1–2 days |
| Corner dealing | $40–80/hr standing the corner | 5%/hr undercover roll, 3%/hr rival robbery | 7–21 days |
| Car theft | beater $150 / luxury $5,000 at chop shop | 15% + alarms; hot plates | 7–14 days |
| Burglary | T2 home $80–200, T5 $2,000+; case the schedule first | 15% base, +25% occupied, −3%×Stealth | 5–15 days |
| Armed robbery | register $200–600 + safe; ALWAYS witnesses | 35%; 50% silent alarm = cops in 3 min | 20–40 days |
| Contracts (fixer) | courier $200 → hits $8–15k | per mission | per crime |

Worked example: 3 burglaries/wk at base skill = 39% weekly bust chance; Stealth 6 cuts it to ~18%. Stealth levels are crime's tuition. Crime out-earns work right up until one bad night erases 2–6 weeks.

### 6.5 Dirty money & businesses (the late-game engine)
Crime pays into `cash_dirty` — spends fine on the street, but **can't** buy property or enter the bank (>$500/wk unexplained deposits → audit chain). Businesses launder up to a daily cap for a fee — that's WHY the criminal buys the laundromat. Ladder: Laundromat $25k ($60/day net, $500/day wash) → corner store → pawnshop (you ARE the fence) → diner → auto shop (chop-shop toggle) → bar (fixer HQ) → **casino $400k** ($700/day, $5k/day wash; the Gambler's Itch goes feral inside his own casino). Daily settlement = base × neighborhood × management × condition × (1 − town_fear/200) ± 15%, minus wages. Events: shoplifters, health inspector bribes, robberies (you're on the other side now), rival arson.

### 6.6 Passive money
Bank savings 0.3%/wk, CDs 0.8%/wk locked; loans at 2%/wk need credit ≥ 40. **Big Mickey** the loan shark: anyone, instantly, 20%/wk; enforcement ladder reminder → beating → seizure → kneecap ("corpses don't carry balances"). Stocks-lite (M7): 5 town-fiction tickers, random walk + news events leaked a day early as rumors — befriend an exec for tips; "insider trading is legal here because the SEC is not in this town."

### 6.7 Budget reality check (weekly)
Broke dishwasher: +$270, −$204 → saves $66; one sick day is the margin. Office worker: +$880, −$430 → house in ~40 weeks. Criminal on the rise: $900 dirty → $720 laundered, −$374 (motel because landlords reject The Record) → nets ~$350 while carrying 39% bust risk and a parole officer. The spreadsheet itself argues "go straight or go bigger" — that's the design working.

---

## Part 7 — Crime, Police & Consequences (detailed design)

### 7.1 Crime catalog (`CrimeDef` .tres, ~14 entries)
Severity 1–10 from jaywalking ($20 fine) through pickpocket/shoplift (1–3 days) → burglary (5–15) → armed robbery (20–40) → witness intimidation (25–50, deliberately worse than most crimes it conceals) → **murder (180–365, evidence never decays)**. Fields: severity, heat stars, evidence decay/day, gossip salience, fear contribution, sentence range, bailable.

### 7.2 Heat model: cases + stars
Every crime creates a `CrimeCaseRecord` (even unwitnessed): perpetrator (ground truth) vs **suspect** (what police believe — the gap is where framing and getting-away-with-it live), evidence list 0–100, status UNREPORTED→OPEN→WARRANT→COLD. **Warrant at evidence ≥ 60.** Wanted stars = active warrants (persistent, only cleared by arrest/dismissal/cold) + hot-pursuit stars (cop saw you; decays 1/20 min out of sight). Anonymous crime ≈ evidence 0–20; one confident witness ≈ 40+; caught red-handed = instant 100. Disguise mask ×0.3 ID confidence (but masks on the street are suspicious); Forgettable Face ×0.5; the Athlete's Recognized = floor 0.9 always.

### 7.3 Witness pipeline (the heart of it)
See (LOS + distance band + lighting) → **identify** (id_confidence = visibility × light × familiarity × disguise × traits) → **decide to report** (civic_duty − 50 if they're your friend − fear of you + 40 if they're the victim) → report = evidence. Non-reporters still gossip, and gossip reaching a cop becomes half-confidence evidence — "nobody reported it" ≠ "nobody knows."
**Interventions, in moral escalation order:** befriend (relationship ≥ 60 = they look away) → bribe ($25 × severity × greed factor; civic-duty-80+ NPCs report the bribe itself) → intimidate (vs their bravery; suppressed memories can UN-suppress if you get jailed or they buy a gun) → silence (murder — which spawns a worse case, usually with its own witnesses). Structural dark joke: **the coverup is always one tier worse than the crime.** Case chains (`spawned_by_case_id`) let detectives walk it backwards.

### 7.4 Police = regular NPCs in cop costume
Cops have homes, spouses, lunch orders, patrol `ScheduleDef`s, and a `corruption` stat (town mean 25; one guy at 85). Off-duty cops are civilians with 100 civic duty — robbing the diner where Officer Dan eats pancakes is a self-solving crime. Escalation: question/ticket → arrest attempt (comply-or-flee) → backup radio (SimEngine embodies 2 cops at the district edge) → weapons drawn at ★5/armed player. Corrupt cops become contacts: $100/wk warrant tip-offs, evidence "mishandling" at $150/point (cheap for shoplifting, ruinous for murder — as it should be).

### 7.5 Jail (M5 time-skip → M7 walkable)
Bail = $50 × max sentence days (skipping it spawns a comic bail bondsman). Lawyer $500/$1,500 cuts 30% + dismissal roll below evidence 80. Inside: forced fast-forward with daily events — yard weights (Fitness XP: the prison-physique pipeline), library, kitchen job ($2/day), **and a real social ecosystem**: criminal NPC records are in there with you; contacts made inside persist outside and open the underworld faster than street rep. Meanwhile your outside life rots: rent accrues, relationships decay, Child Services takes the kid. Parole at 50% via the same generic `parole` tag the Ex-Con starts with.

### 7.6 Murder, bodies & detectives
Killing creates a `BodyRecord` with concealment 0–100; hourly discovery rolls scale with location traffic — and the social graph overrides dice (the spouse notices at dinner; the boss sends someone after two missed shifts). Disposal ladder, Coen-brothers tone: leave it (hours) → dumpster (garbage day is Thursday, plan accordingly) → woods burial (5%/wk, hunters) → weighted river (1%/wk; a drought news event can resurface old sins literally) → pig farm $2k → your own casino's foundation. Undiscovered = missing-person case (evidence ceiling 40); the town's loneliest NPC can vanish forever, and one NPC should remark on that.
Two named **detective NPCs** (persistent, promotable, corruptible at very high cost) spend 3 investigation points/day: canvass (pulls NPC memories near the scene — gossip becomes leads), forensics (lab delay 1–2 days), suspect interviews (doorstep visit; alibi = any NPC who remembers seeing you elsewhere ±30 min — the bartender who knows you is an alibi machine; paid liars crack under pressure). Motive (+15) from public feuds. Murder cases never expire; an accomplice flipping in jail reopens them. Framing an innocent (planted weapon + motive) is possible — the game lets you, and lets you live with it.

### 7.7 Murder-hobo equilibrium (`town_fear` 0–100)
Witnessed murder +8, body found +4, robbery +2; decays 1/day. Fear 20: prices +10%, extra patrol. Fear 40: shops shut at dusk, streets empty at night (**fewer witnesses — the careful killer gets a perverse advantage, on purpose**), civilians start carrying. Fear 60: task force, checkpoints, some NPCs move away permanently. Fear 80: armored response, shoot-on-sight at ★5, all business revenue halved — including yours; terror is bad for the casino. A disciplined murder hobo can hold fear under 40 indefinitely: valid, but it's a logistics game — spreadsheet-brained serial killing IS the dark comedy. On death, fear/trauma/graves/vacancies persist into your next character's town; survivor NPCs gain trauma quirks (the jumpy shopkeeper now charges everyone +20%).

### 7.8 Schema & milestone mapping
New resources: `crime_def.gd`, `housing_def.gd`, `business_def.gd`, extended `job_def.gd`; new records: CrimeCase, Evidence, Body, Business, Loan, Parole (all with to_dict/from_dict per the save design); player money splits into `cash_clean / cash_dirty / bank_balance / credit_score`. New EventBus signals: paycheck, rent_due, crime_committed, crime_witnessed, report_filed, warrant_issued, arrest_made, wanted_changed, body_discovered, town_fear_changed, business_day_closed.
Lands in: **M3** bills/eviction + ladder rungs 1–2 + bank/loan shark + dirty-cash split (cheap now, painful later); **M5** crime catalog, witness pipeline, cops, jail v1, fence, bribe/intimidate; **M6** housing T3–T5 + credit; **M7** businesses/laundering, stocks, murder/detectives, town fear, top rungs, legacy inheritance.

---

## Verification

Each milestone has its own playable test (table above). The standing checks every milestone: (1) the game runs from a fresh launch, (2) save → quit → load resumes correctly, (3) the F3 overlay shows all NPCs in sane locations/activities at 1× and max fast-forward. Architecture-critical first verification is M2: 200 abstract NPCs ticking with no frame spikes, and seamless embody/de-embody when walking into the diner.

## First implementation step (when approved)

M0 is done and committed. Start **M1**: `ContentDB` autoload scanning `data/`; `OriginDef`, `TraitDef`, `PerkDef`, `ItemDef` resource scripts; 3 starter origins as .tres data (Off the Bus, Fired Exec, Rock Bottom — they span the difficulty range); character creation flow (origin/class picker → 6-stat point-buy → trait budget screen); wire trait/origin multipliers into the existing `Needs` class (`scripts/sim/needs.gd` already has `decay_multipliers` waiting); first `SaveManager` pass with the ironman single-slot model.
