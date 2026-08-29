# Running the app, without writing any code

You do not need to program anything to run this. Xcode is being used here as a
Run button and nothing else. This page assumes you have a Mac and an iPhone and
have never opened Xcode before.

There are two ways to see the app. The **simulator** needs no Apple account, no
cable, and no setup beyond installing Xcode — start there. Putting it on your
**actual phone** takes about ten more minutes and is worth doing once you want to
carry it around Tallinn.

---

## 0. Check your Mac can run it

Click the Apple menu → About This Mac. You need **macOS 14.5 (Sonoma) or later**,
because this project needs Xcode 16 or later to open.

If your Mac is older than that, stop here and tell Claude — the project can be
converted to a format older Xcodes understand.

Your iPhone needs **iOS 17 or later** (iPhone XS and newer all qualify).

---

## 1. Install Xcode

Open the **App Store** on your Mac, search for **Xcode**, install it.

It is a very large download — 10 GB or more, commonly half an hour or longer.
Start it and go do something else. When it finishes, open Xcode once and let it
install the extra components it asks for.

---

## 2. Get the code onto your Mac

You do not need git or the Terminal.

1. Go to
   <https://github.com/etibarhasanov/TallinnTasteBudsApp/tree/claude/ios-app-tallinn-taste-buds-dsywel>
2. Click the green **Code** button → **Download ZIP**.
3. Double-click the downloaded ZIP to unpack it.
4. Open the unpacked folder and double-click **TallinnTasteBuds.xcodeproj**.

Xcode opens. Ignore everything on screen except the toolbar at the top.

> Each time Claude pushes a change, download the ZIP again the same way. If that
> gets tedious, install **GitHub Desktop** (<https://desktop.github.com>) — it is
> a normal Mac app with a Fetch button, no Terminal involved.

---

## 3. See it in the simulator (no account needed)

In the toolbar at the top of the Xcode window there is a dropdown that probably
says *Any iOS Device*. Click it and choose any **iPhone 16** (or whichever
iPhone is listed under Simulator).

Press the **▶︎ play button**, or ⌘R.

The first build takes a couple of minutes. Then a fake iPhone appears on your
screen with the app running in it. You can click around it with the mouse.

That is the whole loop: Claude pushes, you download, you press play.

---

## 4. Put it on your actual iPhone

### 4a. Sign in with your ordinary Apple ID

You do **not** need to pay Apple $99 for this. Your normal Apple ID is enough.

1. Xcode menu → **Settings…** → **Accounts** tab.
2. Click **+** → **Apple ID** → sign in with the Apple ID you already use.

### 4b. Tell the project to use your account

1. In the left sidebar click the blue **TallinnTasteBuds** project icon at the
   very top.
2. In the main area choose the **TallinnTasteBuds** target, then the
   **Signing & Capabilities** tab.
3. Tick **Automatically manage signing**.
4. In **Team**, choose your name — it will say *(Personal Team)*.
5. If a red error appears about the bundle identifier being unavailable, change
   **Bundle Identifier** from `ee.tallinntastebuds.app` to something nobody else
   has used, like `com.yourname.tallinntastebuds`. That is the only text you will
   ever have to type.

### 4c. Prepare the phone

1. Plug the iPhone into the Mac. Unlock it and tap **Trust** if asked.
2. On the phone: **Settings → Privacy & Security → Developer Mode** → turn it on.
   The phone restarts.
3. Back in Xcode, pick your iPhone from that same toolbar dropdown.

### 4d. Run it

Press **▶︎**. Xcode builds and installs.

The first time, the app will refuse to open and the phone will complain about an
untrusted developer. Fix it once:

**Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.

Now open the app from your home screen.

---

## The seven-day catch

With a free Apple ID, Apple lets the app live on your phone for **7 days**. After
that it stops opening until you plug in and press ▶︎ again, which takes a minute
and resets the clock. Nothing is lost — your saved places stay put.

That limit exists because you have not paid for the Apple Developer Program
($99/year). Paying removes it and unlocks **TestFlight**, which installs the app
over the air with no cable and no Mac needed after the first setup. It is only
worth it when you want the app on your phone permanently, or on other people's
phones.

---

## Things that go wrong, and what they mean

| What you see | What to do |
| --- | --- |
| *"Unsupported Xcode version" / the project will not open* | Your Xcode is older than 16. Update it, or tell Claude. |
| *"Failed to register bundle identifier"* | Someone already used that id. Change it as in step 4b. |
| *"Untrusted Developer"* on the phone | Trust it: Settings → General → VPN & Device Management. |
| App opens but the map is empty | It could not reach the site and has no snapshot yet. Check the phone's connection, then close the app fully and reopen it. |
| App worked yesterday, now it will not open | The 7 days are up. Plug in, press ▶︎. |
| Location button does nothing | Allow location when asked, or iPhone Settings → Tallinn Tastebuds → Location. |

## What you never have to do

Edit a file, use the Terminal, run `git`, install anything besides Xcode, or
understand Swift. If something needs changing in the app, that is Claude's job —
describe what is wrong and it gets pushed to the branch.

Content is a different matter and stays entirely yours: places, photos, blurbs
and discounts all come from the website repo, and editing them there updates the
app by itself. See the main [README](../README.md).
