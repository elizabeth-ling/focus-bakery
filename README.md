**yet another pomodoro timer & app blocker...**

my attempt at building an app with a soul; built because I got fed up with Forest after using it for 8 years

![donut](images/donut.png)
![cookie](images/cookie.png)
![baker](images/baker.png)
![oven](images/oven.png)

## how to run


test: 
`xcodebuild test -scheme FocusBakery -destination 'platform=iOS Simulator, name=iPhone 16'`

see the bakery:
`xcodebuild build -scheme FocusBakery -destination 'platform=iOS Simulator, name=iPhone 16'`
then run it from Xcode, or install the built app with `xcrun simctl install`.
