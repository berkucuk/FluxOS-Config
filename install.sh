#!/bin/bash

# FluxOS Post-Install Script
# Archinstall custom script için - chroot ortamında ROOT olarak çalışır
# GitHub: https://github.com/yourusername/fluxos-config

set -euo pipefail

# Chroot ortamında root olarak çalışıyoruz, sudo gerekmez

# Renkli çıktı
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[FluxOS] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Kullanıcı adını tespit et
detect_user() {
    # /etc/passwd'dan normal kullanıcıyı bul
    USERNAME=$(grep -E ":/home/.*:/bin/(bash|zsh|fish)" /etc/passwd | head -1 | cut -d: -f1 2>/dev/null || echo "")
    
    if [ -z "$USERNAME" ]; then
        # Alternatif: 1000 UID'li kullanıcıyı bul
        USERNAME=$(getent passwd 1000 | cut -d: -f1 2>/dev/null || echo "")
    fi
    
    if [ -z "$USERNAME" ]; then
        warn "Kullanıcı tespit edilemedi, varsayılan olarak 'user' kullanılacak"
        USERNAME="user"
    fi
    
    log "Tespit edilen kullanıcı: $USERNAME"
}

# KDE paketlerini yükle
install_kde_packages() {
    log "KDE paketleri kontrol ediliyor ve eksikler yükleniyor..."
    
    # Temel KDE paketleri
    local packages=(
        "plasma-desktop"
        "plasma-workspace"
        "plasma-systemmonitor"
        "sddm"
        "sddm-kcm"
        "konsole"
        "dolphin"
        "kate"
        "spectacle"
        "gwenview"
        "okular"
        "ark"
        "breeze"
        "breeze-gtk"
        "kde-gtk-config"
    )
    
    # Paketleri yükle (zaten yüklüyse atla)
    for package in "${packages[@]}"; do
        if ! pacman -Q "$package" &>/dev/null; then
            log "Yükleniyor: $package"
            pacman -S --noconfirm "$package" || warn "$package yüklenemedi"
        fi
    done
    
    # SDDM'i etkinleştir
    systemctl enable sddm.service
    log "SDDM servisi etkinleştirildi"
}

# Config dizinlerini oluştur
create_config_dirs() {
    local user_home="/home/$USERNAME"
    local config_dir="$user_home/.config"
    local local_share="$user_home/.local/share"
    
    log "Konfigürasyon dizinleri oluşturuluyor..."
    
    # Gerekli dizinleri oluştur
    mkdir -p "$config_dir"
    mkdir -p "$local_share/plasma"
    mkdir -p "$local_share/kservices5"
    mkdir -p "/usr/share/pixmaps/fluxos"
    
    # Sahiplik ayarla
    chown -R "$USERNAME:$USERNAME" "$user_home"
    
    log "Dizinler oluşturuldu"
}

# KDE konfigürasyonlarını kopyala
copy_kde_configs() {
    local user_home="/home/$USERNAME"
    local config_dir="$user_home/.config"
    
    log "KDE konfigürasyonları kopyalanıyor..."
    
    # Script'in bulunduğu dizindeki config dosyalarını kopyala
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_files=(
        "kdeglobals"
        "kwinrc"
        "plasma-org.kde.plasma.desktop-appletsrc"
        "plasmarc"
        "plasmashellrc"
        "systemsettingsrc"
    )
    
    # Config dosyalarını kopyala
    for config_file in "${config_files[@]}"; do
        if [ -f "$script_dir/configs/$config_file" ]; then
            cp "$script_dir/configs/$config_file" "$config_dir/"
            log "Kopyalandı: $config_file"
        else
            warn "Config dosyası bulunamadı: $config_file"
        fi
    done
    
    # Sahiplik ayarla
    chown -R "$USERNAME:$USERNAME" "$config_dir"
    
    log "KDE konfigürasyonları kopyalandı"
}

