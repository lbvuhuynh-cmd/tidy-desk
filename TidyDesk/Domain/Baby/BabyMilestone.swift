import Foundation

/// A "first" in the baby's life. Reached automatically when the baby turns `month` months old, celebrated with a
/// card, and kept as a page in the Baby Book. Ids are stored in `BabyProfile`, so never rename one.
struct BabyMilestone: Identifiable, Equatable, Hashable {
    let id: String
    let month: Int
    let emoji: String
    let title: String
    /// `{name}` = the baby's name, `{word}` = the first word the player picked.
    let caption: String

    var stage: BabyStage { .stage(forMonths: month) }

    func caption(name: String, firstWord: String) -> String {
        caption
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{word}", with: firstWord.isEmpty ? "Mama" : firstWord)
    }
}

enum BabyMilestones {
    /// The milestone where the player picks what the baby says.
    static let firstWordId = "first_word"
    /// One-tap choices for the first word (kids who can't type still get to choose).
    static let firstWordChoices = ["Mama", "Papa", "Nana", "Hi!", "Duck!", "Yum!"]

    /// In age order.
    static let all: [BabyMilestone] = [
        BabyMilestone(id: "hello", month: 0, emoji: "👶", title: "Hello, Little One", caption: "Welcome home, {name}!"),
        BabyMilestone(id: "first_gaze", month: 1, emoji: "👀", title: "First Gaze", caption: "{name} looked right at you."),
        BabyMilestone(id: "first_smile", month: 2, emoji: "😊", title: "First Smile", caption: "A big gummy smile!"),
        BabyMilestone(id: "first_giggle", month: 3, emoji: "😆", title: "First Giggle", caption: "{name} laughed out loud!"),
        BabyMilestone(id: "rolled_over", month: 4, emoji: "🔄", title: "Rolled Over", caption: "From tummy to back. Whee!"),
        BabyMilestone(id: "grabbed_toy", month: 5, emoji: "✋", title: "Grabbed a Toy", caption: "Tiny hands, strong grip."),
        BabyMilestone(id: "sits_up", month: 6, emoji: "🙌", title: "Sitting Up", caption: "{name} sat up all alone!"),
        BabyMilestone(id: "first_tooth", month: 7, emoji: "🦷", title: "First Tooth", caption: "A tiny tooth popped up."),
        BabyMilestone(id: "first_crawl", month: 8, emoji: "🐾", title: "First Crawl", caption: "Off to explore the rug!"),
        BabyMilestone(id: "stands_up", month: 10, emoji: "🧍", title: "Stood Up", caption: "Holding on and standing tall."),
        BabyMilestone(id: firstWordId, month: 11, emoji: "🗣️", title: "First Word", caption: "{name} said “{word}”!"),
        BabyMilestone(id: "birthday_1", month: 12, emoji: "🎂", title: "First Birthday", caption: "One whole year of {name}!"),
        BabyMilestone(id: "first_steps", month: 13, emoji: "👣", title: "First Steps", caption: "Wobble, wobble… walk!"),
        BabyMilestone(id: "runs", month: 18, emoji: "🏃", title: "Running Around", caption: "Zoom, zoom! Catch me!"),
        BabyMilestone(id: "first_sentence", month: 21, emoji: "💬", title: "First Sentence", caption: "“{name} loves you!”"),
        BabyMilestone(id: "birthday_2", month: 24, emoji: "🎈", title: "Second Birthday", caption: "Two candles, big wishes."),
        BabyMilestone(id: "first_drawing", month: 30, emoji: "🖍️", title: "First Drawing", caption: "A masterpiece for the fridge."),
        BabyMilestone(id: "birthday_3", month: 36, emoji: "🎉", title: "Third Birthday", caption: "Three years of love!"),
    ]

    static func milestone(id: String) -> BabyMilestone? { all.first { $0.id == id } }
}
