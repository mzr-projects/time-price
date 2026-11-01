<<<<<<< HEAD
# time-price
=======
<<<<<<< HEAD
# time-price
=======
# TimePrice

TimePrice turns a price into hours of deep work at your net hourly wage. A wishlist link, and on iPhone a shielded app, stays closed until a real focus session finishes. The session counts foreground time only. There is no skip.

There is no account, no server, and no analytics. Wage, wishlist, focus, unlocks, and the deep-work log stay on the device.

## Wage

Money uses `Decimal`. Two inputs are stored separately, with an explicit source, so saving one does not erase the other.

Direct: the net hourly wage after tax and work expenses, plus an ISO currency code. The default currency is USD.

Derived:

```
annualNet = annualGross * (1 - taxRate) - annualWorkExpenses
netHourly = annualNet / annualHours
```

Tax rate is from 0 through 0.80. Annual hours default to 2080. If annual net or annual hours is not greater than zero, derivation fails. It is not coerced to zero.

Money rounds to 2 decimal places and the hourly rate to 4, with plain `NSDecimalRound`. Division by zero is an error.

Hours of deep work are `price / netHourly`. A different currency is left unchanged. There is no exchange rate in v1. Display rounds to the nearest minute: 0.5 is "30 minutes", 1 is "1 hour", 1.5 is "1 hour 30 minutes", 4.5 is "4 hours 30 minutes". A price above zero that is under 30 seconds still shows 1 minute.

## Safari

One extension codebase is built into the iOS and Mac Safari app extensions. The content script annotates a price. It does not remove it. The hours are the primary text. The original amount stays visible, smaller, in `aria-label`, and in `data-original`.

Inputs, text areas, selects, contenteditable nodes, and anything inside a form field are left alone. Payment iframes are left alone. Pages whose path contains `/checkout` or `/payment` are skipped. If the page currency is not the wage currency, the price is unchanged. v1 recognizes USD, EUR, and GBP.

The apps write a small snapshot to the App Group whenever the wage or display settings change: net hourly (string), currency code, enabled, required focus minutes, and unlock window minutes. `SharedConfig` is the only key list. The extension handler answers `getConfig` from that snapshot.

The popup shows the hourly wage, a per-site on/off toggle in `browser.storage.local`, and a note that the wage is edited in the app.

### Turn the extension on

Mac: Safari, Settings, Extensions, enable TimePrice, and allow the sites you want.

iPhone: Settings, Safari, Extensions, enable TimePrice, and allow the sites you want.

The app cannot flip that switch for you.

## Shields (iPhone)

TimePrice asks for individual Screen Time access, stores the Family Activity selection in the App Group, and shields the chosen apps, categories, and websites. Clearing a shield sets those three fields to nil. It does not call `clearAllSettings()`.

A finished focus session writes one unlock grant and lifts the shields. The grant window is 15, 30, or 60 minutes. The default is 15 because a `DeviceActivitySchedule` interval has to be at least 15 minutes. A new completion replaces an unexpired grant. It does not stack.

When the interval ends, the Device Activity monitor puts the shields back. If that callback is late, opening the app does the same check. If a grant would make the scheduled interval shorter than 15 minutes, the schedule end is moved out to 15 minutes. The in-app timer still follows the real grant end while TimePrice is open.

The shield's primary button cannot reliably open the app. It writes a `wantsFocus` flag, posts a local notification, and defers. Tapping the notification opens `timeprice://focus`. "Not now" closes the shield.

### Why Mac does not shield apps

Family Controls authorization fails under the Mac sandbox. The system looks up FamilyControlsAgent and returns error 159. The Mac app does not call Family Controls. On Mac, the pause is the Safari translation and wishlist links that open only after a focus session.

## Focus and wishlist

A session starts idle. Running time is accumulated foreground time plus the open segment since the last resume. Leaving the app for more than 15 seconds pauses at the background time. Those 15 seconds are a grace period, not extra credit. Coming back does not resume on its own. Completion is true only when elapsed time reaches the requirement, from 15 to 60 minutes, default 25. One completion writes one deep-work entry and one unlock grant.

"Earn to open" starts or resumes that session. The link opens only while the grant is unexpired. On iPhone, that same grant is what lifts the shields.

Home shows time focused today and this week.

## CSV import

Settings accepts a paste or a file. There is no Toggl API. Empty rows are ignored. The same start and end, at one-second resolution, are kept once.

Either header is optional:

```
started_at,ended_at
2026-04-02T09:00:00Z,2026-04-02T11:30:00Z
```

```
date,duration_minutes
2026-04-02,90
```

`started_at` and `ended_at` are ISO8601. `date` is `YYYY-MM-DD` or a date-time. A date with no time starts at midnight in the device time zone. `duration_minutes` is a positive number of minutes.

## Requirements

- Xcode 16
- Apple Developer Program, for a team, the App Group, and Family Controls
- iOS 17 or later
- macOS 14 or later
- The checked-in `TimePrice.xcodeproj` opens without XcodeGen. `project.yml` describes the same targets, membership, bundle ids, and settings.

## Signing

`DEVELOPMENT_TEAM` is empty on purpose. `CODE_SIGN_STYLE` is Automatic.

1. Open `TimePrice.xcodeproj` in Xcode 16.
2. Select each target, set your team, and leave signing automatic.
3. Register the App Group `group.com.timeprice.shared` and add it to every target. The entitlement files already name that group.
4. On the iOS app, the shield configuration extension, the shield action extension, and the device activity monitor, add the Family Controls capability. The entitlement key is `com.apple.developer.family-controls`.

Development on your own devices works after that capability is added. App Store and TestFlight distribution need Apple's Family Controls distribution entitlement. Request it at [https://developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution). This project does not claim that entitlement has been granted.

URL scheme: `timeprice`. `timeprice://focus` opens the timer. `timeprice://wishlist` opens the list.

The Mac app is sandboxed. It has the App Group and user-selected read-only file access so CSV import can read a file you pick. It does not include `com.apple.security.network.client`. Wishlist links use SwiftUI `openURL`, which asks the system to open the URL in the browser. That was not exercised in a sandbox on this machine.

## Tests

From `TimePriceCore`:

```
swift test
```

The package is Swift tools 5.10 and Swift language mode 5. On this Linux machine the toolchain is Swift 6.2.1, which compiles that mode. `OSLog` is not in the Linux SDK, so the core logger is a no-op there and `Logger` on Apple.

From the project root:

```
node --test SafariPriceEngine/engine.test.js
```

The price decisions live in `Extensions/Safari/Resources/engine.js`. The Node tests import that file with a small DOM stub. They are not skipped.

## Privacy

See [PRIVACY.md](PRIVACY.md). Nothing leaves the device.

## Known limit

This environment did not compile the Xcode project. `xcodebuild` was not run. There was no Simulator run and no on-device Family Controls authorization.

Regenerate the icon PNGs with `python3 Scripts/generate_icons.py`.
>>>>>>> a44ad21 (Initial Commit)
>>>>>>> 5a1c15b (initial commit)
