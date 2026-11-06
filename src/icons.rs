//! Logos des recipes rognés de leurs marges transparentes et centrés dans un carré : leurs SVG ont
//! des marges très variables, et paraîtraient de tailles différentes. PNG gardés en cache.
use std::{
    fs,
    path::{Path, PathBuf},
    sync::OnceLock,
};

use resvg::{tiny_skia, usvg};

/// Côté du PNG : net jusqu'à l'échelle 2 pour une icône affichée à 32 px.
const SIZE: u32 = 64;
const PROBE: f32 = 256.0;

fn options() -> &'static usvg::Options<'static> {
    static OPTIONS: OnceLock<usvg::Options<'static>> = OnceLock::new();
    OPTIONS.get_or_init(|| {
        let mut o = usvg::Options::default();
        o.fontdb_mut().load_system_fonts(); // quelques logos contiennent du texte
        o
    })
}

/// PNG rogné du logo `<dossier de recipe>/icon.svg`, recalculé si le SVG est plus récent.
pub fn trimmed(svg: &Path) -> Option<PathBuf> {
    let name = svg.parent()?.file_name()?.to_str()?;
    let out = dirs::cache_dir()?.join("vigie-rs/icons").join(format!("{name}.png"));
    let modified = |p: &Path| fs::metadata(p).and_then(|m| m.modified()).ok();
    if modified(&out).zip(modified(svg)).is_some_and(|(o, s)| o >= s) {
        return Some(out);
    }
    let tree = usvg::Tree::from_data(&fs::read(svg).ok()?, options()).ok()?;
    let size = tree.size();
    let scale = PROBE / size.width().max(size.height());
    let base = tiny_skia::Transform::from_scale(scale, scale);
    // Rendu en grand pour trouver le rectangle des pixels visibles…
    let mut probe = tiny_skia::Pixmap::new(PROBE as u32, PROBE as u32)?;
    resvg::render(&tree, base, &mut probe.as_mut());
    let (x0, y0, x1, y1) = bounds(&probe).unwrap_or((0, 0, PROBE as u32 - 1, PROBE as u32 - 1));
    let (w, h) = ((x1 - x0 + 1) as f32, (y1 - y0 + 1) as f32);
    let side = w.max(h);
    // …puis rendu net où ce rectangle remplit le carré, centré.
    let k = SIZE as f32 / side;
    let fit = base
        .post_translate(-(x0 as f32) + (side - w) / 2.0, -(y0 as f32) + (side - h) / 2.0)
        .post_scale(k, k);
    let mut icon = tiny_skia::Pixmap::new(SIZE, SIZE)?;
    resvg::render(&tree, fit, &mut icon.as_mut());
    fs::create_dir_all(out.parent()?).ok()?;
    icon.save_png(&out).ok()?;
    Some(out)
}

/// Icône de l'application (assets/io.github.vigie_rs.svg, incluse dans le binaire) en PNG de
/// 16 à 256 px, dans le cache : `app-<taille>.png`. Renvoie le dossier.
pub fn app_icon_dir() -> Option<PathBuf> {
    const SVG: &[u8] = include_bytes!("../assets/io.github.vigie_rs.svg");
    let dir = dirs::cache_dir()?.join("vigie-rs/app-icon");
    let tree = usvg::Tree::from_data(SVG, options()).ok()?;
    fs::create_dir_all(&dir).ok()?;
    for size in [16u32, 24, 32, 48, 64, 128, 256] {
        let out = dir.join(format!("app-{size}.png"));
        let scale = size as f32 / tree.size().width().max(tree.size().height());
        let mut pixmap = tiny_skia::Pixmap::new(size, size)?;
        resvg::render(&tree, tiny_skia::Transform::from_scale(scale, scale), &mut pixmap.as_mut());
        pixmap.save_png(&out).ok()?;
    }
    Some(dir)
}

/// Rectangle (x0, y0, x1, y1) des pixels visibles.
fn bounds(p: &tiny_skia::Pixmap) -> Option<(u32, u32, u32, u32)> {
    let w = p.width();
    let (mut x0, mut y0, mut x1, mut y1) = (u32::MAX, u32::MAX, 0, 0);
    for (i, px) in p.pixels().iter().enumerate() {
        if px.alpha() > 8 {
            let (x, y) = (i as u32 % w, i as u32 / w);
            (x0, y0, x1, y1) = (x0.min(x), y0.min(y), x1.max(x), y1.max(y));
        }
    }
    (x0 <= x1).then_some((x0, y0, x1, y1))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn icone_de_l_app() {
        let dir = app_icon_dir().expect("dossier");
        let icon = tiny_skia::Pixmap::load_png(dir.join("app-256.png")).unwrap();
        assert_eq!((icon.width(), icon.height()), (256, 256));
        assert!(bounds(&icon).is_some(), "icône vide");
    }

    #[test]
    fn rogne_et_centre() {
        let dir = std::env::temp_dir().join(format!("vigie-icone-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        // Carré rouge de 20 × 10 au milieu d'une toile de 100 × 100 : il doit remplir la largeur.
        let svg = dir.join("icon.svg");
        fs::write(&svg, r#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect x="40" y="45" width="20" height="10" fill="red"/></svg>"#).unwrap();
        let png = trimmed(&svg).expect("png");
        let icon = tiny_skia::Pixmap::load_png(&png).unwrap();
        let (x0, y0, x1, y1) = bounds(&icon).expect("pixels visibles");
        // À un pixel près (anticrénelage) : toute la largeur, la moitié de la hauteur, centré.
        assert!(x0 <= 1 && x1 >= 62, "largeur remplie : {x0}..{x1}");
        assert!((15..=17).contains(&y0) && (46..=48).contains(&y1), "hauteur centrée : {y0}..{y1}");
        fs::remove_dir_all(&dir).unwrap();
        fs::remove_file(png).unwrap();
    }
}
