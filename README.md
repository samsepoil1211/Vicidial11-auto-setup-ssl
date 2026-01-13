# VICIdial SSL Auto Configuration Script

This guide walks you through the full process of enabling SSL on your VICIdial server using a shell script. It works on ViciBox (SUSE-based) systems and updates Apache, Asterisk, hosts, and hostname settings in a safe and automated way.

---

## 📦 Requirements

- A running ViciBox server (v11+)
- Root privileges
- Your SSL certificate and key files placed in:
<p>/etc/apache2/ssl.crt/star_beltalk_live.crt</p>
<p>/etc/apache2/ssl.key/_.beltalk.live.key</p>  
<hr>
## 🔧 1. Installation 

```bash
zypper install git
cd /usr/src
git clone https://github.com/samsepoil1211/Vicidial11-auto-setup-ssl.git
cp ssl.crt/star_beltalk_live.crt /etc/apache2/ssl.crt/
cp ssl.key/_.beltalk.live.key /etc/apache2/ssl.key
chmod +x /usr/src/Vicidial11-auto-setup-ssl/setup.sh
./usr/src/Vicidial11-auto-setup-ssl/setup.sh
