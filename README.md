📘 OMNIPANEL docker management V1.0 - Simple Version 

🚀 OmniPanel Docker Aanagement - Simple Version dengan Resource Limit

Panel Docker super ringan dengan batasan resource untuk menjaga performa. Cocok untuk belajar Docker, VPS terbatas, dan homelab. Hanya support Debian/Ubuntu!

---

✨ FITUR UTAMA

Fitur Keterangan
📦 Images Maksimal 6 image (cukup untuk belajar)
🐳 Containers Maksimal 10 container (tidak boros RAM)
📚 Compose Stacks Maksimal 5 stack
🚪 Akses SSH Port 4086, langsung masuk panel
🌐 DNS .lan Akses container via domain (web.lan)
🔒 Keamanan User terisolasi, tidak bisa akses shell
💻 OS Support Debian & Ubuntu ONLY
📊 Live Monitoring Cek penggunaan resource dengan limits

---

📥 INSTALASI MANUAL

Langkah 1: Download Installer

```bash
# Gunakan wget
wget -O installer.sh https://raw.githubusercontent.com/Konsep-baru/omnipanel/main/installer.sh

# Atau gunakan curl
curl -o installer.sh https://raw.githubusercontent.com/Konsep-baru/omnipanel/main/installer.sh
```

Langkah 2: Beri Izin Execute

```bash
chmod +x installer.sh
```

Langkah 3: Install (sebagai root)

```bash
sudo ./installer.sh
```

Langkah 4: Ikuti Petunjuk Password

· Masukkan password untuk user omnipanel
· Password minimal 6 karakter
· Konfirmasi password

---

🔐 LOGIN KE PANEL

```bash
ssh -p 4086 omnipanel@localhost
# Ganti 'localhost' dengan IP server jika akses dari luar
```

Contoh:

```bash
ssh -p 4086 omnipanel@192.168.1.100
```

Setelah login, Anda akan melihat:

```
╔════════════════════════════════════════════════════════════╗
║         OMNIPANEL V1.0 - SIMPLE EDITION                   ║
║     Limited: 6 Images | 10 Containers | 5 Compose Stacks  ║
║     Type 'help' for commands                              ║
╚════════════════════════════════════════════════════════════╝

omni>
```

---

📋 DAFTAR SEMUA COMMAND

🖥️ SYSTEM

```
help        - Tampilkan bantuan semua perintah
clear       - Bersihkan layar terminal
exit        - Keluar dari panel OmniPanel
version     - Lihat versi OmniPanel dan Docker
limits      - Lihat penggunaan resource saat ini
```

📦 IMAGES (maksimal 6)

```
image ls             - Lihat semua Docker images
image pull <nama>    - Download image (contoh: image pull nginx)
image rm <id>        - Hapus image berdasarkan ID
```

🐳 CONTAINERS (maksimal 10)

```
container ls              - Lihat container yang sedang running
container ls -a           - Lihat semua container (termasuk yang sudah stop)
container run <image>     - Jalankan container baru (auto-pull jika perlu)
container stop <nama>     - Stop container
container start <nama>    - Start container
container restart <nama>  - Restart container
container rm <nama>       - Hapus container
container logs <nama>     - Lihat 50 baris terakhir log
container logs <nama> -f  - Follow log (real-time)
```

💾 VOLUMES

```
volume ls        - Lihat semua Docker volumes
```

📚 COMPOSE (maksimal 5 stacks)

```
compose ls              - Lihat semua stack dengan statusnya
compose create          - Buat stack baru (paste docker-compose.yml)
compose start <nama>    - Start semua service dalam stack
compose stop <nama>     - Stop semua service dalam stack
compose logs <nama>     - Lihat log stack
compose logs <nama> -f  - Follow log stack
```

🌍 DNS (.lan domain)

```
dns ls           - Lihat semua entri DNS
```

---

📊 MONITORING RESOURCE

```bash
omni> limits
=== RESOURCE USAGE ===
  Images:     3/6
  Containers: 2/10
  Compose:    1/5
```

Saat limit tercapai:

```bash
omni> image pull mysql
Limit reached! Maximum 6 images allowed.
```

---

🚀 CONTOH PENGGUNAAN CEPAT

