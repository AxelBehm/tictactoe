//
//  ContentView.swift
//  tictactoe
//
//  Created by Axel Behm on 12.05.26.
//

import SwiftUI
import Combine

private enum Player: String {
    case human = "X"
    case computer = "O"

    var systemImage: String {
        switch self {
        case .human:
            "xmark"
        case .computer:
            "circle"
        }
    }

    var color: Color {
        switch self {
        case .human:
            .blue
        case .computer:
            .orange
        }
    }
}

private enum GameMode: String, CaseIterable, Identifiable {
    case computer
    case twoPlayers
    case nearby

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .computer:
            "Gegen Computer"
        case .twoPlayers:
            "Zu zweit"
        case .nearby:
            "2 iPhones"
        }
    }

    var description: String {
        switch self {
        case .computer:
            "Du spielst X, der Computer spielt O."
        case .twoPlayers:
            "Spieler X und Spieler O sind abwechselnd dran."
        case .nearby:
            "Zwei iPhones spielen lokal über WLAN oder Bluetooth."
        }
    }
}

private enum GameVariant: String, CaseIterable, Identifiable {
    case classic
    case large

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .classic:
            "3x3"
        case .large:
            "5x5"
        }
    }

    var description: String {
        switch self {
        case .classic:
            "3 gleiche Zeichen gewinnen."
        case .large:
            "4 gleiche Zeichen gerade oder diagonal gewinnen."
        }
    }

    var boardSize: Int {
        switch self {
        case .classic:
            3
        case .large:
            5
        }
    }

    var marksToWin: Int {
        switch self {
        case .classic:
            3
        case .large:
            4
        }
    }

    var cellCount: Int {
        boardSize * boardSize
    }
}

struct ContentView: View {
    private let privacyURL = URL(string: "https://axelbehm.github.io/kisoft4you/datenschutz.html")!

