# Painted art: portraits and scenes

Part of the art pass the owner put first (10 Nov 2026). The game draws its ships, flags, structures and harbour towns in code; faces and scenes are painted images dropped into the project. The owner first chose his own Qwen image skill, which runs on his machine; as it cannot be reached from a cloud session he then asked for Canva's image generator, and left the style to the agent. The 24 portraits and 12 scenes in the project were made that way on 10 Nov 2026 from the prompts below, exported through a holder design ("Game art export sheet" in his Canva account) and saved as JPEG; the ensign in `flag.jpg` was recoloured by hand because it came out as a red cross on white.

## How it works

- `godot/assets/portraits/*.jpg` (any number): each officer is given one at random and keeps it (`face` on the officer, saved). Shown beside officers in Command and in port. With no files there are no portraits.
- `godot/assets/scenes/<key>.jpg`: a banner across the top of a panel when the file exists. Wired now: `victory`, `defeat`, `disengaged` (the aftermath), `port` and `capital` (a harbour's panel), `bomb` (after a nuclear strike). Prepared for later: `contact`, `storm`, `landing`, `survey`, `flag`, `title`.
- Code: `godot/scripts/art.gd` (finds the files), `world_map._banner` and `_face` (show them). PNG, JPG or WebP.
- After adding files: `godot --headless --path godot --editor --quit` to import them, then export as usual. Commit the images (and Godot's `.import` files beside them).

## The style

Painted naval illustration in muted gouache and ink wash, in the manner of 1940s war artists' sketchbooks: visible brushwork, soft edges, restrained detail. Palette of slate blue, dark teal, grey and bone white with small accents of brass gold and signal red. Overcast northern light. No text, no lettering, no numbers, no flags or insignia of any real country or navy, no photographic realism, no modern objects.

Why: it sits with the chart's dark teal and gold interface and the Rule the Waves plan-view ships without competing with them, it suits 1946, and loose brushwork hides the small inconsistencies between generated images better than a polished realistic style would.

## The prompts

Every prompt, with its file name and size, is in `tools/art_prompts.json` (`portraits`: 24 at 768x960; `scenes`: 12 at 1536x640; `negative` for generators that take a negative prompt). Generate each to its `file` path. Keep one seed family or one sitting for the portraits so they match; regenerate any that show lettering or a real flag.

| File | Subject |
| --- | --- |
| `p01.jpg` | weathered man in his fifties, grey moustache, peaked cap, dark blue greatcoat with the collar up; stern |
| `p02.jpg` | woman in her thirties, dark hair pinned under a naval cap, navy reefer jacket; calm and watchful |
| `p03.jpg` | young man in his twenties, clean-shaven, fair hair, white polo-neck jersey under an oilskin; eager |
| `p04.jpg` | heavy-set man in his forties, black beard, knitted watch cap, duffel coat; amused |
| `p05.jpg` | lean man in his sixties, white hair, deep-lined face, old-fashioned frock uniform; tired and proud |
| `p06.jpg` | woman in her forties, short grey-streaked hair, binoculars on a strap, bridge coat; appraising |
| `p07.jpg` | man in his thirties, East Asian features, neat dark uniform with a high collar, peaked cap; composed |
| `p08.jpg` | man in his forties, South Asian features, trimmed beard, white tropical uniform, cap under his arm; courteous |
| `p09.jpg` | woman in her twenties, West African features, cropped hair, engineer's boiler suit with rolled sleeves, grease on one cheek; confident |
| `p10.jpg` | man in his fifties, Mediterranean features, olive skin, unshaven, open-necked shirt and battered cap; sardonic |
| `p11.jpg` | man in his thirties, scar across one eyebrow, leather jerkin over a jersey, no cap, wind-blown hair; hard |
| `p12.jpg` | woman in her fifties, silver hair in a bun, immaculate dark uniform, reading glasses pushed up; severe |
| `p13.jpg` | man in his twenties, freckled, red hair, signalman's cap, scarf; nervous |
| `p14.jpg` | man in his forties, Pacific islander features, broad shoulders, plain khaki uniform; steady |
| `p15.jpg` | old man, bald, hooded eyes, heavy fur-collared coat, pipe; unreadable |
| `p16.jpg` | woman in her thirties, East Asian features, flying jacket with a sheepskin collar, goggles pushed up; bold |
| `p17.jpg` | man in his thirties, dark skin, wire-rimmed glasses, gunnery officer's duffel coat, notebook in hand; exact |
| `p18.jpg` | man in his fifties, grey stubble, eye patch, merchant captain's shabby blue jacket; wary |
| `p19.jpg` | woman in her forties, Nordic features, blonde plait, white roll-neck and oilskin; cold |
| `p20.jpg` | young man, Latin features, thin moustache, dress uniform slightly too large; vain |
| `p21.jpg` | man in his forties, Central Asian features, fur hat, greatcoat, cigarette; patient |
| `p22.jpg` | woman in her sixties, lined brown face, headscarf under a pilot's cap, heavy cardigan; shrewd |
| `p23.jpg` | man in his thirties, bandaged hand, torn collar, smoke-stained face; grim |
| `p24.jpg` | man in his fifties, round spectacles, academic's tweed under a naval coat, slide rule in the pocket; absent-minded |
| `scenes/victory.png` | A squadron of grey warships steaming away in line at dusk, a pall of black smoke and an oil slick astern where an enemy ship has gone down, signal flags going up, gulls |
| `scenes/defeat.png` | A warship sinking by the stern at dawn, crew in boats and on rafts in a grey swell, smoke drifting low, the horizon empty |
| `scenes/disengaged.png` | A damaged destroyer making smoke and turning away at speed, shell splashes falling short astern, heavy sky |
| `scenes/port.png` | A small working harbour seen from the mole: cranes, sheds, a coaster and two destroyers alongside, fishing boats, wet cobbles, lamps coming on at dusk |
| `scenes/capital.png` | A great naval harbour seen from a hill: a battleship and cruisers at anchor in the roads, dockyard cranes, a city of stone and smoke behind, low sun through cloud |
| `scenes/contact.png` | Seen from a ship's bridge wing in poor light: dark shapes of unknown warships on the horizon, lookouts with binoculars, a signal lamp flashing |
| `scenes/storm.png` | A destroyer burying her bow in a huge grey sea, spray over the bridge, sky nearly black, one gull |
| `scenes/landing.png` | Landing craft running in to a beach under a headland, troopships offshore, smoke on the shore, grey morning |
| `scenes/survey.png` | Divers' boats moored over a half-sunken wreck on a reef, rusted upperworks above the water, calm green shallows, an abandoned pier |
| `scenes/flag.png` | A new ensign being run up over a harbour fort at sunrise, a small crowd on the quay, warships dressed overall in the roads |
| `scenes/bomb.png` | A towering mushroom cloud over a distant coast seen from the sea, a submarine's conning tower in the foreground, the sea glassy and lit orange |
| `scenes/title.png` | A lone destroyer under a vast overcast sky on a slate sea, a distant coast and a thin line of light on the horizon, wide and empty |
