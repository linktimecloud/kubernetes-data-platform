package main

controllerArgs: [
	"--watch-all-namespaces",
	"--log-level=debug",
	"--log-encoding=json",
	// Turn off leader-election, otherwise user cannot upgrade from 
    // previous versions (v1.3.5 and earlier).
	// Refer to #429 for details.
	// "--enable-leader-election",
]
