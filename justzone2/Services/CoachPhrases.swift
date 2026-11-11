import Foundation

/// The coach's phrasebook: written lines for each moment of an interval
/// session, with placeholders filled from the session so numbers are always
/// right. Upbeat and encouraging, but firm. British English.
///
/// Placeholders:
/// - `{n}` this interval, `{next}` the one coming up, `{total}` intervals in the session
/// - `{toGo}` intervals still to come including the next ("4 intervals")
/// - `{left}` intervals after this one ("3 intervals")
/// - `{set}` / `{sets}` set number and count
/// - `{workNoun}` "1 minute", `{rest}` "2 minutes"
/// - `{workTime}` total hard work in the session ("11 minutes")
enum CoachPhrases {

    // MARK: Introduction (greeting + kind + structure + start)

    /// What the session is for, by interval length (see `IntervalCoach.SessionType`;
    /// the categories themselves are never shown).
    static let kind: [IntervalCoach.SessionType: [String]] = [
        .shortSharp: [
            "Short, sharp efforts today. Quick, punchy and full of intent.",
            "Speed and snap today. Every effort brief, every effort sharp.",
            "Short bursts today. Hit them crisply and recover well.",
            "Punchy work today. Bring energy to every single one.",
            "Quick, sharp intervals today. Quality over quantity.",
        ],
        .hard: [
            "Hard intervals today. Tough, honest efforts that lift your ceiling.",
            "Today is properly hard work. Commit to each one and hang tough.",
            "Big efforts today. They're meant to hurt, and they're meant to work.",
            "Hard, high-end work today. Settle into each effort and own it.",
            "A tough session today. Brave starts, strong finishes.",
        ],
        .medium: [
            "Solid, controlled efforts today. Hard, but paced.",
            "Today is about controlled hard work. Even pacing wins.",
            "Strong, sustained intervals today. Find the rhythm and hold it.",
            "Controlled efforts today. Start measured, finish strong.",
            "Steady-hard work today. Patience now pays off later.",
        ],
        .long: [
            "Long efforts today: steady, patient and strong.",
            "Today builds real staying power. Calm mind, steady legs.",
            "Long intervals today. Settle in and make them sustainable.",
            "Sustained work today. The skill is patience.",
            "Long, strong efforts today. This is where endurance is built.",
        ],
    ]

    /// Extra introduction lines for on/off sessions (short work, shorter rest).
    static let kindOnOff = [
        "On/off efforts today. Short hard bits, shorter rests: the work adds up fast.",
        "Micro-intervals today. Rhythm is everything: on, off, on, off.",
    ]

    static let structure = [
        "{total} × {workNoun} today, with {rest} easy between.",
        "{total} × {workNoun}, with {rest} recovery after each.",
    ]
    static let structureSets = [
        "{sets} sets of {count} × {workNoun}, with a longer recovery between sets.",
        "{sets} sets of {count} × {workNoun}, and a proper breather between sets.",
    ]
    static let startWithWarmUp = [
        "Warm up easy for now.",
        "Easy spinning first: the work comes soon.",
        "Use the warm-up well. We'll get going shortly.",
    ]
    static let startNoWarmUp = [
        "No warm-up today: we start straight away.",
        "Straight into it: no warm-up today.",
    ]

    // MARK: Warm-up (midway through it)

    static let warmUp = [
        "Easy does it. Let the legs wake up properly before the work starts.",
        "Loosen off now. The hard part comes later, and you'll be ready for it.",
        "Smooth pedalling, relaxed shoulders. Use this time well.",
        "Settle in and breathe easy. Good preparation makes good intervals.",
        "Nice and light. Let your heart rate rise gently.",
        "This is your time to get ready. Steady, smooth, unhurried.",
        "Spin it out and find your rhythm. The work is coming.",
        "Relax the grip, sit tall, get comfortable. We start soon.",
        "Keep it easy. A proper warm-up pays you back in every interval.",
        "Warming up nicely. Stay patient: the first effort isn't far off.",
        "Get your bottle within reach and your mind on the job.",
        "Breathe deep and loosen the hips. {total} intervals ahead, and you're ready.",
    ]

    // MARK: 10 seconds before an interval

