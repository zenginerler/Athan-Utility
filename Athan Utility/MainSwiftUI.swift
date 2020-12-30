//
//  MainSwiftUI.swift
//  Athan Utility
//
//  Created by Omar Al-Ejel on 9/24/20.
//  Copyright © 2020 Omar Alejel. All rights reserved.
//

import SwiftUI
import Adhan
import Combine

enum CurrentView {
    case Main, Settings, Location
}

@available(iOS 13.0.0, *)
extension View {
    func onValueChanged<Value: Equatable>(_ value: Value, completion: (Value) -> Void) -> some View {
        completion(value)
        return self
    }
}

@available(iOS 13.0.0, *)
struct GradientView: View, Equatable {
    static func == (lhs: GradientView, rhs: GradientView) -> Bool {
        lhs.currentPrayer == rhs.currentPrayer && lhs.appearance.id == rhs.appearance.id
    }
    
    @Binding var currentPrayer: Prayer
    @State var lastShownPrayer: Prayer? = nil
    @Binding var appearance: AppearanceSettings
    @State private var firstPlane: Bool = true
    
    @State private var gradientA: [Color] = {
        let settings = AthanManager.shared.appearanceSettings
        let startColors = settings.colors(for: settings.isDynamic ? AthanManager.shared.currentPrayer : nil)
        return [startColors.0, startColors.1]
    }()
    
    @State private var gradientB: [Color] = { // setting here is useless
        let settings = AthanManager.shared.appearanceSettings
        let startColors = settings.colors(for: settings.isDynamic ? AthanManager.shared.currentPrayer : nil)
        return [startColors.0, startColors.1]
    }()
    
    @State var lastTimerDate = Date(timeIntervalSinceNow: -100)
    
    func adjustGradient(gradient: [Color]) {
        gradientA = gradient
        gradientB = gradient
    }
    
    func setGradient(gradient: [Color]) {
        if firstPlane {
            gradientB = gradient
        } else {
            gradientA = gradient
        }
        firstPlane = !firstPlane
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: gradientA), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            LinearGradient(gradient: Gradient(colors: gradientB), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
                .opacity(firstPlane ? 0 : 1)
                .onValueChanged(currentPrayer) { x in
                    // start a 0.1 second timer that updates the view
                    // to avoid state change issues
                    print("GRADIENT PRAYER CHANGED")
                    
                    // if last fire of timer happened sufficiently long ago,
                    // we know that the state change is being caused by a change in currentPrayer
                    if lastTimerDate.timeIntervalSinceNow < -0.02 {
                        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { t in
                            lastTimerDate = Date()
                            print("GRADIENT TIMER CALLED")
                            let startColors = appearance.colors(for: appearance.isDynamic ? currentPrayer : nil)
                            withAnimation {
                                setGradient(gradient: [startColors.0, startColors.1])
                            }
                        })
                    }
                }
        }
        
        //                                                    let settings = AthanManager.shared.appearanceSettings
        //                                                    let startColors = settings.colors(for: settings.isDynamic ? manager.currentPrayer : nil)
        //
        //                                                    if let lastShown = lastShownPrayer {
        //                                                        setGradient(gradient: [startColors.0, startColors.1])
        //                                                    } else {
        //                                                        adjustGradient(gradient: [startColors.0, startColors.1])
        //                                                    }
        //                                                    lastShownPrayer = manager.currentPrayer
        
    }
}

@available(iOS 13.0.0, *)
class DragState: ObservableObject {
    @Published var progress: Double = 0
    @Published var dragIncrement: Int = 0
    @Published var showCalendar: Bool = false
}

@available(iOS 13.0.0, *)
struct MainSwiftUI: View {
    
    @EnvironmentObject var manager: ObservableAthanManager
    
    //    var tomorrowPeekProgress = CurrentValueSubject<Double, Never>(0.0)
    @ObservedObject var dragState = DragState()
    @State var minuteTimer: Timer? = nil
    
    @State var settingsToggled = false
    @State var locationSettingsToggled = false
    
    @State var currentView = CurrentView.Main
    
    @State var todayHijriString = hijriDateString(date: Date())
    @State var tomorrowHijriString = hijriDateString(date: Date().addingTimeInterval(86400))
    
    @State var nextRoundMinuteTimer: Timer?
    @State var percentComplete: Double = 0.0
    
