# ============================================
# One-time New VM Setup Script
# Run from Windows / PowerShell
#
# Does everything discussed for a single new VM:
#   1. Push SSH key (idempotent)
#   2. Verify key login works
#   3. Run apt update && upgrade now
#   4. Check for cloud-init SSH drop-in
#   5. Disable password authentication (main config + cloud-init drop-in)
#   6. Set up passwordless apt update/upgrade
#   7. Set up unattended-upgrades (auto security patching + 4am auto-reboot)
#   8. Install qemu-guest-agent (optional - see toggle below)
#   9. Verify everything actually took effect
#
# EDIT THESE THREE VALUES BEFORE RUNNING:
# ============================================

$vmHost   = "172.21.234.XXX"    # IP or hostname of the new VM
$sshUser  = "youruser"          # SSH username on the VM
$installGuestAgent = $true      # set to $false to skip qemu-guest-agent install

$pubKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"

# ============================================
# Sanity checks before doing anything
# ============================================

if (-not (Test-Path $pubKeyPath)) {
    Write-Host "No public key found at $pubKeyPath - generate one first with: ssh-keygen -t ed25519" -ForegroundColor Red
    exit 1
}
$pubKey = (Get-Content $pubKeyPath).Trim()

Write-Host "===== Setting up $vmHost =====" -ForegroundColor Cyan

# ============================================
# 1. Push SSH key (safe to re-run - checks for exact match first)
# ============================================
Write-Host "`n[1/9] Pushing SSH key..." -ForegroundColor Yellow
$keyCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF '$pubKey' ~/.ssh/authorized_keys 2>/dev/null || echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
ssh "$sshUser@$vmHost" $keyCmd

# ============================================
# 2. Verify key login works BEFORE touching password auth
# ============================================
Write-Host "`n[2/9] Verifying key login..." -ForegroundColor Yellow
$testResult = ssh -o BatchMode=yes -o ConnectTimeout=5 "$sshUser@$vmHost" "echo OK" 2>$null

if ($testResult -ne "OK") {
    Write-Host "!! Key login FAILED. Stopping here - do not proceed to disabling passwords." -ForegroundColor Red
    Write-Host "!! Check that the key was pushed correctly and the VM allows password auth for step 1 to have worked." -ForegroundColor Red
    exit 1
}
Write-Host "-> Key login confirmed." -ForegroundColor Green

# ============================================
# 3. Run apt update && upgrade now
#    Done early, before touching SSH/sudoers config. Passwordless apt isn't
#    set up yet at this point, so this will prompt for the sudo password once.
# ============================================
Write-Host "`n[3/9] Running apt update && upgrade (this may take a few minutes)..." -ForegroundColor Yellow
ssh -t "$sshUser@$vmHost" "sudo apt update && sudo apt upgrade -y"

# ============================================
# 4. Check for a cloud-init drop-in that could override our SSH config change
# ============================================
Write-Host "`n[4/9] Checking for cloud-init SSH drop-in..." -ForegroundColor Yellow
$dropinCheck = ssh "$sshUser@$vmHost" "ls /etc/ssh/sshd_config.d/*cloud-init*.conf 2>/dev/null"

if ($dropinCheck) {
    Write-Host "-> Found cloud-init drop-in: $dropinCheck - will patch this too." -ForegroundColor Yellow
} else {
    Write-Host "-> No cloud-init drop-in found." -ForegroundColor Green
}

# ============================================
# 5. Disable password authentication (main config + drop-in if present)
#    Uses -t so sudo can prompt for a password interactively.
# ============================================
Write-Host "`n[5/9] Disabling password authentication..." -ForegroundColor Yellow
$sshdCmd = @"
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/*.conf 2>/dev/null
sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd
"@
ssh -t "$sshUser@$vmHost" $sshdCmd

# Also stop cloud-init from re-writing the drop-in with 'yes' on next boot, if cloud-init is present
ssh -t "$sshUser@$vmHost" "sudo sed -i 's/ssh_pwauth:.*/ssh_pwauth: false/' /etc/cloud/cloud.cfg 2>/dev/null"