    static let prepareFirst = [
        "Ten seconds. First interval coming up: settle in and get ready.",
        "Here we go. Interval 1 of {total} in ten seconds.",
        "Warm-up done. Ten seconds to the first effort: sit tall and commit.",
        "Get ready. First interval in ten. Smooth and strong from the start.",
        "Ten seconds. Breathe in, relax the shoulders, and go when it starts.",
        "Time to work. The first of {total} starts in ten seconds.",
        "Ready? Ten seconds to interval 1. Start controlled, not frantic.",
        "First effort in ten. You've done the prep, now use it.",
        "Ten seconds to go. Hands relaxed, eyes up, here it comes.",
        "Interval 1 in ten seconds. Let's set the tone.",
    ]

    /// Early in the session (first third).
    static let prepareEarly = [
        "Ten seconds. Interval {next} of {total}: get ready.",
        "Here comes number {next}. Breathe, settle, commit.",
        "Interval {next} in ten. Plenty in the legs: use it well.",
        "Get ready for interval {next}. Smooth and controlled.",
        "Ten seconds to interval {next}. Build the rhythm now.",
        "Next one in ten. Same quality as the first.",
        "Interval {next} coming up. Sit tall, relax the grip.",
        "Ten seconds. Interval {next}: start it the right way.",
    ]

    /// The middle third.
    static let prepareMiddle = [
        "Recovery's nearly done. Interval {next} in ten seconds.",
        "Ten seconds to interval {next}. Same again: smooth and strong.",
        "Interval {next} coming up. Reset and go again.",
        "Back to work in ten. Interval {next} of {total}.",
        "Get ready for interval {next}. You know what to do.",
        "Interval {next} in ten. {toGo} to go, one at a time.",
        "Ten seconds. This is where good sessions are made. Interval {next}.",
        "Here comes interval {next}. Keep the standard high.",
    ]

    /// The last third.
    static let prepareLate = [
        "Interval {next} in ten. Only {toGo} left: stay with it.",
        "Ten seconds. Interval {next} of {total}. The end is in sight.",
        "Here comes {next}. Tired legs, strong mind.",
        "Interval {next} coming up. This is where you earn it.",
        "Ten seconds to interval {next}. Dig in and stay smooth.",
        "Get ready. {toGo} to go. Make every one count.",
        "Interval {next} in ten. You've done the hard part, keep going.",
        "Back to it. Interval {next}: hold your form.",
    ]

    static let prepareFinal = [
        "Last one coming up in ten seconds. Make it count.",
        "Final interval in ten. Everything you've got left, under control.",
        "Ten seconds to the last effort. Finish this properly.",
        "This is it: final interval in ten seconds.",
        "One more. Ten seconds. Let's finish strong.",
        "Last interval coming. Smooth and strong, all the way to the end.",
        "Ten seconds to the final effort. Make it a proud finish.",
        "Final one next. You've earned this. Let's go.",
        "Last interval in ten seconds. Hold your form right to the end.",
        "The final effort starts in ten. Head up, shoulders down, go.",
    ]

    static let prepareNewSet = [
        "Set {set} of {sets} starts in ten seconds. Fresh start, same focus.",
        "Longer recovery done. Set {set} in ten seconds: let's go again.",
        "Ten seconds to set {set}. Reset and commit.",
        "Here comes set {set}. Same quality as before.",
        "Set {set} of {sets} coming up. Settle and go.",
        "New set in ten. Breathe deep, sit tall, here we go.",
        "Ten seconds to set {set}. One interval at a time.",
        "Back to it: set {set} starts in ten.",
    ]

    static let prepareLastSet = [
        "Final set in ten seconds. Let's finish this session properly.",
        "Last set coming up. Everything you've got, under control.",
        "Ten seconds to the final set. Head up, here we go.",
        "This is the last set. Make it your best one.",
        "Final set starts in ten. You've been building to this.",
        "Last set. Ten seconds. Strong start, strong finish.",
    ]

    /// Before the next interval, when this moment is also halfway through the session.
    static let prepareHalfway = [
        "Halfway through the session. Interval {next} in ten seconds.",
        "That's half the work done. Ten seconds to interval {next}.",
        "Halfway there. Reset, then interval {next} in ten.",
        "Past halfway now. Interval {next} coming up: same quality.",
        "Half the session done, and done well. Interval {next} in ten.",
        "We're halfway. Ten seconds, then interval {next}.",
    ]

    // MARK: Lines flavoured by interval length (mixed into the packs above)

