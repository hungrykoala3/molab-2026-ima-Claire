import SwiftUI
import Foundation

// Food choices shared by both pages
enum Meal: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case lateNight = "Late Night"

    var id: String { rawValue }

    var foods: [String] {
        switch self {
        case .breakfast:
            return ["🥞 Pancakes", "🍳 Eggs", "🥯 Bagel", "🥐 Croissant"]
        case .lunch:
            return ["🥪 Sandwich", "🥗 Salad", "🍜 Noodles", "🌮 Tacos"]
        case .dinner:
            return ["🍝 Pasta", "🍣 Sushi", "🍛 Curry", "🍕 Pizza"]
        case .lateNight:
            return ["🍿 Popcorn", "🍪 Cookies", "🍌 Banana", "🥛 Milk"]
        }
    }

    var hours: String {
        switch self {
        case .breakfast: return "7 AM – 10:59 AM"
        case .lunch: return "11 AM – 3:59 PM"
        case .dinner: return "4 PM – 9:59 PM"
        case .lateNight: return "10 PM – 6:59 AM"
        }
    }

    static func current(at date: Date) -> Meal {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 7..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default: return .lateNight
        }
    }
}

// Two pages connected by a tab bar.
struct ContentView: View {
    var body: some View {
        TabView {
            NowView()
                .tabItem {
                    Label("Now", systemImage: "clock")
                }

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "fork.knife")
                }
        }
        .tint(.orange)
    }
}

// PAGE 1: Live clock and time-based food suggestion.
struct NowView: View {
    @State private var suggestionIndex = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let meal = Meal.current(at: context.date)

            ScrollView {
                VStack(spacing: 24) {
                    Text("Meal Clock")
                        .font(.largeTitle.bold())

                    Text("What time is it? What should you eat?")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text(
                        context.date,
                        format: .dateTime
                            .hour()
                            .minute()
                            .second()
                    )
                    .font(.system(
                        size: 42,
                        weight: .bold,
                        design: .rounded
                    ))
                    .monospacedDigit()

                    VStack(spacing: 16) {
                        Text("It's \(meal.rawValue) time!")
                            .font(.title2.bold())

                        Text(meal.hours)
                            .foregroundStyle(.secondary)

                        Text(meal.foods[suggestionIndex])
                            .font(.largeTitle)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.orange.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 24)
                    )

                    Button {
                        // Choose a different suggestion.
                        let otherIndices = meal.foods.indices.filter {
                            $0 != suggestionIndex
                        }
                        suggestionIndex = otherIndices.randomElement() ?? 0
                    } label: {
                        Label("Another idea", systemImage: "shuffle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Text("Visit Explore to browse any meal.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
        }
    }
}

// PAGE 2: Browse meals independently of the current time.
struct ExploreView: View {
    @State private var selectedMeal: Meal = .breakfast
    @State private var chosenFood = "🥞 Pancakes"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Explore Meals")
                    .font(.largeTitle.bold())

                Text("Choose a meal and find something to eat.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Picker("Meal", selection: $selectedMeal) {
                    ForEach(Meal.allCases) { meal in
                        Text(meal.rawValue).tag(meal)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedMeal) { oldMeal, newMeal in
                    chosenFood = newMeal.foods[0]
                }

                Text(chosenFood)
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.orange.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 24)
                    )

                Button("Pick a food") {
                    let otherFoods = selectedMeal.foods.filter {
                        $0 != chosenFood
                    }
                    chosenFood = otherFoods.randomElement()
                        ?? selectedMeal.foods[0]
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                VStack(alignment: .leading, spacing: 14) {
                    Text("All options")
                        .font(.headline)

                    ForEach(selectedMeal.foods, id: \.self) { food in
                        Text(food)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .padding(24)
        }
    }
}
