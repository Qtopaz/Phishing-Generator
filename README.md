# Phishing Automation Script

A fully automated Bash script for setting up phishing pages, injecting credential capture logic, enabling SSL via Certbot, and generating a short public URL. Designed for Red Team and educational purposes only.


## 🧰 Features

- Clone any real website and inject a PHP credential capture script
- Use built-in phishing templates (Facebook, Gmail), or load a custom template
- Automatically installs and configures required tools: Apache, PHP, Certbot
- Sets file permissions and configures Apache
- Optionally enables HTTPS with a valid SSL certificate
- Generates a TinyURL link for easy victim delivery

---

## 📦 Requirements

Run as root on Kali or Debian-based system.

Required tools (installed automatically if missing):

- `wget`
- `apache2`
- `php`, `php-mysql`, `libapache2-mod-php`
- `certbot`, `python3-certbot-apache`
- `curl`

---

## 🚀 Usage

```bash
chmod +x phishing_setup.sh
sudo ./phishing_setup.sh