```bash
# 1. Login ke panel
ssh -p 4086 omnipanel@192.168.1.100

# 2. Pull image nginx
omni> image pull nginx:alpine

# 3. Jalankan container
omni> container run nginx:alpine
Container name (optional): web
Port (e.g., 8080:80): 8080:80
Run in background? [Y/n]: y
✓ Container created

# 4. Lihat container
omni> container ls
🐳 CONTAINERS:
NAME   STATUS        IMAGE          PORTS
web    Up 5 seconds  nginx:alpine   0.0.0.0:8080->80/tcp

# 5. Lihat DNS
omni> dns ls
🌐 DNS ENTRIES (.lan):
192.168.1.100   panel.lan
192.168.1.100   web.lan

# 6. Akses website
# Browser: http://192.168.1.100:8080

# 7. Lihat log
omni> container logs web

# 8. Cek penggunaan resource
omni> limits

# 9. Keluar
omni> exit
```

---

🌐 DNS .LAN DOMAIN

Semua container otomatis mendapat domain .lan:

```bash
# Contoh
container run nginx --name web
# Akses via browser:
http://web.lan:8080

# Lihat semua DNS
omni> dns ls
192.168.1.100   panel.lan
192.168.1.100   web.lan
192.168.1.100   db.lan
```

*Setting DNS di Client (Agar bisa akses .lan)

Windows:

· Control Panel → Network and Sharing Center → Change adapter settings
· Klik kanan WiFi/Ethernet → Properties
· Pilih "Internet Protocol Version 4 (TCP/IPv4)" → Properties
· Pilih "Use the following DNS server addresses"
· Preferred DNS: 192.168.1.100 (IP server OmniPanel)
· Alternate DNS: 8.8.8.8

Linux/Mac:

· System Settings → Network → DNS
· Tambah DNS Server: 192.168.1.100

Atau akses via IP langsung (lebih mudah):

```
http://192.168.1.100:8080
```

---

🛠️ UNINSTALL

```bash
sudo ./installer.sh uninstall
```

Akan menghapus:

· Semua service OmniPanel
· Konfigurasi SSH
· User omnipanel
· Direktori /opt/omnipanel

Docker TIDAK ikut terhapus (data container Anda aman).

---

📋 COMMAND ADMIN TAMBAHAN

```bash
# Lihat password (jika lupa)
sudo ./installer.sh password

# Bantuan installer
sudo ./installer.sh help
```

---

📊 SPESIFIKASI MINIMUM

Komponen Minimum Rekomendasi
RAM 512 MB 2 GB
CPU 1 core 2 core
Disk 5 GB 20 GB
OS Ubuntu 20.04+, Debian 11+ Ubuntu 22.04 / Debian 12

---

🔧 TROUBLESHOOTING

Error: Docker not found

```bash
# Install manual
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# Logout login ulang
```

*Gagal akses .lan

```bash
# Cek DNS service
sudo systemctl status omnipanel-dns

# Cek file hosts
cat /opt/omnipanel/dns/hosts

# Atau akses via IP langsung
http://192.168.1.100:8080
```

Lupa password

```bash
sudo ./installer.sh password
```

Error SSH "Connection refused"

```bash
# Cek port
ss -tlnp | grep 4086

# Cek service SSH
sudo systemctl status sshd
```

---

📁 STRUKTUR DIREKTORI

```
/opt/omnipanel/
├── venv/              # Python virtual environment
├── stacks/            # Docker compose stacks
├── dns/               # DNS hosts file
├── config/            # Konfigurasi dnsmasq
├── logs/              # Log files
├── panel.py           # Panel utama
├── ssh-wrapper.sh     # SSH wrapper
├── update-dns.sh      # DNS updater
└── .password          # Password file
```

---

🎯 OS YANG DIDUKUNG

OS Versi Status
Ubuntu 20.04, 22.04, 24.04 ✅ Support
Debian 11, 12 ✅ Support
OS Lain Fedora, RHEL, CentOS ❌ Tidak support

---

📝 LISENSI

MIT License - Silakan gunakan, modifikasi, dan sebarkan!

---

OmniPanel V1.0 - Simple Edition
Ringan, Terbatas, dan Mudah Digunakan untuk Belajar Docker! 🚀

```bash
# Install sekarang juga!
wget -O installer.sh https://raw.githubusercontent.com/Konsep-baru/omnipanel/main/installer.sh
chmod +x installer.sh
sudo ./installer.sh install
```
