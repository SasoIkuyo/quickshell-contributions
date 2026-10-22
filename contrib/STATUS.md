# Desktop contributions

Base: dim-ghub/midnight-shell at `f4ade958`.

This branch separates changes developed in Caelestia ES from personal desktop settings.

- Audio: hide output devices and microphones by stable node name, restore them from “Show hidden devices”, and skip hidden outputs when cycling. Hiding never disconnects or mutes a device. Preferences are saved in the user's state directory.
- Weather: search cities through Open-Meteo, choose a result, save its coordinates, or return to automatic IP location. Older search responses cannot replace newer results.
- Rendering: avoid the extra full-screen layer when visualizer blur is disabled, upload the data texture only for the GPU renderer, and cap decorative visualizer animation at 30 fps. Hidden media panels release their audio-analysis references.
- Translation: register a native Spanish gettext catalog. 700 entries are translated; 40 remain untranslated. Terminology still needs a translation review. Explicit English uses source strings without requiring a catalog.

`experimental-updater/` preserves the Arch/paru updater for review. It is not connected to this shell's page registry. It needs broader testing before an upstream proposal. The complete integrated version is on the Caelestia ES branch.

## Validation

```sh
python -m unittest discover -s tests -v
node --test tests/qml-logic.test.js
msgfmt --check --statistics -o /tmp/caelestia-es.mo plugin/src/Caelestia/I18n/trs/es.po
```

The Python tests use fake package-manager processes; they do not install packages. The JavaScript tests exercise the QML service methods with simulated devices and network replies. The native I18n library was compiled against this base. The installed Caelestia ES interface was also exercised with real audio devices and a city search; that does not replace a fresh upstream UI test.

No pull request has been submitted to MiDnight or Quickshell.
