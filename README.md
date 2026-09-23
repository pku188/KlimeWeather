
# KlimeWeather

Weather widget for KDE Plasma, without the noise.

Two weather sources, two layouts, and readouts you choose. Plasma 6.

This is a fork of the [Bare Weather](https://github.com/bvlthvzvr/BareWeather) widget with various QoL improvements.

<img width="956" height="442" alt="klime-weather-1" src="https://pkucaj.com/github/img/klime-weather-1.png" />

## Widget features

### Two weather sources

- **Open-Meteo** and **MET Norway** — switched with the source button in the popup.


### Two layouts, one click apart

- **Graph** — a temperature curve and precipitation band taking hourly readings in a 12, 24 or 48 hours graph view, with sunrise/sunset markers and day buttons.
- **Cards** — day tabs with the date and high/low, over a scrollable strip of hourly cards.

### Readouts you pick

- Point anywhere along the graph to read that hour's conditions.
- Up to four **Weather Elements** in the header: air pressure, feels like, humidity, UV,
precipitation rate or daily sum, wind (with a direction arrow), cloud cover, sunrise/sunset.
- Units: °C/°F (or your system locale's), km/h, mph, m/s or knots, hPa, inHg or mmHg,
  12- or 24-hour clock. Dates follow your system's date format.


### Other characteristics

- **Adaptive layout** — colors of the widget inherit the system's color scheme.

- **Meteocons icons in four styles** — fill, flat, line or monochrome, animated or still.
Your system icon theme or a folder of your own icons work too.
- **Icons throughout the toolbar** — refresh, zoom, layout switch and pin each have
  their own icon.
- **Personalize almost anything** — nearly every piece of text has its own font-size setting,
with both layouts having additional customization options.
- **Redrawn wind direction icon** — a clear arrow at a size you choose, turning to
the exact reported angle instead of snapping to the fixed set of compass points.
- **Severe-weather alerts** from the KDE FOSS Public Alert Server, from a severity you set.
- **Saved locations with favourites** — search by name, or detect one automatically.
- **Scroll through the forecast** — the mouse wheel moves through hours and days.
  How far and fast one notch travels is configurable per layout and graph view (12/24/48 hours).


### Faster and smoother

- **Icons are vector, not video** — the animated icons are Meteocons' own SVG animations,
  played by Qt Quick, instead of 3 MB of pre-rendered WebP frames. The widget package
  shrank over four times and the popup opens noticeably faster now. Each different
  icon is rendered once and shared across all weather images of the same type.

- **Never opens empty** — the last forecast is saved to disk, so after a reboot the
  widget shows weather immediately instead of waiting for the network to come up.
  If a fetch does fail, it says so and keeps retrying.
- **The graph builds only what it draws** — the widget elements, like layout types, graph
views are built in the background, so switching them is instant and never flashes an empty frame.
- **Only visible cards are drawn** — cards outside the visible strip are now hidden from the
renderer, which halves the CPU usage.
- **The card initial animation is quicker by default**, and adjustable if you want it
  slower or off.
- **The graph curve is rendered on the GPU**, on its own thread, so dragging through
  the hours stays smooth instead of re-rasterising the full width every frame.
- **Refreshes are conditional** — when the forecast has not changed, the server answers
  with a few bytes instead of the whole payload.
- **Refresh after each hour updates cards in place**, instead of recreating the full set.


## Install

### KDE Store

Right click your panel or desktop -> **Add Widgets…** -> **Get New Widgets** ->
**Download New Plasma Widgets**, then search for **KlimeWeather** 

### From a release file

1. Download the latest version from the [Releases](https://github.com/pku188/KlimeWeather/releases) page.
2. Install it — either:
   - **GUI:** Add Widgets… -> Get New Widgets -> **Install Widget from Local File…**, or
   - **Terminal:**
     ```bash
     kpackagetool6 --type Plasma/Applet --install KlimeWeather.plasmoid
     ```

### From source

```bash
python3 tools/build-plasmoid.py
kpackagetool6 --type Plasma/Applet --upgrade KlimeWeather.plasmoid
```

## Credits

- Fork of the [Bare Weather](https://github.com/bvlthvzvr/BareWeather)
- Weather data from [Open-Meteo](https://open-meteo.com)
- Weather data from [MET Norway](https://www.met.no/en)
- Icons derived from [Meteocons](https://github.com/basmilius/meteocons) by
  Bas Milius (MIT). See `contents/icons/*/ATTRIBUTION.md` for details.
- Severe-weather alerts via the [KDE FOSS Public Alert Server](https://invent.kde.org/webapps/foss-public-alert-server) (AGPL)
- Auto-detect via [Mullvad](https://mullvad.net)

## License

GPL-2.0-or-later — see [LICENSE](LICENSE).
