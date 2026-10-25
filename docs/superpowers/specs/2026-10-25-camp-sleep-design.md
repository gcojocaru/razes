# Camp sleep

The user requests a Sleep item beside Eat in the camp context menu, an hours
input and predictions of recovery before confirmation. Use the existing camp
menu and HUD-window style, replacing the indefinite Rest/Resume command.
This is a direct extension of the approved camp-food flow, implemented inline.

Sleep opens a small window, default 8 hours, with quarter-hour controls and
positive durations up to 24 hours. Opening/closing changes nothing. Confirm
returns the farmer to camp, sleeps for the chosen duration, then resumes the
preserved work queue. The timer starts on arrival, works in daytime too, and
stops on death. Sleep never begins automatically. Wake up ends it early; R
opens the sleep window or wakes the farmer if sleep is already pending.

Sleep reduces fatigue by 20 percentage points/hour and consumes 60 kcal/hour.
It cannot create food calories. Show restedness (100 minus fatigue), food
energy and health predictions, including travel home at the existing walking
rates. Use an isolated Human running the actual simulation for the prediction,
so travel, depleted energy and early death use the same rules. Warn visibly if
the chosen duration would exhaust food energy or end in death. These are game
tuning, with no new circadian, comfort, disease or nutrition systems.

One sleep or meal at a time; reject conflicting/duplicate/invalid commands.
Camp keyboard navigation must choose either item, retaining Enter for the
focused item. Remove the old direct Rest button; show Wake up only while sleep
is pending. Escape closes the window; input cannot reach field selection or
camera movement through it. Refresh predictions while time advances and stop
all controls at Game Over. No dependencies, saves or migrations. Preserve the
current edits and foreign export configuration.

Approach: extend the deterministic model and shared HUD controls. A separate
fatigue/calorie formula would drift from the simulation; a new combined needs
system adds scope. Test fixed-duration wake-up, travel, seed conservation,
preview equality/side effects, malformed inputs, meals, death and subdivision,
then actual camp/menu/window input and normal/minimum-size GPU captures.
