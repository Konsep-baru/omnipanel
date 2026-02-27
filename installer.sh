#!/bin/bash
# =============================================================================
# OMNIPANEL V1.0 - Docker Management System
# Version: 1.0.0 - With Docker Auto-Install
# =============================================================================

set -e

# Configuration
INSTALL_DIR="/opt/omnipanel"
VENV_DIR="$INSTALL_DIR/venv"
STACKS_DIR="$INSTALL_DIR/stacks"
DNS_DIR="$INSTALL_DIR/dns"
CONFIG_DIR="$INSTALL_DIR/config"
LOGS_DIR="$INSTALL_DIR/logs"

# Service Configuration
PANEL_USER="omnipanel"
SSH_PORT="4086"
DNS_PORT="5353"
DNS_DOMAIN="lan"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# =============================================================================
# Logging Functions
# =============================================================================
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

# =============================================================================
# Get Server IP
# =============================================================================
get_server_ip() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1 || echo "127.0.0.1"
}

# =============================================================================
# Install Docker
# =============================================================================
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker already installed: $(docker --version)"
        return
    fi
    
    log_step "Installing Docker..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Add the repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif [ -f /etc/fedora-release ]; then
        # Fedora/RHEL
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # Start and enable Docker
    systemctl enable docker
    systemctl start docker
    
    log_success "Docker installed: $(docker --version)"
}

# =============================================================================
# Install Dependencies
# =============================================================================
install_dependencies() {
    log_step "Installing dependencies..."
    
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y python3 python3-pip python3-venv dnsmasq jq curl
    elif [ -f /etc/fedora-release ]; then
        dnf install -y python3 python3-pip dnsmasq jq curl
    fi
    
    log_success "Dependencies installed"
}

# =============================================================================
# Setup Docker Group
# =============================================================================
setup_docker_group() {
    # Create docker group if it doesn't exist
    if ! getent group docker >/dev/null; then
        log_step "Creating docker group..."
        groupadd docker
        log_success "Docker group created"
    else
        log_info "Docker group already exists"
    fi
}

