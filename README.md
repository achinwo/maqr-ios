# Smartz

Reinventing qr codes
## Things to take note of while running running locally
1. Check out the `MaqrCore` submodule (`git submodule update --init`). It holds the `MaqrApi` client the apps link and the web designer they share code with.
2. If using the local simulator - then edit `MaqrCore/Sources/MaqrApi/MaqrApi.swift` to include the IP address of your local server in the connection whitelist in `sharedUrlSessionDelegate`.
3. Run the following to autogenerate required files - 
$ brew install sourcery
$ cd <project dir>
$ sourcery