    static let prepareByType: [IntervalCoach.SessionType: [String]] = [
        .shortSharp: [
            "Ten seconds. Quick and sharp: interval {next}.",
            "Get ready to hit it. Interval {next} in ten.",
            "Short one coming. Snap into it: interval {next}.",
            "Ten seconds. Crisp start, crisp finish.",
        ],
        .hard: [
            "Ten seconds. Interval {next}: brave start, then hang tough.",
            "Here comes a hard one. Interval {next} in ten.",
            "Interval {next} in ten. It's meant to hurt: stay with it.",
            "Deep breath. Interval {next} starts in ten.",
        ],
        .medium: [
            "Ten seconds. Interval {next}: start controlled, build into it.",
            "Interval {next} coming up. Measured start, even pace.",
            "Get ready. Interval {next}: settle in early.",
            "Ten seconds to interval {next}. Don't go off too hot.",
        ],
        .long: [
            "Ten seconds. Interval {next}: patient and steady from the start.",
            "Long one coming up. Interval {next}: settle in calmly.",
            "Interval {next} in ten. Find your rhythm early and keep it.",
            "Get ready for interval {next}. Steady wins this.",
        ],
    ]

    static let endingByType: [IntervalCoach.SessionType: [String]] = [
        .shortSharp: [
            "Ten seconds! Sharp to the end.",
            "Nearly done. Stay quick, stay strong.",
            "Ten seconds. Keep the snap in it.",
            "Hold it! Crisp finish.",
        ],
        .hard: [
            "Ten seconds! This is the hard bit: hold on.",
            "Ten to go. Hang tough, nearly through.",
            "Hold it! Ten seconds and it's done.",
            "Ten seconds. It hurts because it works.",
        ],
        .medium: [
            "Ten seconds. Finish as evenly as you started.",
            "Nearly done. Hold the pace right to the end.",
            "Ten to go. Controlled to the very last second.",
            "Ten seconds! Strong and even.",
        ],
        .long: [
            "Ten seconds. A long one, done well.",
            "Nearly through this one. Steady to the end.",
            "Ten to go. That's real staying power.",
            "Ten seconds! Patient work, nearly finished.",
        ],
    ]

    // MARK: Halfway through an interval longer than 2 minutes

    static let midEffort: [IntervalCoach.SessionType: [String]] = [
        .hard: [
            "Halfway through this one. It's meant to be hard: stay with it.",
            "Half done. Breathe deep and rhythmic, keep the shoulders low.",
            "Middle of the effort. Stay smooth: the second half is yours.",
            "Halfway. This is where your ceiling goes up.",
            "Half of interval {n} done. Calm face, strong legs.",
            "Good, halfway. Don't fight it, ride it.",
        ],
        .medium: [
            "Halfway through this one. Keep it even.",
            "Half done. Controlled and strong: exactly right.",
            "Middle of the effort. Hold the pace, don't chase it.",
            "Halfway through interval {n}. Smooth breathing, steady legs.",
            "Half of this one done. Keep the pedal stroke round.",
            "Good, halfway. Measured and strong.",
        ],
        .long: [
            "Halfway through this one. Steady, patient, controlled.",
            "Half done. Settle in and hold the rhythm.",
            "You're in the middle now. Calm and steady wins this.",
            "Halfway through interval {n}. Break the rest into small pieces.",
            "Steady now. Halfway there, and doing it well.",
            "Midway. Sit tall, relax the grip, keep it even.",
        ],
    ]

    static let midEffortHalfway = [
        "Halfway through this one, and halfway through the session. Stay steady.",
        "Half of this effort done, and half the session too. Keep it controlled.",
        "Middle of the effort, middle of the session. Smooth and patient.",
        "Halfway point of the whole session. Hold this one steady.",
    ]

    // MARK: 10 seconds before an interval ends

    static let endingEarly = [
        "Ten seconds! Hold it to the end.",
        "Nearly done. Ten more seconds, stay strong.",
        "Last ten seconds of interval {n}. Finish it properly.",
        "Ten to go. Good start to the session.",
        "Hold on, ten seconds left. Nice work.",
        "Ten seconds. Finish clean, then recover well.",
        "Almost there. Ten seconds and recovery is yours.",
        "Ten more. Smooth and strong right to the end.",
    ]

