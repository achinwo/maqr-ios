# Smartz

Reinventing qr codes
## Things to take note of while running running locally
1. This is a bit hacky but - copy the JoliApi project into mc-ios directory
2. If using the local simulator - then edit JoliApi.swift module to include the IP address of your local server in the connection whitelist in the `sharedUrlSessionDelegate` function.
3. Run the following to autogenerate required files - 
$ brew install sourcery
$ cd <project dir>
$ sourcery