# =============================================================================
# Setup Password (Manual/Custom Only)
# =============================================================================
setup_password() {
    echo -e "\n${CYAN}=== PASSWORD SETUP ===${NC}"
    echo "Please enter password for user $PANEL_USER"
    echo ""
    
    while true; do
        read -sp "Enter password: " PANEL_PASSWORD
        echo ""
        read -sp "Confirm password: " PASS_CONFIRM
        echo ""
        
        if [ "$PANEL_PASSWORD" != "$PASS_CONFIRM" ]; then
            echo -e "${RED}Passwords do not match!${NC}"
            continue
        fi
        
        if [ ${#PANEL_PASSWORD} -lt 6 ]; then
            echo -e "${RED}Password must be at least 6 characters!${NC}"
            continue
        fi
        
        break
    done
    
    log_success "Password set"
}

# =============================================================================
# Setup User
# =============================================================================
setup_user() {
    log_step "Creating panel user..."
    
    # Setup docker group first
    setup_docker_group
    
    # Setup password manually
    setup_password
    
    if ! id -u "$PANEL_USER" >/dev/null 2>&1; then
        useradd -m -s /bin/bash -G docker "$PANEL_USER"
        echo "$PANEL_USER:$PANEL_PASSWORD" | chpasswd
    else
        echo "$PANEL_USER:$PANEL_PASSWORD" | chpasswd
        # Ensure user is in docker group
        usermod -a -G docker "$PANEL_USER"
    fi
    
    mkdir -p "$INSTALL_DIR"
    echo "$PANEL_PASSWORD" > "$INSTALL_DIR/.password"
    chmod 600 "$INSTALL_DIR/.password"
    
    # Sudoers
    echo "$PANEL_USER ALL=(ALL) NOPASSWD: /usr/bin/docker *" > /etc/sudoers.d/omnipanel
    chmod 440 /etc/sudoers.d/omnipanel
    
    log_success "User created with custom password"
}

# =============================================================================
# Setup Directories
# =============================================================================
setup_directories() {
    log_step "Creating directories..."
    
    mkdir -p "$VENV_DIR" "$STACKS_DIR" "$DNS_DIR" "$CONFIG_DIR" "$LOGS_DIR"
    chown -R "$PANEL_USER:$PANEL_USER" "$INSTALL_DIR"
    
    log_success "Directories created"
}

# =============================================================================
# Setup SSH
# =============================================================================
setup_ssh() {
    log_step "Configuring SSH..."
    
    # Backup SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Add custom port if not exists
    if ! grep -q "^Port $SSH_PORT" /etc/ssh/sshd_config; then
        echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    fi
    
    # SSH wrapper
    cat > "$INSTALL_DIR/ssh-wrapper.sh" << 'EOF'
#!/bin/bash
export OMNIPANEL_HOME="/opt/omnipanel"
export PATH="$OMNIPANEL_HOME/venv/bin:$PATH"

clear
echo "╔════════════════════════════════════════╗"
echo "║         OMNIPANEL V1.0                 ║"
echo "║     Docker Management System           ║"
echo "║     Type 'help' for commands           ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Run panel
python3 "$OMNIPANEL_HOME/panel.py"
EOF
    chmod 755 "$INSTALL_DIR/ssh-wrapper.sh"
    
    # Remove old match block if exists
    sed -i '/^Match User omnipanel/,/^$/d' /etc/ssh/sshd_config
    
    # Add new match block
    cat >> /etc/ssh/sshd_config << EOF

Match User $PANEL_USER
    ForceCommand $INSTALL_DIR/ssh-wrapper.sh
    X11Forwarding no
    PermitTTY yes
    PasswordAuthentication yes
    MaxSessions 1
EOF

    # Test SSH config
    if sshd -t 2>/dev/null; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
        log_success "SSH configured on port $SSH_PORT"
    else
        log_error "SSH config error - restoring backup"
        cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
        exit 1
    fi
}

# =============================================================================
# Setup Python Virtual Environment
# =============================================================================
setup_venv() {
    log_step "Creating Python environment..."
    
    sudo -u "$PANEL_USER" python3 -m venv "$VENV_DIR"
    sudo -u "$PANEL_USER" "$VENV_DIR/bin/pip" install pyyaml
    
    log_success "Python environment created"
}

# =============================================================================
# Setup DNS
# =============================================================================
setup_dns() {
    log_step "Configuring DNS..."
    
    SERVER_IP=$(get_server_ip)
    
    # dnsmasq config
    cat > "$CONFIG_DIR/dnsmasq.conf" << EOF
port=$DNS_PORT
bind-interfaces
listen-address=127.0.0.1
domain=$DNS_DOMAIN
local=/$DNS_DOMAIN/
addn-hosts=$DNS_DIR/hosts
cache-size=1000
server=8.8.8.8
server=8.8.4.4
EOF

    # Initial hosts file
    echo "$SERVER_IP panel.$DNS_DOMAIN" > "$DNS_DIR/hosts"
    echo "127.0.0.1 localhost" >> "$DNS_DIR/hosts"
    
    # DNS update script
    cat > "$INSTALL_DIR/update-dns.sh" << 'EOF'
#!/bin/bash
DNS_DIR="/opt/omnipanel/dns"
DNS_DOMAIN="lan"
SERVER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
TEMP_HOSTS=$(mktemp)

echo "$SERVER_IP panel.$DNS_DOMAIN" > "$TEMP_HOSTS"
echo "127.0.0.1 localhost" >> "$TEMP_HOSTS"

# Get containers
docker ps --format '{{.Names}}' 2>/dev/null | while read container; do
    [ -n "$container" ] && echo "$SERVER_IP $container.$DNS_DOMAIN" >> "$TEMP_HOSTS"
done

# Update if changed
if ! cmp -s "$TEMP_HOSTS" "$DNS_DIR/hosts"; then
    mv "$TEMP_HOSTS" "$DNS_DIR/hosts"
    systemctl reload omnipanel-dns 2>/dev/null || systemctl restart omnipanel-dns
else
    rm -f "$TEMP_HOSTS"
fi
EOF
    chmod 755 "$INSTALL_DIR/update-dns.sh"
    
    # Systemd service
    cat > /etc/systemd/system/omnipanel-dns.service << EOF
[Unit]
Description=OmniPanel DNS
After=network.target docker.service

[Service]
Type=simple
User=$PANEL_USER
ExecStart=/usr/sbin/dnsmasq -k -C $CONFIG_DIR/dnsmasq.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # DNS update timer
    cat > /etc/systemd/system/omnipanel-dns-update.service << EOF
[Unit]
Description=DNS Update
After=docker.service

[Service]
Type=oneshot
User=$PANEL_USER
ExecStart=$INSTALL_DIR/update-dns.sh
EOF

    cat > /etc/systemd/system/omnipanel-dns-update.timer << EOF
[Unit]
Description=DNS Update Timer

[Timer]
OnCalendar=*:0/1

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable omnipanel-dns omnipanel-dns-update.timer
    systemctl start omnipanel-dns omnipanel-dns-update.timer
    
    log_success "DNS configured with server IP: $SERVER_IP"
}

# =============================================================================
# Create Panel Python Script
# =============================================================================
create_panel() {
    log_step "Creating panel interface..."
    
    cat > "$INSTALL_DIR/panel.py" << 'EOF'
#!/usr/bin/env python3
# =============================================================================
# OMNIPANEL V1.0 - Docker Management CLI
# =============================================================================

import os
import sys
import subprocess
from pathlib import Path

# Colors
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'
    BOLD = '\033[1m'

class OmniPanel:
    def __init__(self):
        self.user = os.getenv('USER', 'unknown')
        self.stacks_dir = Path("/opt/omnipanel/stacks")
        self.dns_dir = Path("/opt/omnipanel/dns")
        self.dns_domain = "lan"
        self.server_ip = self.get_server_ip()
        
    def get_server_ip(self):
        """Get server IP"""
        try:
            ip = subprocess.check_output(
                "ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1",
                shell=True, text=True
            ).strip()
            return ip if ip else "127.0.0.1"
        except:
            return "127.0.0.1"
    
    def print_help(self):
        """Show help"""
        print(f"""
{Colors.CYAN}COMMANDS:{Colors.NC}

{Colors.BOLD}SYSTEM:{Colors.NC}
  help                 - Show this help
  clear                - Clear screen
  exit                 - Exit panel
  version              - Show versions

{Colors.BOLD}IMAGES:{Colors.NC}
  image ls             - List images
  image pull <name>    - Pull image
  image rm <id>        - Remove image

{Colors.BOLD}CONTAINERS:{Colors.NC}
  container ls         - List running containers
  container ls -a      - List all containers
  container run <image> - Run container (auto-pull)
  container stop <id>  - Stop container
  container start <id> - Start container
  container restart <id> - Restart container
  container rm <id>    - Remove container
  container logs <id>  - Show logs
  container exec <id> <cmd> - Execute in container
  container stats      - Show stats

{Colors.BOLD}VOLUMES:{Colors.NC}
  volume ls            - List volumes

{Colors.BOLD}NETWORKS:{Colors.NC}
  network ls           - List networks

{Colors.BOLD}COMPOSE:{Colors.NC}
  compose ls           - List stacks
  compose create       - Create new stack
  compose start <name> - Start stack
  compose stop <name>  - Stop stack
  compose logs <name>  - Show logs

{Colors.BOLD}DNS (.{self.dns_domain}):{Colors.NC}
  dns ls               - List DNS entries
""")
    
    def run_cmd(self, cmd):
        """Run shell command"""
        try:
            subprocess.run(cmd, shell=True)
        except Exception as e:
            print(f"{Colors.RED}Error: {e}{Colors.NC}")
    
    def run_cmd_capture(self, cmd):
        """Run command and capture output"""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.stdout.strip()
        except:
            return ""
    
    def cmd_image_ls(self):
        """List images"""
        print(f"\n{Colors.CYAN}📦 IMAGES:{Colors.NC}")
        self.run_cmd("docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}'")
    
    def cmd_image_pull(self, image):
        """Pull image"""
        print(f"{Colors.YELLOW}Pulling {image}...{Colors.NC}")
        self.run_cmd(f"docker pull {image}")
    
    def cmd_image_rm(self, img_id):
        """Remove image"""
        print(f"{Colors.YELLOW}Removing image...{Colors.NC}")
        self.run_cmd(f"docker rmi {img_id}")
    
    def cmd_container_ls(self, all_c=False):
        """List containers"""
        cmd = "docker ps" + (" -a" if all_c else "")
        cmd += " --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'"
        print(f"\n{Colors.GREEN}🐳 CONTAINERS:{Colors.NC}")
        self.run_cmd(cmd)
    
    def cmd_container_run(self, image):
        """Run container"""
        print(f"{Colors.YELLOW}Running {image}...{Colors.NC}")
        
        # Check if image exists
        check = self.run_cmd_capture(f"docker image inspect {image} 2>/dev/null && echo 'exists'")
        if not check:
            print(f"{Colors.YELLOW}Image not found, pulling...{Colors.NC}")
            self.run_cmd(f"docker pull {image}")
        
        name = input("Container name (optional): ").strip()
        port = input("Port (e.g., 8080:80, or press Enter): ").strip()
        
        cmd = "docker run -d" if input("Run in background? [Y/n]: ").lower() != 'n' else "docker run -it"
        if name:
            cmd += f" --name {name}"
        if port:
            cmd += f" -p {port}"
        cmd += f" {image}"
        
        if input("Run this container? [Y/n]: ").lower() != 'n':
            self.run_cmd(cmd)
    
    def cmd_container_stop(self, name):
        """Stop container"""
        self.run_cmd(f"docker stop {name}")
    
    def cmd_container_start(self, name):
        """Start container"""
        self.run_cmd(f"docker start {name}")
    
    def cmd_container_restart(self, name):
        """Restart container"""
        self.run_cmd(f"docker restart {name}")
    
    def cmd_container_rm(self, name):
        """Remove container"""
        self.run_cmd(f"docker rm -f {name}")
    
    def cmd_container_logs(self, name, follow=False):
        """Show logs"""
        cmd = f"docker logs --tail 50"
        if follow:
            cmd += " -f"
        self.run_cmd(f"{cmd} {name}")
    
    def cmd_container_exec(self, name, command):
        """Execute in container"""
        self.run_cmd(f"docker exec -it {name} {command}")
    
    def cmd_container_stats(self):
        """Show stats"""
        self.run_cmd("docker stats --no-stream")
    
    def cmd_volume_ls(self):
        """List volumes"""
        print(f"\n{Colors.CYAN}💾 VOLUMES:{Colors.NC}")
        self.run_cmd("docker volume ls")
    
    def cmd_network_ls(self):
        """List networks"""
        print(f"\n{Colors.CYAN}🌐 NETWORKS:{Colors.NC}")
        self.run_cmd("docker network ls")
    
    def cmd_compose_ls(self):
        """List stacks"""
        print(f"\n{Colors.CYAN}📚 STACKS:{Colors.NC}")
        if not self.stacks_dir.exists():
            return
        for stack in self.stacks_dir.iterdir():
            if stack.is_dir() and (stack/'docker-compose.yml').exists():
                status = self.run_cmd_capture(f"cd '{stack}' && docker compose ps --format json 2>/dev/null")
                if 'running' in status:
                    print(f"  {Colors.GREEN}●{Colors.NC} {stack.name}")
                else:
                    print(f"  {Colors.YELLOW}○{Colors.NC} {stack.name}")
    
    def cmd_compose_create(self):
        """Create stack"""
        name = input("Stack name: ").strip()
        if not name:
            return
        
        stack_path = self.stacks_dir / name
        if stack_path.exists():
            print(f"{Colors.RED}Stack exists{Colors.NC}")
            return
        
        stack_path.mkdir()
        print(f"{Colors.YELLOW}Paste docker-compose.yml (Ctrl+D then Enter):{Colors.NC}")
        content = sys.stdin.read()
        
        if content.strip():
            (stack_path/'docker-compose.yml').write_text(content)
            print(f"{Colors.GREEN}✓ Stack created{Colors.NC}")
            
            if input("Start now? [y/N]: ").lower() == 'y':
                self.run_cmd(f"cd '{stack_path}' && docker compose up -d")
    
    def cmd_compose_start(self, name):
        """Start stack"""
        stack_path = self.stacks_dir / name
        if stack_path.exists():
            self.run_cmd(f"cd '{stack_path}' && docker compose up -d")
    
    def cmd_compose_stop(self, name):
        """Stop stack"""
        stack_path = self.stacks_dir / name
        if stack_path.exists():
            self.run_cmd(f"cd '{stack_path}' && docker compose down")
    
    def cmd_compose_logs(self, name, follow=False):
        """Show stack logs"""
        stack_path = self.stacks_dir / name
        if stack_path.exists():
            cmd = f"cd '{stack_path}' && docker compose logs --tail 50"
            if follow:
                cmd += " -f"
            self.run_cmd(cmd)
    
    def cmd_dns_ls(self):
        """List DNS entries"""
        hosts = self.dns_dir / 'hosts'
        if hosts.exists():
            print(f"\n{Colors.CYAN}🌐 DNS ENTRIES (.{self.dns_domain}):{Colors.NC}")
            with open(hosts) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        parts = line.split()
                        if len(parts) >= 2:
                            ip, domain = parts[0], parts[1]
                            color = Colors.GREEN if ip == self.server_ip else ''
                            print(f"  {color}{ip:<15}{Colors.NC} {domain}")
    
    def cmd_version(self):
        """Show versions"""
        docker_v = self.run_cmd_capture("docker --version | cut -d' ' -f3 | sed 's/,//'")
        compose_v = self.run_cmd_capture("docker compose version | cut -d' ' -f4 | sed 's/,//' 2>/dev/null || echo 'installed'")
        print(f"\n{Colors.BLUE}=== VERSIONS ==={Colors.NC}")
        print(f"  OmniPanel: 1.0.0")
        print(f"  Docker:    {docker_v}")
        print(f"  Compose:   {compose_v}")
        print(f"  Server IP: {self.server_ip}")
    
    def run(self):
        """Main loop"""
        print(f"\n{Colors.BLUE}OmniPanel V1.0 - Type 'help' for commands{Colors.NC}")
        
        while True:
            try:
                cmd_line = input(f"\n{Colors.GREEN}omni>{Colors.NC} ").strip()
                
                if not cmd_line:
                    continue
                
                parts = cmd_line.split()
                cmd = parts[0].lower()
                args = parts[1:]
                
                if cmd in ['exit', 'quit']:
                    print(f"{Colors.GREEN}Goodbye!{Colors.NC}")
                    break
                    
                elif cmd == 'clear':
                    os.system('clear')
                    
                elif cmd == 'help':
                    self.print_help()
                    
                elif cmd == 'version':
                    self.cmd_version()
                    
                # Image commands
                elif cmd == 'image':
                    if not args or args[0] == 'ls':
                        self.cmd_image_ls()
                    elif args[0] == 'pull' and len(args) > 1:
                        self.cmd_image_pull(args[1])
                    elif args[0] == 'rm' and len(args) > 1:
                        self.cmd_image_rm(args[1])
                    else:
                        print(f"{Colors.RED}Unknown image command{Colors.NC}")
                
                # Container commands
                elif cmd == 'container':
                    if not args:
                        self.cmd_container_ls()
                    elif args[0] == 'ls':
                        self.cmd_container_ls('-a' in args)
                    elif args[0] == 'run' and len(args) > 1:
                        self.cmd_container_run(args[1])
                    elif args[0] == 'stop' and len(args) > 1:
                        self.cmd_container_stop(args[1])
                    elif args[0] == 'start' and len(args) > 1:
                        self.cmd_container_start(args[1])
                    elif args[0] == 'restart' and len(args) > 1:
                        self.cmd_container_restart(args[1])
                    elif args[0] == 'rm' and len(args) > 1:
                        self.cmd_container_rm(args[1])
                    elif args[0] == 'logs' and len(args) > 1:
                        self.cmd_container_logs(args[1], '-f' in args)
                    elif args[0] == 'exec' and len(args) > 2:
                        self.cmd_container_exec(args[1], ' '.join(args[2:]))
                    elif args[0] == 'stats':
                        self.cmd_container_stats()
                    else:
                        print(f"{Colors.RED}Unknown container command{Colors.NC}")
                
                # Volume commands
                elif cmd == 'volume':
                    if not args or args[0] == 'ls':
                        self.cmd_volume_ls()
                    else:
                        print(f"{Colors.RED}Unknown volume command{Colors.NC}")
                
                # Network commands
                elif cmd == 'network':
                    if not args or args[0] == 'ls':
                        self.cmd_network_ls()
                    else:
                        print(f"{Colors.RED}Unknown network command{Colors.NC}")
                
                # Compose commands
                elif cmd == 'compose':
                    if not args or args[0] == 'ls':
                        self.cmd_compose_ls()
                    elif args[0] == 'create':
                        self.cmd_compose_create()
                    elif args[0] == 'start' and len(args) > 1:
                        self.cmd_compose_start(args[1])
                    elif args[0] == 'stop' and len(args) > 1:
                        self.cmd_compose_stop(args[1])
                    elif args[0] == 'logs' and len(args) > 1:
                        self.cmd_compose_logs(args[1], '-f' in args)
                    else:
                        print(f"{Colors.RED}Unknown compose command{Colors.NC}")
                
                # DNS commands
                elif cmd == 'dns':
                    if not args or args[0] == 'ls':
                        self.cmd_dns_ls()
                    else:
                        print(f"{Colors.RED}Unknown dns command{Colors.NC}")
                
                else:
                    print(f"{Colors.RED}Unknown command: {cmd}{Colors.NC}")
                    print(f"Type '{Colors.YELLOW}help{Colors.NC}' for commands")
                    
            except KeyboardInterrupt:
                print(f"\n{Colors.YELLOW}Use 'exit' to quit{Colors.NC}")
            except EOFError:
                print(f"\n{Colors.GREEN}Goodbye!{Colors.NC}")
                break
            except Exception as e:
                print(f"{Colors.RED}Error: {e}{Colors.NC}")

if __name__ == "__main__":
    try:
        OmniPanel().run()
    except KeyboardInterrupt:
        print(f"\n{Colors.GREEN}Goodbye!{Colors.NC}")
        sys.exit(0)
EOF

    chown "$PANEL_USER:$PANEL_USER" "$INSTALL_DIR/panel.py"
    chmod 755 "$INSTALL_DIR/panel.py"
    
    log_success "Panel created"
}

# =============================================================================
# Show Summary
# =============================================================================
show_summary() {
    SERVER_IP=$(get_server_ip)
    
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      OMNIPANEL V1.0 INSTALLED         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}Access:{NC}"
    echo "  SSH:  ssh -p $SSH_PORT $PANEL_USER@localhost"
    echo "  Pass: (your custom password)"
    echo
    echo -e "${WHITE}Server IP:{NC} $SERVER_IP"
    echo -e "${WHITE}DNS Domain:{NC} .$DNS_DOMAIN"
    echo
    echo -e "${WHITE}Quick Commands:{NC}"
    echo "  omni> help              # Show help"
    echo "  omni> container run nginx:latest  # Run nginx"
    echo "  omni> container ls       # List containers"
    echo "  omni> dns ls            # Show DNS entries"
    echo "  omni> exit              # Exit panel"
    echo
    echo -e "${YELLOW}Uninstall options:{NC}"
    echo "  sudo $0 uninstall       # Remove panel (with options)"
    echo
}

# =============================================================================
# Uninstall - FLEXIBLE
# =============================================================================
uninstall() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}   OMNIPANEL UNINSTALL                  ${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "${WHITE}This will remove OmniPanel components.{NC}"
    echo -e "${WHITE}You can choose what to keep/remove.{NC}"
    echo ""
    
    # Confirm uninstall
    read -p "Proceed with uninstall? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Cancelled${NC}"
        exit 0
    fi
    
    echo ""
    log_step "Stopping OmniPanel services..."
    
    # Stop and disable DNS service
    systemctl stop omnipanel-dns 2>/dev/null || true
    systemctl disable omnipanel-dns 2>/dev/null || true
    systemctl stop omnipanel-dns-update.timer 2>/dev/null || true
    systemctl disable omnipanel-dns-update.timer 2>/dev/null || true
    
    # Remove service files
    rm -f /etc/systemd/system/omnipanel-dns.service
    rm -f /etc/systemd/system/omnipanel-dns-update.service
    rm -f /etc/systemd/system/omnipanel-dns-update.timer
    systemctl daemon-reload
    
    log_step "Removing SSH configuration..."
    
    # Remove SSH match block
    sed -i '/^Match User omnipanel/,/^$/d' /etc/ssh/sshd_config
    
    # Remove custom port (commented)
    sed -i "s/^Port $SSH_PORT/# Port $SSH_PORT (removed by OmniPanel uninstall)/" /etc/ssh/sshd_config
    
    # Restart SSH
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    
    log_step "Removing sudoers configuration..."
    rm -f /etc/sudoers.d/omnipanel
    
    # ===== PANEL USER =====
    echo ""
    echo -e "${CYAN}=== USER REMOVAL ===${NC}"
    read -p "Remove user $PANEL_USER? [y/N]: " rm_user
    if [[ "$rm_user" =~ ^[Yy]$ ]]; then
        userdel -r "$PANEL_USER" 2>/dev/null || true
        log_info "User $PANEL_USER removed"
    else
        log_info "User $PANEL_USER kept"
    fi
    
    # ===== PYTHON VENV =====
    echo ""
    echo -e "${CYAN}=== PYTHON ENVIRONMENT ===${NC}"
    if [ -d "$VENV_DIR" ]; then
        read -p "Remove Python virtual environment? [y/N]: " rm_venv
        if [[ "$rm_venv" =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_DIR"
            log_info "Python virtual environment removed"
        else
            log_info "Python virtual environment kept at $VENV_DIR"
        fi
    fi
    
    # ===== DNSMASQ =====
    echo ""
    echo -e "${CYAN}=== DNSMASQ ===${NC}"
    if command -v dnsmasq >/dev/null 2>&1; then
        read -p "Remove dnsmasq package? [y/N]: " rm_dnsmasq
        if [[ "$rm_dnsmasq" =~ ^[Yy]$ ]]; then
            if [ -f /etc/debian_version ]; then
                apt-get remove -y dnsmasq
            elif [ -f /etc/fedora-release ]; then
                dnf remove -y dnsmasq
            fi
            log_info "dnsmasq removed"
        else
            log_info "dnsmasq kept"
        fi
    fi
    
    # ===== DOCKER =====
    echo ""
    echo -e "${CYAN}=== DOCKER ===${NC}"
    if command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}WARNING: Removing Docker will delete ALL containers, images, and volumes!${NC}"
        read -p "Remove Docker completely? [y/N]: " rm_docker
        if [[ "$rm_docker" =~ ^[Yy]$ ]]; then
            # Stop all containers
            docker stop $(docker ps -aq) 2>/dev/null || true
            # Remove all containers, images, volumes
            docker system prune -af --volumes 2>/dev/null || true
            
            if [ -f /etc/debian_version ]; then
                apt-get remove -y docker.io docker-ce docker-ce-cli containerd.io
                apt-get autoremove -y
            elif [ -f /etc/fedora-release ]; then
                dnf remove -y docker docker-ce docker-ce-cli containerd.io
            fi
            log_info "Docker removed"
        else
            log_info "Docker kept"
        fi
    fi
    
    # ===== OTHER PACKAGES =====
    echo ""
    echo -e "${CYAN}=== OTHER PACKAGES ===${NC}"
    echo "The following packages were installed as dependencies:"
    echo "  - python3, python3-pip, python3-venv"
    echo "  - jq, curl"
    read -p "Remove these packages? [y/N]: " rm_pkgs
    if [[ "$rm_pkgs" =~ ^[Yy]$ ]]; then
        if [ -f /etc/debian_version ]; then
            apt-get remove -y python3-pip python3-venv jq curl
            apt-get autoremove -y
        elif [ -f /etc/fedora-release ]; then
            dnf remove -y python3-pip jq curl
        fi
        log_info "Additional packages removed"
    else
        log_info "Additional packages kept"
    fi
    
    # ===== DATA DIRECTORY =====
    echo ""
    echo -e "${CYAN}=== DATA DIRECTORY ===${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        read -p "Remove OmniPanel data directory ($INSTALL_DIR)? [y/N]: " rm_data
        if [[ "$rm_data" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            log_info "Data directory removed"
        else
            log_info "Data directory kept at $INSTALL_DIR"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Uninstall Complete                   ${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# =============================================================================
# Main Install
# =============================================================================
main() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      OMNIPANEL V1.0 INSTALLER         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root${NC}"
        exit 1
    fi
    
    install_dependencies
    install_docker  # <-- DOCKER DIINSTALL OTOMATIS
    setup_user
    setup_directories
    setup_ssh
    setup_venv
    setup_dns
    create_panel
    
    chown -R "$PANEL_USER:$PANEL_USER" "$INSTALL_DIR"
    
    show_summary
}

# =============================================================================
# Script Entry
# =============================================================================
case "${1:-install}" in
    install)
        main
        ;;
    uninstall)
        uninstall
        ;;
    password)
        if [ -f "$INSTALL_DIR/.password" ]; then
            echo -e "${GREEN}Password: $(cat $INSTALL_DIR/.password)${NC}"
        else
            echo -e "${RED}Password file not found${NC}"
        fi
        ;;
    help)
        echo "Usage: $0 {install|uninstall|password}"
        echo "  install   - Install OmniPanel V1.0 (with Docker)"
        echo "  uninstall - Remove OmniPanel (with options)"
        echo "  password  - Show current password"
        ;;
    *)
        echo "Usage: $0 {install|uninstall|password}"
        exit 1
        ;;
esac