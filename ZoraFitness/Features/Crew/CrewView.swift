import SwiftUI

struct CrewView: View {
    @Environment(SettingsStore.self) private var settings

    // MARK: - Mock Data

    private struct MockMember: Identifiable {
        let id = UUID()
        let name: String
        let initials: String
        let role: Role
        let contribution: Double  // each member's slice of 100% crew goal (max 25)

        enum Role {
            case referee, linesperson
            var label: String { self == .referee ? "REFEREE" : "LINESPERSON" }
            var color: Color { self == .referee ? Color(red: 1.0, green: 0.52, blue: 0.05) : AppTheme.strainBlue }
        }
    }

    private var weekLabel: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today)
        let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
        let monday = cal.date(byAdding: .day, value: daysToMonday, to: today)!
        let sunday = cal.date(byAdding: .day, value: 6, to: monday)!
        return monday.formatted(.dateTime.month(.abbreviated).day()) + " – " +
               sunday.formatted(.dateTime.month(.abbreviated).day())
    }

    private var members: [MockMember] {
        let myName = settings.officialName.isEmpty ? "You" : settings.officialName
        return [
            MockMember(name: myName,      initials: initials(from: myName), role: .referee,     contribution: 18.0),
            MockMember(name: "D. Bowman", initials: "DB",                   role: .referee,     contribution: 20.5),
            MockMember(name: "M. Torres", initials: "MT",                   role: .linesperson, contribution: 14.5),
            MockMember(name: "K. Park",   initials: "KP",                   role: .linesperson, contribution: 15.0),
        ]
    }

    private var crewProgress: Double { members.map(\.contribution).reduce(0, +) }

    // MARK: - Star System

    private var starsEarned: Int {
        if crewProgress >= 100 { return 3 }
        if crewProgress >= 66  { return 2 }
        if crewProgress >= 33  { return 1 }
        return 0
    }

    private let accentColor = AppTheme.recoveryYellow
    @State private var showProfile = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.sectionGap) {
                        starsCard
                        progressCard
                        officialsRoomCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("The Crew")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarButton(initials: initialsFromName(settings.officialName.isEmpty ? "You" : settings.officialName)) {
                        showProfile = true
                    }
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
        }
    }

    // MARK: - Stars Card

    private var starsCard: some View {
        VStack(spacing: 18) {
            HStack {
                Text("CREW STARS")
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.4)
                Spacer()
                Text(weekLabel)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 0) {
                ForEach(1...3, id: \.self) { n in
                    Spacer()
                    VStack(spacing: 7) {
                        Image(systemName: starsEarned >= n ? "star.fill" : "star")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(starsEarned >= n ? accentColor : Color(white: 0.22))
                            .animation(.easeOut(duration: 0.4), value: starsEarned)
                        Text(n == 1 ? "33%" : n == 2 ? "66%" : "100%")
                            .font(AppTheme.micro)
                            .foregroundStyle(starsEarned >= n ? accentColor.opacity(0.7) : AppTheme.tertiaryText)
                            .tracking(1.0)
                    }
                    Spacer()
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // MARK: - Collective Progress Card

    private var progressCard: some View {
        VStack(spacing: 20) {
            crewProgressBar

            VStack(spacing: 12) {
                ForEach(members) { member in
                    memberRow(member)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private var crewProgressBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CREW GOAL")
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.4)
                Spacer()
                HStack(spacing: 5) {
                    ForEach([33.0, 66.0, 100.0], id: \.self) { threshold in
                        Image(systemName: crewProgress >= threshold ? "star.fill" : "star")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(crewProgress >= threshold ? accentColor : Color(white: 0.28))
                    }
                }
            }

            GeometryReader { proxy in
                let gap: CGFloat = 6
                let sectionW = (proxy.size.width - gap * 2) / 3
                HStack(spacing: gap) {
                    sectionSegment(lo: 0,  hi: 33,  width: sectionW)
                    sectionSegment(lo: 33, hi: 66,  width: sectionW)
                    sectionSegment(lo: 66, hi: 100, width: sectionW)
                }
            }
            .frame(height: 22)
        }
    }

    @ViewBuilder
    private func sectionSegment(lo: Double, hi: Double, width: CGFloat) -> some View {
        let range        = hi - lo
        let fillFraction = ((crewProgress - lo) / range).clamped(to: 0...1)
        let isComplete   = crewProgress >= hi
        let isActive     = crewProgress >= lo && crewProgress < hi
        let displayPct   = Int((fillFraction * 100).rounded())

        ZStack {
            // Glow bleeds outside clip — must live in outer unclipped ZStack
            if isComplete {
                RoundedRectangle(cornerRadius: 5)
                    .fill(accentColor.opacity(0.7))
                    .blur(radius: 14)
                RoundedRectangle(cornerRadius: 5)
                    .fill(accentColor.opacity(0.5))
                    .blur(radius: 6)
            }

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(white: 0.13))

                // Fill
                if fillFraction > 0 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(accentColor)
                        .frame(width: width * fillFraction)
                        .animation(.easeOut(duration: 0.9), value: fillFraction)
                }

                // % label — only on the active (in-progress) section
                if isActive {
                    Text("\(displayPct)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .frame(width: width, alignment: .center)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .frame(width: width, height: 22)
    }

    private func memberRow(_ member: MockMember) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(member.role.color.opacity(0.14))
                    .frame(width: 30, height: 30)
                Text(member.initials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(member.role.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text(member.role.label)
                    .font(AppTheme.micro)
                    .foregroundStyle(member.role.color)
                    .tracking(1.0)
            }
            .frame(width: 90, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.18))
                    Capsule()
                        .fill(member.role.color.opacity(0.85))
                        .frame(width: proxy.size.width * (member.contribution / 25).clamped(to: 0...1))
                        .animation(.easeOut(duration: 0.9), value: member.contribution)
                }
            }
            .frame(height: 5)

            Text("\(Int(member.contribution * 4))%")
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.primaryText)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Officials' Room Card

    private var officialsRoomCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("OFFICIALS' ROOM")
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.4)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.recoveryGreen)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.recoveryGreen)
                        .tracking(1.1)
                }
            }

            VStack(spacing: 10) {
                messageBubble(initials: "DB", text: "Who is skating tonight?", isMe: false, color: AppTheme.strainBlue)
                messageBubble(initials: "KP", text: "Hit your zones!", isMe: false, color: AppTheme.sleepPurple)
                messageBubble(initials: userInitials, text: "Save the streak!", isMe: true, color: accentColor)
            }

            Divider().background(Color(white: 0.18))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Who is skating tonight?", "Hit your zones!", "Save the streak!"], id: \.self) { macro in
                        Text(macro)
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(white: 0.18), in: Capsule())
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    @ViewBuilder
    private func messageBubble(initials: String, text: String, isMe: Bool, color: Color) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 40) }

            if !isMe {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Text(initials)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }
            }

            Text(text)
                .font(AppTheme.caption)
                .foregroundStyle(isMe ? AppTheme.background : AppTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isMe ? color : Color(white: 0.20),
                    in: RoundedRectangle(cornerRadius: 14)
                )

            if !isMe { Spacer(minLength: 40) }
        }
    }

    // MARK: - Helpers

    private var userInitials: String {
        initials(from: settings.officialName.isEmpty ? "You" : settings.officialName)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        guard let first = parts.first?.first else { return "?" }
        if parts.count >= 2, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        }
        return String(first).uppercased()
    }
}