# ============================================
# 6. Passwordless apt update/upgrade
# ============================================
Write-Host "`n[6/9] Setting up passwordless apt..." -ForegroundColor Yellow
$sudoersCmd = "echo '$sshUser ALL=(ALL) NOPASSWD: /usr/bin/apt update, /usr/bin/apt upgrade -y, /usr/bin/apt full-upgrade -y' | sudo tee /etc/sudoers.d/010-$sshUser-apt > /dev/null && sudo chmod 440 /etc/sudoers.d/010-$sshUser-apt && sudo visudo -c"
ssh -t "$sshUser@$vmHost" $sudoersCmd

# ============================================
# 7. Set up unattended-upgrades for ongoing automatic security patching
#    Installs the package and enables the two settings that actually turn it on:
#    APT::Periodic::Update-Package-Lists and APT::Periodic::Unattended-Upgrade.
#    Default coverage is security updates only, not every package update.
#    Also enables automatic reboots (when a patched package requires one),
#    scheduled for 4:00 AM local time on the VM.
# ============================================
Write-Host "`n[7/9] Setting up unattended-upgrades (with 4am auto-reboot)..." -ForegroundColor Yellow
$unattendedCmd = @"
sudo apt install -y unattended-upgrades apt-listchanges
sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades' <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
sudo bash -c 'cat > /etc/apt/apt.conf.d/52auto-reboot' <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
EOF
sudo systemctl enable --now unattended-upgrades
sudo systemctl is-enabled unattended-upgrades
"@
ssh -t "$sshUser@$vmHost" $unattendedCmd
Write-Host "-> unattended-upgrades installed and enabled. Security updates only by default; auto-reboot set for 04:00 (only reboots if a patched package actually requires it)." -ForegroundColor Green
Write-Host "-> Note: 04:00 is the VM's own local time/timezone, not necessarily yours - worth checking with: timedatectl" -ForegroundColor Gray

# ============================================
# 8. Install qemu-guest-agent (optional)
#    Note: also run `qm set <VMID> --agent enabled=1` and reboot the VM
#    from the Proxmox host for this to actually take effect.
# ============================================
if ($installGuestAgent) {
    Write-Host "`n[8/9] Installing qemu-guest-agent..." -ForegroundColor Yellow
    ssh -t "$sshUser@$vmHost" "sudo apt install -y qemu-guest-agent && sudo systemctl start qemu-guest-agent"
    Write-Host "-> Installed. Remember to run on the PROXMOX HOST: qm set <VMID> --agent enabled=1  then  qm reboot <VMID>" -ForegroundColor Yellow
} else {
    Write-Host "`n[8/9] Skipping qemu-guest-agent install (installGuestAgent = false)" -ForegroundColor Gray
}

# ============================================
# 9. Verification
# ============================================
Write-Host "`n[9/9] Verifying final state..." -ForegroundColor Yellow

Write-Host "-> Live sshd config check:" -ForegroundColor Yellow
ssh -t "$sshUser@$vmHost" "sudo sshd -T | grep -iE 'passwordauthentication|kbdinteractiveauthentication'"

Write-Host "-> Real-world test: forcing password auth, expecting immediate rejection..." -ForegroundColor Yellow
$rejectTest = ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password -o BatchMode=yes -o ConnectTimeout=5 "$sshUser@$vmHost" "echo SHOULD_NOT_SEE_THIS" 2>&1
if ($rejectTest -match "SHOULD_NOT_SEE_THIS") {
    Write-Host "!! WARNING: password auth still worked! Something is still overriding the config." -ForegroundColor Red
} else {
    Write-Host "-> Confirmed: password auth is rejected." -ForegroundColor Green
}

Write-Host "-> Confirming key login still works cleanly:" -ForegroundColor Yellow
ssh "$sshUser@$vmHost" "echo key login OK"

Write-Host "`n===== Setup complete for $vmHost =====" -ForegroundColor Cyan
Write-Host "Reminder: add an entry to your ~/.ssh/config for easier access, e.g.:" -ForegroundColor Gray
Write-Host "  Host <alias>" -ForegroundColor Gray
Write-Host "      HostName $vmHost" -ForegroundColor Gray
Write-Host "      User $sshUser" -ForegroundColor Gray
Write-Host "      IdentityFile ~/.ssh/id_ed25519" -ForegroundColor Gray