    func getPercentComplete() -> Double {
        var currentTime: Date?
        if let currentPrayer = manager.todayTimes.currentPrayer() {
            currentTime = manager.todayTimes.time(for: currentPrayer)
        } else { // if current prayer nil (post midnight, before fajr), set current time to approximately today's isha, subtracting by a day
            currentTime = manager.todayTimes.time(for: .isha).addingTimeInterval(-86400)
        }
        
        var nextTime: Date?
        if let nextPrayer = manager.todayTimes.nextPrayer() {
            nextTime = manager.todayTimes.time(for: nextPrayer)
        } else { // if next prayer is nil (i.e. we are on isha) use tomorrow fajr
            nextTime = manager.tomorrowTimes.time(for: .fajr)
        }
        
        return Date().timeIntervalSince(currentTime!) / nextTime!.timeIntervalSince(currentTime!)
    }
    
    static func hijriDateString(date: Date) -> String {
        let hijriCal = Calendar(identifier: .islamic)
        let df = DateFormatter()
        df.calendar = hijriCal
        df.dateStyle = .medium
        print("here")
        if Locale.preferredLanguages.first?.hasPrefix("ar") ?? false {
            df.locale = Locale(identifier: "ar_SY")
        }
        
        return df.string(from: date)
    }
    
    
    let weakImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    let strongImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // publishes counter of 4 ticks
    //    var dragPublisher: AnyPublisher<Double, Never> {
    //        return dragState.$progress
    //            .eraseToAnyPublisher()
    //    }
    
    // necessary to allow ARC to throw out unused values
    var dragCancellable: AnyCancellable?
    
    init() {
        dragCancellable = dragState.$progress
            .receive(on: RunLoop.main)
            // pass along last value, and whether we had an increase
            .scan((0.0, 0), { [self] (tup, new) -> (Double, Int) in
                let r1 = Int(tup.0 / 0.33)
                let r2 = Int(new / 0.33)
                
                if r1 != r2 {
                    print(r1, r2)
                    if r2 > r1 {
                        if r2 == 3 {
                            DispatchQueue.main.async {
                                //                                print("STRONG")
                                self.strongImpactGenerator.impactOccurred()
                            }
                        } else {
                            DispatchQueue.main.async {
                                //                                print("WEAK")
                                self.weakImpactGenerator.impactOccurred()
                            }
                        }
                    }
                }
                
                return (new, r2)
            })
            .map { v in
                //                print("PUHING: \(v.1)")
                return v.1
            }
            .assign(to: \.dragIncrement, on: dragState)
        //            .eraseToAnyPublisher()
        //            .assign(to: \.dragIncrement, on: self)
        
        //        cancellablePub2 = dragState.$progress
        //            .receive(on: RunLoop.main) // latch showcalendar
        ////            .map {
        ////                $0 > 0.999
        ////            }
        ////            .buffer(size: 2, prefetch: .keepFull, whenFull: .dropOldest)
        //            .scan(false, { (isOn, prog) -> Bool in
        //                if prog > 0.999 {
        //                    return true
        //                } // else return last value we published
        //                return
        ////                return
        //                isOn || prog > 0.999 // latch. if was true, stay true until we get both to be false
        //            })
        //            .assign(to: \.showCalendar, on: dragState)
        
        
        
        //        cancellablePub3 = dragState.$progress
        //            .receive(on: RunLoop.main) // latch showcalendar
        //            .scan(0, { (i, out) -> Double in
        //                return (i > out) ? i : out
        //            })
        //
        ////            .buffer(size: 2, prefetch: .keepFull, whenFull: .dropOldest)
        ////            .scan(false, { (isOn, prog) -> Bool in
        ////                isOn || prog > 0.999 // latch. if was true, stay true until we get both to be false
        ////            })
        //            .assign(to: \.highestProgress, on: dragState)
        
        //        highestProgress
        
    }
    
    @GestureState private var dragOffset = CGSize.zero
    
