# services/alert_messages_en.py

ALERTES_EN = {
    1: ("Frontal collision", [
            "Easy there! Frontal collision incoming. Slow down!",
            "Heads up! Frontal collision detected. Not the time to play bowling.",
            "BAM! Frontal collision coming. Brake like your life depends on it.",
        ]),
    2: ("Pedestrian detected", [
            "Pedestrian! They're crossing like they own the road, watch out.",
            "Oh a pedestrian! Slow down, you don't want to end up at the police station.",
            "Pedestrian ahead! Slow down or you'll kiss them with your bumper.",
        ]),
    3: ("Lane departure", [
            "Hey! You left your lane. Trying to drive on the sidewalk?",
            "Lane departure! Wake up, the road isn't a slalom course.",
            "You're zigzagging! Stay in your lane, Michael Schumacher.",
        ]),
    4: ("Virtual bumper", [
            "Virtual safety zone! Your bumper is about to kiss an imaginary wall.",
            "Virtual bumper detected! Slow down before touching the invisible.",
            "Safety zone ahead. Imagine a wall, now slow down.",
        ]),
    9: ("Phone while driving", [
            "Put down that phone! The road isn't TikTok.",
            "Phone detected! Want a like or an accident?",
        ]),
    10: ("Cigarette detected", [
            "You smoking? Look, even the car is coughing!",
            "Smoking while driving? That's for when you're parked, champ.",
            "Smoking kills... especially when you miss the truck coming at you.",
        ]),
    11: ("Distraction", [
            "Daydreaming? Look at the road before you end up in the scenery.",
            "Distraction detected! Are you driving or watching Netflix?",
            "Hey, up there! The road is ahead, not in your thoughts.",
            "Wake up! Guardian angels aren't on strike but they're getting tired.",
        ]),
    12: ("Fatigue detected", [
            "Your eyes are blinking like hazard lights. Stop and sleep.",
            "Fatigue detected! Naps are for parking lots, not highways.",
            "You're tired bro! Pull over before taking a permanent nap.",
            "Eyelids heavy? Then stop, you're not Superman.",
        ]),
    14: ("Seatbelt unbuckled", [
            "No seatbelt? Want to end up as human origami? Click-click!",
            "Seatbelt not fastened! Buckle up or prepare for takeoff.",
            "The seatbelt isn't just for decoration. Buckle it now.",
            "Buckle up! The road is nice but it doesn't joke around.",
        ]),
    17: ("Vehicle started", [
            "Vroom! Here we go. May the best (or worst) win.",
            "Vehicle started! Buckle up, it's gonna shake.",
            "Engine on. Let's go, easy on the gas.",
            "Here we go, we're moving. Stay awake, this can take a while.",
        ]),
    18: ("Vehicle stopped", [
            "Stop. Let's get out. Put away your cap, champ.",
            "Vehicle stopped. Turn off the engine and breathe.",
            "Break time. Stretch, you'll need it for what's next.",
        ]),
    22: ("Over speed", [
            "Slow down, Flash McQueen!",
            "The radar is gonna love you if you keep this up.",
            "In a hurry to get to heaven or the bakery?",
        ]),
    23: ("Sudden acceleration", [
            "Rocket-style acceleration. This isn't Cape Canaveral.",
            "Sudden acceleration! Got a private jet under the hood?",
            "Easy on the gas, it's a car, not a missile.",
            "Heavy foot detected! The engine is crying, stop crushing it.",
        ]),
    24: ("Sudden braking", [
            "Whoa! You braked like you saw a ghost.",
            "Sudden braking! Did you see a mouse or something?",
            "BAM on the brakes! Forgot you have brakes or just testing them?",
        ]),
    25: ("Sudden turn", [
            "Sudden turn! Thought this was an F1 circuit?",
            "Easy in the turn, you're not Sébastien Loeb.",
            "Want to drift? Rent a track, not the public road.",
        ]),
    29: ("Prolonged idle", [
            "Taking a nap? Move or park properly.",
            "Prolonged idle! Waiting for a package or what?",
            "Move or turn off the engine, but decide already.",
            "You're parked without being parked. Move or turn off the ignition.",
        ]),
    30: ("Collision detected", [
            "BAM! You hit something. Your bumper says 'ouch'.",
            "Collision detected! Wanted to test how solid the wall is?",
            "Ouch ouch ouch! You crashed. Call for help or a miracle.",
            "You hit something. Hope it wasn't a human.",
        ]),
    32: ("Low battery", [
            "Battery is tired. Like you on Monday morning.",
            "Low battery! Recharge quickly or you'll end up stranded.",
            "I've got no energy left. Plug me in or I'm going on strike.",
        ]),
    33: ("Battery dead", [
            "Battery dead. Call someone, or pray.",
            "Battery drained! Did you leave the lights on?",
            "No electricity. Go get some jumper cables or friends.",
            "Dead. Like a phone without a charger. Call roadside assistance.",
        ]),
    34: ("Alternator failure", [
            "The alternator is on strike. Support the electrical protest.",
            "Alternator failure! The battery is gonna cry.",
            "Alternator dead. The car is living its last moments.",
            "The alternator isn't charging anymore. Your car is in survival mode.",
        ]),
    36: ("Engine failure", [
            "Engine KO. It went to see if the grass is greener elsewhere.",
            "Engine failure! The heart of the car is giving up.",
            "Engine dead. Call a tow truck.",
            "The engine says stop. It doesn't want to know anything anymore.",
        ]),
    37: ("Engine overheating", [
            "Engine in sauna mode. Let it cool before it explodes.",
            "Engine overheating! Stop or you'll make pancakes.",
            "The engine is boiling. Open the hood, not the windows.",
            "Smoke under the hood! This isn't a barbecue.",
        ]),
    38: ("Misfire", [
            "Misfire! Engine is sick, go see a mechanic.",
            "Coughing under the hood. Did you catch a cold?",
            "A spark plug died. Go change it before it gets angry.",
        ]),
    39: ("Engine stalled", [
            "Engine stalled. Restart before it gets depressed.",
            "Engine stalled! Forgot the clutch, rookie.",
            "It's dead, it stopped. Try again.",
            "Stalled! Like a candle. Restart gently.",
        ]),
    40: ("Low oil pressure", [
            "Low oil pressure. I'm about to faint.",
            "Low oil pressure! Stop quickly before it seizes up.",
            "The oil is too low. Like my patience.",
        ]),
    41: ("Oil leak", [
            "Oil leak. I'm crying, wipe me quickly.",
            "Oil leak detected! There's a stain underneath, take a look.",
            "The oil is leaking. It's not a fountain, plug the hole.",
            "There's oil on the ground. Is it me or the car before?",
        ]),
    42: ("Critical oil level", [
            "Critical oil level! Add oil or change the car.",
            "The oil is at rock bottom. Haven't checked since 2020?",
            "Oil almost empty. Fill up quickly or goodbye engine.",
        ]),
    43: ("Transmission failure", [
            "Transmission lost. It doesn't know if it should go forward or think.",
            "Transmission failure! Gears are about to get blurry.",
            "Transmission sick. Go see a specialist.",
            "The transmission is coughing. Go to the mechanic quickly.",
        ]),
    44: ("Clutch slipping", [
            "Clutch slipping! You pushed too hard, it's slipping.",
            "The clutch is as smooth as soap. Replace it.",
            "The clutch is slipping. You feel the revs going up without moving forward.",
        ]),
    45: ("Shifting error", [
            "Looking for 3rd gear? It went on vacation without you.",
            "Shifting error! Thought it was automatic?",
            "Wrong gear. Learn to drive again.",
            "Incorrect gear. The gearbox is lost, so are you.",
        ]),
    46: ("Brake failure", [
            "BRAKES FAILURE. Pray or brake with your foot like in cartoons.",
            "Brake failure! Stop with a wall if you want to live.",
            "No brakes. Start praying or coast slowly.",
            "Brakes out of service. Use the handbrake or pray.",
        ]),
    48: ("High brake wear", [
            "Your brakes are thinner than a slice of ham. Replace them!",
            "High brake wear! In 200 km you'll have nothing left but the cable.",
            "Pads dead. Change quickly or you'll hit something.",
            "Critical brake wear. Go change them before you hit the wall.",
        ]),
    49: ("Sudden stop", [
            "Stop like an invisible wall. The seatbelt held your soul.",
            "Sudden stop! Did you see a cat crossing or what?",
            "You braked like the road was ending. Calm down.",
            "Emergency stop. Behind you, they almost kissed your bumper.",
        ]),
    50: ("Puncture detected", [
            "Flat tire. You're driving on air... except there's none left.",
            "Change your tire before it falls apart.",
            "Flat tire. Did you hit a pothole or a dinosaur?",
            "Flat tire. Felt the car pulling? That's why.",
        ]),
    51: ("Low fuel", [
            "Low fuel! Next station is in your pocket.",
            "Empty tank. Go to the pump before you start pushing.",
            "Gas finished. The nearest station, you're about to know it well.",
        ]),
    52: ("General overheating", [
            "Your car is in pizza oven mode. Open the windows, not the hood.",
            "General overheating! Everything is hot, stop quickly.",
            "Everything is heating up. Stop before the fire.",
        ]),
}