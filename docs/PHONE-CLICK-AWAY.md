# Clicking away from the phone

A click anywhere that isn't the Quick Panel's phone closes it, including the empty
corners of the box around the tilted phone. Issue [#47](https://github.com/Blapples/SekaiPop/issues/47).

## Why there was a dead zone

The phone's window takes the mouse only inside one rectangle (`hitRect` in
`QuickPanel.qml`), and everything else lets clicks through, which closes the panel.
That rectangle is the box around the phone as it is drawn. In 2.5D the phone leans, so
the box has big empty corners (upper left, lower right). A click there landed on the
panel's window, nothing on the phone took it, and the panel stayed open. In 2D the
corners outside the rounded screen had the same problem, only smaller.

## How it works now

- `PhoneMath.js` `silhouette()` projects the phone's outline with the matrix it is drawn
  with: the front's rounded outline, the back's (the body's thickness), and boxes for
  what stands out of it (the side buttons; the flat Power button in 2D). Their convex hull is
  the phone's shape on screen. `insideConvex()` tests a point against it.
- `PhoneBody.outlinePoly` is that polygon for the pose it is drawn in right now, in the
  phone's own coordinates (`frontMatrix`, so the 2D phone's direct draw is right too).
- `QuickPanel.qml` `besidePhone`: a MouseArea over `hitRect`, under the phone. A press
  that nothing on the phone took reaches it. On the outline (3 units of slack for the
  antialiased edge) it lets go; beside it, it closes the panel, on the Quick and Apps
  screens alike.

## What it doesn't do

- **The click is used up**, like the Apps screen's click-away. A click in those corners
  closes the phone but doesn't also reach the window under it. Letting it through would
  mean a window mask the shape of the phone, and Quickshell's `Region` only does
  rectangles and ellipses: it would have to be a stack of strips, moved every frame of
  the bounce.
- The Settings phone still takes the mouse over its whole rectangle (it faces straight on,
  so only its rounded corners are outside it).

Test: `tests/phone-test/click_away_test.js`.
