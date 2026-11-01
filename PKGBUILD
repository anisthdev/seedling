# Maintainer: Asif Arbaj <asifarbaj@gmail.com>
_name=seedling
pkgname=totoro-seedling
pkgver=r0
pkgrel=1
pkgdesc="Keyboard-driven transmission-daemon client, a Quickshell menu (qs -c seedling)"
arch=('any')
url="https://github.com/anisthdev/seedling"
provides=('seedling')
conflicts=('seedling')
replaces=('seedling')
license=('unknown')
depends=('quickshell' 'uwsm' 'wl-clipboard')
optdepends=('transmission-cli: the daemon it talks to (transmission-daemon)')
makedepends=('git')
source=("git+$url.git")
sha256sums=('SKIP')

pkgver() {
    cd "$_name"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
}

package() {
    cd "$_name"
    # The Quickshell config, where `qs -c seedling` finds it; a
    # ~/.config/quickshell/seedling of your own comes first
    install -d "$pkgdir/usr/share/seedling"
    cp -r --no-preserve=ownership ./*.qml components icons views "$pkgdir/usr/share/seedling/"
    install -d "$pkgdir/etc/xdg/quickshell"
    ln -s /usr/share/seedling "$pkgdir/etc/xdg/quickshell/seedling"
    install -Dm755 seedling "$pkgdir/usr/bin/seedling"
    install -Dm644 io.github.anisthdev.Seedling.desktop \
        "$pkgdir/usr/share/applications/io.github.anisthdev.Seedling.desktop"
}