    var body: some View {
        
        ZStack {
            GeometryReader { g in
                let timeRemainingString: String = {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: Date(),
                                                                to: AthanManager.shared.guaranteedNextPrayerTime())
                    // 1h 2m | 1h | 53m | 10s
                    if comps.hour == 0 && comps.minute == 0 {
                        return "<1m left"
                    } else if comps.minute == 0 { // only
                        return "\(comps.hour!)h left"
                    } else if comps.hour == 0 { // only mins
                        return "\(comps.minute!)m left"
                    }
                    return "\(comps.hour!)h \(comps.minute!)m left"
                }()
                
                GradientView(currentPrayer: $manager.currentPrayer, appearance: $manager.appearance)
                    .equatable()
                    .sheet(isPresented: $dragState.showCalendar) { // set highest progress back to 0 when we know the view disappeared
                        CalendarView()
                    }
                
                VStack(alignment: .leading) {
                    switch currentView {
                    case .Location:
                        LocationSettingsView(parentSession: $currentView, locationPermissionGranted: $manager.locationPermissionsGranted)
                            .equatable()
                            .transition(.opacity)
                        
                    case .Settings:
                        SettingsView(parentSession: $currentView)
                            .transition(.opacity)
                    case .Main:
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .center, spacing: 0) {
                                    Spacer()
                                    MoonView3D()
                                        .frame(width: g.size.width / 3, height: g.size.width / 3, alignment: .center)
                                        .offset(y: 12)
                                        .shadow(radius: 3)
                                        .flipsForRightToLeftLayoutDirection(false)
                                    Spacer()
                                }
                                .opacity(1 - 0.8 * dragState.progress)
                                
                                HStack(alignment: .bottom) {
                                    VStack(alignment: .leading) {
                                        
                                        PrayerSymbol(prayerType: manager.currentPrayer)
                                            .foregroundColor(.white)
                                            .font(Font.system(.title).weight(.medium))
                                        
                                        Text(manager.currentPrayer.localizedOrCustomString())
                                            .font(.largeTitle)
                                            .bold()
                                            .foregroundColor(.white)
                                    }
                                    .opacity(1 - 0.8 * dragState.progress)
                                    
                                    Spacer() // space title | qibla
                                    
                                    VStack(alignment: .trailing, spacing: 0) {
                                        QiblaPointerView(angle: $manager.currentHeading,
                                                         qiblaAngle: $manager.qiblaHeading)
                                            .frame(width: g.size.width * 0.2, height: g.size.width * 0.2, alignment: .center)
                                            .offset(x: g.size.width * 0.03, y: 0) // offset to let pointer go out
                                        
                                        
                                        // for now, time remaining will only show seconds on ios >=14
                                        if #available(iOS 14.0, *) {
                                            Text("\(AthanManager.shared.guaranteedNextPrayerTime(), style: .relative) \(NSLocalizedString("left", comment: ""))")
                                                .fontWeight(.bold)
                                                .autocapitalization(.none)
                                                .foregroundColor(Color(.lightText))
                                                .multilineTextAlignment(.trailing)
                                                .minimumScaleFactor(0.01)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .lineLimit(1)
                                                .opacity(1 - 0.8 * dragState.progress)
                                            
                                        } else {
                                            // Fallback on earlier versions
                                            Text("\(timeRemainingString)")
                                                .fontWeight(.bold)
                                                .autocapitalization(.none)
                                                .foregroundColor(Color(.lightText))
                                                .multilineTextAlignment(.trailing)
                                                .minimumScaleFactor(0.01)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .lineLimit(1)
                                                .opacity(1 - 0.8 * dragState.progress)
                                            
                                        }
                                    }
                                }
                                
                                ProgressBar(progress: CGFloat(percentComplete), lineWidth: 10,
                                            outlineColor: .init(white: 1, opacity: 0.2), colors: [.white, .white])
                                    .onAppear(perform: { // wake update timers that will update progress
                                        nextRoundMinuteTimer = {
                                            // this gets called again when the view appears -- have it invalidated on appear
                                            let comps = Calendar.current.dateComponents([.second], from: Date())
                                            let secondsTilNextMinute = 60 - comps.second!
                                            return Timer.scheduledTimer(withTimeInterval: TimeInterval(secondsTilNextMinute),
                                                                        repeats: false) { _ in
                                                percentComplete = getPercentComplete()
                                                minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { _ in
                                                    percentComplete = getPercentComplete()
                                                    todayHijriString = MainSwiftUI.hijriDateString(date: Date())
                                                    tomorrowHijriString = MainSwiftUI.hijriDateString(date: Date().addingTimeInterval(86400))
                                                })
                                            }
                                        }()
                                        percentComplete = getPercentComplete()
                                    })
                                    .onDisappear {
                                        minuteTimer?.invalidate()
                                        nextRoundMinuteTimer?.invalidate()
                                        minuteTimer?.invalidate()
                                    }
                                    .opacity(1 - 0.8 * dragState.progress)
                                
                                let cellFont = Font.system(size: g.size.width * 0.06)
                                let timeFormatter: DateFormatter = {
                                    let df = DateFormatter()
                                    df.timeStyle = .short
                                    if Locale.preferredLanguages.first?.hasPrefix("ar") ?? false {
                                        df.locale = Locale(identifier: "ar_SY")
                                    }
                                    return df
                                }()
                                
                                ZStack {
                                    Rectangle()
                                        .foregroundColor(.init(.sRGB, white: 1, opacity: 0.000001)) // to allow gestures from middle of box
                                    
                                    VStack(alignment: .leading, spacing: 18) { // bottom of prayer names
                                        ForEach(0..<6) { pIndex in
                                            let p = Prayer(index: pIndex)
                                            let highlight: PrayerHighlightType = {
                                                var h = PrayerHighlightType.present
                                                if p == manager.todayTimes.currentPrayer() {
                                                    h = .present
                                                } else if manager.todayTimes.currentPrayer() == nil {
                                                    h = .future
                                                } else {
                                                    h = p.rawValue() < manager.currentPrayer.rawValue() ? .past : .future
                                                }
                                                return h
                                            }()
                                            
                                            HStack {
                                                Text(p.localizedOrCustomString())
                                                    .foregroundColor(highlight.color())
                                                    .font(cellFont)
                                                    .bold()
                                                
                                                Spacer()
                                                Text(timeFormatter.string(from: manager.todayTimes.time(for: p)))
                                                    // replace 3 with current prayer index
                                                    .foregroundColor(highlight.color())
                                                    .font(cellFont)
                                                    .bold()
                                            }
                                            .opacity(min(1, 1 - 0.8 * dragState.progress))
                                            .rotation3DEffect(
                                                Angle(degrees: dragState.progress * 90 - 0.001),
                                                axis: (x: 1, y: 0, z: 0.0),
                                                anchor: .top,
                                                anchorZ: 0,
                                                perspective: 0.1
                                            )
                                            .animation(.linear(duration: 0.2))
                                        }
                                    }
                                    
                                    VStack(alignment: .center, spacing: 18) {
                                        Text("Show Calendar")
                                            .font(Font.body.bold())
                                        Image(systemName: dragState.dragIncrement > 2 ? "arrow.up.circle.fill" : "arrow.up.circle") // arrow.up.circle.fill
                                            .font(.title)
                                        Image(systemName: dragState.dragIncrement > 1 ? "circle.fill" : "circle")
                                            .font(Font.body.bold())
                                        Image(systemName: dragState.dragIncrement > 0 ? "circle.fill" : "circle")
                                            .font(Font.body.bold())
                                    }
                                    .foregroundColor(Color(.lightText))
                                    .opacity(max(0, dragState.progress * 1.3 - 0.3))
                                    .animation(.linear(duration: 0.2))
                                    
                                    //                                    HStack {
                                    //                                        Text("text")
                                    //                                            .foregroundColor(PrayerHighlightType.future.color())
                                    //                                            .font(cellFont)
                                    //                                            .bold()
                                    //                                        Spacer()
                                    //                                    }
                                    //                                    .opacity(max(0, tomorrowPeekProgress * 1.3 - 0.3))
                                    //                                    .rotation3DEffect(
                                    //                                        Angle(degrees: max(0, tomorrowPeekProgress - 0.3) * 100 - 90),
                                    //                                        axis: (x: 1, y: 0, z: 0.0),
                                    //                                        anchor: .bottom,
                                    //                                        anchorZ: 0,
                                    //                                        perspective: 0.1
                                    //                                    )
                                }
                                
                                .gesture(
                                    DragGesture(minimumDistance: 0.1, coordinateSpace: .global)
                                        .onEnded({ _ in
                                            withAnimation(Animation.linear(duration: 0.05)) {
                                                dragState.progress = 0
                                            }
                                        })
                                        .updating($dragOffset, body: { (value, state, transaction) in
                                            //                                            state = value.translation
                                            //                                            dragState.showCalendar = false
                                            dragState.progress = Double(max(0.0, min(1.0, value.translation.height / -140)))
                                            if dragState.progress > 0.999 {
                                                dragState.showCalendar = true
                                                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { t in
                                                    // if still on max after half a second, go back to zero
                                                    // this is necessary because swiftui has a big where onEnded is
                                                    // not called if a sheet apepars
                                                    if dragState.progress > 0.999 {
                                                        dragState.progress = 0
                                                    }
                                                }
                                                
                                            }
                                        })
                                )
                            }
                            .padding([.leading, .trailing])
                            .padding([.leading, .trailing])
                            
