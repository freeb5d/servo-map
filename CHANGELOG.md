# Changelog

## [0.8.0](https://github.com/Misoto22/servo-map/compare/v0.7.1...v0.8.0) (2026-09-30)


### Features

* **design:** add generic car renders and the render pipeline ([#62](https://github.com/Misoto22/servo-map/issues/62)) ([4560d27](https://github.com/Misoto22/servo-map/commit/4560d27eca5494f668bc356797638cd349729f56))


### Documentation

* **decisions:** record the iOS redesign of You, Settings and Trends ([#60](https://github.com/Misoto22/servo-map/issues/60)) ([2bee583](https://github.com/Misoto22/servo-map/commit/2bee583e006566de08fe876d693a83827c51b371))

## [0.7.1](https://github.com/Misoto22/servo-map/compare/v0.7.0...v0.7.1) (2026-09-30)


### Bug Fixes

* **web:** rank cheapest within the visible map ([#58](https://github.com/Misoto22/servo-map/issues/58)) ([18f58e4](https://github.com/Misoto22/servo-map/commit/18f58e4ea2adcf2a4ef3b361ded49e64e07682e7))

## [0.7.0](https://github.com/Misoto22/servo-map/compare/v0.6.1...v0.7.0) (2026-09-30)


### Features

* **shared:** credit each state's data source as its licence requires ([#55](https://github.com/Misoto22/servo-map/issues/55)) ([8520eeb](https://github.com/Misoto22/servo-map/commit/8520eebe73a535c8bf9bdab994b9f21c3b7d2c4a))

## [0.6.1](https://github.com/Misoto22/servo-map/compare/v0.6.0...v0.6.1) (2026-09-30)


### Bug Fixes

* **ingest:** keep skipped states' brands in the brand list ([#53](https://github.com/Misoto22/servo-map/issues/53)) ([d31626b](https://github.com/Misoto22/servo-map/commit/d31626bc31253ff7803a11a7ef703e9fb21b89df))
* **worker:** fetch TAS and file ACT stations under ACT ([#46](https://github.com/Misoto22/servo-map/issues/46)) ([43cb4d1](https://github.com/Misoto22/servo-map/commit/43cb4d15c0f157e468f2837b1e39b10fe6af65cc))

## [0.6.0](https://github.com/Misoto22/servo-map/compare/v0.5.0...v0.6.0) (2026-09-30)


### Features

* **worker:** keep price history in a D1 database ([#45](https://github.com/Misoto22/servo-map/issues/45)) ([49fee1d](https://github.com/Misoto22/servo-map/commit/49fee1dd8d1c07495dd2a377e7cce9ffbdd4d85a))

## [0.5.0](https://github.com/Misoto22/servo-map/compare/v0.4.1...v0.5.0) (2026-09-30)


### Features

* **accounts:** sign in with Apple and sync to Cloudflare D1 ([#42](https://github.com/Misoto22/servo-map/issues/42)) ([ee2e44f](https://github.com/Misoto22/servo-map/commit/ee2e44f4ea17291ee3c5374f6c79ca48d8a70e40))
* **alerts:** push saved-station price drops and cycle lows ([#43](https://github.com/Misoto22/servo-map/issues/43)) ([832402f](https://github.com/Misoto22/servo-map/commit/832402f0167382120b34075370afdf2e02faa2f4))
* **vehicles:** add the shared car catalogue and model picker ([#41](https://github.com/Misoto22/servo-map/issues/41)) ([30b8722](https://github.com/Misoto22/servo-map/commit/30b8722e8696e681d425cdd8603e8ba478748afb))

## [0.4.1](https://github.com/Misoto22/servo-map/compare/v0.4.0...v0.4.1) (2026-09-30)


### Refactoring

* **design:** read the app mark palette from design tokens ([#33](https://github.com/Misoto22/servo-map/issues/33)) ([3b9c3f9](https://github.com/Misoto22/servo-map/commit/3b9c3f9aed225819c3c62bcad9d6157673a494e5))

## [0.4.0](https://github.com/Misoto22/servo-map/compare/v0.3.0...v0.4.0) (2026-09-30)


### Features

* **web:** adopt brand logos and the cheapest station emphasis ([#37](https://github.com/Misoto22/servo-map/issues/37)) ([4c9e6bc](https://github.com/Misoto22/servo-map/commit/4c9e6bc39aef18ba6eddbb4e284ce362615a90db))

## [0.3.0](https://github.com/Misoto22/servo-map/compare/v0.2.2...v0.3.0) (2026-09-30)


### Features

* **ios:** audit fixes, brand logos, clearer cheapest station and finer trends ([#30](https://github.com/Misoto22/servo-map/issues/30)) ([5b0c009](https://github.com/Misoto22/servo-map/commit/5b0c009562dd238ced413ac68f7aa8771c605dbc))

## [0.2.2](https://github.com/Misoto22/servo-map/compare/v0.2.1...v0.2.2) (2026-09-30)


### Refactoring

* **clients:** drop client-side place-name casing ([#32](https://github.com/Misoto22/servo-map/issues/32)) ([5acddad](https://github.com/Misoto22/servo-map/commit/5acddadb2a943ff8546edddca62c5ee8d36150f3))

## [0.2.1](https://github.com/Misoto22/servo-map/compare/v0.2.0...v0.2.1) (2026-09-30)


### Bug Fixes

* **worker:** title-case place names at ingest ([#31](https://github.com/Misoto22/servo-map/issues/31)) ([5ef7b3f](https://github.com/Misoto22/servo-map/commit/5ef7b3fbefbd54f9c5cb50afd8bd84a95ae8dce2))


### Performance

* **ios:** make the map and trends redraw smoothly ([#28](https://github.com/Misoto22/servo-map/issues/28)) ([f844d4c](https://github.com/Misoto22/servo-map/commit/f844d4cf712568b40f09ff180712ef8b543fb248))

## [0.2.0](https://github.com/Misoto22/servo-map/compare/v0.1.0...v0.2.0) (2026-09-29)


### Features

* **ios:** release the app to TestFlight with fastlane ([#26](https://github.com/Misoto22/servo-map/issues/26)) ([d9c5457](https://github.com/Misoto22/servo-map/commit/d9c54570d77c4c67fa66d0c6a0e353ac667fc7be))

## [0.1.0](https://github.com/Misoto22/servo-map/compare/v0.0.1...v0.1.0) (2026-09-29)


### Features

* redesign web and add iOS app on a Japanese-minimal system ([#25](https://github.com/Misoto22/servo-map/issues/25)) ([05aff43](https://github.com/Misoto22/servo-map/commit/05aff43477a07846305ae10afac9d412107e75e3))
* **web:** adopt the generated fuel-gauge mark across app icon and site ([#23](https://github.com/Misoto22/servo-map/issues/23)) ([0824125](https://github.com/Misoto22/servo-map/commit/0824125b5ca250df014ce0b80fa1ca20ca1e520e))
