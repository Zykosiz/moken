# Moken — Opening Scene (Vertical Slice)

Placeholder dialogue throughout — meant to be refined, not final. Character names in brackets are placeholders where nothing's been locked yet. Technical notes flag what each beat needs from existing or new systems.

**Relationship note:** Vyla and Zako are close lifelong friends, not a romantic pairing. She represents his home, community, and the ordinary life that is shattered in the opening. The game's slow-burn romance belongs later, with a visibly cursed woman who becomes part of his found family.

**Cast:**
- **Zako** — protagonist, new lighthouse keeper
- **[Vyla]** — village girl and Zako's close lifelong friend; placeholder name, easily swapped
- **[Old Keeper — "Halvard"?]** — the outgoing lighthouse keeper, placeholder name
- **Pirate Captain** — antagonist for this scene only

---

## Beat 1 — Wake Up (black screen, dialogue only)

*No background needed yet — full black, dialogue box only. Uses existing DialogueManager, no new system required.*

**[Vyla]:** Zako. Zako, wake up — it's happening today.

**Zako:** ...What time is it.

**[Vyla]:** Late enough that if you don't get up, I'm telling Halvard you slept through your own promotion.

**Zako:** He'd probably just find that fitting.

**[Vyla]:** Get dressed. I'll be outside.

*(Fade from black begins here — screen stays dark a moment longer before beat 2.)*

---

## Beat 2 — Outside the House (still minimal background, dialogue continues)

*Can remain a mostly-dark or simple background — doesn't need the full rendered island yet if that's easier. Technical: this is still DialogueManager, just with a change of "scene" implied through a line or a simple background swap, not necessarily real 3D space yet.*

**[Vyla]:** There he is. Lighthouse Keeper Zako. Doesn't have the same ring as just "Zako," does it?

**Zako:** Give it time. Maybe it'll grow on both of us.

**[Vyla]:** Come on — everyone's going to want to see you off. Well. Not *everyone*. But some people.

**Zako:** That's reassuring.

**[Vyla]:** It's a bit of a walk from here to the lighthouse, you know. Halvard picked the one house on the island furthest from his own front door.

**Zako:** Sounds like something he'd do on purpose.

**[Vyla]:** Knowing him? Absolutely on purpose.

---

## Beat 3 — The Walk to the Lighthouse (real spawn, player-controlled)

*Technical: this is where the player actually spawns into the live 3D world for the first time — reuse PlayerTerrainSpawn logic, just as a cutscene entry point rather than a save load. Camera/control handoff from dialogue-only to player-controlled movement happens here. This beat is now a proper walk-and-talk — dialogue plays out over real traversal rather than a single line.*

*(Player gains control, walking alongside Vyla toward the lighthouse. Several lines exchanged along the way — casual, unhurried, gives the island room to feel lived-in before anything happens to it.)*

**[Vyla]:** So. Nervous?

**Zako:** Should I be?

**[Vyla]:** Halvard's been doing this since before either of our parents were born. He's going to expect a lot from you.

**Zako:** Comforting.

**[Vyla]:** I just mean — he wouldn't have picked you if he didn't think you could handle it. He's not exactly generous with his approval.

**Zako:** Is that supposed to help?

**[Vyla]:** A little. Take what you can get.

*(A beat of quiet walking. Then—)*

**[Vyla]:** You know, most people who take this job aren't from here. They get sent. You actually asked for it.

**Zako:** Is that strange?

**[Vyla]:** A little. But it's good. This place needs someone who actually knows the people living here.

**Zako:** I like it here. More than I expected to, honestly.

**[Vyla]:** Then you'll fit right in. None of us know why we stay either.

*(Their closeness should feel familiar and lived-in, without romantic framing. Vyla is part of the community Zako belongs to, not a lost-love setup.)*

**Zako:** It's strange, though. Keeper of the light, and I'm still on the same island as everyone. I half expected it to feel like leaving.

**[Vyla]:** You're not going anywhere. You're just... up a hill now.

**Zako:** Up a hill now. I'll put that on the door.

**[Vyla]:** And if the hill ever gets lonely, come back down. That's where everyone else is.

**Zako:** Hard to argue with that.

**[Vyla]:** Anyway — don't let Halvard scare you. He's all bark. Mostly.

**Zako:** "Mostly" is doing a lot of work in that sentence.

**[Vyla]:** You'll survive. Probably.

*(They arrive at the lighthouse.)*

---

## Beat 4 — Arrival at the Lighthouse

**[Vyla]:** Halvard! He's up. Barely.

**[Halvard]:** *(to Zako)* Punctual as ever, I see.

**Zako:** I'm here, aren't I.

**[Halvard]:** Barely counts. Come inside — we've got a lot to go over before I'm anyone's problem but yours.

**[Vyla]:** That's my cue. I've got things to do that don't involve listening to two lighthouse keepers talk about *maintenance schedules*.

**[Halvard]:** Go on, then.

**[Vyla]:** See you at dinner, Zako. Everyone wants to hear how badly the first day goes.

