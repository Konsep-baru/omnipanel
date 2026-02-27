📘 V1.0 - SIMPLE VERSION

🚀 OmniPanel - Docker Management System via SSH

Panel Docker super ringan yang diakses melalui SSH. Cocok untuk VPS 512MB, homelab, dan belajar Docker. Installasi otomatis, siap pakai dalam 5 menit!

---

✨ FITUR UTAMA

Fitur Keterangan
🚪 Akses SSH Port 4086, langsung masuk panel (bukan shell)
🐳 Docker Install otomatis, auto-detect OS
🌐 DNS .lan Akses container via domain (web.lan, db.lan)
📦 Images Pull, list, hapus image
📋 Containers Run, stop, start, restart, logs, exec, stats
💾 Volumes List volume
🔌 Networks List network
📚 Compose Buat dan manage stack
🔒 Keamanan User terisolasi, tidak bisa akses shell
💻 Multi-OS Support Ubuntu, Debian, Fedora, dan turunannya

---

📥 INSTALASI (1 COMMAND)

```bash
wget -O omnipanel-install.sh https://raw.githubusercontent.com/Konsep-baru/omnipanel/main/install.sh
chmod +x omnipanel-install.sh
sudo ./omnipanel-install.sh install
```

---

🔐 LOGIN KE PANEL

```bash
ssh -p 4086 omnipanel@server-ip
Password: (password yang Anda buat saat install)
```

Contoh:

```bash
ssh -p 4086 omnipanel@192.168.1.100
```

Setelah login, Anda akan langsung masuk ke panel OmniPanel:

```
╔════════════════════════════════════════╗
║         OMNIPANEL V1.0                 ║
║     Docker Management System           ║
║     Type 'help' for commands           ║
╚════════════════════════════════════════╝

omni>
```

---

📋 DAFTAR SEMUA COMMAND (26 PERINTAH)

🖥️ SYSTEM

```
help        - Tampilkan bantuan semua perintah
clear       - Bersihkan layar terminal
exit        - Keluar dari panel OmniPanel
version     - Lihat versi OmniPanel, Docker, dan IP server
```

📦 IMAGES

```
image ls              - Lihat semua Docker images
image pull <nama>     - Download image (contoh: image pull nginx)
image rm <id>         - Hapus image berdasarkan ID
```

🐳 CONTAINERS

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
container exec <nama> <cmd> - Jalankan perintah di dalam container
container stats           - Lihat statistik resource (CPU, RAM)
```

💾 VOLUMES

```
volume ls        - Lihat semua Docker volumes
```

🌐 NETWORKS

```
network ls       - Lihat semua Docker networks
```

📚 COMPOSE

```
compose ls              - Lihat semua stack dengan statusnya
compose create          - Buat stack baru (paste docker-compose.yml)
compose start <nama>    - Start semua service dalam stack
compose stop <nama>     - Stop semua service dalam stack
compose logs <nama>     - Lihat log stack
compose logs <nama> -f  - Follow log stack
```

🌍 DNS

```
dns ls           - Lihat semua entri DNS (.lan domain)
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
Run this container? [Y/n]: y
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

# 8. Masuk ke container
omni> container exec web sh
/ # ls /usr/share/nginx/html/
/ # exit

# 9. Keluar dari panel
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

💡 CONTOH PENGGUNAAN LAINNYA

WordPress dengan Docker Compose

```bash
# 1. Buat file docker-compose.yml
omni> compose create
Stack name: wordpress
Paste docker-compose.yml (Ctrl+D then Enter):
version: '3.8'
services:
  db:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: root123
      MYSQL_DATABASE: wordpress
    volumes:
      - wp-db-data:/var/lib/mysql
  wordpress:
    depends_on:
      - db
    image: wordpress:latest
    ports:
      - "8081:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: root123
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wp-data:/var/www/html
volumes:
  wp-db-data:
  wp-data:
# Tekan Ctrl+D

# 2. Start stack
omni> compose start wordpress

# 3. Lihat log
omni> compose logs wordpress

# 4. Akses WordPress
# Browser: http://192.168.1.100:8081
```

Database MySQL

```bash
# 1. Jalankan MySQL
omni> container run mysql:8
Container name: mysql
Port: 3306:3306
Run in background? [Y/n]: y

# 2. Masuk ke MySQL
omni> container exec mysql mysql -u root -p
Enter password: (password dari container)
```

Aplikasi Python Sederhana

```bash
# 1. Buat Dockerfile di server
# (via SSH biasa sebagai root)

# 2. Build image
docker build -t myapp .

# 3. Jalankan via panel
omni> container run myapp
Container name: myapp
Port: 5000:5000
Run in background? [Y/n]: y
```

---

🛠️ UNINSTALL

```bash
sudo ./omnipanel-install.sh uninstall
```

Akan menghapus:

· Semua service OmniPanel
· Konfigurasi SSH
· User omnipanel
· Direktori /opt/omnipanel

Docker TIDAK ikut terhapus (data container Anda aman).

---

📊 SPESIFIKASI MINIMUM

Komponen Minimum Rekomendasi
RAM 512 MB 2 GB
CPU 1 core 2 core
Disk 5 GB 20 GB
OS Ubuntu 20.04+, Debian 11+, Fedora 38+ Semua OS modern

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
sudo ./omnipanel-install.sh password
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

OS Family Distribusi Status
Debian Debian 11, 12 ✅ Support
Ubuntu 20.04, 22.04, 24.04 ✅ Support
Ubuntu Turunan Linux Mint, Pop!_OS, Zorin ✅ Support
Fedora 38, 39, 40 ✅ Support
RHEL/CentOS 8, 9 ⚠️ Terbatas

---

📝 LISENSI

MIT License - Silakan gunakan, modifikasi, dan sebarkan!

---

OmniPanel V1.0 - Simple, Lightweight, Powerful! 🚀
