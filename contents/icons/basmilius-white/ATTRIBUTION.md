# Basmilius Weather Icons

The icons in this folder are derived from **Meteocons / Weather Icons by Bas Milius**
(https://github.com/basmilius/weather-icons), licensed under the MIT License
(see `LICENSE` in this folder).

- Source package: `@bybas/weather-icons` v1.5.0 (`production/fill/all`)
- The static `wi-*.svg` files here are the basmilius artwork with their SMIL
  animations stripped, renamed to this widget's icon-stem convention.
- This folder is the panel's white icon set, used whichever icon pack the
  popup shows (`panelWhiteDir` in `contents/ui/main.qml`).

Icon stem → basmilius source mapping:

| widget stem | basmilius |
|---|---|
| day-sunny | clear-day |
| night-clear | clear-night |
| day-cloudy | partly-cloudy-day |
| night-alt-partly-cloudy | partly-cloudy-night |
| cloudy | cloudy |
| day-fog / night-fog | mist |
| day-rain | partly-cloudy-day-rain |
| night-alt-rain | partly-cloudy-night-rain |
| day-snow | partly-cloudy-day-snow |
| night-alt-snow | partly-cloudy-night-snow |
| day-thunderstorm / night-alt-thunderstorm | thunderstorms |
