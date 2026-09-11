// Random Food Pattern Based on Time of Day

import Foundation

func charAt(_ str: String, _ offset: Int) -> String {
    let index = str.index(str.startIndex, offsetBy: offset)
    let char = str[index]
    return String(char)
}
// ISSUE 1:
// I originally wrote:
// let currentHour = Calendar.current.component(hour, from: Date())
// Xcode error:
// Cannot find 'hour' in scope.
// HOW I FIXED IT:
// I learned that "hour" is a Calendar component and needs a period before it and it worked.
// Returns different food choices depending on the hour
func foodForTime(_ hour: Int) -> String {
    if hour >= 7 && hour < 11 {
        // Breakfast: 7:00 AM–10:59 AM
        return "🥞🍳🥐🥯🍓"
    } else if hour >= 11 && hour < 16 {
        // Lunch: 11:00 AM–3:59 PM
        return "🍔🍕🥪🌮🍟"
    } else if hour >= 16 && hour < 22 {
        // Dinner: 4:00 PM–9:59 PM
        return "🍝🍣🍛🥘🍜"
    } else {
        // Late-night snacks: 10:00 PM–6:59 AM
        return "🍪🍩🍿🍫🍦"
    }
}

// fetch the current hour from the computer
let currentHour = Calendar.current.component(.hour, from: Date())

let foodEmojis = foodForTime(currentHour)

print("Current hour:", currentHour)
print("Today's food selection:", foodEmojis)
print("")

func generateFoodLine(_ numberOfFoods: Int) {
    var foodLine = ""

    for _ in 0..<numberOfFoods {
        let randomIndex = Int.random(in: 0..<foodEmojis.count)
        foodLine += charAt(foodEmojis, randomIndex)
    }

    print(foodLine)
}

// Creates a square block of random food emojis.
func generateFoodBlock(_ size: Int) {
    for _ in 0..<size {
        generateFoodLine(size)
    }
}

generateFoodBlock(5)

print("")

generateFoodBlock(5)

print("")

generateFoodBlock(5)