**Zako:** I'll try not to disappoint them.

*(Vyla exits. The exchange should feel warm and familiar, but entirely platonic.)*

---

## Beat 5 — The Keeper's Philosophy

**[Halvard]:** Sit. Before we get to the mechanical part, I want you to understand why this matters — because if you only ever see it as a job, you'll do it like one.

**Zako:** I'm listening.

**[Halvard]:** People out there — sailors, traders, whoever's lost their bearings in the dark — they don't see the island. Not at first. They see the light. It's the only thing telling them there's still a way home.

**[Halvard]:** You keep that light burning, and somewhere out there, someone stops being afraid. That's the whole job. Everything else is just upkeep.

**Zako:** That's... a lot more than I expected from an orientation.

**[Halvard]:** Get used to disappointment. Now — the oil reserves are kept—

*(Interrupted — this is where the pirate attack begins. See Beat 6.)*

---

## Beat 6 — Pirates Attack (scripted, not real combat)

*Technical: this is the first beat needing real cutscene/timeline tooling — camera control, forced NPC positions/reactions, no player combat input. Distant shouting/alarm as a lead-in works well here before anything is shown.*

**[Halvard]:** *(standing, alert)* That's not a drill bell.

*(Cut to: pirates landing/attacking the village below. Zako and Halvard react, move to intervene — still cinematic, no player input.)*

**[Halvard]:** Stay back if you can, Zako — I mean it.

*(He doesn't stay back either. Halvard moves to protect villagers directly.)*

---

## Beat 7 — Halvard is Shot

*(The Captain confronts Halvard. Brief, brutal — no drawn-out fight, this should land fast and hard.)*

**Captain:** Out of my way, old man.

**[Halvard]:** *(stepping between the Captain and villagers)* Not today.

*(The Captain shoots him. Halvard falls.)*

**Captain:** *(to the crowd, boastful)* Anyone else?

---

## Beat 8 — The Girl's Grief, The Threat

**[Vyla]:** *(crying out, running toward Halvard)* No — no, no—

**Captain:** *(turning toward her)* Keep crying, girl, and you'll be next.

---

## Beat 9 — Zako Reaches Her

*(Zako moves — first real active choice-coded moment in the scene, even though it's still scripted. He gets to her before the Captain acts further.)*

**Zako:** *(quiet, pulling her into him)* Don't worry. It's gonna be alright.

**[Vyla]:** *(shaking, barely audible)* I'm scared.

*(He holds her. This is protective friendship and shared terror, not romantic framing. Zako knows his reassurance is a lie, but says it because she needs to hear it.)*

---

## Beat 10 — The Sky Turns

*Technical: the world-lighting state change starts here — this is new work, no existing system covers "sky and sea go black." Likely a WorldEnvironment/skybox override triggered by the cutscene script.*

*(No dialogue. The sky darkens unnaturally. The sea goes black. Something is coming.)*

---

## Beat 11 — The Horror Arrives

*(The Horror emerges. It moves through the pirate crew first — implied/stylized rather than graphic, per the game's tone.)*

*(The Captain, cornered, fires at it. Nothing happens — no effect at all.)*

**Captain:** *(first real fear)* What—

*(The Horror takes him. No line needed — the silence sells it.)*

---

## Beat 12 — Vyla and the Gun

*(Vyla breaks from Zako — unscripted-feeling but still cinematic — reaches for the fallen pistol, fires at the Horror.)*

*(Nothing happens.)*

*(The Horror takes her too — gun still in hand.)*

**Zako:** *(one word, breaking)* Vyla—

*(This is the first time her name is spoken aloud by any character in the scene. The dialogue UI may identify her as [Vyla] beforehand, but no one says her name until Zako realizes she is gone.)*

---

## Beat 13 — The Gun Returns

*(The Horror spits the pistol back out — changed. Black. Faintly glowing.)*

*(It turns toward Zako.)*

---

## Beat 14 — Zako Fires

*(Pure panic, not heroism. He grabs the gun, fires on instinct.)*

*(The Horror screams and flees.)*

---

## Beat 15 — Aftermath

*(Silence. The sky and sea begin to clear — but only over the island. The sea beyond stays black.)*

*(Zako doesn't speak. He's in shock — holding a gun that wasn't his, standing in a village that's lost two people who mattered to him in the same five minutes.)*

*(No dialogue needed here. This beat is about restraint — let the silence do the work.)*

*(Fade to black.)*

*(Time skip — later.)*

---

## Open Notes / Things to Decide Later

- Vyla's ultimate fate is not locked by the romance decision. The opening will need a separate rewrite if she survives under the newer star-sea concept.
- Whether Halvard's death includes any final word to Zako, or stays as abrupt as written (abrupt may be more honest to the tone)
- Confirm placeholder names before this becomes real content in dialogue resources — "Vyla" and "Halvard" are just working names
- Camera direction/blocking specifics are intentionally left loose here — this doc is the dialogue/beat skeleton, not a full shot list
