import SwiftUI

let ncell = 12                  // diamonds along each bracelet
let nstrips = 3                // three bracelets side by side
let colorSpecs: [Color] = [
  Color(red: 0.16, green: 0.69, blue: 0.65),
  Color(red: 0.08, green: 0.39, blue: 0.83),
  Color(red: 0.52, green: 0.18, blue: 0.39)
]
let accentSpecs: [Color] = [.mint, .cyan, .pink]
let patternNames = ["Open diamond", "Small diamond", "Double diamond"]

struct TileData {
  var pattern: Int
  var colorIndex: Int
  var accentIndex: Int
  var direction: Bool
}

@main
struct RandomPatternApp: App {
  var body: some Scene {
    WindowGroup {
      HomeView()
    }
  }
}

// First view: read about the pattern.
struct HomeView: View {
  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Text("FRIENDSHIP BRACELETS")
          .font(.largeTitle.bold())
          .multilineTextAlignment(.center)

        Text("A tiny artwork made from chance")
          .foregroundStyle(.secondary)

        NavigationLink("Make a Pattern") {
          PatternView()
        }
        .buttonStyle(.borderedProminent)

        NavigationLink("How It Works") {
          AboutView()
        }
        .buttonStyle(.bordered)
      }
      .padding()
    }
  }
}

// Second view: show three bracelet strips
struct PatternView: View {
  @State private var tiles: [TileData] = makeTiles()

  var body: some View {
    VStack(spacing: 20) {
      Text("Three strands, new friends each time!")
        .font(.title2.bold())
        .multilineTextAlignment(.center)

      Canvas { context, size in
        let stripSpacing = size.width / CGFloat(nstrips + 1)
        let stripWidth = min(stripSpacing * 0.65, 62.0)
        let cellHeight = size.height / CGFloat(ncell)

        for strip in 0..<nstrips {
          let centerX = stripSpacing * CGFloat(strip + 1)
          let left = centerX - stripWidth / 2

          for row in 0..<ncell {
            let tile = tiles[strip * ncell + row]
            let rect = CGRect(x: left,
                              y: CGFloat(row) * cellHeight,
                              width: stripWidth,
                              height: cellHeight)
            drawKnot(tile, in: rect, context: context)
          }
        }
      }
      .frame(height: 480)
      .background(Color(red: 0.73, green: 0.87, blue: 0.82))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal)

      Button("Make Another") {
        tiles = makeTiles()
      }
      .buttonStyle(.borderedProminent)

      Text("\(tiles.count) knots")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationTitle("Bracelets")
  }
}

// Third view: explain the arrays and random choices.
struct AboutView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("How It Works")
        .font(.largeTitle.bold())

      Text("Canvas draws three narrow strips. Each strip has 12 diamond-shaped knots, like the friendship bracelets in the reference photo.")

      Text("Each knot is saved in a TileData array. Random numbers choose its color, accent, and diamond variation. Make Another generates a new array.")

      Text("Variations: \(patternNames.joined(separator: ", "))")
        .foregroundStyle(.secondary)

      Spacer()
    }
    .padding()
    .navigationTitle("About")
  }
}

// make an array of 36 knots while each strip keeps its own base color.
func makeTiles() -> [TileData] {
  var result: [TileData] = []

  for strip in 0..<nstrips {
    for _ in 0..<ncell {
      let tile = TileData(
        pattern: Int.random(in: 0..<patternNames.count),
        colorIndex: strip,
        accentIndex: Int.random(in: 0..<accentSpecs.count),
        direction: Bool.random()
      )
      result.append(tile)
    }
  }

  return result
}

// Draw a colored knot with the pale crossing threads of a bracelet.
func drawKnot(_ tile: TileData, in rect: CGRect,
              context: GraphicsContext) {
  let x = rect.midX
  let y = rect.midY
  let halfWidth = rect.width * 0.48
  let halfHeight = rect.height * 0.54
  let thread = Color(red: 0.98, green: 0.96, blue: 0.91)

  // Colored woven band underneath the pale threads.
  let band = CGRect(x: rect.minX, y: rect.minY,
                    width: rect.width, height: rect.height)
  context.fill(Path(band), with: .color(colorSpecs[tile.colorIndex]))

  var diamond = Path()
  diamond.move(to: CGPoint(x: x, y: y - halfHeight))
  diamond.addLine(to: CGPoint(x: x + halfWidth, y: y))
  diamond.addLine(to: CGPoint(x: x, y: y + halfHeight))
  diamond.addLine(to: CGPoint(x: x - halfWidth, y: y))
  diamond.closeSubpath()

  // Randomly vary the colored center while keeping a repeating diamond rhythm.
  if tile.pattern == 0 {
    context.fill(diamond, with: .color(colorSpecs[tile.colorIndex].opacity(0.65)))
  } else if tile.pattern == 1 {
    context.fill(diamond, with: .color(accentSpecs[tile.accentIndex].opacity(0.55)))
  } else {
    context.fill(diamond, with: .color(colorSpecs[tile.colorIndex]))
    let smallDiamond = Path(ellipseIn: CGRect(x: x - 5, y: y - 5,
                                              width: 10, height: 10))
    context.fill(smallDiamond, with: .color(accentSpecs[tile.accentIndex]))
  }

  context.stroke(diamond, with: .color(thread),
                 style: StrokeStyle(lineWidth: 5, lineCap: .round,
                                    lineJoin: .round))

  // A short slanted thread makes each knot different.
  var stitch = Path()
  let offset = tile.direction ? -1.0 : 1.0
  stitch.move(to: CGPoint(x: x + offset * 8, y: y - 4))
  stitch.addLine(to: CGPoint(x: x + offset * 3, y: y + 4))
  context.stroke(stitch, with: .color(accentSpecs[tile.accentIndex]),
                 style: StrokeStyle(lineWidth: 2, lineCap: .round))
}

#Preview {
  HomeView()
}