    static let endingMiddle = [
        "Ten seconds! Keep your form.",
        "Final seconds of interval {n}. Strong to the end.",
        "Ten to go. Don't fade now, finish clean.",
        "Nearly there. Ten seconds, then breathe.",
        "Hold it! Ten seconds and that's {n} done.",
        "Ten more seconds. Every one of these counts.",
        "Last ten. Stay smooth, stay strong.",
        "Ten seconds! Good work, keep it going.",
    ]

    static let endingLate = [
        "Ten seconds! Tired is fine: hold it.",
        "Final seconds. Only {left} after this one.",
        "Ten to go. Dig in, you're nearly through the session.",
        "Hold on! Ten seconds and {n} is in the bank.",
        "Ten seconds. Strong finish: the end is close.",
        "Last ten. This is what the work is for.",
        "Ten more. Don't let go now.",
        "Ten seconds! Finish it, then breathe.",
    ]

    static let endingLastInSet = [
        "Ten seconds and set {set} is done. Hold it!",
        "Final seconds of the set. Strong finish, then a proper breather.",
        "Ten to go in this set. Finish it properly.",
        "Last ten of the set. Then you've earned the longer recovery.",
        "Hold it! Ten seconds to the end of set {set}.",
        "Ten seconds. Close the set out strong.",
    ]

    static let endingFinal = [
        "Final ten seconds of the final interval. Bring it home!",
        "Ten seconds left of the hard work today. Finish strong!",
        "Last ten seconds. This is the one, hold it!",
        "Ten seconds to go and you're done. Strong finish!",
        "Final seconds. Everything you've done leads here. Hold it!",
        "Ten to go on the last one. Proud finish!",
        "Nearly finished! Ten seconds, stay strong.",
        "That's the last ten seconds of work today. Hold your form!",
        "Ten seconds and the work is done. Keep going!",
        "Final push to the end. Ten seconds!",
    ]

    static let endingHalfway = [
        "Ten seconds, and that's halfway through the session. Hold it!",
        "Finish this one strong: it takes you past halfway.",
        "Ten more seconds and half the work is done. Stay strong.",
        "Hold it for ten. Halfway through the session after this one.",
        "Nearly done, and nearly halfway. Ten seconds!",
        "Ten seconds to the halfway mark. Keep your form.",
    ]

    // MARK: Cool-down

    static let warmDown = [
        "That's the hard work done. Spin easy and let the heart rate settle.",
        "All intervals complete. Ease right off and breathe.",
        "Done! Now the cool-down: light legs, slow breathing.",
        "Brilliant. Keep pedalling gently and let your body recover.",
        "Work's done. Sit up, relax, spin it out.",
        "Every interval completed. Enjoy the easy spin.",
        "That's it for the hard part. Let the legs flush out.",
        "Great session. Easy pedalling now, nothing more.",
        "Finished the work. Shoulders down, breathe slowly, spin easy.",
        "All done with the efforts. Cool down properly: it's part of the session.",
        "Have a drink and spin easy. You've earned this bit.",
    ]

    static let wrapUp = [
        "{total} intervals done: {workTime} of hard work, well ridden.",
        "Session complete: {total} intervals, every one finished. Well done.",
        "That's {total} out of {total}. Strong, consistent work today.",
        "Job done. {workTime} of quality work in the bank.",
        "Great work today. {total} intervals, completed with control.",
        "Finished! {workTime} of hard efforts. That's how you get fitter.",
        "All {total} intervals done. Be proud of that one.",
        "Well ridden. {total} efforts, all completed. Rest well.",
        "That's the session: {workTime} of work, done properly.",
        "Brilliant work. Recover well and come back stronger.",
    ]

    static let wrapUpSets = [
        "All {sets} sets done: {total} intervals, {workTime} of work. Superb.",
        "{sets} sets, {total} intervals, every one finished. Well ridden.",
        "That's {sets} sets in the bank. Proper session.",
        "Every set completed. {workTime} of quality work today.",
    ]

    // MARK: Labels shown before each message

    static let tags: [String: String] = [
        "intro": "WELCOME",
        "plan": "TODAY'S PLAN",
        "warmUp": "WARM-UP",
        "prepare": "GET READY",
        "prepareFinal": "LAST ONE",
        "prepareNewSet": "NEW SET",
        "halfway": "HALFWAY",
        "ending": "NEARLY THERE",
        "endingFinal": "FINAL PUSH",
        "warmDown": "COOL-DOWN",
        "wrapUp": "WELL DONE",
    ]
}
