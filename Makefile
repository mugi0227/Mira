.PHONY: generate build test clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project Mira.xcodeproj -scheme Mira -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project Mira.xcodeproj -scheme Mira -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' CODE_SIGNING_ALLOWED=NO test

clean:
	rm -rf Mira.xcodeproj DerivedData
