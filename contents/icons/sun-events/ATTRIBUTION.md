# Sunrise and sunset glyphs

The graph's sunrise/sunset markers. Derived from **Meteocons by Bas Milius**
(https://github.com/basmilius/meteocons, MIT — see `LICENSE` in this folder):
the `sunrise` and `sunset` icons, **fill** style, Meteocons v3.0.0-next.10.

They used to live with the retired "Basmilius" icon pack and are decoration,
not condition icons, so every icon pack uses these two. They were processed by
`tools/icon-pipeline/bake_sun_static.py`: the sun is cut at the horizon as flat
geometry (the original does it with a mask), the rays below the horizon dropped,
and the horizon line recoloured white.