# Wallpaper ayarlarını uygula
setup_wallpapers() {
    log "Wallpaper ayarları yapılandırılıyor..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # FluxOS wallpaper dosyasını kopyala
    if [ -f "$script_dir/assets/fluxos-wallpaper.png" ]; then
        cp "$script_dir/assets/fluxos-wallpaper.png" "/usr/share/pixmaps/fluxos/"
        
        # Next teması wallpaper'larını değiştir
        if [ -d "/usr/share/wallpapers/Next" ]; then
            cp /usr/share/pixmaps/fluxos/fluxos-wallpaper.png /usr/share/wallpapers/Next/contents/images/1920x1080.png 2>/dev/null || true
            cp /usr/share/pixmaps/fluxos/fluxos-wallpaper.png /usr/share/wallpapers/Next/contents/images/2560x1440.png 2>/dev/null || true
            cp /usr/share/pixmaps/fluxos/fluxos-wallpaper.png /usr/share/wallpapers/Next/contents/images/7680x2160.png 2>/dev/null || true
            
            # Dark tema wallpaper'ları
            if [ -d "/usr/share/wallpapers/Next/contents/images_dark" ]; then
                cp /usr/share/pixmaps/fluxos/fluxos-wallpaper.png /usr/share/wallpapers/Next/contents/images_dark/1920x1080.png 2>/dev/null || true
                cp /usr/share/pixmaps/fluxos/fluxos-wallpaper.png /usr/share/wallpapers/Next/contents/images_dark/2560x1440.png 2>/dev/null || true
                cp /usr/share/pixmaps/fluxos/fluxos-wallpaper.png /usr/share/wallpapers/Next/contents/images_dark/7680x2160.png 2>/dev/null || true
            fi
        fi
        
        # Tüm .jpg wallpaper'ları değiştir
        find /usr/share/wallpapers/ -name "*.jpg" -exec cp /usr/share/pixmaps/fluxos/fluxos-wallpaper.png {} \; 2>/dev/null || true
        
        log "Wallpaper ayarları tamamlandı"
    else
        warn "FluxOS wallpaper dosyası bulunamadı: $script_dir/assets/fluxos-wallpaper.png"
    fi
}

# FluxAI-Chat kurulumu
install_fluxai_chat() {
    log "FluxAI-Chat kuruluyor..."
    
    # Geçici dizine klonla
    cd /tmp
    
    if git clone --depth 1 https://github.com/berkucuk/FluxAI-Chat.git /tmp/FluxAI-Chat; then
        cd /tmp/FluxAI-Chat
        
        # Install script'i düzenle (sudo kaldır ve desktop dosyasını global yap)
        sed -i 's/sudo //g; s|\$HOME/.local/share/applications|/usr/share/applications|g' install.sh
        
        # Kurulumu çalıştır
        bash install.sh
        
        log "FluxAI-Chat kurulumu tamamlandı"
        
        # Temizlik
        rm -rf /tmp/FluxAI-Chat
    else
        warn "FluxAI-Chat klonlanamadı, internet bağlantısını kontrol edin"
    fi
}

# Sistem ayarları
configure_system() {
    log "Sistem ayarları yapılandırılıyor..."
    
    # SDDM otomatik giriş (isteğe bağlı)
    # Uncomment aşağıdaki satırları otomatik giriş için:
    # cat > /etc/sddm.conf << EOF
    # [Autologin]
    # User=$USERNAME
    # Session=plasma
    # EOF
    
    # Kullanıcıyı wheel grubuna ekle (sudo yetkisi için)
    usermod -a -G wheel "$USERNAME" 2>/dev/null || true
    
    # Sudo ayarları (wheel grubuna izin ver)
    if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
        echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
    fi
    
    log "Sistem ayarları tamamlandı"
}

# Ana fonksiyon  
main() {
    log "FluxOS kurulum script'i başlatılıyor..."
    log "Chroot ortamında ROOT kullanıcısı olarak çalışılıyor"
    
    # Kullanıcıyı tespit et
    detect_user
    
    # Kurulum adımları
    install_kde_packages
    create_config_dirs
    copy_kde_configs
    setup_wallpapers
    install_fluxai_chat
    configure_system
    
    log "FluxOS kurulumu tamamlandı!"
    log "Sistem yeniden başlatıldığında KDE Plasma ile FluxOS deneyimi başlayacak"
}

# Script'i çalıştır
main "$@"