                            ZStack {
                                
                                VStack {
                                    Spacer()
                                    HStack(alignment: .center) {
                                        // Location button
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            withAnimation {
                                                currentView = (currentView != .Main) ? .Main : .Location
                                            }
                                        }) {
                                            HStack(spacing: 1) {
                                                Image(systemName: manager.locationPermissionsGranted && LocationSettings.shared.useCurrentLocation ? "location.fill" : "location.slash")
                                                    .foregroundColor(Color(.lightText))
                                                    .font(Font.body)
                                                
                                                Text("\(manager.locationName)")
                                                    .foregroundColor(Color(.lightText))
                                                    .font(Font.body.weight(.bold))
                                                
                                            }
                                        }
                                        .padding(12)
                                        .offset(x: -14, y: 12)
                                        
                                        Spacer()
                                        
                                        // Settings button
                                        Button(action: {
                                            let lightImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                                            lightImpactFeedbackGenerator.impactOccurred()
                                            withAnimation {
                                                currentView = (currentView != .Main) ? .Main : .Settings // if we were in location, go back to main
                                            }
                                        }) {
                                            Image(systemName: "gear")
                                                .padding(12)
                                        }
                                        .foregroundColor(Color(.lightText))
                                        .font(Font.body.weight(.bold))
                                        .offset(x: 12, y: 12)
                                    }
                                    .padding([.leading, .trailing, .bottom])
                                    .padding([.leading, .trailing, .bottom])
                                }
                                
                                VStack {
                                    ZStack() {
                                        VStack(alignment: .center) {
                                            ZStack {
                                                Text("\(todayHijriString)")
                                                    .fontWeight(.bold)
                                                    .lineLimit(1)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .padding([.trailing, .leading])
                                                    .foregroundColor(Color(.lightText))
                                                    .opacity(min(1, 1 - 0.8 * dragState.progress))
                                                    .rotation3DEffect(
                                                        Angle(degrees: dragState.progress * 90 - 0.001),
                                                        axis: (x: 1, y: 0, z: 0.0),
                                                        anchor: .top,
                                                        anchorZ: 0,
                                                        perspective: 0.1
                                                    )
                                                    .animation(.linear(duration: 0.05))
                                                
                                                Text("\(tomorrowHijriString)")
                                                    .fontWeight(.bold)
                                                    .lineLimit(1)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .padding([.trailing, .leading])
                                                    .foregroundColor(.white)
                                                    .opacity(max(0, dragState.progress * 1.3 - 0.3))
                                                    .rotation3DEffect(
                                                        Angle(degrees: max(0, dragState.progress - 0.3) * 90 - 90),
                                                        axis: (x: 1, y: 0, z: 0.0),
                                                        anchor: .bottom,
                                                        anchorZ: 0,
                                                        perspective: 0.1
                                                    )
                                                    .animation(.linear(duration: 0.05))
                                                
                                            }
                                            //                                            Text("Tap the Hijri date to view\nan athan times table.")
                                            //                                                .foregroundColor(.white)
                                            //                                                .font(.subheadline)
                                            
                                        }
                                        .offset(y: 24)
                                        // include percentComplete * 0 to trigger refresh based on Date()
                                        SolarView(progress: CGFloat(0 * percentComplete) + CGFloat(0.5 + Date().timeIntervalSince(manager.todayTimes.dhuhr) / 86400),
                                                  sunlightFraction: CGFloat(manager.todayTimes.maghrib.timeIntervalSince(manager.todayTimes.sunrise) / 86400),
                                                  dhuhrTime: manager.todayTimes.dhuhr,
                                                  sunriseTime: manager.todayTimes.sunrise)
                                            .equatable()
                                            .opacity(1 - 0.8 * dragState.progress)
                                    }
                                    
                                    // dummy stack used for proper offset
                                    HStack(alignment: .center) {
                                        Text("Spacer")
                                            .font(Font.body.weight(.bold))
                                        Spacer()
                                        Image(systemName: "gear")
                                            .font(Font.body.weight(.bold))
                                    }
                                    .opacity(0)
                                    .padding([.leading, .trailing, .bottom])
                                    .padding([.leading, .trailing, .bottom])
                                }
                            }
                        }
                        .transition(.opacity)
                    //                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                    }
                }
            }
        }
    }
}

@available(iOS 13.0.0, *)
struct ProgressBar: View {
    var progress: CGFloat
    @State var lineWidth: CGFloat = 7
    @State var outlineColor: Color
    
    var colors: [Color] = [Color.white, Color.white]
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(outlineColor)
                .frame(height: lineWidth)
                .cornerRadius(lineWidth * 0.5)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(colors.first)
                        .frame(width: max(lineWidth, progress * g.size.width), height: lineWidth)
                        .cornerRadius(lineWidth * 0.5)
                }
            }
            .padding(.zero)
            .frame(height: lineWidth)
        }
    }
}

@available(iOS 13.0.0, *)
struct MainSwiftUI_Previews: PreviewProvider {
    static var previews: some View {
        MainSwiftUI()
            .environmentObject(ObservableAthanManager.shared)
            .previewDevice("iPhone Xs")
        
    }
}