    @StateObject private var multiplayer = MultiplayerService()
    @State private var gameVariant: GameVariant = .classic
    @State private var gameMode: GameMode = .computer
    @State private var board: [Player?] = Array(repeating: nil, count: 9)
    @State private var statusText = "Du bist dran."
    @State private var currentPlayer: Player = .human
    @State private var isComputerThinking = false
    @State private var isGameOver = false
    @State private var computerMoveID = 0
    @State private var showFireworks = false
    @State private var fireworksID = 0
    @State private var suppressNextVariantSync = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: boardSpacing), count: gameVariant.boardSize)
    }

    private var boardSpacing: CGFloat {
        gameVariant == .classic ? 12 : 8
    }

    private var symbolSize: CGFloat {
        gameVariant == .classic ? 52 : 30
    }

    private var winningLines: [[Int]] {
        makeWinningLines(boardSize: gameVariant.boardSize, marksToWin: gameVariant.marksToWin)
    }

    private var localNetworkPlayer: Player {
        multiplayer.isHosting ? .human : .computer
    }

    private var canTapBoard: Bool {
        switch gameMode {
        case .computer:
            return !isComputerThinking
        case .twoPlayers:
            return true
        case .nearby:
            return multiplayer.isConnected && currentPlayer == localNetworkPlayer
        }
    }

    private var nearbyControls: some View {
        VStack(spacing: 8) {
            Text(multiplayer.connectionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button("Spiel hosten") {
                    resetGame(sendToPeer: false)
                    multiplayer.startHosting()
                    statusText = "Warte auf zweites iPhone ..."
                }
                .buttonStyle(.bordered)
                .disabled(multiplayer.isConnected || multiplayer.isHosting)

                Button("Beitreten") {
                    resetGame(sendToPeer: false)
                    multiplayer.startSearching()
                    statusText = "Suche ein Spiel in der Nähe ..."
                }
                .buttonStyle(.bordered)
                .disabled(multiplayer.isConnected || multiplayer.isSearching)

                if multiplayer.isConnected || multiplayer.isHosting || multiplayer.isSearching {
                    Button("Trennen") {
                        multiplayer.disconnect()
                        resetGame(sendToPeer: false)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.footnote)
        }
        .frame(maxWidth: 420)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.sRGB, white: 0.98, opacity: 1),
                        Color.blue.opacity(0.12),
                        Color.orange.opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Link(destination: privacyURL) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(9)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel("Datenschutz")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, proxy.safeAreaInsets.top + 8)
                .zIndex(1)

                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Text("Tic Tac Toe")
                            .font(.largeTitle.bold())

                        Text(gameMode.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(gameVariant.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(statusText)
                            .font(.headline)
                            .foregroundStyle(isGameOver ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 28)
                    }

                    Picker("Spielmodus", selection: $gameMode) {
                        ForEach(GameMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    .onChange(of: gameMode) {
                        handleGameModeChange()
                    }

                    Picker("Variante", selection: $gameVariant) {
                        ForEach(GameVariant.allCases) { variant in
                            Text(variant.title).tag(variant)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    .onChange(of: gameVariant) {
                        handleGameVariantChange()
                    }

                    if gameMode == .nearby {
                        nearbyControls
                    }

                    Spacer(minLength: 0)

                    LazyVGrid(columns: columns, spacing: boardSpacing) {
                        ForEach(board.indices, id: \.self) { index in
                            Button {
                                makeMove(at: index)
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.thinMaterial)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(.secondary.opacity(0.25), lineWidth: 1)
                                        }

                                    if let player = board[index] {
                                        Image(systemName: player.systemImage)
                                            .font(.system(size: symbolSize, weight: .bold))
                                            .foregroundStyle(player.color)
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .disabled(board[index] != nil || !canTapBoard || isGameOver)
                        }
                    }
                    .frame(width: boardSideLength(in: proxy), height: boardSideLength(in: proxy))

                    Spacer(minLength: 0)

                    Button("Neues Spiel") {
                        resetGame()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showFireworks {
                    FireworksView()
                        .id(fireworksID)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .onReceive(multiplayer.$receivedMessage.compactMap { $0 }) { message in
            handleMultiplayerMessage(message)
        }
        .onChange(of: multiplayer.isConnected) {
            handleMultiplayerConnectionChange()
        }
    }

    private func boardSideLength(in proxy: GeometryProxy) -> CGFloat {
        let horizontalLimit = proxy.size.width - 32
        let safeAreaHeight = proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        let verticalLimit = proxy.size.height - safeAreaHeight - 250
        let maximumBoardSize: CGFloat = gameVariant == .classic ? 420 : 460

        return min(maximumBoardSize, max(260, min(horizontalLimit, verticalLimit)))
    }

    private func makeMove(at index: Int) {
        guard !isComputerThinking, !isGameOver, board[index] == nil else {
            return
        }

        board[index] = currentPlayer

        if gameMode == .nearby {
            sendNetworkMove(index: index, player: currentPlayer)
        }

        guard !finishGameIfNeeded() else {
            return
        }

        switch gameMode {
        case .computer:
            startComputerTurn()
        case .twoPlayers:
            currentPlayer = nextPlayer(after: currentPlayer)
            statusText = turnText()
        case .nearby:
            currentPlayer = nextPlayer(after: currentPlayer)
            statusText = turnText()
        }
    }

    private func startComputerTurn() {
        currentPlayer = .computer
        isComputerThinking = true
        statusText = "Computer denkt ..."
        computerMoveID += 1
        let currentMoveID = computerMoveID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard currentMoveID == computerMoveID else {
                return
            }

            makeComputerMove()
        }
    }

    private func makeComputerMove() {
        guard !isGameOver, gameMode == .computer else {
            return
        }

        if let index = bestComputerMove() {
            board[index] = .computer
        }

        guard !finishGameIfNeeded() else {
            return
        }

        currentPlayer = .human
        isComputerThinking = false
        statusText = "Du bist dran."
    }

    private func finishGameIfNeeded() -> Bool {
        if let winner = winner(in: board) {
            isGameOver = true
            isComputerThinking = false
            statusText = resultText(for: winner)
            startFireworks()
            return true
        }

        if emptyCells(in: board).isEmpty {
            isGameOver = true
            isComputerThinking = false
            statusText = "Unentschieden!"
            return true
        }

        return false
    }

    private func resetGame(sendToPeer: Bool = true) {
        computerMoveID += 1
        fireworksID += 1
        showFireworks = false
        board = Array(repeating: nil, count: gameVariant.cellCount)
        currentPlayer = .human
        isComputerThinking = false
        statusText = turnText()
        isGameOver = false

        if sendToPeer, gameMode == .nearby, multiplayer.isConnected {
            sendNetworkReset()
        }
    }

    private func nextPlayer(after player: Player) -> Player {
        player == .human ? .computer : .human
    }

    private func turnText() -> String {
        switch gameMode {
        case .computer:
            return "Du bist dran."
        case .twoPlayers:
            return "\(currentPlayer.rawValue) ist dran."
        case .nearby:
            guard multiplayer.isConnected else {
                return "Verbinde zwei iPhones."
            }

            let yourMark = localNetworkPlayer.rawValue
            let turnText = currentPlayer == localNetworkPlayer ? "Du bist dran." : "Das andere iPhone ist dran."
            return "Du bist \(yourMark). \(turnText)"
        }
    }

    private func resultText(for winner: Player) -> String {
        switch gameMode {
        case .computer:
            return winner == .human ? "Du hast gewonnen!" : "Der Computer gewinnt."
        case .twoPlayers:
            return "Spieler \(winner.rawValue) gewinnt!"
        case .nearby:
            return winner == localNetworkPlayer ? "Du hast gewonnen!" : "Das andere iPhone gewinnt."
        }
    }

    private func handleGameModeChange() {
        if gameMode == .nearby {
            resetGame(sendToPeer: false)
        } else {
            multiplayer.disconnect()
            resetGame(sendToPeer: false)
        }
    }

    private func handleGameVariantChange() {
        if suppressNextVariantSync {
            suppressNextVariantSync = false
            return
        }

        resetGame(sendToPeer: gameMode == .nearby && multiplayer.isConnected)
    }

    private func handleMultiplayerConnectionChange() {
        guard gameMode == .nearby else {
            return
        }

        resetGame(sendToPeer: false)

        if multiplayer.isConnected, multiplayer.isHosting {
            sendNetworkReset()
        }
    }

    private func handleMultiplayerMessage(_ message: MultiplayerMessage) {
        guard gameMode == .nearby else {
            return
        }

        if let remoteVariant = GameVariant(rawValue: message.variant), remoteVariant != gameVariant {
            suppressNextVariantSync = true
            gameVariant = remoteVariant
        }

        switch message.kind {
        case .reset:
            resetGame(sendToPeer: false)
        case .move:
            guard let index = message.index,
                  board.indices.contains(index),
                  board[index] == nil,
                  let playerRawValue = message.player,
                  let player = Player(rawValue: playerRawValue) else {
                return
            }

            board[index] = player

            guard !finishGameIfNeeded() else {
                return
            }

            currentPlayer = nextPlayer(after: player)
            statusText = turnText()
        }
    }

    private func sendNetworkMove(index: Int, player: Player) {
        let message = MultiplayerMessage(kind: .move, index: index, player: player.rawValue, variant: gameVariant.rawValue)
        multiplayer.send(message)
    }

    private func sendNetworkReset() {
        let message = MultiplayerMessage(kind: .reset, index: nil, player: nil, variant: gameVariant.rawValue)
        multiplayer.send(message)
    }

    private func startFireworks() {
        fireworksID += 1

        withAnimation(.easeInOut(duration: 0.2)) {
            showFireworks = true
        }

        let currentFireworksID = fireworksID

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
            guard currentFireworksID == fireworksID else {
                return
            }

            withAnimation(.easeOut(duration: 0.7)) {
                showFireworks = false
            }
        }
    }

    private func bestComputerMove() -> Int? {
        switch gameVariant {
        case .classic:
            return bestMinimaxMove()
        case .large:
            return bestStrategicMove()
        }
    }

    private func bestMinimaxMove() -> Int? {
        var bestScore = Int.min
        var bestMoves: [Int] = []

        for index in emptyCells(in: board) {
            var possibleBoard = board
            possibleBoard[index] = .computer

            let score = minimax(board: possibleBoard, isComputerTurn: false, depth: 0)

            if score > bestScore {
                bestScore = score
                bestMoves = [index]
            } else if score == bestScore {
                bestMoves.append(index)
            }
        }

        return bestMoves.randomElement()
    }

    private func bestStrategicMove() -> Int? {
        let emptyCells = emptyCells(in: board)

        if emptyCells.isEmpty {
            return nil
        }

        if let winningMove = immediateMove(for: .computer, in: board) {
            return winningMove
        }

        if let blockingMove = immediateMove(for: .human, in: board) {
            return blockingMove
        }

        var bestScore = Int.min
        var bestMoves: [Int] = []

        for index in emptyCells {
            var possibleBoard = board
            possibleBoard[index] = .computer

            let score = strategicScore(forMoveAt: index, possibleBoard: possibleBoard)

            if score > bestScore {
                bestScore = score
                bestMoves = [index]
            } else if score == bestScore {
                bestMoves.append(index)
            }
        }

        return bestMoves.randomElement()
    }

    private func immediateMove(for player: Player, in board: [Player?]) -> Int? {
        for index in emptyCells(in: board) {
            var possibleBoard = board
            possibleBoard[index] = player

            if winner(in: possibleBoard) == player {
                return index
            }
        }

        return nil
    }

    private func strategicScore(forMoveAt index: Int, possibleBoard: [Player?]) -> Int {
        var score = centerScore(for: index)

        for line in winningLines where line.contains(index) {
            let computerCount = line.filter { possibleBoard[$0] == .computer }.count
            let humanCount = line.filter { possibleBoard[$0] == .human }.count

            if humanCount == 0 {
                score += lineScore(for: computerCount)
            }

            let humanCountBeforeMove = line.filter { board[$0] == .human }.count
            let computerCountBeforeMove = line.filter { board[$0] == .computer }.count

            if computerCountBeforeMove == 0 {
                score += lineScore(for: humanCountBeforeMove) * 2
            }
        }

        return score
    }

    private func lineScore(for count: Int) -> Int {
        switch count {
        case 3:
            return 80
        case 2:
            return 18
        case 1:
            return 4
        default:
            return 1
        }
    }

    private func centerScore(for index: Int) -> Int {
        let row = index / gameVariant.boardSize
        let column = index % gameVariant.boardSize
        let center = Double(gameVariant.boardSize - 1) / 2
        let distance = abs(Double(row) - center) + abs(Double(column) - center)

        return max(0, 12 - Int(distance * 4))
    }

    private func minimax(board: [Player?], isComputerTurn: Bool, depth: Int) -> Int {
        if let winner = winner(in: board) {
            return winner == .computer ? 10 - depth : depth - 10
        }

        let emptyCells = emptyCells(in: board)

        if emptyCells.isEmpty {
            return 0
        }

        if isComputerTurn {
            var bestScore = Int.min

            for index in emptyCells {
                var possibleBoard = board
                possibleBoard[index] = .computer
                bestScore = max(bestScore, minimax(board: possibleBoard, isComputerTurn: false, depth: depth + 1))
            }

            return bestScore
        } else {
            var bestScore = Int.max

            for index in emptyCells {
                var possibleBoard = board
                possibleBoard[index] = .human
                bestScore = min(bestScore, minimax(board: possibleBoard, isComputerTurn: true, depth: depth + 1))
            }

            return bestScore
        }
    }

    private func winner(in board: [Player?]) -> Player? {
        for line in winningLines {
            guard let firstPlayer = board[line[0]] else {
                continue
            }

            if line.allSatisfy({ board[$0] == firstPlayer }) {
                return firstPlayer
            }
        }

        return nil
    }

    private func emptyCells(in board: [Player?]) -> [Int] {
        board.indices.filter { board[$0] == nil }
    }

    private func makeWinningLines(boardSize: Int, marksToWin: Int) -> [[Int]] {
        guard boardSize >= marksToWin else {
            return []
        }

        var lines: [[Int]] = []
        let lastStart = boardSize - marksToWin

        for row in 0..<boardSize {
            for column in 0...lastStart {
                lines.append((0..<marksToWin).map { row * boardSize + column + $0 })
            }
        }

        for row in 0...lastStart {
            for column in 0..<boardSize {
                lines.append((0..<marksToWin).map { (row + $0) * boardSize + column })
            }
        }

        for row in 0...lastStart {
            for column in 0...lastStart {
                lines.append((0..<marksToWin).map { (row + $0) * boardSize + column + $0 })
            }

            for column in (marksToWin - 1)..<boardSize {
                lines.append((0..<marksToWin).map { (row + $0) * boardSize + column - $0 })
            }
        }

        return lines
    }
}

private struct FireworksView: View {
    private let bursts: [(x: CGFloat, y: CGFloat, color: Color, delay: Double)] = [
        (0.22, 0.24, .pink, 0.0),
        (0.74, 0.28, .yellow, 0.2),
        (0.50, 0.18, .purple, 0.4),
        (0.30, 0.62, .cyan, 0.7),
        (0.70, 0.66, .orange, 0.9),
        (0.46, 0.52, .mint, 1.2),
        (0.16, 0.48, .red, 1.5),
        (0.84, 0.48, .blue, 1.8),
        (0.38, 0.34, .green, 2.2),
        (0.62, 0.40, .indigo, 2.6),
        (0.24, 0.78, .yellow, 3.0),
        (0.78, 0.78, .pink, 3.4)
    ]

    @State private var isExpanded = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(bursts.indices, id: \.self) { index in
                    let burst = bursts[index]

                    FireworkBurst(color: burst.color, isExpanded: isExpanded)
                        .position(x: proxy.size.width * burst.x, y: proxy.size.height * burst.y)
                        .animation(.easeOut(duration: 1.25).delay(burst.delay), value: isExpanded)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                isExpanded = false

                DispatchQueue.main.async {
                    isExpanded = true
                }
            }
        }
    }
}

private struct FireworkBurst: View {
    let color: Color
    let isExpanded: Bool

    private let sparkCount = 30

    var body: some View {
        ZStack {
            ForEach(0..<sparkCount, id: \.self) { sparkIndex in
                Capsule()
                    .fill(color)
                    .frame(width: 6, height: 22)
                    .shadow(color: color.opacity(0.9), radius: 12)
                    .offset(y: isExpanded ? -112 : 0)
                    .rotationEffect(.degrees(Double(sparkIndex) * 360 / Double(sparkCount)))
                    .scaleEffect(isExpanded ? 0.28 : 1)
                    .opacity(isExpanded ? 0 : 1)
            }

            ForEach(0..<sparkCount, id: \.self) { sparkIndex in
                Circle()
                    .fill(color.opacity(0.85))
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(0.8), radius: 10)
                    .offset(y: isExpanded ? -64 : 0)
                    .rotationEffect(.degrees(Double(sparkIndex) * 360 / Double(sparkCount) + 6))
                    .opacity(isExpanded ? 0 : 1)
            }

            Circle()
                .fill(color.opacity(isExpanded ? 0 : 0.9))
                .frame(width: 24, height: 24)
                .shadow(color: color.opacity(0.9), radius: 18)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
